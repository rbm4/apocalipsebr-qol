-- Original by Viruana for Zupercarts, modified by RedChili for Bicycle

require "Items/InventoryItemFactory"
require "Items/SuburbsDistributions"
require "Items/BicycleRoomDefs"

if not InventoryItemFactory or not InventoryItemFactory.CreateItem then
    InventoryItemFactory = {}
    function InventoryItemFactory.CreateItem(itemName)
        if ScriptManager and ScriptManager.instance then
            local item = ScriptManager.instance:FindItem(itemName)
            if not item then
                error("SpawnTMC: Fallback could not find item \"" .. tostring(itemName) .. "\"")
            end
            return item
        else
            error("SpawnTMC: ScriptManager not available!")
        end
    end
end

BikeSpawner = BikeSpawner or {}
BikeSpawner.Container = {}
BikeSpawner.Container.targetRooms = Bicycle.RoomDefs
BikeSpawner.Container.spawnedRooms = {}
BikeSpawner.Container.spawnReserves = {}
BikeSpawner.Container.tickCounter = 0
BikeSpawner.Container.checkInterval = 45
BikeSpawner.Container.processedSquares = {}
BikeSpawner.Container.buildingsWithBikes = {}
BikeSpawner.Container.spawnRateMultiplier = nil

local function getSpawnRateMultiplier()
    if BikeSpawner.Container.spawnRateMultiplier ~= nil then
        return BikeSpawner.Container.spawnRateMultiplier
    end

    local multiplier = 1
    if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.SpawnRate then
        multiplier = SandboxVars.Bicycle.SpawnRate
    end

    if multiplier >= 100 then
        BikeSpawner.Container.spawnRateMultiplier = 100
    else
        BikeSpawner.Container.spawnRateMultiplier = math.max(0, multiplier / 100)
    end

    return BikeSpawner.Container.spawnRateMultiplier
end

function BikeSpawner.Container.getRoomSpawnChance(roomName)
    local baseChance = BikeSpawner.Container.targetRooms[roomName]
    if not baseChance then return 0 end

    local scaledChance = baseChance * getSpawnRateMultiplier()
    return math.max(0, math.min(100, scaledChance))
end

function BikeSpawner.Container.getRandomBicycleType()
    if ZombRand(100) < 50 then
        return "Bicycle.Bicycle"
    end

    return "Bicycle.Bicycle_RedStreet"
end

function BikeSpawner.Container.getSquareID(square)
    if not square then return "invalid_square" end

    local buildingInfo = "no_building"

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    if not x or not y or not z then
        return "invalid_square"
    end

    local building = nil
    if square.getBuilding ~= nil then
        building = square:getBuilding()
    end

    if building ~= nil then
        local def = nil
        if building.getDef ~= nil then
            def = building:getDef()
        end

        if def ~= nil then
            local name = nil
            if def.getName ~= nil then
                name = def:getName()
            end

            if name ~= nil then
                buildingInfo = name
            end
        end
    end

    return x .. "," .. y .. "," .. z .. "," .. buildingInfo
end

function BikeSpawner.Container.getBuildingID(square)
    if not square then return nil end

    local building = nil
    if square.getBuilding ~= nil then
        building = square:getBuilding()
    end

    if building ~= nil then
        local def = nil
        if building.getDef ~= nil then
            def = building:getDef()
        end

        if def ~= nil then
            local x = def:getX()
            local y = def:getY()
            local w = def:getW()
            local h = def:getH()
            return x .. "," .. y .. "," .. w .. "," .. h
        end
    end

    return nil
end

local function isValidSpawnLocation(square)
    -- Basic checks
    if not square then return false end
    if not square:isFree(false) then return false end
    if square:isOutside() then return false end
-- Stair fix...?
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local aboveSquare = getCell():getGridSquare(x, y, z + 1)
    if aboveSquare then
        if aboveSquare:HasStairs() then return false end
        for i = 0, aboveSquare:getObjects():size() - 1 do
            local obj = aboveSquare:getObjects():get(i)
            if obj and (obj:getSprite():getProperties():Is("FloorOverlay") or
                       obj:getSprite():getProperties():Is("WallOverlay")) then
                return false
            end
        end
    end

    for i = 0, square:getObjects():size() - 1 do
        local obj = square:getObjects():get(i)
        if obj and obj:getSprite() and obj:getSprite():getProperties() and
          (obj:getSprite():getProperties():Is("SolidTrans") or
           obj:getSprite():getProperties():Is("Solid") or
           obj:getSprite():getProperties():Is("WallN") or
           obj:getSprite():getProperties():Is("WallW")) then
            return false
        end
    end

    local adjacentOpenCount = 0
    local adjacentSquares = {
        getCell():getGridSquare(x+1, y, z),
        getCell():getGridSquare(x-1, y, z),
        getCell():getGridSquare(x, y+1, z),
        getCell():getGridSquare(x, y-1, z)
    }

    for _, adjSquare in ipairs(adjacentSquares) do
        if adjSquare and adjSquare:isFreeOrMidair(false) and not adjSquare:isSolid() and not adjSquare:isSolidTrans() then
            local clear = true
            for i = 0, adjSquare:getObjects():size() - 1 do
                local obj = adjSquare:getObjects():get(i)
                if obj and obj:getSprite() and obj:getSprite():getProperties() and
                  (obj:getSprite():getProperties():Is("SolidTrans") or
                   obj:getSprite():getProperties():Is("Solid")) then
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

function BikeSpawner.Container.onLoadGridsquare(square)
    if not BikeSpawner.Container.spawnedSquares then
        BikeSpawner.Container.spawnedSquares = ModData.getOrCreate("Bicycle_SpawnedSquares") or {}
    end
    if not BikeSpawner.Container.spawnedRooms then
        BikeSpawner.Container.spawnedRooms = ModData.getOrCreate("Bicycle_SpawnedRooms") or {}
    end
    if not BikeSpawner.Container.buildingsWithBikes then
        BikeSpawner.Container.buildingsWithBikes = ModData.getOrCreate("Bicycle_BuildingsWithBikes") or {}
    end
    if not BikeSpawner.Container.processedSquares then BikeSpawner.Container.processedSquares = {} end
    if not square then return end
    local squareID = square:getX() .. "," .. square:getY() .. "," .. square:getZ()
    if BikeSpawner.Container.processedSquares[squareID] then return end
    BikeSpawner.Container.processedSquares[squareID] = true

    local room = square:getRoom()
    if not room then return end

    local roomName = room:getName()
    if not roomName then return end

    -- Check if this building already has a bike
    local buildingID = BikeSpawner.Container.getBuildingID(square)
    if buildingID and BikeSpawner.Container.buildingsWithBikes[buildingID] then return end

    if BikeSpawner.Container.checkRelatedRooms(roomName) then return end

    local persistentSquareID = BikeSpawner.Container.getSquareID(square)
    if BikeSpawner.Container.spawnedSquares[persistentSquareID] then return end

    if BikeSpawner.Container.targetRooms[roomName] and
       isValidSpawnLocation(square) then

        local chance = BikeSpawner.Container.getRoomSpawnChance(roomName)
        if chance <= 0 then return end

        if buildingID then
            BikeSpawner.Container.buildingsWithBikes[buildingID] = true
            ModData.add("Bicycle_BuildingsWithBikes", BikeSpawner.Container.buildingsWithBikes)
            ModData.transmit("Bicycle_BuildingsWithBikes")
        end

        local roll = ZombRand(0, 101)

        if getDebug() then
        --    
        end

        if roll <= chance then
            local offsetX = 0.25
            local offsetY = 0.25

            table.insert(BikeSpawner.Container.spawnReserves, {
                square = square,
                roomName = roomName,
                squareID = persistentSquareID,
                buildingID = buildingID,
                processed = false,
                offsetX = offsetX,
                offsetY = offsetY
            })
            BikeSpawner.Container.spawnedRooms[roomName] = true
            ModData.add("Bicycle_SpawnedRooms", BikeSpawner.Container.spawnedRooms)
            ModData.transmit("Bicycle_SpawnedRooms")
        end
    end
end

function BikeSpawner.Container.processSpawnReserves()
    for i = #BikeSpawner.Container.spawnReserves, 1, -1 do
        local reserve = BikeSpawner.Container.spawnReserves[i]

        if reserve.square and isValidSpawnLocation(reserve.square) and not reserve.processed then
            reserve.processed = true

            local item = reserve.square:AddWorldInventoryItem(BikeSpawner.Container.getRandomBicycleType(),
                0.5 + reserve.offsetX,
                0.5 + reserve.offsetY,
                0)

            if item then
                BikeSpawner.Container.spawnedSquares[reserve.squareID] = true
                ModData.add("Bicycle_SpawnedSquares", BikeSpawner.Container.spawnedSquares)
                ModData.transmit("Bicycle_SpawnedSquares")

                table.remove(BikeSpawner.Container.spawnReserves, i)
            end
        end
    end
end

function BikeSpawner.Container.onTick()
    BikeSpawner.Container.tickCounter = BikeSpawner.Container.tickCounter + 1
    if BikeSpawner.Container.tickCounter >= BikeSpawner.Container.checkInterval then
        BikeSpawner.Container.tickCounter = 0
        if #BikeSpawner.Container.spawnReserves > 0 then
            BikeSpawner.Container.processSpawnReserves()
        end
    end
end

function BikeSpawner.Container.OnGameStart()
    if not BikeSpawner then BikeSpawner = {} end
    if not BikeSpawner.Container then BikeSpawner.Container = {} end

    BikeSpawner.Container.spawnedSquares = ModData.getOrCreate("Bicycle_SpawnedSquares") or {}
    BikeSpawner.Container.spawnedRooms = ModData.getOrCreate("Bicycle_SpawnedRooms") or {}
    BikeSpawner.Container.buildingsWithBikes = ModData.getOrCreate("Bicycle_BuildingsWithBikes") or {} -- Load building data
    BikeSpawner.Container.spawnReserves = {}
    BikeSpawner.Container.processedSquares = {}
    BikeSpawner.Container.tickCounter = 0
    BikeSpawner.Container.spawnRateMultiplier = nil

    -- if SandboxVars.Bicycle and not SandboxVars.Bicycle.SpawnBikes then
    --     Events.LoadGridsquare.Remove(BikeSpawner.Container.onLoadGridsquare)
    --     Events.OnTick.Remove(BikeSpawner.Container.onTick)
    --     return
    -- end

    -- print("Bikespawner: Cart spawning system initialized with persistent data")

    Events.LoadGridsquare.Add(BikeSpawner.Container.onLoadGridsquare)
    Events.OnTick.Add(BikeSpawner.Container.onTick)
end

function BikeSpawner.Container.OnSaveGame()
    if BikeSpawner.Container.spawnedSquares then
        ModData.add("Bicycle_SpawnedSquares", BikeSpawner.Container.spawnedSquares)
        ModData.transmit("Bicycle_SpawnedSquares")
    end

    if BikeSpawner.Container.spawnedRooms then
        ModData.add("Bicycle_SpawnedRooms", BikeSpawner.Container.spawnedRooms)
        ModData.transmit("Bicycle_SpawnedRooms")
    end

    if BikeSpawner.Container.buildingsWithBikes then
        ModData.add("Bicycle_BuildingsWithBikes", BikeSpawner.Container.buildingsWithBikes)
        ModData.transmit("Bicycle_BuildingsWithBikes")
    end
end

function BikeSpawner.Container.checkRelatedRooms(roomName)
    local baseRoomChecks = {
        ["gigamartkitchen"] = "gigamart",
        ["departmentstorage"] = "departmentstore",
        ["cornerstorestorage"] = "cornerstore",
        ["grocerystorage"] = "grocery",
    }

    if baseRoomChecks[roomName] and BikeSpawner.Container.spawnedRooms[baseRoomChecks[roomName]] then
        return true
    end

    return false
end

Events.OnServerStarted.Add(BikeSpawner.Container.OnSaveGame)
Events.OnPreMapLoad.Add(BikeSpawner.Container.OnSaveGame)
Events.OnGameStart.Add(BikeSpawner.Container.OnGameStart)
