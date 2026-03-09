# fish_foodtruck

A food truck resource for FiveM built on the ox stack (ox_core, ox_inventory, ox_target, ox_lib).

A player enters a registered food truck and is attached to the serving spot as a worker. They can craft items onto a per-truck serving tray stash, then toggle NPC selling to have pedestrians approach and purchase from the tray. Sale proceeds go into the tray stash. The worker exits cleanly via the door bone they entered from.

## Dependencies

- [ox_core](https://github.com/overextended/ox_core)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_target](https://github.com/overextended/ox_target)
- [ox_lib](https://github.com/overextended/ox_lib)

## Setup

1. Add the resource to your `server.cfg`:
   ```
   ensure fish_foodtruck
   ```
2. Add the items you intend to sell and their ingredients to your `ox_inventory` items list.
3. Register your truck models in `config.lua` (see [Configuration](#configuration)).

## Configuration

All configuration lives in `config.lua`.

### Truck definitions — `Config.Trucks`

Each key is the **vehicle model name** (lowercase). Example:

```lua
['taco'] = {
    label           = 'Taco Truck',
    servingPosition = vector3(0.0, -1.0, 0.5), -- attachment offset relative to vehicle
    servingHeading  = -90.0,                    -- worker yaw relative to vehicle
    targetBones     = { 'door_dside_r', 'door_pside_r' }, -- ox_target interaction bones
    servingDoor     = 5,    -- vehicle door index to open while working (nil = none)
    exitOffset      = { side = -0.5, back = 2.0 }, -- fine-tune exit position per model
    items = {
        {
            id          = 'taco',
            label       = 'Taco',
            price       = 75,
            craftTime   = 4000, -- ms
            ingredients = {
                { item = 'tortilla', amount = 1 },
                { item = 'meat',     amount = 1 },
            },
            output = { item = 'taco', amount = 1 },
        },
    },
}
```

**`exitOffset`** controls where the player is placed when they stop working. `side` adjusts left/right relative to the door bone; `back` adjusts how far rearward along the vehicle. Tune per model to avoid clipping.

### Serving tray

```lua
Config.TraySlots  = 10     -- inventory slots on the tray stash
Config.TrayWeight = 30000  -- max weight
```

The tray stash is identified as `fishFoodTruck_tray_<PLATE>` and is accessible to the worker via the in-game menu.

### NPC selling — `Config.NPCSelling`

```lua
Config.NPCSelling = {
    radius             = 15.0,   -- distance NPCs are spawned from the truck
    interval           = 10000,  -- ms between customer waves
    randomAttackChance = 0.05,   -- chance (0–1) a customer turns hostile instead of buying
    meleeWeaponChance  = 0.3,    -- chance the hostile NPC uses a melee weapon
    meleeWeapons       = { 'WEAPON_BAT', 'WEAPON_KNIFE', ... },
}
```

### Job gate (optional)

```lua
Config.RequireJob  = true
Config.AllowedJobs = { 'foodvendor' }
```

Set `RequireJob = false` to allow anyone to use any registered truck.

## Usage

1. Approach a registered food truck and use the **ox_target** interaction on the door to start working.
2. The worker is attached to the serving spot. Press **F5** to open the menu.
3. From the menu:
   - **Craft** — produce food items from ingredients in your inventory onto the serving tray.
   - **Serving Tray** — inspect or manage the tray stash directly.
   - **Start/Stop Selling to Locals** — toggle NPC customer waves. NPCs approach, buy a random item from the tray, and the sale price is deposited into the tray stash as cash.
4. Press **F** or select **Stop Working** from the menu to exit the truck.
