-- Abyss's 10 Year Later - small server-side compatibility registry.
--
-- Compatibility addons should declare `require=Abyss10YearsLater` in mod.info,
-- then require this module from their server Lua and register only read-only
-- classification/protection callbacks. This API intentionally exposes no queue
-- or mutation internals.
local Compatibility = {}
local Text = require("A10YL/A10YL_Translation")
local Debug = require("A10YL/core/A10YL_Debug")

Compatibility.API_VERSION = 1

local TERRAIN_CLASSES = {
    natural = true,
    road = true,
    hardscape = true,
    rail = true,
    water = true,
    protected = true,
}

local OUTPUT_POOLS = {
    tree = true,
    grass = true,
    leaf = true,
    customgrass = true,
    bush = true,
    debris = true,
    vinew = true,
    vinewtop = true,
    vinewlow = true,
    vinen = true,
    vinentop = true,
    vinenlow = true,
    vinenw = true,
    vinenwtop = true,
    vinenwlow = true,
}

Compatibility.TERRAIN_CLASSES = TERRAIN_CLASSES
Compatibility.OUTPUT_POOLS = OUTPUT_POOLS

local protectedSprites = {}
local protectedPrefixes = {}
local protectedPredicates = {}
local systemExclusions = {}
local terrainSprites = {}
local terrainPrefixes = {}
local terrainClassifiers = {}
local outputSprites = {}
local warned = {}
local revision = 0

local function nonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function bumpRevision()
    revision = revision + 1
end

local function warnOnce(key, message)
    key = tostring(key or message or "unknown")
    if warned[key] then return end
    warned[key] = true
    Debug.warn("[Compatibility] " .. tostring(message or key))
end

local function safeCallback(kind, id, callback, ...)
    local ok, result = pcall(callback, ...)
    if not ok then
        warnOnce(kind .. ":" .. tostring(id),
            Text.format(
                "IGUI_A10YL_Warning_CompatibilityCallback",
                "Compatibility callback '{id}' ({kind}) failed and was treated as protected: {error}",
                { id = id, kind = kind, error = result }
            ))
        return nil, false
    end
    return result, true
end

local function addNamedCallback(registry, id, callback)
    if not nonEmptyString(id) or type(callback) ~= "function" then
        return false
    end
    if registry[id] ~= nil then
        return false
    end
    registry[id] = callback
    bumpRevision()
    return true
end

local function spriteNameOf(obj)
    if not obj then return nil end
    if type(obj.getSpriteName) == "function" then
        local ok, value = pcall(obj.getSpriteName, obj)
        if ok and value ~= nil then return tostring(value) end
    end
    if type(obj.getSprite) == "function" then
        local okSprite, sprite = pcall(obj.getSprite, obj)
        if okSprite and sprite and type(sprite.getName) == "function" then
            local okName, name = pcall(sprite.getName, sprite)
            if okName and name ~= nil then return tostring(name) end
        end
    end
    return nil
end

local function floorSpriteName(square)
    if not square or type(square.getFloor) ~= "function" then return nil end
    local okFloor, floor = pcall(square.getFloor, square)
    if not okFloor or not floor then return nil end
    if type(floor.getSpriteName) == "function" then
        local okName, name = pcall(floor.getSpriteName, floor)
        if okName and name ~= nil then return tostring(name) end
    end
    if type(floor.getSprite) == "function" then
        local okSprite, sprite = pcall(floor.getSprite, floor)
        if okSprite and sprite and type(sprite.getName) == "function" then
            local okName, name = pcall(sprite.getName, sprite)
            if okName and name ~= nil then return tostring(name) end
        end
    end
    return nil
end

local function startsWith(value, prefix)
    return value ~= nil and prefix ~= nil and string.sub(value, 1, #prefix) == prefix
end

function Compatibility.getRevision()
    return revision
end

function Compatibility.registerProtectedSprite(spriteName)
    if not nonEmptyString(spriteName) or protectedSprites[spriteName] then
        return false
    end
    protectedSprites[spriteName] = true
    bumpRevision()
    return true
end

function Compatibility.registerProtectedPrefix(prefix)
    if not nonEmptyString(prefix) then return false end
    for i = 1, #protectedPrefixes do
        if protectedPrefixes[i] == prefix then return false end
    end
    protectedPrefixes[#protectedPrefixes + 1] = prefix
    table.sort(protectedPrefixes)
    bumpRevision()
    return true
end

function Compatibility.registerProtectedPredicate(id, callback)
    return addNamedCallback(protectedPredicates, id, callback)
end

function Compatibility.registerSystemExclusion(systemName, id, callback)
    if not nonEmptyString(systemName) or not nonEmptyString(id) or type(callback) ~= "function" then
        return false
    end
    local system = string.lower(systemName)
    systemExclusions[system] = systemExclusions[system] or {}
    return addNamedCallback(systemExclusions[system], id, callback)
end

function Compatibility.registerTerrainSprite(className, spriteName)
    local class = type(className) == "string" and string.lower(className) or nil
    if not TERRAIN_CLASSES[class] or not nonEmptyString(spriteName) then return false end
    terrainSprites[class] = terrainSprites[class] or {}
    if terrainSprites[class][spriteName] then return false end
    terrainSprites[class][spriteName] = true
    bumpRevision()
    return true
end

function Compatibility.registerTerrainPrefix(className, prefix)
    local class = type(className) == "string" and string.lower(className) or nil
    if not TERRAIN_CLASSES[class] or not nonEmptyString(prefix) then return false end
    terrainPrefixes[class] = terrainPrefixes[class] or {}
    for i = 1, #terrainPrefixes[class] do
        if terrainPrefixes[class][i] == prefix then return false end
    end
    terrainPrefixes[class][#terrainPrefixes[class] + 1] = prefix
    table.sort(terrainPrefixes[class])
    bumpRevision()
    return true
end

function Compatibility.registerTerrainClassifier(id, callback)
    return addNamedCallback(terrainClassifiers, id, callback)
end

function Compatibility.registerOutputSprite(poolName, spriteName)
    if not nonEmptyString(poolName) or not nonEmptyString(spriteName) then return false end
    local pool = string.lower(poolName)
    if not OUTPUT_POOLS[pool] then return false end
    outputSprites[pool] = outputSprites[pool] or {}
    if outputSprites[pool][spriteName] then return false end
    outputSprites[pool][spriteName] = true
    bumpRevision()
    return true
end

function Compatibility.getOutputSprites(poolName)
    if not nonEmptyString(poolName) then return {} end
    local values = outputSprites[string.lower(poolName)]
    if not values then return {} end

    local result = {}
    for spriteName, _ in pairs(values) do
        result[#result + 1] = spriteName
    end
    table.sort(result)
    return result
end

function Compatibility.isProtectedObject(obj, square)
    if not obj then return false end

    local spriteName = spriteNameOf(obj)
    if spriteName and protectedSprites[spriteName] then return true end
    if spriteName then
        for i = 1, #protectedPrefixes do
            if startsWith(spriteName, protectedPrefixes[i]) then return true end
        end
    end

    for id, callback in pairs(protectedPredicates) do
        local result, ok = safeCallback("protected", id, callback, obj, square)
        if not ok then return true end
        if result == true then return true end
    end

    return false
end

function Compatibility.isSystemExcluded(systemName, obj, square)
    if Compatibility.isProtectedObject(obj, square) then return true end
    if not nonEmptyString(systemName) then return false end

    local callbacks = systemExclusions[string.lower(systemName)]
    if not callbacks then return false end
    for id, callback in pairs(callbacks) do
        local result, ok = safeCallback("exclude:" .. tostring(systemName), id, callback, obj, square)
        if not ok then return true end
        if result == true then return true end
    end
    return false
end

function Compatibility.isSquareExcluded(systemName, square, context)
    if not square then return true end
    local system = nonEmptyString(systemName) and string.lower(systemName) or ""
    if context then
        context._compatSquareExclusions = context._compatSquareExclusions or {}
        local cached = context._compatSquareExclusions[system]
        if cached ~= nil then return cached == true end
    end

    local objects = square:getObjects()
    if not objects then
        if context then context._compatSquareExclusions[system] = false end
        return false
    end
    for i = 0, objects:size() - 1 do
        if Compatibility.isSystemExcluded(systemName, objects:get(i), square) then
            if context then context._compatSquareExclusions[system] = true end
            return true
        end
    end
    if context then context._compatSquareExclusions[system] = false end
    return false
end

function Compatibility.classifyTerrain(square)
    if not square then return nil, false end
    local spriteName = floorSpriteName(square)
    local selected = nil

    local function accept(class)
        if selected == nil then
            selected = class
            return true
        end
        if selected ~= class then
            return false
        end
        return true
    end

    if spriteName then
        for class, sprites in pairs(terrainSprites) do
            if sprites[spriteName] and not accept(class) then
                warnOnce("terrain:sprite:" .. spriteName,
                    "conflicting terrain registrations for sprite '" .. spriteName .. "'; treating square as protected")
                return "protected", true
            end
        end
        for class, prefixes in pairs(terrainPrefixes) do
            for i = 1, #prefixes do
                if startsWith(spriteName, prefixes[i]) and not accept(class) then
                    warnOnce("terrain:prefix:" .. spriteName,
                        "conflicting terrain prefix registrations for sprite '" .. spriteName .. "'; treating square as protected")
                    return "protected", true
                end
            end
        end
    end

    for id, callback in pairs(terrainClassifiers) do
        local result, ok = safeCallback("terrain", id, callback, square, spriteName)
        if not ok then return "protected", true end
        if result ~= nil and result ~= false then
            local class = type(result) == "string" and string.lower(result) or nil
            if not TERRAIN_CLASSES[class] then
                warnOnce("terrain:return:" .. tostring(id),
                    "terrain callback '" .. tostring(id) .. "' returned unsupported class; treating square as protected")
                return "protected", true
            end
            if not accept(class) then
                warnOnce("terrain:conflict:" .. tostring(id) .. ":" .. tostring(spriteName),
                    "conflicting terrain classifiers; treating square as protected")
                return "protected", true
            end
        end
    end

    return selected, selected ~= nil
end

return Compatibility
