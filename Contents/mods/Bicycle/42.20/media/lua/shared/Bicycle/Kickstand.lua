local BicycleUtils = require("Bicycle/Utils")

---@class BicycleKickstand
local BicycleKickstand = {}

---@param bikeItem InventoryItem|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param partType string
local function removeKickstandPart(bikeItem, player, partType)
    if not (bikeItem and bikeItem.getWeaponPart) then
        return
    end

    local part = bikeItem:getWeaponPart(partType)
    if not part then
        return
    end

    if bikeItem.detachWeaponPart then
        bikeItem:detachWeaponPart(player, part)
    end

    BicycleUtils.removeItemFromContainer(part)

    local worldItem = part.getWorldItem and part:getWorldItem() or nil
    if worldItem and worldItem.removeFromWorld then
        worldItem:removeFromWorld()
    end
    if worldItem and worldItem.removeFromSquare then
        worldItem:removeFromSquare()
    end
end

---@param bikeItem InventoryItem|nil
---@param fullType string
local function attachKickstandPart(bikeItem, fullType)
    if not (bikeItem and bikeItem.attachWeaponPart and instanceItem) then
        return
    end

    local part = instanceItem(fullType)
    if part then
        bikeItem:attachWeaponPart(part, true)
    end
end

---@param bikeItem InventoryItem|nil
---@return string|nil
---@nodiscard
function BicycleKickstand.getCurrentState(bikeItem)
    if not bikeItem or not bikeItem.getWeaponPart then
        return nil
    end

    local hasKickstandUp = bikeItem:getWeaponPart("KickstandUp") ~= nil
    local hasKickstandDown = bikeItem:getWeaponPart("KickstandDown") ~= nil

    if hasKickstandDown then
        return "down"
    end
    if hasKickstandUp then
        return "up"
    end

    return nil
end

---@param bikeItem InventoryItem|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param targetState string
function BicycleKickstand.ensureState(bikeItem, player, targetState)
    if not bikeItem then
        return
    end

    local hasKickstandUp = bikeItem.getWeaponPart and bikeItem:getWeaponPart("KickstandUp") ~= nil
    local hasKickstandDown = bikeItem.getWeaponPart and bikeItem:getWeaponPart("KickstandDown") ~= nil

    if not hasKickstandUp and not hasKickstandDown then
        return
    end

    if targetState == "up" then
        if hasKickstandUp then
            if hasKickstandDown then
                removeKickstandPart(bikeItem, player, "KickstandDown")
            end
            return
        end

        if not hasKickstandDown then
            return
        end

        removeKickstandPart(bikeItem, player, "KickstandDown")
        attachKickstandPart(bikeItem, "Bicycle.Bicycle_KickstandUp")
        return
    end

    if hasKickstandDown then
        if hasKickstandUp then
            removeKickstandPart(bikeItem, player, "KickstandUp")
        end
        return
    end

    if not hasKickstandUp then
        return
    end

    removeKickstandPart(bikeItem, player, "KickstandUp")
    attachKickstandPart(bikeItem, "Bicycle.Bicycle_KickstandDown")
end

return BicycleKickstand
