local BicycleUtils = require("Bicycle/Utils")

local ThrowRotations = {}

local function buildDefaultThrowRotations()
    local defaults = {}
    local directions = {
        IsoDirections.N,
        IsoDirections.NE,
        IsoDirections.E,
        IsoDirections.SE,
        IsoDirections.S,
        IsoDirections.SW,
        IsoDirections.W,
        IsoDirections.NW,
    }

    for _, dir in ipairs(directions) do
        local zRot = BicycleUtils.directionToZRotation(dir)
        defaults[dir] = {
            x = 84,
            y = 0,
            z = BicycleUtils.normalizeZRotation((zRot or 0) + 90),
        }
    end

    return defaults
end

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION = buildDefaultThrowRotations()
ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.NE] = {
    x = 84,  -- your desired X rotation
    y = 285,   -- your desired Y rotation
    z = 180, -- your desired Z rotation
    faceDir = 45,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.E] = {
    x = 84,  -- your desired X rotation
    y = 333,   -- your desired Y rotation
    z = 180, -- your desired Z rotation
    faceDir = 90,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.SE] = {
    x = 84,  -- your desired X rotation
    y = 27,   -- your desired Y rotation
    z = 180, -- your desired Z rotation
    faceDir = 135,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.S] = {
    x = 273,  -- your desired X rotation
    y = 240,   -- your desired Y rotation
    z = 0, -- your desired Z rotation
    faceDir = 180,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.SW] = {
    x = 273,  -- your desired X rotation
    y = 297,   -- your desired Y rotation
    z = 0, -- your desired Z rotation
    faceDir = 225,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.W] = {
    x = 276,  -- your desired X rotation
    y = 360,   -- your desired Y rotation
    z = 0, -- your desired Z rotation
    faceDir = 270,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.NW] = {
    x = 267,  -- your desired X rotation
    y = 48,   -- your desired Y rotation
    z = 0, -- your desired Z rotation
    faceDir = 315,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.N] = {
    x = 270,  -- your desired X rotation
    y = 48,   -- your desired Y rotation
    z = 0, -- your desired Z rotation
    faceDir = 0,
}

ThrowRotations.getThrowRotation = function(direction, zRotation)
    local rotation = ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[direction]
    local normalizedZ = BicycleUtils.normalizeZRotation(zRotation)

    local fallbackZ = normalizedZ or 350
    local x = rotation and rotation.x or 84
    local y = rotation and rotation.y or 0
    local z = rotation and rotation.z or fallbackZ

    z = BicycleUtils.normalizeZRotation(z) or fallbackZ

    return x, y, z, rotation
end

local function rotationsMatch(target, xRot, yRot, zRot)
    if not target then return false end

    local tolerance = 0.1
    local function close(a, b)
        return a ~= nil and b ~= nil and math.abs(a - b) <= tolerance
    end

    local function closeZ(a, b)
        if a == nil or b == nil then return false end
        local na = BicycleUtils.normalizeZRotation(a)
        local nb = BicycleUtils.normalizeZRotation(b)
        if na == nil or nb == nil then return false end

        local diff = math.abs(na - nb)
        diff = math.min(diff, 360 - diff)
        return diff <= tolerance
    end

    return close(target.x, xRot) and close(target.y, yRot) and closeZ(target.z, zRot)
end

ThrowRotations.findMatchingRotation = function(xRot, yRot, zRot)
    for direction, rotation in pairs(ThrowRotations.THROW_ROTATIONS_BY_DIRECTION) do
        if rotationsMatch(rotation, xRot, yRot, zRot) then
            return direction, rotation
        end
    end

    return nil, nil
end

return ThrowRotations
