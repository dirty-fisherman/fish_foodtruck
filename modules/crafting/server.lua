-- Crafting module - Server side

-- Event to craft items
RegisterNetEvent('fish_foodtruck:craftItem', function(plate, recipeId, truckType)
    local source = source
    
    -- Get player ped
    local playerPed = GetPlayerPed(source)
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    
    -- Verify player is in a vehicle
    if not playerVehicle or playerVehicle == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Food Truck',
            description = 'You need to be in a food truck!',
            type = 'error'
        })
        return
    end
    
    -- Get truck config
    local truckConfig = Config.TruckTypes[truckType]
    if not truckConfig then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Food Truck',
            description = 'Invalid truck type!',
            type = 'error'
        })
        return
    end
    
    -- Find the recipe
    local recipe = nil
    for _, r in ipairs(truckConfig.recipes) do
        if r.id == recipeId then
            recipe = r
            break
        end
    end
    
    if not recipe then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Food Truck',
            description = 'Invalid recipe!',
            type = 'error'
        })
        return
    end
    
    -- Trim plate to remove whitespace and get the actual plate from the vehicle
    local actualPlate = GetVehicleNumberPlateText(playerVehicle):gsub("%s+", "")
    
    -- Construct glovebox inventory ID (format: 'glove' + plate)
    local gloveboxId = 'glove' .. actualPlate
    
    -- Count available ingredients using Search on glovebox
    local availableIngredients = {}
    for _, ingredient in ipairs(recipe.ingredients) do
        local count = exports.ox_inventory:Search(gloveboxId, 'count', ingredient.item)
        availableIngredients[ingredient.item] = count or 0
    end
    
    -- Check if player has enough ingredients
    local hasIngredients = true
    local missingItems = {}
    
    for _, ingredient in ipairs(recipe.ingredients) do
        if availableIngredients[ingredient.item] < ingredient.amount then
            hasIngredients = false
            table.insert(missingItems, string.format('%dx %s', ingredient.amount, ingredient.item))
        end
    end
    
    if not hasIngredients then
        TriggerClientEvent('ox_lib:notify', source, {
            title = truckConfig.label,
            description = 'Missing ingredients: ' .. table.concat(missingItems, ', '),
            type = 'error'
        })
        -- Reopen crafting menu so player can try another recipe
        TriggerClientEvent('fish_foodtruck:reopenCraftingMenu', source)
        return
    end
    
    -- Start crafting with progress bar
    local progressCompleted = lib.callback.await('fish_foodtruck:clientProgressBar', source, recipe.craftTime, 'Making ' .. recipe.label .. '...')
    
    if progressCompleted then
        -- Remove ingredients from glovebox
        local removed = true
        
        for _, ingredient in ipairs(recipe.ingredients) do
            local success = exports.ox_inventory:RemoveItem(gloveboxId, ingredient.item, ingredient.amount)
            if not success then
                removed = false
                break
            end
        end
        
        if removed then
            -- Add output to player inventory
            local added = exports.ox_inventory:AddItem(source, recipe.output.item, recipe.output.amount)
            
            if added then
                TriggerClientEvent('ox_lib:notify', source, {
                    title = truckConfig.label,
                    description = 'Successfully made ' .. recipe.label .. '!',
                    type = 'success'
                })
                -- Reopen crafting menu
                TriggerClientEvent('fish_foodtruck:reopenCraftingMenu', source)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = truckConfig.label,
                    description = 'Failed to add item - inventory full?',
                    type = 'error'
                })
                -- Reopen crafting menu even on failure
                TriggerClientEvent('fish_foodtruck:reopenCraftingMenu', source)
            end
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = truckConfig.label,
                description = 'Failed to remove ingredients!',
                type = 'error'
            })
            -- Reopen crafting menu
            TriggerClientEvent('fish_foodtruck:reopenCraftingMenu', source)
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = truckConfig.label,
            description = 'Crafting cancelled!',
            type = 'error'
        })
        -- Reopen crafting menu after cancellation
        TriggerClientEvent('fish_foodtruck:reopenCraftingMenu', source)
    end
end)
