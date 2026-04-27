-- Discord Logging Configuration
Config.Logs = {
    enable = true,
    webhook = '' -- Add your Discord webhook URL here
}

-- Function to send logs to Discord
local function SendDiscordLog(title, message, color)
    if not Config.Logs.enable then return end
    if Config.Logs.webhook == "" then return end

    local embed = {
        {
            ["title"] = title,
            ["description"] = message,
            ["type"] = "rich",
            ["color"] = color or 3447003, -- Blue color by default
            ["footer"] = {
                ["text"] = "Shop Logs • " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }

    PerformHttpRequest(Config.Logs.webhook, function(err, text, headers) end, 'POST', json.encode({
        username = "Shop Logs",
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

-- Log transaction
RegisterNetEvent('flake_shops:logTransaction')
AddEventHandler('flake_shops:logTransaction', function(playerId, zone, cart, totalCost, payMethod)
    local src = playerId
    local playerName = GetPlayerName(src)
    local identifier = nil

    if QBCore then
        identifier = QBCore.Functions.GetPlayer(src).PlayerData.citizenid
    elseif ESX then
        identifier = ESX.GetPlayerFromId(src).identifier
    else
        identifier = "Unknown"
    end

    local itemsList = ""
    for _, item in ipairs(cart) do
        itemsList = itemsList .. "• " .. item.count .. "x " .. item.label .. " ($" .. item.price .. " each)\n"
    end

    local message = string.format("**Player:** %s (ID: %s, Identifier: %s)\n**Shop:** %s\n**Total Cost:** $%s\n**Payment Method:** %s\n\n**Items Purchased:**\n%s",
        playerName, src, identifier, zone, totalCost, payMethod, itemsList)

    SendDiscordLog("Shop Purchase", message, 3066993) -- Green color

    if Config.Debug then
        print("[SHOP LOG] " .. message:gsub("\n", " | "))
    end
end)

-- Log pickup
RegisterNetEvent('flake_shops:logPickup')
AddEventHandler('flake_shops:logPickup', function(playerId, items)
    local src = playerId
    local playerName = GetPlayerName(src)
    local identifier = nil

    if QBCore then
        identifier = QBCore.Functions.GetPlayer(src).PlayerData.citizenid
    elseif ESX then
        identifier = ESX.GetPlayerFromId(src).identifier
    else
        identifier = "Unknown"
    end

    local itemsList = ""
    for _, item in ipairs(items) do
        itemsList = itemsList .. "• " .. item.count .. "x " .. item.label .. "\n"
    end

    local message = string.format("**Player:** %s (ID: %s, Identifier: %s)\n\n**Items Picked Up:**\n%s",
        playerName, src, identifier, itemsList)

    SendDiscordLog("Shop Pickup", message, 10181046) -- Purple color

    if Config.Debug then
        print("[SHOP PICKUP LOG] " .. message:gsub("\n", " | "))
    end
end)
