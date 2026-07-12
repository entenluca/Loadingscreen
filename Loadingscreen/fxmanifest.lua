fx_version 'cerulean'
game 'gta5'

author 'MB Development'
description 'FiveM LoadingScreen mit ox_lib Admin-Panel, Dashboard-UI und dynamischer Konfiguration'
version '2.0.0'

loadscreen 'html/index.html'
loadscreen_cursor 'yes'

dependencies {
    'ox_lib'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/defaults.lua'
}

server_scripts {
    'server/main.lua'
}

client_scripts {
    'client/admin.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/config.js',
    'html/icons.js',
    'html/runtime-config.json',
    'html/assets/*'
}

lua54 'yes'

-- Server.cfg:
-- add_ace group.admin loadingscreen.admin allow
-- ensure ox_lib
-- ensure Loadingscreen
