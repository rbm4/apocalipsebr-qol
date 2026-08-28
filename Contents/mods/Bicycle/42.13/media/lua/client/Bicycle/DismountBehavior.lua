local BicycleDropBehavior = require("Bicycle/DropBehavior")
local BicycleKickstand = require("Bicycle/Kickstand")

local BicycleDismountBehavior = {}

---@param bikeItem InventoryItem|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param targetState string
function BicycleDismountBehavior.ensureKickstandState(bikeItem, player, targetState)
    if not bikeItem then
        return
    end

    if isClient() then
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.requestKickstandState then
            Bicycle.ClientSync.requestKickstandState(bikeItem, targetState)
        end
        return
    elseif isServer() then
        BicycleKickstand.ensureState(bikeItem, player, targetState)
        return
    else
        BicycleKickstand.ensureState(bikeItem, player, targetState)
    end
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param dismountData table|nil
function BicycleDismountBehavior.applyDroppedBikeTransform(player, bikeItem, dismountData)
    BicycleDropBehavior.applyDroppedBikeTransform(player, bikeItem, dismountData)
end

return BicycleDismountBehavior
