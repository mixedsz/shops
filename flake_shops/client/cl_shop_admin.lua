local QBCore, ESX = nil, nil

-- Framework Detection
Citizen.CreateThread(function()
    if GetResourceState(Config.QBCoreGetCoreObject) ~= "missing" then
        QBCore = exports[Config.QBCoreGetCoreObject]:GetCoreObject()
    elseif GetResourceState(Config.ESXgetSharedObject) ~= "missing" then
        ESX = exports[Config.ESXgetSharedObject]:getSharedObject()
    end
end)

-- Check if player is admin
function IsPlayerAdmin()
    if QBCore then
        -- Check if player has admin permission
        if QBCore.Functions.HasPermission("admin") then
            return true
        end
        -- Check against Config.AdminGroups
        local PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData and PlayerData.job then
            for _, group in ipairs(Config.AdminGroups) do
                if PlayerData.job.name == group then
                    return true
                end
            end
        end
    elseif ESX then
        local playerData = ESX.GetPlayerData()
        if playerData and playerData.group then
            local playerGroup = playerData.group
            -- Check against Config.AdminGroups
            for _, group in ipairs(Config.AdminGroups) do
                if playerGroup == group then
                    return true
                end
            end
        end
    end
    return false
end

-- Store admin check result
local isAdminChecked = false
local isAdminResult = false

-- Receive admin permission result from server
RegisterNetEvent('flake_shops:adminPermissionResult')
AddEventHandler('flake_shops:adminPermissionResult', function(isAdmin)
    isAdminChecked = true
    isAdminResult = isAdmin
end)

-- Request admin check from server
local function CheckAdminPermission(callback)
    -- First try client-side check
    local clientCheck = IsPlayerAdmin()
    if clientCheck then
        callback(true)
        return
    end

    -- If client check fails, ask server
    TriggerServerEvent('flake_shops:checkAdminPermission')

    -- Wait for server response
    local timeout = 0
    while not isAdminChecked and timeout < 50 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end

    if isAdminChecked then
        callback(isAdminResult)
        isAdminChecked = false
    else
        callback(false)
    end
end

-- Get player info for UI
local function GetPlayerInfo()
    local playerId = GetPlayerServerId(PlayerId())
    local playerName = GetPlayerName(PlayerId())

    -- Try to get discord avatar (this would need a server callback in production)
    local playerAvatar = "https://cdn.discordapp.com/embed/avatars/" .. (playerId % 5) .. ".png"

    return {
        playerId = playerId,
        playerName = playerName,
        playerAvatar = playerAvatar
    }
end

-- Command: Shops Creator
RegisterCommand('shopscreator', function()
    CheckAdminPermission(function(isAdmin)
        if not isAdmin then
            TriggerEvent('flake_shopsCL:notify', "You don't have permission to use this command!", "error")
            return
        end

        local playerInfo = GetPlayerInfo()

        SetNuiFocus(true, true)
        SendNUIMessage({
            type = "openShopAdmin",
            editMode = false,
            playerName = playerInfo.playerName,
            playerId = playerInfo.playerId,
            playerAvatar = playerInfo.playerAvatar,
            uiColor = Config.UiColor or "#f59e0b"
        })
    end)
end, false)

-- Receive shop list (kept for compatibility but not used for menu)
RegisterNetEvent('flake_shops:receiveShopList')
AddEventHandler('flake_shops:receiveShopList', function(shopList)
    -- This is no longer used for the menu, but kept for compatibility
end)

-- NUI Callbacks
RegisterNUICallback('saveShop', function(data, cb)
    TriggerServerEvent('flake_shops:saveShop', data.shopData, data.editMode)
    cb('ok')
end)

RegisterNUICallback('deleteShop', function(data, cb)
    if data and data.shopName then
        TriggerServerEvent('flake_shops:deleteShop', data.shopName)
    end
    cb({status = 'ok'})
end)

RegisterNUICallback('closeAdmin', function(data, cb)
    SetNuiFocus(false, false)
    cb({status = 'ok'})
end)

-- Server tells client to close admin UI (e.g., after delete)
RegisterNetEvent('flake_shops:closeAdminUI')
AddEventHandler('flake_shops:closeAdminUI', function()
    Citizen.SetTimeout(100, function()
        SetNuiFocus(false, false)
        SendNUIMessage({
            type = "closeShopAdmin"
        })
    end)
end)

RegisterNUICallback('getCurrentPosition', function(data, cb)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    cb({
        x = coords.x,
        y = coords.y,
        z = coords.z
    })
end)

-- Store items callback
local itemsCallback = nil
local shopsCallback = nil

-- Receive items from server
RegisterNetEvent('flake_shops:receiveItems')
AddEventHandler('flake_shops:receiveItems', function(serverItems)
    if itemsCallback then
        itemsCallback(serverItems)
        itemsCallback = nil
    end
end)

-- Request items from server
RegisterNUICallback('requestItems', function(data, cb)
    itemsCallback = cb
    TriggerServerEvent('flake_shops:requestItems')
end)

-- Receive shops from server
RegisterNetEvent('flake_shops:updateShops')
AddEventHandler('flake_shops:updateShops', function(shops)
    if shopsCallback then
        -- Convert Shops table to array format for NUI
        local shopsArray = {}
        for shopName, shopData in pairs(shops) do
            -- Convert vector3 positions to table format for NUI
            local shopDataCopy = {}
            for k, v in pairs(shopData) do
                shopDataCopy[k] = v
            end

            if shopDataCopy.Pos then
                local positions = {}
                for i, pos in ipairs(shopDataCopy.Pos) do
                    table.insert(positions, {x = pos.x, y = pos.y, z = pos.z})
                end
                shopDataCopy.Pos = positions
            end

            shopDataCopy.name = shopName
            table.insert(shopsArray, shopDataCopy)
        end

        shopsCallback(shopsArray)
        shopsCallback = nil
    end
end)

-- Request shops from server
RegisterNUICallback('requestShops', function(data, cb)
    shopsCallback = cb
    TriggerServerEvent('flake_shops:requestShops')
end)

-- Command to list all shops
RegisterCommand('listshops', function()
    CheckAdminPermission(function(isAdmin)
        if not isAdmin then
            TriggerEvent('flake_shopsCL:notify', "You don't have permission to use this command!", "error")
            return
        end

        if not Config.Shops or next(Config.Shops) == nil then
            TriggerEvent('flake_shopsCL:notify', "No shops available!", "info")
            return
        end

        print("=== Available Shops ===")
        for shopName, shopData in pairs(Config.Shops) do
            local itemCount = shopData.Items and #shopData.Items or 0
            local posCount = shopData.Pos and #shopData.Pos or 0
            print(string.format("- %s (%d items, %d locations)", shopName, itemCount, posCount))
        end
        print("======================")

        TriggerEvent('flake_shopsCL:notify', "Shop list printed to console (F8)", "info")
    end)
end, false)

-- Debug command to check your group
RegisterCommand('checkmygroup', function()
    print("=== CHECKING YOUR GROUP ===")
    if QBCore then
        local PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData and PlayerData.job then
            print("Framework: QBCore")
            print("Job Name: " .. tostring(PlayerData.job.name))
            print("Job Label: " .. tostring(PlayerData.job.label))
            print("Job Grade: " .. tostring(PlayerData.job.grade.name))
        else
            print("Framework: QBCore (PlayerData not loaded)")
        end
    elseif ESX then
        local playerData = ESX.GetPlayerData()
        if playerData then
            print("Framework: ESX")
            print("Group: " .. tostring(playerData.group))
            if playerData.job then
                print("Job Name: " .. tostring(playerData.job.name))
                print("Job Label: " .. tostring(playerData.job.label))
            end
        else
            print("Framework: ESX (PlayerData not loaded)")
        end
    else
        print("Framework: Not detected")
    end
    print("===========================")
    print("Configured Admin Groups:")
    for i, group in ipairs(Config.AdminGroups) do
        print("  " .. i .. ". " .. group)
    end
    print("===========================")
    TriggerEvent('flake_shopsCL:notify', "Check console (F8) for your group info", "info")
end, false)

-- Command to teleport to shop
RegisterCommand('gotoshop', function(source, args)
    CheckAdminPermission(function(isAdmin)
        if not isAdmin then
            TriggerEvent('flake_shopsCL:notify', "You don't have permission to use this command!", "error")
            return
        end

        if not args[1] then
            TriggerEvent('flake_shopsCL:notify', "Usage: /gotoshop <shopname>", "error")
            return
        end

        local shopName = args[1]
        local shopData = Config.Shops[shopName]

        if not shopData or not shopData.Pos or #shopData.Pos == 0 then
            TriggerEvent('flake_shopsCL:notify', "Shop not found!", "error")
            return
        end

        local pos = shopData.Pos[1]
        SetEntityCoords(PlayerPedId(), pos.x, pos.y, pos.z, false, false, false, true)
        TriggerEvent('flake_shopsCL:notify', "Teleported to " .. shopName, "success")
    end)
end, false)

-- Receive framework type from server and forward to NUI
RegisterNetEvent('flake_shops:receiveFramework')
AddEventHandler('flake_shops:receiveFramework', function(framework)
    SendNUIMessage({
        type = "frameworkDetected",
        framework = framework
    })
end)

-- NUI requests framework detection
RegisterNUICallback('getFramework', function(data, cb)
    TriggerServerEvent('flake_shops:getFramework')
    cb('ok')
end)

-- NUI requests teleport to shop position (Goto button in admin panel)
RegisterNUICallback('gotoShopPosition', function(data, cb)
    if data and data.x then
        local ped = PlayerPedId()
        SetEntityCoords(ped, data.x, data.y, data.z, false, false, false, true)
        TriggerEvent('flake_shopsCL:notify', 'Teleported to shop location', 'success')
    end
    cb({status = 'ok'})
end)