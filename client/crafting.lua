-- Crafting menu and progress bar logic.

local COOK_DICT = 'amb@prop_human_bbq@male@idle_a'
local COOK_CLIP = 'idle_a'

local function playCookAnim()
    local ped = cache.ped
    if not ped then return end
    RequestAnimDict(COOK_DICT)
    local t = GetGameTimer() + 1000
    while not HasAnimDictLoaded(COOK_DICT) and GetGameTimer() < t do Wait(10) end
    if HasAnimDictLoaded(COOK_DICT) then
        TaskPlayAnim(ped, COOK_DICT, COOK_CLIP, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
end

local function stopCookAnim()
    local ped = cache.ped
    if not ped then return end
    StopAnimTask(ped, COOK_DICT, COOK_CLIP, -8.0)
    -- Resume idle standing loop while still attached
    if FishFoodTruck.isAttached and HasAnimDictLoaded('amb@world_human_stand_impatient@male@base') then
        TaskPlayAnim(ped, 'amb@world_human_stand_impatient@male@base', 'base', 2.0, -2.0, -1, 1, 0.0, false, false, false)
    end
end

-- Server triggers this to run the progress circle on our client and returns bool
lib.callback.register('fishFoodTruck:progressBar', function(duration, label)
    playCookAnim()
    local ok = lib.progressCircle({
        duration     = duration,
        label        = label or 'Preparing...',
        position     = 'bottom',
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
    })
    stopCookAnim()
    return ok
end)

-- ─── Craft sub-menu ───────────────────────────────────────────────────────────
local function openCraftSubmenu()
    local options = {}
    for _, item in ipairs(FishFoodTruck.truckCfg.items) do
        local ingList = {}
        for _, ing in ipairs(item.ingredients) do
            ingList[#ingList + 1] = ing.amount .. 'x ' .. ing.item
        end
        options[#options + 1] = {
            title       = item.label,
            description = 'Requires: ' .. table.concat(ingList, ', '),
            icon        = 'utensils',
            onSelect    = function()
                TriggerServerEvent('fishFoodTruck:craftItem', item.id)
            end,
        }
    end
    lib.registerContext({ id = 'fishFoodTruck_craft', title = 'Craft Food', menu = 'fishFoodTruck_main', options = options })
    lib.showContext('fishFoodTruck_craft')
end

-- ─── Main work menu ───────────────────────────────────────────────────────────
function FishFoodTruck.OpenMenu()
    if not FishFoodTruck.isWorking then return end

    local options = {
        {
            title       = 'Craft Items',
            description = 'Make food from your ingredients',
            icon        = 'utensils',
            onSelect    = openCraftSubmenu,
        },
        {
            title       = FishFoodTruck.sellingToNPCs and 'Stop Selling to Locals' or 'Start Selling to Locals',
            description = FishFoodTruck.sellingToNPCs and 'Stop selling to passing NPCs' or 'NPCs will approach and buy food',
            icon        = 'users',
            onSelect    = function()
                FishFoodTruck.sellingToNPCs = not FishFoodTruck.sellingToNPCs
                lib.notify({
                    title       = FishFoodTruck.truckCfg.label,
                    description = FishFoodTruck.sellingToNPCs and 'Now selling to locals!' or 'Stopped selling to locals.',
                    type        = FishFoodTruck.sellingToNPCs and 'success' or 'info',
                })
                Wait(50)
                FishFoodTruck.OpenMenu()
            end,
        },
        {
            title       = 'Open Serving Tray',
            description = 'Place cooked food here for player sales',
            icon        = 'window-restore',
            onSelect    = function()
                TriggerServerEvent('fishFoodTruck:openTray', FishFoodTruck.plate)
            end,
        },
        {
            title    = 'Stop Working',
            icon     = 'times',
            onSelect = function()
                local label = FishFoodTruck.truckCfg and FishFoodTruck.truckCfg.label or 'Food Truck'
                FishFoodTruck.Reset()
                lib.notify({ title = label, description = 'Stopped working.', type = 'info' })
            end,
        },
    }

    lib.registerContext({ id = 'fishFoodTruck_main', title = FishFoodTruck.truckCfg.label, options = options })
    lib.showContext('fishFoodTruck_main')
end

-- Server tells client to reopen the menu after crafting finishes
RegisterNetEvent('fishFoodTruck:reopenMenu', function()
    if FishFoodTruck.isWorking then
        Wait(100)
        FishFoodTruck.OpenMenu()
    end
end)
