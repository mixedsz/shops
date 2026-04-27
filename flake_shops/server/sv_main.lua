local QBCore, ESX = nil, nil
local playerOrders = {}

-- Initialize Config.Shops and Shops (from database)
Config.Shops = Config.Shops or {}
Shops = Shops or {} -- This will be populated from database by sv_shop_manager.lua

-- Framework Detection
Citizen.CreateThread(function()
    if GetResourceState(Config.QBCoreGetCoreObject) ~= "missing" then
        QBCore = exports[Config.QBCoreGetCoreObject]:GetCoreObject()
    elseif GetResourceState(Config.ESXgetSharedObject) ~= "missing" then
        ESX = exports[Config.ESXgetSharedObject]:getSharedObject()
    end

    -- Startup message
    Citizen.Wait(1000)
    print("^2📦 FlakeShops ^0started successfully! -> ^6discord.gg/gcrz ^0for updates & new scripts.")
end)

-- Helper Functions
local function GetPlayerIdentifier(source)
    if QBCore then
        return QBCore.Functions.GetPlayer(source).PlayerData.citizenid
    elseif ESX then
        return ESX.GetPlayerFromId(source).identifier
    end
    return tostring(source)
end

local function GetPlayerMoney(source, currency)
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)

        if currency == "cash" then
            return Player.PlayerData.money["cash"]
        elseif currency == "bank" then
            return Player.PlayerData.money["bank"]
        elseif currency == "crypto" then
            return Player.PlayerData.money["crypto"]
        else
            return Player.Functions.GetItemByName(currency) and Player.Functions.GetItemByName(currency).amount or 0
        end
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(source)

        if currency == "money" then
            return xPlayer.getMoney()
        elseif currency == "bank" then
            return xPlayer.getAccount("bank").money
        elseif currency == "black_money" then
            return xPlayer.getAccount("black_money").money
        else
            local item = xPlayer.getInventoryItem(currency)
            return item and item.count or 0
        end
    end
    return 0
end

local function RemoveMoney(source, currency, amount)
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)

        if currency == "cash" then
            Player.Functions.RemoveMoney("cash", amount)
            return true
        elseif currency == "bank" then
            Player.Functions.RemoveMoney("bank", amount)
            return true
        elseif currency == "crypto" then
            Player.Functions.RemoveMoney("crypto", amount)
            return true
        else
            Player.Functions.RemoveItem(currency, amount)
            return true
        end
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(source)

        if currency == "money" then
            xPlayer.removeMoney(amount)
            return true
        elseif currency == "bank" then
            xPlayer.removeAccountMoney("bank", amount)
            return true
        elseif currency == "black_money" then
            xPlayer.removeAccountMoney("black_money", amount)
            return true
        else
            xPlayer.removeInventoryItem(currency, amount)
            return true
        end
    end
    return false
end

local function AddItem(source, item, amount)
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        Player.Functions.AddItem(item, amount)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], "add")
        return true
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        xPlayer.addInventoryItem(item, amount)
        return true
    end
    return false
end

-- Buy Items
RegisterNetEvent('flake_shops:buyItems')
AddEventHandler('flake_shops:buyItems', function(zone, cart, payMethod)
    local src = source
    local identifier = GetPlayerIdentifier(src)

    -- Get shop data from Shops variable (loaded from database)
    local shopData = Shops and Shops[zone] or Config.Shops[zone]

    if not shopData then
        TriggerClientEvent('flake_shopsCL:notify', src, "Invalid shop zone", "error")
        return
    end

    if not cart or #cart == 0 then
        TriggerClientEvent('flake_shopsCL:notify', src, "Your cart is empty", "error")
        return
    end

    -- Check if payment method is valid
    local validPayment = false
    for _, currency in ipairs(shopData.Currency) do
        if currency == payMethod then
            validPayment = true
            break
        end
    end

    if not validPayment then
        TriggerClientEvent('flake_shopsCL:notify', src, "Invalid payment method", "error")
        return
    end

    -- Calculate total cost
    local totalCost = 0
    for _, item in ipairs(cart) do
        totalCost = totalCost + (tonumber(item.price) * tonumber(item.count))
    end

    -- Check if player has enough money
    local playerMoney = GetPlayerMoney(src, payMethod)
    if playerMoney < totalCost then
        local currencyLabel = Config.CurrencyLabels[payMethod] or payMethod:upper()
        local missingAmount = totalCost - playerMoney
        TriggerClientEvent('flake_shopsCL:notify', src, string.format("You are missing $%s %s", missingAmount, currencyLabel), "error")
        return
    end

    -- Remove money
    if not RemoveMoney(src, payMethod, totalCost) then
        TriggerClientEvent('flake_shopsCL:notify', src, "Failed to process payment", "error")
        return
    end

    -- Log the transaction
   -- Log the transaction
    TriggerEvent('flake_shops:logTransaction', src, zone, cart, totalCost, payMethod)

    -- Track analytics
    TriggerEvent('flake_shops:trackPurchase', src, zone, cart, totalCost, payMethod)

    -- Check if this shop uses the pickup system

    -- Check if this shop uses the pickup system
    local usePickup = shopData.UsePickup

    if usePickup and #Config.PickUpLocations > 0 then
        -- Create pickup order
        local randomLocation = math.random(1, #Config.PickUpLocations)
        local waitTime = Config.PickUpLocations[randomLocation].waitTime

        playerOrders[identifier] = {
            items = cart,
            location = randomLocation,
            ready = false
        }

        -- Create pickup blip for player
        TriggerClientEvent('flake_shops:createPickupBlip', src, randomLocation)

        -- Set timer for pickup to be ready
        Citizen.SetTimeout(waitTime * 1000, function()
            if playerOrders[identifier] then
                playerOrders[identifier].ready = true
                TriggerClientEvent('flake_shops:pickupReady', src)
            end
        end)
    else
        -- Give items directly to player
        for _, item in ipairs(cart) do
            AddItem(src, item.item, tonumber(item.count))
        end

        TriggerClientEvent('flake_shopsCL:notify', src, Config.Notifications.direct_purchase, "success")
    end
end)

-- Pickup Items
RegisterNetEvent('flake_shops:pickupItems')
AddEventHandler('flake_shops:pickupItems', function()
    local src = source
    local identifier = GetPlayerIdentifier(src)

    if not playerOrders[identifier] then
        TriggerClientEvent('flake_shopsCL:notify', src, "You don't have any pending orders", "error")
        return
    end

    if not playerOrders[identifier].ready then
        TriggerClientEvent('flake_shopsCL:notify', src, Config.Notifications.not_ready, "error")
        return
    end



    -- Give items to player
    for _, item in ipairs(playerOrders[identifier].items) do
        AddItem(src, item.item, tonumber(item.count))
    end

    -- Log the pickup
    TriggerEvent('flake_shops:logPickup', src, playerOrders[identifier].items)

    TriggerClientEvent('flake_shopsCL:notify', src, Config.Notifications.bought, "success")

    -- Clear order
    playerOrders[identifier] = nil
end)


