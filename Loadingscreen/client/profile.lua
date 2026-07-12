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

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    for _ = 1, 30 do
        requestProfile()
        Wait(500)
    end
end)

exports('RefreshPlayerProfile', requestProfile)
