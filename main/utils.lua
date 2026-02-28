-- Server utilities

-- Register and return the serving stash ID for a vehicle plate
function GetOrCreateServingStash(plate)
    plate = plate:gsub("%s+", "")
    local stashId = string.format('%s_%s', Config.ServingStash.id, plate)
    exports.ox_inventory:RegisterStash(stashId, Config.ServingStash.label, Config.ServingStash.slots, Config.ServingStash.weight, false)
    return stashId
end

-- Return the stash ID for a plate without re-registering (assumes already registered at work start)
function GetServingStashId(plate)
    plate = plate:gsub("%s+", "")
    return string.format('%s_%s', Config.ServingStash.id, plate)
end
