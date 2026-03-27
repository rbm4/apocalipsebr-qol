-- ERS_DEBUG_PRINT_GUARD
local _ERS_RAW_PRINT = (_G and _G.print) or print
local function ersDebugLogsEnabled()
    if EnergyRouting and EnergyRouting.IsDebugEnabled then
        return EnergyRouting.IsDebugEnabled()
    end
    if EnergyRouting and EnergyRouting.GetConfigValue then
        return EnergyRouting.GetConfigValue("DebugLogs") == true
    end
    local vars = SandboxVars and (SandboxVars.EnergyRoutingSystem or SandboxVars.EnergyRouting) or nil
    return vars and vars.DebugLogs == true
end
local function debugPrint(...)
    if ersDebugLogsEnabled() then
        _ERS_RAW_PRINT(...)
    end
end
local print = debugPrint
require "EnergyRouting/Init"

ERS = ERS or {}
ERS.BuildingPower = ERS.BuildingPower or {}

local BP = ERS.BuildingPower
local DEFAULT_CONTROLLER_VERTICAL_RANGE = 2

EnergyRouting = EnergyRouting or {}
EnergyRouting.BuildingPower = BP

BP._coverageCache = BP._coverageCache or {}
BP.DEBUG = false

print("[SPESS][BuildingPower] ERS_BuildingPower.lua loaded (virtual generator routing)")

local function logBP(msg)
    if BP.DEBUG then
        print("[SPESS][BuildingPower] " .. tostring(msg))
    end
end

local function safeCall(obj, method, ...)
    if obj and obj[method] then
        local ok, result = pcall(obj[method], obj, ...)
        if ok then
            return result
        end
    end
    return nil
end

local function getCoverageRadius()
    local radius = EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("DeviceScanRadius") or nil
    radius = tonumber(radius) or (EnergyRouting and EnergyRouting.CONTROLLER_RADIUS) or 20
    if radius < 1 then
        radius = 1
    end
    return radius
end

local function getControllerVerticalRange()
    local range = EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("ControllerVerticalRange") or nil
    range = tonumber(range)
    if not range or range < 0 then
        range = DEFAULT_CONTROLLER_VERTICAL_RANGE
    end
    return math.floor(math.max(0, range))
end

local function getGeneratorZBounds(centerZ)
    local cell = getCell and getCell() or nil
    local range = getControllerVerticalRange()
    local minZ = math.floor(tonumber(centerZ) or 0) - range
    if minZ < 0 then
        minZ = 0
    end
    local maxZ = math.floor(tonumber(centerZ) or 0) + range
    if cell and cell.getMaxZ then
        local ok, worldMaxZ = pcall(cell.getMaxZ, cell)
        if ok and type(worldMaxZ) == "number" and worldMaxZ >= 0 then
            worldMaxZ = math.floor(worldMaxZ)
            if maxZ > worldMaxZ then
                maxZ = worldMaxZ
            end
        end
    end
    if maxZ < minZ then
        maxZ = minZ
    end
    return minZ, maxZ
end

local function makeSquareKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function getCachedCoverageSquares(edc)
    if not edc or not edc.id then
        return {}
    end

    if type(edc.coverageSquares) == "table" and #edc.coverageSquares > 0 then
        return edc.coverageSquares
    end

    local radius = getCoverageRadius()
    local cacheKey = tostring(edc.id)
    local signature = tostring(edc.x) .. ":" .. tostring(edc.y) .. ":" .. tostring(edc.z) .. ":" .. tostring(radius)
    local cached = BP._coverageCache[cacheKey]
    if cached and cached.signature == signature and cached.squares then
        return cached.squares
    end

    local squares = {}
    for x = edc.x - radius, edc.x + radius do
        for y = edc.y - radius, edc.y + radius do
            table.insert(squares, { x = x, y = y, z = edc.z })
        end
    end

    BP._coverageCache[cacheKey] = {
        signature = signature,
        squares = squares,
    }
    return squares
end

function BP.getBuildingsForController(edc)
    local buildings = {}
    if not edc then
        return buildings
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return buildings
    end

    local seenSquares = {}
    local coverageSquares = getCachedCoverageSquares(edc)
    for _, sqData in ipairs(coverageSquares) do
        local key = makeSquareKey(sqData.x, sqData.y, sqData.z)
        if not seenSquares[key] then
            seenSquares[key] = true
            local sq = cell:getGridSquare(sqData.x, sqData.y, sqData.z)
            if sq then
                local building = safeCall(sq, "getBuilding")
                if not building then
                    local room = safeCall(sq, "getRoom")
                    building = room and safeCall(room, "getBuilding") or nil
                end
                if building then
                    local bId = safeCall(building, "getID")
                    if bId == nil then
                        bId = tostring(building)
                    end
                    buildings[bId] = building
                end
            end
        end
    end

    local count = 0
    for _ in pairs(buildings) do
        count = count + 1
    end
    logBP("getBuildingsForController id=" .. tostring(edc and edc.id)
        .. " coverageSquares=" .. tostring(#coverageSquares)
        .. " buildings=" .. tostring(count))
    return buildings
end

local function applyCoverageSquaresDirect(edc, hasPower)
    if not edc then
        return
    end
    local cell = getCell and getCell() or nil
    if not cell then
        return
    end
    local seenSquares = {}
    for _, sqData in ipairs(getCachedCoverageSquares(edc)) do
        local key = makeSquareKey(sqData.x, sqData.y, sqData.z)
        if not seenSquares[key] then
            seenSquares[key] = true
            local sq = cell:getGridSquare(sqData.x, sqData.y, sqData.z)
            if sq then
                if sq.setHaveElectricity then
                    pcall(sq.setHaveElectricity, sq, hasPower)
                end
                if sq.setHasElectricity then
                    pcall(sq.setHasElectricity, sq, hasPower)
                end
                if sq.setElectricity then
                    pcall(sq.setElectricity, sq, hasPower)
                end
            end
        end
    end
end

local CHUNK_SIZE = 8

local function makeChunkKeyFromSquare(x, y)
    local wx = math.floor((tonumber(x) or 0) / CHUNK_SIZE)
    local wy = math.floor((tonumber(y) or 0) / CHUNK_SIZE)
    return tostring(wx) .. ":" .. tostring(wy)
end

local function hasAnyEntry(T)
    if not T then
        return false
    end
    for _ in pairs(T) do
        return true
    end
    return false
end

local function getCoverageChunks(edc)
    local chunks = {}
    if not edc then
        return chunks
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return chunks
    end

    local seen = {}
    for _, sqData in ipairs(getCachedCoverageSquares(edc)) do
        local wx = math.floor((tonumber(sqData.x) or 0) / CHUNK_SIZE)
        local wy = math.floor((tonumber(sqData.y) or 0) / CHUNK_SIZE)
        local key = tostring(wx) .. ":" .. tostring(wy)
        if not seen[key] then
            seen[key] = true
            local chunk = nil
            if cell.getChunk then
                chunk = safeCall(cell, "getChunk", wx, wy)
            end
            if not chunk then
                local sx = tonumber(sqData.x)
                local sy = tonumber(sqData.y)
                local sz = tonumber(sqData.z)
                if sx then sx = math.floor(sx) end
                if sy then sy = math.floor(sy) end
                if sz then sz = math.floor(sz) end
                local sq = nil
                if sx and sy and sz and cell.getGridSquare then
                    sq = safeCall(cell, "getGridSquare", sx, sy, sz)
                end
                chunk = sq and safeCall(sq, "getChunk") or nil
            end
            if chunk then
                chunks[key] = chunk
            end
        end
    end

    if not hasAnyEntry(chunks) and edc.x and edc.y and edc.z then
        local ex = tonumber(edc.x)
        local ey = tonumber(edc.y)
        local ez = tonumber(edc.z)
        if ex then ex = math.floor(ex) end
        if ey then ey = math.floor(ey) end
        if ez then ez = math.floor(ez) end
        local sq = nil
        if ex and ey and ez and cell.getGridSquare then
            sq = safeCall(cell, "getGridSquare", ex, ey, ez)
        end
        local chunk = sq and safeCall(sq, "getChunk") or nil
        if chunk then
            local key = makeChunkKeyFromSquare(ex, ey)
            chunks[key] = chunk
        end
    end

    return chunks
end

local function applyVirtualGeneratorState(edc, hasPower)
    if not edc then
        return 0
    end

    local gx = tonumber(edc.x)
    local gy = tonumber(edc.y)
    local gz = tonumber(edc.z)
    if gx then
        gx = math.floor(gx)
    end
    if gy then
        gy = math.floor(gy)
    end
    if gz then
        gz = math.floor(gz)
    end
    if not gx or not gy or not gz then
        return 0
    end

    local minZ, maxZ = getGeneratorZBounds(gz)
    local prevMinZ = tonumber(edc._ersVirtualGeneratorMinZ)
    local prevMaxZ = tonumber(edc._ersVirtualGeneratorMaxZ)
    if prevMinZ then
        prevMinZ = math.floor(prevMinZ)
    end
    if prevMaxZ then
        prevMaxZ = math.floor(prevMaxZ)
    end

    local chunks = getCoverageChunks(edc)
    local count = 0
    if hasPower and prevMinZ and prevMaxZ and (prevMinZ ~= minZ or prevMaxZ ~= maxZ) then
        for _, chunk in pairs(chunks) do
            if chunk.removeGeneratorPos then
                for rz = prevMinZ, prevMaxZ do
                    pcall(chunk.removeGeneratorPos, chunk, gx, gy, rz)
                    count = count + 1
                end
            end
        end
    end

    local removeMinZ = minZ
    local removeMaxZ = maxZ
    if (not hasPower) and prevMinZ and prevMaxZ then
        removeMinZ = prevMinZ
        removeMaxZ = prevMaxZ
    end

    for _, chunk in pairs(chunks) do
        if hasPower and chunk.addGeneratorPos then
            for z = minZ, maxZ do
                pcall(chunk.addGeneratorPos, chunk, gx, gy, z)
                count = count + 1
            end
        elseif not hasPower and chunk.removeGeneratorPos then
            for z = removeMinZ, removeMaxZ do
                pcall(chunk.removeGeneratorPos, chunk, gx, gy, z)
                count = count + 1
            end
        end
    end

    edc._ersVirtualGenerator = hasPower and true or false
    edc._ersVirtualGeneratorChunkCount = count
    if hasPower then
        edc._ersVirtualGeneratorMinZ = minZ
        edc._ersVirtualGeneratorMaxZ = maxZ
    else
        edc._ersVirtualGeneratorMinZ = nil
        edc._ersVirtualGeneratorMaxZ = nil
    end
    if hasPower and count <= 0 then
        local signature = tostring(gx) .. ":" .. tostring(gy) .. ":" .. tostring(minZ) .. "-" .. tostring(maxZ)
        if edc._ersNoChunkWarn ~= signature then
            edc._ersNoChunkWarn = signature
            print("[SPESS][BuildingPower] WARN virtual generator has zero chunks id="
                .. tostring(edc.id)
                .. " pos=" .. signature)
        end
    else
        edc._ersNoChunkWarn = nil
    end
    return count
end

function BP.applyDebugGeneratorBus(edc, hasPower, forceApply)
    if not edc then
        return 0
    end

    local desired = hasPower and true or false
    local previous = edc._ersDebugGeneratorBusState
    if previous == desired and not forceApply then
        return tonumber(edc._ersVirtualGeneratorChunkCount) or 0
    end

    local chunksApplied = applyVirtualGeneratorState(edc, desired)
    edc._ersDebugGeneratorBusState = desired
    logBP("applyDebugGeneratorBus id=" .. tostring(edc.id)
        .. " desired=" .. tostring(desired)
        .. " previous=" .. tostring(previous)
        .. " force=" .. tostring(forceApply)
        .. " chunksApplied=" .. tostring(chunksApplied))
    return chunksApplied
end

function BP.applyPowerState(edc, hasPower, forceApply)
    if not edc then
        return
    end

    local totalMode = true
    if EnergyRouting and EnergyRouting.GetConfigValue then
        local configured = EnergyRouting.GetConfigValue("TotalBuildingPowerMode")
        if configured ~= nil then
            totalMode = (configured == true)
        end
    end

    -- Total mode: allow virtual generator bus when ERS has power.
    -- Non-total mode: keep bus disabled (object-level routing only).
    local desired = totalMode and (hasPower and true or false) or false
    local previous = edc._ersBuildingPowerState
    if previous == desired and not forceApply then
        return
    end

    local chunksApplied = applyVirtualGeneratorState(edc, desired)
    edc._ersBuildingPowerState = desired
    logBP("applyPowerState id=" .. tostring(edc.id)
        .. " requested=" .. tostring(hasPower and true or false)
        .. " desired=" .. tostring(desired)
        .. " previous=" .. tostring(previous)
        .. " force=" .. tostring(forceApply)
        .. " chunksApplied=" .. tostring(chunksApplied))
end

function BP.resolvePowerSource(edc)
    if not edc then
        return "Vanilla"
    end
    if edc.outputEnabled == false then
        return "Off"
    end
    local hasEnoughEnergy = ((edc.authorizedPowerWatts or 0) > 0)
        or ((edc.production or 0) > 0)
        or ((edc.storage or 0) > 0)
        or ((edc.energyAvailable or 0) > 0)
        or ((edc.poweredConsumerCount or 0) > 0)
        or ((edc.consumptionTotal or 0) > 0)
    if hasEnoughEnergy then
        return "ERS"
    end
    return "Vanilla"
end

function BP.applyControllerDecision(edc)
    local source = BP.resolvePowerSource(edc)
    if source == "ERS" then
        BP.applyPowerState(edc, true, false)
    elseif source == "Off" then
        BP.applyPowerState(edc, false, true)
    else
        -- Release ERS hold once; vanilla (grid/generator) can take over.
        if edc and edc._ersBuildingPowerState == true then
            BP.applyPowerState(edc, false, true)
        end
    end
    logBP("applyControllerDecision id=" .. tostring(edc and edc.id)
        .. " source=" .. tostring(source)
        .. " outputEnabled=" .. tostring(edc and edc.outputEnabled)
        .. " energyAvailable=" .. tostring(edc and edc.energyAvailable)
        .. " production=" .. tostring(edc and edc.production)
        .. " storage=" .. tostring(edc and edc.storage))
    return source
end

