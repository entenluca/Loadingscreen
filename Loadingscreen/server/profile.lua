local RESOURCE = GetCurrentResourceName()
local avatarCache = {}

local STATUS_LABELS = {
    online = 'Online',
    idle = 'Abwesend',
    dnd = 'Bitte nicht stören',
    offline = 'Offline',
    connecting = 'Verbindet...',
    loading = 'Lädt...'
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

local function defaultAvatar(discordId)
    local numericId = tonumber(discordId)
    if not numericId then
        return nil
    end

    return ('https://cdn.discordapp.com/embed/avatars/%d.png'):format((numericId >> 22) % 6)
end

local function buildAvatarUrl(discordId, avatarHash)
    if avatarHash and avatarHash ~= '' then
        return ('https://cdn.discordapp.com/avatars/%s/%s.png?size=128'):format(discordId, avatarHash)
    end

    return defaultAvatar(discordId)
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
    local user = data.discord_user or {}

    return {
        avatar = buildAvatarUrl(discordId, user.avatar),
        discordUsername = user.global_name or user.username or nil,
        discordStatus = data.discord_status or 'offline'
    }
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
    if type(user) ~= 'table' then
        return nil
    end

    local profile = {
        avatar = buildAvatarUrl(discordId, user.avatar),
        discordUsername = user.global_name or user.username or nil,
        discordStatus = 'online'
    }

    avatarCache[discordId] = {
        profile = profile,
        expiresAt = os.time() + 300
    }

    return profile
end

local function resolveStatusLabel(status)
    return STATUS_LABELS[status] or STATUS_LABELS.online
end

local function buildPlayerProfile(source)
    local playerName = GetPlayerName(source) or 'Spieler'
    local discordId = getDiscordId(source)
    local profile = {
        name = playerName,
        discordId = discordId,
        discordUsername = playerName,
        discordStatus = 'connecting',
        statusLabel = resolveStatusLabel('connecting'),
        avatar = nil,
        isOnline = true
    }

    if not discordId then
        profile.statusLabel = resolveStatusLabel('loading')
        profile.discordStatus = 'loading'
        return profile
    end

    local remoteProfile

    if getConvarBool('loadingscreen:use_lanyard', true) then
        remoteProfile = fetchLanyardProfile(discordId)
    end

    if not remoteProfile then
        remoteProfile = fetchDiscordProfile(discordId)
    end

    if remoteProfile then
        profile.avatar = remoteProfile.avatar
        profile.discordUsername = remoteProfile.discordUsername or playerName
        profile.discordStatus = remoteProfile.discordStatus or 'online'
        profile.statusLabel = resolveStatusLabel(profile.discordStatus)
        profile.isOnline = profile.discordStatus ~= 'offline'
    else
        profile.avatar = defaultAvatar(discordId)
        profile.discordUsername = playerName
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
