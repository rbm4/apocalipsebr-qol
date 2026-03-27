local function updateLocation(old_loc, new_loc)
    local items = getAllItemsForBodyLocation(old_loc:toString())
    print("[ZWatchSlots] Patching " .. #items .. " items from " .. tostring(old_loc) .. " to " .. tostring(new_loc) .. ".")
    for _, pitem in ipairs(items) do
        local item = ScriptManager.instance:FindItem(pitem)
        if item and item:isBodyLocation(old_loc) and item.setBodyLocation then
            print("[ZWatchSlots] Patching " .. tostring(item))
            item:setBodyLocation(new_loc)
        end
    end
end

Events.OnGameBoot.Add( function()
    updateLocation(ItemBodyLocation.LEFT_WRIST, ItemBodyLocation.LEFT_WATCH)
    updateLocation(ItemBodyLocation.RIGHT_WRIST, ItemBodyLocation.RIGHT_WATCH)
end)
