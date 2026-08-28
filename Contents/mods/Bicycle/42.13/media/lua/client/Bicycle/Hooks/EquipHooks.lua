local BicycleAttachments = require("Bicycle/SaddleBag/Saddlebag")
local BicycleContainers = require("Bicycle/Containers")
local BicycleDebug = require("Bicycle/Debug")
local BicycleRidingSystem = require("Bicycle/Systems/RidingSystem")
local BicycleUtils = require("Bicycle/Utils")

---@type BicycleMenu|nil
local BicycleMenu = nil
---@type BicycleHopOnAction|nil
local BicycleHopOnAction = nil

---@return BicycleMenu
local function getBicycleMenu()
    if BicycleMenu then
        return BicycleMenu
    end

    BicycleMenu = require("Bicycle/BicycleMenu")
    return BicycleMenu
end

---@return BicycleHopOnAction
local function getBicycleHopOnAction()
    if BicycleHopOnAction then
        return BicycleHopOnAction
    end

    BicycleHopOnAction = require("Bicycle/TimedAction/BicycleHopOnAction")
    return BicycleHopOnAction
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param equippedItem InventoryItem|nil
---@return InventoryItem|nil
---@nodiscard
local function getBothHandsBicycle(player, equippedItem)
    if not player then
        return nil
    end

    local primaryItem = player:getPrimaryHandItem()
    local secondaryItem = player:getSecondaryHandItem()
    if not (BicycleUtils.isBicycleItem(primaryItem) and primaryItem == secondaryItem) then
        return nil
    end

    if equippedItem and equippedItem.getID and primaryItem.getID then
        if equippedItem:getID() ~= primaryItem:getID() then
            return nil
        end
    end

    return primaryItem
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function shouldSkipMountedEquipRecovery(player)
    if not player then
        return true
    end
    if player:getVariableBoolean("BicycleActive") then
        return true
    end
    if player:getVariableBoolean("droppingBicycle") then
        return true
    end
    if player:getVariableBoolean("Dismounting") then
        return true
    end
    if player:getVariableBoolean("Bicycle_Stopping") then
        return true
    end

    return false
end

---@param player IsoPlayer|IsoGameCharacter
---@param bikeItem InventoryItem
---@return string|nil
---@nodiscard
local function getQueuedMountAnim(player, bikeItem)
    local hopOnAction = getBicycleHopOnAction()
    local mountAnim = hopOnAction.getQueuedMountAnimForItem(bikeItem)
    if mountAnim and mountAnim ~= "" then
        return mountAnim
    end

    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    if not (queue and queue.queue and bikeItem.getID) then
        return nil
    end

    local itemId = bikeItem:getID()
    for i = 1, #queue.queue do
        local action = queue.queue[i]
        if action and action.Type == "BicycleHopOnAction" and action.itemId == itemId then
            if action.mountAnim and action.mountAnim ~= "" then
                return action.mountAnim
            end
            return nil
        end
    end

    return nil
end

---@param bikeItem InventoryItem
---@param player IsoPlayer|IsoGameCharacter
---@param mountAnim string|nil
---@return table
local function buildMountRecoveryData(bikeItem, player, mountAnim)
    local payload = {
        mountAnim = mountAnim
    }

    local square = player:getSquare()
    if square then
        payload.x = square:getX()
        payload.y = square:getY()
        payload.z = square:getZ()
    end
    if bikeItem.getWorldXRotation then
        payload.worldXRotation = bikeItem:getWorldXRotation()
    end
    if bikeItem.getWorldYRotation then
        payload.worldYRotation = bikeItem:getWorldYRotation()
    end
    if bikeItem.getWorldZRotation then
        payload.worldZRotation = bikeItem:getWorldZRotation()
    end

    return payload
end

---@param action ISEquipWeaponAction
local function recoverMountedStateAfterEquip(action)
    local player = action.character
    if shouldSkipMountedEquipRecovery(player) then
        return
    end

    local bikeItem = getBothHandsBicycle(player, action.item)
    if not bikeItem then
        return
    end

    local mountAnim = getQueuedMountAnim(player, bikeItem)
    BicycleDebug.log(
        "ISEquipWeaponAction:perform mount recovery player=" .. BicycleDebug.describePlayer(player)
            .. ", item=" .. BicycleDebug.describeItem(bikeItem)
            .. ", mountAnim=" .. BicycleDebug.describeValue(mountAnim)
    )
    getBicycleMenu().enterMountedState(player, bikeItem, mountAnim)

    if isClient() then
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.requestMountBike then
            Bicycle.ClientSync.requestMountBike(bikeItem, buildMountRecoveryData(bikeItem, player, mountAnim))
        end
    elseif isServer() then
        BicycleDebug.log("ISEquipWeaponAction:perform mount recovery server-side sync skipped")
    else
        BicycleDebug.log("ISEquipWeaponAction:perform mount recovery singleplayer")
    end
end

local originalGrabValid = ISGrabItemAction.isValid

---@return boolean
function ISGrabItemAction:isValid()
    local itemType = self.item:getItem():getType()
    if BicycleContainers.isContainerItemType(itemType) then
        return false
    end
    if BicycleUtils.isBicycleType(itemType) then
        return false
    end
    return originalGrabValid(self)
end

local originalIsUnequipValid = ISUnequipAction.isValid

---@return boolean
function ISUnequipAction:isValid()
    if self.item
        and type(self.item.getType) == "function"
        and (BicycleUtils.isBicycleItem(self.item) or BicycleContainers.isContainerItemType(self.item:getType())) then
        return false
    end
    return originalIsUnequipValid(self)
end

local originalIsEquipValid = ISEquipWeaponAction.isValid

---@return boolean
function ISEquipWeaponAction:isValid()
    if self.item and BicycleUtils.isBicycleItem(self.item) then
        BicycleDebug.log(
            "ISEquipWeaponAction:isValid start item=" .. BicycleDebug.describeItem(self.item)
                .. ", primary=" .. BicycleDebug.describeItem(self.character:getPrimaryHandItem())
                .. ", secondary=" .. BicycleDebug.describeItem(self.character:getSecondaryHandItem())
        )
    end
    local primaryItem = self.character:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) then
        if self.item and BicycleUtils.isBicycleItem(self.item) then
            if self.item == primaryItem or self.item:getID() == primaryItem:getID() then
                local valid = originalIsEquipValid(self)
                BicycleDebug.log("ISEquipWeaponAction:isValid bicycle-already-primary valid=" .. tostring(valid))
                return valid
            end
        end
        self.character:Say(getText("IGUI_Bicycle_HopOffFirst"))
        BicycleDebug.log("ISEquipWeaponAction:isValid blocked by other primary bicycle")
        return false
    end
    if self.item
        and type(self.item.getType) == "function"
        and BicycleContainers.isContainerItemType(self.item:getType()) then
        return false
    end
    local valid = originalIsEquipValid(self)
    if self.item and BicycleUtils.isBicycleItem(self.item) then
        BicycleDebug.log("ISEquipWeaponAction:isValid final valid=" .. tostring(valid))
    end
    return valid
end

local originalWearClothing = ISWearClothing.isValid

---@return boolean
function ISWearClothing:isValid()
    local itemType = self.item:getType()
    if BicycleContainers.isContainerItemType(itemType) then
        return true
    end
    return originalWearClothing(self)
end

local originalGetWearClothesDuration = ISWearClothing.getDuration

---@return number
function ISWearClothing:getDuration()
    local itemType = self.item:getType()
    if BicycleUtils.isBicycleType(itemType) or BicycleContainers.isContainerItemType(itemType) then
        return 0
    end
    return originalGetWearClothesDuration(self)
end

local originalDropItem = ISInventoryPaneContextMenu.onDropItems

---@param items table
---@param player number
---@return unknown
function ISInventoryPaneContextMenu.onDropItems(items, player)
    items = ISInventoryPane.getActualItems(items)
    local filteredItems = {}
    local pzPlayer = getSpecificPlayer(player)

    for _, item in ipairs(items) do
        if BicycleUtils.isBicycleItem(item) then
            if pzPlayer and pzPlayer:getVariableBoolean("Bicycle_Riding") then
                -- Ignore drop requests while actively riding to avoid interrupting animations
            else
                if pzPlayer then
                    pzPlayer:setBlockMovement(true)
                    pzPlayer:setVariable("droppingBicycle", "true")
                end
                BicycleRidingSystem.clearUpdateHandlers()
                if pzPlayer then
                    local emitter = pzPlayer:getEmitter()
                    emitter:stopSoundByName("Bicycle_Riding")
                    BicycleAttachments.dropContainers(item, pzPlayer)
                else
                    BicycleAttachments.dropContainers(item, nil)
                end
                BicycleUtils.runAfter(0.4, function()
                    if pzPlayer then
                        pzPlayer:setBlockMovement(false)
                        pzPlayer:setVariable("BicycleActive", "false")
                        pzPlayer:setVariable("Bicycle_Stopping", false)
                        pzPlayer:setCanShout(true)
                        pzPlayer:setAllowRun(true)
                        pzPlayer:setForceSprint(false)
                        pzPlayer:setBannedAttacking(false)
                        pzPlayer:setVariable("droppingBicycle", "false")
                        pzPlayer:setIgnoreAutoVault(false)
                        BicycleAttachments.onBikeDropped(pzPlayer, item)
                    end
                end)
                table.insert(filteredItems, item)
            end
        else
            table.insert(filteredItems, item)
        end
    end

    if #filteredItems == 0 then
        return
    end

    return originalDropItem(filteredItems, player)
end

local originalCreate

local function onGameStart()
    originalCreate = ISPlace3DItemCursor.create

    ---@return unknown
    function ISPlace3DItemCursor:create()
        local item = self.items and self.items[1]
        if BicycleUtils.isBicycleItem(item) then
            local player = self.character
            player:removeFromHands(item)
            BicycleRidingSystem.clearUpdateHandlers()
            local emitter = player:getEmitter()
            emitter:stopSoundByName("Bicycle_Riding")
            player:setVariable("Bicycle_Riding", "false")
            player:setVariable("BicycleActive", "false")
            player:setVariable("Bicycle_Stopping", false)
            player:setAllowRun(true)
            player:setForceSprint(false)
            player:setCanShout(true)
            player:setBannedAttacking(false)
            player:setIgnoreAutoVault(false)

            BicycleUtils.runAfter(0.2, function()
                local plrQueue = ISTimedActionQueue.getTimedActionQueue(player)
                if not plrQueue or not plrQueue.queue then
                    return
                end

                for _, action in ipairs(plrQueue.queue) do
                    if plrQueue.queue[1].Type == "ISDropWorldItemAction" then
                        BicycleAttachments.dropContainers(item, player)
                        BicycleAttachments.onBikeDropped(player, item)
                        break
                    end
                    if action.Type == "ISWalkToTimedAction" then
                        action:setOnComplete(function()
                            BicycleAttachments.onBikeDropped(player, item)
                        end)
                        break
                    end
                end
            end)
        end

        return originalCreate(self)
    end
end

Events.OnGameStart.Add(onGameStart)

local originalISEquipPerform = ISEquipWeaponAction.perform

---@return nil
function ISEquipWeaponAction:perform()
    if self.item and BicycleUtils.isBicycleItem(self.item) then
        BicycleDebug.log(
            "ISEquipWeaponAction:perform before item=" .. BicycleDebug.describeItem(self.item)
                .. ", primary=" .. BicycleDebug.describeItem(self.character:getPrimaryHandItem())
                .. ", secondary=" .. BicycleDebug.describeItem(self.character:getSecondaryHandItem())
        )
    end
    originalISEquipPerform(self)
    recoverMountedStateAfterEquip(self)
    if self.item and BicycleUtils.isBicycleItem(self.item) then
        BicycleDebug.log(
            "ISEquipWeaponAction:perform after item=" .. BicycleDebug.describeItem(self.item)
                .. ", primary=" .. BicycleDebug.describeItem(self.character:getPrimaryHandItem())
                .. ", secondary=" .. BicycleDebug.describeItem(self.character:getSecondaryHandItem())
        )
    end
end
