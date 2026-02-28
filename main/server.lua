-- Main server entry point

-- Reverse lookup: source -> vehicleNetId, used for cleanup on disconnect
local workerVehicle = {}

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    print('[fish_foodtruck] Resource started successfully')
end)

-- Event to check if a vehicle is available for work
-- vehicleNetId is passed by the client so we can scope state to the entity
RegisterNetEvent('fish_foodtruck:requestWorkStart', function(plate, vehicleNetId)
    local source = source

    -- Check job requirement if enabled
    if Config.RequireJob then
        local player = Ox.GetPlayer(source)
        if not player then
            TriggerClientEvent('fish_foodtruck:workDeniedJob', source, 'Unable to verify player data')
            return
        end

        local hasJob = false
        for _, allowedJob in ipairs(Config.AllowedJobs) do
            if player.charId and player:getGroup(allowedJob) then
                hasJob = true
                break
            end
        end

        if not hasJob then
            TriggerClientEvent('fish_foodtruck:workDeniedJob', source, 'You need to be a food vendor to work here')
            return
        end
    end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then
        TriggerClientEvent('fish_foodtruck:workDenied', source)
        return
    end

    -- Check entity statebag instead of a manual plate table
    local existingWorker = Entity(vehicle).state.foodtruckWorker
    if existingWorker and existingWorker ~= source then
        if GetPlayerName(existingWorker) ~= nil then
            TriggerClientEvent('fish_foodtruck:workDenied', source)
            return
        end
        -- Stale entry - fall through and let this player take over
    end

    -- Scope working state to the vehicle entity (replicated = true so clients can read it)
    Entity(vehicle).state:set('foodtruckWorker', source, true)
    -- Let other resources know this player is working a food truck
    Player(source).state:set('foodtruckWorking', true, true)

    -- Pre-register serving stash so it's ready before any NPC sales or stash opens
    GetOrCreateServingStash(plate)

    workerVehicle[source] = vehicleNetId
    TriggerClientEvent('fish_foodtruck:workApproved', source)
end)

-- Event when player stops working
RegisterNetEvent('fish_foodtruck:stopWork', function(vehicleNetId)
    local source = source
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    if DoesEntityExist(vehicle) then
        Entity(vehicle).state:set('foodtruckWorker', nil, true)
    end

    Player(source).state:set('foodtruckWorking', false, true)
    workerVehicle[source] = nil
end)

-- baseevents fires this server-side when any player leaves a vehicle
-- Handles statebag cleanup only; client-side ped/state cleanup is driven by cache:vehicle and the monitor thread
AddEventHandler('baseevents:leftVehicle', function()
    local source = source
    if not workerVehicle[source] then return end

    local vehicleNetId = workerVehicle[source]
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    if DoesEntityExist(vehicle) then
        Entity(vehicle).state:set('foodtruckWorker', nil, true)
    end

    Player(source).state:set('foodtruckWorking', false, true)
    workerVehicle[source] = nil
end)

-- Clean up when player disconnects
AddEventHandler('playerDropped', function()
    local source = source
    local vehicleNetId = workerVehicle[source]

    if vehicleNetId then
        local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
        if DoesEntityExist(vehicle) then
            Entity(vehicle).state:set('foodtruckWorker', nil, true)
        end
        Player(source).state:set('foodtruckWorking', false, true)
        workerVehicle[source] = nil
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for source, vehicleNetId in pairs(workerVehicle) do
        local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
        if DoesEntityExist(vehicle) then
            Entity(vehicle).state:set('foodtruckWorker', nil, true)
        end
        Player(source).state:set('foodtruckWorking', false, true)
    end
    workerVehicle = {}
end)
