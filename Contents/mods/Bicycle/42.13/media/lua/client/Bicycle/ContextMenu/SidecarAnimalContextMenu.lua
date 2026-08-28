require("Bicycle/BicycleCore")
require("ISUI/Animal/ISAnimalContextMenu")

if isServer() then
    return
end

local AttachmentActionUtils = require("Bicycle/AttachmentActionUtils")
local BicycleMenu = require("Bicycle/BicycleMenu")
local BicycleUtils = require("Bicycle/Utils")
local SidecarAnimal = require("Bicycle/SidecarAnimal")
local BicycleStowAnimalAction = require("Bicycle/TimedAction/BicycleStowAnimalAction")
local BicycleReleaseAnimalAction = require("Bicycle/TimedAction/BicycleReleaseAnimalAction")
local Core = Bicycle.Core

local SIDECAR_FULL_TYPE = "Bicycle.Sidecar"

local REACH_RADIUS_SQ = 9

---@param player IsoPlayer
---@param bikeItem InventoryItem
---@return boolean
---@nodiscard
local function isBikeReachableForSidecar(player, bikeItem)
    if not (player and bikeItem) then
        return false
    end
    if player:getInventory():contains(bikeItem) then
        return true
    end
    local worldItem = bikeItem:getWorldItem()
    if not worldItem then
        return false
    end
    local bikeSquare = worldItem:getSquare()
    local playerSquare = player:getSquare()
    if not (bikeSquare and playerSquare) then
        return false
    end
    if bikeSquare:getZ() ~= playerSquare:getZ() then
        return false
    end
    local dx = bikeSquare:getX() - playerSquare:getX()
    local dy = bikeSquare:getY() - playerSquare:getY()
    return dx * dx + dy * dy <= REACH_RADIUS_SQ
end

---@param player IsoPlayer
---@return InventoryItem|nil
---@nodiscard
local function findReachableSidecarBike(player)
    local primary = player:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primary) and primary:getWeaponPart("Sidecar") then
        return primary
    end

    local inventory = player:getInventory()
    local bikeTypes = BicycleUtils.getBicycleTypes()
    for i = 1, #bikeTypes do
        local items = inventory:getAllTypeRecurse(bikeTypes[i])
        for j = 0, items:size() - 1 do
            local item = items:get(j)
            if item:getWeaponPart("Sidecar") then
                return item
            end
        end
    end

    local square = player:getSquare()
    if not square then
        return nil
    end
    local worldObj = BicycleMenu.findNearestBicycleWithAttachments(square, player)
    if worldObj then
        local item = worldObj:getItem()
        if BicycleUtils.isBicycleItem(item) and item:getWeaponPart("Sidecar") and isBikeReachableForSidecar(player, item) then
            return item
        end
    end

    return nil
end

---@param player IsoPlayer
---@param bikeItem InventoryItem
---@param animalItem InventoryItem
local function queueStowHeldAnimal(player, bikeItem, animalItem)
    local bikeSquare = AttachmentActionUtils.resolveBikeSquare(player, bikeItem)
    local action = BicycleStowAnimalAction:newFromHeld(player, bikeItem, animalItem, bikeSquare)
    ISTimedActionQueue.add(action)
end

---@param player IsoPlayer
---@param bikeItem InventoryItem
---@param worldAnimal IsoAnimal
local function queueStowWorldAnimal(player, bikeItem, worldAnimal)
    local bikeSquare = AttachmentActionUtils.resolveBikeSquare(player, bikeItem)
    local animalSquare = worldAnimal:getSquare()
    if animalSquare and luautils.walkAdj(player, animalSquare) then
        local action = BicycleStowAnimalAction:newFromWorldAnimal(player, bikeItem, worldAnimal, bikeSquare)
        ISTimedActionQueue.add(action)
    end
end

---@param player IsoPlayer
---@param bikeItem InventoryItem
local function queueReleaseAnimal(player, bikeItem)
    local bikeSquare = AttachmentActionUtils.resolveBikeSquare(player, bikeItem)
    if bikeSquare then
        luautils.walkAdj(player, bikeSquare)
    end
    local action = BicycleReleaseAnimalAction:new(player, bikeItem, bikeSquare)
    ISTimedActionQueue.add(action)
end

---@param player IsoPlayer
---@param animalItem InventoryItem
---@return InventoryItem|nil
---@nodiscard
local function findBikeFromSidecarHosting(player, animalItem)
    local container = animalItem:getContainer()
    if not container then
        return nil
    end
    local containingItem = container:getContainingItem()
    if not containingItem then
        return nil
    end
    if containingItem:getFullType() ~= SIDECAR_FULL_TYPE then
        return nil
    end
    local md = containingItem:getModData()
    if not (md and md.Bicycle and md.Bicycle.container) then
        return nil
    end
    local bikeId = tonumber(md.Bicycle.container.bikeItemId)
    if not bikeId then
        return nil
    end
    local bikeItem = Core.findItemById(player, bikeId, nil)
    if not BicycleUtils.isBicycleItem(bikeItem) then
        return nil
    end
    return bikeItem
end

-- Vanilla short-circuits the inventory context menu for AnimalInventoryItem in
-- ISInventoryPaneContextMenu.lua:141, so OnFillInventoryObjectContextMenu never
-- fires for held animals. Wrap the canonical entry point instead.
local originalDoInventoryMenu = AnimalContextMenu.doInventoryMenu
AnimalContextMenu.doInventoryMenu = function(playerNum, context, animalInv, test)
    local result = originalDoInventoryMenu(playerNum, context, animalInv, test)

    if test then
        return result
    end

    local player = getSpecificPlayer(playerNum)
    if not player then
        return result
    end

    if not SidecarAnimal.isAllowedAnimalItem(animalInv) then
        return result
    end

    -- If the animal item lives inside a sidecar, disable the vanilla "Drop"
    -- option. Plain Drop only removes the item and lets the Java side spawn
    -- the IsoAnimal, leaving the weapon part orphaned on the bike. The user
    -- must use the dedicated "Release animal from sidecar" option to keep
    -- the dual-representation in sync.
    if findBikeFromSidecarHosting(player, animalInv) then
        local dropOption = context:getOptionFromName(getText("ContextMenu_Drop"))
        if dropOption then
            dropOption.notAvailable = true
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip:setName(getText("IGUI_Bicycle_Sidecar_UseReleaseInstead"))
            dropOption.toolTip = tooltip
        end
        return result
    end

    local bikeItem = findReachableSidecarBike(player)
    if not bikeItem then
        return result
    end

    if SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
        return result
    end

    local option = context:addOption(
        getText("ContextMenu_Bicycle_PlaceAnimalInSidecar"),
        nil,
        function()
            queueStowHeldAnimal(player, bikeItem, animalInv)
        end
    )
    local icon = getTexture("media/ui/Bicycle/SidecarStow.png")
    if icon then
        option.iconTexture = icon
    end
    return result
end

---@param player IsoPlayer
---@param context ISContextMenu
---@param animal IsoAnimal
local function addWorldAnimalSidecarOption(player, context, animal)
    if not animal then
        return
    end

    local animalType = animal:getAnimalType()
    if not SidecarAnimal.isAllowedAnimalType(animalType) then
        return
    end

    local bikeItem = findReachableSidecarBike(player)
    if not bikeItem then
        return
    end

    if SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
        return
    end

    local option = context:addOption(
        getText("ContextMenu_Bicycle_PutAnimalInSidecar"),
        nil,
        function()
            queueStowWorldAnimal(player, bikeItem, animal)
        end
    )
    local icon = getTexture("media/ui/Bicycle/SidecarStow.png")
    if icon then
        option.iconTexture = icon
    end
end

---@param playerNum number
---@param context ISContextMenu
---@param animals table
local function onAnimalClickedForSidecar(playerNum, context, animals)
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    for i = 1, #animals do
        addWorldAnimalSidecarOption(player, context, animals[i])
    end
end

Events.OnClickedAnimalForContext.Add(onAnimalClickedForSidecar)

---@param player IsoPlayer
---@return InventoryItem|nil
---@nodiscard
local function findHeldAllowedAnimal(player)
    local primary = player:getPrimaryHandItem()
    if SidecarAnimal.isAllowedAnimalItem(primary) then
        return primary
    end
    local secondary = player:getSecondaryHandItem()
    if SidecarAnimal.isAllowedAnimalItem(secondary) then
        return secondary
    end
    return nil
end

---@param player IsoPlayer
---@param radiusSq number
---@return IsoAnimal[]
---@nodiscard
local function findNearbyAllowedAnimals(player, radiusSq)
    local results = {}
    local center = player:getSquare()
    if not center then
        return results
    end
    local cx = center:getX()
    local cy = center:getY()
    local cz = center:getZ()
    local radius = math.ceil(math.sqrt(radiusSq))
    for dx = -radius, radius do
        for dy = -radius, radius do
            if dx * dx + dy * dy <= radiusSq then
                local square = getSquare(cx + dx, cy + dy, cz)
                if square then
                    local objects = square:getMovingObjects()
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local obj = objects:get(i)
                            if instanceof(obj, "IsoAnimal")
                                and SidecarAnimal.isAllowedAnimalType(obj:getAnimalType()) then
                                results[#results + 1] = obj
                            end
                        end
                    end
                end
            end
        end
    end
    return results
end

---@param player IsoPlayer
---@param context ISContextMenu
---@param bikeItem InventoryItem
local function addStowFromBikeContextOption(player, context, bikeItem)
    if not bikeItem:getWeaponPart("Sidecar") then
        return
    end
    if SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
        return
    end
    if not isBikeReachableForSidecar(player, bikeItem) then
        return
    end

    local stowIcon = getTexture("media/ui/Bicycle/SidecarStow.png")

    local animalItem = findHeldAllowedAnimal(player)
    if animalItem then
        local option = context:addOption(
            getText("ContextMenu_Bicycle_PlaceAnimalInSidecar"),
            nil,
            function()
                queueStowHeldAnimal(player, bikeItem, animalItem)
            end
        )
        if stowIcon then
            option.iconTexture = stowIcon
        end
        return
    end

    local nearby = findNearbyAllowedAnimals(player, REACH_RADIUS_SQ)
    for i = 1, #nearby do
        local animal = nearby[i]
        local option = context:addOption(
            getText("ContextMenu_Bicycle_PutAnimalInSidecar"),
            nil,
            function()
                queueStowWorldAnimal(player, bikeItem, animal)
            end
        )
        if stowIcon then
            option.iconTexture = stowIcon
        end
    end
end

---@param player IsoPlayer
---@param context ISContextMenu
---@param bikeItem InventoryItem
local function addReleaseAnimalOption(player, context, bikeItem)
    if not SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
        return
    end
    if not isBikeReachableForSidecar(player, bikeItem) then
        return
    end
    local option = context:addOption(
        getText("ContextMenu_Bicycle_ReleaseAnimalFromSidecar"),
        nil,
        function()
            queueReleaseAnimal(player, bikeItem)
        end
    )
    local icon = getTexture("media/ui/Bicycle/SidecarRelease.png")
    if icon then
        option.iconTexture = icon
    end
end

---@param worldobjects table
---@param player IsoPlayer
---@return InventoryItem|nil
---@nodiscard
local function findBikeForReleaseFromWorldObjects(worldobjects, player)
    for i = 1, #worldobjects do
        local obj = worldobjects[i]
        if obj and obj.getItem then
            local item = obj:getItem()
            if BicycleUtils.isBicycleItem(item) then
                return item
            end
        end
    end

    if not (worldobjects[1] and worldobjects[1].getSquare) then
        return nil
    end
    local square = worldobjects[1]:getSquare()
    if not square then
        return nil
    end
    local closest = BicycleMenu.findNearestBicycleWithAttachments(square, player)
    if closest then
        local item = closest:getItem()
        if BicycleUtils.isBicycleItem(item) then
            return item
        end
    end
    return nil
end

---@param playerNum number
---@param context ISContextMenu
---@param worldobjects table
---@param test boolean
local function onFillWorldObjectContextMenuForRelease(playerNum, context, worldobjects, test)
    if test then
        return
    end
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    local bikeItem = findBikeForReleaseFromWorldObjects(worldobjects, player)
    if not bikeItem then
        return
    end
    addStowFromBikeContextOption(player, context, bikeItem)
    addReleaseAnimalOption(player, context, bikeItem)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenuForRelease)

---@param items table
---@return InventoryItem|nil
---@nodiscard
local function findBikeInInventoryItemList(items)
    for i = 1, #items do
        local entry = items[i]
        local candidate = entry
        if not instanceof(entry, "InventoryItem") and entry.items then
            candidate = entry.items[1]
        end
        if instanceof(candidate, "InventoryItem") and BicycleUtils.isBicycleItem(candidate) then
            return candidate
        end
    end
    return nil
end

---@param playerNum number
---@param context ISContextMenu
---@param items table
local function onFillInventoryObjectContextMenuForRelease(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    local bikeItem = findBikeInInventoryItemList(items)
    if not bikeItem then
        return
    end
    addStowFromBikeContextOption(player, context, bikeItem)
    addReleaseAnimalOption(player, context, bikeItem)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenuForRelease)
