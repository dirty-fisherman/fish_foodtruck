-- NPC selling module - Client side

-- Track the NPC currently approaching for debug visualization
local approachingNPC = nil

-- Function to make an NPC attack the player
local function MakeNPCAttack(npc, reason)
    if not npc or not DoesEntityExist(npc) then return end
    
    local playerPed = PlayerPedId()
    
    -- NPC insults player
    PlayAmbientSpeech1(npc, 'GENERIC_INSULT_HIGH', 'Speech_Params_Force')
    Wait(500) -- Brief pause after insult
    
    -- Make NPC hostile and attack player
    SetPedRelationshipGroupHash(npc, GetHashKey('HATES_PLAYER'))
    SetPedCombatAttributes(npc, 46, true) -- BF_CanFightArmedPedsWhenNotArmed
    SetPedCombatAttributes(npc, 5, true) -- BF_AlwaysFight
    SetPedFleeAttributes(npc, 0, false) -- Don't flee
    SetPedCombatRange(npc, 2) -- Medium range
    SetPedCombatMovement(npc, 2) -- Offensive
    TaskCombatPed(npc, playerPed, 0, 16) -- Attack player
    
    -- Give NPC a weapon (fists by default, or melee weapon)
    if math.random() < 0.3 then -- 30% chance of having a melee weapon
        local meleeWeapons = {
            'WEAPON_BAT',
            'WEAPON_KNIFE',
            'WEAPON_BOTTLE',
            'WEAPON_CROWBAR'
        }
        local weapon = meleeWeapons[math.random(#meleeWeapons)]
        GiveWeaponToPed(npc, GetHashKey(weapon), 1, false, true)
    end
    
    -- Show notification
    lib.notify({
        title = 'Food Truck',
        description = reason or 'This customer seems angry!',
        type = 'error',
        duration = 5000
    })
end

-- Function to make an NPC approach and attempt purchase
local function MakeNPCApproach(npc)
    if not npc or not DoesEntityExist(npc) then return end
    if not State.currentVehicle or not DoesEntityExist(State.currentVehicle) then return end
    if not State.servingPed or not DoesEntityExist(State.servingPed) then return end
    
    State.npcApproaching = true
    approachingNPC = npc -- Track for debug visualization
    
    -- Block ambient actions and clear existing tasks
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedKeepTask(npc, true)
    ClearPedTasks(npc)
    ClearPedSecondaryTask(npc)
    
    -- NPC wants to buy - play greeting
    PlayAmbientSpeech1(npc, 'GENERIC_HI', 'Speech_Params_Force')
    
    -- Calculate position in front of serving ped (where customer should stand at serving window)
    local servingPedPos = GetEntityCoords(State.servingPed)
    local servingPedForward = GetEntityForwardVector(State.servingPed)
    
    -- Position 1.2 meters in front of where the serving ped is facing
    local customerStandPos = servingPedPos + (servingPedForward * 1.2)
    
    -- Debug output
    if Config.Debug then
        print('^3[NPC Approach Debug]^7')
        print('Serving Ped Pos:', servingPedPos)
        print('Serving Ped Forward:', servingPedForward)
        print('Customer Stand Pos:', customerStandPos)
        print('Distance to walk:', #(GetEntityCoords(npc) - customerStandPos))
    end
    
    -- Make NPC walk to the customer position (in front of serving window)
    TaskGoToCoordAnyMeans(npc, customerStandPos.x, customerStandPos.y, customerStandPos.z, 1.0, 0, false, 786603, 0xbf800000)
    
    -- Wait for NPC to get close
    CreateThread(function()
        local timeout = 0
        local lastDist = #(GetEntityCoords(npc) - customerStandPos)
        local stuckCounter = 0
        
        while timeout < 15000 do -- 15 second timeout
            Wait(500)
            timeout = timeout + 500
            
            if not DoesEntityExist(npc) or IsPedDeadOrDying(npc, true) then
                State.npcApproaching = false
                approachingNPC = nil
                break
            end
            
            if not DoesEntityExist(State.currentVehicle) then
                State.npcApproaching = false
                approachingNPC = nil
                SetBlockingOfNonTemporaryEvents(npc, false)
                TaskWanderStandard(npc, 10.0, 10)
                break
            end
            
            local npcCoords = GetEntityCoords(npc)
            local dist = #(npcCoords - customerStandPos)
            
            -- Check if NPC is stuck (not making progress)
            if math.abs(dist - lastDist) < 0.5 then
                stuckCounter = stuckCounter + 1
                if stuckCounter >= 10 then -- Stuck for 5 seconds
                    if Config.Debug then
                        print('^1[NPC Approach] NPC appears stuck, cancelling^7')
                    end
                    State.npcApproaching = false
                    approachingNPC = nil
                    SetBlockingOfNonTemporaryEvents(npc, false)
                    TaskWanderStandard(npc, 10.0, 10)
                    break
                end
            else
                stuckCounter = 0
            end
            lastDist = dist
            
            if dist < 2.0 then
                -- Make NPC face the serving ped (recheck it still exists)
                if State.servingPed and DoesEntityExist(State.servingPed) then
                    local currentServingPos = GetEntityCoords(State.servingPed)
                    TaskTurnPedToFaceCoord(npc, currentServingPos.x, currentServingPos.y, currentServingPos.z, 1000)
                end
                Wait(500)
                
                -- Random chance NPC decides to attack instead of buy
                if math.random() < Config.NPCSelling.randomAttackChance then
                    MakeNPCAttack(npc, 'This customer seems angry!')
                    State.npcApproaching = false
                    approachingNPC = nil
                    break
                end
                
                -- NPC reached vehicle, server will pick an in-stock item
                local npcNetId = NetworkGetNetworkIdFromEntity(npc)
                TriggerServerEvent('fish_foodtruck:npcPurchase', State.currentPlate, npcNetId, State.currentTruckType)
                
                -- Wait for server response
                Wait(2000)
                
                -- Re-enable ambient behavior
                SetBlockingOfNonTemporaryEvents(npc, false)
                TaskWanderStandard(npc, 10.0, 10)
                State.npcApproaching = false
                approachingNPC = nil
                break
            end
        end
        
        -- Timeout reached
        if timeout >= 15000 then
            if Config.Debug then
                print('^1[NPC Approach] Timeout - NPC failed to reach destination^7')
            end
            State.npcApproaching = false
            approachingNPC = nil
            if DoesEntityExist(npc) then
                SetBlockingOfNonTemporaryEvents(npc, false)
                TaskWanderStandard(npc, 10.0, 10)
            end
        end
    end)
end

-- NPC selling thread
CreateThread(function()
    while true do
        -- Dynamic wait - check more frequently when not selling to save performance
        if not State.sellingToNPCs or not State.isWorking then
            Wait(5000)
        else
            Wait(Config.NPCSelling.interval)
            
            -- Only process if all conditions met and no NPC currently approaching
            if State.sellingToNPCs and State.isWorking and State.currentVehicle and DoesEntityExist(State.currentVehicle) and not State.npcApproaching then
                local vehCoords = GetEntityCoords(State.currentVehicle)
                local nearbyPeds = lib.getNearbyPeds(vehCoords, Config.NPCSelling.radius, true)
                
                -- Filter out players, serving ped clone, and find valid NPCs
                local validNPCs = {}
                for _, pedData in ipairs(nearbyPeds) do
                    local ped = pedData.ped
                    local distance = pedData.distance or #(GetEntityCoords(ped) - vehCoords)
                    
                    -- Exclude: players, our serving clone, peds in vehicles, dead peds, and peds too close (< 3m)
                    if not IsPedAPlayer(ped) 
                        and ped ~= State.servingPed 
                        and not IsPedInAnyVehicle(ped, false) 
                        and not IsPedDeadOrDying(ped, true)
                        and distance >= 3.0 then
                        table.insert(validNPCs, ped)
                    end
                end
                
                -- Pick a random NPC to approach
                if #validNPCs > 0 then
                    local randomNPC = validNPCs[math.random(#validNPCs)]
                    MakeNPCApproach(randomNPC)
                end
            end
        end
    end
end)

-- Debug visualization thread
CreateThread(function()
    while true do
        if Config.Debug and State.isWorking and State.currentVehicle and DoesEntityExist(State.currentVehicle) then
            local vehCoords = GetEntityCoords(State.currentVehicle)
            
            -- Draw radius circle around vehicle showing NPC search area
            DrawMarker(
                1, -- Cylinder marker
                vehCoords.x, vehCoords.y, vehCoords.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                Config.NPCSelling.radius * 2.0, Config.NPCSelling.radius * 2.0, 0.5,
                0, 255, 0, 50, -- Green, semi-transparent
                false, false, 2, false, nil, nil, false
            )
            
            -- Draw marker above approaching NPC's head
            if approachingNPC and DoesEntityExist(approachingNPC) then
                local npcCoords = GetEntityCoords(approachingNPC)
                local npcHeadPos = GetPedBoneCoords(approachingNPC, 31086, 0.0, 0.0, 0.0) -- Head bone
                
                -- Draw arrow pointing down at NPC
                DrawMarker(
                    2, -- Sphere marker
                    npcHeadPos.x, npcHeadPos.y, npcHeadPos.z + 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    0.3, 0.3, 0.3,
                    255, 255, 0, 200, -- Yellow, mostly opaque
                    true, true, 2, false, nil, nil, false
                )
                
                -- Draw vertical line from marker to head
                DrawLine(
                    npcHeadPos.x, npcHeadPos.y, npcHeadPos.z + 1.0,
                    npcHeadPos.x, npcHeadPos.y, npcHeadPos.z,
                    255, 255, 0, 200
                )
            end
            
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

-- Debug command to spawn a customer NPC
RegisterCommand('spawncustomer', function()
    -- Check if debug mode is enabled
    if not Config.Debug then
        lib.notify({
            title = 'Food Truck',
            description = 'Debug mode is disabled',
            type = 'error'
        })
        return
    end
    
    if not State.isWorking then
        lib.notify({
            title = 'Food Truck',
            description = 'You need to be working first!',
            type = 'error'
        })
        return
    end
    
    if not State.currentVehicle or not DoesEntityExist(State.currentVehicle) then
        lib.notify({
            title = 'Food Truck',
            description = 'No valid food truck found!',
            type = 'error'
        })
        return
    end
    
    -- Get a spawn position in front of the truck
    local vehCoords = GetEntityCoords(State.currentVehicle)
    local vehHeading = GetEntityHeading(State.currentVehicle)
    local vehForward = GetEntityForwardVector(State.currentVehicle)
    
    -- Spawn 5-10 meters in front of the truck
    local spawnDistance = 5.0 + math.random() * 5.0
    local spawnPos = vehCoords + (vehForward * spawnDistance)
    
    -- Random ped model
    local pedModels = {
        'a_m_y_hipster_01',
        'a_f_y_hipster_01',
        'a_m_y_business_01',
        'a_f_y_business_01',
        'a_m_y_tourist_01',
        'a_f_y_tourist_01'
    }
    local pedModel = pedModels[math.random(#pedModels)]
    local pedHash = GetHashKey(pedModel)
    
    -- Request model
    RequestModel(pedHash)
    while not HasModelLoaded(pedHash) do
        Wait(10)
    end
    
    -- Spawn ped
    local customerPed = CreatePed(4, pedHash, spawnPos.x, spawnPos.y, spawnPos.z, vehHeading, true, false)
    SetModelAsNoLongerNeeded(pedHash)
    
    -- Make them approach the truck
    Wait(100) -- Small delay to ensure ped is fully spawned
    MakeNPCApproach(customerPed)
    
    lib.notify({
        title = 'Food Truck',
        description = 'Customer spawned!',
        type = 'success'
    })
end, false)
-- Handle NPC purchase result
RegisterNetEvent('fish_foodtruck:npcPurchaseResult', function(npcNetId, success)
    local npc = NetworkGetEntityFromNetworkId(npcNetId)
    
    if DoesEntityExist(npc) then
        if success then
            -- Only play handoff animation if serving ped exists
            if State.servingPed and DoesEntityExist(State.servingPed) then
                -- Load animation dictionary
                local animDict = 'mp_common'
                RequestAnimDict(animDict)
                while not HasAnimDictLoaded(animDict) do
                    Wait(10)
                end
                
                -- Serving ped hands over item
                TaskPlayAnim(State.servingPed, animDict, 'givetake1_a', 8.0, -8.0, 1500, 0, 0, false, false, false)
                
                -- NPC receives item (mirrored animation)
                TaskPlayAnim(npc, animDict, 'givetake1_b', 8.0, -8.0, 1500, 0, 0, false, false, false)
                
                -- Wait for animation to play a bit
                Wait(800)
            end
            
            -- Successful purchase - NPC says thanks
            PlayAmbientSpeech1(npc, 'GENERIC_THANKS', 'Speech_Params_Force')
        else
            -- No items available - NPC insults you and may attack
            if math.random() < Config.NPCSelling.attackChanceWhenOutOfStock then
                MakeNPCAttack(npc, 'You fucked up their order!')
            else
                PlayAmbientSpeech1(npc, 'GENERIC_INSULT_HIGH', 'Speech_Params_Force')
            end
        end
    end
end)
