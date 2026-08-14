local CommonMethods = require("TOC/CommonMethods")
local StaticData = require("TOC/StaticData")
local DataController = require("TOC/Controllers/DataController")
local CachedDataHandler = require("TOC/Handlers/CachedDataHandler")
local CommandsData = require("TOC/CommandsData")

local OverridenMethodsArchive = require("TOC/OverridenMethodsArchive")
-------------------------

LuaEventManager.AddEvent("OnProsthesisUnequipped")  -- args: playerObj, limbName

---@class ProsthesisHandler
local ProsthesisHandler = {}

local bodylocArmProstBaseline = "toc:armprost_"
--local bodyLocLegProst = "TOC_LegProst"

---Check if the following item is a prosthesis or not
---@param item InventoryItem?
---@return boolean
function ProsthesisHandler.CheckIfProst(item)
    -- TODO Won't be correct when prost for legs are gonna be in
    if item == nil or item:getBodyLocation() == nil then
        --TOC_DEBUG.print("Not prost or no body location")
        return false
    end
    --TOC_DEBUG.print("CheckIfProst")
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
        TOC_DEBUG.print("Something is wrong, no position in this item")
        position = nil
    end

    local index = position .. side
    local group = StaticData.AMP_GROUPS_IND_STR[index]
    return group
end

---Check if a prosthesis is equippable. It depends whether the player has a cut limb or not on that specific side. There's an exception for Upper arm, obviously
---@param fullType string
---@param character IsoPlayer?
---@return boolean
function ProsthesisHandler.CheckIfEquippable(fullType, character)
    --TOC_DEBUG.print("Current item is a prosthesis")
    local side = CommonMethods.GetSide(fullType)
    --TOC_DEBUG.print("Checking side: " .. tostring(side))

    character = character or getPlayer()
    if not character then return false end

    local highestAmputatedLimbs = CachedDataHandler.GetHighestAmputatedLimbs(character:getUsername())

    --TOC_DEBUG.print("highestAmputatedLimbs")
    --TOC_DEBUG.printTable(highestAmputatedLimbs)
    if highestAmputatedLimbs then
        local hal = highestAmputatedLimbs[side]
        if hal and not string.contains(hal, "UpperArm") then
            TOC_DEBUG.print("Found acceptable limb to use prosthesis => " .. tostring(hal))
            return true
        end
    end

    -- No acceptable cut limbs
    return false
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
    TOC_DEBUG.print("Setup Prosthesis => " .. group .. " - is equipping? " .. tostring(isEquipping))
    local dcInst = DataController.GetInstance(username)
    if not dcInst then return false end     -- DC not ready yet, bail safely
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
            isEquipping = isEquipping
        })
        return true
    end

    return ProsthesisHandler.SearchAndSetupProsthesis(character, item, isEquipping)
end

function ProsthesisHandler.Validate(item, isEquippable, character)
    local isProst = ProsthesisHandler.CheckIfProst(item)
    if not isProst then return isEquippable end

    local fullType = item:getFullType() -- use fulltype for side
    if isEquippable then
        isEquippable = ProsthesisHandler.CheckIfEquippable(fullType, character)
    else
        TOC_DEBUG.print("Should say cant equip")
        getPlayer():Say(getText("UI_Say_CantEquip"))        -- FIX not working
    end

    return isEquippable
end



-------------------------
--* Overrides *--


local og_ISWearClothing_isValid = ISWearClothing.isValid
---@diagnostic disable-next-line: duplicate-set-field
function ISWearClothing:isValid()
    --TOC_DEBUG.print("ISWearClothing override")
    local isEquippable = og_ISWearClothing_isValid(self)
    return ProsthesisHandler.Validate(self.item, isEquippable, self.character)
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
    return ProsthesisHandler.Validate(testItem, isEquippable, self.character)
end

local og_ISClothingExtraAction_complete = OverridenMethodsArchive.Save("ISClothingExtraAction_complete", ISClothingExtraAction.complete)
---@diagnostic disable-next-line: duplicate-set-field
function ISClothingExtraAction:complete()
    local extraItem = instanceItem(self.extra)
    local result = og_ISClothingExtraAction_complete(self)
    if result then
        ProsthesisHandler.ApplyEquipState(self.character, extraItem, true)
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
