-- NPC purchase handler.
-- workerVehicle is declared global in server/main.lua.

RegisterNetEvent('fishFoodTruck:npcPurchase', function(npcNetId)
    local source = source

    local vid = workerVehicle[source]
    if not vid then
        TriggerClientEvent('fishFoodTruck:npcPurchaseResult', source, npcNetId, false)
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(vid)
    if not DoesEntityExist(vehicle) then
        TriggerClientEvent('fishFoodTruck:npcPurchaseResult', source, npcNetId, false)
        return
    end

    local _, cfg = Config.GetTruck(GetEntityModel(vehicle))
    if not cfg then
        TriggerClientEvent('fishFoodTruck:npcPurchaseResult', source, npcNetId, false)
        return
    end

    local plate       = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local trayStashId = 'fishFoodTruck_tray_' .. plate

    -- Find items currently in stock on the serving tray
    local available = {}
    for _, item in ipairs(cfg.items) do
        if exports.ox_inventory:GetItemCount(trayStashId, item.id) > 0 then
            available[#available + 1] = item
        end
    end

    if #available == 0 then
        TriggerClientEvent('ox_lib:notify', source, { title = 'Food Truck', description = 'No stock on the serving tray!', type = 'error' })
        TriggerClientEvent('fishFoodTruck:npcPurchaseResult', source, npcNetId, false)
        return
    end

    local pick    = available[math.random(#available)]
    local removed = exports.ox_inventory:RemoveItem(trayStashId, pick.id, 1)

    if removed then
        exports.ox_inventory:AddItem(trayStashId, 'money', pick.price)
        TriggerClientEvent('ox_lib:notify', source, {
            title       = 'Food Truck',
            description = 'Sold ' .. pick.label .. ' for $' .. pick.price,
            type        = 'success',
        })
        TriggerClientEvent('fishFoodTruck:npcPurchaseResult', source, npcNetId, true)
    else
        TriggerClientEvent('fishFoodTruck:npcPurchaseResult', source, npcNetId, false)
    end
end)
