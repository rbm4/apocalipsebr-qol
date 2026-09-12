-- Live-state safety predicates used immediately before persistent mutations.
-- B42.20.4 API-sensitive predicates fail closed when current semantics cannot be resolved.
local Identity = require("A10YL/A10YL_Identity")
local Compatibility = require("A10YL/core/A10YL_Compatibility")
local Protection = require("A10YL/core/A10YL_Protection")

local Validation = {}

local A10YL_MODDATA_KEYS = {
    A10YL_Owner = true,
    A10YL_Type = true,
    A10YL_OpKey = true,
    A10YL_EffectKey = true,
    A10YL_AttachedOps = true,
}

local function safeMethod(obj, methodName, ...)
    if not obj then return false, nil end
    local method = obj[methodName]
    if type(method) ~= "function" then return false, nil end
    return pcall(method, obj, ...)
end

local function tableHasEntries(value, ignoredKeys)
    if value == nil then return false end

    local ok, result = pcall(function()
        for key, _ in pairs(value) do
            if not ignoredKeys or not ignoredKeys[tostring(key)] then
                return true
            end
        end
        return false
    end)

    -- If a foreign table cannot be inspected safely, fail closed.
    return not ok or result == true
end

function Validation.objectHasContainers(obj)
    if not obj then return false end

    if obj.getContainerCount then
        local ok, count = safeMethod(obj, "getContainerCount")
        if not ok then return true end
        if (tonumber(count) or 0) > 0 then
            return true
        end
    end

    if obj.getContainer then
        local ok, container = safeMethod(obj, "getContainer")
        if not ok then return true end
        if container ~= nil then
            return true
        end
    end

    return false
end

function Validation.objectHasAttachedOrOverlayState(obj)
    if not obj then return false end

    if obj.hasAttachedAnimSprites then
        local ok, hasAttachments = safeMethod(obj, "hasAttachedAnimSprites")
        if not ok then return true end
        if hasAttachments then return true end
    elseif obj.getAttachedAnimSpriteCount then
        local ok, count = safeMethod(obj, "getAttachedAnimSpriteCount")
        if not ok then return true end
        if (tonumber(count) or 0) > 0 then return true end
    end

    if obj.hasOverlaySprite then
        local ok, hasOverlay = safeMethod(obj, "hasOverlaySprite")
        if not ok then return true end
        if hasOverlay then return true end
    elseif obj.getOverlaySprite then
        local ok, overlay = safeMethod(obj, "getOverlaySprite")
        if not ok then return true end
        if overlay ~= nil then return true end
    end

    return false
end

function Validation.objectHasNonA10YLModData(obj)
    return Protection.objectHasForeignModData(obj)
end

function Validation.isPlayerProtectedObject(obj, square, context)
    return Protection.isProtectedObject(obj, square, context)
end

function Validation.isPlayerProtectedSquare(square, context)
    return Protection.isProtectedSquare(square, context)
end

function Validation.objectHasScriptTableState(obj)
    if not obj or not obj.getTable then return false end

    local ok, objectTable = safeMethod(obj, "getTable")
    if not ok then return true end
    return tableHasEntries(objectTable)
end

function Validation.objectWasMovedOrPlaced(obj)
    if not obj then return true end
    if obj.isMovedThumpable then
        local ok, moved = safeMethod(obj, "isMovedThumpable")
        if not ok then return true end
        if moved == true then return true end
    end
    return false
end

function Validation.hasPersistentStateAtRisk(obj)
    if not obj then return true end

    return Validation.objectHasContainers(obj)
        or Validation.objectHasAttachedOrOverlayState(obj)
        or Validation.objectHasNonA10YLModData(obj)
        or Validation.objectHasScriptTableState(obj)
        or Validation.objectWasMovedOrPlaced(obj)
end

function Validation.isPristineOriginalForStructuralAgeing(obj, context)
    if not obj or Identity.isOwnedObject(obj) then
        return false
    end

    local square = obj.getSquare and obj:getSquare() or nil
    if Compatibility.isProtectedObject(obj, square) or Protection.isProtectedObject(obj, square, context) then
        return false
    end

    -- The existence of modData does not prove that another mod "owns" an
    -- object. We still skip structural/destructive ageing when unknown state is
    -- present because A10YL cannot guarantee that a native destroy/state
    -- transition will preserve that unrelated state.
    return not Validation.hasPersistentStateAtRisk(obj)
end

function Validation.isSafeGeneratedDecoration(obj)
    if not obj then return false end

    -- A10YL does not create loot/container-bearing vegetation or debris.
    -- Check both the live object and sprite properties because a container may
    -- be instantiated from tile properties later in the object lifecycle.
    if Validation.objectHasContainers(obj) then
        return false
    end

    local properties = obj.getProperties and obj:getProperties() or nil
    if properties then
        local ok, containerBearing = pcall(function()
            return properties:has("container") or properties:has("ContainerCapacity")
        end)
        if not ok or containerBearing then
            return false
        end
    end

    return true
end


function Validation.isCompatibilitySafeTarget(systemName, obj, square)
    if not obj then return false end
    square = square or (obj.getSquare and obj:getSquare() or nil)
    return not Compatibility.isSystemExcluded(systemName, obj, square)
end

function Validation.isSpecialDoor(obj)
    if not obj or not instanceof(obj, "IsoDoor") then
        return false
    end

    -- B42.20.4 exposes explicit static helpers for multipart door families.
    -- Any API failure is treated as special/unsafe rather than risking one part
    -- of a double or garage door being aged independently.
    if not IsoDoor or type(IsoDoor.getDoubleDoorIndex) ~= "function"
        or type(IsoDoor.getGarageDoorIndex) ~= "function"
    then
        return true
    end

    local okDouble, doubleIndex = pcall(IsoDoor.getDoubleDoorIndex, obj)
    local okGarage, garageIndex = pcall(IsoDoor.getGarageDoorIndex, obj)
    if not okDouble or not okGarage then return true end
    if (tonumber(doubleIndex) or -1) >= 0 or (tonumber(garageIndex) or -1) >= 0 then
        return true
    end

    -- Retain the property test as a second independent guard.
    local properties = obj:getProperties()
    if not properties or not IsoPropertyType then
        return true
    end

    return properties:has(IsoPropertyType.DOUBLE_DOOR)
        or properties:has(IsoPropertyType.GARAGE_DOOR)
end

function Validation.isSupportedExteriorOpening(obj)
    if not obj then
        return false
    end

    if instanceof(obj, "IsoWindow") then
        return obj:isExterior()
            and not obj:isDestroyed()
            and not obj:isSmashed()
            and not obj:isGlassRemoved()
            and not obj:isBarricaded()
    end

    if instanceof(obj, "IsoDoor") then
        return obj:isExterior()
            and not obj:isDestroyed()
            and not obj:isBarricaded()
            and not Validation.isSpecialDoor(obj)
    end

    return false
end

-- Roadmap point #1: ordinary map-authored interior doors are now supported for
-- non-destructive ageing. Windows remain exterior-only because smashing an
-- interior decorative/window-like object is not a validated use case. Double
-- and garage doors remain excluded as multipart structures.
function Validation.isSupportedOpening(obj)
    if not obj then return false end

    if instanceof(obj, "IsoWindow") then
        return Validation.isSupportedExteriorOpening(obj)
    end

    if instanceof(obj, "IsoDoor") then
        return not obj:isDestroyed()
            and not obj:isBarricaded()
            and not Validation.isSpecialDoor(obj)
    end

    -- Player-built/window-like/door-like IsoThumpables are deliberately not
    -- candidates. Exact supported exceptions, if any, must be explicitly
    -- validated rather than inferred from a sprite prefix.
    return false
end

function Validation.isPreservationSafeOpening(obj, context)
    local square = obj and obj.getSquare and obj:getSquare() or nil
    return Validation.isSupportedOpening(obj)
        and Validation.isPristineOriginalForStructuralAgeing(obj, context)
        and Validation.isCompatibilitySafeTarget("openings", obj, square)
end

function Validation.canBarricadeOpening(obj, context)
    if not Validation.isPreservationSafeOpening(obj, context) then
        return false
    end

    -- Barricade remnants are an exterior-history feature. Interior doors are
    -- aged through native door state, never by placing indoor barricades.
    if (instanceof(obj, "IsoWindow") or instanceof(obj, "IsoDoor"))
        and obj:isExterior()
    then
        return not obj:IsOpen() and obj:isBarricadeAllowed()
    end

    return false
end

function Validation.canOpenDoorForAgeing(obj, context)
    if not Validation.isPreservationSafeOpening(obj, context) or not instanceof(obj, "IsoDoor") then
        return false
    end
    if obj:IsOpen() or obj:isBarricaded() or Validation.isSpecialDoor(obj) then
        return false
    end
    if type(obj.isObstructed) == "function" then
        local ok, obstructed = safeMethod(obj, "isObstructed")
        if not ok or obstructed == true then return false end
    end
    -- Do not silently defeat a map-authored exterior lock. Locked exterior
    -- doors remain closed/barricade candidates; ordinary interior doors can be
    -- left open to communicate long abandonment without deleting geometry.
    if obj:isExterior() then
        if type(obj.isLocked) == "function" then
            local ok, locked = safeMethod(obj, "isLocked")
            if not ok or locked == true then return false end
        end
        if type(obj.isLockedByKey) == "function" then
            local ok, lockedByKey = safeMethod(obj, "isLockedByKey")
            if not ok or lockedByKey == true then return false end
        end
    end
    return type(obj.ToggleDoorSilent) == "function"
        and type(obj.syncIsoObject) == "function"
end

function Validation.canRemoveDoorForAgeing(obj, context)
    if not Validation.isPreservationSafeOpening(obj, context) or not instanceof(obj, "IsoDoor") then
        return false
    end
    if obj:isDestroyed() or obj:isBarricaded() or Validation.isSpecialDoor(obj) then
        return false
    end

    local square = obj.getSquare and obj:getSquare() or nil
    if not square or type(square.transmitRemoveItemFromSquare) ~= "function" then
        return false
    end

    -- A missing door represents a physically failed/breached original door, so
    -- a map-authored lock does not make it immune to ten years of abandonment.
    -- Player-built/moved/modified doors were already rejected by the pristine
    -- structural-ageing guard above.
    return true
end

function Validation.isSupportedOriginalFence(obj)
    -- Generic/player-built fences are commonly IsoThumpables; core A10YL does
    -- not destructively age them.
    if not obj or instanceof(obj, "IsoThumpable") or Identity.isOwnedObject(obj) then
        return false
    end

    local properties = obj:getProperties()
    if not properties then
        return false
    end

    local names = properties:getPropertyNames()
    local isLow = properties:has("FenceTypeLow") and properties:get("FenceTypeLow") ~= "Barbwire"
    local isHigh = names and names:contains("FenceTypeHigh")
    return isLow or isHigh
end

function Validation.isPreservationSafeFence(obj, context)
    local square = obj and obj.getSquare and obj:getSquare() or nil
    return Validation.isSupportedOriginalFence(obj)
        and Validation.isPristineOriginalForStructuralAgeing(obj, context)
        and Validation.isCompatibilitySafeTarget("fences", obj, square)
end

function Validation.getOriginalWallOrientation(obj)
    if not obj or instanceof(obj, "IsoThumpable") or instanceof(obj, "IsoDoor")
        or instanceof(obj, "IsoWindow") or Identity.isOwnedObject(obj)
    then
        return nil
    end

    local sprite = obj:getSprite()
    local properties = sprite and sprite:getProperties()
    if not properties then return nil end

    local north = properties:has("WallN") or properties:has("WallNTrans")
    local west = properties:has("WallW") or properties:has("WallWTrans")
    local corner = properties:has("WallNW") or properties:has("WallNWTrans")
    if corner or (north and west) then return "NW" end
    if north then return "N" end
    if west then return "W" end
    return nil
end

function Validation.isSupportedOriginalWall(obj)
    return Validation.getOriginalWallOrientation(obj) ~= nil
end

function Validation.isSupportedOriginalRoof(obj)
    if not obj or instanceof(obj, "IsoThumpable") or Identity.isOwnedObject(obj) then
        return false
    end
    local spriteName = string.lower(tostring(obj:getSpriteName() or ""))
    return string.sub(spriteName, 1, 6) == "roofs_"
        or string.sub(spriteName, 1, 21) == "walls_exterior_roofs_"
end

function Validation.isPreservationSafeStructure(obj, kind, context)
    local square = obj and obj.getSquare and obj:getSquare() or nil
    local supported = kind == "wall" and Validation.isSupportedOriginalWall(obj)
        or kind == "roof" and Validation.isSupportedOriginalRoof(obj)
    return supported == true
        and Validation.isPristineOriginalForStructuralAgeing(obj, context)
        and Validation.isCompatibilitySafeTarget("structures", obj, square)
end

return Validation
