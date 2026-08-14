local CommonMethods = require("TOC/CommonMethods")
local StaticData = require("TOC/StaticData")
local DataController = require("TOC/Controllers/DataController")
local CachedDataHandler = require("TOC/Handlers/CachedDataHandler")
local CommandsData = require("TOC/CommandsData")
require("TOC/BodyLocations")

local OverridenMethodsArchive = require("TOC/OverridenMethodsArchive")
-------------------------

LuaEventManager.AddEvent("OnProsthesisUnequipped")  -- args: playerObj, limbName

---@class ProsthesisHandler
local ProsthesisHandler = {}

local bodylocArmProstBaseline = "toc:armprost_"
--local bodyLocLegProst = "TOC_LegProst"

local function HasAnyCachedLimb(cache)
    if not cache then return false end
    for _, _ in pairs(cache) do
        return true
    end
    return false
end

---Check if the following item is a prosthesis or not
---@param item InventoryItem?
---@return boolean
function ProsthesisHandler.CheckIfProst(item)
    -- TODO Won't be correct when prost for legs are gonna be in
    if item == nil or item:getBodyLocation() == nil then
        TOC_DEBUG.print("Not prost or no body location")
        return false
    end
    return string.contains(tostring(item:getBodyLocation()):lower(), bodylocArmProstBaseline)
end

---Get the grouping for the prosthesis
---@param item InventoryItem
---@return string
function ProsthesisHandler.GetGroup(item)
    local fullType = item:getFullType()
    local side = CommonMethods.GetSide(fullType)

    local bodyLocation = item:getBodyLocation()
    local position
    if string.contains(tostring(bodyLocation):lower(), bodylocArmProstBaseline) then
        position = "Top_"
    else
        TOC_DEBUG.print("No prosthesis position for body location " .. tostring(bodyLocation) .. " on " .. tostring(fullType))
        position = nil
    end

    if not position then return nil end

    local index = position .. side
    local group = StaticData.AMP_GROUPS_IND_STR[index]
    if not group then
        TOC_DEBUG.print("No prosthesis group for index " .. tostring(index) .. " on " .. tostring(fullType))
    end
    return group
end

---@param username string
---@param recalculate boolean?
function ProsthesisHandler.EnsureHighestAmputatedLimbs(username, recalculate)
    local highestAmputatedLimbs = CachedDataHandler.GetHighestAmputatedLimbs(username)
    if HasAnyCachedLimb(highestAmputatedLimbs) and recalculate ~= true then
        return highestAmputatedLimbs
    end

    if isClient() then
        TOC_DEBUG.print("Missing prosthesis cache for " .. tostring(username) .. ", requesting recalculation from server")
        CachedDataHandler.RequestFromServer(username, true)
        return highestAmputatedLimbs
    end

    TOC_DEBUG.print("Missing prosthesis cache for " .. tostring(username) .. ", recalculating locally")
    CachedDataHandler.CalculateHighestAmputatedLimbs(username)
    return CachedDataHandler.GetHighestAmputatedLimbs(username)
end

---Check if a prosthesis is equippable. It depends whether the player has a cut limb or not on that specific side.
---@param fullType string
---@param character IsoPlayer?
---@return boolean, string?
function ProsthesisHandler.CheckIfEquippable(fullType, character)
    local side = CommonMethods.GetSide(fullType)

    character = character or getPlayer()
    if not character then return false, "no character" end

    local username = character:getUsername()
    local dcInst = DataController.GetInstance(username)
    if not dcInst or not dcInst:getIsDataReady() then
        TOC_DEBUG.print("Cannot equip prosthesis " .. tostring(fullType) .. ": DataController not ready for " .. tostring(username))
        return false, "data not ready"
    end

    local highestAmputatedLimbs = ProsthesisHandler.EnsureHighestAmputatedLimbs(username)

    if highestAmputatedLimbs then
        local hal = highestAmputatedLimbs[side]
        if hal then
            TOC_DEBUG.print("Found acceptable limb to use prosthesis => " .. tostring(hal))
            return true, nil
        end
    end

    TOC_DEBUG.print("Cannot equip prosthesis " .. tostring(fullType) .. ": no visible amputated limb found for side " .. tostring(side))
    return false, "no amputated limb on this side"
end

---Handle equipping or unequipping prosthetics
---@server
---@param character IsoPlayer
---@param item InventoryItem
---@param isEquipping boolean
---@return boolean
function ProsthesisHandler.SearchAndSetupProsthesis(character, item, isEquipping)
    if not ProsthesisHandler.CheckIfProst(item) then return false end

    local username = character:getUsername()

    local group = ProsthesisHandler.GetGroup(item)
    if not group then return false end

    TOC_DEBUG.print("Setup Prosthesis => " .. group .. " - is equipping? " .. tostring(isEquipping))
    local dcInst = DataController.GetInstance(username)
    if not dcInst or not dcInst:getIsDataReady() then
        TOC_DEBUG.print("Cannot setup prosthesis for " .. tostring(username) .. ": DataController not ready")
        return false
    end

    dcInst:setIsProstEquipped(group, isEquipping)
    dcInst:apply(character)
    return true
end

---@param character IsoPlayer
---@param item InventoryItem?
---@param isEquipping boolean
---@return boolean
function ProsthesisHandler.ApplyEquipState(character, item, isEquipping)
    if not ProsthesisHandler.CheckIfProst(item) then return false end

    if isClient() then
        sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelaySetProsthesisEquipped, {
            itemFullType = item:getFullType(),
            itemId = item:getID(),
            isEquipping = isEquipping
        })
        return true
    end

    return ProsthesisHandler.SearchAndSetupProsthesis(character, item, isEquipping)
end

function ProsthesisHandler.SayCantEquip(character)
    character = character or getPlayer()
    if character then
        character:Say(getText("UI_Say_CantEquip"))
    end
end

function ProsthesisHandler.Validate(item, isEquippable, character)
    local isProst = ProsthesisHandler.CheckIfProst(item)
    if not isProst then return isEquippable, nil end

    local fullType = item:getFullType() -- use fulltype for side
    if isEquippable then
        local reason
        isEquippable, reason = ProsthesisHandler.CheckIfEquippable(fullType, character)
        if not isEquippable then
            TOC_DEBUG.print("TOC rejected prosthesis equip for " .. tostring(fullType) .. ": " .. tostring(reason))
            return false, reason
        end
    else
        TOC_DEBUG.print("Vanilla rejected prosthesis equip for " .. tostring(fullType))
        return false, "vanilla validation failed"
    end

    return true, nil
end



-------------------------
--* Overrides *--


local og_ISWearClothing_isValid = ISWearClothing.isValid
---@diagnostic disable-next-line: duplicate-set-field
function ISWearClothing:isValid()
    local isEquippable = og_ISWearClothing_isValid(self)
    local result, reason = ProsthesisHandler.Validate(self.item, isEquippable, self.character)
    if not result and reason and not self.tocCantEquipMessageShown then
        ProsthesisHandler.SayCantEquip(self.character)
        self.tocCantEquipMessageShown = true
    end
    return result
end

local og_ISWearClothing_complete = ISWearClothing.complete
---@diagnostic disable-next-line: duplicate-set-field
function ISWearClothing:complete()
    local result = og_ISWearClothing_complete(self)
    if result then
        ProsthesisHandler.ApplyEquipState(self.character, self.item, true)
    end
    return result
end


local og_ISClothingExtraAction_isValid = OverridenMethodsArchive.Save("ISClothingExtraAction_isValid", ISClothingExtraAction.isValid)

---@diagnostic disable-next-line: duplicate-set-field
function ISClothingExtraAction:isValid()
    local isEquippable = og_ISClothingExtraAction_isValid(self)
    -- self.extra is a string, not the item
    local testItem = instanceItem(self.extra)
    local result, reason = ProsthesisHandler.Validate(testItem, isEquippable, self.character)
    if not result and reason and not self.tocCantEquipMessageShown then
        ProsthesisHandler.SayCantEquip(self.character)
        self.tocCantEquipMessageShown = true
    end
    return result
end

local og_ISClothingExtraAction_complete = OverridenMethodsArchive.Save("ISClothingExtraAction_complete", ISClothingExtraAction.complete)
---@diagnostic disable-next-line: duplicate-set-field
function ISClothingExtraAction:complete()
    local extraItem = instanceItem(self.extra)
    local result = og_ISClothingExtraAction_complete(self)
    if result then
        local equippedItem = self.character:getWornItem(extraItem:getBodyLocation())
        ProsthesisHandler.ApplyEquipState(self.character, equippedItem or extraItem, true)
    end

    return result
end

local og_ISUnequipAction_complete = ISUnequipAction.complete
---@diagnostic disable-next-line: duplicate-set-field
function ISUnequipAction:complete()
    if self.item == nil then
        TOC_DEBUG.print("Skipping ISUnequipAction.complete for nil item")
        return false
    end

    local result = og_ISUnequipAction_complete(self)
    if not result then return result end

    local isProst = ProsthesisHandler.ApplyEquipState(self.character, self.item, false)

    if isProst then
        -- we need to fetch the limbname associated to the prosthesis
        local side = CommonMethods.GetSide(self.item:getFullType())
        local highestAmputatedLimbs = CachedDataHandler.GetHighestAmputatedLimbs(self.character:getUsername())
        if highestAmputatedLimbs then
            local hal = highestAmputatedLimbs[side]
            if hal then
                TOC_DEBUG.print("Triggered OnProsthesisUnequipped")
                triggerEvent("OnProsthesisUnequipped", self.character, hal)
            end
        end
    end

    return result
end

return ProsthesisHandler
