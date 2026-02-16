fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Fish'
description 'Food Truck Resource'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'shared/state.lua',
    'modules/crafting/client.lua',
    'modules/serving/client.lua',
    'modules/npc/client.lua',
    'main/client.lua'
}

server_scripts {
    'shared/utils.lua',
    'modules/crafting/server.lua',
    'modules/serving/server.lua',
    'modules/npc/server.lua',
    'main/server.lua'
}

dependencies {
    'ox_target',
    'ox_inventory',
    'ox_core',
    'ox_lib'
}
