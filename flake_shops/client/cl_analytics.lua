-- Add this to client/cl_shop_admin.lua or create a new file client/cl_analytics.lua

-- Track shop visit when opening menu
RegisterNetEvent('flake_shops:openShop')
AddEventHandler('flake_shops:openShop', function(shopName)
    TriggerServerEvent('flake_shops:trackShopVisit', shopName)
end)

-- Request shop analytics callback
RegisterNUICallback('requestShopAnalytics', function(data, cb)
    if data and data.shopName then
        TriggerServerEvent('flake_shops:getShopAnalytics', data.shopName)
    end
    cb('ok')
end)

-- Request all shops analytics
RegisterNUICallback('requestAllShopsAnalytics', function(data, cb)
    TriggerServerEvent('flake_shops:getAllShopsAnalytics')
    cb('ok')
end)

-- Receive shop analytics and display
RegisterNetEvent('flake_shops:receiveShopAnalytics')
AddEventHandler('flake_shops:receiveShopAnalytics', function(analytics)
    SendNUIMessage({
        type = 'showAnalytics',
        analytics = analytics
    })
end)

-- Receive all shops analytics
RegisterNetEvent('flake_shops:receiveAllShopsAnalytics')
AddEventHandler('flake_shops:receiveAllShopsAnalytics', function(analytics)
    SendNUIMessage({
        type = 'analyticsData',
        analytics = analytics
    })
end)