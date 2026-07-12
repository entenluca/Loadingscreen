local RESOURCE = GetCurrentResourceName()

local function pushProfileToLoadscreen(profile)
    if type(profile) ~= 'table' then
        return
    end

    SendLoadingScreenMessage(json.encode({
        eventName = 'playerProfile',
        profile = profile
    }))
end

local function requestProfile()
    TriggerServerEvent('loadingscreen:server:requestProfile')
end

RegisterNetEvent('loadingscreen:client:receiveProfile', function(profile)
    pushProfileToLoadscreen(profile)
end)

exports('RefreshPlayerProfile', requestProfile)
