-- NPC customer logic — ported and simplified from fish_foodtruck.

-- Maps door bone names to GTA5 vehicle door indices.
local BONE_TO_DOOR = {
    door_dside_f = 0, door_pside_f = 1,
    door_dside_r = 2, door_pside_r = 3,
}

local function makeNPCAttack(npc, reason)
    if not DoesEntityExist(npc) then return end

    if FishFoodTruck.isWorking and FishFoodTruck.vehicle and DoesEntityExist(FishFoodTruck.vehicle) then
        local cfg      = FishFoodTruck.truckCfg
        local vehicle  = FishFoodTruck.vehicle
        -- Prefer the bone the player clicked when they started working so the
        -- attack always happens at the same door they entered from.
        local boneName          = FishFoodTruck.entryBone or (cfg.targetBones and cfg.targetBones[1])
        local doorIdx           = boneName and BONE_TO_DOOR[boneName]
        local exitPos, exitHdg  = FishFoodTruck.GetBoneExitPos(vehicle, boneName)

        -- 1. Walk NPC to just outside the door they'll burst through (max 3s)
        ClearPedTasks(npc)
        TaskGoToCoordAnyMeans(npc, exitPos.x, exitPos.y, exitPos.z, 2.0, 0, false, 786603, 0xbf800000)
        local t = 0
        while t < 3000 and DoesEntityExist(npc) and not IsPedDeadOrDying(npc, true) do
            Wait(100)
            t = t + 100
            if #(GetEntityCoords(npc) - exitPos) < 1.5 then break end
        end

        -- 2. Open the door (visual beat before player is ejected)
        if doorIdx then
            SetVehicleDoorOpen(vehicle, doorIdx, false, false)
        end
        Wait(250)

        -- 3. Eject the player out at that exact door position
        FishFoodTruck.Reset(exitPos, exitHdg)

        -- 4. Ragdoll the ped — give one frame for physics to settle first
        Wait(150)
        local ped = cache.ped
        if ped then
            SetPedCanRagdoll(ped, true)
            SetPedToRagdoll(ped, 1500, 2000, 0, false, false, false)
        end
    end

    -- 5. Arm, insult, then go hostile
    if math.random() < Config.NPCSelling.meleeWeaponChance then
        local weapons = Config.NPCSelling.meleeWeapons
        GiveWeaponToPed(npc, GetHashKey(weapons[math.random(#weapons)]), 1, false, true)
    end
    PlayAmbientSpeech1(npc, 'GENERIC_INSULT_HIGH', 'Speech_Params_Force')
    SetPedRelationshipGroupHash(npc, GetHashKey('HATES_PLAYER'))
    SetPedCombatAttributes(npc, 46, true)
    SetPedCombatAttributes(npc, 5, true)
    SetPedFleeAttributes(npc, 0, false)
    SetPedCombatRange(npc, 2)
    SetPedCombatMovement(npc, 2)
    TaskCombatPed(npc, PlayerPedId(), 0, 16)
    lib.notify({ title = 'Food Truck', description = reason or 'Angry customer!', type = 'error', duration = 5000 })
end

local function makeNPCApproach(npc)
    if not DoesEntityExist(npc) then return end
    if not FishFoodTruck.vehicle or not DoesEntityExist(FishFoodTruck.vehicle) then return end

    FishFoodTruck.npcApproaching = true

    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedKeepTask(npc, true)
    ClearPedTasks(npc)
    PlayAmbientSpeech1(npc, 'GENERIC_HI', 'Speech_Params_Force')

    -- Target position: 1.2m in front of the serving ped (the attached player).
    -- Using the ped's own forward vector (which honours servingHeading) gives the
    -- correct facing direction for any truck orientation — identical to the original
    -- fish_foodtruck approach that used servingPed's forward vector.
    local workerPos = GetEntityCoords(cache.ped)
    local workerFwd = GetEntityForwardVector(cache.ped)
    local destPos   = vector3(workerPos.x + workerFwd.x * 1.2,
                              workerPos.y + workerFwd.y * 1.2,
                              workerPos.z)

    TaskGoToCoordAnyMeans(npc, destPos.x, destPos.y, destPos.z, 1.0, 0, false, 786603, 0xbf800000)

    CreateThread(function()
        local timeout    = 0
        local lastDist   = #(GetEntityCoords(npc) - destPos)
        local stuckCount = 0

        while timeout < 15000 do
            Wait(500)
            timeout = timeout + 500

            if not DoesEntityExist(npc) or IsPedDeadOrDying(npc, true) then
                FishFoodTruck.npcApproaching = false
                return
            end

            if not FishFoodTruck.isWorking or not DoesEntityExist(FishFoodTruck.vehicle) then
                SetBlockingOfNonTemporaryEvents(npc, false)
                TaskWanderStandard(npc, 10.0, 10)
                FishFoodTruck.npcApproaching = false
                return
            end

            -- Stuck detection
            local dist = #(GetEntityCoords(npc) - destPos)
            if math.abs(dist - lastDist) < 0.5 then
                stuckCount = stuckCount + 1
                if stuckCount >= 30 then
                    SetBlockingOfNonTemporaryEvents(npc, false)
                    TaskWanderStandard(npc, 10.0, 10)
                    FishFoodTruck.npcApproaching = false
                    return
                end
            else
                stuckCount = 0
            end
            lastDist = dist

            if dist < 2.0 then
                TaskTurnPedToFaceCoord(npc, workerPos.x, workerPos.y, workerPos.z, 1000)
                Wait(500)

                if math.random() < Config.NPCSelling.randomAttackChance then
                    makeNPCAttack(npc, 'This customer seems angry!')
                    FishFoodTruck.npcApproaching = false
                    return
                end

                TriggerServerEvent('fishFoodTruck:npcPurchase', NetworkGetNetworkIdFromEntity(npc))
                Wait(2000)
                SetBlockingOfNonTemporaryEvents(npc, false)
                TaskWanderStandard(npc, 10.0, 10)
                FishFoodTruck.npcApproaching = false
                return
            end
        end

        -- Timeout — NPC gave up
        FishFoodTruck.npcApproaching = false
        if DoesEntityExist(npc) then
            SetBlockingOfNonTemporaryEvents(npc, false)
            TaskWanderStandard(npc, 10.0, 10)
        end
    end)
end

-- Purchase result — play handoff animation when successful
RegisterNetEvent('fishFoodTruck:npcPurchaseResult', function(npcNetId, success)
    local npc = NetworkGetEntityFromNetworkId(npcNetId)
    if not DoesEntityExist(npc) then return end
    if success then
        local dict = 'mp_common'
        RequestAnimDict(dict)
        local t = GetGameTimer() + 1000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(cache.ped, dict, 'givetake1_a', 4.0, -4.0, 1500, 0, 0, false, false, false)
            TaskPlayAnim(npc,       dict, 'givetake1_b', 4.0, -4.0, 1500, 0, 0, false, false, false)
            Wait(1500)
        end
        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
    end
end)

-- ─── NPC selling loop ─────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        if not FishFoodTruck.sellingToNPCs or not FishFoodTruck.isWorking then
            Wait(5000)
        else
            Wait(Config.NPCSelling.interval)

            if FishFoodTruck.sellingToNPCs and FishFoodTruck.isWorking
               and FishFoodTruck.vehicle and DoesEntityExist(FishFoodTruck.vehicle)
               and not FishFoodTruck.npcApproaching then

                local vehCoords = GetEntityCoords(FishFoodTruck.vehicle)
                local nearby    = lib.getNearbyPeds(vehCoords, Config.NPCSelling.radius, true)
                local valid     = {}

                for _, data in ipairs(nearby) do
                    local ped  = data.ped
                    local dist = data.distance or #(GetEntityCoords(ped) - vehCoords)
                    if not IsPedAPlayer(ped)
                       and not IsPedInAnyVehicle(ped, false)
                       and not IsPedDeadOrDying(ped, true)
                       and dist >= 3.0 then
                        valid[#valid + 1] = ped
                    end
                end

                if #valid > 0 then
                    makeNPCApproach(valid[math.random(#valid)])
                end
            end
        end
    end
end)
