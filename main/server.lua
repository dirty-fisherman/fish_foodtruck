-- Main server entry point

-- Track which players are working in which vehicles
local activeWorkers = {} -- [plate] = source

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print('[fish_foodtruck] Resource started successfully')
end)

-- Event to check if a vehicle is available for work
RegisterNetEvent('fish_foodtruck:requestWorkStart', function(plate)
    local source = source
    plate = plate:gsub("%s+", "")
    
    -- Check job requirement if enabled
    if Config.RequireJob then
        local player = Ox.GetPlayer(source)
        if not player then
            TriggerClientEvent('fish_foodtruck:workDeniedJob', source, 'Unable to verify player data')
            return
        end
        
        local hasJob = false
        for _, allowedJob in ipairs(Config.AllowedJobs) do
            if player.charId and player.getGroup(allowedJob) then
                hasJob = true
                break
            end
        end
        
        if not hasJob then
            TriggerClientEvent('fish_foodtruck:workDeniedJob', source, 'You need to be a food vendor to work here')
            return
        end
    end
    
    -- Check if someone else is already working in this vehicle
    if activeWorkers[plate] then
        local workingPlayer = activeWorkers[plate]
        -- Check if that player is still connected
        if GetPlayerPing(workingPlayer) > 0 then
            TriggerClientEvent('fish_foodtruck:workDenied', source)
            return
        else
            -- Clean up stale entry
            activeWorkers[plate] = nil
        end
    end
    
    -- Allow this player to work
    activeWorkers[plate] = source
    TriggerClientEvent('fish_foodtruck:workApproved', source)
end)

-- Event when player stops working
RegisterNetEvent('fish_foodtruck:stopWork', function(plate)
    local source = source
    plate = plate:gsub("%s+", "")
    
    if activeWorkers[plate] == source then
        activeWorkers[plate] = nil
    end
end)

-- Clean up when player disconnects
AddEventHandler('playerDropped', function(reason)
    local source = source
    for plate, workerId in pairs(activeWorkers) do
        if workerId == source then
            activeWorkers[plate] = nil
        end
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Clear all active workers
    activeWorkers = {}
end)
