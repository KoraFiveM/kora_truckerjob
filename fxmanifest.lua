fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'qwerty1Verified'
description 'Trucking job to haul cargo for money with an integrated skill system'
version '1.1.0'

dependencies {
    'qblib',
    'qbcore',
    'qbtarget',
    --'qbvehiclekeys',
}

shared_script '@qblib/init.lua'

shared_scripts {
    '@qbcore/init.lua',
    'config.lua',
}

client_script 'client/client.lua'

server_script 'server.lua'

files {
    'html/images/**/*.webp',
}

this_is_a_map 'yes'
