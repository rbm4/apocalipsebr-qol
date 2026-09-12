-- Lightweight runtime classification cache for the v0.8.0 optimisation pass.
-- The cache stores only stable map-surface facts for loaded square coordinates.
-- Player-built/protected checks still run fresh at plan/apply boundaries, so a
-- newly built object cannot be bypassed by a stale cached surface.
local Cache = {}

local MAX_SURFACE_ENTRIES = 8192
local MAX_FLOOR_ENTRIES = 8192

local surfaceByKey = {}
local floorByKey = {}
local surfaceEntries = 0
local floorEntries = 0

local stats = {
    surfaceHits = 0,
    surfaceMisses = 0,
    floorHits = 0,
    floorMisses = 0,
    clears = 0,
}

local function integer(value)
    value = tonumber(value)
    if value == nil then return nil end
    if value >= 0 then return math.floor(value) end
    return math.ceil(value)
end

function Cache.squareKey(square)
    if not square then return nil end
    local getX, getY, getZ = square.getX, square.getY, square.getZ
    if type(getX) ~= "function" or type(getY) ~= "function" or type(getZ) ~= "function" then
        return nil
    end
    local okX, x = pcall(getX, square)
    local okY, y = pcall(getY, square)
    local okZ, z = pcall(getZ, square)
    if not okX or not okY or not okZ then return nil end
    x, y, z = integer(x), integer(y), integer(z)
    if x == nil or y == nil or z == nil then return nil end
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function clearSurface()
    surfaceByKey = {}
    surfaceEntries = 0
    stats.clears = stats.clears + 1
end

local function clearFloor()
    floorByKey = {}
    floorEntries = 0
    stats.clears = stats.clears + 1
end

function Cache.getSurface(square, loader, arg1, arg2, arg3)
    if type(loader) ~= "function" then return nil end
    local key = Cache.squareKey(square)
    if key ~= nil then
        local cached = surfaceByKey[key]
        if cached ~= nil then
            stats.surfaceHits = stats.surfaceHits + 1
            return cached
        end
    end

    stats.surfaceMisses = stats.surfaceMisses + 1
    local value = loader(square, arg1, arg2, arg3)
    if key ~= nil and value ~= nil then
        if surfaceEntries >= MAX_SURFACE_ENTRIES then clearSurface() end
        if surfaceByKey[key] == nil then surfaceEntries = surfaceEntries + 1 end
        surfaceByKey[key] = value
    end
    return value
end

local function loadFloorSpriteName(square)
    local floor = square and square.getFloor and square:getFloor() or nil
    local sprite = floor and floor.getSprite and floor:getSprite() or nil
    local name = nil
    if floor and type(floor.getSpriteName) == "function" then
        local direct = floor:getSpriteName()
        if direct ~= nil then name = direct end
    end
    if name == nil and sprite and type(sprite.getName) == "function" then
        name = sprite:getName()
    end
    return name and tostring(name) or nil
end

function Cache.getFloorSpriteName(square)
    local key = Cache.squareKey(square)
    if key ~= nil then
        local cached = floorByKey[key]
        if cached ~= nil then
            stats.floorHits = stats.floorHits + 1
            if cached == false then return nil end
            return cached
        end
    end

    stats.floorMisses = stats.floorMisses + 1
    local value = loadFloorSpriteName(square)
    if key ~= nil then
        if floorEntries >= MAX_FLOOR_ENTRIES then clearFloor() end
        if floorByKey[key] == nil then floorEntries = floorEntries + 1 end
        floorByKey[key] = value or false
    end
    return value
end

function Cache.clearSquare(square)
    local key = Cache.squareKey(square)
    if not key then return end
    if surfaceByKey[key] ~= nil then
        surfaceByKey[key] = nil
        surfaceEntries = math.max(0, surfaceEntries - 1)
    end
    if floorByKey[key] ~= nil then
        floorByKey[key] = nil
        floorEntries = math.max(0, floorEntries - 1)
    end
end

function Cache.clearAll()
    surfaceByKey = {}
    floorByKey = {}
    surfaceEntries = 0
    floorEntries = 0
    stats.clears = stats.clears + 1
end

function Cache.getStats()
    return {
        surfaceEntries = surfaceEntries,
        floorEntries = floorEntries,
        surfaceHits = stats.surfaceHits,
        surfaceMisses = stats.surfaceMisses,
        floorHits = stats.floorHits,
        floorMisses = stats.floorMisses,
        clears = stats.clears,
    }
end

return Cache
