-- Main client entry — ox_target setup, work start/stop, lifecycle events.

-- ─── ox_target registration ───────────────────────────────────────────────────
-- Registers two target options on every registered truck model:
--   1. "Start Working"      — only when NOT already working and NOT inside the truck
--   2. "Browse Serving Tray"— visible to anyone outside the truck (including other players)
for model, cfg in pairs(Config.Trucks) do
    exports.ox_target:addModel(model, {
        {
            name        = 'fishFoodTruck_start_' .. model,
            icon        = 'fa-solid fa-truck',
            label       = 'Start Working (' .. cfg.label .. ')',
            distance    = 2.5,
            bones       = cfg.targetBones,  -- nil = whole model; set in config per truck
            canInteract = function(entity)
                if FishFoodTruck.isWorking then return false end
                -- Must be standing outside, not seated in the vehicle
                return not IsPedInVehicle(cache.ped, entity, false)
            end,
            onSelect    = function(data)
                local vehicle = data.entity
                if not DoesEntityExist(vehicle) then return end
                if IsPedInVehicle(cache.ped, vehicle, false) then
                    lib.notify({ title = cfg.label, description = 'Exit the vehicle first.', type = 'error' })
                    return
                end
                -- ox_target doesn't reliably pass the bone name in data.bone, so we
                -- find which of the configured targetBones is closest to the player.
                -- This is always accurate regardless of what the callback provides.
                local pedPos   = GetEntityCoords(cache.ped)
                local bestBone = cfg.targetBones and cfg.targetBones[1]
                local bestDist = math.huge
                for _, bn in ipairs(cfg.targetBones or {}) do
                    local bi = GetEntityBoneIndexByName(vehicle, bn)
                    if bi ~= -1 then
                        local bp = GetWorldPositionOfEntityBone(vehicle, bi)
                        local d  = #(pedPos - bp)
                        if d < bestDist then
                            bestDist = d
                            bestBone = bn
                        end
                    end
                end
                FishFoodTruck.entryBone = bestBone
                print(string.format('[FishFoodTruck] onSelect  closestBone=%s  dist=%.2f', tostring(bestBone), bestDist))
                local plate = GetVehicleNumberPlateText(vehicle)
                TriggerServerEvent('fishFoodTruck:requestWork', VehToNet(vehicle), plate)
            end,
        },
        {
            name        = 'fishFoodTruck_tray_' .. model,
            icon        = 'fa-solid fa-utensils',
            label       = 'Browse Serving Tray',
            distance    = 2.5,
            canInteract = function(entity)
                return not IsPedInVehicle(cache.ped, entity, false)
            end,
            onSelect    = function(data)
                local plate = GetVehicleNumberPlateText(data.entity)
                TriggerServerEvent('fishFoodTruck:openTray', plate)
            end,
        },
    })
end

-- ─── Server responses ─────────────────────────────────────────────────────────
RegisterNetEvent('fishFoodTruck:workApproved', function(vehicleNetId, plate, truckKey)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return end

    local _, truckCfg = Config.GetTruck(GetEntityModel(vehicle))
    if not truckCfg then return end

    FishFoodTruck.isWorking = true
    FishFoodTruck.vehicle   = vehicle
    FishFoodTruck.plate     = plate
    FishFoodTruck.truckKey  = truckKey
    FishFoodTruck.truckCfg  = truckCfg

    FishFoodTruck.Attach(vehicle)

    -- Persistent HUD hint shown for the entire working session
    lib.showTextUI('**F5** Menu [**F**] Exit', {
        position = 'bottom-center',
        icon     = 'fa-solid fa-utensils',
    })

    lib.notify({
        title       = truckCfg.label,
        description = 'You started working! Press [F5] or use the truck target to open the work menu.',
        type        = 'success',
    })
    FishFoodTruck.OpenMenu()
end)

RegisterNetEvent('fishFoodTruck:workDenied', function(reason)
    lib.notify({ title = 'Food Truck', description = reason or 'Cannot start working.', type = 'error' })
end)

-- ─── Keybind to reopen work menu ─────────────────────────────────────────────
RegisterCommand('fishFoodTruckMenu', function()
    if FishFoodTruck.isWorking then FishFoodTruck.OpenMenu() end
end, false)
RegisterKeyMapping('fishFoodTruckMenu', 'Food Truck: Open Work Menu', 'keyboard', 'F5')

-- ─── Lifecycle guards ─────────────────────────────────────────────────────────
local function onDeath()
    if not FishFoodTruck.isWorking then return end
    lib.hideTextUI()
    -- On death the ped ragdolls/falls — reset state and unfreeze so the
    -- respawn flow isn't blocked by a frozen ped.
    FishFoodTruck.isWorking = false  -- prevent Reset() from teleporting (ped position belongs to death system)
    local hadVehicle = FishFoodTruck.vehicle
    local hadCfg     = FishFoodTruck.truckCfg
    -- Destroy camera
    if FishFoodTruck.workCam then
        RenderScriptCams(false, false, 0, true, false)
        if DoesCamExist(FishFoodTruck.workCam) then DestroyCam(FishFoodTruck.workCam, false) end
        FishFoodTruck.workCam = nil
    end
    -- Close serving door
    if hadCfg and hadCfg.servingDoor and hadVehicle and DoesEntityExist(hadVehicle) then
        SetVehicleDoorShut(hadVehicle, hadCfg.servingDoor, false)
    end
    -- Always unfreeze and detach regardless of flags
    local ped = cache.ped
    if ped then
        if FishFoodTruck.isAttached then DetachEntity(ped, true, true) end
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, false)
        SetPedCanRagdoll(ped, true)
        -- Don't ClearPedTasks on death — let the ragdoll play out naturally
    end
    -- Notify server
    if hadVehicle and DoesEntityExist(hadVehicle) then
        TriggerServerEvent('fishFoodTruck:stopWork', VehToNet(hadVehicle))
    end
    -- Clear state
    FishFoodTruck.isAttached     = false
    FishFoodTruck.vehicle        = nil
    FishFoodTruck.plate          = nil
    FishFoodTruck.truckKey       = nil
    FishFoodTruck.truckCfg       = nil
    FishFoodTruck.entryCoords    = nil
    FishFoodTruck.entryHeading   = 0.0
    FishFoodTruck.entryBone      = nil
    FishFoodTruck.sellingToNPCs  = false
    FishFoodTruck.npcApproaching = false
end

AddEventHandler('baseevents:onPlayerDied',   onDeath)
AddEventHandler('baseevents:onPlayerKilled', onDeath)

-- Force cleanup when the resource is stopped/restarted via txAdmin or `ensure`.
-- Without this, the ped stays frozen because Lua threads are killed but
-- FreezeEntityPosition is never reversed on the local ped.
AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    lib.hideTextUI()
    local ped = cache.ped
    if not ped then return end
    -- Detach unconditionally and unfreeze so the player is never left stuck.
    DetachEntity(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCanRagdoll(ped, true)
    ClearPedTasks(ped)
    if FishFoodTruck.workCam and DoesCamExist(FishFoodTruck.workCam) then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(FishFoodTruck.workCam, false)
    end
end)

-- Monitor thread: stop work if the truck entity is deleted
CreateThread(function()
    while true do
        Wait(FishFoodTruck.isWorking and 1000 or 3000)
        if FishFoodTruck.isWorking then
            if not FishFoodTruck.vehicle or not DoesEntityExist(FishFoodTruck.vehicle) then
                lib.notify({ title = 'Food Truck', description = 'Truck is gone!', type = 'error' })
                FishFoodTruck.Reset()
            end
        end
    end
end)

-- F key (INPUT_ENTER = 23) exits the working context and returns the player
-- to the spot they stood when they started working.
CreateThread(function()
    while true do
        if not FishFoodTruck.isWorking then
            Wait(500)
        else
            Wait(0)
            DisableControlAction(0, 23, true)
            if IsDisabledControlJustPressed(0, 23) then
                local label = FishFoodTruck.truckCfg and FishFoodTruck.truckCfg.label or 'Food Truck'
                FishFoodTruck.Reset()
                lib.notify({ title = label, description = 'Stopped working.', type = 'info' })
            end
        end
    end
end)
