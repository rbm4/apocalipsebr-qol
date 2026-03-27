-- required for 42.13+
ItemBodyLocation.LEFT_WATCH = ItemBodyLocation.register("ZWatchSlots:LeftWatch")
ItemBodyLocation.RIGHT_WATCH = ItemBodyLocation.register("ZWatchSlots:RightWatch")

local group = BodyLocations.getGroup("Human")
if group then
    group:getOrCreateLocation(ItemBodyLocation.LEFT_WATCH)
    group:getOrCreateLocation(ItemBodyLocation.RIGHT_WATCH)
else
    print("[?] BodyLocations group 'Human' not found.")
end
