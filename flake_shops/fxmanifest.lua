fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Flake - Enhanced by Claude'
description 'Dynamic Shops System with Advanced Analytics'

ui_page('html/admin.html')

files({
	'html/index.html',
	'html/script.js',
	'html/style.css',
	'html/admin.html',
	'html/admin_script.js',
	'html/admin_style.css',
	'html/fonts/vibes.ttf',
	'html/img/*.png',
	'html/img/*.svg',
})

client_scripts {
	'config/*.lua',
	'client/*.lua'
}

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'config/*.lua',
	'logs.lua',
	'server/sv_shop_manager.lua', -- Load first to initialize Shops variable
	'server/sv_analytics.lua',     -- NEW: Analytics tracking
	'server/sv_main.lua',
	'server/sv_notifications.lua'
}

escrow_ignore {
    'client/cl_notifications.lua',
    'client/cl_shop_admin.lua',
    'client/cl_analytics.lua',     -- NEW: Analytics client
    'server/sv_notifications.lua',
    'server/sv_shop_manager.lua',
    'server/sv_analytics.lua',     -- NEW: Analytics server
    'config/*.lua',
	'logs.lua',
	'shops.sql',
	'enhanced_shops_analytics.sql' -- NEW: Analytics database
}

dependency '/assetpacks'