-- Main server entry — worker registry, work request/stop, serving tray.

-- source -> vehicleNetId  (global so server/crafting.lua and server/npc.lua can read it)
workerVehicle = {}

local function sanitizePlate(plate)
    return plate:gsub('%s+', '')
end

local function trayStashId(plate)
    return 'fishFoodTruck_tray_' .. sanitizePlate(plate)
end

local function ensureTray(plate)
    local id = trayStashId(plate)
    exports.ox_inventory:RegisterStash(id, 'Serving Tray', Config.TraySlots, Config.TrayWeight, false)
    return id
end

-- ─── Request to work ─────────────────────────────────────────────────────────
RegisterNetEvent('fishFoodTruck:requestWork', function(vehicleNetId, plate)
    local source  = source
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    if not DoesEntityExist(vehicle) then
        TriggerClientEvent('fishFoodTruck:workDenied', source, 'Vehicle not found.')
        return
    end

    -- Job gate
    if Config.RequireJob then
        local player = exports.ox_core:GetPlayer(source)
        if not player then
            TriggerClientEvent('fishFoodTruck:workDenied', source, 'Unable to verify your character.')
            return
        end
        local allowed = false
        for _, job in ipairs(Config.AllowedJobs) do
            if player:getGroup(job) then allowed = true; break end
        end
        if not allowed then
            TriggerClientEvent('fishFoodTruck:workDenied', source, 'You need the food vendor job.')
            return
        end
    end

    -- Already has an active worker? Cross-reference the workerVehicle table so a
    -- stale statebag from a crash/disconnect can't permanently lock the truck.
    local existingWorker = Entity(vehicle).state.fishFoodTruckWorker
    if existingWorker and existingWorker ~= source
       and workerVehicle[existingWorker] ~= nil then
        TriggerClientEvent('fishFoodTruck:workDenied', source, 'Someone is already working in this truck.')
        return
    end

    local truckKey, _ = Config.GetTruck(GetEntityModel(vehicle))
    if not truckKey then
        TriggerClientEvent('fishFoodTruck:workDenied', source, 'This is not a registered food truck.')
        return
    end

    plate = sanitizePlate(plate)
    Entity(vehicle).state:set('fishFoodTruckWorker', source, true)
    Player(source).state:set('fishFoodTruckWorking', true, true)
    workerVehicle[source] = vehicleNetId
    ensureTray(plate)

    TriggerClientEvent('fishFoodTruck:workApproved', source, vehicleNetId, plate, truckKey)
end)

-- ─── Stop work ───────────────────────────────────────────────────────────────
RegisterNetEvent('fishFoodTruck:stopWork', function(vehicleNetId)
    local source  = source
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if DoesEntityExist(vehicle) then
        Entity(vehicle).state:set('fishFoodTruckWorker', nil, true)
    end
    Player(source).state:set('fishFoodTruckWorking', false, true)
    workerVehicle[source] = nil
end)

-- ─── Serving tray (worker opens their own tray to stock it) ──────────────────
RegisterNetEvent('fishFoodTruck:openTray', function(plate)
    local source = source
    plate = sanitizePlate(plate)
    local id = ensureTray(plate)
    exports.ox_inventory:forceOpenInventory(source, 'stash', id)
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local source = source
    local vid    = workerVehicle[source]
    if vid then
        local v = NetworkGetEntityFromNetworkId(vid)
        if DoesEntityExist(v) then
            Entity(v).state:set('fishFoodTruckWorker', nil, true)
        end
        Player(source).state:set('fishFoodTruckWorking', false, true)
        workerVehicle[source] = nil
    end
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    for src, vid in pairs(workerVehicle) do
        local v = NetworkGetEntityFromNetworkId(vid)
        if DoesEntityExist(v) then
            Entity(v).state:set('fishFoodTruckWorker', nil, true)
        end
        Player(src).state:set('fishFoodTruckWorking', false, true)
    end
    workerVehicle = {}
end)
