local BicycleRidingSystem = require("Bicycle/Systems/RidingSystem")
local BicycleUtils = require("Bicycle/Utils")

---@class BicycleMountRecovery
local BicycleMountRecovery = {}

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
---@param item InventoryItem|nil
---@return boolean
---@nodiscard
local function isInvalidEquippedBicycle(player, item)
    if not (player and BicycleUtils.isBicycleItem(item)) then
        return false
    end

    if item.getWorldItem and item:getWorldItem() then
        return true
    end
    if item.isInPlayerInventory and not item:isInPlayerInventory() then
        return true
    end

    local playerInventory = player:getInventory()
    local container = nil
    if item.getContainer then
        container = item:getContainer()
    end
    if container and container ~= playerInventory then
        return true
    end

    return false
end

---@param player IsoPlayer|IsoGameCharacter|nil
local function clearInvalidEquippedBicycles(player)
    if not player then
        return
    end

    local cleared = false
    local primaryItem = player:getPrimaryHandItem()
    if isInvalidEquippedBicycle(player, primaryItem) then
        player:setPrimaryHandItem(nil)
        cleared = true
    end

    local secondaryItem = player:getSecondaryHandItem()
    if isInvalidEquippedBicycle(player, secondaryItem) then
        player:setSecondaryHandItem(nil)
        cleared = true
    end

    if not cleared then
        return
    end

    player:setVariable("Bicycle_Riding", "false")
    player:setVariable("BicycleActive", "false")
    player:setVariable("Bicycle_Stopping", false)
    player:setVariable("droppingBicycle", "false")
    player:setVariable("Bicycle_MountPending", false)
    player:setBlockMovement(false)
    player:setIgnoreMovement(false)
    player:setTurnDelta(1)
    player:setAllowRun(true)
    player:setForceSprint(false)
    player:setCanShout(true)
    player:setBannedAttacking(false)
    player:setIgnoreAutoVault(false)
    player:resetEquippedHandsModels()
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function shouldSkipRecovery(player)
    if not player then
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
---@return boolean
---@nodiscard
local function hasQueuedDismountOrDrop(player)
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    if not queue then
        return false
    end

    local current = queue.current
    if current
        and (current.Type == "BicycleDismountAction"
            or current.Type == "BicycleThrowOverFenceAction"
            or current.Type == "ISDropWorldItemAction") then
        return true
    end

    if not queue.queue then
        return false
    end

    for i = 1, #queue.queue do
        local action = queue.queue[i]
        if action
            and (action.Type == "BicycleDismountAction"
                or action.Type == "BicycleThrowOverFenceAction"
                or action.Type == "ISDropWorldItemAction") then
            return true
        end
    end

    return false
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return InventoryItem|nil
---@nodiscard
local function getEquippedBicycle(player)
    if not player then
        return nil
    end

    local primaryItem = player:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) then
        return primaryItem
    end

    local secondaryItem = player:getSecondaryHandItem()
    if BicycleUtils.isBicycleItem(secondaryItem) then
        return secondaryItem
    end

    return nil
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param itemId number|nil
---@return InventoryItem|nil
---@nodiscard
local function getEquippedBicycleById(player, itemId)
    if not (player and itemId) then
        return nil
    end

    local primaryItem = player:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) and primaryItem.getID and primaryItem:getID() == itemId then
        return primaryItem
    end

    local secondaryItem = player:getSecondaryHandItem()
    if BicycleUtils.isBicycleItem(secondaryItem) and secondaryItem.getID and secondaryItem:getID() == itemId then
        return secondaryItem
    end

    return nil
end

---@param player IsoPlayer|IsoGameCharacter
---@return number
---@nodiscard
local function getBicycleSpeedVariable(player)
    if player.getVariableFloat then
        return player:getVariableFloat("BicycleSpeed", 0)
    end

    local rawValue = player:getVariableString("BicycleSpeed")
    local numberValue = tonumber(rawValue)
    if numberValue then
        return numberValue
    end

    return 0
end

---@param player IsoPlayer|IsoGameCharacter
---@param bikeItem InventoryItem
---@return boolean
local function equipBikeInBothHands(player, bikeItem)
    local changed = false

    if player:getPrimaryHandItem() ~= bikeItem then
        player:setPrimaryHandItem(bikeItem)
        changed = true
    end
    if player:getSecondaryHandItem() ~= bikeItem then
        player:setSecondaryHandItem(bikeItem)
        changed = true
    end
    if changed then
        player:resetEquippedHandsModels()
    end

    return changed
end

---@param player IsoPlayer|IsoGameCharacter
---@param bikeItem InventoryItem
---@param mountAnim string|nil
---@return table
local function buildMountRecoveryData(player, bikeItem, mountAnim)
    local payload = {}
    if mountAnim ~= nil then
        payload.mountAnim = mountAnim
    end

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

---@param bikeItem InventoryItem
---@return string|nil
---@nodiscard
local function getQueuedMountAnim(bikeItem)
    local mountAnim = getBicycleHopOnAction().getQueuedMountAnimForItem(bikeItem)
    if mountAnim == "" then
        return nil
    end

    return mountAnim
end

---@param player IsoPlayer|IsoGameCharacter
---@param bikeItem InventoryItem
---@param mountAnim string|nil
local function repairMountedState(player, bikeItem, mountAnim)
    if not player:getVariableBoolean("BicycleActive") or getBicycleSpeedVariable(player) <= 0 then
        getBicycleMenu().enterMountedState(player, bikeItem, mountAnim)
        return
    end

    player:setBlockMovement(false)
    player:setIgnoreMovement(false)
    player:setTurnDelta(1)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param itemId number|nil
function BicycleMountRecovery.recoverByItemId(player, itemId)
    if shouldSkipRecovery(player) then
        return
    end
    if hasQueuedDismountOrDrop(player) then
        return
    end

    local bikeItem = getEquippedBicycleById(player, itemId)
    if not bikeItem then
        return
    end
    if isInvalidEquippedBicycle(player, bikeItem) then
        clearInvalidEquippedBicycles(player)
        return
    end

    local handsChanged = equipBikeInBothHands(player, bikeItem)
    local mountAnim = getQueuedMountAnim(bikeItem)
    repairMountedState(player, bikeItem, mountAnim)

    if handsChanged then
        BicycleRidingSystem.ensureUpdateHandlers()
        BicycleRidingSystem.updateBicycleFlag(player)
    end

    if isClient() then
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.requestMountBike then
            player:setVariable("Bicycle_MountPending", true)
            Bicycle.ClientSync.requestMountBike(bikeItem, buildMountRecoveryData(player, bikeItem, mountAnim))
        end
    end
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
function BicycleMountRecovery.schedule(player, bikeItem)
    if not (player and bikeItem and bikeItem.getID) then
        return
    end

    local playerNum = player:getPlayerNum()
    local itemId = bikeItem:getID()
    ---@type number[]
    local delays = { 1.5, 3.0, 5.0 }

    for i = 1, #delays do
        BicycleUtils.runAfter(delays[i], function()
            local currentPlayer = getSpecificPlayer(playerNum)
            BicycleMountRecovery.recoverByItemId(currentPlayer, itemId)
        end)
    end
end

---@param player IsoPlayer|IsoGameCharacter|nil
function BicycleMountRecovery.repairEquippedState(player)
    if shouldSkipRecovery(player) then
        return
    end
    if not player:isLocalPlayer() then
        return
    end

    local bikeItem = getEquippedBicycle(player)
    if not bikeItem then
        return
    end
    if isInvalidEquippedBicycle(player, bikeItem) then
        return
    end

    local handsChanged = equipBikeInBothHands(player, bikeItem)
    repairMountedState(player, bikeItem, nil)

    if handsChanged then
        BicycleRidingSystem.ensureUpdateHandlers()
        BicycleRidingSystem.updateBicycleFlag(player)
    end
end

return BicycleMountRecovery
