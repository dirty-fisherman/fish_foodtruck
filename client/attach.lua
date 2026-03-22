-- Handles attaching / detaching the player ped to the food truck serving spot.
-- The player starts OUTSIDE the truck (no TaskLeaveVehicle needed).

local IDLE_DICT = 'amb@world_human_stand_impatient@male@base'
local IDLE_CLIP = 'base'

-- Preload the idle anim dict as soon as the resource starts so FishFoodTruck.Attach
-- never has to block-wait for it (that blocking wait was the attach delay).
CreateThread(function()
    RequestAnimDict(IDLE_DICT)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(IDLE_DICT) and GetGameTimer() < deadline do Wait(50) end
end)

--- Teleport the player into the truck and attach them at the serving offset.
--- The driver can sit in seat -1 and drive normally — the ped is attached
--- via chassis bone, not placed in any seat.
function FishFoodTruck.Attach(vehicle)
    local cfg     = FishFoodTruck.truckCfg
    local offset  = cfg.servingPosition
    local hdg     = cfg.servingHeading or 0.0
    local ped     = cache.ped
    local boneIdx = GetEntityBoneIndexByName(vehicle, 'chassis') or 0

    -- Store where the player stood so Reset() can return them there
    FishFoodTruck.entryCoords  = GetEntityCoords(ped)
    FishFoodTruck.entryHeading = GetEntityHeading(ped)

    -- Log entry position and the door bone world position for debugging exit placement
    local entryBoneName = FishFoodTruck.entryBone or '(unknown)'
    local entryBoneIdx  = GetEntityBoneIndexByName(vehicle, entryBoneName)
    if entryBoneIdx ~= -1 then
        local bp = GetWorldPositionOfEntityBone(vehicle, entryBoneIdx)
        print(string.format('[FishFoodTruck] Attach  entryCoords=(%.2f, %.2f, %.2f)  bone=%s  boneWorld=(%.2f, %.2f, %.2f)',
            FishFoodTruck.entryCoords.x, FishFoodTruck.entryCoords.y, FishFoodTruck.entryCoords.z,
            entryBoneName, bp.x, bp.y, bp.z))
    else
        print(string.format('[FishFoodTruck] Attach  entryCoords=(%.2f, %.2f, %.2f)  bone=%s  (bone not found on model)',
            FishFoodTruck.entryCoords.x, FishFoodTruck.entryCoords.y, FishFoodTruck.entryCoords.z, entryBoneName))
    end

    -- Freeze and strip physics BEFORE teleporting so there is no single-frame
    -- window where the ped is visible in the wrong position.
    SetEntityCollision(ped, false, false)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    -- Teleport to the serving spot (ped is already frozen — no glitch window).
    local worldPos = GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, offset.z)
    SetEntityCoords(ped, worldPos.x, worldPos.y, worldPos.z, false, false, false, false)

    -- Attach immediately — no Wait() so attachment is in the same tick.
    -- isPed=true and fixedRotation=true are critical for ped-to-vehicle attachment.
    -- collision=false prevents the capsule from scraping the interior mesh.
    AttachEntityToEntity(
        ped, vehicle,
        boneIdx,
        offset.x, offset.y, offset.z,  -- position offset
        0.0, 0.0, hdg,                  -- rotation offset (relative yaw only)
        false,  -- p9
        false,  -- useSoftPinning
        false,  -- collision
        true,   -- isPed
        2,      -- rotationOrder
        true    -- fixedRotation
    )

    -- Play idle anim — dict is already guaranteed loaded above.
    -- lockX/Y/Z=true prevents root motion from sliding the ped off the attach point.
    -- SetPedKeepTask prevents the engine from cancelling the task (eliminates shuffle).
    if HasAnimDictLoaded(IDLE_DICT) then
        SetPedKeepTask(ped, true)
        TaskPlayAnim(ped, IDLE_DICT, IDLE_CLIP, 2.0, -2.0, -1, 1, 0.0, true, true, true)
    end

    FishFoodTruck.isAttached = true

    -- Open serving door/hatch if configured (e.g. taco truck serving window)
    if cfg.servingDoor then
        SetVehicleDoorOpen(vehicle, cfg.servingDoor, false, false)
    end

    -- ─── Working camera — mouse-look orbit with scroll-wheel zoom ───────────
    -- Scroll wheel (up = zoom in, down = zoom out) adjusts camDist while working.
    -- Controls 14/15 (next/prev weapon on scroll) are suppressed so the player
    -- doesn't accidentally cycle weapons while adjusting zoom.
    -- Orbit rotation is suppressed while any NUI (e.g. ox_inventory) has focus.
    local sp = cfg.servingPosition

    local camYaw   = (GetEntityHeading(vehicle) + 180.0) % 360.0
    local camPitch = 55.0
    local camDist  = 7.0    -- default orbit radius in metres
    local CAM_MIN  = 2.0
    local CAM_MAX  = 14.0
    local ZOOM_STEP = 0.7   -- metres per scroll notch

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    FishFoodTruck.workCam = cam
    SetCamActive(cam, true)
    SetCamFov(cam, 55.0)    -- matches GTA's natural third-person FOV
    RenderScriptCams(true, false, 0, true, false)

    local localCam = cam
    CreateThread(function()
        while FishFoodTruck.isAttached do
            Wait(0)
            if not DoesCamExist(localCam) then break end

            -- Scroll wheel zooms; suppress native weapon cycling while working.
            DisableControlAction(0, 14, true)   -- scroll up   (next weapon)
            DisableControlAction(0, 15, true)   -- scroll down (prev weapon)
            if IsDisabledControlJustPressed(0, 14) then
                camDist = math.max(CAM_MIN, camDist - ZOOM_STEP)
            elseif IsDisabledControlJustPressed(0, 15) then
                camDist = math.min(CAM_MAX, camDist + ZOOM_STEP)
            end

            -- Orbit rotation — suppressed when NUI (e.g. inventory) has focus.
            local nuiFocused = IsNuiFocused()
            if not nuiFocused then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                camYaw   = (camYaw   - GetDisabledControlNormal(0, 1) * 5.0) % 360.0
                camPitch = math.max(-10.0, math.min(89.0,
                    camPitch + GetDisabledControlNormal(0, 2) * 5.0))
            end

            local lookAt = GetOffsetFromEntityInWorldCoords(vehicle, sp.x, sp.y, sp.z + 0.5)

            local yawRad   = math.rad(camYaw)
            local pitchRad = math.rad(camPitch)
            local cx = -math.sin(yawRad) * math.cos(pitchRad) * camDist
            local cy =  math.cos(yawRad) * math.cos(pitchRad) * camDist
            local cz =  math.sin(pitchRad) * camDist

            SetCamCoord(localCam, lookAt.x + cx, lookAt.y + cy, lookAt.z + cz)
            PointCamAtCoord(localCam, lookAt.x, lookAt.y, lookAt.z)
        end
    end)

    -- ─── Anti-shuffle ─────────────────────────────────────────────────────────
    -- If anything interrupts the idle task (engine AI, ambient events), reapply it.
    local localPed = ped
    CreateThread(function()
        while FishFoodTruck.isAttached do
            Wait(1000)
            if FishFoodTruck.isAttached and DoesEntityExist(localPed)
               and not IsEntityPlayingAnim(localPed, IDLE_DICT, IDLE_CLIP, 3) then
                SetPedKeepTask(localPed, true)
                TaskPlayAnim(localPed, IDLE_DICT, IDLE_CLIP, 8.0, -8.0, -1, 1, 0.0, true, true, true)
            end
        end
    end)
end

--- Detach and fully restore the player ped to normal world state.
function FishFoodTruck.Detach()
    local ped = cache.ped
    if not ped then return end

    FishFoodTruck.isAttached = false

    -- Store vehicle reference before detaching to restore its collision
    local hadVehicle = FishFoodTruck.vehicle

    -- Use ignorePhysics=false to let the ped respect physics during detach (FiveM best practice)
    DetachEntity(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCanRagdoll(ped, true)
    ClearPedTasks(ped)

    -- Restore vehicle collision so player can't walk through it post-detach
    if hadVehicle and DoesEntityExist(hadVehicle) then
        SetEntityCollision(hadVehicle, true, true)
    end
end
