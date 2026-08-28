require("Bicycle/BicycleCore")
require("Bicycle/Utils")

if not isClient() then
    return
end

local Core = Bicycle.Core
local BicycleDebug = require("Bicycle/Debug")
local BicycleKickstand = require("Bicycle/Kickstand")
local BicycleMountDismountState = require("Bicycle/MountDismountState")
local BicycleRidingSystem = require("Bicycle/Systems/RidingSystem")
local BicycleUtils = require("Bicycle/Utils")

local Handlers = {}
Handlers[Core.SyncModule] = {}
local lastRemoteSoundUpdate = 0
local remoteSoundUpdateMs = 250

local Client = {}
Client.lastSyncedState = Client.lastSyncedState or {}
Client.lastSyncedSoundState = Client.lastSyncedSoundState or {}

---@param player IsoPlayer
---@param baseVolume number
---@param soundRange number
---@return number|nil
local function getRemoteVolume(player, baseVolume, soundRange, localPlayer)
    localPlayer = localPlayer or getPlayer() or getSpecificPlayer(0)
    if localPlayer and soundRange > 0 then
        local dx = player:getX() - localPlayer:getX()
        local dy = player:getY() - localPlayer:getY()
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance > soundRange then
            return nil
        end

        local t = math.min(distance / soundRange, 1.0)
        return baseVolume * (1.0 - t) * (1.0 - t)
    end

    return baseVolume
end

---@return number
---@nodiscard
local function getBicycleSoundVolume()
    if isClient() and SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.SoundVolume then
        return SandboxVars.Bicycle.SoundVolume
    end

    if isServer() and SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.SoundVolume then
        return SandboxVars.Bicycle.SoundVolume
    end

    if PZAPI and PZAPI.ModOptions then
        local options = PZAPI.ModOptions:getOptions("BicycleMod")
        if options then
            local option = options:getOption("BicycleSoundVolume")
            if option then
                return option:getValue()
            end
        end
    end

    return 0.40
end

---@param player IsoPlayer
---@return nil
local function stopBicycleAudio(player)
    local emitter = player:getEmitter()
    if not emitter then
        return
    end

    local modData = player:getModData()
    modData.bicycleSoundIds = modData.bicycleSoundIds or {}

    if emitter:isPlaying("Bicycle_Riding") then
        emitter:stopSoundByName("Bicycle_Riding")
    end

    modData.bicycleSoundIds["Bicycle_Riding"] = nil
end

---@param player IsoPlayer|nil
---@param itemId number|nil
---@return boolean
---@nodiscard
local function playerHasBicycleItemId(player, itemId)
    if not (player and itemId) then
        return false
    end

    local primaryItem = player:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) and primaryItem.getID and primaryItem:getID() == itemId then
        return true
    end

    local secondaryItem = player:getSecondaryHandItem()
    if BicycleUtils.isBicycleItem(secondaryItem) and secondaryItem.getID and secondaryItem:getID() == itemId then
        return true
    end

    return false
end

---@param itemId number|nil
---@return IsoPlayer|nil
---@nodiscard
local function findLocalPlayerForMountFailure(itemId)
    local playerCount = getNumActivePlayers()
    for playerIndex = 0, playerCount - 1 do
        local player = getSpecificPlayer(playerIndex)
        if playerHasBicycleItemId(player, itemId) then
            return player
        end
    end

    return getSpecificPlayer(0)
end

---@param player IsoPlayer|nil
---@param itemId number|nil
---@param reason string|nil
local function clearLocalMountAfterFailure(player, itemId, reason)
    if not player then
        return
    end

    BicycleDebug.log(
        "BicycleSyncClient:MountBikeFailed itemId=" .. BicycleDebug.describeValue(itemId)
            .. ", reason=" .. BicycleDebug.describeValue(reason)
    )

    stopBicycleAudio(player)

    local primary = player:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primary) then
        player:setPrimaryHandItem(nil)
    end
    local secondary = player:getSecondaryHandItem()
    if BicycleUtils.isBicycleItem(secondary) then
        player:setSecondaryHandItem(nil)
    end
    player:resetEquippedHandsModels()

    BicycleMountDismountState.resetAllBikeVariables(player)
    player:setBlockMovement(false)
    player:setIgnoreMovement(false)
    player:setTurnDelta(1)
    player:setAllowRun(true)
    player:setForceSprint(false)
    player:setCanShout(true)
    player:setBannedAttacking(false)
    player:setIgnoreAutoVault(false)
    BicycleRidingSystem.ensureUpdateHandlers()
    Client.syncState(player, true)
end

---@param player IsoPlayer|nil
---@param soundName string
---@param isPlaying boolean
---@return nil
function Client.syncSoundState(player, soundName, isPlaying)
    if not (isClient() and player) then
        return
    end

    if player.isLocalPlayer and not player:isLocalPlayer() then
        return
    end

    local previousState = Client.lastSyncedSoundState[soundName]
    if previousState == isPlaying then
        return
    end

    sendClientCommand(Core.SyncModule, "Sound", {
        sound = soundName,
        playing = isPlaying
    })
    Client.lastSyncedSoundState[soundName] = isPlaying
end

---@param player IsoPlayer
---@param args table
---@return nil
local function syncRemoteBicycleSound(player, args)
    if player.isLocalPlayer and player:isLocalPlayer() then
        return
    end

    local emitter = player:getEmitter()
    if not emitter then
        return
    end

    local soundName = args and args.sound or nil
    if not soundName then
        return
    end

    local modData = player:getModData()
    modData.bicycleSoundIds = modData.bicycleSoundIds or {}

    if not args.playing then
        if emitter:isPlaying(soundName) then
            emitter:stopSoundByName(soundName)
        end
        modData.bicycleSoundIds[soundName] = nil
        return
    end

    local soundVolume = getBicycleSoundVolume()
    local soundRange = 15
    local volume = getRemoteVolume(player, soundVolume, soundRange)
    if not volume then
        if emitter:isPlaying(soundName) then
            emitter:stopSoundByName(soundName)
        end
        modData.bicycleSoundIds[soundName] = nil
        return
    end

    if emitter:isPlaying(soundName) then
        emitter:stopSoundByName(soundName)
    end

    local sound = emitter:playSoundImpl(soundName, nil)
    emitter:setVolume(sound, volume)
    modData.bicycleSoundIds[soundName] = sound
end

---@param player IsoPlayer|nil
---@return nil
local function updateRemoteRidingSounds(player)
    if not (player and player.isLocalPlayer and player:isLocalPlayer()) then
        return
    end

    local now = getTimestampMs()
    if now - lastRemoteSoundUpdate < remoteSoundUpdateMs then
        return
    end
    lastRemoteSoundUpdate = now

    local soundVolume = getBicycleSoundVolume()
    local soundRange = 15

    local function syncRidingForPlayer(remote)
        if not remote or (remote.isLocalPlayer and remote:isLocalPlayer()) then
            return
        end

        local emitter = remote:getEmitter()
        if not emitter then
            return
        end

        local modData = remote:getModData()
        modData.bicycleSoundIds = modData.bicycleSoundIds or {}

        local isMoving = remote.getVariableBoolean and remote:getVariableBoolean("ismoving") or false
        if remote.isPlayerMoving then
            isMoving = remote:isPlayerMoving()
        end

        local shouldPlay = remote:getVariableBoolean(Core.PlayerVars.Active)
            and remote:getVariableBoolean(Core.PlayerVars.Riding)
            and isMoving

        if not shouldPlay then
            if emitter:isPlaying("Bicycle_Riding") then
                emitter:stopSoundByName("Bicycle_Riding")
            end
            modData.bicycleSoundIds["Bicycle_Riding"] = nil
            return
        end

        local volume = getRemoteVolume(remote, soundVolume, soundRange, player)
        if not volume then
            if emitter:isPlaying("Bicycle_Riding") then
                emitter:stopSoundByName("Bicycle_Riding")
            end
            modData.bicycleSoundIds["Bicycle_Riding"] = nil
            return
        end

        local soundId = modData.bicycleSoundIds["Bicycle_Riding"]
        if soundId and emitter:isPlaying("Bicycle_Riding") then
            emitter:setVolume(soundId, volume)
            return
        end

        if emitter:isPlaying("Bicycle_Riding") then
            emitter:stopSoundByName("Bicycle_Riding")
        end

        local sound = emitter:playSoundImpl("Bicycle_Riding", nil)
        emitter:setVolume(sound, volume)
        modData.bicycleSoundIds["Bicycle_Riding"] = sound
    end

    local onlinePlayers = getOnlinePlayers and getOnlinePlayers() or nil
    if onlinePlayers then
        for index = 0, onlinePlayers:size() - 1 do
            syncRidingForPlayer(onlinePlayers:get(index))
        end
        return
    end

    local playerCount = getNumActivePlayers and getNumActivePlayers() or 1
    for playerIndex = 0, playerCount - 1 do
        syncRidingForPlayer(getSpecificPlayer(playerIndex))
    end
end

---@param player IsoPlayer|nil
---@return table
local function getVariableFloat(player, variable)
    if player.getVariableFloat then
        return player:getVariableFloat(variable, 0)
    end

    local rawValue = player:getVariableString(variable)
    local numberValue = tonumber(rawValue)
    if numberValue then
        return numberValue
    end

    return 0
end

---@param player IsoPlayer|nil
---@return table
local function getState(player)
    return {
        active = player:getVariableBoolean(Core.PlayerVars.Active),
        riding = player:getVariableBoolean(Core.PlayerVars.Riding),
        walkSpeed = getVariableFloat(player, Core.PlayerVars.WalkSpeed),
        runSpeed = getVariableFloat(player, Core.PlayerVars.RunSpeed),
        speed = getVariableFloat(player, Core.PlayerVars.Speed)
    }
end

---@param previous table
---@param current table
---@return boolean
local function didStateChange(previous, current)
    if previous.active ~= current.active then
        return true
    end
    if previous.riding ~= current.riding then
        return true
    end
    if previous.walkSpeed ~= current.walkSpeed then
        return true
    end
    if previous.runSpeed ~= current.runSpeed then
        return true
    end
    if previous.speed ~= current.speed then
        return true
    end

    return false
end

---@param player IsoPlayer|nil
---@param force boolean|nil
function Client.syncState(player, force)
    if not (isClient() and player) then
        return
    end

    if player.isLocalPlayer and not player:isLocalPlayer() then
        return
    end

    local currentState = getState(player)
    if force or didStateChange(Client.lastSyncedState, currentState) then
        sendClientCommand(Core.SyncModule, "SetState", currentState)
        Client.lastSyncedState = currentState
    end
end

---@param bikeItem InventoryItem|nil
---@param targetState string
function Client.requestKickstandState(bikeItem, targetState)
    if not (isClient() and bikeItem and bikeItem.getID) then
        return
    end

    sendClientCommand(Core.SyncModule, "SetKickstand", {
        itemId = bikeItem:getID(),
        targetState = targetState
    })
end

-- targetSquare is what makes the throw work: the server owns world items, and without the hint it falls back
-- to the player own square. The server clamps the hint to 5 tiles; a throw is 3.
---@param bikeItem InventoryItem|nil
---@param dismountData table|nil
---@param targetSquare IsoGridSquare|nil
function Client.requestDropBike(bikeItem, dismountData, targetSquare)
    if not (isClient() and bikeItem and bikeItem.getID) then
        return
    end

    local payload = {
        itemId = bikeItem:getID(),
        dismountData = dismountData
    }
    if targetSquare then
        payload.x = targetSquare:getX()
        payload.y = targetSquare:getY()
        payload.z = targetSquare:getZ()
    end

    sendClientCommand(Core.SyncModule, "DropBike", payload)
end

---@param itemId number|nil
---@param sourceSquare IsoGridSquare|nil
---@param rotation table|nil
---@param mountActionId number|nil
function Client.requestCancelMount(itemId, sourceSquare, rotation, mountActionId)
    if not (isClient() and itemId) then
        return
    end

    local payload = {
        itemId = itemId
    }
    if sourceSquare then
        payload.x = sourceSquare:getX()
        payload.y = sourceSquare:getY()
        payload.z = sourceSquare:getZ()
    end
    if rotation then
        payload.worldXRotation = rotation.x
        payload.worldYRotation = rotation.y
        payload.worldZRotation = rotation.z
    end
    if mountActionId then
        payload.mountActionId = mountActionId
    end

    sendClientCommand(Core.SyncModule, "CancelMount", payload)
end

---@param bikeItem InventoryItem|nil
---@param mountData table|nil
function Client.requestMountBike(bikeItem, mountData)
    if not (isClient() and bikeItem and bikeItem.getID) then
        BicycleDebug.log("BicycleSyncClient:requestMountBike skipped missing bike item")
        return
    end

    local payload = {
        itemId = bikeItem:getID()
    }
    if mountData then
        if mountData.x ~= nil then
            payload.x = mountData.x
        end
        if mountData.y ~= nil then
            payload.y = mountData.y
        end
        if mountData.z ~= nil then
            payload.z = mountData.z
        end
        if mountData.worldXRotation ~= nil then
            payload.worldXRotation = mountData.worldXRotation
        end
        if mountData.worldYRotation ~= nil then
            payload.worldYRotation = mountData.worldYRotation
        end
        if mountData.worldZRotation ~= nil then
            payload.worldZRotation = mountData.worldZRotation
        end
        if mountData.mountAnim ~= nil then
            payload.mountAnim = mountData.mountAnim
        end
    end

    BicycleDebug.log(
        "BicycleSyncClient:requestMountBike item=" .. BicycleDebug.describeItem(bikeItem)
            .. ", mountAnim=" .. BicycleDebug.describeValue(payload.mountAnim)
            .. ", square=" .. BicycleDebug.describeValue(payload.x)
            .. "," .. BicycleDebug.describeValue(payload.y)
            .. "," .. BicycleDebug.describeValue(payload.z)
    )
    sendClientCommand(Core.SyncModule, "MountBike", payload)
end

---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@param conditionLoss number
---@param elapsed number
---@param isFlat boolean
function Client.requestWearTick(bikeItem, partType, conditionLoss, elapsed, isFlat)
    if not (isClient() and bikeItem and bikeItem.getID and partType) then
        return
    end

    sendClientCommand(Core.SyncModule, "ApplyWearTick", {
        itemId = bikeItem:getID(),
        partType = partType,
        conditionLoss = conditionLoss,
        elapsed = elapsed,
        flat = isFlat == true
    })
end

---@param fullType string|nil
function Client.requestSpawnDebugItem(fullType)
    if not (isClient() and fullType) then
        return
    end

    sendClientCommand(Core.SyncModule, "SpawnDebugItem", {
        fullType = fullType
    })
end

---@param itemId number
---@param partType string|nil
---@param square IsoGridSquare|nil
function Client.requestTransferContainer(itemId, partType, square)
    if not (isClient() and itemId) then
        return
    end

    local payload = { itemId = itemId }
    if partType then
        payload.partType = partType
    end
    if square then
        payload.x = square:getX()
        payload.y = square:getY()
        payload.z = square:getZ()
    end

    sendClientCommand(Core.SyncModule, "TransferContainer", payload)
end

Handlers[Core.SyncModule].SetState = function(args)
    local remote = getPlayerByOnlineID(args.id)
    if not remote then
        return
    end

    remote:setVariable(Core.PlayerVars.Active, tostring(args.active and "true" or "false"))
    remote:setVariable(Core.PlayerVars.Riding, tostring(args.riding and "true" or "false"))
    remote:setVariable(Core.PlayerVars.WalkSpeed, args.walkSpeed)
    remote:setVariable(Core.PlayerVars.RunSpeed, args.runSpeed)
    remote:setVariable(Core.PlayerVars.Speed, args.speed)

    if not args.active then
        remote:setVariable(Core.PlayerVars.RollingTimestamp, "0")
        stopBicycleAudio(remote)
    end
end

Handlers[Core.SyncModule].MountBikeFailed = function(args)
    local itemId = nil
    local reason = nil
    if args then
        itemId = tonumber(args.itemId)
        reason = args.reason
    end
    local player = findLocalPlayerForMountFailure(itemId)
    clearLocalMountAfterFailure(player, itemId, reason)
end

---@param itemId number
---@return IsoPlayer|nil
---@nodiscard
local function findLocalPlayerWithInventoryItemId(itemId)
    local playerCount = getNumActivePlayers()
    for playerIndex = 0, playerCount - 1 do
        local player = getSpecificPlayer(playerIndex)
        if player and player:getInventory():getItemWithID(itemId) then
            return player
        end
    end
    return nil
end

---@param player IsoPlayer
---@param bikeItem InventoryItem
local function equipMountedBikeLocally(player, bikeItem)
    player:setPrimaryHandItem(bikeItem)
    player:setSecondaryHandItem(bikeItem)
    BicycleKickstand.ensureState(bikeItem, player, "up")
    player:resetEquippedHandsModels()
    player:setVariable("Bicycle_MountPending", false)
    BicycleRidingSystem.ensureUpdateHandlers()
    BicycleRidingSystem.updateBicycleFlag(player)
end

Handlers[Core.SyncModule].MountEquip = function(args)
    if not args then
        return
    end
    local itemId = tonumber(args.itemId)
    if not itemId then
        return
    end

    local player = findLocalPlayerWithInventoryItemId(itemId)
    local bikeItem = player and player:getInventory():getItemWithID(itemId) or nil
    if player and bikeItem then
        equipMountedBikeLocally(player, bikeItem)
        return
    end

    local maxTicks = 180
    local tickCount = 0
    local tick
    tick = function()
        tickCount = tickCount + 1
        local foundPlayer = findLocalPlayerWithInventoryItemId(itemId)
        local foundItem = foundPlayer and foundPlayer:getInventory():getItemWithID(itemId) or nil
        if foundPlayer and foundItem then
            Events.OnTick.Remove(tick)
            equipMountedBikeLocally(foundPlayer, foundItem)
            return
        end
        if tickCount >= maxTicks then
            Events.OnTick.Remove(tick)
            BicycleDebug.log("BicycleSyncClient:MountEquip timed out itemId=" .. tostring(itemId))
        end
    end
    Events.OnTick.Add(tick)
end

---@param player IsoPlayer
local function clearLocalMountState(player)
    local primary = player:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primary) then
        player:setPrimaryHandItem(nil)
    end
    local secondary = player:getSecondaryHandItem()
    if BicycleUtils.isBicycleItem(secondary) then
        player:setSecondaryHandItem(nil)
    end
    player:resetEquippedHandsModels()

    BicycleMountDismountState.resetAllBikeVariables(player)
    player:setBlockMovement(false)
    player:setIgnoreMovement(false)
    player:setTurnDelta(1)
    player:setAllowRun(true)
    player:setForceSprint(false)
    player:setCanShout(true)
    player:setBannedAttacking(false)
    player:setIgnoreAutoVault(false)

    local emitter = player:getEmitter()
    if emitter then
        emitter:stopSoundByName("Bicycle_Riding")
    end

    BicycleRidingSystem.clearUpdateHandlers()
end

Handlers[Core.SyncModule].MountCancelled = function(args)
    if not args then
        return
    end
    local itemId = tonumber(args.itemId)
    if not itemId then
        return
    end

    local player = getSpecificPlayer(0)
    local playerCount = getNumActivePlayers()
    for playerIndex = 0, playerCount - 1 do
        local candidate = getSpecificPlayer(playerIndex)
        if candidate then
            local primary = candidate:getPrimaryHandItem()
            local secondary = candidate:getSecondaryHandItem()
            if (primary and primary.getID and primary:getID() == itemId)
                or (secondary and secondary.getID and secondary:getID() == itemId) then
                player = candidate
                break
            end
        end
    end

    if player then
        clearLocalMountState(player)
    end
end

Handlers[Core.SyncModule].SetKickstandVisual = function(args)
    local player = getPlayerByOnlineID(args.id)
    if not player then
        return
    end

    local currentItem = player:getPrimaryHandItem()
    if not BicycleUtils.isBicycleItem(currentItem) then
        return
    end
end

---@param reason string|nil
---@return string
---@nodiscard
local function getSidecarFailureText(reason)
    local key = "IGUI_Bicycle_Sidecar_Failed_" .. tostring(reason or "unknown")
    return getText(key)
end

Handlers[Core.SyncModule].SidecarAnimalFailed = function(args)
    local reason = nil
    if args then
        reason = args.reason
    end
    local player = getSpecificPlayer(0)
    if not player then
        return
    end
    player:Say(getSidecarFailureText(reason))
end

Handlers[Core.SyncModule].SidecarAnimalPlaced = function(args)
    if triggerEvent then
        triggerEvent("OnContainerUpdate")
    end
end

Handlers[Core.SyncModule].SidecarAnimalReleased = function(args)
    if triggerEvent then
        triggerEvent("OnContainerUpdate")
    end
end

Handlers[Core.SyncModule].ContainerUpdated = function(args)
    local player = getPlayerByOnlineID(args.id)
    if not (player and player.isLocalPlayer and player:isLocalPlayer()) then
        return
    end

    if triggerEvent then
        triggerEvent("OnContainerUpdate")
    end
    if not getPlayerData then
        return
    end
    local pdata = getPlayerData(player:getPlayerNum())
    if not pdata then
        return
    end
    if pdata.playerInventory and pdata.playerInventory.refreshBackpacks then
        pdata.playerInventory:refreshBackpacks()
    end
    if pdata.lootInventory and pdata.lootInventory.refreshBackpacks then
        pdata.lootInventory:refreshBackpacks()
    end
end

Handlers[Core.SyncModule].Sound = function(args)
    local remote = getPlayerByOnlineID(args.id)
    if not remote then
        return
    end

    syncRemoteBicycleSound(remote, args)
end

---@param module string
---@param command string
---@param args table
local function handleServerCommand(module, command, args)
    local modTable = Handlers[module]
    if modTable and modTable[command] then
        modTable[command](args)
    end
end

local function requestRemoteStates()
    sendClientCommand(Core.SyncModule, "RequestState", {})
end

local function onPlayerUpdate(player)
    if not (player and player.isLocalPlayer and player:isLocalPlayer()) then
        return
    end

    Client.syncState(player)
end

Bicycle.ClientSync = Client

Events.OnServerCommand.Add(handleServerCommand)
Events.OnGameStart.Add(requestRemoteStates)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnPlayerUpdate.Add(updateRemoteRidingSounds)
