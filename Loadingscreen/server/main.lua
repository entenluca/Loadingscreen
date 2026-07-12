local Config = {}
local RESOURCE = GetCurrentResourceName()
local ADMIN_ACE = 'loadingscreen.admin'

local function deepCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}
    for key, item in pairs(value) do
        copy[key] = deepCopy(item)
    end

    return copy
end

local function isArrayTable(value)
    if type(value) ~= 'table' then
        return false
    end

    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' then
            return false
        end
        count += 1
    end

    return count > 0
end

local function deepMerge(base, override)
    local result = deepCopy(base)

    if type(override) ~= 'table' then
        return result
    end

    for key, value in pairs(override) do
        if type(value) == 'table' and type(result[key]) == 'table' and not isArrayTable(value) and not isArrayTable(result[key]) then
            result[key] = deepMerge(result[key], value)
        else
            result[key] = deepCopy(value)
        end
    end

    return result
end

local function encodeConfig(data)
    return json.encode(data, { indent = true, sort_keys = true })
end

local function persistConfig()
    SaveResourceFile(RESOURCE, 'data/settings.json', encodeConfig(Config), -1)
    SaveResourceFile(RESOURCE, 'html/runtime-config.json', encodeConfig(Config), -1)
end

local function loadConfigFromDisk()
    local raw = LoadResourceFile(RESOURCE, 'data/settings.json')

    if raw and raw ~= '' then
        local decoded = json.decode(raw)
        if decoded then
            Config = deepMerge(LoadingDefaults, decoded)
            persistConfig()
            return
        end
    end

    Config = deepCopy(LoadingDefaults)
    persistConfig()
end

local function isAdmin(source)
    if source == 0 then
        return true
    end

    return IsPlayerAceAllowed(source, ADMIN_ACE)
end

local function updateConfig(source, patch)
    if not isAdmin(source) then
        return false, 'Keine Berechtigung.'
    end

    if type(patch) ~= 'table' then
        return false, 'Ungültige Konfiguration.'
    end

    Config = deepMerge(Config, patch)
    persistConfig()
    TriggerClientEvent('loadingscreen:client:configUpdated', -1)

    return true, Config
end

local function resetConfig(source)
    if not isAdmin(source) then
        return false, 'Keine Berechtigung.'
    end

    Config = deepCopy(LoadingDefaults)
    persistConfig()
    TriggerClientEvent('loadingscreen:client:configUpdated', -1)

    return true, Config
end

loadConfigFromDisk()

lib.callback.register('loadingscreen:server:canAdmin', function(source)
    return isAdmin(source)
end)

lib.callback.register('loadingscreen:server:getConfig', function(source)
    if not isAdmin(source) then
        return nil
    end

    return Config
end)

lib.callback.register('loadingscreen:server:updateConfig', function(source, patch)
    return updateConfig(source, patch)
end)

lib.callback.register('loadingscreen:server:resetConfig', function(source)
    return resetConfig(source)
end)

exports('GetConfig', function()
    return deepCopy(Config)
end)

exports('SetConfig', function(patch)
    return updateConfig(0, patch)
end)

exports('ResetConfig', function()
    return resetConfig(0)
end)

exports('ReloadConfig', function()
    loadConfigFromDisk()
    TriggerClientEvent('loadingscreen:client:configUpdated', -1)
    return deepCopy(Config)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    print(('[%s] Loading-Screen Konfiguration geladen. Admin ACE: %s'):format(RESOURCE, ADMIN_ACE))
end)
