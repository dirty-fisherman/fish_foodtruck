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
local function HandleWorkToggle()
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
end

RegisterCommand(Config.WorkCommand, HandleWorkToggle, false)

-- Event to toggle work (for radial menus like qb-radialmenu)
RegisterNetEvent('fish_foodtruck:toggleWork', HandleWorkToggle)

-- Detect vehicle exit via cache event (covers F key, being dragged out, teleports, etc.)
AddEventHandler('cache:vehicle', function(vehicle)
    if not vehicle and State.isWorking then
        ResetWorkingState()
        lib.notify({
            title = 'Food Truck',
            description = 'You stopped working',
            type = 'info'
        })
    end
end)

-- Event-driven: Player death (baseevents)
AddEventHandler('baseevents:onPlayerDied', function()
    if State.isWorking then
        ResetWorkingState()
    end
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    if State.isWorking then
        ResetWorkingState()
    end
end)

-- Monitor for ragdoll/jacking and theft (vehicle-exit is handled by cache:vehicle event)
CreateThread(function()
    while true do
        Wait(State.isWorking and 500 or 2000)

        if State.isWorking then
            local playerPed = cache.ped

            -- Check if player is being ragdolled or jacked
            if IsPedRagdoll(playerPed) or IsPedBeingJacked(playerPed) then
                ResetWorkingState()
                lib.notify({
                    title = 'Food Truck',
                    description = 'You stopped working',
                    type = 'info'
                })
            -- Check if someone jumped in the driver seat (truck theft)
            elseif State.currentVehicle and DoesEntityExist(State.currentVehicle) then
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

