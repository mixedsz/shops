Config = {}
Config.Debug = false  -- Set to true to enable debug messages

-- Admin Groups (for ESX framework)
Config.AdminGroups = {
    'management',
    'admin',
    'lead',
    'senior',
    'owner',
}

Config.QBCoreGetCoreObject = 'qb-core'
Config.ESXgetSharedObject   = 'es_extended'

-- Currency display labels (will appear after the $ symbol)
Config.CurrencyLabels = {
    cash = "Cash - (USD)",
    money = "Cash - (USD)",
    bank = "(Bank - USD)",
    blackdiamond = "(Black Diamonds)",
    black_money = "(Dirty Money)"
    -- Add more currency types and their display labels as needed
}

-- Currencies shown in the admin panel per framework (auto-detected at runtime)
Config.FrameworkCurrencies = {
    qbcore = {
        { value = "cash",         label = "Cash" },
        { value = "bank",         label = "Bank" },
        { value = "crypto",       label = "Crypto" },
        { value = "black_money",  label = "Black Money" },
        { value = "blackdiamond", label = "Black Diamond" },
    },
    esx = {
        { value = "money",        label = "Cash" },
        { value = "bank",         label = "Bank" },
        { value = "black_money",  label = "Black Money" },
        { value = "blackdiamond", label = "Black Diamond" },
    },
}


Config.DrawDistance = 25
Config.Size         = { x = 0.4, y = 0.4, z = 0.2 }
Config.Color        = { r = 0, g = 128, b = 255 }
Config.Type         = 2
Config.InventoryImgUrl = "ox_inventory/web/images/"  --  QB Inventory = "qb-inventory/html/images/"  |  OX Inventory = "ox_inventory/web/images/"

-- Shops are now managed through the admin UI (/createshop, /editshop)
-- All shop data is stored in the database
Config.Shops = {}


Config.PickUpLocations = {
    [1] = {
        coords   = vector4(950.5075, -203.5941, 73.2085, 296.1207),
        pedModel = "g_m_y_mexgang_01",
        waitTime = 30,  -- seconds to pick up
        label    = "BROKEN MOTELS"
    },
    [2] = {
        coords   = vector4(725.1525, -1190.7144, 24.2791, 221.5764),
        pedModel = "g_m_y_salvaboss_01",
        waitTime = 10,
        label    = "Grove Circle"
    },
}