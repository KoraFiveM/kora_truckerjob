fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'qwerty1Verified'
description 'Trucking job to haul cargo for money with an integrated skill system'
version '0.2.1'

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

client_scripts {
    'client/client.lua',
    -- Optional FFT hooks: returns immediately unless fft_kora_hooks is true.
    'fft_hooks.lua'
}

server_script 'server.lua'

files {
    'html/images/**/*.webp',
}

this_is_a_map 'yes'

-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'
