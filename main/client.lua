-- Main client entry point

-- Function to actually start working (called after server approval)
local function StartWorking(vehicle, truckType, truckConfig, plate)
    State.isWorking = true
    State.currentVehicle = vehicle
    State.currentPlate = plate
    State.currentTruckType = truckType
    State.currentTruckConfig = truckConfig
    
    -- Turn off the engine
    SetVehicleEngineOn(vehicle, false, true, true)
    
    -- Turn on interior lights
    SetVehicleInteriorlight(vehicle, true)
    
    -- If taco truck, open the trunk (serving hatch)
    if truckType == 'taco' then
        SetVehicleDoorOpen(vehicle, 5, false, false) -- 5 is the trunk door
    end
    
    -- Create serving ped clone
    CreateServingPed()
    
    lib.notify({
        title = truckConfig.label,
        description = 'You started working! Use /' .. Config.WorkCommand .. ' to access the menu',
        type = 'success'
    })
    OpenCraftingMenu()
end

-- Server approved work request
RegisterNetEvent('fish_foodtruck:workApproved', function()
    if State.pendingWork then
        StartWorking(State.pendingWork.vehicle, State.pendingWork.truckType, State.pendingWork.truckConfig, State.pendingWork.plate)
        State.pendingWork = nil
    end
end)

-- Server denied work request
RegisterNetEvent('fish_foodtruck:workDenied', function()
    lib.notify({
        title = 'Food Truck',
        description = 'Someone else is already working in this vehicle!',
        type = 'error'
    })
    State.pendingWork = nil
end)

-- Server denied work request due to job
RegisterNetEvent('fish_foodtruck:workDeniedJob', function(reason)
    lib.notify({
        title = 'Food Truck',
        description = reason or 'You do not have the required job',
        type = 'error'
    })
    State.pendingWork = nil
end)

-- Command to start working
RegisterCommand(Config.WorkCommand, function()
    local inTruck, vehicle, truckType, truckConfig = IsInFoodTruck()
    
    if not inTruck then
        lib.notify({
            title = 'Food Truck',
            description = 'You need to be inside a food truck!',
            type = 'error'
        })
        return
    end

    if State.isWorking then
        -- Already working, open menu
        OpenCraftingMenu()
    else
        -- Request permission from server
        local plate = GetVehicleNumberPlateText(vehicle)
        State.pendingWork = {
            vehicle = vehicle,
            truckType = truckType,
            truckConfig = truckConfig,
            plate = plate
        }
        TriggerServerEvent('fish_foodtruck:requestWorkStart', plate)
    end
end, false)

-- Detect vehicle exit button press
CreateThread(function()
    while true do
        Wait(0)
        
        if State.isWorking then
            -- Control 75 is the vehicle exit key (F by default)
            if IsControlJustPressed(0, 75) then
                ResetWorkingState()
                lib.notify({
                    title = 'Food Truck',
                    description = 'You stopped working',
                    type = 'info'
                })
            end
        else
            Wait(500) -- Sleep when not working
        end
    end
end)

-- Event-driven: Player death
AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim = data[1]
        if victim == cache.ped and IsEntityDead(victim) and State.isWorking then
            ResetWorkingState()
        end
    end
end)

-- Monitor for theft, ragdoll, and vehicle movement (these need polling)
CreateThread(function()
    while true do
        Wait(State.isWorking and 500 or 2000) -- Check every half second when working
        
        if State.isWorking then
            local playerPed = cache.ped
            
            -- Check current vehicle - catch if somehow we're not in it anymore
            local currentVeh = GetVehiclePedIsIn(playerPed, false)
            if currentVeh ~= State.currentVehicle then
                ResetWorkingState()
            end
            
            -- Check if player is being dragged out or in ragdoll
            if IsPedRagdoll(playerPed) or IsPedBeingJacked(playerPed) or IsPedGettingUp(playerPed) then
                ResetWorkingState()
                lib.notify({
                    title = 'Food Truck',
                    description = 'You stopped working',
                    type = 'info'
                })
            end
            
            -- Check if vehicle was stolen (someone else in driver seat)
            if State.currentVehicle and DoesEntityExist(State.currentVehicle) then
                local driverSeat = GetPedInVehicleSeat(State.currentVehicle, -1)
                if driverSeat ~= 0 and driverSeat ~= playerPed then
                    ResetWorkingState()
                    lib.notify({
                        title = 'Food Truck',
                        description = 'Someone stole your truck!',
                        type = 'error'
                    })
                end
            end
        end
    end
end)
-- Prevent driving while working
CreateThread(function()
    while true do
        if State.isWorking and State.currentVehicle and DoesEntityExist(State.currentVehicle) then
            -- Disable vehicle controls while working (must be called every frame)
            DisableControlAction(0, 71, true)  -- Accelerate (W)
            DisableControlAction(0, 72, true)  -- Brake/Reverse (S)
            DisableControlAction(0, 63, true)  -- Steer Left (analog)
            DisableControlAction(0, 64, true)  -- Steer Right (analog)
            DisableControlAction(0, 34, true)  -- Move Left (A key)
            DisableControlAction(0, 35, true)  -- Move Right (D key)
            DisableControlAction(0, 59, true)  -- Steer Left (keyboard)
            DisableControlAction(0, 60, true)  -- Steer Right (keyboard)
            Wait(0) -- Must run every frame for controls to stay disabled
        else
            Wait(500) -- Less frequent checks when not working
        end
    end
end)

-- Monitor engine state while working (can be slower)
CreateThread(function()
    while true do
        if State.isWorking and State.currentVehicle and DoesEntityExist(State.currentVehicle) then
            -- Force engine off if someone tries to start it
            if GetIsVehicleEngineRunning(State.currentVehicle) then
                SetVehicleEngineOn(State.currentVehicle, false, true, true)
            end
            Wait(100) -- Check engine every 100ms
        else
            Wait(500)
        end
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Force cleanup of serving ped
    if State.servingPed and DoesEntityExist(State.servingPed) then
        DeleteEntity(State.servingPed)
    end
    
    -- Make player visible again
    local playerPed = cache.ped
    if playerPed then
        SetEntityAlpha(playerPed, 255, false)
    end
    
    -- Notify server we're stopping work
    if State.currentPlate then
        TriggerServerEvent('fish_foodtruck:stopWork', State.currentPlate)
    end
end)

-- Extra safety: cleanup on player death (redundant but harmless fallback)
CreateThread(function()
    while true do
        Wait(2000) -- Only every 2 seconds as event handler is primary
        
        local playerPed = cache.ped
        if playerPed and IsEntityDead(playerPed) and State.isWorking then
            ResetWorkingState()
        end
    end
end)