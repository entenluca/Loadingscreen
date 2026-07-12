fx_version 'cerulean'
game 'gta5'

author 'ChatGPT'
description 'MB Development FiveM LoadingScreen mit Video-/PNG-Slideshow-Modus, Icons, Space-Toggle, Spielerprofil und voller Progressbar'
version '1.2.0'

loadscreen 'html/index.html'
loadscreen_cursor 'yes'

server_script 'server/profile.lua'
client_script 'client/profile.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/config.js',
    'html/icons.js',
    'html/assets/*'
}
