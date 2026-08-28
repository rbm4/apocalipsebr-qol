local BicycleUtils = {}

local BICYCLE_TYPES = {
    Bicycle = true,
    Bicycle_RedStreet = true,
}

local DirectionToRotation = {
    [IsoDirections.N] = 0,
    [IsoDirections.NE] = 45,
    [IsoDirections.E] = 90,
    [IsoDirections.SE] = 135,
    [IsoDirections.S] = 180,
    [IsoDirections.SW] = 225,
    [IsoDirections.W] = 270,
    [IsoDirections.NW] = 315,
}

BicycleUtils.normalizeZRotation = function(rotation)
    if rotation == nil then return nil end

    local normalized = rotation % 360
    if normalized < 0 then
        normalized = normalized + 360
    end

    return normalized
end

BicycleUtils.directionToZRotation = function(direction)
    return DirectionToRotation[direction]
end

BicycleUtils.zRotationToDirection = function(rotation)
    local normalized = BicycleUtils.normalizeZRotation(rotation)
    if normalized == nil then return nil end

    local closestDir = nil
    local smallestDiff = nil
    for dir, angle in pairs(DirectionToRotation) do
        local diff = math.abs(angle - normalized)
        diff = math.min(diff, 360 - diff)

        if not smallestDiff or diff < smallestDiff then
            smallestDiff = diff
            closestDir = dir
        end
    end

    return closestDir
end

function BicycleUtils.isBicycleType(itemType)
    if not itemType then return false end
    return BICYCLE_TYPES[itemType] == true
end

function BicycleUtils.isBicycleItem(item)
    if not (item and item.getType) then return false end
    return BicycleUtils.isBicycleType(item:getType())
end

function BicycleUtils.getBicycleTypes()
    local results = {}
    for typeName, _ in pairs(BICYCLE_TYPES) do
        table.insert(results, typeName)
    end
    table.sort(results)
    return results
end

BicycleUtils.runAfter = function(seconds, callback, ...)
    local elapsed = 0 --[[@as number]]
    local gameTime = GameTime.getInstance()
    local args = {...}

    local function tick()
        elapsed = elapsed + gameTime:getTimeDelta()
        if elapsed < seconds then
            return
        end

        Events.OnTick.Remove(tick)
        callback(unpack(args))
    end

    Events.OnTick.Add(tick)

    return function()
        Events.OnTick.Remove(tick)
    end
end

return BicycleUtils
