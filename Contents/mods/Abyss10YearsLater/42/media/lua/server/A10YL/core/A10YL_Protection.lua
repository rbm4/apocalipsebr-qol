-- Central non-mutability checks for player-built, moved or otherwise stateful objects.
-- This module is deliberately small and dependency-light so every ageing system can
-- use the same protection decision before planning and again immediately before
-- mutation. Fail closed when live object semantics cannot be inspected safely.
local Protection = {}

local A10YL_MODDATA_KEYS = {
    A10YL_Owner = true,
    A10YL_Type = true,
    A10YL_OpKey = true,
    A10YL_EffectKey = true,
    -- Generator 26 may annotate a persistent vanilla object with the list of
    -- A10YL-owned attached visual operations. This is our own state, not a
    -- foreign-mod ownership signal.
    A10YL_AttachedOps = true,
}

local function isInstance(obj, className)
    if not obj or type(instanceof) ~= "function" then return false end
    local ok, value = pcall(instanceof, obj, className)
    return ok and value == true
end

local function call(obj, methodName, ...)
    if not obj then return false, nil end
    local method = obj[methodName]
    if type(method) ~= "function" then return false, nil end
    return pcall(method, obj, ...)
end

local function callBool(obj, methodName)
    local ok, value = call(obj, methodName)
    if ok == false and obj and type(obj[methodName]) == "function" then return true end
    return value == true
end

local function tableHasForeignEntries(value)
    if value == nil then return false end
    local ok, result = pcall(function()
        for key, _ in pairs(value) do
            if not A10YL_MODDATA_KEYS[tostring(key)] then
                return true
            end
        end
        return false
    end)
    return not ok or result == true
end

function Protection.isA10YLObject(obj)
    if not obj or not obj.getModData then return false end
    local ok, modData = pcall(obj.getModData, obj)
    return ok and modData and tostring(modData.A10YL_Owner or "") == "Abyss10YearsLater"
end

function Protection.objectHasForeignModData(obj)
    if not obj or not obj.getModData then return false end
    local ok, modData = pcall(obj.getModData, obj)
    if not ok then return true end
    return tableHasForeignEntries(modData)
end

function Protection.isPlayerBuiltOrMovedObject(obj)
    if not obj or Protection.isA10YLObject(obj) then return false end

    -- Vehicles are never part of deterministic map ageing targets.
    if isInstance(obj, "BaseVehicle") then return true end

    -- Moved furniture/player-placed moveables use this native flag when exposed.
    if callBool(obj, "isMovedThumpable") then return true end

    -- Player constructions in B42 are represented through IsoThumpable-derived
    -- objects: walls, fences, gates, doors/window frames, stairs, floors, roofs,
    -- crates, rain collectors and many built utility objects. Treating them as
    -- protected is safer than trying to distinguish every construction subtype.
    if isInstance(obj, "IsoThumpable") then return true end

    -- Any non-A10YL object carrying foreign modData has state we cannot safely
    -- preserve through visual ageing. This also protects modded building pieces.
    if Protection.objectHasForeignModData(obj) then return true end

    return false
end

local function scanObjectList(objects)
    if not objects or type(objects.size) ~= "function" or type(objects.get) ~= "function" then
        return false
    end
    local okSize, size = pcall(objects.size, objects)
    if not okSize then return true end
    size = tonumber(size) or 0
    for i = 0, size - 1 do
        local okObj, obj = pcall(objects.get, objects, i)
        if not okObj then return true end
        if Protection.isPlayerBuiltOrMovedObject(obj) then return true end
    end
    return false
end

local function cachedProtected(context)
    if type(context) ~= "table" then return nil end
    local cached = rawget(context, "protectedSquare")
    if cached ~= nil then return cached == true end
    return nil
end

local function rememberProtected(context, value)
    if type(context) == "table" then
        rawset(context, "protectedSquare", value == true)
    end
end

local function computeProtectedSquare(square)
    if not square then return true end

    if square.isVehicleIntersecting then
        local ok, intersects = pcall(square.isVehicleIntersecting, square)
        if not ok or intersects == true then return true end
    end

    if square.getObjects then
        local ok, objects = pcall(square.getObjects, square)
        if not ok or scanObjectList(objects) then return true end
    end

    if square.getSpecialObjects then
        local ok, objects = pcall(square.getSpecialObjects, square)
        if not ok or scanObjectList(objects) then return true end
    end

    return false
end

function Protection.isProtectedSquare(square, context)
    local cached = cachedProtected(context)
    if cached ~= nil then return cached end
    local protected = computeProtectedSquare(square)
    rememberProtected(context, protected)
    return protected
end

function Protection.isProtectedObject(obj, square, context)
    if Protection.isPlayerBuiltOrMovedObject(obj) then return true end
    if square then return Protection.isProtectedSquare(square, context) end
    if obj and obj.getSquare then
        local ok, ownSquare = pcall(obj.getSquare, obj)
        if not ok then return true end
        return Protection.isProtectedSquare(ownSquare)
    end
    return false
end

return Protection
