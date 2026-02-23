fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Amine'
description 'Ultra-Futuristic Modular Trucking System with Solo and Convoy modes'
version '1.0.0'

-- External Dependencies
dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target'
}

-- Shared scripts (Configuration and Map Data)
shared_scripts {
    '@ox_lib/init.lua',
    -- Solo Module Shared
    'solo/config.lua',
    'solo/location.lua',
    -- Convoy Module Shared
    'convoy/config.lua',
    'convoy/location.lua'
}

-- Client Logic
client_scripts {
    'solo/client.lua',
    'convoy/client.lua'
}

-- Server Logic
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'solo/server.lua',
    'convoy/server.lua'
}

-- NUI Configuration
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    -- Optimized Recursive Image Loading
    'html/images/**/*',
    'html/images/*.png',
    'html/images/trailers/*.png'
}

-- Project Metadata
metadata 'author' 'Amine'
metadata 'project' 'Trucker Job'
