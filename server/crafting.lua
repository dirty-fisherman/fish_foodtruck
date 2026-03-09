-- Server-side crafting validation and item transactions.
-- workerVehicle is declared global in server/main.lua.

local inProgress = {}

RegisterNetEvent('fishFoodTruck:craftItem', function(itemId)
    local source = source
    if inProgress[source] then return end
    inProgress[source] = true

    local vid = workerVehicle[source]
    if not vid then
        inProgress[source] = nil
        TriggerClientEvent('ox_lib:notify', source, { title = 'Food Truck', description = 'Not working in a truck!', type = 'error' })
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(vid)
    if not DoesEntityExist(vehicle) then
        inProgress[source] = nil
        TriggerClientEvent('ox_lib:notify', source, { title = 'Food Truck', description = 'Truck not found!', type = 'error' })
        return
    end

    local _, cfg = Config.GetTruck(GetEntityModel(vehicle))
    if not cfg then
        inProgress[source] = nil
        return
    end

    -- Find recipe
    local recipe
    for _, item in ipairs(cfg.items) do
        if item.id == itemId then recipe = item; break end
    end

    if not recipe then
        inProgress[source] = nil
        TriggerClientEvent('ox_lib:notify', source, { title = cfg.label, description = 'Unknown recipe.', type = 'error' })
        return
    end

    -- Check ingredients in player's own inventory
    local missing = {}
    for _, ing in ipairs(recipe.ingredients) do
        local count = exports.ox_inventory:GetItemCount(source, ing.item)
        if count < ing.amount then
            missing[#missing + 1] = ing.amount .. 'x ' .. ing.item
        end
    end

    if #missing > 0 then
        inProgress[source] = nil
        TriggerClientEvent('ox_lib:notify', source, {
            title       = cfg.label,
            description = 'Missing: ' .. table.concat(missing, ', '),
            type        = 'error',
        })
        TriggerClientEvent('fishFoodTruck:reopenMenu', source)
        return
    end

    if not exports.ox_inventory:CanCarryItem(source, recipe.output.item, recipe.output.amount) then
        inProgress[source] = nil
        TriggerClientEvent('ox_lib:notify', source, { title = cfg.label, description = 'Not enough inventory space!', type = 'error' })
        TriggerClientEvent('fishFoodTruck:reopenMenu', source)
        return
    end

    -- Run progress circle on the worker's client; await the result
    local ok = lib.callback.await('fishFoodTruck:progressBar', source, recipe.craftTime, 'Making ' .. recipe.label .. '...')

    if ok then
        local allRemoved = true
        for _, ing in ipairs(recipe.ingredients) do
            if not exports.ox_inventory:RemoveItem(source, ing.item, ing.amount) then
                allRemoved = false
                break
            end
        end

        if allRemoved then
            local added = exports.ox_inventory:AddItem(source, recipe.output.item, recipe.output.amount)
            TriggerClientEvent('ox_lib:notify', source, {
                title       = cfg.label,
                description = added and ('Made ' .. recipe.label .. '!') or 'Failed to add item.',
                type        = added and 'success' or 'error',
            })
        else
            TriggerClientEvent('ox_lib:notify', source, { title = cfg.label, description = 'Failed to remove ingredients.', type = 'error' })
        end
    else
        TriggerClientEvent('ox_lib:notify', source, { title = cfg.label, description = 'Cancelled.', type = 'error' })
    end

    inProgress[source] = nil
    TriggerClientEvent('fishFoodTruck:reopenMenu', source)
end)
