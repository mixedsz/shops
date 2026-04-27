RegisterNetEvent('flake_shopsSV:notify')
AddEventHandler('flake_shopsSV:notify', function(target, message, type)
    if target == -1 then
        TriggerClientEvent('flake_shopsCL:notify', -1, message, type)
    else
        TriggerClientEvent('flake_shopsCL:notify', target, message, type)
    end
end)
