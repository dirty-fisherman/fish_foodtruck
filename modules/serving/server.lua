-- Serving stash module - Server side

-- Event to open serving stash
RegisterNetEvent('fish_foodtruck:openServingStash', function(plate)
    local source = source
    -- Trim plate to remove whitespace
    plate = plate:gsub("%s+", "")
    local stashId = GetOrCreateServingStash(plate)
    exports.ox_inventory:forceOpenInventory(source, 'stash', stashId)
end)
