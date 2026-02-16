-- Crafting module - Client side

-- Function to open crafting submenu
local function OpenCraftingSubmenu()
    -- Build recipe options
    local recipeOptions = {}
    for _, recipe in ipairs(State.currentTruckConfig.recipes) do
        table.insert(recipeOptions, {
            title = recipe.label,
            description = recipe.description,
            icon = 'utensils',
            onSelect = function()
                TriggerServerEvent('fish_foodtruck:craftItem', State.currentPlate, recipe.id, State.currentTruckType)
            end
        })
    end

    lib.registerContext({
        id = 'foodtruck_craft_submenu',
        title = 'Make Food Items',
        menu = 'foodtruck_menu',
        options = recipeOptions
    })

    lib.showContext('foodtruck_craft_submenu')
end

-- Function to open crafting menu
function OpenCraftingMenu()
    if not State.isWorking then
        lib.notify({
            title = 'Food Truck',
            description = 'You need to start working first!',
            type = 'error'
        })
        return
    end

    local inTruck, vehicle, truckType, truckConfig = IsInFoodTruck()
    if not inTruck then
        lib.notify({
            title = 'Food Truck',
            description = 'You need to be in a food truck!',
            type = 'error'
        })
        return
    end

    -- Build main menu options
    local menuOptions = {
        {
            title = 'Craft Items',
            description = 'Make food items from ingredients',
            icon = 'utensils',
            onSelect = function()
                OpenCraftingSubmenu()
            end
        },
        {
            title = State.sellingToNPCs and 'Stop Local Sales' or 'Start Local Sales',
            description = State.sellingToNPCs and 'Stop selling to Locals' or 'Locals will approach and buy food',
            icon = 'users',
            onSelect = function()
                State.sellingToNPCs = not State.sellingToNPCs
                
                if State.sellingToNPCs then
                    lib.notify({
                        title = State.currentTruckConfig.label,
                        description = 'Now selling to nearby locals!',
                        type = 'success'
                    })
                else
                    lib.notify({
                        title = State.currentTruckConfig.label,
                        description = 'Stopped selling to locals',
                        type = 'info'
                    })
                end
                
                -- Refresh menu to update button text
                Wait(100)
                OpenCraftingMenu()
            end
        },
        {
            title = 'Open Serving Stash',
            description = 'Access the serving window inventory',
            icon = 'window-restore',
            onSelect = function()
                TriggerServerEvent('fish_foodtruck:openServingStash', State.currentPlate)
            end
        },
        {
            title = 'Stop Working',
            description = 'Exit working mode',
            icon = 'times',
            onSelect = function()
                ResetWorkingState()
                lib.notify({
                    title = 'Food Truck',
                    description = 'You stopped working',
                    type = 'info'
                })
            end
        }
    }

    lib.registerContext({
        id = 'foodtruck_menu',
        title = State.currentTruckConfig.label,
        options = menuOptions
    })

    lib.showContext('foodtruck_menu')
end

-- Callback for progress bar
lib.callback.register('fish_foodtruck:clientProgressBar', function(duration, label)
    return lib.progressCircle({
        duration = duration,
        label = label or 'Preparing food...',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_player'
        },
    })
end)

-- Event to reopen menu after crafting
RegisterNetEvent('fish_foodtruck:reopenCraftingMenu', function()
    -- Only reopen if still working and in a food truck
    if State.isWorking then
        local inTruck = IsInFoodTruck()
        if inTruck then
            Wait(100) -- Small delay for smoother UX
            OpenCraftingMenu()
        end
    end
end)
