# Fish Food Truck - FiveM Resource

A fully-featured configurable food truck resource for FiveM servers using the ox framework. Supports multiple truck types with unique recipes!

## Features

- 🚚 Work from multiple food truck types (Ice Cream, Tacos, and more!)
- 🍽️ Multiple recipes per truck type
- 📦 Serve customers from a dedicated serving stash
- 🤖 Automatic NPC sales system with AI behavior
- 💰 Get paid for each item sold (different prices per item)
- ⚔️ Angry NPCs may attack if you're out of stock!

## Code Structure

The resource uses a modular architecture where each feature has its client and server code together:

### Modules (modules/)
- **crafting/** - Food crafting system
  - `client.lua` - Dynamic crafting menu based on truck type and progress bar
  - `server.lua` - Recipe validation and ingredient processing
  
- **serving/** - Serving stash interactions
  - `client.lua` - ox_target setup for all truck types
  - `server.lua` - Inventory management for serving stash
  
- **npc/** - NPC selling system
  - `client.lua` - NPC AI behavior, approach logic, attack system
  - `server.lua` - Purchase processing and payment handling (supports all items)

### Core
- **main/** - Core functionality
  - `client.lua` - Work command and state monitoring
  - `server.lua` - Resource initialization

### Shared
- **shared/state.lua** - Client state management (`State` table)
- **shared/utils.lua** - Server utilities (stash creation)
- **config.lua** - All configuration settings
- **items.lua** - Item definitions (copy these to ox_inventory)

## Requirements

- ox_target
- ox_inventory
- ox_core
- ox_lib

## Installation

1. Place the `fish_foodtruck` folder in your resources directory
2. Add `ensure fish_foodtruck` to your server.cfg
3. Add the items from [items.lua](items.lua) to your `ox_inventory/data/items.lua` file
4. Restart your server

**Important:** You need to manually add all item definitions from the `items.lua` file to your ox_inventory items file for the resource to work properly.

## Supported Truck Types

### Ice Cream Truck (mrtasty)
- **Ice Cream** - 1x Milk, 2x Ice → 1x Ice Cream (3s, sells for $50)

### Taco Truck (taco)
- **Taco** - 1x Tortilla, 1x Meat, 1x Cheese → 1x Taco (4s, sells for $75)
- **Burrito** - 2x Tortilla, 2x Meat, 1x Cheese, 1x Rice → 1x Burrito (5s, sells for $100)

## Usage

### For Workers
1. Get inside a supported food truck (mrtasty or taco)
2. Type `/foodtruck` to start working
3. Menu options:
   - **Recipe options** - Dynamic menu showing all recipes for your truck type
   - **Start/Stop Selling to NPCs** - Toggle automatic NPC sales
   - **Open Serving Stash** - Manage inventory for customers
   - **Stop Working** - Exit working mode
4. Stock the glovebox with ingredients for your recipes
5. Craft food items - they go directly to player inventory
6. Place finished items in serving stash (accessible from menu)
7. Enable NPC selling to earn passive income

### For Customers
- Walk up to any supported food truck
- Use ox_target to open the serving window
- Purchase food from the serving stash

### NPC Selling System
- NPCs within 30m will randomly approach your truck
- They greet you, walk to the vehicle, and purchase a random item
- Different items have different prices (ice cream $50, taco $75, burrito $100)
- If out of stock, NPCs insult you and may attack (30% chance)
- Selling stops automatically when vehicle moves

## Configuration

Edit `config.lua` to customize or add new truck types:

### Adding a New Food Truck
```lua
Config.TruckTypes['vehicle_model'] = {
    label = 'Display Name',
    recipes = {
        {
            id = 'output_item',
            label = 'Recipe Name',
            description = 'Requires: ...',
            ingredients = {
                { item = 'ingredient1', amount = 1 },
                { item = 'ingredient2', amount = 2 }
            },
            output = {
                item = 'output_item',
                amount = 1
            },
            craftTime = 4000
        }
    }
}
```

Then add item definitions to `items.lua`, copy them to your ox_inventory items file, and add prices to `Config.NPCSelling.prices`.

### General Settings
- Serving stash size and weight
- Command name (default: `/foodtruck`)
- NPC selling radius (default: 30m)
- NPC selling interval (default: 30 seconds)
- Per-item sale prices
- Attack chance when out of stock (default: 30%)

## Notes

- Each vehicle has its own serving stash (based on license plate)
- Working mode stops automatically when exiting vehicle
- Ingredients must be in the glovebox (not trunk)
- Crafted ice cream goes to player inventory
- NPCs use ambient speech (greetings, thanks, insults)
- Attacking NPCs may spawn with melee weapons
## Debug Commands

### `/spawncustomer`
Spawns a random NPC customer that will approach your food truck and attempt to purchase an item. Useful for testing the NPC selling system without waiting for random NPCs.

**Usage:**
1. Start working in your food truck (`/foodtruck`)
2. Type `/spawncustomer` to spawn a test customer
3. The NPC will walk to your truck and try to buy something