fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ha0lu8_rodin'
description 'Gun Game Phone (QBCore)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/framework.lua',
}

client_scripts {
    'client/cl_appearance.lua',
    'client/cl_main.lua',
    'client/cl_match.lua',
    'client/cl_standin.lua',
}

ui_page 'ui/hud.html'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
    'server/sv_account.lua',
    'server/sv_social.lua',
    'server/sv_match.lua',
    'server/sv_standin.lua',
}

files {
    'ui/index.html',
    'ui/app.js',
    'ui/styles.css',
    'ui/icon.png',
    'ui/hud.html',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'qbx_core',
}
