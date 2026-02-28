-- Client state
State = {
    isWorking = false,
    currentVehicle = nil,
    currentPlate = nil,
    currentTruckType = nil,
    currentTruckConfig = nil,
    sellingToNPCs = false,
    npcApproaching = false,
    servingPed = nil, -- Cloned ped in serving position
    originalSeat = -1, -- Seat player was in before working
    pendingWork = nil -- Pending work request data
}

-- Function to check if player is in a food truck
function IsInFoodTruck()
    local ped = cache.ped
    local vehicle = cache.vehicle
    
    if vehicle then
        local model = GetEntityModel(vehicle)
        local truckType, truckConfig = Config.GetTruckType(model)
        
        if truckType then
            return true, vehicle, truckType, truckConfig
        end
    end
    
    return false, nil, nil, nil
end

-- Function to reset working state
function ResetWorkingState()
    -- Notify server we're stopping work; pass the vehicle netId so the server can clear its entity statebag
    if State.currentVehicle and DoesEntityExist(State.currentVehicle) then
        TriggerServerEvent('fish_foodtruck:stopWork', VehToNet(State.currentVehicle))
    end
    
    -- Clean up serving ped
    CleanupServingPed()
    
    -- Turn off interior lights and close trunk if vehicle still exists
    if State.currentVehicle and DoesEntityExist(State.currentVehicle) then
        SetVehicleInteriorlight(State.currentVehicle, false)
        
        if State.currentTruckType == 'taco' then
            SetVehicleDoorShut(State.currentVehicle, 5, false) -- 5 is the trunk door
        end
    end
    
    State.isWorking = false
    State.sellingToNPCs = false
    State.currentVehicle = nil
    State.currentPlate = nil
    State.currentTruckType = nil
    State.currentTruckConfig = nil
    State.npcApproaching = false
    State.originalSeat = -1
end

