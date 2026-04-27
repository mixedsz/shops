local QBCore, ESX = nil, nil
local PlayerData = {}
local isLoggedIn = false
local inZone = false
local currentZone = nil
local blips = {}
local pickupBlip = nil
local pickupCoords = nil
local pickupReady = false
local pickupPed = nil
local pickupLocation = nil
local cart = {}
local shopPeds = {} -- Table to store shop peds

-- Dynamic shops loaded from server
Config.Shops = Config.Shops or {}

-- TextUI state tracking
local isShopTextUIShown = false
local isPickupTextUIShown = false

-- Check if ox_lib is available
local hasOxLib = GetResourceState('ox_lib') ~= 'missing'

-- Helper function for showing TextUI
local function ShowTextUI(text)
    if hasOxLib then
        exports.ox_lib:showTextUI(text)
    end
end

-- Helper function for hiding TextUI
local function HideTextUI()
    if hasOxLib then
        exports.ox_lib:hideTextUI()
    end
end

-- Framework Detection
Citizen.CreateThread(function()
    if GetResourceState(Config.QBCoreGetCoreObject) ~= "missing" then
        QBCore = exports[Config.QBCoreGetCoreObject]:GetCoreObject()

        RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            isLoggedIn = true
            PlayerData = QBCore.Functions.GetPlayerData()
            TriggerServerEvent('flake_shops:requestShops')
        end)

        RegisterNetEvent('QBCore:Client:OnPlayerUnload')
        AddEventHandler('QBCore:Client:OnPlayerUnload', function()
            isLoggedIn = false
            PlayerData = {}
            RemoveBlips()
        end)

        RegisterNetEvent('QBCore:Player:SetPlayerData')
        AddEventHandler('QBCore:Player:SetPlayerData', function(data)
            PlayerData = data
        end)

        isLoggedIn = true
        PlayerData = QBCore.Functions.GetPlayerData()
    elseif GetResourceState(Config.ESXgetSharedObject) ~= "missing" then
        ESX = exports[Config.ESXgetSharedObject]:getSharedObject()

        RegisterNetEvent('esx:playerLoaded')
        AddEventHandler('esx:playerLoaded', function(xPlayer)
            isLoggedIn = true
            PlayerData = xPlayer
            TriggerServerEvent('flake_shops:requestShops')
        end)

        RegisterNetEvent('esx:onPlayerLogout')
        AddEventHandler('esx:onPlayerLogout', function()
            isLoggedIn = false
            PlayerData = {}
            RemoveBlips()
        end)

        RegisterNetEvent('esx:setJob')
        AddEventHandler('esx:setJob', function(job)
            PlayerData.job = job
        end)

        isLoggedIn = true
        PlayerData = ESX.GetPlayerData()
    end

    -- Request shops from server
    Citizen.Wait(1000)
    TriggerServerEvent('flake_shops:requestShops')
end)

-- Receive shops from server
RegisterNetEvent('flake_shops:updateShops')
AddEventHandler('flake_shops:updateShops', function(shops)
    Config.Shops = shops
    RefreshBlips()
    SpawnAllShopPeds()
end)

-- Create Blips
function RefreshBlips()
    RemoveBlips()

    for k, v in pairs(Config.Shops) do
        if v.Blip then
            for i = 1, #v.Pos do
                local blip = AddBlipForCoord(v.Pos[i])
                SetBlipSprite(blip, v.Blip.sprite)
                SetBlipDisplay(blip, v.Blip.display)
                SetBlipScale(blip, v.Blip.scale)
                SetBlipColour(blip, v.Blip.colour)
                SetBlipAsShortRange(blip, v.Blip.shortRange)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(v.Blip.name)
                EndTextCommandSetBlipName(blip)
                table.insert(blips, blip)
            end
        end
    end
end

function RemoveBlips()
    for i = 1, #blips do
        if DoesBlipExist(blips[i]) then
            RemoveBlip(blips[i])
        end
    end
    blips = {}
end

-- Function to spawn a shop ped
function SpawnShopPed(shopName, shopConfig, position, index)
    -- Delete existing ped if there is one
    if shopPeds[shopName .. index] then
        DeletePed(shopPeds[shopName .. index])
        shopPeds[shopName .. index] = nil
    end

    -- Get the ped model
    local pedModel = GetHashKey(shopConfig.ShopPed.model)

    -- Request the model
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Citizen.Wait(1)
    end

    -- Create the ped
    local heading = shopConfig.ShopPed.heading or 0.0
    local ped = CreatePed(4, pedModel, position.x, position.y, position.z - 1.0, heading, false, true)

    -- Set ped attributes
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    -- Set ped to not flee or react to events
    TaskSetBlockingOfNonTemporaryEvents(ped, true)

    -- Set ped scenario/animation if specified
    if shopConfig.ShopPed.scenario then
        TaskStartScenarioInPlace(ped, shopConfig.ShopPed.scenario, 0, true)
    end

    -- Release the model
    SetModelAsNoLongerNeeded(pedModel)

    -- Store the ped reference
    shopPeds[shopName .. index] = ped

    return ped
end

-- Function to spawn all shop peds
function SpawnAllShopPeds()
    -- Clean up existing peds first
    for k, v in pairs(shopPeds) do
        if DoesEntityExist(v) then
            DeletePed(v)
        end
    end
    shopPeds = {}

    -- Spawn new peds for each shop location
    for shopName, shopConfig in pairs(Config.Shops) do
        if shopConfig.UsePed and shopConfig.ShopPed then
            for i, pos in ipairs(shopConfig.Pos) do
                SpawnShopPed(shopName, shopConfig, pos, i)
            end
        end
    end
end

-- Create Markers and handle shop interactions
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local sleep = 1000
        inZone = false

        for k, v in pairs(Config.Shops) do
            for i = 1, #v.Pos do
                local distance = #(coords - v.Pos[i])
                local interactionDistance = v.UsePed and 2.0 or Config.Size.x

                if distance < Config.DrawDistance then
                    sleep = 0

                    -- Only draw marker if not using a ped
                    if not v.UsePed then
                        DrawMarker(Config.Type, v.Pos[i].x, v.Pos[i].y, v.Pos[i].z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Size.x, Config.Size.y, Config.Size.z, Config.Color.r, Config.Color.g, Config.Color.b, 100, false, true, 2, false, nil, nil, false)
                    end

                    if distance < interactionDistance then
                        inZone = true
                        currentZone = {name = k, pos = i}

                        if IsControlJustReleased(0, 38) then -- E key
                            -- Hide TextUI when opening menu
                            if isShopTextUIShown then
                                HideTextUI()
                                isShopTextUIShown = false
                            end
                            OpenShopMenu(k)
                        end
                    end
                end
            end
        end

        -- Check if we should show the text UI
        local shouldShowUI = inZone

        -- Try to check if inventory UI is open (if the export exists)
        local inventoryOpen = false
        if GetResourceState('qb-inventory') ~= 'missing' and pcall(function() return exports['qb-inventory'].IsNuiFocused end) then
            inventoryOpen = exports['qb-inventory']:IsNuiFocused()
        elseif GetResourceState('ox_inventory') ~= 'missing' and pcall(function() return exports['ox_inventory'].IsNuiFocused end) then
            inventoryOpen = exports['ox_inventory']:IsNuiFocused()
        end

        -- Only update TextUI when state changes to prevent flashing
        if shouldShowUI and not inventoryOpen then
            if not isShopTextUIShown then
                ShowTextUI(Config.Notifications.press_menu)
                isShopTextUIShown = true
            end
        else
            if isShopTextUIShown then
                HideTextUI()
                isShopTextUIShown = false
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- Open Shop Menu
function OpenShopMenu(zone)
    TriggerEvent('flake_shops:openShop', zone)
    local items = Config.Shops[zone].Items
    local currencies = {}
    local defaultCurrency = Config.Shops[zone].Currency[1] or "cash"
    local currencyLabel = Config.CurrencyLabels[defaultCurrency] or defaultCurrency:upper()
    local shopLogo = Config.Shops[zone].ShopLogo or "blackmarket.png"

    -- Add currency information to each item
    for i, item in ipairs(items) do
        item.currencyLabel = currencyLabel
    end

    -- Prepare currency options for payment
    for _, currency in ipairs(Config.Shops[zone].Currency) do
        local label = Config.CurrencyLabels[currency] or currency:upper()
        table.insert(currencies, {name = currency, label = label})
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "shop",
        result = items,
        name = zone,
        currencies = currencies,
        currencyLabel = currencyLabel,
        imageBaseUrl = Config.InventoryImgUrl,
        shopLogo = shopLogo
    })

    cart = {}
end

-- NUI Callbacks
RegisterNUICallback('putcart', function(data, cb)
    table.insert(cart, {
        item = data.item,
        price = data.price,
        label = data.label
    })
    cb(cart)
end)

RegisterNUICallback('removecart', function(data)
    for k, v in pairs(cart) do
        if v.item == data.item then
            table.remove(cart, k)
            break
        end
    end
end)

RegisterNUICallback('emptycart', function()
    cart = {}
end)

RegisterNUICallback('escape', function()
    SetNuiFocus(false, false)
end)

RegisterNUICallback('notify', function(data)
    TriggerEvent('flake_shopsCL:notify', data.msg, 'error')
end)

RegisterNUICallback('buyCart', function(data)
    TriggerServerEvent('flake_shops:buyItems', data.Zone, data.Cart, data.payMethod)
    SetNuiFocus(false, false)
end)

-- Pickup System
-- Function to spawn a ped at the pickup location
function SpawnPickupPed(location)
    -- Delete existing ped if there is one
    if pickupPed then
        DeletePed(pickupPed)
        pickupPed = nil
    end

    -- Get the ped model
    local pedModel = GetHashKey(Config.PickUpLocations[location].pedModel)

    -- Request the model
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Citizen.Wait(1)
    end

    -- Create the ped
    pickupPed = CreatePed(4, pedModel,
        pickupCoords.x, pickupCoords.y, pickupCoords.z - 1.0, pickupCoords.w,
        false, true)

    -- Set ped attributes
    SetEntityAsMissionEntity(pickupPed, true, true)
    SetBlockingOfNonTemporaryEvents(pickupPed, true)
    SetPedDiesWhenInjured(pickupPed, false)
    SetPedCanPlayAmbientAnims(pickupPed, true)
    SetPedCanRagdollFromPlayerImpact(pickupPed, false)
    SetEntityInvincible(pickupPed, true)
    FreezeEntityPosition(pickupPed, true)

    -- Set ped to not flee or react to events
    TaskSetBlockingOfNonTemporaryEvents(pickupPed, true)

    -- Release the model
    SetModelAsNoLongerNeeded(pedModel)

    return pickupPed
end

RegisterNetEvent('flake_shops:createPickupBlip')
AddEventHandler('flake_shops:createPickupBlip', function(location)
    local randomLocation = Config.PickUpLocations[location]
    pickupCoords = randomLocation.coords
    pickupLocation = location

    if pickupBlip then
        RemoveBlip(pickupBlip)
    end

    pickupBlip = AddBlipForCoord(pickupCoords.x, pickupCoords.y, pickupCoords.z)
    SetBlipSprite(pickupBlip, 501)
    SetBlipDisplay(pickupBlip, 4)
    SetBlipScale(pickupBlip, 0.8)
    SetBlipColour(pickupBlip, 2)
    SetBlipAsShortRange(pickupBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Notifications.pick_up_blip)
    EndTextCommandSetBlipName(pickupBlip)

    TriggerEvent('flake_shopsCL:notify', Config.Notifications.order_placed, 'success')
end)

RegisterNetEvent('flake_shops:pickupReady')
AddEventHandler('flake_shops:pickupReady', function()
    pickupReady = true

    -- Spawn the ped when items are ready for pickup
    if pickupLocation then
        SpawnPickupPed(pickupLocation)
    end

    TriggerEvent('flake_shopsCL:notify', Config.Notifications.items_ready, 'success')
end)

-- Pickup Thread
Citizen.CreateThread(function()
    while true do
        local sleep = 1000

        if pickupCoords then
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local distance = #(coords - vector3(pickupCoords.x, pickupCoords.y, pickupCoords.z))

            -- More responsive checks when near pickup location
            if distance < 10.0 then
                sleep = 0 -- Update every frame when close to pickup

                if distance < 2.0 then
                    if pickupReady then
                        -- Only show TextUI if not already shown
                        if not isPickupTextUIShown or isPickupTextUIShown ~= 'ready' then
                            ShowTextUI(Config.Notifications.pickup_prompt)
                            isPickupTextUIShown = 'ready'
                        end

                        -- Check for E key press
                        if IsControlJustPressed(0, 38) then -- E key
                            -- Immediately trigger pickup
                            TriggerServerEvent('flake_shops:pickupItems')

                            -- Disable control briefly to prevent multiple triggers
                            Citizen.CreateThread(function()
                                DisableControlAction(0, 38, true) -- Disable E key
                                Citizen.Wait(1000) -- Wait 1 second
                                EnableControlAction(0, 38, true) -- Re-enable E key
                            end)

                            -- Hide TextUI
                            if isPickupTextUIShown then
                                HideTextUI()
                                isPickupTextUIShown = false
                            end

                            -- Clean up blip
                            if pickupBlip then
                                RemoveBlip(pickupBlip)
                                pickupBlip = nil
                            end

                            -- Clean up ped
                            if pickupPed then
                                DeletePed(pickupPed)
                                pickupPed = nil
                            end

                            -- Reset pickup variables
                            pickupCoords = nil
                            pickupReady = false
                            pickupLocation = nil
                        end
                    else
                        -- Only show TextUI if not already shown
                        if not isPickupTextUIShown or isPickupTextUIShown ~= 'not_ready' then
                            ShowTextUI(Config.Notifications.not_ready)
                            isPickupTextUIShown = 'not_ready'
                        end
                    end
                else
                    -- Only hide TextUI if currently shown
                    if isPickupTextUIShown then
                        HideTextUI()
                        isPickupTextUIShown = false
                    end
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- Clean up shop peds when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    -- Delete all shop peds
    for k, v in pairs(shopPeds) do
        if DoesEntityExist(v) then
            DeletePed(v)
        end
    end
    shopPeds = {}
end)

-- Debug
if Config.Debug then
    RegisterCommand('bmdebug', function()
        print('QBCore:', QBCore ~= nil)
        print('ESX:', ESX ~= nil)
        print('isLoggedIn:', isLoggedIn)
        print('inZone:', inZone)
        print('currentZone:', currentZone)
        print('cart:', json.encode(cart))
        print('shopPeds:', json.encode(shopPeds))
    end)

    -- Debug command to respawn all shop peds
    RegisterCommand('bmrespawnpeds', function()
        SpawnAllShopPeds()
        TriggerEvent('flake_shopsCL:notify', 'Shop peds respawned', 'success')
    end)
end
