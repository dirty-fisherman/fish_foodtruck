-- Client-side shared state for fish_foodtruck2

FishFoodTruck = {
    -- Working session
    isWorking      = false,
    isAttached     = false,
    vehicle        = nil,   -- entity handle of the truck we're working in
    plate          = nil,
    truckKey       = nil,   -- key into Config.Trucks
    truckCfg       = nil,

    -- Entry restore: position where the player stood before they started working
    entryCoords    = nil,
    entryHeading   = 0.0,
    entryBone      = nil,   -- bone name clicked to start working; determines exit side

    -- Scripted camera shown while working
    workCam        = nil,

    -- NPC selling
    sellingToNPCs  = false,
    npcApproaching = false,
}

--- Compute the world-space exit position and heading for a given door bone.
--- Uses the actual bone world position so the player lands at the right door
--- regardless of truck model dimensions.  Returns (vector3, number).
function FishFoodTruck.GetBoneExitPos(vehicle, boneName)
    boneName      = boneName or ''
    local isPside = boneName:find('pside') ~= nil
    local sign    = isPside and 1.0 or -1.0

    -- Vehicle right vector in world XY: cross(forward, upZ) = (fwd.y, -fwd.x)
    local fwd = GetEntityForwardVector(vehicle)
    local rx, ry = fwd.y, -fwd.x

    local boneIdx = GetEntityBoneIndexByName(vehicle, boneName)
    if boneIdx ~= -1 then
        local bp  = GetWorldPositionOfEntityBone(vehicle, boneIdx)
        local exitOff    = (FishFoodTruck.truckCfg and FishFoodTruck.truckCfg.exitOffset) or {}
        local sideOffset = exitOff.side or -0.5
        local backOffset = exitOff.back or  0.7
        local pos = vector3(
            bp.x + rx * sign * sideOffset - fwd.x * backOffset,
            bp.y + ry * sign * sideOffset - fwd.y * backOffset,
            bp.z
        )
        local hdg = (GetEntityHeading(vehicle) + (isPside and 90.0 or -90.0)) % 360.0

        -- Snap Z to ground level — the bone is at door-handle height, not foot level.
        -- Search from 2m above the computed XY position downward.
        local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)
        if found then pos = vector3(pos.x, pos.y, gz + 0.05) end

        print(string.format('[FishFoodTruck] GetBoneExitPos  bone=%s  boneIdx=%d  boneWorld=(%.2f, %.2f, %.2f)  exit=(%.2f, %.2f, %.2f)  hdg=%.1f',
            boneName, boneIdx, bp.x, bp.y, bp.z, pos.x, pos.y, pos.z, hdg))
        return pos, hdg
    end

    -- Fallback when the bone name doesn't exist on this model
    print(string.format('[FishFoodTruck] GetBoneExitPos  bone=%s  NOT FOUND, using offset fallback', boneName))
    local pos = GetOffsetFromEntityInWorldCoords(vehicle, sign * 2.2, 0.0, 0.0)
    local hdg = (GetEntityHeading(vehicle) + (isPside and 90.0 or -90.0)) % 360.0
    return pos, hdg
end

--- Fully reset session state and restore the player ped.
--- Reset can receive an optional world-space exit position (used when an NPC
--- attack ejects the player to a specific door instead of the default side exit).
function FishFoodTruck.Reset(customExitPos, customExitHeading)
    local hadVehicle = FishFoodTruck.vehicle
    local hadCfg     = FishFoodTruck.truckCfg
    local hadEntry   = FishFoodTruck.entryCoords
    local hadHeading = FishFoodTruck.entryHeading

    -- Dismiss the persistent working context indicator
    lib.hideTextUI()

    -- Destroy working camera (immediate cut — no blend to avoid disorientation)
    if FishFoodTruck.workCam then
        RenderScriptCams(false, false, 0, true, false)
        if DoesCamExist(FishFoodTruck.workCam) then DestroyCam(FishFoodTruck.workCam, false) end
        FishFoodTruck.workCam = nil
    end

    -- Close serving door/hatch if one was opened
    if hadCfg and hadCfg.servingDoor and hadVehicle and DoesEntityExist(hadVehicle) then
        SetVehicleDoorShut(hadVehicle, hadCfg.servingDoor, false)
    end

    -- Detach + restore the ped.
    local ped = cache.ped
    if ped then
        if FishFoodTruck.isAttached then
            DetachEntity(ped, true, true)
        end
        FreezeEntityPosition(ped, false)
        SetBlockingOfNonTemporaryEvents(ped, false)
        SetPedCanRagdoll(ped, true)
        ClearPedTasks(ped)

        if customExitPos then
            print(string.format('[FishFoodTruck] Reset  exiting to CUSTOM pos=(%.2f, %.2f, %.2f)  hdg=%.1f',
                customExitPos.x, customExitPos.y, customExitPos.z, customExitHeading or 0.0))
            SetEntityCoords(ped, customExitPos.x, customExitPos.y, customExitPos.z,
                false, false, false, false)
            SetEntityHeading(ped, customExitHeading or 0.0)
        elseif hadVehicle and DoesEntityExist(hadVehicle) and hadCfg then
            local bn = FishFoodTruck.entryBone or (hadCfg.targetBones and hadCfg.targetBones[1])
            local exitPos, exitHdg = FishFoodTruck.GetBoneExitPos(hadVehicle, bn)
            print(string.format('[FishFoodTruck] Reset  bone=%s  exiting to=(%.2f, %.2f, %.2f)  hdg=%.1f',
                tostring(bn), exitPos.x, exitPos.y, exitPos.z, exitHdg))
            SetEntityCoords(ped, exitPos.x, exitPos.y, exitPos.z, false, false, false, false)
            SetEntityHeading(ped, exitHdg)
        end

        -- FishFoodTruck.Attach disabled the ped's global collision (SetEntityCollision false) before
        -- teleporting in.  Restore it now that the ped is at the exit position.
        SetEntityCollision(ped, true, true)
        if hadVehicle and DoesEntityExist(hadVehicle) then
            SetEntityCollision(hadVehicle, true, true)
        end

        local p = GetEntityCoords(ped)
        print(string.format('[FishFoodTruck] Reset  collision restored  pedPos=(%.2f, %.2f, %.2f)', p.x, p.y, p.z))
    end

    -- Notify server (clear statebag, worker table)
    if hadVehicle and DoesEntityExist(hadVehicle) then
        TriggerServerEvent('fishFoodTruck:stopWork', VehToNet(hadVehicle))
    end

    FishFoodTruck.isWorking      = false
    FishFoodTruck.isAttached     = false
    FishFoodTruck.vehicle        = nil
    FishFoodTruck.plate          = nil
    FishFoodTruck.truckKey       = nil
    FishFoodTruck.truckCfg       = nil
    FishFoodTruck.entryCoords    = nil
    FishFoodTruck.entryHeading   = 0.0
    FishFoodTruck.entryBone      = nil
    FishFoodTruck.workCam        = nil
    FishFoodTruck.sellingToNPCs  = false
    FishFoodTruck.npcApproaching = false
end
