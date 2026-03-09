Config = {}

-- ─── Truck definitions ────────────────────────────────────────────────────────
-- Each key is the vehicle model name (lowercase).
-- servingPosition: x/y/z offset relative to the vehicle for the worker attachment.
-- servingHeading:  relative yaw (degrees) of the worker when attached.
Config.Trucks = {
    ['mrtasty'] = {
        label           = 'Ice Cream Truck',
        servingPosition = vector3(0.0, -1.5, 0.5),
        servingHeading  = -90.0,
        -- Bones used for the ox_target "Start Working" interaction zone.
        targetBones     = { 'door_dside_r', 'door_pside_r' },
        -- Vehicle door index to open when working (nil = don't open any door).
        servingDoor     = nil,
        -- How far to offset the player on exit.
        -- sideOffset: negative = toward vehicle centre (left/right fine-tune)
        -- backOffset: positive = toward rear of vehicle
        exitOffset      = { side = -0.5, back = 2.5 },
        items = {
            {
                id          = 'icecream',
                label       = 'Ice Cream',
                price       = 50,
                craftTime   = 3000,  -- ms
                ingredients = {
                    { item = 'milk', amount = 1 },
                    { item = 'ice',  amount = 2 },
                },
                output = { item = 'icecream', amount = 1 },
            },
        },
    },
    ['taco'] = {
        label           = 'Taco Truck',
        servingPosition = vector3(0.0, -1.0, 0.5),
        servingHeading  = -90.0,
        -- Bones used for the ox_target "Start Working" interaction zone.
        targetBones     = { 'door_dside_r', 'door_pside_r' },
        -- Vehicle door index to open when working.
        -- 5 = trunk/boot — the taco truck's serving window cover.
        servingDoor     = 5,
        exitOffset      = { side = -0.5, back = 2 },
        items = {
            {
                id          = 'taco',
                label       = 'Taco',
                price       = 75,
                craftTime   = 4000,
                ingredients = {
                    { item = 'tortilla', amount = 1 },
                    { item = 'meat',     amount = 1 },
                },
                output = { item = 'taco', amount = 1 },
            },
        },
    },
}

-- ─── Serving tray stash ───────────────────────────────────────────────────────
Config.TraySlots  = 10
Config.TrayWeight = 30000

-- ─── NPC selling ─────────────────────────────────────────────────────────────
Config.NPCSelling = {
    radius              = 15.0,
    interval            = 10000,   -- ms between customer waves
    randomAttackChance  = 0.05,
    meleeWeaponChance   = 0.3,
    meleeWeapons        = { 'WEAPON_BAT', 'WEAPON_KNIFE', 'WEAPON_BOTTLE', 'WEAPON_CROWBAR' },
}

-- ─── Job gate (optional) ─────────────────────────────────────────────────────
Config.RequireJob  = false
Config.AllowedJobs = { 'foodvendor' }

Config.Debug = false

-- ─── Helpers ─────────────────────────────────────────────────────────────────
function Config.GetTruck(modelHash)
    modelHash = type(modelHash) == 'string' and GetHashKey(modelHash) or modelHash
    for model, cfg in pairs(Config.Trucks) do
        if GetHashKey(model) == modelHash then return model, cfg end
    end
    return nil, nil
end

function Config.GetItemPrice(itemId)
    for _, cfg in pairs(Config.Trucks) do
        for _, item in ipairs(cfg.items) do
            if item.id == itemId then return item.price end
        end
    end
    return 50
end
