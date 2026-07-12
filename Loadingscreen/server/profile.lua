local avatarCache = {}
local avatarDataCache = {}

local STATUS_LABELS = {
    online = 'Online',
    idle = 'Abwesend',
    dnd = 'Bitte nicht stören',
    offline = 'Offline',
    connecting = 'Verbindet...',
    loading = 'Status unbekannt'
}

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64Encode(data)
    return ((data:gsub('.', function(x)
        local r, byte = '', x:byte()
        for i = 8, 1, -1 do
            r = r .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then
            return ''
        end
        local value = 0
        for i = 1, 6 do
            value = value + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
        end
        return B64:sub(value + 1, value + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function getConvarBool(name, default)
    local value = GetConvar(name, default and 'true' or 'false')
    return value == '1' or value == 'true' or value == 'yes'
end

local function isDebugEnabled()
    return getConvarBool('loadingscreen:debug', false)
end

local function debugLog(message)
    if isDebugEnabled() then
        print(('[Loadingscreen] %s'):format(message))
    end
end

local function getDiscordId(source)
    local identifier = GetPlayerIdentifierByType(source, 'discord')
    if identifier then
        return identifier:gsub('discord:', '')
    end

    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if id:find('^discord:') then
            return id:gsub('discord:', '')
        end
    end

    return nil
end

local function defaultAvatar(discordId, discriminator)
    local disc = tonumber(discriminator)

    if disc and disc > 0 then
        return ('https://cdn.discordapp.com/embed/avatars/%d.png'):format(disc % 5)
    end

    local numericId = tonumber(discordId)
    if numericId then
        return ('https://cdn.discordapp.com/embed/avatars/%d.png'):format((numericId >> 22) % 6)
    end

    return nil
end

local function buildAvatarUrl(discordId, avatarHash, discriminator)
    if avatarHash and avatarHash ~= '' then
        local extension = avatarHash:sub(1, 2) == 'a_' and 'gif' or 'png'
        return ('https://cdn.discordapp.com/avatars/%s/%s.%s?size=128'):format(discordId, avatarHash, extension)
    end

    return defaultAvatar(discordId, discriminator)
end

local function parseDiscordUser(user, discordId)
    if type(user) ~= 'table' then
        return nil
    end

    local username = user.username
    if type(username) ~= 'string' or username == '' then
        return nil
    end

    local globalName = user.global_name or user.display_name
    local displayName = (type(globalName) == 'string' and globalName ~= '') and globalName or username

    return {
        avatarUrl = buildAvatarUrl(discordId, user.avatar, user.discriminator),
        displayName = displayName,
        username = username,
        discriminator = user.discriminator
    }
end

local function awaitHttp(method, url, headers, body)
    local completed = false
    local result = {
        status = 0,
        body = ''
    }

    PerformHttpRequest(url, function(statusCode, responseBody)
        result.status = statusCode
        result.body = responseBody or ''
        completed = true
    end, method, body or '', headers or {})

    while not completed do
        Wait(0)
    end

    return result
end

local function fetchAvatarDataUri(avatarUrl)
    if type(avatarUrl) ~= 'string' or avatarUrl == '' then
        return nil
    end

    local cached = avatarDataCache[avatarUrl]
    if cached then
        return cached
    end

    local response = awaitHttp('GET', avatarUrl)
    if response.status ~= 200 or response.body == '' then
        debugLog(('Avatar-Download fehlgeschlagen (%s): HTTP %s'):format(avatarUrl, response.status))
        return nil
    end

    local mime = avatarUrl:find('%.gif', 1, true) and 'image/gif' or 'image/png'
    local dataUri = ('data:%s;base64,%s'):format(mime, base64Encode(response.body))

    avatarDataCache[avatarUrl] = dataUri
    return dataUri
end

local function embedAvatar(profile)
    if type(profile) ~= 'table' then
        return profile
    end

    local avatarUrl = profile.avatarUrl or profile.avatar
    if type(avatarUrl) == 'string' and avatarUrl ~= '' and not avatarUrl:find('^data:') then
        profile.avatar = fetchAvatarDataUri(avatarUrl) or nil
    end

    profile.avatarUrl = nil
    return profile
end

local function fetchLanyardProfile(discordId)
    local response = awaitHttp('GET', ('https://api.lanyard.rest/v1/users/%s'):format(discordId))

    if response.status ~= 200 or response.body == '' then
        return nil
    end

    local decoded = json.decode(response.body)
    if not decoded or not decoded.success or type(decoded.data) ~= 'table' then
        return nil
    end

    local data = decoded.data
    local userData = parseDiscordUser(data.discord_user, discordId)

    if not userData then
        return nil
    end

    userData.discordStatus = data.discord_status or 'offline'
    return userData
end

local function fetchDiscordProfile(discordId)
    local token = GetConvar('loadingscreen:discord_bot_token', '')
    if token == '' then
        debugLog('Kein Bot-Token gesetzt (set loadingscreen:discord_bot_token "...")')
        return nil
    end

    local cacheEntry = avatarCache[discordId]
    if cacheEntry and cacheEntry.expiresAt > os.time() then
        return cacheEntry.profile
    end

    local response = awaitHttp('GET', ('https://discord.com/api/v10/users/%s'):format(discordId), {
        ['Authorization'] = ('Bot %s'):format(token),
        ['Content-Type'] = 'application/json'
    })

    if response.status ~= 200 or response.body == '' then
        debugLog(('Discord API Fehler fuer %s: HTTP %s'):format(discordId, response.status))
        return nil
    end

    local user = json.decode(response.body)
    local userData = parseDiscordUser(user, discordId)

    if not userData then
        return nil
    end

    avatarCache[discordId] = {
        profile = userData,
        expiresAt = os.time() + 300
    }

    return userData
end

local function resolveStatusLabel(status)
    return STATUS_LABELS[status] or STATUS_LABELS.online
end

function BuildPlayerProfile(source)
    local playerName = GetPlayerName(source) or 'Spieler'
    local discordId = getDiscordId(source)
    local profile = {
        name = playerName,
        displayName = playerName,
        discordUsername = nil,
        discordId = discordId,
        discordStatus = 'connecting',
        statusLabel = resolveStatusLabel('connecting'),
        avatar = nil,
        isOnline = false
    }

    if not discordId then
        debugLog(('Keine Discord-ID fuer Spieler %s (%s)'):format(playerName, source))
        profile.statusLabel = resolveStatusLabel('loading')
        profile.discordStatus = 'loading'
        return profile
    end

    local userData = fetchDiscordProfile(discordId)
    local discordStatus = nil

    if getConvarBool('loadingscreen:use_lanyard', true) then
        local lanyardData = fetchLanyardProfile(discordId)

        if lanyardData then
            discordStatus = lanyardData.discordStatus

            if not userData then
                userData = lanyardData
            end
        end
    end

    if userData then
        profile.displayName = userData.displayName
        profile.name = userData.displayName
        profile.discordUsername = userData.username
        profile.avatarUrl = userData.avatarUrl

        if discordStatus then
            profile.discordStatus = discordStatus
            profile.isOnline = discordStatus ~= 'offline'
        else
            profile.discordStatus = 'loading'
            profile.isOnline = false
        end

        profile.statusLabel = resolveStatusLabel(profile.discordStatus)
    else
        profile.avatarUrl = defaultAvatar(discordId, nil)
        profile.discordStatus = 'connecting'
        profile.statusLabel = resolveStatusLabel('connecting')
    end

    return embedAvatar(profile)
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    deferrals.defer()
    Wait(0)

    local src = source
    deferrals.update('Profil wird geladen...')

    local profile = BuildPlayerProfile(src)

    deferrals.handover({
        playerProfile = profile
    })

    deferrals.done()
end)

RegisterNetEvent('loadingscreen:server:requestProfile', function()
    local src = source
    local profile = BuildPlayerProfile(src)
    TriggerClientEvent('loadingscreen:client:receiveProfile', src, profile)
end)

exports('GetPlayerProfile', BuildPlayerProfile)
