local avatarCache = {}
local avatarDataCache = {}
local playerDiscordCache = {}

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

local function isValidSource(source)
    return type(source) == 'number' and source > 0
end

--- Discord-ID NUR waehrend playerConnecting verfuegbar – sofort auslesen!
--- @see https://forum.cfx.re/t/getplayeridentifierbytype-discord-returns-null-during-game/5311088
local function captureIdentifiers(source)
    local identifiers = {}
    local discordId = nil
    local license = nil

    if not isValidSource(source) then
        return discordId, license, identifiers
    end

    local count = GetNumPlayerIdentifiers(source)
    for i = 0, count - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            identifiers[#identifiers + 1] = id

            if id:find('^discord:') then
                discordId = id:gsub('discord:', '')
            elseif id:find('^license:') then
                license = id
            end
        end
    end

    if not discordId then
        local byType = GetPlayerIdentifierByType(source, 'discord')
        if byType then
            discordId = byType:gsub('discord:', '')
        end
    end

    if not license then
        license = GetPlayerIdentifierByType(source, 'license')
    end

    return discordId, license, identifiers
end

local function getCachedDiscordId(source)
    local license = isValidSource(source) and GetPlayerIdentifierByType(source, 'license') or nil
    if license and playerDiscordCache[license] then
        return playerDiscordCache[license]
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

local function buildAvatarUrl(discordId, avatarHash, discriminator, size)
    size = size or 128

    if avatarHash and avatarHash ~= '' then
        local extension = avatarHash:sub(1, 2) == 'a_' and 'gif' or 'png'
        return ('https://cdn.discordapp.com/avatars/%s/%s.%s?size=%d'):format(discordId, avatarHash, extension, size)
    end

    return defaultAvatar(discordId, discriminator)
end

local function parseDiscordUser(user, discordId, avatarSize)
    avatarSize = avatarSize or 128

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
        avatarUrl = buildAvatarUrl(discordId, user.avatar, user.discriminator, avatarSize),
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

local function embedAvatar(profile, skipAvatar)
    if type(profile) ~= 'table' or skipAvatar then
        if type(profile) == 'table' then
            profile.avatarUrl = nil
        end
        return profile
    end

    local avatarUrl = profile.avatarUrl or profile.avatar
    if type(avatarUrl) == 'string' and avatarUrl ~= '' and not avatarUrl:find('^data:') then
        profile.avatar = fetchAvatarDataUri(avatarUrl) or nil
    end

    profile.avatarUrl = nil
    return profile
end

local function fetchLanyardStatus(discordId)
    local response = awaitHttp('GET', ('https://api.lanyard.rest/v1/users/%s'):format(discordId))

    if response.status ~= 200 or response.body == '' then
        return nil
    end

    local decoded = json.decode(response.body)
    if not decoded or not decoded.success or type(decoded.data) ~= 'table' then
        return nil
    end

    return decoded.data.discord_status or 'offline'
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
    local userData = parseDiscordUser(data.discord_user, discordId, 128)

    if not userData then
        return nil
    end

    userData.discordStatus = data.discord_status or 'offline'
    return userData
end

local function fetchDiscordProfile(discordId, avatarSize)
    avatarSize = avatarSize or 128

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
        debugLog(('Discord Users API Fehler fuer %s: HTTP %s'):format(discordId, response.status))
        return nil
    end

    local user = json.decode(response.body)
    local userData = parseDiscordUser(user, discordId, avatarSize)

    if not userData then
        return nil
    end

    avatarCache[discordId] = {
        profile = userData,
        expiresAt = os.time() + 300
    }

    return userData
end

local function fetchGuildMemberProfile(discordId, avatarSize)
    avatarSize = avatarSize or 128

    local token = GetConvar('loadingscreen:discord_bot_token', '')
    local guildId = GetConvar('loadingscreen:discord_guild_id', '')

    if token == '' or guildId == '' then
        return nil
    end

    local response = awaitHttp('GET', ('https://discord.com/api/v10/guilds/%s/members/%s'):format(guildId, discordId), {
        ['Authorization'] = ('Bot %s'):format(token),
        ['Content-Type'] = 'application/json'
    })

    if response.status ~= 200 or response.body == '' then
        debugLog(('Discord Guild Member API Fehler fuer %s: HTTP %s'):format(discordId, response.status))
        return nil
    end

    local member = json.decode(response.body)
    if type(member) ~= 'table' or type(member.user) ~= 'table' then
        return nil
    end

    local userData = parseDiscordUser(member.user, discordId, avatarSize)
    if not userData then
        return nil
    end

    if type(member.nick) == 'string' and member.nick ~= '' then
        userData.displayName = member.nick
    end

    return userData
end

local function resolveStatusLabel(status)
    return STATUS_LABELS[status] or STATUS_LABELS.online
end

local function buildFallbackProfile(playerName, discordId)
    return {
        name = playerName,
        displayName = playerName,
        discordUsername = nil,
        discordId = discordId,
        discordStatus = discordId and 'loading' or 'connecting',
        statusLabel = resolveStatusLabel(discordId and 'loading' or 'connecting'),
        avatar = nil,
        isOnline = false
    }
end

function BuildPlayerProfileFromData(discordId, playerName, options)
    options = options or {}
    local skipAvatar = options.skipAvatar == true

    playerName = playerName or 'Spieler'

    local profile = buildFallbackProfile(playerName, discordId)

    if not discordId then
        return embedAvatar(profile, skipAvatar)
    end

    local userData = fetchDiscordProfile(discordId, options.avatarSize or 128)

    if not userData then
        userData = fetchGuildMemberProfile(discordId, options.avatarSize or 128)
    end

    local discordStatus = nil

    if getConvarBool('loadingscreen:use_lanyard', true) then
        discordStatus = fetchLanyardStatus(discordId)

        if not discordStatus then
            local lanyardData = fetchLanyardProfile(discordId)

            if lanyardData then
                discordStatus = lanyardData.discordStatus

                if not userData then
                    userData = lanyardData
                end
            end
        elseif not userData then
            local lanyardData = fetchLanyardProfile(discordId)
            if lanyardData then
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
            profile.statusLabel = resolveStatusLabel(profile.discordStatus)
        else
            profile.discordStatus = 'loading'
            profile.isOnline = false
            profile.statusLabel = resolveStatusLabel('loading')
        end
    else
        profile.avatarUrl = defaultAvatar(discordId, nil)
        profile.discordStatus = 'loading'
        profile.statusLabel = resolveStatusLabel('loading')
    end

    return embedAvatar(profile, skipAvatar)
end

function BuildPlayerProfile(source)
    if not isValidSource(source) then
        return buildFallbackProfile('Spieler', nil)
    end

    local playerName = GetPlayerName(source) or 'Spieler'
    local discordId = getCachedDiscordId(source)

    return BuildPlayerProfileFromData(discordId, playerName, { skipAvatar = false })
end

--- playerConnecting: Discord-ID SOFORT lesen + handover (ohne defer – txAdmin/Queue-kompatibel)
--- @see https://docs.fivem.net/docs/scripting-manual/nui-development/loading-screens/#handover-data
AddEventHandler('playerConnecting', function(playerName, _, deferrals)
    local src = source
    local capturedName = playerName or 'Spieler'

    local discordId, license, identifierList = captureIdentifiers(src)

    if license and discordId then
        playerDiscordCache[license] = discordId
    end

    local profile = buildFallbackProfile(capturedName, discordId)

    if discordId then
        local ok, result = pcall(function()
            return BuildPlayerProfileFromData(discordId, capturedName, {
                skipAvatar = false,
                avatarSize = 64
            })
        end)

        if ok and type(result) == 'table' then
            profile = result
        else
            debugLog(('Profil-Fehler: %s'):format(tostring(result)))
        end
    elseif isDebugEnabled() then
        local listed = #identifierList > 0 and table.concat(identifierList, ', ') or '(keine)'
        print(('[Loadingscreen] Keine Discord-ID fuer %s'):format(capturedName))
        print(('[Loadingscreen] Identifier beim Connect: %s'):format(listed))
        print('[Loadingscreen] Discord Desktop muss laufen (nicht nur im Browser)!')
        print('[Loadingscreen] Discord -> Einstellungen -> Autorisierte Apps -> FiveM erlauben')
        print('[Loadingscreen] FiveM & Discord NICHT als Administrator starten')
    end

    if deferrals and deferrals.handover then
        deferrals.handover({
            playerProfile = profile
        })
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if not isValidSource(src) then
        return
    end

    local license = GetPlayerIdentifierByType(src, 'license')
    if license then
        playerDiscordCache[license] = nil
    end
end)

RegisterNetEvent('loadingscreen:server:requestProfile', function()
    local src = source
    if not isValidSource(src) then
        return
    end

    local profile = BuildPlayerProfile(src)
    TriggerClientEvent('loadingscreen:client:receiveProfile', src, profile)
end)

RegisterCommand('lsdebug', function(source)
    if source == 0 then
        print('[Loadingscreen] lsdebug: Nur ingame als Spieler nutzbar.')
        return
    end

    local playerName = GetPlayerName(source) or 'Spieler'
    local license = GetPlayerIdentifierByType(source, 'license')
    local cachedDiscord = license and playerDiscordCache[license] or nil
    local liveDiscord = GetPlayerIdentifierByType(source, 'discord')

    print(('[Loadingscreen] lsdebug %s | Cache: %s | Live: %s'):format(
        playerName,
        cachedDiscord or 'KEINE',
        liveDiscord or 'KEINE (normal nach Connect!)'
    ))

    TriggerClientEvent('chat:addMessage', source, {
        color = { 245, 255, 0 },
        multiline = true,
        args = { 'Loadingscreen', ('Discord (Cache): %s'):format(cachedDiscord or 'KEINE – Discord Desktop pruefen!') }
    })
end, false)

exports('GetPlayerProfile', BuildPlayerProfile)
