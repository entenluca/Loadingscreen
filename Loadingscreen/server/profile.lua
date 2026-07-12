local avatarCache = {}

local STATUS_LABELS = {
    online = 'Online',
    idle = 'Abwesend',
    dnd = 'Bitte nicht stören',
    offline = 'Offline',
    connecting = 'Verbindet...',
    loading = 'Status unbekannt'
}

local function getConvarBool(name, default)
    local value = GetConvar(name, default and 'true' or 'false')
    return value == '1' or value == 'true' or value == 'yes'
end

local function getDiscordId(source)
    local identifier = GetPlayerIdentifierByType(source, 'discord')
    if not identifier then
        return nil
    end

    return identifier:gsub('discord:', '')
end

--- Discord CDN: Default-Avatar
--- @see https://discord.com/developers/docs/reference#image-formatting
local function defaultAvatar(discordId, discriminator)
    local disc = tonumber(discriminator)

    -- Legacy-Usernames: discriminator % 5
    if disc and disc > 0 then
        return ('https://cdn.discordapp.com/embed/avatars/%d.png'):format(disc % 5)
    end

    -- Neues Username-System: (user_id >> 22) % 6
    local numericId = tonumber(discordId)
    if numericId then
        return ('https://cdn.discordapp.com/embed/avatars/%d.png'):format((numericId >> 22) % 6)
    end

    return nil
end

--- Discord CDN: Custom-Avatar (a_-Hash = animiert → .gif)
--- @see https://discord.com/developers/docs/reference#image-formatting
local function buildAvatarUrl(discordId, avatarHash, discriminator)
    if avatarHash and avatarHash ~= '' then
        local extension = avatarHash:sub(1, 2) == 'a_' and 'gif' or 'png'
        return ('https://cdn.discordapp.com/avatars/%s/%s.%s?size=128'):format(discordId, avatarHash, extension)
    end

    return defaultAvatar(discordId, discriminator)
end

--- Discord User Object → einheitliches Profil
--- global_name = Anzeigename, username = @-Handle
--- @see https://discord.com/developers/docs/resources/user#user-object
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
        avatar = buildAvatarUrl(discordId, user.avatar, user.discriminator),
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

local function buildPlayerProfile(source)
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
        profile.avatar = userData.avatar

        if discordStatus then
            profile.discordStatus = discordStatus
            profile.isOnline = discordStatus ~= 'offline'
        else
            profile.discordStatus = 'loading'
            profile.isOnline = false
        end

        profile.statusLabel = resolveStatusLabel(profile.discordStatus)
    else
        profile.avatar = defaultAvatar(discordId, nil)
        profile.discordStatus = 'connecting'
        profile.statusLabel = resolveStatusLabel('connecting')
    end

    return profile
end

RegisterNetEvent('loadingscreen:server:requestProfile', function()
    local src = source
    local profile = buildPlayerProfile(src)
    TriggerClientEvent('loadingscreen:client:receiveProfile', src, profile)
end)

exports('GetPlayerProfile', function(source)
    return buildPlayerProfile(source)
end)
