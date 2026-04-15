local QBCore, ESX = nil, nil
Shops = {} -- Global variable so other files can access it

-- Framework Detection
Citizen.CreateThread(function()
    if GetResourceState(Config.QBCoreGetCoreObject) ~= "missing" then
        QBCore = exports[Config.QBCoreGetCoreObject]:GetCoreObject()
    elseif GetResourceState(Config.ESXgetSharedObject) ~= "missing" then
        ESX = exports[Config.ESXgetSharedObject]:getSharedObject()
    end
    
    -- Load shops from database on startup
    LoadShopsFromDatabase()
end)

-- Check if player is admin
function IsPlayerAdmin(source)
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            -- Check if player has admin permission
            if QBCore.Functions.HasPermission(source, "admin") then
                return true
            end
            -- Check against Config.AdminGroups
            if Player.PlayerData and Player.PlayerData.job then
                for _, group in ipairs(Config.AdminGroups) do
                    if Player.PlayerData.job.name == group then
                        return true
                    end
                end
            end
        end
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local playerGroup = xPlayer.getGroup()
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

-- Server callback to check admin permission
RegisterNetEvent('flake_shops:checkAdminPermission')
AddEventHandler('flake_shops:checkAdminPermission', function()
    local src = source
    local isAdmin = IsPlayerAdmin(src)
    TriggerClientEvent('flake_shops:adminPermissionResult', src, isAdmin)
end)

-- Get all items from framework
RegisterNetEvent('flake_shops:requestItems')
AddEventHandler('flake_shops:requestItems', function()
    local src = source
    local items = {}
    local inventoryImgUrl = Config.InventoryImgUrl or "qb-inventory/html/images/"

    if QBCore then
        -- Get items from QBCore shared items
        local QBItems = QBCore.Shared.Items
        if QBItems then
            for itemName, itemData in pairs(QBItems) do
                local imageName = itemData.image or (itemName .. '.png')
                table.insert(items, {
                    name = itemName,
                    label = itemData.label or itemName,
                    image = imageName,
                    imagePath = 'nui://' .. inventoryImgUrl .. imageName
                })
            end
        end
        TriggerClientEvent('flake_shops:receiveItems', src, items)
    elseif ESX then
        -- Try ox_inventory first
        local oxItems = exports.ox_inventory and exports.ox_inventory:Items()
        if oxItems then
            for itemName, itemData in pairs(oxItems) do
                local imageName = (itemName .. '.png')
                table.insert(items, {
                    name = itemName,
                    label = itemData.label or itemName,
                    image = imageName,
                    imagePath = 'nui://' .. inventoryImgUrl .. imageName
                })
            end
            TriggerClientEvent('flake_shops:receiveItems', src, items)
        else
            -- Fallback to ESX database
            MySQL.Async.fetchAll('SELECT * FROM items', {}, function(result)
                if result then
                    for _, itemData in ipairs(result) do
                        local imageName = (itemData.name .. '.png')
                        table.insert(items, {
                            name = itemData.name,
                            label = itemData.label or itemData.name,
                            image = imageName,
                            imagePath = 'nui://' .. inventoryImgUrl .. imageName
                        })
                    end
                end
                TriggerClientEvent('flake_shops:receiveItems', src, items)
            end)
            return
        end
    end
end)

-- Load shops from database
function LoadShopsFromDatabase()
    MySQL.Async.fetchAll('SELECT * FROM shops', {}, function(result)
        if result then
            Shops = {}
            for _, row in ipairs(result) do
                local shopData = json.decode(row.shop_data)
                if shopData then
                    -- Convert position data to vector3
                    if shopData.Pos then
                        for i, pos in ipairs(shopData.Pos) do
                            shopData.Pos[i] = vector3(pos.x, pos.y, pos.z)
                        end
                    end
                    Shops[row.shop_name] = shopData
                end
            end

            -- Send shops to all clients
            TriggerClientEvent('flake_shops:updateShops', -1, Shops)
        end
    end)
end

-- Get all shops
RegisterNetEvent('flake_shops:requestShops')
AddEventHandler('flake_shops:requestShops', function()
    local src = source
    TriggerClientEvent('flake_shops:updateShops', src, Shops)
end)

-- Save shop to database
RegisterNetEvent('flake_shops:saveShop')
AddEventHandler('flake_shops:saveShop', function(shopData, editMode)
    local src = source
    
    if not IsPlayerAdmin(src) then
        TriggerClientEvent('flake_shopsCL:notify', src, "You don't have permission to do this!", "error")
        return
    end
    
    if not shopData or not shopData.name then
        TriggerClientEvent('flake_shopsCL:notify', src, "Invalid shop data!", "error")
        return
    end
    
    local shopName = shopData.name
    
    -- Convert vector3 positions to table format for JSON
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
    
    local shopDataJson = json.encode(shopDataCopy)
    
    if editMode then
        -- Update existing shop
        MySQL.Async.execute('UPDATE shops SET shop_data = @shop_data WHERE shop_name = @shop_name', {
            ['@shop_name'] = shopName,
            ['@shop_data'] = shopDataJson
        }, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent('flake_shopsCL:notify', src, "Shop updated successfully!", "success")
                LoadShopsFromDatabase()
            else
                TriggerClientEvent('flake_shopsCL:notify', src, "Failed to update shop!", "error")
            end
        end)
    else
        -- Check if shop already exists
        MySQL.Async.fetchScalar('SELECT COUNT(*) FROM shops WHERE shop_name = @shop_name', {
            ['@shop_name'] = shopName
        }, function(count)
            if count > 0 then
                TriggerClientEvent('flake_shopsCL:notify', src, "A shop with this name already exists!", "error")
                return
            end
            
            -- Insert new shop
            MySQL.Async.execute('INSERT INTO shops (shop_name, shop_data) VALUES (@shop_name, @shop_data)', {
                ['@shop_name'] = shopName,
                ['@shop_data'] = shopDataJson
            }, function(insertId)
                if insertId then
                    TriggerClientEvent('flake_shopsCL:notify', src, "Shop created successfully!", "success")
                    LoadShopsFromDatabase()
                else
                    TriggerClientEvent('flake_shopsCL:notify', src, "Failed to create shop!", "error")
                end
            end)
        end)
    end
end)

-- Delete shop
RegisterNetEvent('flake_shops:deleteShop')
AddEventHandler('flake_shops:deleteShop', function(shopName)
    local src = source

    if not IsPlayerAdmin(src) then
        TriggerClientEvent('flake_shopsCL:notify', src, "You don't have permission to do this!", "error")
        return
    end

    MySQL.Async.execute('DELETE FROM shops WHERE shop_name = @shop_name', {
        ['@shop_name'] = shopName
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('flake_shopsCL:notify', src, "Shop deleted successfully!", "success")
            -- Close the admin UI
            TriggerClientEvent('flake_shops:closeAdminUI', src)
            LoadShopsFromDatabase()
        else
            TriggerClientEvent('flake_shopsCL:notify', src, "Failed to delete shop!", "error")
        end
    end)
end)

-- Get shop list for editing
RegisterNetEvent('flake_shops:getShopList')
AddEventHandler('flake_shops:getShopList', function()
    local src = source
    
    if not IsPlayerAdmin(src) then
        return
    end
    
    local shopList = {}
    for shopName, _ in pairs(Shops) do
        table.insert(shopList, shopName)
    end
    
    TriggerClientEvent('flake_shops:receiveShopList', src, shopList)
end)

