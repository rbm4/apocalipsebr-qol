-- Central mutation/synchronisation facade.
-- Queued plans contain only primitive descriptors; live objects are re-resolved
-- immediately before a mutation is applied.
local Identity = require("A10YL/A10YL_Identity")
local Validation = require("A10YL/core/A10YL_Validation")
local Protection = require("A10YL/core/A10YL_Protection")
local PersistentPlacement = require("A10YL/core/A10YL_PersistentPlacement")
local Debug = require("A10YL/core/A10YL_Debug")

local Mutations = {}

-- Legacy preload-state guard retained for compatibility with older private
-- callers. Checkpoint 69 no longer performs normal world ageing from LoadChunk;
-- authoritative mutations are expected to run on fully live squares.
local preloadDepth = 0

function Mutations.beginPreload()
    preloadDepth = preloadDepth + 1
end

function Mutations.endPreload()
    preloadDepth = math.max(0, preloadDepth - 1)
end

function Mutations.isPreload()
    return preloadDepth > 0
end

-- Any authoritative world mutation must dirty the containing square so the
-- server's chunk serializer cannot unload a visually-mutated square while
-- retaining the older on-disk state. This is separate from network replication:
-- transmit* updates connected clients; setSquareChanged protects save persistence.
local function markSquareChanged(square)
    if not square then return false end
    local changed = false
    if type(square.setSquareChanged) == "function" then
        changed = pcall(square.setSquareChanged, square) or changed
    end
    if type(square.flagForHotSave) == "function" then
        changed = pcall(square.flagForHotSave, square) or changed
    end
    if type(square.getChunk) == "function" then
        local okChunk, chunk = pcall(square.getChunk, square)
        if okChunk and chunk and type(chunk.flagForHotSave) == "function" then
            changed = pcall(chunk.flagForHotSave, chunk) or changed
        end
    end
    if type(square.RecalcProperties) == "function" then
        pcall(square.RecalcProperties, square)
    end
    return changed
end

function Mutations.markSquareChanged(square)
    return markSquareChanged(square)
end

function Mutations.describeTarget(obj)
    return Identity.describeTarget(obj)
end

function Mutations.targetKey(target)
    return Identity.targetKey(target)
end

function Mutations.semanticSlot(obj)
    return Identity.semanticSlot(obj)
end

function Mutations.resolveObject(square, target)
    if not square or not target then
        return nil
    end

    local objects = square:getObjects()
    if not objects then
        return nil
    end

    -- #34 stable-target rule: no object-list index is retained. A target is
    -- resolved only from its stable semantic signature, and only when that
    -- signature identifies exactly one live object on the square.
    local match = nil
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Identity.matchesTarget(obj, target) then
            if match ~= nil then
                return nil
            end
            match = obj
        end
    end

    return match
end

function Mutations.findOwnedByOperationKey(square, operationKey, expectedType)
    if not square or type(operationKey) ~= "string" or operationKey == "" then
        return nil
    end

    local objects = square:getObjects()
    if not objects then return nil end

    local match = nil
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Identity.isOwnedObject(obj, expectedType, operationKey) then
            -- Duplicate operation keys should never be produced by the rebuild.
            -- If an old/broken state contains duplicates, report ambiguity to
            -- callers by returning false rather than creating another object.
            if match ~= nil then
                return false
            end
            match = obj
        end
    end

    return match
end

function Mutations.hasOwnedOperation(square, operationKey, expectedType)
    local result = Mutations.findOwnedByOperationKey(square, operationKey, expectedType)
    return result ~= nil
end

function Mutations.tagOwnedObject(obj, ownedType, operationKey)
    return Identity.tagOwnedObject(obj, ownedType, operationKey)
end

function Mutations.isOwnedObject(obj, expectedType, operationKey)
    return Identity.isOwnedObject(obj, expectedType, operationKey)
end

function Mutations.findEffectByOperationKey(square, operationKey)
    if not square or type(operationKey) ~= "string" or operationKey == "" then
        return nil
    end
    local objects = square:getObjects()
    if not objects then return nil end

    local match = nil
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local modData = obj and obj.getModData and obj:getModData() or nil
        if modData and tostring(modData.A10YL_EffectKey or "") == operationKey then
            if match ~= nil then
                return false
            end
            match = obj
        end
    end
    return match
end

function Mutations.hasEffectKey(square, operationKey)
    return Mutations.findEffectByOperationKey(square, operationKey) ~= nil
end

-- Sparse proof for native transitions whose new sprite/signature may no
-- longer resolve the original target. This does not claim ownership and never
-- replaces unrelated object modData.
function Mutations.markEffectKey(obj, operationKey)
    if not obj or type(operationKey) ~= "string" or operationKey == "" then
        return false, false
    end
    local modData = obj:getModData()
    if not modData then return false, false end
    if modData.A10YL_EffectKey ~= nil then
        return tostring(modData.A10YL_EffectKey) == operationKey, false
    end
    modData.A10YL_EffectKey = operationKey
    return true, true
end

function Mutations.hasSpriteObject(square, spriteName)
    if not square or not spriteName then
        return false
    end

    local objects = square:getObjects()
    if not objects then
        return false
    end

    spriteName = tostring(spriteName)
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and tostring(obj:getSpriteName() or "") == spriteName then
            return true
        end
    end

    return false
end

function Mutations.hasSpritePrefix(square, prefix)
    if not square or type(prefix) ~= "string" or prefix == "" then
        return false
    end
    local objects = square:getObjects()
    if not objects then return false end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local spriteName = obj and tostring(obj:getSpriteName() or "") or ""
        if string.sub(spriteName, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

local function attachedSpriteName(instance)
    if not instance then return nil end
    local parent = instance.getParentSprite and instance:getParentSprite() or nil
    if parent and parent.getName then return parent:getName() end
    return nil
end

function Mutations.hasAttachedSprite(obj, spriteName)
    if not obj or type(spriteName) ~= "string" or spriteName == ""
        or type(obj.getAttachedAnimSprite) ~= "function"
    then
        return false
    end
    local attached = obj:getAttachedAnimSprite()
    if not attached then return false end
    for i = 0, attached:size() - 1 do
        if tostring(attachedSpriteName(attached:get(i)) or "") == spriteName then
            return true
        end
    end
    return false
end

function Mutations.addAttachedSprite(obj, spriteName, operationKey, attachedType)
    if not obj or type(spriteName) ~= "string" or spriteName == "" then return false end
    local square = obj.getSquare and obj:getSquare() or nil
    if not square or Protection.isProtectedSquare(square) or Protection.isProtectedObject(obj, square) then
        return false
    end
    local sprite = getSprite(spriteName)
    if not sprite or type(obj.addAttachedAnimSprite) ~= "function" then return false end

    if Mutations.hasAttachedSprite(obj, spriteName) then return true end

    obj:addAttachedAnimSprite(sprite)
    local modData = obj.getModData and obj:getModData() or nil
    if modData and type(operationKey) == "string" and operationKey ~= "" then
        if type(modData.A10YL_AttachedOps) ~= "table" then modData.A10YL_AttachedOps = {} end
        modData.A10YL_AttachedOps[operationKey] = tostring(attachedType or "Attached") .. "|" .. spriteName
    end

    if type(obj.flagForHotSave) == "function" then pcall(obj.flagForHotSave, obj) end
    markSquareChanged(square)
    if type(obj.transmitUpdatedSpriteToClients) == "function" then
        pcall(obj.transmitUpdatedSpriteToClients, obj)
    end
    -- A10YL_AttachedOps is server-private bookkeeping. The sprite update is the
    -- only client-visible state required here; avoid a second ModData packet.
    return Mutations.hasAttachedSprite(obj, spriteName)
end

function Mutations.removeOwnedObject(square, obj)
    if not square or not obj or not Identity.isOwnedObject(obj)
        or type(square.transmitRemoveItemFromSquare) ~= "function"
    then
        return false
    end
    local ok, result = pcall(square.transmitRemoveItemFromSquare, square, obj, true)
    if not ok then return false end
    if result ~= nil and tonumber(result) ~= nil and tonumber(result) < 0 then
        return false
    end
    markSquareChanged(square)
    return true
end

function Mutations.addSpecialObject(square, obj)
    if not square or Protection.isProtectedSquare(square) or not obj or not Identity.isOwnedObject(obj)
        or not Validation.isSafeGeneratedDecoration(obj)
        or type(square.AddSpecialObject) ~= "function"
        or type(obj.transmitCompleteItemToClients) ~= "function"
    then
        return false
    end

    -- Preflight the replication API before insertion. If a future B42 API
    -- removes it, fail closed before changing the authoritative world.
    square:AddSpecialObject(obj)
    if type(obj.flagForHotSave) == "function" then pcall(obj.flagForHotSave, obj) end
    markSquareChanged(square)
    -- Normal ageing reaches this path only after the square is fully live. On a dedicated server the object
    -- must be both part of the authoritative square and explicitly replicated;
    -- chunk-payload timing is not used as a persistence guarantee.
    local ok = pcall(obj.transmitCompleteItemToClients, obj)
    if not ok then return false end
    -- transmitCompleteItemToClients carries the newly inserted object's complete
    -- state; do not immediately follow it with a redundant ModData packet.
    return true
end

function Mutations.addTileObject(square, obj)
    if not square or Protection.isProtectedSquare(square) or not obj or not Identity.isOwnedObject(obj)
        or not Validation.isSafeGeneratedDecoration(obj)
        or type(square.AddTileObject) ~= "function"
        or type(obj.transmitCompleteItemToClients) ~= "function"
    then
        return false
    end

    square:AddTileObject(obj)
    if type(obj.flagForHotSave) == "function" then pcall(obj.flagForHotSave, obj) end
    markSquareChanged(square)
    local ok = pcall(obj.transmitCompleteItemToClients, obj)
    if not ok then return false end
    -- Complete-item replication already sends the inserted object's state.
    return true
end

-- Existing-object state changes must use the narrow B42.20.4 replication
-- mechanism for that state. Complete-item transmission is reserved here for
-- newly inserted A10YL-owned objects and newly created barricade objects.
local function flagObjectForSave(obj)
    if obj and type(obj.flagForHotSave) == "function" then
        pcall(obj.flagForHotSave, obj)
    end
end

function Mutations.smashWindow(obj)
    if not obj or not instanceof(obj, "IsoWindow") then
        return false
    end

    -- Dedicated-server B42 exposes an explicit authoritative smash-window
    -- network path. During LoadChunk preload, mutate the native object locally
    -- instead so the completed chunk state carries the result without a packet.
    if type(isServer) == "function" and isServer() then
        if Mutations.isPreload() then
            if type(obj.smashWindow) ~= "function" then return false end
            local ok = pcall(obj.smashWindow, obj, true, false)
            if ok then
                flagObjectForSave(obj)
                markSquareChanged(obj:getSquare())
            end
            return ok
        end
        if not GameServer or type(GameServer.smashWindow) ~= "function" then
            return false
        end
        GameServer.smashWindow(obj)
        flagObjectForSave(obj)
        markSquareChanged(obj:getSquare())
        return true
    end

    if type(obj.smashWindow) ~= "function" then
        return false
    end
    obj:smashWindow()
    flagObjectForSave(obj)
    markSquareChanged(obj:getSquare())
    return true
end

-- Native ordinary-door state ageing. B42 IsoDoor exposes ToggleDoorSilent plus
-- syncIsoObject; this keeps the original door object, collision contract and
-- save identity intact while allowing abandoned interiors/breached entrances
-- to be visibly left open. Destructive IsoDoor:destroy() remains excluded.
function Mutations.openDoor(obj)
    if not obj or not instanceof(obj, "IsoDoor")
        or type(obj.ToggleDoorSilent) ~= "function"
        or type(obj.syncIsoObject) ~= "function"
    then
        return false
    end
    if obj:IsOpen() then return true end

    local square = obj.getSquare and obj:getSquare() or nil
    if obj.DirtySlice then obj:DirtySlice() end
    if square and square.InvalidateSpecialObjectPaths then
        square:InvalidateSpecialObjectPaths()
    end

    obj:ToggleDoorSilent()
    if not obj:IsOpen() then return false end
    flagObjectForSave(obj)

    if square and square.RecalcProperties then square:RecalcProperties() end
    if square and square.RecalcAllWithNeighbours then
        square:RecalcAllWithNeighbours(true)
    end
    if square and square.setSquareChanged then square:setSquareChanged() end

    -- IsoDoor's specialised sync packet carries its open/closed state for live
    -- runtime changes. During LoadChunk preload the already-mutated door is part
    -- of the chunk payload, so sending syncIsoObject here is redundant and can
    -- race the object's client-side index assignment.
    if not Mutations.isPreload() then
        obj:syncIsoObject(false, 1, nil, nil)
    end

    if obj.invalidateRenderChunkLevel and FBORenderChunk
        and FBORenderChunk.DIRTY_OBJECT_MODIFY ~= nil
    then
        obj:invalidateRenderChunkLevel(FBORenderChunk.DIRTY_OBJECT_MODIFY)
    end
    markSquareChanged(square)
    return true
end

function Mutations.removeOriginalObject(obj)
    if not obj or not obj.getSquare then return false end
    local square = obj:getSquare()
    if not square or type(square.transmitRemoveItemFromSquare) ~= "function" then
        return false
    end

    -- Original map-object removal keeps the already-validated replicated square
    -- primitive even during preload. Point #4 suppresses redundant A10YL-owned
    -- additions and state packets, but does not reintroduce the older direct
    -- tile-removal path that historical safety reviews deliberately excluded.
    local ok, result = pcall(square.transmitRemoveItemFromSquare, square, obj, true)
    if not ok then return false end
    if result ~= nil and tonumber(result) ~= nil and tonumber(result) < 0 then
        return false
    end
    markSquareChanged(square)
    return true
end

function Mutations.removeDoor(obj)
    if not obj or not instanceof(obj, "IsoDoor") then return false end
    return Mutations.removeOriginalObject(obj)
end

local function sameSquare(a, b)
    return a ~= nil and b ~= nil and a == b
end

-- Return false for the object's own square, true for the opposite square, and
-- nil when the interior side cannot be resolved unambiguously. Barricades are
-- placed on the interior side so abandoned-building barricades make physical
-- sense and do not depend on a player character.
function Mutations.getBarricadeOppositeFlag(obj)
    if not obj or not obj.getSquare or not obj.getOppositeSquare then
        return nil
    end

    local own = obj:getSquare()
    local opposite = obj:getOppositeSquare()
    if not own or not opposite then return nil end

    if obj.getInsideSquare then
        local inside = obj:getInsideSquare()
        if sameSquare(inside, own) then return false end
        if sameSquare(inside, opposite) then return true end
    end

    -- Some BarricadeAble implementations expose indoor rather than inside.
    if obj.getIndoorSquare then
        local inside = obj:getIndoorSquare()
        if sameSquare(inside, own) then return false end
        if sameSquare(inside, opposite) then return true end
    end

    -- Final conservative fallback: exactly one side must be a room.
    local ownRoom = own.getRoom and own:getRoom() or nil
    local oppositeRoom = opposite.getRoom and opposite:getRoom() or nil
    if (ownRoom ~= nil) ~= (oppositeRoom ~= nil) then
        return oppositeRoom ~= nil
    end

    return nil
end

function Mutations.addBarricade(obj, plankCount, metal)
    if not obj or not (instanceof(obj, "IsoWindow") or instanceof(obj, "IsoDoor")) then
        return false
    end
    if type(obj.getSquare) ~= "function" or type(obj.getOppositeSquare) ~= "function" then
        return false
    end
    if not IsoBarricade or type(IsoBarricade.AddBarricadeToObject) ~= "function" then
        return false
    end

    local addOpposite = Mutations.getBarricadeOppositeFlag(obj)
    if addOpposite == nil then return false end

    local barricade = IsoBarricade.AddBarricadeToObject(obj, addOpposite)
    if not barricade then return false end

    if metal == true then
        if type(barricade.addMetal) ~= "function" then return false end
        barricade:addMetal(nil, nil)
    else
        if type(barricade.addPlank) ~= "function" then return false end
        local count = math.floor(tonumber(plankCount) or 2)
        if count < 1 then count = 1 end
        if count > 4 then count = 4 end
        for _ = 1, count do
            barricade:addPlank(nil, nil)
        end
    end

    if type(barricade.transmitCompleteItemToClients) ~= "function" then
        return false
    end
    local barricadeSquare = barricade.getSquare and barricade:getSquare() or obj:getSquare()
    flagObjectForSave(barricade)
    flagObjectForSave(obj)
    markSquareChanged(barricadeSquare)
    markSquareChanged(obj:getSquare())
    local ok = pcall(barricade.transmitCompleteItemToClients, barricade)
    if not ok then return false end
    return true
end


-- Checkpoint 73: ordinary grass/bush/debris/vine IsoObjects first try B42's
-- vanilla server-side moveable placement path. This is the same engine path
-- used by normal placed props and by the Brush Tool persistence workaround,
-- without inheriting its brush hooks or marking natural terrain as construction.
-- If the sprite cannot safely use that path we fall back to the previous raw
-- insertion method so the visual generator remains functional for comparison.
function Mutations.placePersistentDecoration(square, spriteName, ownedType, operationKey, fallbackKind)
    if not square or Protection.isProtectedSquare(square) or not spriteName or not ownedType or not operationKey then
        return false, nil, "invalid-or-protected"
    end
    if not getSprite(spriteName) then return false, nil, "missing-sprite" end

    -- Validate a lightweight probe before invoking vanilla placement; this
    -- preserves the existing no-container/no-loot guarantee.
    local probe = IsoObject.new(getCell(), square, spriteName)
    if not probe or not Validation.isSafeGeneratedDecoration(probe) then
        return false, nil, "unsafe-decoration"
    end

    local ok, placed, path = PersistentPlacement.placeOwnedDecoration(
        square, spriteName, ownedType, operationKey
    )
    if ok and placed then
        return true, placed, path
    end

    -- Controlled compatibility fallback. It retains checkpoint 72 behaviour
    -- for sprites that the vanilla moveable pathway refuses, and the path is
    -- reported to diagnostics so runtime tests can tell which class persisted.
    local obj = IsoObject.new(getCell(), square, spriteName)
    if not obj or not Mutations.tagOwnedObject(obj, ownedType, operationKey) then
        return false, nil, "raw-fallback-create-failed"
    end

    local added
    if fallbackKind == "tile" then
        added = Mutations.addTileObject(square, obj)
    else
        added = Mutations.addSpecialObject(square, obj)
    end
    if not added then return false, nil, "raw-fallback-add-failed" end
    PersistentPlacement.noteRawFallback(ownedType, path)

    Debug.once(
        "persistent-placement-raw-fallback:" .. tostring(ownedType),
        "WARN",
        "Using raw decorative fallback for " .. tostring(ownedType) .. "; first sprite=" .. tostring(spriteName) .. "; moveable reason=" .. tostring(path)
    )
    return true, obj, "raw-fallback:" .. tostring(path or "unknown")
end

function Mutations.getPersistentPlacementStats()
    return PersistentPlacement.getStats()
end

function Mutations.addOwnedTileSprite(square, spriteName, ownedType, operationKey)
    if not square or Protection.isProtectedSquare(square) or not spriteName or not ownedType or not operationKey then
        return false
    end
    if not getSprite(spriteName) then return false end

    local obj = IsoObject.new(getCell(), square, spriteName)
    if not obj then return false end
    if not Mutations.tagOwnedObject(obj, ownedType, operationKey) then
        return false
    end
    return Mutations.addTileObject(square, obj)
end

-- Roadmap point #3 deliberately has no generic existing-object sprite-sync
-- facade. B42.20.4 still exposes the generic updated-sprite client call, but live MP
-- testing showed thousands of deprecated sprite-sync warnings while A10YL used
-- that family. Existing-object visual ageing must now use a specialised native
-- state packet (doors/windows) or replicated removal; additive visuals are new
-- A10YL-owned objects transmitted as complete items.

return Mutations
