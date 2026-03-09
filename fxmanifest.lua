fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Fish'
description 'Food Truck'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/state.lua',
    'client/attach.lua',
    'client/crafting.lua',
    'client/npc.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
    'server/crafting.lua',
    'server/npc.lua',
    'server/selling.lua',
}

dependencies {
    'ox_target',
    'ox_inventory',
    'ox_core',
    'ox_lib',
}
