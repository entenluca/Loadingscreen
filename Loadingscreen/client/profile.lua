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
    Wait(300)

    for _ = 1, 25 do
        requestProfile()
        Wait(800)
    end
end)

exports('RefreshPlayerProfile', requestProfile)
