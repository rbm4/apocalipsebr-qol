require("TimedActions/ISBaseTimedAction")
require("Bicycle/BicycleCore")

local BicycleActionUtils = require("Bicycle/ActionUtils")
local BicycleContainerManager = nil
local BicycleDropBehavior = require("Bicycle/DropBehavior")
local BicycleMountDismountState = require("Bicycle/MountDismountState")
local BicycleUtils = require("Bicycle/Utils")
local BicycleWorldUtils = require("Bicycle/WorldUtils")
if isClient() then
    BicycleContainerManager = nil
elseif isServer() then
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
else
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
end

-- Retried on first use, not captured at load time. On a dedicated server this file loads BEFORE
-- server/Bicycle/BicycleContainerManager.lua, so the require above fails and the upvalue stays nil
-- for the whole session -- silently skipping container sync for every bike put down.
---@return BicycleContainerManager|nil
local function getBicycleContainerManager()
    if BicycleContainerManager then
        return BicycleContainerManager
    end
    if isClient() then
        return nil
    end
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
    return BicycleContainerManager
end

---@param value any
---@return string|nil
---@nodiscard
local function boolToString(value)
    if value == true or value == "true" then return "true" end
    if value == false or value == "false" then return "false" end
    return nil
end

---@param value any
---@return boolean|nil
---@nodiscard
local function parseBool(value)
    if value == true or value == "true" then return true end
    if value == false or value == "false" then return false end
    return nil
end

---@param character IsoGameCharacter|IsoPlayer
---@param bicycleItem InventoryItem
---@param dismountData table|nil
local function runClientThrowCleanup(character, bicycleItem, dismountData)
    local BicycleMenu = require("Bicycle/BicycleMenu")
    BicycleMenu.onCompleteDrop(character, bicycleItem, dismountData)
end

---@class BicycleThrowOverFenceAction : ISBaseTimedAction
BicycleThrowOverFenceAction = ISBaseTimedAction:derive("BicycleThrowOverFenceAction")

---@param self BicycleThrowOverFenceAction
---@return boolean
function BicycleThrowOverFenceAction:isValid()
    -- The direction and landing square are part of validity, not just the character and the bike.
    -- Without them the action used to run anyway and the throw defaulted south, which in MP meant the
    -- server flinging the bike somewhere the client never animated. Cancelling leaves the bike in the
    -- player's hands, which is the safe failure.
    -- A sidecar bike is never throwable. Enforced here as well as in the menu because this runs on the
    -- authoritative side too: in MP the server rebuilds this action from the serialized arguments, so
    -- a client that skipped the menu check cannot get a sidecar bike thrown over a fence anyway.
    -- isBikeUnderPlayer stays true once the action is running: ensureEquipped moves the bike into the
    -- player's inventory, and a carried bike counts as under them. It only rejects the case this
    -- restriction exists for -- starting a throw on a bike lying on some other square.
    return self.character ~= nil
        and self.bicycleItem ~= nil
        and self.startDir ~= nil
        and self.targetSquare ~= nil
        and BicycleUtils.isBikeUnderPlayer(self.character, self.bicycleItem)
        and not BicycleUtils.hasSidecar(self.bicycleItem)
end

---@param self BicycleThrowOverFenceAction
---@return boolean
function BicycleThrowOverFenceAction:waitToStart()
    -- Turn to face the fence BEFORE the throw begins, and do not begin while still moving.
    --
    -- :start() used to fire the animation immediately and :update() forced the facing every tick, so
    -- picking up a bike lying behind you meant the turn happened DURING the throw. The animation was
    -- cut short, its ThrowBicycleFenceFinished event never landed, and the client's copy and the
    -- server's NetTimedAction copy stopped agreeing about when the throw completed -- which is how the
    -- bike went missing instead of landing. Holding here spends the turn/settle time in waitToStart,
    -- where the queue expects it, rather than inside the animation.
    if self.startDir then
        self.character:setDir(self.startDir)
    end

    return self.character.isMoving and self.character:isMoving() or false
end

---@param self BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:start()
    if self.startDir then
        self.character:setDir(self.startDir)
    end
    self.character:setVariable("ThrowBicycleFence", true)
    self:setActionAnim("ThrowBicycleFence")
end

---@param self BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:update()
    if self.startDir and self.character:getDir() ~= self.startDir then
        self.character:setDir(self.startDir)
    end

    BicycleActionUtils.ensureEquipped(self.character, self.bicycleItem)

    if self.character:getVariableBoolean("ThrowBicycleFenceFinished") then
        self:forceComplete()
    end
end

---@param self BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:stop()
    self.character:setVariable("ThrowBicycleFence", false)
    -- :update() keeps BicycleActive set through ensureEquipped so the animation plays, and the flag
    -- has to die with the action. Only onCompleteDrop cleared it, and that runs from :perform() --
    -- which the client's copy never reaches in MP, because the server drives the NetTimedAction and
    -- the client's action is STOPPED instead. The flag then outlived the throw, BicycleStateGuards
    -- saw a player marked as mounted holding nothing, decided a bike was stranded, and dumped the
    -- first bicycle out of the inventory onto the ground. The player cannot be riding here (the menu
    -- only offers a throw while unmounted), so clearing it unconditionally is safe.
    self.character:setVariable("BicycleActive", "false")

    -- Never end holding nothing. :update() calls ensureEquipped, which lifts the bike off the ground
    -- (removeWorldItem + removeItemFromContainer) on the FIRST tick, before the throw is committed to
    -- anything. If the action then ends without completing -- interrupted, cancelled, isValid turning
    -- false, the animation event never arriving -- the bike has already left the world and nothing
    -- puts it back, so it is simply destroyed. That is the "it despawned mid-throw" report, and it is
    -- why throwing a bike BACK could lose it even when the outbound throw worked.
    --
    -- Belonging to no container and having no world item is the signature of an item in that limbo.
    -- Putting it in the thrower's inventory is always recoverable; destroying it never is.
    local item = self.bicycleItem
    if item then
        local hasWorldItem = item.getWorldItem and item:getWorldItem() ~= nil
        local hasContainer = item.getContainer and item:getContainer() ~= nil
        if not hasWorldItem and not hasContainer then
            local inventory = self.character and self.character:getInventory() or nil
            if inventory and inventory.AddItem then
                inventory:AddItem(item)
                if isServer() and sendEquip then
                    sendEquip(self.character)
                end
            end
        end
    end

    BicycleMountDismountState.finishDismount(self.character)
    ISBaseTimedAction.stop(self)
end

---@param self BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:perform()
    self.character:setVariable("ThrowBicycleFence", false)
    self.character:setVariable("ThrowBicycleFenceFinished", false)
    -- Same reasoning as :stop() -- clear the flag the action itself set, on every exit path, rather
    -- than relying on the cleanup that only some paths reach.
    self.character:setVariable("BicycleActive", "false")
    if isClient() then
        if self.bicycleItem then
            -- Ask the server to place the bike HERE, in perform(), not in complete().
            --
            -- complete() is not a vanilla ISBaseTimedAction hook -- it only runs through the
            -- NetTimedAction path, which on a dedicated server means the SERVER runs it. The client's
            -- copy never reaches it. So the request lived in a function that never executed on this
            -- side, while runClientThrowCleanup below ran every time and destroyed the client's copy
            -- (onCompleteDrop does DoRemoveItem + setContainer(nil) + setWorldItem(nil)). The bike was
            -- thrown away locally and the server was never told to put one down: it just vanished.
            -- Singleplayer hid this completely, because there complete() does run.
            -- No DropBike request from here. The server runs :complete() through NetTimedAction and
            -- places the bike itself -- confirmed in the trace as throw.complete + throw.placed.OK --
            -- so sending one from the client placed it a SECOND time: a redundant remove-and-re-add of
            -- an item already lying on the ground, which on failure would have yanked a successfully
            -- thrown bike back off the floor. If the action never completes, :stop() returns the bike
            -- to the inventory, so an abort still cannot destroy it.
            runClientThrowCleanup(self.character, self.bicycleItem, self.dismountData)
        else
            BicycleMountDismountState.finishDismount(self.character)
        end
    end
    ISBaseTimedAction.perform(self)
end

---@param self BicycleThrowOverFenceAction
---@return boolean
function BicycleThrowOverFenceAction:complete()
    local dropSquare = self.targetSquare or self.character:getSquare()
    if not dropSquare then
        return false
    end

    if not self.bicycleItem then
        return false
    end

    if not self.dismountData or self.dismountData.kickstandDown == nil then
        local kickstandDown = parseBool(self.dm_kickstandDown)
        local shiftHeld = parseBool(self.dm_shiftHeld)

        if kickstandDown == nil and shiftHeld == nil then
            kickstandDown = false
            shiftHeld = true
        end

        self.dismountData = {
            kickstandDown = kickstandDown,
            shiftHeld = shiftHeld,
            dismountAnim = self.dm_dismountAnim or "throwBicycle",
            zRotation = self.dm_zRotation,
            direction = self.character:getDir(),
        }
    end

    -- Take it out of the player's HANDS before dropping it. :update() deliberately keeps the bike
    -- equipped for the animation, and removeItemFromContainer only touches the container, not the
    -- hand slots. Leave it equipped here and the authoritative side still believes the player is
    -- holding the bike it just threw, so the inventory syncs a copy straight back to the client and
    -- the bike exists twice: once on the ground, once in the thrower's hands. The DropBike command
    -- clears hands and re-sends equip for precisely this reason; the throw has to do the same.
    local character = self.character
    if character and character.getPrimaryHandItem then
        if character:getPrimaryHandItem() == self.bicycleItem
            or character:getSecondaryHandItem() == self.bicycleItem then
            character:removeFromHands(self.bicycleItem)
            if isServer() and sendEquip then
                sendEquip(character)
            end
        end
    end

    -- A client never places the world item itself (the server owns world items, and a client-side
    -- placement is a phantom that vanishes on the next sync). The request is sent from :perform(),
    -- which is the hook that actually runs on this side; if complete() somehow does run on a client,
    -- there is nothing left to do here.
    if isClient() then
        return true
    end

    BicycleUtils.removeWorldItem(self.bicycleItem)
    BicycleUtils.removeItemFromContainer(self.bicycleItem)

    -- The bike has just been pulled out of the container, so from here until it is standing in the
    -- world it belongs to nothing. addPersistentWorldItem returns the item even when
    -- AddWorldInventoryItem REFUSED the placement, so a truthy return is not proof it landed -- the
    -- only proof is a world item. Without this check a refused placement silently destroyed the bike,
    -- which is exactly the "throw it over and it despawns" report.
    local placed = BicycleUtils.addPersistentWorldItem(dropSquare, self.bicycleItem, 0, 0, 0)
    local placedWorldItem = placed and placed.getWorldItem and placed:getWorldItem() or nil
    if not placedWorldItem then
        local inventory = self.character and self.character:getInventory()
        if inventory and inventory.AddItem then
            inventory:AddItem(self.bicycleItem)
        end
        BicycleMountDismountState.finishDismount(self.character)
        return false
    end

    local droppedBikeItem = placed
    BicycleDropBehavior.applyDropState(droppedBikeItem, self.character, self.dismountData)
    local containerManager = getBicycleContainerManager()
    if containerManager then
        containerManager.syncBikeContainers(self.character, droppedBikeItem, dropSquare, nil)
    end
    if isServer() then
        BicycleMountDismountState.finishDismount(self.character)
    elseif isClient() then
        BicycleMountDismountState.finishDismount(self.character)
    else
        runClientThrowCleanup(self.character, droppedBikeItem, self.dismountData)
    end

    return true
end

---@param self BicycleThrowOverFenceAction
---@return number
function BicycleThrowOverFenceAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    -- -1 means run until the animation says stop, but the dedicated server has no animation and reads this
    -- as an endTime in the past. Give it a real one; the client still finishes on the anim event.
    if isServer() then
        return 120
    end

    return -1
end

---@param character IsoGameCharacter
---@param bicycleItem InventoryItem
---@param fenceDirName string|nil
---@return BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:new(character, bicycleItem, fenceDirName)
    local o = ISBaseTimedAction.new(self, character)
    o.bicycleItem = bicycleItem
    o.stopOnWalk = true
    o.stopOnRun = true

    -- Passed in rather than discovered, because NetTimedAction re-runs this constructor server-side and
    -- re-discovery there can pick a different neighbour than the client animated against.
    local fenceDir = BicycleWorldUtils.directionFromName(fenceDirName)
        or BicycleWorldUtils.findHoppableDirection(character)
    o.startDir = fenceDir
    o.fenceDirName = BicycleWorldUtils.directionToName(fenceDir)
    o.targetSquare = fenceDir and BicycleWorldUtils.findThrowLandingSquare(character, fenceDir) or nil
    o.dismountData = {
        direction = o.startDir,
        zRotation = BicycleUtils.directionToZRotation(o.startDir),
        dismountAnim = "throwBicycle",
        kickstandDown = false,
        shiftHeld = true
    }
    o.dm_kickstandDown = boolToString(o.dismountData.kickstandDown)
    o.dm_shiftHeld = boolToString(o.dismountData.shiftHeld)
    o.dm_dismountAnim = o.dismountData.dismountAnim
    o.dm_zRotation = o.dismountData.zRotation

    o.maxTime = o:getDuration()

    return o
end

_G[BicycleThrowOverFenceAction.Type] = BicycleThrowOverFenceAction

return BicycleThrowOverFenceAction
