fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lngx-hud'
author 'lngx'
description 'lngx-hud - HUD'
version '2.0.0'

shared_scripts {
    'config.lua',
    'shared/locale.lua'
}

client_scripts {
    'client/bridge.lua',
    'client/settings.lua',
    'client/admin.lua',
    'client/minimap.lua',
    'client/info.lua',
    'client/flightpath.lua',
    'client/weapon.lua',
    'client/vehicle.lua',
    'client/main.lua'
}

server_script 'server/admin.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*',
    'html/logo.*',
    'html/logo-*.png',
    'html/sounds/*.mp3',
    'html/weapons/*.png',
    'locales/*.json'
}
