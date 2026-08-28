local BicycleKickstand = require("Bicycle/Kickstand")

---@class BicycleMigration
local BicycleMigration = {}

---@param bikeItem InventoryItem|nil
---@param player IsoPlayer|IsoGameCharacter|nil
function BicycleMigration.normalizeKickstandState(bikeItem, player)
    if not bikeItem then
        return
    end

    if not bikeItem.getWeaponPart then
        return
    end

    local hasKickstandUp = bikeItem:getWeaponPart("KickstandUp") ~= nil
    local hasKickstandDown = bikeItem:getWeaponPart("KickstandDown") ~= nil

    if hasKickstandUp and hasKickstandDown then
        BicycleKickstand.ensureState(bikeItem, player, "down")
        return
    end

    if not hasKickstandUp and not hasKickstandDown then
        return
    end

    if hasKickstandDown then
        BicycleKickstand.ensureState(bikeItem, player, "down")
    else
        BicycleKickstand.ensureState(bikeItem, player, "up")
    end
end

return BicycleMigration
