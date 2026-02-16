-- Shared client state
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
    -- Notify server we're stopping work
    if State.currentPlate then
        TriggerServerEvent('fish_foodtruck:stopWork', State.currentPlate)
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

-- Function to create serving ped clone
function CreateServingPed()
    -- Clean up any existing ped first
    if State.servingPed and DoesEntityExist(State.servingPed) then
        DeleteEntity(State.servingPed)
        State.servingPed = nil
    end
    
    if not State.currentVehicle or not DoesEntityExist(State.currentVehicle) then return end
    if not State.currentTruckConfig.servingPosition then return end
    
    local playerPed = cache.ped
    
    -- Store original seat
    State.originalSeat = GetPedInVehicleSeat(State.currentVehicle, -1) == playerPed and -1 or GetPedVehicleSeat(playerPed)
    
    -- Clone player ped
    local servingPed = ClonePed(playerPed, false, false, true)
    
    -- Disable collision completely
    SetEntityCollision(servingPed, false, false)
    SetEntityCompletelyDisableCollision(servingPed, false, false)
    
    -- Calculate offset relative to vehicle for attachment
    local offset = State.currentTruckConfig.servingPosition
    
    -- Attach ped to vehicle so it moves with the vehicle
    AttachEntityToEntity(
        servingPed, 
        State.currentVehicle, 
        0, -- bone index (0 = center)
        offset.x, offset.y, offset.z, -- offset from vehicle center
        0.0, 0.0, State.currentTruckConfig.servingHeading, -- rotation
        false, false, false, false, 2, true
    )
    
    -- Completely lock down the ped
    FreezeEntityPosition(servingPed, true)
    SetBlockingOfNonTemporaryEvents(servingPed, true)
    SetPedCanRagdoll(servingPed, false)
    SetPedCanPlayGestureAnims(servingPed, false)
    SetPedCanPlayAmbientAnims(servingPed, false)
    SetPedCanPlayVisemeAnims(servingPed, false)
    
    -- Disable AI and movement
    SetPedConfigFlag(servingPed, 17, true) -- CPED_CONFIG_FLAG_BlockNonTemporaryEvents
    SetPedConfigFlag(servingPed, 128, true) -- CPED_CONFIG_FLAG_DisableMelee
    SetPedConfigFlag(servingPed, 208, true) -- CPED_CONFIG_FLAG_DisableShallowWaterBikeJumpOut
    SetPedConfigFlag(servingPed, 281, false) -- CPED_CONFIG_FLAG_CanAttackFriendly
    TaskStandStill(servingPed, -1) -- Stand still indefinitely
    
    -- Clone is NOT invincible - it can take damage
    SetEntityInvincible(servingPed, false)
    SetEntityHealth(servingPed, GetEntityHealth(playerPed))
    SetPedSuffersCriticalHits(servingPed, true) -- Can take headshots
    
    -- Make player invisible
    SetEntityAlpha(playerPed, 0, false)
    
    State.servingPed = servingPed
    
    -- Start damage monitoring thread
    CreateThread(function()
        local clonePed = servingPed -- Local reference to avoid race condition
        local lastCloneHealth = GetEntityHealth(clonePed)
        local lastPlayerHealth = GetEntityHealth(playerPed)
        
        while State.servingPed == clonePed and DoesEntityExist(clonePed) and State.isWorking do
            Wait(50) -- Fast checks for responsive damage
            
            -- Check if we're still working first
            if not State.isWorking then break end
            
            local cloneHealth = GetEntityHealth(clonePed)
            local playerHealth = GetEntityHealth(playerPed)
            
            -- Only sync if both are alive and valid
            if cloneHealth > 0 and playerHealth > 0 then
                -- Sync damage from clone to player
                if cloneHealth < lastCloneHealth then
                    local damage = lastCloneHealth - cloneHealth
                    SetEntityHealth(playerPed, math.max(0, playerHealth - damage))
                    lastPlayerHealth = GetEntityHealth(playerPed)
                end
                
                -- Sync damage from player to clone (if hit from inside vehicle somehow)
                if playerHealth < lastPlayerHealth then
                    local damage = lastPlayerHealth - playerHealth
                    SetEntityHealth(clonePed, math.max(0, cloneHealth - damage))
                    lastCloneHealth = GetEntityHealth(clonePed)
                end
            end
            
            -- If clone actually died from damage (not deletion), handle it
            if DoesEntityExist(clonePed) and IsEntityDead(clonePed) and State.isWorking then
                SetEntityHealth(playerPed, 0)
                ResetWorkingState()
                break
            end
            
            -- If player died, stop working
            if IsEntityDead(playerPed) then
                ResetWorkingState()
                break
            end
            
            lastCloneHealth = cloneHealth
            lastPlayerHealth = playerHealth
        end
    end)
end

-- Function to cleanup serving ped
function CleanupServingPed()
    local playerPed = cache.ped
    if not playerPed then return end
    
    -- Store reference to ped before clearing state
    local pedToDelete = State.servingPed
    
    -- Clear state FIRST to stop damage monitoring thread
    State.servingPed = nil
    
    -- Make player visible again
    if DoesEntityExist(playerPed) then
        SetEntityAlpha(playerPed, 255, false)
    end
    
    -- Now delete cloned ped
    if pedToDelete then
        if DoesEntityExist(pedToDelete) then
            -- Detach from vehicle first
            DetachEntity(pedToDelete, true, true)
            
            SetEntityAsNoLongerNeeded(pedToDelete)
            DeleteEntity(pedToDelete)
            
            -- Force deletion if still exists
            local attempts = 0
            while DoesEntityExist(pedToDelete) and attempts < 5 do
                Wait(10)
                DeleteEntity(pedToDelete)
                attempts = attempts + 1
            end
        end
    end
    
    -- Return to driver seat if free
    if playerPed and State.currentVehicle and DoesEntityExist(State.currentVehicle) and State.originalSeat ~= -1 then
        if IsVehicleSeatFree(State.currentVehicle, State.originalSeat) then
            TaskWarpPedIntoVehicle(playerPed, State.currentVehicle, State.originalSeat)
        end
    end
end
