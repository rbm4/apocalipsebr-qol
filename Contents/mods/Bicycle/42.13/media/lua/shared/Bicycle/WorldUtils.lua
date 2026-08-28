---@class BicycleWorldUtils
local BicycleWorldUtils = {}

---@type table<IsoDirections, { x: number, y: number }>
local DIRECTION_VECTORS = {
    [IsoDirections.N] = { x = 0, y = -1 },
    [IsoDirections.S] = { x = 0, y = 1 },
    [IsoDirections.E] = { x = 1, y = 0 },
    [IsoDirections.W] = { x = -1, y = 0 },
    [IsoDirections.NE] = { x = 1, y = -1 },
    [IsoDirections.NW] = { x = -1, y = -1 },
    [IsoDirections.SE] = { x = 1, y = 1 },
    [IsoDirections.SW] = { x = -1, y = 1 },
}

-- Directions travel to the server as names: NetTimedAction re-runs :new() from args serialized by name,
-- and a Java IsoDirections enum does not survive that trip. Only the four hoppable directions occur.
---@type table<string, IsoDirections>
local DIRECTION_BY_NAME = {
    N = IsoDirections.N,
    S = IsoDirections.S,
    E = IsoDirections.E,
    W = IsoDirections.W,
}

---@param direction IsoDirections|nil
---@return string|nil
---@nodiscard
function BicycleWorldUtils.directionToName(direction)
    if not direction then
        return nil
    end

    for name, value in pairs(DIRECTION_BY_NAME) do
        if value == direction then
            return name
        end
    end

    return nil
end

---@param name string|nil
---@return IsoDirections|nil
---@nodiscard
function BicycleWorldUtils.directionFromName(name)
    if type(name) ~= "string" then
        return nil
    end

    return DIRECTION_BY_NAME[name]
end

---@param square IsoGridSquare|nil
---@return boolean
---@nodiscard
function BicycleWorldUtils.isDroppableSquare(square)
    if not (square and square.isFree) then
        return false
    end

    return square:isFree(false)
end

-- Where a thrown bike can actually land, or nil if there is nowhere. A refused placement destroys the bike,
-- since it has already left the inventory by then. Distance 1 is never tried: it can land ON the fence square.
---@param character IsoGameCharacter|nil
---@param direction IsoDirections|nil
---@return IsoGridSquare|nil, number|nil
---@nodiscard
function BicycleWorldUtils.findThrowLandingSquare(character, direction)
    if not (character and direction) then
        return nil, nil
    end

    local startSquare = character:getSquare()
    local distances = { 3, 2 }
    for i = 1, #distances do
        local candidate = BicycleWorldUtils.getSquareInDirection(character, direction, distances[i])
        -- getSquareInDirection falls back to the thrower own square when off-cell; that is not over the fence.
        if candidate and candidate ~= startSquare and BicycleWorldUtils.isDroppableSquare(candidate) then
            return candidate, distances[i]
        end
    end

    return nil, nil
end

---@param square IsoGridSquare|nil
---@return boolean
---@nodiscard
function BicycleWorldUtils.squareHasHoppable(square)
    if not square or not square.getObjects then
        return false
    end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.isHoppable and obj:isHoppable() then
            return true
        end
    end

    return false
end

---@param square IsoGridSquare|nil
---@param includeDiagonal boolean|nil
---@return IsoGridSquare[]
---@nodiscard
function BicycleWorldUtils.getNeighborSquares(square, includeDiagonal)
    if not square then
        return {}
    end

    -- Cell lookups, not the cached n/s/e/w refs: those are null until neighbours are calculated.
    local cell = getCell()
    if not cell then
        return { square }
    end

    local sx, sy, sz = square:getX(), square:getY(), square:getZ()
    local offsets = {
        { x = 0, y = 0 },
        { x = 0, y = -1 },
        { x = 0, y = 1 },
        { x = 1, y = 0 },
        { x = -1, y = 0 },
    }
    if includeDiagonal then
        offsets[#offsets + 1] = { x = 1, y = -1 }
        offsets[#offsets + 1] = { x = -1, y = -1 }
        offsets[#offsets + 1] = { x = 1, y = 1 }
        offsets[#offsets + 1] = { x = -1, y = 1 }
    end

    -- Appended one at a time: a nil inside the array constructor ends the array early for ipairs.
    local squares = {}
    for i = 1, #offsets do
        local neighbor = cell:getGridSquare(sx + offsets[i].x, sy + offsets[i].y, sz)
        if neighbor then
            squares[#squares + 1] = neighbor
        end
    end

    return squares
end

---@param character IsoGameCharacter|nil
---@return IsoDirections|nil
---@nodiscard
function BicycleWorldUtils.findHoppableDirection(character)
    local square = character and character:getSquare()
    if not square then
        return nil
    end

    if BicycleWorldUtils.squareHasHoppable(square) then
        local props = square:getProperties()
        if props and props:has(IsoFlagType.HoppableN) then
            return IsoDirections.N
        end
        if props and props:has(IsoFlagType.HoppableW) then
            return IsoDirections.W
        end
    end

    -- Resolve through the cell, not IsoGridSquare cached n/s/e/w refs -- those are null until neighbours are
    -- calculated, which made a fence work only from the side that owns the Hoppable property.
    local cell = getCell()
    if not cell then
        return nil
    end

    local sx, sy, sz = square:getX(), square:getY(), square:getZ()
    local neighbors = {
        { dir = IsoDirections.N, square = cell:getGridSquare(sx, sy - 1, sz) },
        { dir = IsoDirections.S, square = cell:getGridSquare(sx, sy + 1, sz) },
        { dir = IsoDirections.E, square = cell:getGridSquare(sx + 1, sy, sz) },
        { dir = IsoDirections.W, square = cell:getGridSquare(sx - 1, sy, sz) },
    }

    for _, entry in ipairs(neighbors) do
        if BicycleWorldUtils.squareHasHoppable(entry.square) then
            return entry.dir
        end
    end

    return nil
end

---@param character IsoGameCharacter|nil
---@param direction IsoDirections|nil
---@param distance number|nil
---@return IsoGridSquare|nil
---@nodiscard
function BicycleWorldUtils.getSquareInDirection(character, direction, distance)
    local startSquare = character and character:getSquare()
    if not startSquare or not character then
        return nil
    end

    local delta = DIRECTION_VECTORS[direction or IsoDirections.S]
    if not delta then
        return startSquare
    end

    local cell = character:getCell()
    local step = distance or 1
    local targetX = startSquare:getX() + delta.x * step
    local targetY = startSquare:getY() + delta.y * step

    return cell and cell:getGridSquare(targetX, targetY, startSquare:getZ()) or startSquare
end

---@param square IsoGridSquare|nil
---@return boolean
---@nodiscard
function BicycleWorldUtils.isRoughSurface(square)
    if not square or not square.getObjects then
        return false
    end

    local roughMaterials = {
        Sand = true,
        Grass = true,
        Gravel = true,
        Dirt = true,
    }

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getProperties then
            local material = obj:getProperties():get("FootstepMaterial")
            if material and roughMaterials[material] then
                return true
            end
        end
    end

    return false
end

---@param square IsoGridSquare|nil
---@return IsoObject[]
---@nodiscard
function BicycleWorldUtils.getLuaTileObjects(square)
    local results = {}
    for _, neighbor in ipairs(BicycleWorldUtils.getNeighborSquares(square, true)) do
        if neighbor and neighbor.getLuaTileObjectList then
            for _, item in ipairs(neighbor:getLuaTileObjectList()) do
                table.insert(results, item)
            end
        end
    end

    return results
end

return BicycleWorldUtils
