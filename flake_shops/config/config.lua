Config = {}
Config.Debug = false  -- Set to true to enable debug messages

-- UI accent color — changes the main highlight color in both the Shop UI
-- and the ShopsCreator admin panel. Accepts any CSS hex color (e.g. "#e74c3c").
Config.UiColor = "#0b97f5"

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

-- ─────────────────────────────────────────────────────────────────────────────
-- Player-Owned / Job Shop Settings
-- ─────────────────────────────────────────────────────────────────────────────

-- Resource used to credit job society accounts after a sale.
-- Supported: "esx_society" (ESX), "qb-management" (QBCore), or "" to disable.
Config.SocietyResource = "esx_society"

-- Default % of each sale credited to the owning job's society when a new
-- player-owned shop is created. Bosses can change this per-shop in their
-- boss menu.
Config.DefaultSocietyPercent = 20

-- Job-specific UI themes applied when a shop's OwnerJob matches a key here.
-- theme: CSS class suffix applied to #wrapper ("police" → "police-theme")
-- accentColor: overrides Config.UiColor for that shop's UI
-- label: optional header prefix shown in the shop UI
Config.JobThemes = {
    police = {
        theme       = "police",
        accentColor = "#3b82f6",
        label       = "LSPD ARMORY",
    },
    ambulance = {
        theme       = "ems",
        accentColor = "#10b981",
        label       = "EMS MEDICAL SUPPLY",
    },
    ems = {
        theme       = "ems",
        accentColor = "#10b981",
        label       = "EMS MEDICAL SUPPLY",
    },
}

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