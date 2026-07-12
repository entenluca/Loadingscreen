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

-- Avatar kommt erst nach dem Connect (nicht blockierend im playerConnecting)
CreateThread(function()
    Wait(1500)
    requestProfile()
end)

exports('RefreshPlayerProfile', requestProfile)
