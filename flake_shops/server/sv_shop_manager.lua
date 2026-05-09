local QBCore, ESX = nil, nil
Shops = {} -- Global variable so other files can access it

-- Framework Detection
Citizen.CreateThread(function()
    if GetResourceState(Config.QBCoreGetCoreObject) ~= "missing" then
        QBCore = exports[Config.QBCoreGetCoreObject]:GetCoreObject()
    elseif GetResourceState(Config.ESXgetSharedObject) ~= "missing" then
        ESX = exports[Config.ESXgetSharedObject]:getSharedObject()
    end

    -- Ensure required tables exist (safe for existing installs)
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `shop_analytics` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_name` VARCHAR(100) NOT NULL,
            `total_cost` DECIMAL(12,2) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            INDEX `idx_shop_name` (`shop_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function() end)

    -- Load shops from database on startup
    LoadShopsFromDatabase()
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Global helpers (used by sv_main.lua and boss menu below)
-- ─────────────────────────────────────────────────────────────────────────────

-- Returns jobName, gradeLevel (number)
function GetPlayerJobInfo(source)
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            local job   = Player.PlayerData.job
            local grade = job.grade and (job.grade.level or 0) or 0
            return job.name, grade
        end
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            return xPlayer.job.name, (xPlayer.job.grade or 0)
        end
    end
    return "", 0
end

-- Returns all grades for a job as [{grade=N, label="..."}] sorted ascending
local function GetJobGrades(jobName, cb)
    local grades = {}
    if QBCore then
        local jobData = QBCore.Shared.Jobs and QBCore.Shared.Jobs[jobName]
        if jobData and jobData.grades then
            for gradeLevel, gradeData in pairs(jobData.grades) do
                table.insert(grades, {
                    grade = tonumber(gradeLevel),
                    label = gradeData.name or ("Grade " .. gradeLevel)
                })
            end
            table.sort(grades, function(a, b) return a.grade < b.grade end)
        end
        cb(grades)
    elseif ESX then
        MySQL.Async.fetchAll(
            'SELECT grade, label FROM job_grades WHERE job_name = @job ORDER BY grade ASC',
            {['@job'] = jobName},
            function(rows)
                if rows then
                    for _, r in ipairs(rows) do
                        table.insert(grades, {grade = r.grade, label = r.label or ("Grade " .. r.grade)})
                    end
                end
                cb(grades)
            end
        )
    else
        cb(grades)
    end
end

-- Async: calls cb(true) if the player is at the highest grade for their job.
-- This correctly handles custom job names (not just "boss") and grade 0 being top rank.
local function IsJobBoss(source, jobName, gradeLevel, cb)
    GetJobGrades(jobName, function(grades)
        if #grades == 0 then
            -- No grade data available — fall back to QBCore isboss flag only
            if QBCore then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player and Player.PlayerData.job.isboss == true then
                    cb(true)
                    return
                end
            end
            cb(false)
            return
        end
        -- Find the highest grade number in the job
        local maxGrade = grades[1].grade
        for _, g in ipairs(grades) do
            if g.grade > maxGrade then maxGrade = g.grade end
        end
        cb(gradeLevel >= maxGrade)
    end)
end

-- Credit the owning job's society account after a sale
function AddSocietyMoney(jobName, amount)
    if not jobName or jobName == "" or amount <= 0 then return end
    local res = Config.SocietyResource or ""
    if res == "esx_society" and GetResourceState('esx_society') ~= 'missing' then
        TriggerEvent('esx_society:addMoney', jobName, amount)
    elseif res == "qb-management" and GetResourceState('qb-management') ~= 'missing' then
        pcall(function() exports['qb-management']:AddMoney(jobName, amount) end)
    end
end

-- Returns society balance for ESX society (async, fires cb with number)
local function GetSocietyBalance(jobName, cb)
    local res = Config.SocietyResource or ""
    if res == "esx_society" and GetResourceState('esx_society') ~= 'missing' then
        TriggerEvent('esx_society:getSocietyAccount', jobName, function(account)
            cb(account and account.money or 0)
        end)
    else
        cb(0)
    end
end

-- Convert Shops[name] to a JSON-safe table (vector3 → plain tables, name attached)
local function ShopToSafeTable(name, data)
    local copy = {}
    for k, v in pairs(data) do copy[k] = v end
    if copy.Pos then
        local positions = {}
        for _, pos in ipairs(copy.Pos) do
            table.insert(positions, {x = pos.x, y = pos.y, z = pos.z})
        end
        copy.Pos = positions
    end
    copy.name = name
    return copy
end

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
AddEventHandler('flake_shops:saveShop', function(shopData, editMode, originalName)
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
    local lookupName = (editMode and originalName and originalName ~= "") and originalName or shopName

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
        local nameChanged = originalName and originalName ~= "" and originalName ~= shopName

        if nameChanged then
            -- Name changed: check the new name is not already taken
            MySQL.Async.fetchScalar('SELECT COUNT(*) FROM shops WHERE shop_name = @shop_name', {
                ['@shop_name'] = shopName
            }, function(count)
                if count > 0 then
                    TriggerClientEvent('flake_shopsCL:notify', src, "A shop with this name already exists!", "error")
                    return
                end
                MySQL.Async.execute('UPDATE shops SET shop_name = @new_name, shop_data = @shop_data WHERE shop_name = @old_name', {
                    ['@new_name'] = shopName,
                    ['@old_name'] = originalName,
                    ['@shop_data'] = shopDataJson
                }, function(affectedRows)
                    if affectedRows > 0 then
                        TriggerClientEvent('flake_shopsCL:notify', src, "Shop renamed and updated successfully!", "success")
                        LoadShopsFromDatabase()
                    else
                        TriggerClientEvent('flake_shopsCL:notify', src, "Failed to rename shop!", "error")
                    end
                end)
            end)
        else
            -- Same name, update data only
            MySQL.Async.execute('UPDATE shops SET shop_data = @shop_data WHERE shop_name = @shop_name', {
                ['@shop_name'] = lookupName,
                ['@shop_data'] = shopDataJson
            }, function(affectedRows)
                if affectedRows > 0 then
                    TriggerClientEvent('flake_shopsCL:notify', src, "Shop updated successfully!", "success")
                    LoadShopsFromDatabase()
                else
                    TriggerClientEvent('flake_shopsCL:notify', src, "Failed to update shop!", "error")
                end
            end)
        end
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

-- Return detected framework to client (for currency UI)
RegisterNetEvent('flake_shops:getFramework')
AddEventHandler('flake_shops:getFramework', function()
    local src = source
    local fw = "esx"
    if QBCore then fw = "qbcore"
    elseif ESX then fw = "esx" end
    TriggerClientEvent('flake_shops:receiveFramework', src, fw)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Boss Menu  (job bosses only, no server-admin permission needed)
-- ─────────────────────────────────────────────────────────────────────────────

RegisterNetEvent('flake_shops:requestBossMenu')
AddEventHandler('flake_shops:requestBossMenu', function()
    local src = source
    local jobName, gradeLevel = GetPlayerJobInfo(src)

    if jobName == "" then
        TriggerClientEvent('flake_shopsCL:notify', src, "Could not detect your job!", "error")
        return
    end

    IsJobBoss(src, jobName, gradeLevel, function(isBoss)
        if not isBoss then
            TriggerClientEvent('flake_shopsCL:notify', src, "You must be the highest rank in your job to access the boss menu!", "error")
            return
        end

        -- Find every shop owned by this job (case-insensitive, trimmed match)
        local jobLower = jobName:lower():gsub("^%s*(.-)%s*$", "%1")
        local ownedShops = {}
        for name, data in pairs(Shops) do
            local ownerLower = (data.OwnerJob or ""):lower():gsub("^%s*(.-)%s*$", "%1")
            if ownerLower ~= "" and ownerLower == jobLower then
                table.insert(ownedShops, ShopToSafeTable(name, data))
            end
        end

        if #ownedShops == 0 then
            TriggerClientEvent('flake_shopsCL:notify', src, "No shops found for job: " .. jobName .. " (check Owner Job field matches exactly)", "error")
            return
        end

    -- Grab analytics totals for each owned shop
    local shopNames = {}
    for _, s in ipairs(ownedShops) do table.insert(shopNames, "'" .. s.name .. "'") end
    local inClause = table.concat(shopNames, ",")

    MySQL.Async.fetchAll(
        'SELECT shop_name, COALESCE(SUM(total_cost),0) AS revenue, COUNT(*) AS transactions FROM shop_analytics WHERE shop_name IN (' .. inClause .. ') GROUP BY shop_name',
        {},
        function(rows)
            local analyticsMap = {}
            if rows then
                for _, r in ipairs(rows) do
                    analyticsMap[r.shop_name] = { revenue = r.revenue, transactions = r.transactions }
                end
            end
            for _, s in ipairs(ownedShops) do
                s.analytics = analyticsMap[s.name] or { revenue = 0, transactions = 0 }
            end

            -- Get society balance then job grades before sending the menu
            GetSocietyBalance(jobName, function(balance)
                GetJobGrades(jobName, function(grades)
                    TriggerClientEvent('flake_shops:receiveBossMenu', src, ownedShops, balance, jobName, grades)
                end)
            end)
        end
    )
    end) -- IsJobBoss callback
end)

-- Boss saves society% and per-item grade requirements for their own shop
RegisterNetEvent('flake_shops:saveBossShopSettings')
AddEventHandler('flake_shops:saveBossShopSettings', function(data)
    local src = source
    local jobName, gradeLevel = GetPlayerJobInfo(src)

    if not data or not data.shopName then return end

    IsJobBoss(src, jobName, gradeLevel, function(isBoss)
        if not isBoss then return end

        local shopName = data.shopName
        local shopOwner = (Shops[shopName] and Shops[shopName].OwnerJob or ""):lower():gsub("^%s*(.-)%s*$", "%1")
        if not Shops[shopName] or shopOwner ~= jobName:lower():gsub("^%s*(.-)%s*$", "%1") then
            TriggerClientEvent('flake_shopsCL:notify', src, "You don't own this shop!", "error")
            return
        end

        -- Only allow bosses to adjust SocietyPercent and item minGrade values
        if data.societyPercent ~= nil then
            Shops[shopName].SocietyPercent = math.max(0, math.min(100, tonumber(data.societyPercent) or 0))
        end

        if data.items and Shops[shopName].Items then
            local gradeMap = {}
            for _, upd in ipairs(data.items) do gradeMap[upd.item] = tonumber(upd.minGrade) or 0 end
            for _, shopItem in ipairs(Shops[shopName].Items) do
                if gradeMap[shopItem.item] ~= nil then
                    shopItem.minGrade = gradeMap[shopItem.item]
                end
            end
        end

        local copy = ShopToSafeTable(shopName, Shops[shopName])
        MySQL.Async.execute('UPDATE shops SET shop_data = @d WHERE shop_name = @n', {
            ['@n'] = shopName, ['@d'] = json.encode(copy)
        }, function(affected)
            if affected and affected > 0 then
                TriggerClientEvent('flake_shopsCL:notify', src, "Shop settings saved!", "success")
                LoadShopsFromDatabase()
            else
                TriggerClientEvent('flake_shopsCL:notify', src, "Failed to save settings!", "error")
            end
        end)
    end) -- IsJobBoss callback
end)