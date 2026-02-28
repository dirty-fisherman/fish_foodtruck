-- NPC selling module - Server side

-- Event to handle NPC purchase
RegisterNetEvent('fish_foodtruck:npcPurchase', function(npcNetId)
    local source = source

    -- Derive plate and truck type server-side
    local playerPed = GetPlayerPed(source)
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    if not playerVehicle or playerVehicle == 0 then
        TriggerClientEvent('fish_foodtruck:npcPurchaseResult', source, npcNetId, false)
        return
    end

    local plate = GetVehicleNumberPlateText(playerVehicle):gsub("%s+", "")
    local truckType, truckConfig = Config.GetTruckType(GetEntityModel(playerVehicle))
    if not truckConfig then
        TriggerClientEvent('fish_foodtruck:npcPurchaseResult', source, npcNetId, false)
        return
    end

    -- Get serving stash ID (already registered at work start)
    local servingStashId = GetServingStashId(plate)
    
    -- Build list of items that are both craftable by this truck AND in stock
    local availableItems = {}
    for _, recipe in ipairs(truckConfig.recipes) do
        local itemName = recipe.output.item
        if exports.ox_inventory:GetItemCount(servingStashId, itemName) > 0 then
            table.insert(availableItems, itemName)
        end
    end
    
    -- If no items available, fail the purchase
    if #availableItems == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Food Truck',
            description = 'You have run out of stock!',
            type = 'error'
        })
        TriggerClientEvent('fish_foodtruck:npcPurchaseResult', source, npcNetId, false)
        return
    end
    
    -- Pick a random item from available stock
    local itemToSell = availableItems[math.random(#availableItems)]
    
    -- Remove one item
    local removed = exports.ox_inventory:RemoveItem(servingStashId, itemToSell, 1)
    
    if removed then
        -- Get price for this item from recipe config
        local price = Config.GetItemPrice(itemToSell)
        
        -- Give player money
        exports.ox_inventory:AddItem(source, 'money', price)
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Food Truck',
            description = 'Sold ' .. itemToSell .. ' to local for $' .. price,
            type = 'success'
        })
        
        -- Tell client purchase was successful
        TriggerClientEvent('fish_foodtruck:npcPurchaseResult', source, npcNetId, true)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Food Truck',
            description = 'Failed to remove item from stash',
            type = 'error'
        })
        TriggerClientEvent('fish_foodtruck:npcPurchaseResult', source, npcNetId, false)
    end
end)

-- Debug command to spawn a customer NPC (ACE restricted: command.spawncustomer)
if Config.Debug then
    RegisterCommand('spawncustomer', function(source)
        TriggerClientEvent('fish_foodtruck:spawnDebugCustomer', source)
    end, true)
end
