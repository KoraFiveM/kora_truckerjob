fx_version 'cerulean'
game 'gta5'
lua54 'yes'
-- Keep the legacy resource name resolvable for exports['qbtruckerjob'] callers.
provide 'qbtruckerjob'
author 'qwerty1Verified'
description 'Trucking job to haul cargo for money with an integrated skill system'
version '1.1.0'

dependencies {
    'kora_lib',
    'kora_core',
    'kora_target',
    --'kora_vehiclekeys',
}

shared_script '@kora_lib/init.lua'

shared_scripts {
    '@kora_core/init.lua',
    'config.lua',
}

client_script 'client/client.lua'

server_script 'server.lua'

files {
    'html/images/**/*.webp',
}

this_is_a_map 'yes'
