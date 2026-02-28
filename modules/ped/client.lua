-- Serving ped module - Client side

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

    -- Clone player ped (networked so other players can see it)
    local servingPed = ClonePed(playerPed, true, false, true)

    -- Disable collision completely
    SetEntityCollision(servingPed, false, false)
    SetEntityCompletelyDisableCollision(servingPed, false, false)

    -- Attach ped to vehicle so it moves with the vehicle
    local offset = State.currentTruckConfig.servingPosition
    AttachEntityToEntity(
        servingPed,
        State.currentVehicle,
        0,
        offset.x, offset.y, offset.z,
        0.0, 0.0, State.currentTruckConfig.servingHeading,
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
    TaskStandStill(servingPed, -1)

    -- Clone is NOT invincible - it can take damage
    SetEntityInvincible(servingPed, false)
    SetEntityHealth(servingPed, GetEntityHealth(playerPed))
    SetPedSuffersCriticalHits(servingPed, true)

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

    -- Store reference before clearing state (clearing stops the damage monitor thread)
    local pedToDelete = State.servingPed
    State.servingPed = nil

    -- Make player visible again immediately
    if DoesEntityExist(playerPed) then
        SetEntityAlpha(playerPed, 255, false)
    end

    -- Delete the networked clone in a thread so we can wait for network control
    if pedToDelete then
        CreateThread(function()
            if not DoesEntityExist(pedToDelete) then return end

            -- Must acquire network control before DeleteEntity will stick on a networked ped
            NetworkRequestControlOfEntity(pedToDelete)
            local timeout = 0
            while not NetworkHasControlOfEntity(pedToDelete) and timeout < 2000 do
                Wait(50)
                timeout = timeout + 50
                NetworkRequestControlOfEntity(pedToDelete)
            end

            if DoesEntityExist(pedToDelete) then
                DetachEntity(pedToDelete, true, true)
                SetEntityAsNoLongerNeeded(pedToDelete)
                DeleteEntity(pedToDelete)
            end
        end)
    end

    -- Return to seat only if the player is still physically inside the vehicle
    if cache.vehicle and playerPed and State.currentVehicle and DoesEntityExist(State.currentVehicle) and State.originalSeat ~= -1 then
        if IsVehicleSeatFree(State.currentVehicle, State.originalSeat) then
            TaskWarpPedIntoVehicle(playerPed, State.currentVehicle, State.originalSeat)
        end
    end
end
