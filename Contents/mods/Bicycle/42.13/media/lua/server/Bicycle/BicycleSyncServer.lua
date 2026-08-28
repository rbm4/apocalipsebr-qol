require("Bicycle/BicycleCore")
require("Bicycle/TimedAction/BicycleAttachPartAction")
require("Bicycle/TimedAction/BicycleDetachPartAction")

if isClient() then
    return
end

local Core = Bicycle.Core
local AttachmentActionUtils = require("Bicycle/AttachmentActionUtils")
local BicycleContainerManager = require("Bicycle/BicycleContainerManager")
local BicycleDebug = require("Bicycle/Debug")
local BicycleDropBehavior = require("Bicycle/DropBehavior")
local BicycleKickstand = require("Bicycle/Kickstand")
local BicycleMigration = require("Bicycle/Migration")
local BicyclePartAttachmentService = require("Bicycle/PartAttachmentService")
local BicycleUtils = require("Bicycle/Utils")
local SidecarAnimal = require("Bicycle/SidecarAnimal")

local Bridge = {}
Bridge[Core.SyncModule] = {}
local lastKnownStateById = {}
local DEBUG_SPAWN_TYPES = {
    ["Bicycle.Bicycle"] = true,
    ["Bicycle.Bicycle_Saddlebag"] = true,
    ["Bicycle.Bicycle_Basket"] = true,
    ["Bicycle.Bicycle_Crate"] = true
}
local MOUNT_BIKE_RETRY_COUNT = 30
local MOUNT_BIKE_RETRY_DELAY = 0.05
local MOUNT_BIKE_DISTANCE_SQ = 25

-- Tracks mount cancellations that arrived at the server before the matching
-- BicycleHopOnAction:complete() ran. :complete() consults this table and bails
-- if the player's mount has been cancelled, preventing the bike from being
-- committed to inventory.
local MOUNT_CANCEL_EXPIRY_MS = 5000
local pendingMountCancellations = {}

Bicycle.Sync = Bicycle.Sync or {}

---@param playerOnlineId number
---@param itemId number
---@param mountActionId number|nil
function Bicycle.Sync.markMountCancel(playerOnlineId, itemId, mountActionId)
    pendingMountCancellations[playerOnlineId] = {
        itemId = itemId,
        mountActionId = mountActionId,
        expiresAt = getTimestampMs() + MOUNT_CANCEL_EXPIRY_MS
    }
end

---@param playerOnlineId number
---@param itemId number
---@param mountActionId number|nil
---@return boolean
---@nodiscard
function Bicycle.Sync.consumeMountCancel(playerOnlineId, itemId, mountActionId)
    local pending = pendingMountCancellations[playerOnlineId]
    if not pending then
        return false
    end
    if pending.expiresAt < getTimestampMs() then
        pendingMountCancellations[playerOnlineId] = nil
        return false
    end
    if pending.itemId ~= itemId then
        return false
    end
    -- Scope the cancel to the specific action instance that requested it.
    -- A new BicycleHopOnAction has its own mountActionId, so a stale marker
    -- left over from an earlier cancelled-then-rejected attempt cannot
    -- spuriously bail a later mount's :complete().
    if pending.mountActionId ~= mountActionId then
        return false
    end
    pendingMountCancellations[playerOnlineId] = nil
    return true
end

BicycleDebug.log("server bootstrap loaded BicycleSyncServer")

---@param player IsoPlayer|nil
---@param args table|nil
---@return table|nil
local function buildState(player, args)
    if not (player and args) then
        return nil
    end

    local id = player:getOnlineID()
    if not id then
        return nil
    end

    return {
        id = id,
        active = args.active == true,
        riding = args.riding == true,
        walkSpeed = args.walkSpeed,
        runSpeed = args.runSpeed,
        speed = args.speed
    }
end

---@param player IsoPlayer|nil
---@param args table|nil
---@return IsoGridSquare|nil
local function resolveHintedSquare(player, args)
    if not (player and args) then
        return nil
    end

    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z)
    if not (x and y and z) then
        return nil
    end

    local sx = math.floor(x)
    local sy = math.floor(y)
    local sz = math.floor(z)
    local playerSquare = player:getSquare()
    if not playerSquare or playerSquare:getZ() ~= sz then
        return nil
    end

    local dx = playerSquare:getX() - sx
    local dy = playerSquare:getY() - sy
    if dx * dx + dy * dy > 25 then
        return nil
    end

    return getSquare(sx, sy, sz)
end

---@param container ItemContainer|nil
---@param itemId number|nil
---@return InventoryItem|nil
---@nodiscard
local function findItemByIdInContainer(container, itemId)
    if not (container and itemId) then
        return nil
    end

    if container.getItemWithID then
        local found = container:getItemWithID(itemId)
        if found then
            return found
        end
    end

    local items = container:getItems()
    if not items then
        return nil
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getID and item:getID() == itemId then
            return item
        end
    end

    return nil
end

---@param args table|nil
---@param prefix string
---@return string|nil
---@nodiscard
local function getTransferContainerKind(args, prefix)
    local kind = nil
    if args then
        kind = args[prefix .. "Kind"]
    end
    if type(kind) ~= "string" or kind == "" then
        return nil
    end

    return kind
end

---@param player IsoPlayer|nil
---@param args table|nil
---@param prefix string
---@return ItemContainer|nil
---@nodiscard
local function resolveTransferContainer(player, args, prefix)
    local kind = getTransferContainerKind(args, prefix)
    if kind == "player" then
        if player then
            return player:getInventory()
        end
        return nil
    end
    if kind ~= "vehicle" then
        return nil
    end

    local vehicleId = tonumber(args[prefix .. "VehicleId"])
    local partId = args[prefix .. "PartId"]
    if not (vehicleId and type(partId) == "string" and partId ~= "") then
        return nil
    end

    local vehicle = getVehicleById(vehicleId)
    if not vehicle then
        return nil
    end

    local part = vehicle:getPartById(partId)
    if not part then
        return nil
    end

    return part:getItemContainer()
end

---@param player IsoPlayer|nil
---@param itemId number|nil
---@param srcContainer ItemContainer|nil
---@param destContainer ItemContainer|nil
---@param hintedSquare IsoGridSquare|nil
---@return InventoryItem|nil
---@nodiscard
local function resolveBikeTransferItem(player, itemId, srcContainer, destContainer, hintedSquare)
    local fromDest = findItemByIdInContainer(destContainer, itemId)
    if BicycleUtils.isBicycleItem(fromDest) then
        return fromDest
    end

    local fromSrc = findItemByIdInContainer(srcContainer, itemId)
    if BicycleUtils.isBicycleItem(fromSrc) then
        return fromSrc
    end

    local fromWorldOrInventory = Core.findItemById(player, itemId, hintedSquare)
    if BicycleUtils.isBicycleItem(fromWorldOrInventory) then
        return fromWorldOrInventory
    end

    return nil
end

---@param player IsoPlayer|nil
---@param itemId number|nil
---@param reason string
local function sendMountBikeFailed(player, itemId, reason)
    if not player then
        return
    end

    BicycleDebug.log(
        "BicycleSyncServer:MountBike failed player=" .. BicycleDebug.describePlayer(player)
            .. ", itemId=" .. BicycleDebug.describeValue(itemId)
            .. ", reason=" .. reason
    )
    sendServerCommand(player, Core.SyncModule, "MountBikeFailed", {
        itemId = itemId,
        reason = reason
    })
end

---@param player IsoPlayer|nil
---@param itemId number
---@return InventoryItem|nil
---@nodiscard
local function findEquippedBikeById(player, itemId)
    if not player then
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

---@param player IsoPlayer|nil
---@param itemId number
---@return InventoryItem|nil
---@nodiscard
local function findInventoryBikeById(player, itemId)
    if not player then
        return nil
    end

    local item = findItemByIdInContainer(player:getInventory(), itemId)
    if BicycleUtils.isBicycleItem(item) then
        return item
    end

    return nil
end

---@param item InventoryItem|nil
---@return IsoGridSquare|nil
---@nodiscard
local function getItemWorldSquare(item)
    if not (item and item.getWorldItem) then
        return nil
    end

    local worldItem = item:getWorldItem()
    if not worldItem then
        return nil
    end

    return worldItem:getSquare()
end

---@param player IsoPlayer|nil
---@param square IsoGridSquare|nil
---@return boolean
---@nodiscard
local function isSquareReachableForMount(player, square)
    if not (player and square) then
        return false
    end

    local playerSquare = player:getSquare()
    if not playerSquare then
        return false
    end
    if playerSquare:getZ() ~= square:getZ() then
        return false
    end

    local dx = playerSquare:getX() - square:getX()
    local dy = playerSquare:getY() - square:getY()
    return dx * dx + dy * dy <= MOUNT_BIKE_DISTANCE_SQ
end

---@param player IsoPlayer|nil
---@param itemId number
---@param hintedSquare IsoGridSquare|nil
---@param allowWorld boolean
---@return InventoryItem|nil
---@nodiscard
local function resolveMountBikeItem(player, itemId, hintedSquare, allowWorld)
    local equippedItem = findEquippedBikeById(player, itemId)
    if equippedItem then
        return equippedItem
    end

    local inventoryItem = findInventoryBikeById(player, itemId)
    if inventoryItem then
        return inventoryItem
    end

    if not allowWorld then
        return nil
    end

    local nearbyItem = Core.findItemById(player, itemId, hintedSquare)
    if BicycleUtils.isBicycleItem(nearbyItem) and getItemWorldSquare(nearbyItem) then
        return nearbyItem
    end

    return nil
end

---@param player IsoPlayer
---@param bikeItem InventoryItem
local function equipMountBikeOnServer(player, bikeItem)
    local inventory = player:getInventory()
    if getItemWorldSquare(bikeItem) then
        BicycleUtils.removeWorldItem(bikeItem)
    end

    local container = nil
    if bikeItem.getContainer then
        container = bikeItem:getContainer()
    end
    if container ~= inventory then
        BicycleUtils.removeItemFromContainer(bikeItem)
        inventory:AddItem(bikeItem)
        sendAddItemToContainer(inventory, bikeItem)
    end

    BicycleMigration.normalizeKickstandState(bikeItem, player)
    BicycleKickstand.ensureState(bikeItem, player, "up")
    player:setVariable(Core.PlayerVars.Active, "true")
    player:setVariable(Core.PlayerVars.Riding, "false")
    player:setVariable("Bicycle_Stopping", false)
    player:setVariable("droppingBicycle", false)

    -- Server-side setPrimaryHandItem auto-broadcasts an EquipPacket via
    -- preupdate (handItemShouldSendToClients flag), which races
    -- AddInventoryItemToContainerPacket on a different channel — on a
    -- listen-server host the Equip wins, the bike is "equipped" before it
    -- exists in the client's inventory, and the player gets stuck in idle
    -- with no riding animation. Defer to MountEquip: the client polls until
    -- the bike is observed locally, then equips client-side. Matches
    -- BicycleHopOnAction:complete().
    sendServerCommand(player, Core.SyncModule, "MountEquip", {
        itemId = bikeItem:getID()
    })
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].SetState = function(player, args)
    local state = buildState(player, args)
    if not state then
        return
    end

    sendServerCommand(Core.SyncModule, "SetState", state)
    lastKnownStateById[state.id] = state
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].RequestState = function(player, args)
    for _, state in pairs(lastKnownStateById) do
        sendServerCommand(Core.SyncModule, "SetState", state)
    end
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].MountBike = function(player, args)
    if not player then
        return
    end
    if not args then
        sendMountBikeFailed(player, nil, "missing_args")
        return
    end

    local itemId = tonumber(args.itemId)
    if not itemId then
        sendMountBikeFailed(player, nil, "invalid_item_id")
        return
    end

    local hintedSquare = resolveHintedSquare(player, args)
    if not hintedSquare then
        hintedSquare = player:getSquare()
        if not hintedSquare then
            sendMountBikeFailed(player, itemId, "invalid_square")
            return
        end
    end

    BicycleDebug.log(
        "BicycleSyncServer:MountBike request player=" .. BicycleDebug.describePlayer(player)
            .. ", itemId=" .. tostring(itemId)
            .. ", square=" .. BicycleDebug.describeSquare(hintedSquare)
            .. ", mountAnim=" .. BicycleDebug.describeValue(args.mountAnim)
    )

    local function tryMount(retriesRemaining)
        local bikeItem = resolveMountBikeItem(player, itemId, hintedSquare, true)
        if not bikeItem then
            if retriesRemaining > 0 then
                BicycleDebug.log(
                    "BicycleSyncServer:MountBike retry itemId=" .. tostring(itemId)
                        .. ", remaining=" .. tostring(retriesRemaining)
                )
                BicycleUtils.runAfter(MOUNT_BIKE_RETRY_DELAY, function()
                    tryMount(retriesRemaining - 1)
                end)
                return
            end

            sendMountBikeFailed(player, itemId, "item_not_found")
            return
        end

        if not BicycleUtils.isBicycleItem(bikeItem) then
            sendMountBikeFailed(player, itemId, "not_bicycle")
            return
        end

        local worldSquare = getItemWorldSquare(bikeItem)
        if worldSquare and not isSquareReachableForMount(player, worldSquare) then
            sendMountBikeFailed(player, itemId, "out_of_reach")
            return
        end

        equipMountBikeOnServer(player, bikeItem)
        BicycleDebug.log(
            "BicycleSyncServer:MountBike success player=" .. BicycleDebug.describePlayer(player)
                .. ", item=" .. BicycleDebug.describeItem(bikeItem)
        )
    end

    tryMount(MOUNT_BIKE_RETRY_COUNT)
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].SetKickstand = function(player, args)
    if not (player and args and args.itemId and args.targetState) then
        return
    end

    local item = Core.findItemById(player, args.itemId)
    if not BicycleUtils.isBicycleItem(item) then
        return
    end

    BicycleMigration.normalizeKickstandState(item, player)
    BicycleKickstand.ensureState(item, player, args.targetState)

    sendServerCommand(Core.SyncModule, "SetKickstandVisual", {
        id = player:getOnlineID(),
        targetState = args.targetState
    })
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].DropBike = function(player, args)
    if not (player and args and args.itemId) then
        return
    end

    local bikeItem = Core.findItemById(player, args.itemId)
    if not BicycleUtils.isBicycleItem(bikeItem) then
        return
    end

    local square = player:getSquare()
    local hintedSquare = resolveHintedSquare(player, args)
    if hintedSquare then
        square = hintedSquare
    end
    if not square then
        return
    end

    if player:getPrimaryHandItem() == bikeItem or player:getSecondaryHandItem() == bikeItem then
        player:removeFromHands(bikeItem)
        if sendEquip then
            sendEquip(player)
        end
    end


    BicycleUtils.removeWorldItem(bikeItem)
    BicycleUtils.removeItemFromContainer(bikeItem)

    -- The bike leaves its container before the placement is known to be accepted, and addPersistentWorldItem
    -- returns the item even when refused -- so falling back to bikeItem masked the failure and destroyed it.
    local placedItem = BicycleUtils.addPersistentWorldItem(square, bikeItem, 0, 0, 0)
    local placedWorldItem = placedItem and placedItem.getWorldItem and placedItem:getWorldItem() or nil
    if not placedWorldItem then
        -- Give it back rather than destroy it.
        local inventory = player:getInventory()
        if inventory and inventory.AddItem then
            inventory:AddItem(bikeItem)
            if sendEquip then
                sendEquip(player)
            end
        end
        return
    end

    local droppedBikeItem = placedItem
    if args.worldXRotation ~= nil and droppedBikeItem.setWorldXRotation then
        droppedBikeItem:setWorldXRotation(args.worldXRotation)
    end
    if args.worldYRotation ~= nil and droppedBikeItem.setWorldYRotation then
        droppedBikeItem:setWorldYRotation(args.worldYRotation)
    end
    if args.worldZRotation ~= nil and droppedBikeItem.setWorldZRotation then
        droppedBikeItem:setWorldZRotation(args.worldZRotation)
    end
    BicycleDropBehavior.applyDropState(droppedBikeItem, player, args.dismountData)
    BicycleContainerManager.syncBikeContainers(player, droppedBikeItem, square, nil)
end

---@param player IsoPlayer
---@param bikeItem InventoryItem
---@param square IsoGridSquare
---@param rotation table|nil
local function undoCommittedMount(player, bikeItem, square, rotation)
    if player:getPrimaryHandItem() == bikeItem or player:getSecondaryHandItem() == bikeItem then
        player:removeFromHands(bikeItem)
    end
    BicycleUtils.removeItemFromContainer(bikeItem)
    local droppedBikeItem = BicycleUtils.addPersistentWorldItem(square, bikeItem, 0, 0, 0) or bikeItem
    if rotation then
        if rotation.x ~= nil and droppedBikeItem.setWorldXRotation then
            droppedBikeItem:setWorldXRotation(rotation.x)
        end
        if rotation.y ~= nil and droppedBikeItem.setWorldYRotation then
            droppedBikeItem:setWorldYRotation(rotation.y)
        end
        if rotation.z ~= nil and droppedBikeItem.setWorldZRotation then
            droppedBikeItem:setWorldZRotation(rotation.z)
        end
    end

    player:setVariable("BicycleActive", "false")
    player:setVariable("Bicycle_Riding", "false")
    player:setVariable("Bicycle_Stopping", false)
    player:setVariable("droppingBicycle", false)
    player:setVariable("Bicycle_MountPending", false)

    sendServerCommand(player, Core.SyncModule, "MountCancelled", {
        itemId = bikeItem:getID()
    })
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].CancelMount = function(player, args)
    if not (player and args and args.itemId) then
        return
    end
    local itemId = tonumber(args.itemId)
    if not itemId then
        return
    end
    local mountActionId = tonumber(args.mountActionId)

    -- Mark the cancel so a still-pending :complete() bails before committing.
    -- The marker carries the action instance id so a later mount attempt's
    -- :complete() cannot match this cancel by player+itemId alone.
    Bicycle.Sync.markMountCancel(player:getOnlineID(), itemId, mountActionId)

    -- If :complete() already committed the bike to inventory, undo it now.
    local bikeItem = player:getInventory():getItemWithID(itemId)
    if not (bikeItem and BicycleUtils.isBicycleItem(bikeItem)) then
        BicycleDebug.log(
            "BicycleSyncServer:CancelMount marked pre-commit player=" .. BicycleDebug.describePlayer(player)
                .. ", itemId=" .. tostring(itemId)
                .. ", mountActionId=" .. tostring(mountActionId)
        )
        return
    end

    local square = resolveHintedSquare(player, args) or player:getSquare()
    if not square then
        BicycleDebug.log(
            "BicycleSyncServer:CancelMount no square for undo player=" .. BicycleDebug.describePlayer(player)
                .. ", itemId=" .. tostring(itemId)
        )
        return
    end

    local rotation = {
        x = args.worldXRotation,
        y = args.worldYRotation,
        z = args.worldZRotation
    }

    undoCommittedMount(player, bikeItem, square, rotation)
    -- The cancel is fully resolved (bike already removed from inventory and
    -- placed back in the world). Drop the marker so it cannot interfere with
    -- a subsequent mount attempt.
    pendingMountCancellations[player:getOnlineID()] = nil
    BicycleDebug.log(
        "BicycleSyncServer:CancelMount undid commit player=" .. BicycleDebug.describePlayer(player)
            .. ", itemId=" .. tostring(itemId)
            .. ", square=" .. BicycleDebug.describeSquare(square)
    )
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].ApplyWearTick = function(player, args)
    if not (player and args and args.itemId and args.partType) then
        return
    end

    local bikeItem = Core.findItemById(player, args.itemId)
    if not BicycleUtils.isBicycleItem(bikeItem) then
        return
    end

    local part = bikeItem:getWeaponPart(args.partType)
    if not part then
        return
    end

    local conditionLoss = tonumber(args.conditionLoss)
    local elapsed = tonumber(args.elapsed)
    if not conditionLoss or not elapsed then
        return
    end

    if part.getCondition and part.setCondition then
        part:setCondition(math.max(0, part:getCondition() - conditionLoss))
    end

    if args.flat == true then
        local normalToFlat = {
            ["Bicycle.Bicycle_StreetWheelFrontItem"] = "Bicycle.Bicycle_StreetWheelFrontFlatItem",
            ["Bicycle.Bicycle_StreetWheelRearItem"] = "Bicycle.Bicycle_StreetWheelRearFlatItem",
            ["Bicycle.Bicycle_OffroadWheelFrontItem"] = "Bicycle.Bicycle_OffroadWheelFrontFlatItem",
            ["Bicycle.Bicycle_OffroadWheelRearItem"] = "Bicycle.Bicycle_OffroadWheelRearFlatItem",
        }
        local flatFullType = normalToFlat[part:getFullType()]
        if flatFullType then
            local flatPart = instanceItem(flatFullType)
            if flatPart then
                if part.getCondition and flatPart.setCondition then
                    flatPart:setCondition(math.max(0, part:getCondition() - conditionLoss))
                end
                if part.getUsedDelta and flatPart.setUsedDelta then
                    flatPart:setUsedDelta(part:getUsedDelta())
                end
                local targetModData = flatPart:getModData()
                targetModData.bicycleWearElapsed = elapsed
                bikeItem:detachWeaponPart(player, part)
                bikeItem:attachWeaponPart(flatPart, true)
                local inv = player:getInventory()
                if inv:contains(part) then
                    inv:Remove(part)
                    sendRemoveItemFromContainer(inv, part)
                end

                local bikeModData = bikeItem:getModData()
                local mdKey = "bicycleFlat" .. flatPart:getPartType()
                bikeModData[mdKey] = flatFullType
                if bikeItem.transmitModData then
                    bikeItem:transmitModData()
                end

                if flatPart.transmitModData then
                    flatPart:transmitModData()
                end
                return
            end
        end
    end

    if part.getModData then
        local modData = part:getModData()
        modData.bicycleWearElapsed = elapsed
        if part.transmitModData then
            part:transmitModData()
        end
    end
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].TransferContainer = function(player, args)
    if not (player and args and args.itemId) then
        return
    end

    local itemId = tonumber(args.itemId)
    if not itemId then
        return
    end

    local targetSquare = player:getSquare()
    local hintedSquare = resolveHintedSquare(player, args)
    if hintedSquare then
        targetSquare = hintedSquare
    end

    local bikeItem = Core.findItemById(player, itemId, hintedSquare)
    if not BicycleUtils.isBicycleItem(bikeItem) then
        return
    end

    local partType = args.partType
    if type(partType) ~= "string" or partType == "" then
        partType = nil
    end

    BicycleContainerManager.syncBikeContainers(player, bikeItem, targetSquare, partType)
    sendServerCommand(Core.SyncModule, "ContainerUpdated", {
        id = player:getOnlineID()
    })
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].TransferBikeContainers = function(player, args)
    if not (player and args and args.itemId) then
        return
    end

    local itemId = tonumber(args.itemId)
    if not itemId then
        return
    end

    local srcContainer = resolveTransferContainer(player, args, "src")
    local destContainer = resolveTransferContainer(player, args, "dest")
    local hintedSquare = resolveHintedSquare(player, args)
    local targetSquare = hintedSquare or player:getSquare()
    local srcKind = getTransferContainerKind(args, "src")
    local destKind = getTransferContainerKind(args, "dest")
    local srcIsStorage = srcKind == "vehicle" or srcKind == "player"
    local destIsStorage = destKind == "vehicle" or destKind == "player"
    if not (srcIsStorage or destIsStorage) then
        return
    end

    local function tryTransfer(retriesRemaining)
        local bikeItem = resolveBikeTransferItem(player, itemId, srcContainer, destContainer, hintedSquare)
        if not bikeItem then
            if retriesRemaining > 0 then
                BicycleUtils.runAfter(0.05, function()
                    tryTransfer(retriesRemaining - 1)
                end)
            end
            return
        end

        -- Route by DESTINATION, not by whether the source is also packed-storage.
        -- A vehicle-trunk / player-inventory destination keeps the bike's hidden
        -- containers PACKED, so it must go through transferBikeContainersToContainer:
        -- that path gathers each container whether it is currently packed in the
        -- source OR materialized as a world item at the bike's square (the mounted /
        -- ridden case, where getBikeTrackingSquare puts the containers at the rider's
        -- feet). transferBikeContainersFromContainer only unpacks a packed source to a
        -- world drop and has NO world-item fallback, so routing a ridden bike through
        -- it left the foot-level containers orphaned -- the OnTick cleanup then
        -- spilled/removed them instead of moving them into the trunk.
        if destIsStorage then
            BicycleContainerManager.transferBikeContainersToContainer(player, bikeItem, srcContainer, destContainer)
        else
            BicycleContainerManager.transferBikeContainersFromContainer(
                player,
                bikeItem,
                srcContainer,
                targetSquare,
                destContainer
            )
        end

        sendServerCommand(Core.SyncModule, "ContainerUpdated", {
            id = player:getOnlineID()
        })
    end

    tryTransfer(8)
end

---@param player IsoPlayer|nil
---@param reason string
local function sendSidecarFailed(player, reason)
    if not player then
        return
    end
    if isServer() then
        sendServerCommand(player, Core.SyncModule, "SidecarAnimalFailed", {
            reason = reason
        })
    else
        -- Singleplayer: BicycleSyncClient bails on SP so OnServerCommand
        -- handlers are never registered. Say the failure directly.
        player:Say(getText("IGUI_Bicycle_Sidecar_Failed_" .. reason))
    end
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@return boolean
---@nodiscard
local function canSidecarReach(player, bikeItem)
    return BicyclePartAttachmentService.canAccessBike(player, bikeItem)
end

local ANIMAL_PICKUP_RANGE_SQ = 9

---@param worldAnimalId number|nil
---@return IsoAnimal|nil
---@nodiscard
local function findWorldAnimalById(worldAnimalId)
    if not worldAnimalId or worldAnimalId <= 0 then
        return nil
    end
    -- Vanilla Lua-exposed global (LuaManager.GlobalObject.getAnimal). It
    -- internally calls AnimalInstanceManager.getInstance().get(short). Only
    -- resolves on dedicated MP server; SP returns nil because IsoAnimal.init
    -- skips AnimalInstanceManager.add unless GameServer.server is true.
    return getAnimal(worldAnimalId)
end

---@param square IsoGridSquare|nil
---@param animalType string|nil
---@return IsoAnimal|nil
---@nodiscard
local function findAnimalOnSquareByType(square, animalType)
    if not (square and animalType) then
        return nil
    end
    local objects = square:getMovingObjects()
    if not objects then
        return nil
    end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoAnimal") and obj:getAnimalType() == animalType then
            return obj
        end
    end
    return nil
end

---@param args table
---@return IsoAnimal|nil
---@nodiscard
local function resolveWorldAnimal(args)
    local byId = findWorldAnimalById(tonumber(args.worldAnimalId))
    if byId then
        return byId
    end

    local animalType = args.worldAnimalType
    if type(animalType) ~= "string" or animalType == "" then
        return nil
    end

    local x = tonumber(args.worldAnimalX)
    local y = tonumber(args.worldAnimalY)
    local z = tonumber(args.worldAnimalZ)
    if not (x and y and z) then
        return nil
    end

    -- Scan the recorded square first, then a 1-tile ring in case the animal
    -- wandered between right-click and action completion.
    local exact = findAnimalOnSquareByType(getSquare(x, y, z), animalType)
    if exact then
        return exact
    end
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local found = findAnimalOnSquareByType(getSquare(x + dx, y + dy, z), animalType)
                if found then
                    return found
                end
            end
        end
    end
    return nil
end

---@param player IsoPlayer|nil
---@param animal IsoAnimal|nil
---@return boolean
---@nodiscard
local function isWorldAnimalReachable(player, animal)
    if not (player and animal) then
        return false
    end
    local animalSquare = animal:getSquare()
    local playerSquare = player:getSquare()
    if not (animalSquare and playerSquare) then
        return false
    end
    if animalSquare:getZ() ~= playerSquare:getZ() then
        return false
    end
    local dx = animalSquare:getX() - playerSquare:getX()
    local dy = animalSquare:getY() - playerSquare:getY()
    return dx * dx + dy * dy <= ANIMAL_PICKUP_RANGE_SQ
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].PlaceAnimalInSidecar = function(player, args)
    if not (player and args) then
        return
    end

    local bikeItemId = tonumber(args.bikeItemId)
    if not bikeItemId then
        sendSidecarFailed(player, "unknown")
        return
    end

    local hintedSquare = resolveHintedSquare(player, args)
    local bikeItem = Core.findItemById(player, bikeItemId, hintedSquare)
    if not BicycleUtils.isBicycleItem(bikeItem) then
        sendSidecarFailed(player, "unknown")
        return
    end

    if not bikeItem:getWeaponPart("Sidecar") then
        sendSidecarFailed(player, "no_sidecar")
        return
    end

    if SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
        sendSidecarFailed(player, "sidecar_full")
        return
    end

    if not canSidecarReach(player, bikeItem) then
        sendSidecarFailed(player, "out_of_reach")
        return
    end

    local sidecarContainerItem = BicycleContainerManager.findSidecarContainerItem(player, bikeItem)
    if not sidecarContainerItem then
        sendSidecarFailed(player, "sidecar_container_missing")
        return
    end
    local sidecarContainer = sidecarContainerItem:getItemContainer()
    if not sidecarContainer then
        sendSidecarFailed(player, "sidecar_container_missing")
        return
    end

    local animalItem = nil
    local playerInv = player:getInventory()

    if args.sourceMode == "held" then
        local animalItemId = tonumber(args.animalItemId)
        if not animalItemId then
            sendSidecarFailed(player, "animal_item_missing")
            return
        end
        animalItem = playerInv:getItemWithID(animalItemId)
        if not SidecarAnimal.isAllowedAnimalItem(animalItem) then
            if SidecarAnimal.isAnimalItem(animalItem) then
                sendSidecarFailed(player, "species_not_allowed")
            else
                sendSidecarFailed(player, "animal_item_missing")
            end
            return
        end

        if player:getPrimaryHandItem() == animalItem then
            player:setPrimaryHandItem(nil)
        end
        if player:getSecondaryHandItem() == animalItem then
            player:setSecondaryHandItem(nil)
        end
        if sendEquip then
            sendEquip(player)
        end
        playerInv:Remove(animalItem)
        sendRemoveItemFromContainer(playerInv, animalItem)
    elseif args.sourceMode == "world" then
        local worldAnimal = resolveWorldAnimal(args)
        if not worldAnimal then
            sendSidecarFailed(player, "animal_item_missing")
            return
        end
        if not isWorldAnimalReachable(player, worldAnimal) then
            sendSidecarFailed(player, "out_of_reach")
            return
        end
        local animalType = worldAnimal:getAnimalType()
        if not SidecarAnimal.isAllowedAnimalType(animalType) then
            sendSidecarFailed(player, "species_not_allowed")
            return
        end

        animalItem = instanceItem("Base.Animal")
        if not animalItem then
            sendSidecarFailed(player, "animal_item_missing")
            return
        end
        -- setAnimal links the held animal to the inventory item and calls
        -- setItemID internally, so no separate itemId field write is needed
        -- (and Kahlua cannot write the field directly anyway).
        animalItem:setAnimal(worldAnimal)
        worldAnimal:setWild(false)
        -- IsoAnimal:remove() → delete() removes from world, removes from square,
        -- and on a dedicated server pushes the deletion to AnimalSynchronization-
        -- Manager so all clients drop their copy. Plain removeFromWorld doesn't
        -- broadcast — that's why the world animal lingered on listen-server
        -- clients before. The state we care about is already copied into
        -- animalItem via setAnimal, so destroying the world instance is safe.
        worldAnimal:remove()
    else
        sendSidecarFailed(player, "unknown")
        return
    end

    local partFullType = SidecarAnimal.getFullTypeForAnimal(animalItem:getAnimal())
    if not partFullType then
        sendSidecarFailed(player, "species_not_allowed")
        return
    end

    local partItem = instanceItem(partFullType)
    if not partItem then
        sendSidecarFailed(player, "unknown")
        return
    end

    partItem:getModData()[SidecarAnimal.BACKREF_MODDATA_KEY] = animalItem:getID()
    if partItem.transmitModData then
        partItem:transmitModData()
    end

    sidecarContainer:AddItem(animalItem)
    sendAddItemToContainer(sidecarContainer, animalItem)

    bikeItem:attachWeaponPart(player, partItem)

    -- Force the bike world model to re-render so the animal-part visual
    -- appears immediately, matching the standard attach/detach refresh path.
    AttachmentActionUtils.refreshBikeState(player, bikeItem)

    BicycleContainerManager.syncBikeContainers(
        player,
        bikeItem,
        AttachmentActionUtils.resolveBikeSquare(player, bikeItem),
        "Sidecar"
    )

    sendServerCommand(Core.SyncModule, "ContainerUpdated", {
        id = player:getOnlineID()
    })
    sendServerCommand(player, Core.SyncModule, "SidecarAnimalPlaced", {
        bikeItemId = bikeItemId
    })

    BicycleDebug.log(
        "BicycleSyncServer:PlaceAnimalInSidecar success player=" .. BicycleDebug.describePlayer(player)
            .. ", bike=" .. BicycleDebug.describeItem(bikeItem)
            .. ", part=" .. BicycleDebug.describeItem(partItem)
    )
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].ReleaseAnimalFromSidecar = function(player, args)
    if not (player and args) then
        return
    end

    local bikeItemId = tonumber(args.bikeItemId)
    if not bikeItemId then
        sendSidecarFailed(player, "unknown")
        return
    end

    local hintedSquare = resolveHintedSquare(player, args)
    local bikeItem = Core.findItemById(player, bikeItemId, hintedSquare)
    if not BicycleUtils.isBicycleItem(bikeItem) then
        sendSidecarFailed(player, "unknown")
        return
    end

    if not canSidecarReach(player, bikeItem) then
        sendSidecarFailed(player, "out_of_reach")
        return
    end

    local partItem = SidecarAnimal.getAttachedAnimalPart(bikeItem)
    if not partItem then
        sendSidecarFailed(player, "no_animal_in_sidecar")
        return
    end

    local sidecarContainerItem = BicycleContainerManager.findSidecarContainerItem(player, bikeItem)
    if not sidecarContainerItem then
        sendSidecarFailed(player, "sidecar_container_missing")
        return
    end
    local sidecarContainer = sidecarContainerItem:getItemContainer()
    if not sidecarContainer then
        sendSidecarFailed(player, "sidecar_container_missing")
        return
    end

    local animalItem = SidecarAnimal.findStoredAnimalItem(sidecarContainerItem)
    if not animalItem then
        sendSidecarFailed(player, "animal_item_missing")
        return
    end

    local dropSquare = AttachmentActionUtils.resolveBikeSquare(player, bikeItem)
    if not dropSquare then
        sendSidecarFailed(player, "out_of_reach")
        return
    end

    local heldAnimal = animalItem:getAnimal()
    local newAnimal = IsoAnimal.new(
        getCell(),
        dropSquare:getX(),
        dropSquare:getY(),
        dropSquare:getZ(),
        heldAnimal:getAnimalType(),
        heldAnimal:getBreed()
    )
    newAnimal:copyFrom(heldAnimal)
    -- Kahlua can't assign Java fields directly (e.g. `newAnimal.itemId = 0`
    -- throws "attempted index of non-table"). Use the setter.
    newAnimal:setItemID(0)
    -- AnimalInstanceManager has no @UsedFromLua binding, so we cannot
    -- re-register the dropped animal under its original online id from Lua.
    -- IsoAnimal:update() on a dedicated server calls AnimalInstanceManager
    -- automatically, so MP sync catches up on the next tick.
    newAnimal:addToWorld()
    newAnimal:playBreedSound("put_down")

    sidecarContainer:Remove(animalItem)
    sendRemoveItemFromContainer(sidecarContainer, animalItem)

    bikeItem:detachWeaponPart(player, partItem)

    -- Force the bike world model to re-render so the animal-part visual goes
    -- away on screen the same way attach/detach of other parts refreshes.
    AttachmentActionUtils.refreshBikeState(player, bikeItem)

    BicycleContainerManager.syncBikeContainers(
        player,
        bikeItem,
        dropSquare,
        "Sidecar"
    )

    sendServerCommand(Core.SyncModule, "ContainerUpdated", {
        id = player:getOnlineID()
    })
    sendServerCommand(player, Core.SyncModule, "SidecarAnimalReleased", {
        bikeItemId = bikeItemId
    })

    BicycleDebug.log(
        "BicycleSyncServer:ReleaseAnimalFromSidecar success player=" .. BicycleDebug.describePlayer(player)
            .. ", bike=" .. BicycleDebug.describeItem(bikeItem)
    )
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].Sound = function(player, args)
    if not (player and args and args.sound ~= nil and args.playing ~= nil) then
        return
    end

    sendServerCommand(Core.SyncModule, "Sound", {
        id = player:getOnlineID(),
        sound = args.sound,
        playing = args.playing == true
    })
end

---@param player IsoPlayer|nil
---@param args table|nil
Bridge[Core.SyncModule].SpawnDebugItem = function(player, args)
    if not (player and args and args.fullType) then
        return
    end
    if not player:isAccessLevel("admin") then
        return
    end
    if DEBUG_SPAWN_TYPES[args.fullType] ~= true then
        return
    end

    local item = player:getInventory():AddItem(args.fullType)
    if item then
        sendAddItemToContainer(player:getInventory(), item)
    end
end

---@param module string
---@param command string
---@param player IsoPlayer
---@param args table
local function handleClientCommand(module, command, player, args)
    local modTable = Bridge[module]
    if modTable and modTable[command] then
        modTable[command](player, args)
    end
end

Events.OnClientCommand.Add(handleClientCommand)
