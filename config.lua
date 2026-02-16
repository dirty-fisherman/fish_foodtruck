Config = {}

-- Food truck types configuration
Config.TruckTypes = {
    ['mrtasty'] = {
        label = 'Ice Cream Truck',
        servingPosition = vector3(0.0, -1.5, 0.5), -- Offset from vehicle center
        servingHeading = -90.0, -- Relative to vehicle
        recipes = {
            {
                id = 'icecream',
                label = 'Ice Cream',
                description = 'Requires: 1x Milk, 2x Ice',
                ingredients = {
                    { item = 'milk', amount = 1 },
                    { item = 'ice', amount = 2 }
                },
                output = {
                    item = 'icecream',
                    amount = 1
                },
                craftTime = 3000,
                price = 50
            }
        }
    },
    ['taco'] = {
        label = 'Taco Truck',
        servingPosition = vector3(0.0, -1.0, 0.5), -- Offset from vehicle center
        servingHeading = -90.0, -- Relative to vehicle
        recipes = {
            {
                id = 'taco',
                label = 'Taco',
                description = 'Requires: 1x Tortilla, 1x Meat, 1x Cheese',
                ingredients = {
                    { item = 'tortilla', amount = 1 },
                    { item = 'meat', amount = 1 },
                    { item = 'cheese', amount = 1 }
                },
                output = {
                    item = 'taco',
                    amount = 1
                },
                craftTime = 4000,
                price = 75
            },
            {
                id = 'burrito',
                label = 'Burrito',
                description = 'Requires: 2x Tortilla, 2x Meat, 1x Cheese, 1x Rice',
                ingredients = {
                    { item = 'tortilla', amount = 2 },
                    { item = 'meat', amount = 2 },
                    { item = 'cheese', amount = 1 },
                    { item = 'rice', amount = 1 }
                },
                output = {
                    item = 'burrito',
                    amount = 1
                },
                craftTime = 5000,
                price = 100
            }
        }
    }
}

-- Serving stash configuration
Config.ServingStash = {
    id = 'foodtruck_serving',
    label = 'Serving Hatch',
    slots = 10,
    weight = 50000,
}

-- Command configuration
Config.WorkCommand = 'foodtruck'

-- Job requirement (set to false to disable job check)
Config.RequireJob = false -- Set to true to require a job
Config.AllowedJobs = {
    'foodvendor'
}

-- Debug mode (enables debug commands)
Config.Debug = true -- Set to true to enable debug commands like /spawncustomer

-- NPC selling configuration
Config.NPCSelling = {
    enabled = true,
    radius = 15.0,
    interval = 30000,
    attackChanceWhenOutOfStock = 1.0,
    randomAttackChance = 0.05, 
}

-- Helper function to get truck type by model
function Config.GetTruckType(vehicleModel)
    local modelHash = type(vehicleModel) == 'string' and GetHashKey(vehicleModel) or vehicleModel
    
    for model, config in pairs(Config.TruckTypes) do
        if GetHashKey(model) == modelHash then
            return model, config
        end
    end
    
    return nil, nil
end

-- Helper function to get item price from recipes
function Config.GetItemPrice(itemName)
    for _, truckConfig in pairs(Config.TruckTypes) do
        for _, recipe in ipairs(truckConfig.recipes) do
            if recipe.output.item == itemName then
                return recipe.price or 50 -- Default price if not set
            end
        end
    end
    return 50 -- Fallback price
end
