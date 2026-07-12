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

CreateThread(function()
    Wait(400)

    for _ = 1, 10 do
        requestProfile()
        Wait(1000)
    end
end)

RegisterNetEvent('loadingscreen:client:receiveProfile', function(profile)
    pushProfileToLoadscreen(profile)
end)

exports('RefreshPlayerProfile', requestProfile)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    requestProfile()
end)
