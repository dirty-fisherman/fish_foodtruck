-- Shared server utilities

-- Function to get or create serving stash for a vehicle
function GetOrCreateServingStash(plate)
    -- Trim plate to remove whitespace
    plate = plate:gsub("%s+", "")
    local stashId = string.format('%s_%s', Config.ServingStash.id, plate)
    exports.ox_inventory:RegisterStash(stashId, Config.ServingStash.label, Config.ServingStash.slots, Config.ServingStash.weight, false)
    return stashId
end
