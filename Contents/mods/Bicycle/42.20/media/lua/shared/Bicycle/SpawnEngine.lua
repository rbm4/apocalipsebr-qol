local BicycleUtils = require("Bicycle/Utils")

SpawnEngine = SpawnEngine or {}

local CHUNK_SIZE = 8
local HASH_MODULUS = 2147483647
local STREAM_GROUP_ROLL = 101
local STREAM_ROOM_PICK = 211
local STREAM_SQUARE_OFFSET = 307
local STREAM_VARIANT = 401

local specs = {}
local specsById = {}
local eventsInstalled = false
local worldSalt = nil
local currentChunkKey = nil
local roomsSeenInChunk = {}

---@param accumulator number
---@param value number
---@return number
---@nodiscard
local function hashMix(accumulator, value)
    local mixed = (accumulator + (math.floor(value) % HASH_MODULUS)) % HASH_MODULUS
    mixed = (mixed * 8191 + 60493) % HASH_MODULUS
    return (mixed * 127 + 12347) % HASH_MODULUS
end

---@param accumulator number
---@param values number[]
---@return number
---@nodiscard
local function hashValues(accumulator, values)
    local result = accumulator
    for i = 1, #values do
        result = hashMix(result, values[i])
    end
    return result
end

---@param accumulator number
---@param text string
---@return number
---@nodiscard
local function hashString(accumulator, text)
    local result = accumulator
    for i = 1, #text do
        result = hashMix(result, string.byte(text, i))
    end
    return result
end

---@param seed number
---@param stream number
---@return number
---@nodiscard
local function hashUnit(seed, stream)
    return hashMix(seed, stream) / HASH_MODULUS
end

---@return number
---@nodiscard
local function getWorldSalt()
    if worldSalt then
        return worldSalt
    end

    local salt = 0
    local world = getWorld()
    if world and world.getWorld then
        local saveName = world:getWorld()
        if type(saveName) == "string" then
            salt = hashString(salt, saveName)
        end
    end

    worldSalt = salt
    return worldSalt
end

---@param coordinate number
---@return number
---@nodiscard
local function chunkIndexOf(coordinate)
    return math.floor(coordinate / CHUNK_SIZE)
end

---@param square IsoGridSquare|nil
---@return boolean
---@nodiscard
local function isValidSpawnLocation(square)
    if not square then
        return false
    end
    if not square:isFree(false) then
        return false
    end

    local x, y, z = square:getX(), square:getY(), square:getZ()
    local aboveSquare = getCell():getGridSquare(x, y, z + 1)
    if aboveSquare then
        if aboveSquare:HasStairs() then
            return false
        end
        for i = 0, aboveSquare:getObjects():size() - 1 do
            local obj = aboveSquare:getObjects():get(i)
            if obj and (obj:getSprite():getProperties():has("FloorOverlay")
                or obj:getSprite():getProperties():has("WallOverlay")) then
                return false
            end
        end
    end

    for i = 0, square:getObjects():size() - 1 do
        local obj = square:getObjects():get(i)
        if obj
            and obj:getSprite()
            and obj:getSprite():getProperties()
            and (obj:getSprite():getProperties():has("SolidTrans")
                or obj:getSprite():getProperties():has("Solid")
                or obj:getSprite():getProperties():has("WallN")
                or obj:getSprite():getProperties():has("WallW")) then
            return false
        end
    end

    local adjacentOpenCount = 0
    local adjacentSquares = {
        getCell():getGridSquare(x + 1, y, z),
        getCell():getGridSquare(x - 1, y, z),
        getCell():getGridSquare(x, y + 1, z),
        getCell():getGridSquare(x, y - 1, z),
    }

    for squareIndex = 1, #adjacentSquares do
        local adjSquare = adjacentSquares[squareIndex]
        if adjSquare and adjSquare:isFreeOrMidair(false) and not adjSquare:isSolid() and not adjSquare:isSolidTrans() then
            local clear = true
            for i = 0, adjSquare:getObjects():size() - 1 do
                local obj = adjSquare:getObjects():get(i)
                if obj
                    and obj:getSprite()
                    and obj:getSprite():getProperties()
                    and (obj:getSprite():getProperties():has("SolidTrans")
                        or obj:getSprite():getProperties():has("Solid")) then
                    clear = false
                    break
                end
            end
            if clear then
                adjacentOpenCount = adjacentOpenCount + 1
            end
        end
    end

    return adjacentOpenCount >= 2
end

---@param square IsoGridSquare|nil
---@param itemTypes table<string, boolean>
---@return boolean
---@nodiscard
local function squareHasItemOfType(square, itemTypes)
    if not square then
        return false
    end

    local worldObjects = square:getWorldObjects()
    if not worldObjects then
        return false
    end

    for i = 0, worldObjects:size() - 1 do
        local worldObject = worldObjects:get(i)
        local item = worldObject and worldObject:getItem()
        if item and itemTypes[item:getType()] then
            return true
        end
    end

    return false
end

---@param roomDefs RoomDef[]
---@param itemTypes table<string, boolean>
---@return boolean
---@nodiscard
local function anyRoomHasItemOfType(roomDefs, itemTypes)
    local cell = getCell()
    if not cell then
        return false
    end

    for roomIndex = 1, #roomDefs do
        local roomDef = roomDefs[roomIndex]
        local rects = roomDef:getRects()
        local level = roomDef:getZ()
        if rects then
            for rectIndex = 0, rects:size() - 1 do
                local rect = rects:get(rectIndex)
                local minX = rect:getX()
                local minY = rect:getY()
                for y = minY, minY + rect:getH() - 1 do
                    for x = minX, minX + rect:getW() - 1 do
                        if squareHasItemOfType(cell:getGridSquare(x, y, level), itemTypes) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

---@param roomDef RoomDef
---@return number|nil, number|nil
---@nodiscard
local function resolveOwnerChunk(roomDef)
    local rects = roomDef:getRects()
    if not rects or rects:size() == 0 then
        return nil, nil
    end

    local areaByKey = {}
    local orderedChunks = {}

    for rectIndex = 0, rects:size() - 1 do
        local rect = rects:get(rectIndex)
        local minX = rect:getX()
        local minY = rect:getY()
        local maxX = minX + rect:getW() - 1
        local maxY = minY + rect:getH() - 1

        for chunkX = chunkIndexOf(minX), chunkIndexOf(maxX) do
            for chunkY = chunkIndexOf(minY), chunkIndexOf(maxY) do
                local overlapW = math.min(maxX, chunkX * CHUNK_SIZE + CHUNK_SIZE - 1) - math.max(minX, chunkX * CHUNK_SIZE) + 1
                local overlapH = math.min(maxY, chunkY * CHUNK_SIZE + CHUNK_SIZE - 1) - math.max(minY, chunkY * CHUNK_SIZE) + 1
                local key = chunkX .. ":" .. chunkY
                local accumulated = areaByKey[key]
                if not accumulated then
                    accumulated = 0
                    orderedChunks[#orderedChunks + 1] = { key = key, x = chunkX, y = chunkY }
                end
                areaByKey[key] = accumulated + overlapW * overlapH
            end
        end
    end

    local bestArea = -1
    local bestX, bestY = nil, nil
    for i = 1, #orderedChunks do
        local entry = orderedChunks[i]
        local area = areaByKey[entry.key]
        if area > bestArea then
            bestArea = area
            bestX = entry.x
            bestY = entry.y
        end
    end

    return bestX, bestY
end

---@param roomDef RoomDef
---@param ownerChunkX number
---@param ownerChunkY number
---@return table[]
---@nodiscard
local function collectOwnerChunkSquares(roomDef, ownerChunkX, ownerChunkY)
    local rects = roomDef:getRects()
    if not rects then
        return {}
    end

    local level = roomDef:getZ()
    local chunkMinX = ownerChunkX * CHUNK_SIZE
    local chunkMinY = ownerChunkY * CHUNK_SIZE
    local chunkMaxX = chunkMinX + CHUNK_SIZE - 1
    local chunkMaxY = chunkMinY + CHUNK_SIZE - 1
    local coordinates = {}

    for rectIndex = 0, rects:size() - 1 do
        local rect = rects:get(rectIndex)
        local minX = math.max(rect:getX(), chunkMinX)
        local minY = math.max(rect:getY(), chunkMinY)
        local maxX = math.min(rect:getX() + rect:getW() - 1, chunkMaxX)
        local maxY = math.min(rect:getY() + rect:getH() - 1, chunkMaxY)
        for y = minY, maxY do
            for x = minX, maxX do
                coordinates[#coordinates + 1] = { x = x, y = y, z = level }
            end
        end
    end

    return coordinates
end

---@param spec table
---@return table<string, number>
---@nodiscard
local function getRoomChances(spec)
    if not spec.chances then
        spec.chances = spec.buildRoomChances()
    end
    return spec.chances
end

---@param left RoomDef
---@param right RoomDef
---@return boolean
---@nodiscard
local function roomDefOrder(left, right)
    if left:getZ() ~= right:getZ() then
        return left:getZ() < right:getZ()
    end
    if left:getX() ~= right:getX() then
        return left:getX() < right:getX()
    end
    if left:getY() ~= right:getY() then
        return left:getY() < right:getY()
    end
    if left:getX2() ~= right:getX2() then
        return left:getX2() < right:getX2()
    end
    if left:getY2() ~= right:getY2() then
        return left:getY2() < right:getY2()
    end
    return left:getName() < right:getName()
end

---@param spec table
---@param roomDef RoomDef
---@param buildingDef BuildingDef|nil
---@return RoomDef[], number[]
---@nodiscard
local function collectTargetRooms(spec, roomDef, buildingDef)
    local chances = getRoomChances(spec)
    local rooms = {}
    local roomChances = {}

    if not buildingDef then
        local chance = chances[roomDef:getName()]
        if chance and chance > 0 then
            rooms[1] = roomDef
            roomChances[1] = chance
        end
        return rooms, roomChances
    end

    local buildingRooms = buildingDef:getRooms()
    if not buildingRooms then
        return rooms, roomChances
    end

    for i = 0, buildingRooms:size() - 1 do
        local candidate = buildingRooms:get(i)
        local chance = candidate and chances[candidate:getName()]
        if chance and chance > 0 then
            rooms[#rooms + 1] = candidate
        end
    end

    table.sort(rooms, roomDefOrder)

    for i = 1, #rooms do
        roomChances[i] = chances[rooms[i]:getName()]
    end

    return rooms, roomChances
end

---@param spec table
---@param roomDef RoomDef
---@param buildingDef BuildingDef|nil
---@return table|boolean
---@nodiscard
local function computeDecision(spec, roomDef, buildingDef)
    local rooms, roomChances = collectTargetRooms(spec, roomDef, buildingDef)
    if #rooms == 0 then
        return false
    end

    local salt = getWorldSalt()
    local seed
    if buildingDef then
        seed = hashValues(salt, {
            spec.salt,
            buildingDef:getX(), buildingDef:getY(), buildingDef:getX2(), buildingDef:getY2(),
        })
    else
        seed = hashValues(salt, {
            spec.salt,
            roomDef:getX(), roomDef:getY(), roomDef:getX2(), roomDef:getY2(), roomDef:getZ(),
        })
    end

    local missAll = 1
    local weightTotal = 0
    for i = 1, #roomChances do
        local clamped = math.max(0, math.min(100, roomChances[i]))
        roomChances[i] = clamped
        missAll = missAll * (1 - clamped / 100)
        weightTotal = weightTotal + clamped
    end

    if weightTotal <= 0 then
        return false
    end
    if hashUnit(seed, STREAM_GROUP_ROLL) >= (1 - missAll) then
        return false
    end

    local pick = hashUnit(seed, STREAM_ROOM_PICK) * weightTotal
    local cursor = 0
    local winner = rooms[#rooms]
    for i = 1, #rooms do
        cursor = cursor + roomChances[i]
        if pick < cursor then
            winner = rooms[i]
            break
        end
    end

    local ownerChunkX, ownerChunkY = resolveOwnerChunk(winner)
    if not ownerChunkX then
        return false
    end

    local coordinates = collectOwnerChunkSquares(winner, ownerChunkX, ownerChunkY)
    if #coordinates == 0 then
        return false
    end

    return {
        seed = seed,
        rooms = rooms,
        winner = winner,
        winnerName = winner:getName(),
        ownerChunkX = ownerChunkX,
        ownerChunkY = ownerChunkY,
        coordinates = coordinates,
    }
end

---@param decision table
---@param buildingDef BuildingDef|nil
---@return boolean
---@nodiscard
local function isRetrofitAllowed(decision, buildingDef)
    if buildingDef and buildingDef:isHasBeenVisited() then
        return false
    end
    return not decision.winner:isExplored()
end

---@param decision table
---@param buildingDef BuildingDef|nil
---@param chunkX number
---@param chunkY number
---@param chunkIsNew boolean
---@return boolean, string
---@nodiscard
local function isPlacementAllowed(decision, buildingDef, chunkX, chunkY, chunkIsNew)
    if decision.ownerChunkX ~= chunkX or decision.ownerChunkY ~= chunkY then
        return false, "not-owner-chunk"
    end
    if chunkIsNew then
        return true, "new-chunk"
    end
    if isRetrofitAllowed(decision, buildingDef) then
        return true, "retrofit-window-open"
    end
    return false, "generated-chunk-retrofit-closed"
end

---@param spec table
---@param decision table
---@return nil
local function placeSpawn(spec, decision)
    if anyRoomHasItemOfType(decision.rooms, spec.itemTypes) then
        return
    end

    local cell = getCell()
    if not cell then
        return
    end

    local coordinates = decision.coordinates
    local count = #coordinates
    local offset = math.floor(hashUnit(decision.seed, STREAM_SQUARE_OFFSET) * count)

    for i = 0, count - 1 do
        local coordinate = coordinates[(offset + i) % count + 1]
        local square = cell:getGridSquare(coordinate.x, coordinate.y, coordinate.z)
        if square and not squareHasItemOfType(square, spec.itemTypes) and isValidSpawnLocation(square) then
            local fullType = spec.pickFullType(decision.winnerName, hashUnit(decision.seed, STREAM_VARIANT))
            if fullType then
                BicycleUtils.addPersistentWorldItem(square, fullType, 0.0, 0.0, 0.0)
            end
            return
        end
    end
end

---@param spec table
---@param roomDef RoomDef
---@param chunkX number
---@param chunkY number
---@param chunkIsNew boolean
---@return nil
local function evaluate(spec, roomDef, chunkX, chunkY, chunkIsNew)
    local buildingDef = roomDef:getBuilding()
    local groupId
    if buildingDef then
        groupId = "b" .. tostring(buildingDef:getID())
    else
        groupId = "r" .. tostring(roomDef:getID())
    end

    if spec.resolved[groupId] then
        return
    end

    local decision = spec.decisions[groupId]
    if decision == nil then
        decision = computeDecision(spec, roomDef, buildingDef)
        spec.decisions[groupId] = decision
    end
    if decision == false then
        return
    end

    if not isPlacementAllowed(decision, buildingDef, chunkX, chunkY, chunkIsNew) then
        return
    end

    spec.resolved[groupId] = true
    placeSpawn(spec, decision)
end

---@param square IsoGridSquare|nil
---@return nil
local function onLoadGridsquare(square)
    if isClient() then
        return
    end
    if not square or #specs == 0 then
        return
    end

    local room = square:getRoom()
    if not room then
        return
    end

    local roomDef = room:getRoomDef()
    if not roomDef then
        return
    end

    local chunkX = chunkIndexOf(square:getX())
    local chunkY = chunkIndexOf(square:getY())
    local chunkKey = chunkX .. ":" .. chunkY
    if chunkKey ~= currentChunkKey then
        currentChunkKey = chunkKey
        roomsSeenInChunk = {}
    end

    local roomId = roomDef:getID()
    if roomsSeenInChunk[roomId] then
        return
    end
    roomsSeenInChunk[roomId] = true

    local chunk = square:getChunk()
    if not chunk then
        return
    end

    local chunkIsNew = chunk:isNewChunk()
    for i = 1, #specs do
        evaluate(specs[i], roomDef, chunkX, chunkY, chunkIsNew)
    end
end

---@return nil
local function onGameStart()
    worldSalt = nil
    currentChunkKey = nil
    roomsSeenInChunk = {}
    for i = 1, #specs do
        specs[i].decisions = {}
        specs[i].resolved = {}
        specs[i].chances = nil
    end
end

---@param spec table
---@return nil
function SpawnEngine.register(spec)
    spec.decisions = {}
    spec.resolved = {}
    spec.chances = nil
    specs[#specs + 1] = spec
    specsById[spec.id] = spec

    if not eventsInstalled then
        eventsInstalled = true
        Events.LoadGridsquare.Add(onLoadGridsquare)
        Events.OnGameStart.Add(onGameStart)
    end
end

---@param id string
---@return table|nil
---@nodiscard
function SpawnEngine.getSpec(id)
    return specsById[id]
end

---@param id string
---@param roomDef RoomDef|nil
---@return table|boolean|nil
---@nodiscard
function SpawnEngine.decide(id, roomDef)
    local spec = specsById[id]
    if not spec or not roomDef then
        return nil
    end
    return computeDecision(spec, roomDef, roomDef:getBuilding())
end

---@param id string
---@param decision table
---@return nil
function SpawnEngine.place(id, decision)
    local spec = specsById[id]
    if not spec or not decision then
        return
    end
    placeSpawn(spec, decision)
end

---@param id string
---@param decision table|boolean|nil
---@return table|nil
---@nodiscard
function SpawnEngine.summarize(id, decision)
    if decision == nil then
        return nil
    end
    if decision == false then
        return { spawns = false }
    end

    return {
        spawns = true,
        winnerName = decision.winnerName,
        winnerX = decision.winner:getX(),
        winnerY = decision.winner:getY(),
        winnerZ = decision.winner:getZ(),
        winnerExplored = decision.winner:isExplored(),
        ownerChunkX = decision.ownerChunkX,
        ownerChunkY = decision.ownerChunkY,
        candidateCount = #decision.coordinates,
        roomCount = #decision.rooms,
        seed = decision.seed,
    }
end

---@param id string
---@param roomDef RoomDef|nil
---@return table|nil
---@nodiscard
function SpawnEngine.probePlacement(id, roomDef)
    local spec = specsById[id]
    if not spec or not roomDef then
        return nil
    end

    local buildingDef = roomDef:getBuilding()
    local decision = computeDecision(spec, roomDef, buildingDef)
    if decision == false then
        return { spawns = false, wouldPlace = false, reason = "no-spawn" }
    end

    local probeSquare, chunkLoaded, chunkIsNew = nil, false, false
    local cell = getCell()
    if cell then
        local coordinates = decision.coordinates
        for i = 1, #coordinates do
            local coordinate = coordinates[i]
            local square = cell:getGridSquare(coordinate.x, coordinate.y, coordinate.z)
            local chunk = square and square:getChunk()
            if chunk then
                probeSquare = coordinate
                chunkLoaded = true
                chunkIsNew = chunk:isNewChunk()
                break
            end
        end
    end

    local allowed, reason = isPlacementAllowed(
        decision, buildingDef, decision.ownerChunkX, decision.ownerChunkY, chunkIsNew)

    local groupId
    if buildingDef then
        groupId = "b" .. tostring(buildingDef:getID())
    else
        groupId = "r" .. tostring(roomDef:getID())
    end

    return {
        spawns = true,
        wouldPlace = allowed,
        reason = reason,
        chunkLoaded = chunkLoaded,
        chunkIsNew = chunkIsNew,
        retrofitOpen = isRetrofitAllowed(decision, buildingDef),
        buildingVisited = (buildingDef and buildingDef:isHasBeenVisited()) or false,
        roomExplored = decision.winner:isExplored(),
        resolvedThisSession = spec.resolved[groupId] == true,
        ownerChunkX = decision.ownerChunkX,
        ownerChunkY = decision.ownerChunkY,
        probeX = probeSquare and probeSquare.x or nil,
        probeY = probeSquare and probeSquare.y or nil,
        probeZ = probeSquare and probeSquare.z or nil,
    }
end

---@return nil
function SpawnEngine.resetSessionState()
    onGameStart()
end

return SpawnEngine
