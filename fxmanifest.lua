fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Your Name'
description 'Modern car dealership - ESX / QBCore / Qbox / Standalone'
version '2.0.0'

shared_script 'config/config.lua'

ui_page 'html/index.html'

client_scripts {
    'bridge/client.lua',
    'client/client.lua'
}

server_scripts {
    'bridge/server.lua',
    'server/server.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/design.css',
    'html/script.js',
    'html/img/*.png',
    'html/img/*.svg'
}
