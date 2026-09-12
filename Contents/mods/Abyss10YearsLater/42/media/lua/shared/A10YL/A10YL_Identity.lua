-- Stable A10YL identifiers shared by client/server code.
-- This module is intentionally deterministic and contains no mutable runtime state.
local Identity = {}

Identity.OWNER = "Abyss10YearsLater"
Identity.OP_VERSION = 1

local function objectKind(obj)
    if not obj then
        return "Object"
    elseif instanceof(obj, "IsoWindow") then
        return "IsoWindow"
    elseif instanceof(obj, "IsoDoor") then
        return "IsoDoor"
    elseif instanceof(obj, "IsoTree") then
        return "IsoTree"
    end
    return "Object"
end

local function text(value)
    if value == nil then return "" end
    return tostring(value)
end

local function hashText(value, seed, multiplier)
    local hash = seed
    local source = tostring(value or "")
    for i = 1, #source do
        hash = (hash * multiplier + string.byte(source, i)) % 2147483629
    end
    return hash
end

function Identity.shortToken(value)
    local a = hashText(value, 5381, 33)
    local b = hashText(value, 7919, 131)
    return string.format("%08x%08x", a, b)
end

function Identity.describeTarget(obj)
    if not obj then return nil end

    local spriteName = obj:getSpriteName()
    local textureName = obj:getTextureName()
    local target = {
        kind = objectKind(obj),
        spriteName = spriteName and tostring(spriteName) or nil,
        textureName = textureName and tostring(textureName) or nil,
    }
    target.key = Identity.targetKey(target)
    return target
end

function Identity.targetKey(target)
    if not target then return "missing-target" end
    return table.concat({
        text(target.kind or "Object"),
        text(target.spriteName),
        text(target.textureName),
    }, "|")
end

function Identity.targetToken(target)
    return Identity.shortToken(Identity.targetKey(target))
end

local function hasProperty(properties, name)
    if not properties or not name then return false end
    local ok, result = pcall(function() return properties:has(name) end)
    return ok and result == true
end

local function objectOrientation(obj, properties)
    if obj and (instanceof(obj, "IsoWindow") or instanceof(obj, "IsoDoor")) and obj.getNorth then
        local ok, north = pcall(function() return obj:getNorth() end)
        if ok then return north and "N" or "W" end
    end

    if hasProperty(properties, "WallNW") then return "NW" end
    if hasProperty(properties, "WindowN") or hasProperty(properties, "DoorWallN")
        or hasProperty(properties, "WallN") or hasProperty(properties, "collideN")
    then
        return "N"
    end
    if hasProperty(properties, "WindowW") or hasProperty(properties, "DoorWallW")
        or hasProperty(properties, "WallW") or hasProperty(properties, "collideW")
    then
        return "W"
    end
    return "U"
end

function Identity.semanticSlot(obj)
    if not obj then return "missing" end

    local kind = objectKind(obj)
    local properties = obj.getProperties and obj:getProperties() or nil
    local orientation = objectOrientation(obj, properties)

    if kind == "IsoWindow" then
        return "window-" .. orientation
    elseif kind == "IsoDoor" then
        return "door-" .. orientation
    end

    if hasProperty(properties, "FenceTypeLow") or hasProperty(properties, "FenceTypeHigh") then
        return "fence-" .. orientation
    end

    if hasProperty(properties, "WallN") or hasProperty(properties, "WallW")
        or hasProperty(properties, "WallNW") or hasProperty(properties, "WallNTrans")
        or hasProperty(properties, "WallWTrans") or hasProperty(properties, "WindowN")
        or hasProperty(properties, "WindowW") or hasProperty(properties, "DoorWallN")
        or hasProperty(properties, "DoorWallW")
    then
        return "wall-" .. orientation
    end

    return "target-" .. Identity.targetToken(Identity.describeTarget(obj))
end

function Identity.matchesTarget(obj, target)
    if not obj or not target then return false end

    local kind = objectKind(obj)
    if kind ~= tostring(target.kind or "Object") then
        return false
    end

    if target.spriteName ~= nil and text(obj:getSpriteName()) ~= text(target.spriteName) then
        return false
    end

    if target.textureName ~= nil and text(obj:getTextureName()) ~= text(target.textureName) then
        return false
    end

    return true
end

function Identity.operationKey(x, y, z, system, action, slot)
    return table.concat({
        "A10YL",
        "OP" .. tostring(Identity.OP_VERSION),
        tostring(tonumber(x) or 0),
        tostring(tonumber(y) or 0),
        tostring(tonumber(z) or 0),
        text(system),
        text(action),
        text(slot or "primary"),
    }, ":")
end

function Identity.operationSlotForTarget(target, prefix)
    return tostring(prefix or "target") .. "-" .. Identity.targetToken(target)
end

function Identity.tagOwnedObject(obj, ownedType, operationKey)
    if not obj or not ownedType or not operationKey then return false end
    local modData = obj:getModData()
    if not modData then return false end

    local wantedType = tostring(ownedType)
    local wantedKey = tostring(operationKey)

    -- Never overwrite pre-existing values in our namespace. Fresh A10YL
    -- objects normally have none; a conflicting value means the object is not
    -- safe for us to claim.
    if modData.A10YL_Owner ~= nil and modData.A10YL_Owner ~= Identity.OWNER then
        return false
    end
    if modData.A10YL_Type ~= nil and tostring(modData.A10YL_Type) ~= wantedType then
        return false
    end
    if modData.A10YL_OpKey ~= nil and tostring(modData.A10YL_OpKey) ~= wantedKey then
        return false
    end

    modData.A10YL_Owner = Identity.OWNER
    modData.A10YL_Type = wantedType
    modData.A10YL_OpKey = wantedKey
    return true
end

function Identity.isOwnedObject(obj, expectedType, operationKey)
    if not obj then return false end
    local modData = obj:getModData()
    if not modData or modData.A10YL_Owner ~= Identity.OWNER then
        return false
    end
    if expectedType ~= nil and tostring(modData.A10YL_Type or "") ~= tostring(expectedType) then
        return false
    end
    if operationKey ~= nil and tostring(modData.A10YL_OpKey or "") ~= tostring(operationKey) then
        return false
    end
    return type(modData.A10YL_OpKey) == "string" and modData.A10YL_OpKey ~= ""
end

function Identity.getOperationKey(obj)
    if not obj then return nil end
    local modData = obj:getModData()
    if not modData or modData.A10YL_Owner ~= Identity.OWNER then return nil end
    local key = modData.A10YL_OpKey
    if type(key) ~= "string" or key == "" then return nil end
    return key
end

return Identity
