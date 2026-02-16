-- Serving stash module - Client side

-- Setup ox_target for all food truck models
CreateThread(function()
    for model, config in pairs(Config.TruckTypes) do
        exports.ox_target:addModel(model, {
            {
                name = 'foodtruck_serving_' .. model,
                icon = 'fas fa-utensils',
                label = 'Open Serving Hatch',
                onSelect = function(data)
                    local vehicle = data.entity
                    local plate = GetVehicleNumberPlateText(vehicle)
                    TriggerServerEvent('fish_foodtruck:openServingStash', plate)
                end,
                distance = 2.5
            }
        })
    end
end)
