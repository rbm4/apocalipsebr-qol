local BicycleAttachments = require("Bicycle/SaddleBag/Saddlebag")
local BicycleMountRecovery = require("Bicycle/MountRecovery")
local BicycleRidingSystem = require("Bicycle/Systems/RidingSystem")
local BicycleUtils = require("Bicycle/Utils")

local bicycleTypes = BicycleUtils.getBicycleTypes()

---@param player IsoPlayer|IsoGameCharacter|nil
local function clearMountedState(player)
    if not player then
        return
    end
    local emitter = player.getEmitter and player:getEmitter() or nil
    if emitter then
        emitter:stopSoundByName("Bicycle_Riding")
    end
    if player.setBlockMovement then
        player:setBlockMovement(false)
    end
    if player.setVariable then
        player:setVariable("Bicycle_Riding", "false")
        player:setVariable("BicycleActive", "false")
        player:setVariable("Bicycle_Stopping", false)
        player:setVariable("droppingBicycle", "false")
        player:setVariable("Bicycle_MountPending", false)
    end
    if player.setIgnoreAutoVault then
        player:setIgnoreAutoVault(false)
    end
    if player.setAllowRun then
        player:setAllowRun(true)
    end
    if player.setForceSprint then
        player:setForceSprint(false)
    end
    if player.setBannedAttacking then
        player:setBannedAttacking(false)
    end
    if player.setCanShout then
        player:setCanShout(true)
    end
    BicycleRidingSystem.clearUpdateHandlers()
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function playerHasEquippedBicycle(player)
    if not player then
        return false
    end
    local primary = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    local secondary = player.getSecondaryHandItem and player:getSecondaryHandItem() or nil
    if BicycleUtils.isBicycleItem(primary) then
        return true
    end
    if BicycleUtils.isBicycleItem(secondary) then
        return true
    end
    return false
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function playerHasMountPending(player)
    if not player then
        return false
    end

    if player:getVariableBoolean("Bicycle_MountPending") then
        if playerHasEquippedBicycle(player) then
            player:setVariable("Bicycle_MountPending", false)
            return false
        end
        return true
    end

    local mountAnim = player:getVariableString("mountAnim")
    if mountAnim and mountAnim ~= "" then
        return true
    end

    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    if not queue then
        return false
    end

    if queue.current and queue.current.Type == "BicycleHopOnAction" then
        return true
    end

    if not queue.queue then
        return false
    end

    for i = 1, #queue.queue do
        local action = queue.queue[i]
        if action and action.Type == "BicycleHopOnAction" then
            return true
        end
    end

    return false
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
    local container = item.getContainer and item:getContainer() or nil
    if container and container ~= playerInventory then
        return true
    end

    return false
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function clearInvalidEquippedBicycles(player)
    if not player then
        return false
    end
    if player:isDoingActionThatCanBeCancelled() then
        return false
    end
    if player:getVariableBoolean("Dismounting") then
        return false
    end

    local cleared = false

    local primary = player:getPrimaryHandItem()
    if isInvalidEquippedBicycle(player, primary) then
        player:setPrimaryHandItem(nil)
        cleared = true
    end

    local secondary = player:getSecondaryHandItem()
    if isInvalidEquippedBicycle(player, secondary) then
        player:setSecondaryHandItem(nil)
        cleared = true
    end

    if cleared and player.resetEquippedHandsModels then
        player:resetEquippedHandsModels()
    end

    return cleared
end

---@param player IsoPlayer|IsoGameCharacter|nil
local function followInventoryBicycles(player)
    if not player then
        return
    end

    local inventory = player.getInventory and player:getInventory() or nil
    if not inventory then
        return
    end
    if inventory.containsTypeRecurse then
        local containsBicycle = false
        for _, typeName in ipairs(bicycleTypes) do
            if inventory:containsTypeRecurse(typeName) then
                containsBicycle = true
                break
            end
        end
        if not containsBicycle then
            return
        end
    end

    local seenItems = {}
    local visitedContainers = {}

    local followContainer

    ---@param item InventoryItem|nil
    local function followItem(item)
        if not item then
            return
        end
        if seenItems[item] then
            return
        end

        if BicycleUtils.isBicycleItem(item) then
            seenItems[item] = true
            BicycleAttachments.followPlayer(player, item)
        end

        if item.getInventory then
            local sub = item:getInventory()
            if sub then
                followContainer(sub)
            end
        end
    end

    ---@param container ItemContainer|nil
    followContainer = function(container)
        if not container then
            return
        end
        if visitedContainers[container] then
            return
        end
        visitedContainers[container] = true

        local items = container.getItems and container:getItems() or nil
        if not items then
            return
        end
        for i = 0, items:size() - 1 do
            followItem(items:get(i))
        end
    end

    followContainer(inventory)
    followItem(player.getPrimaryHandItem and player:getPrimaryHandItem() or nil)
    followItem(player.getSecondaryHandItem and player:getSecondaryHandItem() or nil)
end

-- While one of the mod bike actions is running, the mounted-state variables are mid-transition by design.
---@param player IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function playerHasBicycleActionQueued(player)
    if not (player and ISTimedActionQueue and ISTimedActionQueue.getTimedActionQueue) then
        return false
    end

    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    if not queue then
        return false
    end

    local function isBicycleAction(action)
        if not action then
            return false
        end
        return action.Type == "BicycleThrowOverFenceAction"
            or action.Type == "BicycleDismountAction"
            or action.Type == "BicycleHopOnAction"
    end

    if isBicycleAction(queue.current) then
        return true
    end
    if queue.queue then
        for i = 1, #queue.queue do
            if isBicycleAction(queue.queue[i]) then
                return true
            end
        end
    end

    return false
end

local MOUNT_PENDING_TIMEOUT_FRAMES = 300

---@type table<IsoPlayer|IsoGameCharacter, number>
local mountPendingFrames = {}

---Put a bike that a failed mount stranded loose in the bag back into the world. onBikeDropped assumes
---the frame is already a world item, so for an inventory bike it would no-op and leave it stranded;
---place it in the world first so it is visible, retrievable, and its hidden containers can re-link.
---@param player IsoPlayer|IsoGameCharacter|nil
local function ensurePlayerUnmounted(player)
    if not player then
        return
    end
    local active = player.getVariableBoolean and player:getVariableBoolean("BicycleActive") or false
    local riding = player.getVariableBoolean and player:getVariableBoolean("Bicycle_Riding") or false
    if not active and not riding then
        mountPendingFrames[player] = nil
        return
    end
    if playerHasEquippedBicycle(player) then
        mountPendingFrames[player] = nil
        return
    end

    -- Not stranded, mid-action: a throw or dismount reads as mounted-but-holding-nothing for a frame or two,
    -- and recovering from that dropped whichever bike happened to be first in the inventory.
    if player.getVariableBoolean and player:getVariableBoolean("ThrowBicycleFence") then
        mountPendingFrames[player] = nil
        return
    end
    if playerHasBicycleActionQueued(player) then
        mountPendingFrames[player] = nil
        return
    end

    if playerHasMountPending(player) then
        -- A mount is legitimately in progress -- let it finish. But if it stays pending without ever
        -- equipping past the equip-poll window, the MountEquip handoff was lost and the bike is stuck
        -- loose in the bag; fall through to recover instead of waiting forever.
        local frames = (mountPendingFrames[player] or 0) + 1
        mountPendingFrames[player] = frames
        if frames < MOUNT_PENDING_TIMEOUT_FRAMES then
            return
        end
    end
    mountPendingFrames[player] = nil

    -- Clearing the stuck mounted flags is the whole job; nothing is dropped. This point is only reached when
    -- nothing is equipped, so there is no stranded bike to identify -- only a guess, and it guessed by type.
    clearMountedState(player)
end

local TELEPORT_DEBUG_ENABLED = false

-- DEBUG: track bicycle world item position to catch teleportation
local _debugTrackedBike = nil
local _debugTrackedSquare = nil

local function _debugLog(_message)
    if not TELEPORT_DEBUG_ENABLED then
        return
    end
end

local function _debugDescSq(sq)
    if not sq then return "nil" end
    return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
end

local function _debugCheckBikeMoved(label)
    if not _debugTrackedBike then return end
    local wObj = _debugTrackedBike.getWorldItem and _debugTrackedBike:getWorldItem() or nil
    local wSq = wObj and wObj.getSquare and wObj:getSquare() or nil
    local player = getSpecificPlayer(0)
    local pSq = player and player:getSquare() or nil
    if wSq and _debugTrackedSquare and wSq ~= _debugTrackedSquare then
        _debugLog("[BIKE-TELEPORT] " .. label .. " MOVED from " .. _debugDescSq(_debugTrackedSquare)
            .. " to " .. _debugDescSq(wSq) .. " playerAt=" .. _debugDescSq(pSq))
        _debugTrackedSquare = wSq
    end
    if not wSq and _debugTrackedSquare then
        _debugLog("[BIKE-TELEPORT] " .. label .. " world item GONE (was at " .. _debugDescSq(_debugTrackedSquare) .. ")")
        local inv = player and player:getInventory() or nil
        if inv then
            for _, typeName in ipairs(bicycleTypes) do
                if inv:containsTypeRecurse(typeName) then
                    _debugLog("[BIKE-TELEPORT] " .. label .. " bike found back IN INVENTORY type=" .. typeName)
                    break
                end
            end
        end
    end
end

local function _debugOnContainerUpdate()
    _debugCheckBikeMoved("OnContainerUpdate")
end

if Events and Events.OnContainerUpdate then
    if TELEPORT_DEBUG_ENABLED then
        Events.OnContainerUpdate.Add(_debugOnContainerUpdate)
    end
end

---@param player IsoPlayer|IsoGameCharacter
local function onPlayerUpdate(player)
    if clearInvalidEquippedBicycles(player) then
        clearMountedState(player)
    end
    BicycleMountRecovery.repairEquippedState(player)

    if TELEPORT_DEBUG_ENABLED then
        -- DEBUG: track bicycle after dismount
        if _debugTrackedBike then
            _debugCheckBikeMoved("onPlayerUpdate")
        end

        -- DEBUG: detect dismount and start tracking
        if not _debugTrackedBike and player and player.getSquare then
            local sq = player:getSquare()
            if sq then
                local objects = sq:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and instanceof(obj, "IsoWorldInventoryObject") then
                            local item = obj:getItem()
                            if item and BicycleUtils.isBicycleItem(item) then
                                -- Only start tracking after we just dropped it (not riding)
                                if not player:getVariableBoolean("BicycleActive") then
                                    _debugTrackedBike = item
                                    _debugTrackedSquare = sq
                                    _debugLog("[BIKE-DEBUG] Started tracking bike at " .. _debugDescSq(sq)
                                        .. " equipParent=" .. tostring(item.getEquipParent and item:getEquipParent() or "N/A")
                                        .. " container=" .. tostring(item:getContainer()))
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    followInventoryBicycles(player)
    ensurePlayerUnmounted(player)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
