local BicycleUtils = require("Bicycle/Utils")

---@class BicycleThrowRotations
local ThrowRotations = {}

---@class BicycleThrowRotation
---@field x number
---@field y number
---@field z number
---@field faceDir number|nil

---@return table<IsoDirections, BicycleThrowRotation>
---@nodiscard
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

---@type table<IsoDirections, BicycleThrowRotation>
ThrowRotations.THROW_ROTATIONS_BY_DIRECTION = buildDefaultThrowRotations()
ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.NE] = {
    x = 84,
    y = 285,
    z = 180,
    faceDir = 45,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.E] = {
    x = 84,
    y = 333,
    z = 180,
    faceDir = 90,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.SE] = {
    x = 84,
    y = 27,
    z = 180,
    faceDir = 135,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.S] = {
    x = 273,
    y = 240,
    z = 0,
    faceDir = 180,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.SW] = {
    x = 273,
    y = 297,
    z = 0,
    faceDir = 225,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.W] = {
    x = 276,
    y = 360,
    z = 0,
    faceDir = 270,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.NW] = {
    x = 267,
    y = 48,
    z = 0,
    faceDir = 315,
}

ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[IsoDirections.N] = {
    x = 270,
    y = 48,
    z = 0,
    faceDir = 0,
}

---@param direction IsoDirections|nil
---@param zRotation number|nil
---@return number
---@return number
---@return number
---@return BicycleThrowRotation|nil
---@nodiscard
function ThrowRotations.getThrowRotation(direction, zRotation)
    local rotation = ThrowRotations.THROW_ROTATIONS_BY_DIRECTION[direction]
    local normalizedZ = BicycleUtils.normalizeZRotation(zRotation)

    local fallbackZ = normalizedZ or 350
    local x = rotation and rotation.x or 84
    local y = rotation and rotation.y or 0
    local z = rotation and rotation.z or fallbackZ

    z = BicycleUtils.normalizeZRotation(z) or fallbackZ

    return x, y, z, rotation
end

---@param target BicycleThrowRotation|nil
---@param xRot number|nil
---@param yRot number|nil
---@param zRot number|nil
---@return boolean
---@nodiscard
local function rotationsMatch(target, xRot, yRot, zRot)
    if not target then
        return false
    end

    local tolerance = 0.1

    ---@param left number|nil
    ---@param right number|nil
    ---@return boolean
    ---@nodiscard
    local function close(left, right)
        return left ~= nil and right ~= nil and math.abs(left - right) <= tolerance
    end

    ---@param left number|nil
    ---@param right number|nil
    ---@return boolean
    ---@nodiscard
    local function closeZ(left, right)
        if left == nil or right == nil then
            return false
        end

        local normalizedLeft = BicycleUtils.normalizeZRotation(left)
        local normalizedRight = BicycleUtils.normalizeZRotation(right)
        if normalizedLeft == nil or normalizedRight == nil then
            return false
        end

        local diff = math.abs(normalizedLeft - normalizedRight)
        diff = math.min(diff, 360 - diff)
        return diff <= tolerance
    end

    return close(target.x, xRot) and close(target.y, yRot) and closeZ(target.z, zRot)
end

---@param xRot number|nil
---@param yRot number|nil
---@param zRot number|nil
---@return IsoDirections|nil
---@return BicycleThrowRotation|nil
---@nodiscard
function ThrowRotations.findMatchingRotation(xRot, yRot, zRot)
    for direction, rotation in pairs(ThrowRotations.THROW_ROTATIONS_BY_DIRECTION) do
        if rotationsMatch(rotation, xRot, yRot, zRot) then
            return direction, rotation
        end
    end

    return nil, nil
end

return ThrowRotations
