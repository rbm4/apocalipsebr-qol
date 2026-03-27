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
require "EnergyNetwork"
require "EnergyRouting/Weather"

print("[SPESS][Server] EnergyController_Server.lua loaded")

EnergyController = EnergyController or {}
EnergyController.Server = EnergyController.Server or {}
local ECS = EnergyController.Server

local function logEnergy(message)
    local debugEnabled = EnergyRouting and EnergyRouting.IsDebugEnabled and EnergyRouting.IsDebugEnabled() == true
    if not debugEnabled then
        return
    end
    print("[SPESS][EnergyTick] " .. tostring(message))
end

local OFF_IDLE_CONTROLLER_TICK_INTERVAL_MINUTES = 30

local ensureEnergyPanelMeta
local ensurePanelMeta
local ensureBatteryMeta
local ensureWindMeta
local ensureWindBatteryMeta
local ensureHydroMeta
local getPanelId
local getBatteryId
local getWindId
local getWindBatteryId
local getHydroId
local cacheControllerById
local getControllerById
local isControllerPrototypeObject

local PENDING_LINK_REMOVE_CONFIRM_MS = 5000

local function safeCall(obj, method, ...)
    if not obj or not method then
        return nil
    end
    local fn = nil
    local ok, result = pcall(function()
        return obj[method]
    end)
    if ok then
        fn = result
    end
    if type(fn) ~= "function" then
        return nil
    end
    local okCall, resultCall = pcall(fn, obj, ...)
    if okCall then
        return resultCall
    end
    return nil
end

local function getObjectModData(obj)
    if not obj then
        return nil
    end
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item and item.getModData then
        return item:getModData()
    end
    return safeCall(obj, "getModData")
end

local function transmitObjectModData(obj)
    if not obj then
        return
    end
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item and item.transmitModData then
        item:transmitModData()
        return
    end
    if obj.transmitModData then
        obj:transmitModData()
    end
end

local function hasItemByFullType(container, fullType)
    if not container then
        return false
    end
    local items = container:getItems()
    if not items then
        return false
    end
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and item.getFullType and item:getFullType() == fullType then
            return true
        end
        if item and item.getInventory then
            local sub = item:getInventory()
            if sub and hasItemByFullType(sub, fullType) then
                return true
            end
        end
    end
    return false
end

local CABLE_FULL_TYPES = {
    "EnergyRouting.WireTransferEnergy",
    "WireTransferEnergy",
    "EnergyRouting.EnergyTransferCable",
    "EnergyTransferCable",
}

local REPAIR_WIRE_TYPES = {
    "Base.ElectricWire",
    "ElectricWire",
}

local REPAIR_SOLAR_SPARE_TYPES = {
    "EnergyRouting.SolarPanel_Individual",
    "SolarPanel_Individual",
}

local REPAIR_WIND_MOTOR_TYPES = {
    "EnergyRouting.WindTurbineMotor",
    "WindTurbineMotor",
}

local REPAIR_HYDRO_HELICE_TYPES = {
    "EnergyRouting.TurbineHelice",
    "TurbineHelice",
}

local REPAIR_ELECTRONICS_TYPES = {
    "Base.ElectronicsScrap",
    "ElectronicsScrap",
}

local REPAIR_SCREWDRIVER_TYPES = {
    "Base.Screwdriver",
    "Screwdriver",
}

local REPAIR_PLIERS_TYPES = {
    "Base.Pliers",
    "Pliers",
}

local REPAIR_PIPE_WRENCH_TYPES = {
    "Base.PipeWrench",
    "PipeWrench",
}

local function hasItemByPredicate(container, predicate)
    if not container or not predicate then
        return false
    end
    local items = container:getItems()
    if not items then
        return false
    end
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and predicate(item) then
            return true
        end
        if item and item.getInventory then
            local sub = item:getInventory()
            if sub and hasItemByPredicate(sub, predicate) then
                return true
            end
        end
    end
    return false
end

local function removeItemByFullType(container, fullType)
    if not container then
        return false
    end
    local items = container:getItems()
    if not items then
        return false
    end
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and item.getFullType and item:getFullType() == fullType then
            if container.DoRemoveItem then
                container:DoRemoveItem(item)
            else
                container:Remove(item)
            end
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(container, item)
            end
            if container.setDrawDirty then
                container:setDrawDirty(true)
            end
            return true
        end
        if item and item.getInventory then
            local sub = item:getInventory()
            if sub and removeItemByFullType(sub, fullType) then
                return true
            end
        end
    end
    return false
end

local function removeItemByPredicate(container, predicate)
    if not container or not predicate then
        return false
    end
    local items = container:getItems()
    if not items then
        return false
    end
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and predicate(item) then
            if container.DoRemoveItem then
                container:DoRemoveItem(item)
            else
                container:Remove(item)
            end
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(container, item)
            end
            if container.setDrawDirty then
                container:setDrawDirty(true)
            end
            return true
        end
        if item and item.getInventory then
            local sub = item:getInventory()
            if sub and removeItemByPredicate(sub, predicate) then
                return true
            end
        end
    end
    return false
end

local function playerHasCable(player)
    if not player or not player.getInventory then
        return false
    end
    local inventory = player:getInventory()
    if not inventory then
        return false
    end
    for _, fullType in ipairs(CABLE_FULL_TYPES) do
        if inventory:contains(fullType) or hasItemByFullType(inventory, fullType) then
            return true
        end
    end
    return hasItemByPredicate(inventory, function(item)
        local itemType = item and item.getType and item:getType() or nil
        local display = item and item.getDisplayName and item:getDisplayName() or nil
        return itemType == "WireTransferEnergy"
            or itemType == "EnergyTransferCable"
            or display == "Energy Transfer Cable"
    end)
end

local function consumeCable(player)
    if not player or not player.getInventory then
        return false
    end
    local inventory = player:getInventory()
    if not inventory then
        return false
    end
    for _, fullType in ipairs(CABLE_FULL_TYPES) do
        if removeItemByFullType(inventory, fullType) then
            return true
        end
    end
    return removeItemByPredicate(inventory, function(item)
        local itemType = item and item.getType and item:getType() or nil
        local display = item and item.getDisplayName and item:getDisplayName() or nil
        return itemType == "WireTransferEnergy"
            or itemType == "EnergyTransferCable"
            or display == "Energy Transfer Cable"
    end)
end

local function returnCable(player)
    if not player or not player.getInventory then
        return false
    end
    local inventory = player:getInventory()
    if not inventory then
        return false
    end
    local item = inventory:AddItem("EnergyRouting.WireTransferEnergy")
    if item and sendAddItemToContainer then
        sendAddItemToContainer(inventory, item)
    end
    if inventory.setDrawDirty then
        inventory:setDrawDirty(true)
    end
    return item ~= nil
end

local function sendLinkSync(player, kind, objectId, controllerId, connected, sourceControllerId)
    if not sendServerCommand then
        return
    end
    if not kind or not objectId then
        return
    end
    local payload = {
        kind = kind,
        objectId = objectId,
        controllerId = controllerId,
        connected = connected and true or false,
        sourceControllerId = sourceControllerId,
    }

    local sent = 0
    if getOnlinePlayers then
        local online = getOnlinePlayers()
        if online and online.size then
            for i = 0, online:size() - 1 do
                local target = online:get(i)
                if target then
                    sendServerCommand(target, "EnergyRouting", "LinkSync", payload)
                    sent = sent + 1
                end
            end
        end
    end

    if sent == 0 and player then
        sendServerCommand(player, "EnergyRouting", "LinkSync", payload)
    end
end

local function findNearestPlayerToSquare(square, maxDistance)
    if not square then
        return nil
    end
    local bestPlayer = nil
    local bestDist = nil
    local maxDist = tonumber(maxDistance) or 6

    local function considerPlayer(player)
        if not player or player:isDead() then
            return
        end
        local psq = player.getSquare and player:getSquare() or nil
        if not psq then
            return
        end
        local dist = psq:DistToProper(square)
        if dist <= maxDist and (bestDist == nil or dist < bestDist) then
            bestDist = dist
            bestPlayer = player
        end
    end

    if getOnlinePlayers then
        local online = getOnlinePlayers()
        if online and online.size then
            for i = 0, online:size() - 1 do
                considerPlayer(online:get(i))
            end
        end
    end

    if not bestPlayer and getNumActivePlayers and getSpecificPlayer then
        local count = tonumber(getNumActivePlayers()) or 0
        for i = 0, count - 1 do
            considerPlayer(getSpecificPlayer(i))
        end
    end

    return bestPlayer
end

local function dropCableOnSquare(square, amount)
    if not square then
        return 0
    end
    local remaining = math.max(0, math.floor(tonumber(amount) or 0))
    local dropped = 0
    while remaining > 0 do
        local ok = false
        if square.AddWorldInventoryItem then
            local success = pcall(function()
                square:AddWorldInventoryItem("EnergyRouting.WireTransferEnergy", 0.5, 0.5, 0.0)
            end)
            ok = success == true
        end
        if (not ok) and square.addWorldInventoryItem then
            local success = pcall(function()
                square:addWorldInventoryItem("EnergyRouting.WireTransferEnergy", 0.5, 0.5, 0.0)
            end)
            ok = success == true
        end
        if not ok then
            break
        end
        dropped = dropped + 1
        remaining = remaining - 1
    end
    return dropped
end

local function findAnyAlivePlayer()
    local function isUsable(player)
        return player and (not player.isDead or not player:isDead())
    end

    if getOnlinePlayers then
        local online = getOnlinePlayers()
        if online and online.size then
            for i = 0, online:size() - 1 do
                local p = online:get(i)
                if isUsable(p) then
                    return p
                end
            end
        end
    end

    if getNumActivePlayers and getSpecificPlayer then
        local count = tonumber(getNumActivePlayers()) or 0
        for i = 0, count - 1 do
            local p = getSpecificPlayer(i)
            if isUsable(p) then
                return p
            end
        end
    end

    return nil
end

local function returnCableForUnlink(square, amount)
    local needed = math.max(0, math.floor(tonumber(amount) or 0))
    if needed <= 0 then
        return 0
    end
    local granted = 0
    local player = square and findNearestPlayerToSquare(square, 8) or nil
    if not player then
        player = findAnyAlivePlayer()
    end
    while granted < needed do
        if player and returnCable(player) then
            granted = granted + 1
        else
            break
        end
    end
    if granted < needed and square then
        granted = granted + dropCableOnSquare(square, needed - granted)
    end
    return granted
end

local function countItemsByPredicate(container, predicate)
    if not container or not predicate then
        return 0
    end
    local items = container:getItems()
    if not items then
        return 0
    end
    local total = 0
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and predicate(item) then
            total = total + 1
        end
        if item and item.getInventory then
            local sub = item:getInventory()
            if sub then
                total = total + countItemsByPredicate(sub, predicate)
            end
        end
    end
    return total
end

local function itemMatchesToken(item, token)
    if not item or not token then
        return false
    end
    local fullType = item.getFullType and item:getFullType() or nil
    local itemType = item.getType and item:getType() or nil
    return fullType == token or itemType == token
end

local function inventoryCountByToken(inventory, token)
    return countItemsByPredicate(inventory, function(item)
        return itemMatchesToken(item, token)
    end)
end

local function inventoryCountAny(inventory, tokens)
    if not inventory or not tokens then
        return 0
    end
    local best = 0
    for _, token in ipairs(tokens) do
        local count = inventoryCountByToken(inventory, token)
        if count > best then
            best = count
        end
    end
    return best
end

local function inventoryHasAny(inventory, tokens)
    return inventoryCountAny(inventory, tokens) > 0
end

local function removeOneByToken(inventory, token)
    if not inventory or not token then
        return false
    end
    if removeItemByFullType(inventory, token) then
        return true
    end
    return removeItemByPredicate(inventory, function(item)
        return itemMatchesToken(item, token)
    end)
end

local function removeCountByAnyToken(inventory, tokens, amount)
    if not inventory or not tokens then
        return false
    end
    local needed = math.max(0, math.floor(tonumber(amount) or 0))
    for _ = 1, needed do
        local removed = false
        for _, token in ipairs(tokens) do
            if removeOneByToken(inventory, token) then
                removed = true
                break
            end
        end
        if not removed then
            return false
        end
    end
    return true
end

local function findItemByPredicate(container, predicate)
    if not container or not predicate then
        return nil
    end
    local items = container:getItems()
    if not items then
        return nil
    end
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and predicate(item) then
            return item
        end
        if item and item.getInventory then
            local sub = item:getInventory()
            local found = sub and findItemByPredicate(sub, predicate) or nil
            if found then
                return found
            end
        end
    end
    return nil
end

local function findItemByAnyToken(inventory, tokens)
    if not inventory or not tokens then
        return nil
    end
    for _, token in ipairs(tokens) do
        local item = findItemByPredicate(inventory, function(candidate)
            return itemMatchesToken(candidate, token)
        end)
        if item then
            return item
        end
    end
    return nil
end

local function applyItemWearOnePoint(item)
    if not item then
        return false
    end
    if not (item.getCondition and item.setCondition) then
        return false
    end
    local current = tonumber(item:getCondition()) or 0
    if current <= 0 then
        return false
    end
    item:setCondition(math.max(0, current - 1))
    return true
end

local function applyRepairToolWear(player, producerType)
    if not player or not player.getInventory then
        return
    end
    local inventory = player:getInventory()
    if not inventory then
        return
    end
    local screwdriver = findItemByAnyToken(inventory, REPAIR_SCREWDRIVER_TYPES)
    local secondaryTool = nil
    if producerType == "hydro" then
        secondaryTool = findItemByAnyToken(inventory, REPAIR_PIPE_WRENCH_TYPES)
    else
        secondaryTool = findItemByAnyToken(inventory, REPAIR_PLIERS_TYPES)
    end
    applyItemWearOnePoint(screwdriver)
    applyItemWearOnePoint(secondaryTool)
end

local function playerCanRepairProducer(player, producerType)
    if not player or not player.getInventory or not player.getPerkLevel then
        return false
    end
    local isHydro = producerType == "hydro"
    if isHydro then
        local inventory = player:getInventory()
        if not inventory then
            return false
        end
        if not inventoryHasAny(inventory, REPAIR_SCREWDRIVER_TYPES) then
            return false
        end
        if not inventoryHasAny(inventory, REPAIR_PIPE_WRENCH_TYPES) then
            return false
        end
        if inventoryCountAny(inventory, REPAIR_HYDRO_HELICE_TYPES) < 1 then
            return false
        end
        if inventoryCountAny(inventory, REPAIR_WIRE_TYPES) < 2 then
            return false
        end
        if inventoryCountAny(inventory, REPAIR_ELECTRONICS_TYPES) < 4 then
            return false
        end
        return true
    end
    if player:getPerkLevel(Perks.Electricity) < 6 then
        return false
    end
    local inventory = player:getInventory()
    if not inventory then
        return false
    end
    if not inventoryHasAny(inventory, REPAIR_SCREWDRIVER_TYPES) then
        return false
    end
    if not inventoryHasAny(inventory, REPAIR_PLIERS_TYPES) then
        return false
    end
    local isWind = producerType == "wind"
    if isWind then
        if inventoryCountAny(inventory, REPAIR_WIRE_TYPES) < 4 then
            return false
        end
        if inventoryCountAny(inventory, REPAIR_ELECTRONICS_TYPES) < 6 then
            return false
        end
        if inventoryCountAny(inventory, REPAIR_WIND_MOTOR_TYPES) < 2 then
            return false
        end
    else
        if inventoryCountAny(inventory, REPAIR_WIRE_TYPES) < 2 then
            return false
        end
        if inventoryCountAny(inventory, REPAIR_SOLAR_SPARE_TYPES) < 4 then
            return false
        end
    end
    return true
end

local function consumeRepairProducerMaterials(player, producerType)
    if not player or not player.getInventory then
        return false
    end
    local inventory = player:getInventory()
    if not inventory then
        return false
    end
    local isHydro = producerType == "hydro"
    if isHydro then
        if not removeCountByAnyToken(inventory, REPAIR_HYDRO_HELICE_TYPES, 1) then
            return false
        end
        if not removeCountByAnyToken(inventory, REPAIR_WIRE_TYPES, 2) then
            return false
        end
        if not removeCountByAnyToken(inventory, REPAIR_ELECTRONICS_TYPES, 4) then
            return false
        end
        applyRepairToolWear(player, producerType)
        return true
    end
    local isWind = producerType == "wind"
    if isWind then
        if not removeCountByAnyToken(inventory, REPAIR_WIRE_TYPES, 4) then
            return false
        end
        if not removeCountByAnyToken(inventory, REPAIR_ELECTRONICS_TYPES, 6) then
            return false
        end
        if not removeCountByAnyToken(inventory, REPAIR_WIND_MOTOR_TYPES, 2) then
            return false
        end
    else
        if not removeCountByAnyToken(inventory, REPAIR_WIRE_TYPES, 2) then
            return false
        end
        if not removeCountByAnyToken(inventory, REPAIR_SOLAR_SPARE_TYPES, 4) then
            return false
        end
    end
    applyRepairToolWear(player, producerType)
    return true
end

local function getSquare(x, y, z)
    local cell = getCell()
    if not cell then
        return nil
    end
    return cell:getGridSquare(x, y, z)
end

local function getSquareFromObj(obj)
    return safeCall(obj, "getSquare")
end

local function getWorldMinutes()
    local gt = getGameTime and getGameTime() or nil
    if not gt or not gt.getWorldAgeHours then
        return 0
    end
    return math.floor(gt:getWorldAgeHours() * 60)
end

local function getWorldTimestampMs()
    local gt = getGameTime and getGameTime() or nil
    if not gt or not gt.getWorldAgeHours then
        return 0
    end
    return math.floor((gt:getWorldAgeHours() or 0) * 3600000)
end

local TRANSIENT_REMOVE_PLAYER_DISTANCE = 8

local function shouldPreserveLinksOnObjectRemoved(obj)
    if not obj then
        return false
    end

    local isEnergyObject = (ECS.IsControllerObject and ECS.IsControllerObject(obj))
        or (ECS.IsWorldControllerObject and ECS.IsWorldControllerObject(obj))
        or (isControllerPrototypeObject and isControllerPrototypeObject(obj))
        or (ECS.IsPanelObject and ECS.IsPanelObject(obj))
        or (ECS.IsBatteryObject and ECS.IsBatteryObject(obj))
        or (ECS.IsWindObject and ECS.IsWindObject(obj))
        or (ECS.IsHydroObject and ECS.IsHydroObject(obj))
        or (ECS.IsWindBatteryObject and ECS.IsWindBatteryObject(obj))
    if not isEnergyObject then
        return false
    end

    local square = getSquareFromObj(obj)
    if not square then
        return false
    end

    if findNearestPlayerToSquare(square, TRANSIENT_REMOVE_PLAYER_DISTANCE) then
        return false
    end

    return true
end

local function getWorldDayNumber()
    local gt = getGameTime and getGameTime() or nil
    if not gt then
        return 0
    end
    local days = nil

    if gt.getWorldAgeDays then
        local ok, value = pcall(gt.getWorldAgeDays, gt)
        if ok then
            days = tonumber(value)
        end
    end

    if (not days) and gt.getWorldAgeHours then
        local ok, value = pcall(gt.getWorldAgeHours, gt)
        if ok then
            local hours = tonumber(value)
            if hours then
                days = hours / 24
            end
        end
    end

    if not days and gt.getNightsSurvived then
        local ok, value = pcall(gt.getNightsSurvived, gt)
        if ok then
            days = tonumber(value)
        end
    end

    return math.floor(days or 0)
end

local function withinRadius(squareA, squareB, radius)
    if not squareA or not squareB then
        return false
    end
    if squareA:getZ() ~= squareB:getZ() then
        return false
    end
    local dx = squareA:getX() - squareB:getX()
    local dy = squareA:getY() - squareB:getY()
    return (dx * dx + dy * dy) <= (radius * radius)
end

local function getItemFullType(obj)
    if not obj then
        return nil
    end
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item and item.getFullType then
        return item:getFullType()
    end
    if obj.getFullType then
        return obj:getFullType()
    end
    return nil
end

local function hasWorldItemBacking(obj)
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    return item ~= nil
end

local function getSpriteName(obj)
    local sprite = safeCall(obj, "getSprite")
    if sprite and sprite.getName then
        return sprite:getName()
    end
    return nil
end

local function getObjectName(obj)
    if not obj then
        return nil
    end
    if obj.getName then
        local name = obj:getName()
        if name then
            return name
        end
    end
    if obj.getObjectName then
        local name = obj:getObjectName()
        if name then
            return name
        end
    end
    return nil
end

local function getPanelBonus(obj)
    local fullType = getItemFullType(obj)
    if not EnergyNetwork or not EnergyNetwork.GetConfigValue then
        return 0
    end
    if fullType == "EnergyRouting.SolarPanelHorizontal" or fullType == "SolarPanelHorizontal" then
        return EnergyNetwork.GetConfigValue("PanelBonusH")
    end
    return EnergyNetwork.GetConfigValue("PanelBonusV")
end

local function getPanelBaseProduction(obj)
    local fullType = getItemFullType(obj)
    local horizontalBase = (EnergyRouting and EnergyRouting.SOLAR_HORIZONTAL_BASE_W) or 220
    local verticalBase = (EnergyRouting and EnergyRouting.SOLAR_VERTICAL_BASE_W)
        or (EnergyRouting and EnergyRouting.SOLAR_BASE_W)
        or 330
    if fullType == "EnergyRouting.SolarPanelHorizontal"
        or fullType == "SolarPanelHorizontal"
        or (type(fullType) == "string" and string.find(fullType, "SolarPanelHorizontal", 1, true)) then
        return horizontalBase
    end
    return verticalBase
end

local function clamp01(value, fallback)
    local n = tonumber(value)
    if n == nil then
        n = tonumber(fallback) or 0
    end
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function randomFloat(minValue, maxValue)
    local minN = tonumber(minValue) or 0
    local maxN = tonumber(maxValue) or minN
    if maxN < minN then
        minN, maxN = maxN, minN
    end
    if ZombRandFloat then
        return ZombRandFloat(minN, maxN)
    end
    if maxN == minN then
        return minN
    end
    return minN + (math.random() * (maxN - minN))
end

local function getPanelQualityRange(obj)
    local configured = tonumber(getPanelBonus(obj)) or 0
    if configured >= 0.30 then
        return 0.25, 0.35
    end
    return 0.10, 0.25
end

local PRODUCER_CRITICAL_THRESHOLD = 0.30
local PRODUCER_OFFLINE_THRESHOLD = 0.20
local PRODUCER_CRITICAL_MULT = 0.50
local SOLAR_DAILY_DECAY = 0.0005
local SOLAR_STORM_DECAY = 0.0010
local WIND_DAILY_DECAY = 0.0008
local PRODUCER_REPAIR_STEP = 0.25

local function getWearReductionFactor(degradation)
    local d = clamp01(degradation, 1.0)
    if d < PRODUCER_OFFLINE_THRESHOLD then
        return 0, "offline"
    end
    if d < PRODUCER_CRITICAL_THRESHOLD then
        -- Keep device barely useful in critical band before going fully offline.
        return clamp01(d * PRODUCER_CRITICAL_MULT, 0), "critical"
    end
    return d, "normal"
end

local function ensureProductionMeta(obj, defaultDegradation)
    local md = getObjectModData(obj)
    if not md then
        return nil, nil, false
    end

    local created = false
    md.production = md.production or {}
    local production = md.production

    if production.degradation == nil then
        production.degradation = clamp01(defaultDegradation or 1.0, 1.0)
        created = true
    else
        production.degradation = clamp01(production.degradation, 1.0)
    end

    local today = getWorldDayNumber()
    if production.lastUpdateDay == nil then
        production.lastUpdateDay = today
        created = true
    else
        production.lastUpdateDay = math.floor(tonumber(production.lastUpdateDay) or today)
    end

    if production.hoursUsed == nil then
        production.hoursUsed = 0
        created = true
    else
        production.hoursUsed = math.max(0, tonumber(production.hoursUsed) or 0)
    end

    return md, production, created
end

local function applySolarDailyDegradation(obj)
    local md, production, created = ensureProductionMeta(obj, 1.0)
    if not md or not production then
        return 1.0
    end

    local changed = created
    md.solar = md.solar or {}
    local solar = md.solar
    if solar.degradation ~= nil and production.degradation >= 0.9999 then
        production.degradation = clamp01(solar.degradation, production.degradation)
        changed = true
    end

    local today = getWorldDayNumber()
    local last = math.floor(tonumber(production.lastUpdateDay) or today)
    if today > last then
        local deltaDays = today - last
        local decay = deltaDays * SOLAR_DAILY_DECAY
        local weather = EnergyRouting and EnergyRouting.Weather and EnergyRouting.Weather.GetWeatherSnapshot
            and EnergyRouting.Weather.GetWeatherSnapshot() or nil
        local weatherLabel = string.lower(tostring(weather and weather.label or ""))
        if weatherLabel == "storm" then
            decay = decay + (deltaDays * SOLAR_STORM_DECAY)
        end
        local before = production.degradation
        production.degradation = math.max(0, before - decay)
        production.lastUpdateDay = today
        changed = true
        if math.abs((before or 0) - (production.degradation or 0)) > 0.000001 then
            changed = true
        end
    elseif today < last then
        production.lastUpdateDay = today
        changed = true
    end

    local synced = clamp01(production.degradation, 1.0)
    if solar.degradation == nil or math.abs((tonumber(solar.degradation) or 0) - synced) > 0.000001 then
        solar.degradation = synced
        changed = true
    end
    production.degradation = synced

    if changed then
        transmitObjectModData(obj)
    end
    return production.degradation
end

function ECS.RepairProductionObject(obj, amount)
    if not obj then
        return false
    end
    local isPanel = ECS.IsPanelObject and ECS.IsPanelObject(obj)
    local isWind = ECS.IsWindObject and ECS.IsWindObject(obj)
    local isHydro = ECS.IsHydroObject and ECS.IsHydroObject(obj)
    if not isPanel and not isWind and not isHydro then
        return false
    end

    local repair = tonumber(amount) or 0
    if isHydro then
        repair = math.min(0.40, repair)
    else
        repair = math.min(PRODUCER_REPAIR_STEP, repair)
    end
    if repair <= 0 then
        return false
    end

    local md, production = ensureProductionMeta(obj, 1.0)
    if not md then
        return false
    end

    local before = nil
    if isHydro then
        local hydro = ensureHydroMeta and ensureHydroMeta(obj) or nil
        if not hydro then
            return false
        end
        before = math.max(0, math.min(100, tonumber(hydro.condition) or 100))
        hydro.condition = math.max(0, math.min(100, before + (repair * 100)))
        hydro.isActive = hydro.condition > 0
        if production then
            production.degradation = clamp01(hydro.condition / 100, 1.0)
            production.lastUpdateDay = getWorldDayNumber()
        end
    else
        if not production then
            return false
        end
        before = tonumber(production.degradation) or 1.0
        production.degradation = clamp01(before + repair, 1.0)
        production.lastUpdateDay = getWorldDayNumber()
    end

    if md.solar and type(md.solar) == "table" then
        md.solar.degradation = production.degradation
    end
    if md.panel and type(md.panel) == "table" then
        md.panel.degradation = production.degradation
    end
    if md.wind and type(md.wind) == "table" then
        md.wind.condition = production.degradation
    end
    if md.hydro and type(md.hydro) == "table" and production then
        md.hydro.condition = math.max(0, math.min(100, (tonumber(production.degradation) or 1.0) * 100))
        md.hydro.isActive = md.hydro.condition > 0
    end

    local changed = false
    if isHydro then
        local after = md.hydro and tonumber(md.hydro.condition) or before
        changed = math.abs((before or 0) - (after or 0)) > 0.000001
    else
        changed = math.abs((before or 0) - (tonumber(production and production.degradation) or 0)) > 0.000001
    end
    if changed then
        transmitObjectModData(obj)
    end
    return changed
end

if EnergyRouting then
    EnergyRouting.RepairProductionObject = ECS.RepairProductionObject
end

local function applyWindDailyDegradation(obj, windWeather, active)
    local md, production, created = ensureProductionMeta(obj, 1.0)
    if not md or not production then
        return 1.0
    end

    local changed = created
    md.wind = md.wind or {}
    local wind = md.wind
    if wind.condition ~= nil and production.degradation >= 0.9999 then
        production.degradation = clamp01(wind.condition, production.degradation)
        changed = true
    end

    local weather = windWeather
    if not weather then
        weather = EnergyRouting and EnergyRouting.Weather and EnergyRouting.Weather.GetWindSnapshot
            and EnergyRouting.Weather.GetWindSnapshot() or nil
    end
    local weatherLabel = string.lower(tostring(weather and weather.label or ""))
    local weatherSpeed = string.lower(tostring(weather and weather.speed or ""))
    local weatherMult = tonumber(weather and weather.multiplier) or 0
    local band = "low"
    if weatherLabel == "storm" then
        band = "storm"
    elseif weatherSpeed == "high" or weatherMult >= 1.2 then
        band = "high"
    elseif weatherSpeed == "medium" or weatherMult >= 0.7 then
        band = "medium"
    end
    local today = getWorldDayNumber()
    local last = math.floor(tonumber(production.lastUpdateDay) or today)
    if today > last then
        local deltaDays = today - last
        if active then
            local factor = 1
            if band == "high" then
                factor = 2
            elseif band == "storm" then
                factor = 3
            end
            local decay = deltaDays * WIND_DAILY_DECAY * factor
            local before = production.degradation
            production.degradation = math.max(0, before - decay)
            production.hoursUsed = (tonumber(production.hoursUsed) or 0) + (24 * deltaDays)
            if math.abs((before or 0) - (production.degradation or 0)) > 0.000001 then
                changed = true
            end
            changed = true
        end
        production.lastUpdateDay = today
        changed = true
    elseif today < last then
        production.lastUpdateDay = today
        changed = true
    end

    local synced = clamp01(production.degradation, 1.0)
    production.degradation = synced
    if wind.condition == nil or math.abs((tonumber(wind.condition) or 0) - synced) > 0.000001 then
        wind.condition = synced
        changed = true
    end

    if changed then
        transmitObjectModData(obj)
    end
    return production.degradation
end

local function ensureSolarIdentity(obj)
    if not obj then
        return nil, false
    end
    local md = getObjectModData(obj)
    if not md then
        return nil, false
    end

    local created = false
    local hadSolarIdentity = (md.solar ~= nil)
    md.solar = md.solar or {}
    local solar = md.solar
    if not hadSolarIdentity then
        created = true
    end

    if solar.baseEfficiency == nil then
        solar.baseEfficiency = clamp01(randomFloat(0.75, 0.95), 0.85)
        created = true
    else
        solar.baseEfficiency = clamp01(solar.baseEfficiency, 0.85)
    end

    if solar.qualityBonus == nil then
        local legacyBonus = nil
        if md.panel and md.panel.bonus ~= nil then
            legacyBonus = tonumber(md.panel.bonus)
        end
        if legacyBonus and legacyBonus >= 0 then
            solar.qualityBonus = math.max(0, legacyBonus)
        else
            local minBonus, maxBonus = getPanelQualityRange(obj)
            solar.qualityBonus = math.max(0, randomFloat(minBonus, maxBonus))
        end
        created = true
    else
        solar.qualityBonus = math.max(0, tonumber(solar.qualityBonus) or 0)
    end

    local _, production, createdProduction = ensureProductionMeta(obj, 1.0)
    if production then
        if solar.degradation ~= nil and createdProduction then
            production.degradation = clamp01(solar.degradation, production.degradation)
            created = true
        end
        solar.degradation = clamp01(production.degradation, 1.0)
        md.panel = md.panel or {}
        md.panel.degradation = solar.degradation
    elseif solar.degradation == nil then
        solar.degradation = 1.0
        created = true
    else
        solar.degradation = clamp01(solar.degradation, 1.0)
    end

    md.panel = md.panel or {}
    if md.panel.bonus == nil then
        md.panel.bonus = solar.qualityBonus
        created = true
    else
        md.panel.bonus = tonumber(md.panel.bonus) or solar.qualityBonus
    end

    return solar, created
end

local function getPanelQualityBonus(obj)
    local solar = ensureSolarIdentity(obj)
    if solar and solar.qualityBonus ~= nil then
        return math.max(0, tonumber(solar.qualityBonus) or 0)
    end
    return math.max(0, tonumber(getPanelBonus(obj)) or 0)
end

local HARD_MAX_PANELS = 4
local HARD_MAX_WIND_TURBINES = 3
local HARD_MAX_BATTERIES = 2
local HARD_MAX_WIND_BATTERIES = 2
local HARD_MAX_HYDRO_TURBINES = 1
local HYDRO_CONDITION_DECAY_STEP = 0.03
local HYDRO_DAMAGED_EXTRA_DECAY_STEP = 0.03
local HYDRO_WATER_SEARCH_RADIUS = 4

local function getClampedLimit(configValue, hardMax, fallback)
    local limit = tonumber(configValue)
    if not limit then
        limit = fallback
    end
    if limit < 1 then
        return 1
    end
    if limit > hardMax then
        return hardMax
    end
    return math.floor(limit)
end

local function getSolarEfficiency()
    local climate = getClimateManager and getClimateManager() or nil
    if not climate then
        local gt = getGameTime and getGameTime() or nil
        local hour = gt and gt.getHour and gt:getHour() or nil
        if hour and hour >= 6 and hour < 20 then
            return 1.0
        end
        return 0
    end
    local dayLight = climate.getDayLightStrength and climate:getDayLightStrength() or 0
    local isDay = climate.isDay and climate:isDay() or (dayLight and dayLight > 0)
    if not isDay or dayLight <= 0 then
        local gt = getGameTime and getGameTime() or nil
        local hour = gt and gt.getHour and gt:getHour() or nil
        if hour and hour >= 6 and hour < 20 then
            dayLight = 1.0
        else
            return 0
        end
    end
    local cloud = climate.getCloudIntensity and climate:getCloudIntensity() or 0
    local rain = climate.getRainIntensity and climate:getRainIntensity() or 0
    local fog = climate.getFogIntensity and climate:getFogIntensity() or 0
    local efficiency = dayLight
    efficiency = efficiency * (1 - cloud * 0.5)
    efficiency = efficiency * (1 - rain * 0.3)
    efficiency = efficiency * (1 - fog * 0.2)
    if EnergyRouting and EnergyRouting.GetConfigValue then
        efficiency = efficiency * (EnergyRouting.GetConfigValue("SolarWeatherImpact") or 1.0)
    end
    if efficiency < 0 then
        efficiency = 0
    elseif efficiency > 1 then
        efficiency = 1
    end
    return efficiency
end

local function getWindWeatherSnapshot()
    if EnergyRouting and EnergyRouting.Weather and EnergyRouting.Weather.GetWindSnapshot then
        return EnergyRouting.Weather.GetWindSnapshot()
    end
    return { label = "Clear", multiplier = 0.5, speed = "low" }
end

local function normalizeWindSpeedBand(windWeather)
    local label = string.lower(tostring((windWeather and windWeather.label) or ""))
    local speed = string.lower(tostring((windWeather and windWeather.speed) or ""))
    local multiplier = tonumber(windWeather and windWeather.multiplier) or 0

    if label == "storm" then
        return "storm"
    end
    if speed == "high" then
        return "high"
    end
    if speed == "medium" then
        return "medium"
    end
    if speed == "low" then
        return "low"
    end

    if multiplier >= 1.8 then
        return "storm"
    elseif multiplier >= 1.2 then
        return "high"
    elseif multiplier >= 0.7 then
        return "medium"
    end
    return "low"
end

local function getWindEfficiencyRange(band)
    if band == "storm" then
        return 0.70, 1.00
    end
    if band == "high" then
        return 0.50, 0.70
    end
    if band == "medium" then
        return 0.30, 0.50
    end
    return 0.00, 0.30
end

local function stringHash(text)
    local h = 0
    local source = tostring(text or "")
    for i = 1, #source do
        h = (h * 31 + string.byte(source, i)) % 1000003
    end
    return h
end

local function computeWindEfficiencyForCurrentWeather(windObj, windWeather)
    local wind = ensureWindMeta and ensureWindMeta(windObj) or nil
    if not wind then
        return 0
    end

    local band = normalizeWindSpeedBand(windWeather)
    local minEff, maxEff = getWindEfficiencyRange(band)
    if maxEff <= minEff then
        wind.efficiency = math.max(0, math.min(1, minEff))
        return wind.efficiency
    end

    local sq = getSquareFromObj(windObj)
    local x = sq and sq:getX() or 0
    local y = sq and sq:getY() or 0
    local z = sq and sq:getZ() or 0
    local tickBucket = math.floor((getWorldMinutes() or 0) / 10)
    local idHash = stringHash(wind.id or (x .. "_" .. y .. "_" .. z))
    local phase = (idHash * 0.0137) + (tickBucket * 0.71) + (x * 0.11) + (y * 0.07) + (z * 0.19)
    local normalized = (math.sin(phase) + 1) * 0.5 -- 0..1
    local efficiency = minEff + ((maxEff - minEff) * normalized)

    if efficiency < 0 then
        efficiency = 0
    elseif efficiency > 1 then
        efficiency = 1
    end

    wind.efficiency = efficiency
    return efficiency
end

local function getFloorSpriteName(square)
    if not square then
        return nil
    end
    local floor = safeCall(square, "getFloor")
    local sprite = floor and safeCall(floor, "getSprite") or nil
    local name = sprite and safeCall(sprite, "getName") or nil
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return string.lower(name)
end

local function isHydroSquareValid(square)
    if not square then
        return false, nil
    end
    local spriteName = getFloorSpriteName(square)
    local props = safeCall(square, "getProperties")
    if EnergyRouting and EnergyRouting.IsValidHydroSpriteName and EnergyRouting.IsValidHydroSpriteName(spriteName) then
        return true, spriteName
    end
    local hasWaterFlag = props and props.has and props:has(IsoFlagType.water) or false
    local isWaterMethod = safeCall(square, "isWater") == true
    local waterAmount = safeCall(square, "getWaterAmount")
    if hasWaterFlag then
        return true, spriteName
    end
    if isWaterMethod then
        return true, spriteName
    end
    if (tonumber(waterAmount) or 0) > 0 then
        return true, spriteName
    end
    local whitelist = EnergyRouting and EnergyRouting.HYDRO_VALID_SPRITES or nil
    return whitelist and whitelist[spriteName] == true or false, spriteName
end

local function getSquareFromRef(ref)
    if type(ref) ~= "table" then
        return nil
    end
    local x = tonumber(ref.x)
    local y = tonumber(ref.y)
    local z = tonumber(ref.z) or 0
    if not x or not y then
        return nil
    end
    return getSquare(math.floor(x), math.floor(y), math.floor(z))
end

local function updateSquareRef(container, key, square)
    if not container or not key then
        return false
    end
    local old = container[key]
    local oldX = old and tonumber(old.x) or nil
    local oldY = old and tonumber(old.y) or nil
    local oldZ = old and tonumber(old.z) or nil
    local newX = square and square:getX() or nil
    local newY = square and square:getY() or nil
    local newZ = square and square:getZ() or nil
    if oldX == newX and oldY == newY and oldZ == newZ then
        return false
    end
    if square then
        container[key] = { x = newX, y = newY, z = newZ }
    else
        container[key] = nil
    end
    return true
end

local function findAdjacentValidHydroWater(square, maxRadius)
    if not square then
        return nil
    end
    local radiusLimit = math.max(1, math.floor(tonumber(maxRadius) or 2))
    local z = square:getZ()
    local cx = square:getX()
    local cy = square:getY()
    for radius = 1, radiusLimit do
        for ox = -radius, radius do
            for oy = -radius, radius do
                if math.abs(ox) == radius or math.abs(oy) == radius then
                    local candidate = getSquare(cx + ox, cy + oy, z)
                    local valid = isHydroSquareValid(candidate)
                    if valid then
                        return candidate
                    end
                end
            end
        end
    end
    return nil
end

local function resolveHydroValidationSquare(hydroObj, hydro)
    local objectSquare = getSquareFromObj(hydroObj)
    local md = getObjectModData(hydroObj)
    local linked = nil

    if hydro then
        linked = getSquareFromRef(hydro.waterSquare)
        if not linked then
            linked = getSquareFromRef(hydro.sourceWaterSquare)
        end
    end

    if not linked and md and type(md.hydroPlacement) == "table" then
        linked = getSquareFromRef(md.hydroPlacement.waterSquare)
    end

    if linked and objectSquare and linked:DistToProper(objectSquare) > (HYDRO_WATER_SEARCH_RADIUS + 0.5) then
        linked = nil
    end

    if linked then
        return linked, objectSquare, true
    end

    local fallback = findAdjacentValidHydroWater(objectSquare, HYDRO_WATER_SEARCH_RADIUS)
    if fallback then
        return fallback, objectSquare, true
    end

    return objectSquare, objectSquare, false
end

local function refreshHydroWaterState(hydroObj, hydro)
    if not hydroObj or not hydro then
        return false
    end
    local validationSquare, objectSquare, isLinkedWater = resolveHydroValidationSquare(hydroObj, hydro)
    local validWater, spriteName = isHydroSquareValid(validationSquare)
    local changed = false
    if hydro.validWater ~= validWater then
        hydro.validWater = validWater
        changed = true
    end
    local cachedSprite = spriteName or ""
    if hydro.spriteType ~= cachedSprite then
        hydro.spriteType = cachedSprite
        changed = true
    end
    if isLinkedWater then
        if hydro.isOverWater ~= true then
            hydro.isOverWater = true
            changed = true
        end
        if hydro.placedOnWater ~= true then
            hydro.placedOnWater = true
            changed = true
        end
    end
    if updateSquareRef(hydro, "waterSquare", validationSquare) then
        changed = true
    end
    if updateSquareRef(hydro, "anchorSquare", objectSquare) then
        changed = true
    end
    return changed
end

local function setPanelProduction(panelObj, production, panelEfficiency, maxProduction, qualityBonus)
    if not panelObj then
        return
    end
    local md = getObjectModData(panelObj)
    if not md then
        return
    end
    local solar = ensureSolarIdentity(panelObj)
    md.panel = md.panel or {}
    if qualityBonus ~= nil then
        md.panel.bonus = math.max(0, tonumber(qualityBonus) or 0)
    elseif solar and solar.qualityBonus ~= nil then
        md.panel.bonus = math.max(0, tonumber(solar.qualityBonus) or 0)
    elseif md.panel.bonus == nil then
        md.panel.bonus = math.max(0, tonumber(getPanelBonus(panelObj)) or 0)
    end
    if panelEfficiency ~= nil then
        md.panel.efficiency = clamp01(panelEfficiency, 0)
    end
    if solar and solar.degradation ~= nil then
        md.panel.degradation = clamp01(solar.degradation, 1.0)
    end
    if maxProduction ~= nil then
        md.panel.maxProduction = math.max(0, tonumber(maxProduction) or 0)
    end
    local energy = ensureEnergyPanelMeta(panelObj)
    if energy then
        energy.currentProduction = production
        energy.bonus = md.panel.bonus
        if panelEfficiency ~= nil then
            energy.efficiency = clamp01(panelEfficiency, 0)
        end
        if maxProduction ~= nil then
            energy.maxProduction = math.max(0, tonumber(maxProduction) or 0)
        end
        if energy.controllerId == nil and md.panel.controllerId then
            energy.controllerId = md.panel.controllerId
        end
    end
    local prev = md.panel.production
    md.panel.production = production
    md.panel.productionRate = production
    if prev == nil or math.abs(prev - production) >= 1 then
        transmitObjectModData(panelObj)
    end
end

local function computePanelProduction(panelObj, sunFactor, networkBonus)
    if not panelObj then
        return 0
    end
    local energy = ensureEnergyPanelMeta and ensureEnergyPanelMeta(panelObj) or nil
    if not energy then
        return 0
    end
    local solar = ensureSolarIdentity(panelObj)
    local baseEfficiency = solar and clamp01(solar.baseEfficiency, 0.85) or 1.0
    local degradation = applySolarDailyDegradation(panelObj)
    degradation = clamp01(degradation, (solar and solar.degradation) or 1.0)
    local qualityBonus = solar and math.max(0, tonumber(solar.qualityBonus) or 0) or math.max(0, tonumber(energy.bonus) or 0)
    local baseProduction = getPanelBaseProduction(panelObj)
    local maxProduction = baseProduction * (1 + qualityBonus)
    local sun = sunFactor
    if sun == nil then
        sun = getSolarEfficiency()
    end
    local wearFactor = getWearReductionFactor(degradation)
    local panelEfficiency = clamp01(baseEfficiency * (sun or 0) * wearFactor, 0)
    local networkMult = tonumber(networkBonus)
    if not networkMult or networkMult <= 0 then
        networkMult = 1
    end
    local production = maxProduction * panelEfficiency * networkMult
    if production < 0 then
        production = 0
    end
    local rounded = math.floor(production + 0.5)
    local effectiveMaxProduction = math.max(0, maxProduction * networkMult)
    setPanelProduction(panelObj, rounded, panelEfficiency, effectiveMaxProduction, qualityBonus)
    return rounded
end

local function setWindProduction(windObj, production, bonus)
    if not windObj then
        return
    end
    local md = getObjectModData(windObj)
    if not md then
        return
    end
    local wind = ensureWindMeta(windObj)
    if not wind then
        return
    end
    local prev = wind.currentProduction
    wind.currentProduction = production
    if bonus ~= nil then
        wind.bonus = bonus
    elseif wind.bonus == nil then
        wind.bonus = 0
    end
    if prev == nil or math.abs(prev - production) >= 1 then
        transmitObjectModData(windObj)
    end
end

local function computeWindProduction(windObj, weatherMultiplier, networkBonus)
    if not windObj then
        return 0
    end
    local wind = ensureWindMeta and ensureWindMeta(windObj) or nil
    if not wind then
        return 0
    end
    local baseProduction = wind.baseProduction or ((EnergyRouting and EnergyRouting.WIND_BASE_W) or 400)
    local efficiency = wind.efficiency or 1.0
    local windWeather = getWindWeatherSnapshot()
    local multiplier = weatherMultiplier
    if multiplier == nil then
        multiplier = windWeather.multiplier or 0
    else
        windWeather.multiplier = multiplier
    end
    multiplier = math.max(0, tonumber(multiplier) or 0)
    -- Avoid absolute dead-wind frustration on active turbines while keeping output bounded.
    local turbineActive = (wind.connected == true) and (wind.controllerId ~= nil)
    if turbineActive then
        multiplier = math.max(multiplier, 0.08)
    end
    local condition = applyWindDailyDegradation(windObj, windWeather, turbineActive)
    condition = clamp01(condition, wind.condition or 1.0)
    local bonusMult = networkBonus
    if bonusMult == nil or bonusMult < 1 then
        bonusMult = 1
    end
    local wearFactor = getWearReductionFactor(condition)
    local production = baseProduction * multiplier * efficiency * wearFactor * bonusMult
    if production < 0 then
        production = 0
    end
    local rounded = math.floor(production + 0.5)
    setWindProduction(windObj, rounded, bonusMult - 1)
    return rounded
end

local function setHydroProduction(hydroObj, production)
    if not hydroObj then
        return
    end
    local md = getObjectModData(hydroObj)
    if not md then
        return
    end
    local hydro = ensureHydroMeta and ensureHydroMeta(hydroObj) or nil
    if not hydro then
        return
    end
    local rounded = math.max(0, math.floor((tonumber(production) or 0) + 0.5))
    local prev = tonumber(hydro.currentProduction) or 0
    hydro.currentProduction = rounded
    if md.production and type(md.production) == "table" then
        md.production.currentProduction = rounded
    end
    if math.abs(prev - rounded) >= 1 then
        transmitObjectModData(hydroObj)
    end
end

local function computeHydroProduction(hydroObj)
    if not hydroObj then
        return 0
    end
    local hydro = ensureHydroMeta and ensureHydroMeta(hydroObj) or nil
    if not hydro then
        return 0
    end
    local nowMs = getWorldTimestampMs()
    local tickMs = tonumber((EnergyRouting and EnergyRouting.HYDRO_TICK_MS) or 7000) or 7000
    local nextAt = tonumber(hydro.nextCalcAtMs) or 0
    if nextAt > nowMs then
        return math.max(0, math.floor((tonumber(hydro.currentProduction) or 0) + 0.5))
    end

    local changed = refreshHydroWaterState(hydroObj, hydro)
    local condition = tonumber(hydro.condition) or 100
    if condition < 0 then
        condition = 0
    elseif condition > 100 then
        condition = 100
    end

    local baseOutput = tonumber(hydro.baseOutput) or ((EnergyRouting and EnergyRouting.HYDRO_BASE_W) or 450)
    local production = 0
    if hydro.validWater ~= false and hydro.isActive ~= false and condition > 0 then
        production = math.max(0, math.floor(baseOutput + 0.5))
    end

    if production > 0 then
        local decay = HYDRO_CONDITION_DECAY_STEP
        if condition <= 30 then
            decay = decay + HYDRO_DAMAGED_EXTRA_DECAY_STEP
        end
        local newCondition = condition - decay
        if newCondition < 0 then
            newCondition = 0
        end
        if math.abs(newCondition - condition) > 0.000001 then
            condition = newCondition
            changed = true
        end
    end

    if hydro.condition ~= condition then
        hydro.condition = condition
        changed = true
    end
    local shouldBeActive = condition > 0
    if hydro.isActive ~= shouldBeActive then
        hydro.isActive = shouldBeActive
        changed = true
    end

    if condition <= 0 then
        production = 0
    end

    if (tonumber(hydro.currentProduction) or 0) ~= production then
        hydro.currentProduction = production
        changed = true
    end

    hydro.nextCalcAtMs = nowMs + tickMs

    if changed then
        local md = getObjectModData(hydroObj)
        if md then
            md.production = md.production or {}
            md.production.degradation = clamp01(condition / 100, 1.0)
            md.production.currentProduction = production
            md.production.lastUpdateDay = getWorldDayNumber()
        end
        transmitObjectModData(hydroObj)
    end

    return math.max(0, math.floor((tonumber(hydro.currentProduction) or 0) + 0.5))
end

function ECS.IsControllerObject(obj)
    if not obj then
        return false
    end
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.EnergyController" or fullType == "EnergyController" then
        return true
    end
    local spriteName = getSpriteName(obj)
    if spriteName and hasWorldItemBacking(obj) and string.find(spriteName, "EnergyController", 1, true) then
        return true
    end
    return false
end

function ECS.IsWorldControllerObject(obj)
    if not obj then
        return false
    end
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item and item.getFullType and item:getFullType() == "EnergyRouting.EnergyController" then
        return true
    end
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.EnergyController" or fullType == "EnergyController" then
        return true
    end
    return false
end

local CONTROLLER_MODE_PRESET_TOGGLES = {
    Balanced = {
        refrigeration = true,
        lights = true,
        cooking = true,
        industrial = true,
    },
    Survival = {
        refrigeration = true,
        lights = true,
        cooking = false,
        industrial = false,
    },
    Comfort = {
        refrigeration = true,
        lights = true,
        cooking = true,
        industrial = false,
    },
}

local function normalizeControllerModeValue(mode)
    if mode == "Balanced" or mode == "Survival" or mode == "Comfort" or mode == "Manual" then
        return mode
    end
    return "Balanced"
end

local function getControllerPresetToggle(mode, groupId)
    local preset = CONTROLLER_MODE_PRESET_TOGGLES[mode] or CONTROLLER_MODE_PRESET_TOGGLES.Balanced
    local value = preset and preset[groupId]
    if value == nil then
        value = (mode == "Survival") and false or true
    end
    return value == true
end

local function enforceControllerModeToggles(controller)
    if type(controller) ~= "table" then
        return
    end
    controller.priorityMode = normalizeControllerModeValue(controller.priorityMode or controller.mode or "Balanced")
    controller.mode = normalizeControllerModeValue(controller.mode or controller.priorityMode or "Balanced")
    if controller.outputEnabled == nil then
        controller.outputEnabled = true
    end
    if type(controller.toggles) ~= "table" then
        controller.toggles = {}
    end
    if controller.mode ~= "Manual" then
        local presetToggles = {}
        for _, group in ipairs(EnergyRouting.GroupsList or {}) do
            presetToggles[group.id] = getControllerPresetToggle(controller.mode, group.id)
        end
        controller.toggles = presetToggles
        return
    end
    local defaults = EnergyRouting.MakeDefaultToggles and EnergyRouting.MakeDefaultToggles() or {}
    for groupId, defaultValue in pairs(defaults) do
        if controller.toggles[groupId] == nil then
            controller.toggles[groupId] = defaultValue ~= false
        end
    end
end

function ECS.InitControllerObject(obj)
    if not obj then
        return false
    end
    local square = getSquareFromObj(obj)
    if not square then
        return false
    end
    local md = getObjectModData(obj)
    if not md then
        return false
    end
    if md and type(md.energyController) == "table" then
        return false
    end
    if md and md.energyController ~= nil and type(md.energyController) ~= "table" then
        print("[EnergyController][Server] Invalid energyController type=" .. tostring(type(md.energyController)) .. " -> reset")
    end
    md.energyController = {
        networkId = string.format("network_%d_%d_%d", square:getX(), square:getY(), square:getZ()),
        panels = {},
        batteries = {},
        windTurbines = {},
        hydroTurbines = {},
        windBatteries = {},
        priorityMode = "Balanced",
        mode = "Balanced",
        outputEnabled = true,
        toggles = EnergyRouting.MakeDefaultToggles and EnergyRouting.MakeDefaultToggles() or {},
    }
    enforceControllerModeToggles(md.energyController)
    -- Mark as EDC so EnergyNetwork_Server can register it
    md.EnergyRoutingEDC = true
    md.EnergyRoutingEDCId = md.energyController.networkId

    -- Store EDCId on the square so the client can resolve controllerId
    local sqMd = square:getModData()
    sqMd.EnergyRoutingEDCId = md.energyController.networkId
    if square.transmitModData then
        square:transmitModData()
    end

    -- Register in the server registry (EnergyNetwork_Server.lua)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RegisterEDC then
        EnergyRouting.Server.RegisterEDC(square, nil, md.energyController.networkId)
    end
    transmitObjectModData(obj)
    print("[EnergyController][Server] Controller initialized " .. tostring(md.energyController.networkId))
    return true
end

function ECS.EnsureControllerForObject(obj)
    if not obj then
        return false
    end
    local md = getObjectModData(obj)
    if not md then
        return false
    end
    if md and type(md.energyController) == "table" then
        enforceControllerModeToggles(md.energyController)
        local square = getSquareFromObj(obj)
        if not square then
            return false
        end
        local expectedId = "network_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ())
        local beforeId = md.energyController.networkId
        if beforeId ~= expectedId then
            md.energyController.networkId = expectedId
            md.EnergyRoutingEDC = true
            md.EnergyRoutingEDCId = expectedId
            if ECS._controllerLookupCache and beforeId then
                ECS._controllerLookupCache[beforeId] = nil
            end
            local sqMd = square:getModData()
            if sqMd then
                sqMd.EnergyRoutingEDCId = expectedId
                if square.transmitModData then
                    square:transmitModData()
                end
            end
            if EnergyRouting and EnergyRouting.Server then
                if beforeId and beforeId ~= expectedId and EnergyRouting.Server.RemoveEDC then
                    EnergyRouting.Server.RemoveEDC(beforeId)
                end
                if EnergyRouting.Server.RegisterEDC then
                    EnergyRouting.Server.RegisterEDC(square, nil, expectedId)
                end
            end
            transmitObjectModData(obj)
            return true
        end
        transmitObjectModData(obj)
        return false
    end
    if not ECS.IsWorldControllerObject(obj) and not ECS.IsControllerObject(obj) then
        return false
    end
    return ECS.InitControllerObject(obj) == true
end

function ECS.ServerEnsureController(obj)
    ECS.EnsureControllerForObject(obj)
end

function ECS.GetAllControllers()
    local results = {}
    local cell = getCell()
    if not cell or not cell.getObjectList then
        return results
    end
    local objects = cell:getObjectList()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if ECS.IsWorldControllerObject(obj) or ECS.IsControllerObject(obj) then
            table.insert(results, obj)
        end
    end
    return results
end

function ECS.BackfillControllers()
    for _, controllerObj in ipairs(ECS.GetAllControllers()) do
        ECS.EnsureControllerForObject(controllerObj)
        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RegisterEDC then
            local square = getSquareFromObj(controllerObj)
            local md = getObjectModData(controllerObj)
            local controller = (md and type(md.energyController) == "table") and md.energyController or nil
            if square and controller and controller.networkId then
                md.EnergyRoutingEDC = true
                md.EnergyRoutingEDCId = controller.networkId
                EnergyRouting.Server.RegisterEDC(square, nil, controller.networkId)
            end
        end
    end
end

function ECS.RestoreAllNetworks(silent)
    local cell = getCell()
    if not cell or not cell.getObjectList then
        return 0, 0, 0, 0, 0, 0, {}
    end
    local objects = cell:getObjectList()
    if not objects then
        return 0, 0, 0, 0, 0, 0, {}
    end
    local squares = {}
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local sq = safeCall(obj, "getSquare")
        if sq then
            local key = tostring(sq:getX()) .. ":" .. tostring(sq:getY()) .. ":" .. tostring(sq:getZ())
            squares[key] = sq
        end
    end

    local perController = {}
    local restoredControllers = 0
    local restoredPanels = 0
    local restoredBatteries = 0
    local restoredTurbines = 0
    local restoredHydro = 0
    local restoredWindBatteries = 0
    if not silent then
        print("[SPESS][Links] Restoring energy networks...")
    end
    local function processObject(obj)
        if not obj then
            return
        end
        if ECS.IsWorldControllerObject(obj) or ECS.IsControllerObject(obj) then
            ECS.EnsureControllerForObject(obj)
            if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinksForController then
                EnergyRouting.Server.RestoreLinksForController(obj)
            end
            local md = getObjectModData(obj)
            local controllerId = md and md.energyController and md.energyController.networkId or nil
            if controllerId then
                perController[controllerId] = perController[controllerId] or { panels = 0, batteries = 0, turbines = 0, hydro = 0, windBatteries = 0 }
            end
            restoredControllers = restoredControllers + 1
        elseif ECS.IsPanelObject(obj) then
            ensurePanelMeta(obj)
            ensureEnergyPanelMeta(obj)
            local panelId = getPanelId and getPanelId(obj) or nil
            if panelId then
                local md = getObjectModData(obj)
                if not md then
                    return
                end
                local controllerId = (md and md.panel and md.panel.controllerId)
                    or (md and md.energyPanel and md.energyPanel.controllerId)
                    or (md and md.energy and md.energy.controllerId)
                if controllerId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
                    EnergyRouting.Server.RecordLink(controllerId, "panel", panelId)
                    restoredPanels = restoredPanels + 1
                    perController[controllerId] = perController[controllerId] or { panels = 0, batteries = 0, turbines = 0, hydro = 0, windBatteries = 0 }
                    perController[controllerId].panels = perController[controllerId].panels + 1
                end
                if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
                    EnergyRouting.Server.RestoreLinkForObject(obj, "panel", panelId)
                end
            end
        elseif ECS.IsBatteryObject(obj) then
            local batteryMeta = ensureBatteryMeta(obj)
            if not batteryMeta then
                return
            end
            local batteryId = getBatteryId and getBatteryId(obj) or nil
            if batteryId then
                local md = getObjectModData(obj)
                if not md then
                    return
                end
                local controllerId = md and md.energy and md.energy.controllerId
                if controllerId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
                    EnergyRouting.Server.RecordLink(controllerId, "battery", batteryId)
                    restoredBatteries = restoredBatteries + 1
                    perController[controllerId] = perController[controllerId] or { panels = 0, batteries = 0, turbines = 0, hydro = 0, windBatteries = 0 }
                    perController[controllerId].batteries = perController[controllerId].batteries + 1
                end
                if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
                    EnergyRouting.Server.RestoreLinkForObject(obj, "battery", batteryId)
                end
            end
        elseif ECS.IsWindObject(obj) then
            local windMeta = ensureWindMeta(obj)
            if not windMeta then
                return
            end
            local windId = getWindId(obj)
            if windId then
                local md = getObjectModData(obj)
                if not md then
                    return
                end
                local controllerId = md and md.wind and md.wind.controllerId
                if controllerId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
                    EnergyRouting.Server.RecordLink(controllerId, "turbine", windId)
                    restoredTurbines = restoredTurbines + 1
                    perController[controllerId] = perController[controllerId] or { panels = 0, batteries = 0, turbines = 0, hydro = 0, windBatteries = 0 }
                    perController[controllerId].turbines = (perController[controllerId].turbines or 0) + 1
                end
                if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
                    EnergyRouting.Server.RestoreLinkForObject(obj, "turbine", windId)
                end
            end
        elseif ECS.IsHydroObject(obj) then
            local hydroMeta = ensureHydroMeta(obj)
            if not hydroMeta then
                return
            end
            local hydroId = getHydroId(obj)
            if hydroId then
                local md = getObjectModData(obj)
                if not md then
                    return
                end
                local controllerId = md and md.hydro and md.hydro.controllerId
                if controllerId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
                    EnergyRouting.Server.RecordLink(controllerId, "hydro", hydroId)
                    restoredHydro = restoredHydro + 1
                    perController[controllerId] = perController[controllerId] or { panels = 0, batteries = 0, turbines = 0, hydro = 0, windBatteries = 0 }
                    perController[controllerId].hydro = (perController[controllerId].hydro or 0) + 1
                end
                if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
                    EnergyRouting.Server.RestoreLinkForObject(obj, "hydro", hydroId)
                end
            end
        elseif ECS.IsWindBatteryObject(obj) then
            local windBatteryMeta = ensureWindBatteryMeta(obj)
            if not windBatteryMeta then
                return
            end
            local windBatteryId = getWindBatteryId(obj)
            if windBatteryId then
                local md = getObjectModData(obj)
                if not md then
                    return
                end
                local controllerId = md and md.windBattery and md.windBattery.controllerId
                if controllerId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
                    EnergyRouting.Server.RecordLink(controllerId, "windBattery", windBatteryId)
                    restoredWindBatteries = restoredWindBatteries + 1
                    perController[controllerId] = perController[controllerId] or { panels = 0, batteries = 0, turbines = 0, hydro = 0, windBatteries = 0 }
                    perController[controllerId].windBatteries = (perController[controllerId].windBatteries or 0) + 1
                end
                if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
                    EnergyRouting.Server.RestoreLinkForObject(obj, "windBattery", windBatteryId)
                end
            end
        end
    end

    for _, sq in pairs(squares) do
        local objs = sq:getObjects()
        if objs then
            for i = 0, objs:size() - 1 do
                processObject(objs:get(i))
            end
        end
        if sq.getSpecialObjects then
            local specialObjs = sq:getSpecialObjects()
            if specialObjs then
                for i = 0, specialObjs:size() - 1 do
                    processObject(specialObjs:get(i))
                end
            end
        end
        local worldObjs = sq:getWorldObjects()
        if worldObjs then
            for i = 0, worldObjs:size() - 1 do
                processObject(worldObjs:get(i))
            end
        end
    end
    if not silent then
        print("[SPESS][Links] Restore complete: controllers="
            .. tostring(restoredControllers)
            .. " panels=" .. tostring(restoredPanels)
            .. " batteries=" .. tostring(restoredBatteries)
            .. " turbines=" .. tostring(restoredTurbines)
            .. " hydro=" .. tostring(restoredHydro)
            .. " windBatteries=" .. tostring(restoredWindBatteries))
        for controllerId, counts in pairs(perController) do
            print("[SPESS][Links] Controller " .. tostring(controllerId)
                .. " panels=" .. tostring(counts.panels or 0)
                .. " batteries=" .. tostring(counts.batteries or 0)
                .. " turbines=" .. tostring(counts.turbines or 0)
                .. " hydro=" .. tostring(counts.hydro or 0)
                .. " windBatteries=" .. tostring(counts.windBatteries or 0))
        end
    end
    return restoredControllers, restoredPanels, restoredBatteries, restoredTurbines, restoredHydro, restoredWindBatteries, perController
end

function ECS.TryRestoreNetworks()
    ECS._restoreAttempts = (ECS._restoreAttempts or 0) + 1
    local controllers, panels, batteries, turbines, hydro, windBatteries, perController = ECS.RestoreAllNetworks(true)
    controllers = tonumber(controllers) or 0
    panels = tonumber(panels) or 0
    batteries = tonumber(batteries) or 0
    turbines = tonumber(turbines) or 0
    hydro = tonumber(hydro) or 0
    windBatteries = tonumber(windBatteries) or 0
    local total = controllers + panels + batteries + turbines + hydro + windBatteries

    if ECS._restoreAttempts == 1 then
        print("[SPESS][Links] Restoring energy networks...")
        local cache = EnergyRouting and EnergyRouting.Server
            and EnergyRouting.Server.EnsureLinkCache and EnergyRouting.Server.EnsureLinkCache() or nil
        if cache then
            local cacheControllers = 0
            local cacheObjects = 0
            for _ in pairs(cache.controllers or {}) do
                cacheControllers = cacheControllers + 1
            end
            for _ in pairs(cache.objects or {}) do
                cacheObjects = cacheObjects + 1
            end
            print("[SPESS][Links] Cache controllers=" .. tostring(cacheControllers)
                .. " objects=" .. tostring(cacheObjects))
        end
        local cell = getCell()
        local objects = cell and cell.getObjectList and cell:getObjectList() or nil
        local objCount = objects and objects:size() or 0
        print("[SPESS][Links] Loaded objects=" .. tostring(objCount))
    end

    if total > 0 then
        print("[SPESS][Links] Restore complete: controllers="
            .. tostring(controllers or 0)
            .. " panels=" .. tostring(panels or 0)
            .. " batteries=" .. tostring(batteries or 0)
            .. " turbines=" .. tostring(turbines or 0)
            .. " hydro=" .. tostring(hydro or 0)
            .. " windBatteries=" .. tostring(windBatteries or 0))
        for controllerId, counts in pairs(perController or {}) do
            print("[SPESS][Links] Controller " .. tostring(controllerId)
                .. " panels=" .. tostring(counts.panels or 0)
                .. " batteries=" .. tostring(counts.batteries or 0)
                .. " turbines=" .. tostring(counts.turbines or 0)
                .. " hydro=" .. tostring(counts.hydro or 0)
                .. " windBatteries=" .. tostring(counts.windBatteries or 0))
        end
        if Events and Events.EveryOneMinute and Events.EveryOneMinute.Remove then
            Events.EveryOneMinute.Remove(ECS.TryRestoreNetworks)
        end
        ECS._restoreDone = true
        return
    end

    if ECS._restoreAttempts >= 10 then
        print("[SPESS][Links] Restore stop: no links found after " .. tostring(ECS._restoreAttempts) .. " attempts")
        if Events and Events.EveryOneMinute and Events.EveryOneMinute.Remove then
            Events.EveryOneMinute.Remove(ECS.TryRestoreNetworks)
        end
        return
    end

    print("[SPESS][Links] Restore retry " .. tostring(ECS._restoreAttempts) .. "/10 (no objects yet)")
end

function ECS.IsBatteryObject(obj)
    if not obj then
        return false
    end
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.BatteryTank" or fullType == "BatteryTank" then
        return true
    end
    local spriteName = getSpriteName(obj)
    if spriteName and hasWorldItemBacking(obj) and string.find(spriteName, "BatteryTank", 1, true) then
        return true
    end
    return false
end

function ECS.IsWindBatteryObject(obj)
    if not obj then
        return false
    end
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.WindBattery" or fullType == "WindBattery" then
        return true
    end
    local spriteName = getSpriteName(obj)
    if spriteName and hasWorldItemBacking(obj) and string.find(spriteName, "WindBattery", 1, true) then
        return true
    end
    return false
end

function ECS.IsPanelObject(obj)
    if not obj then
        return false
    end
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.SolarPanel" or fullType == "SolarPanel"
        or fullType == "EnergyRouting.SolarPanelHorizontal" or fullType == "SolarPanelHorizontal" then
        return true
    end
    local spriteName = getSpriteName(obj)
    if spriteName and hasWorldItemBacking(obj) and (string.find(spriteName, "SolarPanel", 1, true) ~= nil) then
        return true
    end
    return false
end

function ECS.IsWindObject(obj)
    if not obj then
        return false
    end
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.Aerogenerador" or fullType == "Aerogenerador" then
        return true
    end
    local spriteName = getSpriteName(obj)
    if spriteName and hasWorldItemBacking(obj) and (string.find(spriteName, "Aerogenerador", 1, true) ~= nil
        or string.find(spriteName, "WindTurbine", 1, true) ~= nil) then
        return true
    end
    return false
end

function ECS.IsHydroObject(obj)
    if not obj then
        return false
    end
    local md = getObjectModData(obj)
    if md and md.hydro then
        return true
    end
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.TurbinaHidraulica" or fullType == "TurbinaHidraulica" then
        return true
    end
    local spriteName = getSpriteName(obj)
    if spriteName and (string.find(spriteName, "TurbinaHidraulica", 1, true) ~= nil
        or string.find(spriteName, "HydroTurbine", 1, true) ~= nil) then
        return true
    end
    return false
end

local function ensureControllerMeta(obj)
    if not obj then
        return nil
    end
    local square = getSquareFromObj(obj)
    if not square then
        return nil
    end
    local md = getObjectModData(obj)
    if not md then
        return nil
    end
    if type(md.energyController) ~= "table" then
        if not ECS.IsWorldControllerObject(obj) and not ECS.IsControllerObject(obj) then
            return nil
        end
        md.energyController = {
            networkId = "network_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ()),
            panels = {},
            batteries = {},
            windTurbines = {},
            hydroTurbines = {},
            windBatteries = {},
            priorityMode = "Balanced",
            mode = "Balanced",
            outputEnabled = true,
            toggles = EnergyRouting.MakeDefaultToggles and EnergyRouting.MakeDefaultToggles() or {},
        }
    end
    md.energyController.networkId = md.energyController.networkId
        or ("network_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ()))
    md.energyController.panels = md.energyController.panels or {}
    md.energyController.batteries = md.energyController.batteries or {}
    md.energyController.windTurbines = md.energyController.windTurbines or {}
    md.energyController.hydroTurbines = md.energyController.hydroTurbines or {}
    md.energyController.windBatteries = md.energyController.windBatteries or {}
    md.energyController.priorityMode = md.energyController.priorityMode or "Balanced"
    md.energyController.mode = md.energyController.mode or md.energyController.priorityMode or "Balanced"
    md.energyController.toggles = md.energyController.toggles or {}
    if md.energyController.outputEnabled == nil then
        md.energyController.outputEnabled = true
    end
    md.energyController.totalProduction = md.energyController.totalProduction or 0
    md.energyController.totalStorage = md.energyController.totalStorage or 0
    md.energyController.totalCapacity = md.energyController.totalCapacity or 0
    md.energyController.windProduction = md.energyController.windProduction or 0
    md.energyController.hydroProduction = md.energyController.hydroProduction or 0
    md.energyController.windStorage = md.energyController.windStorage or 0
    md.energyController.windCapacity = md.energyController.windCapacity or 0
    enforceControllerModeToggles(md.energyController)
    local expectedId = "network_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ())
    if md.energyController.networkId ~= expectedId then
        local oldId = md.energyController.networkId
        md.energyController.networkId = expectedId
        if ECS._controllerLookupCache and oldId then
            ECS._controllerLookupCache[oldId] = nil
        end
        md.EnergyRoutingEDC = true
        md.EnergyRoutingEDCId = expectedId
        local sqMd = square:getModData()
        if sqMd then
            sqMd.EnergyRoutingEDCId = expectedId
            if square.transmitModData then
                square:transmitModData()
            end
        end
        if EnergyRouting and EnergyRouting.Server then
            if oldId and oldId ~= expectedId and EnergyRouting.Server.RemoveEDC then
                EnergyRouting.Server.RemoveEDC(oldId)
            end
            if EnergyRouting.Server.RegisterEDC then
                EnergyRouting.Server.RegisterEDC(square, nil, expectedId)
            end
        end
        transmitObjectModData(obj)
    end
    return md.energyController
end

local _coreBatteryDefinitionsRegistered = false

local function ensureCoreBatteryDefinitionsRegistered()
    if _coreBatteryDefinitionsRegistered then
        return
    end
    if not EnergyRouting or not EnergyRouting.API then
        return
    end
    if not EnergyRouting.Registry or not EnergyRouting.Registry.GetBattery then
        return
    end
    if not EnergyRouting.Registry.GetBattery("core_solar_battery") then
        EnergyRouting.API.RegisterBattery({
            id = "core_solar_battery",
            displayName = "ERS Core Solar Battery",
            sortOrder = 10,
            GetCapacity = function()
                return EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
            end,
        })
    end
    if not EnergyRouting.Registry.GetBattery("core_wind_battery") then
        EnergyRouting.API.RegisterBattery({
            id = "core_wind_battery",
            displayName = "ERS Core Wind Battery",
            sortOrder = 20,
            GetCapacity = function()
                return EnergyRouting.GetConfigValue("BaseWindBatteryCapacity") or 100000
            end,
        })
    end
    _coreBatteryDefinitionsRegistered = true
end

local function getBatteryDefinitionById(batteryId)
    ensureCoreBatteryDefinitionsRegistered()
    if not batteryId or not EnergyRouting or not EnergyRouting.Registry
        or not EnergyRouting.Registry.GetBattery then
        return nil
    end
    return EnergyRouting.Registry.GetBattery(batteryId)
end

local function resolveBatteryCapacityFromDefinition(definition, batteryObj, fallbackCapacity)
    local capacity = nil
    if type(definition) == "table" then
        if type(definition.GetCapacity) == "function" then
            local ok, result = pcall(definition.GetCapacity, batteryObj, definition)
            if ok then
                capacity = tonumber(result)
            end
        end
        if not capacity or capacity <= 0 then
            capacity = tonumber(definition.capacity)
        end
    end
    if not capacity or capacity <= 0 then
        capacity = tonumber(fallbackCapacity) or 0
    end
    return capacity
end

ensureBatteryMeta = function(obj)
    if not obj then
        return nil
    end
    local md = getObjectModData(obj)
    if not md then
        return nil
    end
    md.energy = md.energy or {}
    md.energy.batteryId = md.energy.batteryId or "core_solar_battery"
    md.energy.controllerId = md.energy.controllerId or nil
    md.energy.storedEnergy = md.energy.storedEnergy or 0
    local baseCapacity = EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
    if md.energy.capacity == nil or tonumber(md.energy.capacity) <= 0 then
        local batteryDefinition = getBatteryDefinitionById(md.energy.batteryId)
        md.energy.capacity = resolveBatteryCapacityFromDefinition(batteryDefinition, obj, baseCapacity)
    end
    md.energy.type = md.energy.type or "battery"
    if md.energy.controllerId ~= nil then
        md.energy.connected = true
    elseif md.energy.connected == nil then
        md.energy.connected = false
    end
    return md.energy
end

ensurePanelMeta = function(obj)
    if not obj then
        return nil
    end
    local md = getObjectModData(obj)
    if not md then
        return nil
    end
    md.panel = md.panel or {}
    local solar, createdSolarIdentity = ensureSolarIdentity(obj)
    md.panel.controllerId = md.panel.controllerId or nil
    md.panel.productionRate = md.panel.productionRate or 0
    md.panel.bonus = (solar and solar.qualityBonus) or md.panel.bonus or math.max(0, tonumber(getPanelBonus(obj)) or 0)
    md.panel.baseEfficiency = (solar and solar.baseEfficiency) or md.panel.baseEfficiency or 1.0
    md.panel.degradation = (solar and solar.degradation) or md.panel.degradation or 1.0
    if not md.panel.type then
        md.panel.type = getItemFullType(obj) or getSpriteName(obj) or "Unknown"
    end
    local energy = md.energyPanel
    if energy and energy.controllerId ~= nil then
        md.panel.controllerId = energy.controllerId
    end
    md.energy = md.energy or {}
    md.energy.type = md.energy.type or "solar"
    if (not md.panel.controllerId) and md.energy.controllerId then
        md.panel.controllerId = md.energy.controllerId
    end
    if md.panel and md.panel.controllerId then
        md.energy.controllerId = md.panel.controllerId
    elseif md.energyPanel and md.energyPanel.controllerId then
        md.energy.controllerId = md.energyPanel.controllerId
    end
    md.energy.connected = md.energy.controllerId ~= nil
    if createdSolarIdentity then
        transmitObjectModData(obj)
    end
    return md.panel
end

ensureEnergyPanelMeta = function(obj)
    if not obj then
        return nil
    end
    local md = getObjectModData(obj)
    if not md then
        return nil
    end
    md.panel = md.panel or {}
    md.energyPanel = md.energyPanel or {}
    local energy = md.energyPanel
    local solar = ensureSolarIdentity(obj)
    local qualityBonus = (solar and solar.qualityBonus) or math.max(0, tonumber(getPanelBonus(obj)) or 0)
    -- Max shown in UI: base watts + panel individual quality bonus.
    energy.maxProduction = getPanelBaseProduction(obj) * (1 + qualityBonus)
    energy.efficiency = energy.efficiency or ((solar and solar.baseEfficiency) or 1.0)
    energy.bonus = qualityBonus
    energy.currentProduction = energy.currentProduction or 0
    if energy.controllerId == nil and md.panel and md.panel.controllerId then
        energy.controllerId = md.panel.controllerId
    end
    return energy
end

ensureWindMeta = function(obj)
    if not obj then
        return nil
    end
    local md = getObjectModData(obj)
    if not md then
        return nil
    end
    local square = getSquareFromObj(obj)
    md.wind = md.wind or {}
    local wind = md.wind
    local _, production, createdProduction = ensureProductionMeta(obj, 1.0)
    if square then
        local expectedId = "wind_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ())
        if wind.id ~= expectedId then
            wind.id = expectedId
        end
    end
    wind.controllerId = wind.controllerId or nil
    if wind.condition == nil or type(wind.condition) ~= "number" then
        wind.condition = (production and production.degradation) or 1.0
    elseif createdProduction and production then
        production.degradation = clamp01(wind.condition, production.degradation)
    end
    if wind.condition < 0 then
        wind.condition = 0
    elseif wind.condition > 1 then
        wind.condition = 1
    end
    if production then
        production.degradation = clamp01(production.degradation, wind.condition)
        wind.condition = production.degradation
    end
    wind.baseProduction = wind.baseProduction or ((EnergyRouting and EnergyRouting.WIND_BASE_W) or 400)
    wind.efficiency = wind.efficiency or 1.0
    wind.currentProduction = wind.currentProduction or 0
    wind.connected = wind.connected == true
    return wind
end

ensureHydroMeta = function(obj)
    if not obj then
        return nil
    end
    local md = getObjectModData(obj)
    if not md then
        return nil
    end
    local square = getSquareFromObj(obj)
    md.hydro = md.hydro or {}
    local hydro = md.hydro
    local _, production = ensureProductionMeta(obj, 1.0)
    if square then
        local expectedId = "hydro_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ())
        if hydro.id ~= expectedId then
            hydro.id = expectedId
        end
    end
    hydro.controllerId = hydro.controllerId or nil
    local configuredHydroBase = (EnergyRouting and EnergyRouting.HYDRO_BASE_W) or 450
    local oldHydroBase = 170
    local parsedBaseOutput = tonumber(hydro.baseOutput)
    if parsedBaseOutput == nil then
        hydro.baseOutput = configuredHydroBase
    elseif math.abs(parsedBaseOutput - oldHydroBase) < 0.001 then
        -- Migrate legacy hydro turbines that still have the old 170W default.
        hydro.baseOutput = configuredHydroBase
    else
        hydro.baseOutput = parsedBaseOutput
    end
    local initialCondition = tonumber(hydro.condition)
    if initialCondition == nil then
        local prodDeg = tonumber(production and production.degradation)
        if prodDeg ~= nil then
            initialCondition = prodDeg * 100
        else
            initialCondition = 100
        end
    end
    if initialCondition < 0 then
        initialCondition = 0
    elseif initialCondition > 100 then
        initialCondition = 100
    end
    hydro.condition = initialCondition
    hydro.currentProduction = math.max(0, tonumber(hydro.currentProduction) or 0)
    hydro.connected = hydro.connected == true
    hydro.isActive = hydro.isActive ~= false and hydro.condition > 0
    md.energy = md.energy or {}
    md.energy.type = "hydro"
    if hydro.controllerId then
        md.energy.controllerId = hydro.controllerId
        md.energy.connected = true
    else
        md.energy.controllerId = nil
        md.energy.connected = false
    end
    refreshHydroWaterState(obj, hydro)
    if production then
        production.degradation = clamp01(hydro.condition / 100, 1.0)
    end
    return hydro
end

ensureWindBatteryMeta = function(obj)
    if not obj then
        return nil
    end
    local md = getObjectModData(obj)
    if not md then
        return nil
    end
    local square = getSquareFromObj(obj)
    md.windBattery = md.windBattery or {}
    local battery = md.windBattery
    if square then
        local expectedId = "wind_battery_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ())
        if battery.id ~= expectedId then
            battery.id = expectedId
        end
    end
    battery.controllerId = battery.controllerId or nil
    battery.role = battery.role or nil
    battery.batteryId = battery.batteryId or "core_wind_battery"
    local baseWindCapacity = (EnergyRouting.GetConfigValue("BaseWindBatteryCapacity") or 100000)
    if battery.capacity == nil or tonumber(battery.capacity) <= 0 then
        local batteryDefinition = getBatteryDefinitionById(battery.batteryId)
        battery.capacity = resolveBatteryCapacityFromDefinition(batteryDefinition, obj, baseWindCapacity)
    end
    battery.charge = battery.charge or 0
    battery.state = battery.state or "idle"
    battery.connected = battery.connected == true
    return battery
end

local function collectIds(list)
    local ids = {}
    if not list then
        return ids
    end
    local seen = {}
    for k, v in pairs(list) do
        if type(k) == "string" then
            if not seen[k] then
                seen[k] = true
                table.insert(ids, k)
            end
        elseif type(v) == "string" then
            if not seen[v] then
                seen[v] = true
                table.insert(ids, v)
            end
        end
    end
    return ids
end

local function countIds(list)
    local n = 0
    if not list then
        return 0
    end
    local seen = {}
    for k, v in pairs(list) do
        if type(k) == "string" then
            if not seen[k] then
                seen[k] = true
                n = n + 1
            end
        elseif type(v) == "string" then
            if not seen[v] then
                seen[v] = true
                n = n + 1
            end
        end
    end
    return n
end

local function getMiniPanelLimit()
    local value = EnergyRouting and EnergyRouting.GetConfigValue and tonumber(EnergyRouting.GetConfigValue("MaxMiniPanels")) or nil
    if value == nil then
        value = 2
    end
    value = math.floor(value)
    if value < 0 then
        value = 0
    end
    return value
end

local function getMiniWindLimit()
    local value = EnergyRouting and EnergyRouting.GetConfigValue and tonumber(EnergyRouting.GetConfigValue("MaxMiniWindTurbines")) or nil
    if value == nil then
        value = 2
    end
    value = math.floor(value)
    if value < 0 then
        value = 0
    end
    return value
end

local function isMiniPanelObject(obj)
    if not obj then
        return false
    end

    local md = getObjectModData(obj)
    if md then
        if md.ownerMod == "SmallProducersPack" then
            return true
        end
        if md.isMiniSolar == true then
            return true
        end
        if type(md.smallProducer) == "table" and md.smallProducer.type == "solar" then
            return true
        end
        if type(md.panel) == "table" and tostring(md.panel.type or "") == "Small Solar Panel" then
            return true
        end
    end

    local fullType = getItemFullType(obj)
    if type(fullType) == "string"
        and (string.find(fullType, "MiniSolarPanel", 1, true) ~= nil
            or string.find(fullType, "Mini_SolarPanel", 1, true) ~= nil) then
        return true
    end
    local spriteName = getSpriteName(obj)
    if type(spriteName) == "string"
        and (string.find(spriteName, "MiniSolarPanel", 1, true) ~= nil
            or string.find(spriteName, "Mini_SolarPanel", 1, true) ~= nil) then
        return true
    end

    return false
end

local function isMiniWindObject(obj)
    if not obj then
        return false
    end

    local md = getObjectModData(obj)
    if md then
        if md.ownerMod == "SmallProducersPack" then
            return true
        end
        if md.isMiniWind == true then
            return true
        end
        if type(md.smallProducer) == "table" and md.smallProducer.type == "wind" then
            return true
        end
        if type(md.wind) == "table" and tostring(md.wind.spriteType or "") == "Small Wind Turbine" then
            return true
        end
    end

    local fullType = getItemFullType(obj)
    if type(fullType) == "string"
        and (string.find(fullType, "MiniWindTurbine", 1, true) ~= nil
            or string.find(fullType, "Mini_WindTurbine", 1, true) ~= nil) then
        return true
    end
    local spriteName = getSpriteName(obj)
    if type(spriteName) == "string"
        and (string.find(spriteName, "MiniWindTurbine", 1, true) ~= nil
            or string.find(spriteName, "Mini_WindTurbine", 1, true) ~= nil) then
        return true
    end

    return false
end

local function getPanelKind(obj)
    if isMiniPanelObject(obj) then
        return "mini"
    end
    return "core"
end

local function getWindKind(obj)
    if isMiniWindObject(obj) then
        return "mini"
    end
    return "core"
end

local function countPanelIdsByKind(list, wantedKind)
    local count = 0
    local ids = collectIds(list or {})
    for _, panelId in ipairs(ids) do
        local panelObj = ECS.GetPanelById and ECS.GetPanelById(panelId) or nil
        if panelObj then
            if getPanelKind(panelObj) == wantedKind then
                count = count + 1
            end
        elseif wantedKind == "core" then
            count = count + 1
        end
    end
    return count
end

local function countWindIdsByKind(list, wantedKind)
    local count = 0
    local ids = collectIds(list or {})
    for _, windId in ipairs(ids) do
        local windObj = ECS.GetWindById and ECS.GetWindById(windId) or nil
        if windObj then
            if getWindKind(windObj) == wantedKind then
                count = count + 1
            end
        elseif wantedKind == "core" then
            count = count + 1
        end
    end
    return count
end

local function isMiniHydroObject(obj)
    if not obj then
        return false
    end

    local md = getObjectModData(obj)
    if md then
        if md.ownerMod == "SmallProducersPack" then
            return true
        end
        if md.isMiniHydro == true then
            return true
        end
        if type(md.smallProducer) == "table" and md.smallProducer.type == "hydro" then
            return true
        end
        if type(md.hydro) == "table" and tostring(md.hydro.spriteType or "") == "Small Hydro Turbine" then
            return true
        end
    end

    local fullType = getItemFullType(obj)
    if type(fullType) == "string"
        and (string.find(fullType, "MiniHydroTurbine", 1, true) ~= nil
            or string.find(fullType, "Mini_HydroTurbine", 1, true) ~= nil) then
        return true
    end

    local spriteName = getSpriteName(obj)
    if type(spriteName) == "string"
        and (string.find(spriteName, "MiniHydroTurbine", 1, true) ~= nil
            or string.find(spriteName, "Mini_HydroTurbine", 1, true) ~= nil) then
        return true
    end

    return false
end

local function getHydroKind(obj)
    if isMiniHydroObject(obj) then
        return "mini"
    end
    return "core"
end

local function countHydroIdsByKind(list, wantedKind)
    local count = 0
    local ids = collectIds(list or {})
    for _, hydroId in ipairs(ids) do
        local hydroObj = ECS.GetHydroById and ECS.GetHydroById(hydroId) or nil
        if hydroObj then
            if getHydroKind(hydroObj) == wantedKind then
                count = count + 1
            end
        elseif wantedKind == "core" then
            -- Unknown entries are treated as core to avoid over-allowing links.
            count = count + 1
        end
    end
    return count
end

local function getBatteryRoleById(batteryId)
    if not batteryId then
        return nil
    end
    local batteryObj = ECS.GetBatteryById and ECS.GetBatteryById(batteryId) or nil
    if not batteryObj then
        return nil
    end
    local md = getObjectModData(batteryObj)
    local energy = md and md.energy or nil
    return energy and energy.role or nil
end

local function getOrderedBatteryIds(controller)
    local ids = collectIds(controller and controller.batteries or {})
    local masterId = nil
    local slaves = {}
    for _, id in ipairs(ids) do
        local role = getBatteryRoleById(id)
        if role == "master" and not masterId then
            masterId = id
        else
            table.insert(slaves, id)
        end
    end
    if not masterId and #ids > 0 then
        masterId = ids[1]
        for i = 2, #ids do
            table.insert(slaves, ids[i])
        end
    end
    return masterId, slaves
end

local function chargeBatteryById(batteryId, watts)
    if not batteryId or watts <= 0 then
        return watts
    end
    local batteryObj = ECS.GetBatteryById and ECS.GetBatteryById(batteryId) or nil
    if not batteryObj then
        return watts
    end
    local battery = ensureBatteryMeta(batteryObj)
    local capacity = battery.capacity or EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
    local stored = battery.storedEnergy or 0
    local add = math.min(watts, math.max(0, capacity - stored))
    if add > 0 then
        battery.storedEnergy = stored + add
        transmitObjectModData(batteryObj)
    end
    return watts - add
end

local function dischargeBatteryById(batteryId, watts)
    if not batteryId or watts <= 0 then
        return watts
    end
    local batteryObj = ECS.GetBatteryById and ECS.GetBatteryById(batteryId) or nil
    if not batteryObj then
        return watts
    end
    local battery = ensureBatteryMeta(batteryObj)
    local stored = battery.storedEnergy or 0
    local take = math.min(watts, math.max(0, stored))
    if take > 0 then
        battery.storedEnergy = stored - take
        transmitObjectModData(batteryObj)
    end
    return watts - take
end

local function applyChargeMasterFirst(controller, watts)
    if not controller or watts <= 0 then
        return 0
    end
    local remaining = watts
    local masterId, slaves = getOrderedBatteryIds(controller)
    if masterId then
        remaining = chargeBatteryById(masterId, remaining)
    end
    for _, id in ipairs(slaves) do
        if remaining <= 0 then
            break
        end
        remaining = chargeBatteryById(id, remaining)
    end
    return watts - remaining
end

local function applyDischargeMasterFirst(controller, watts)
    if not controller or watts <= 0 then
        return 0
    end
    local remaining = watts
    local masterId, slaves = getOrderedBatteryIds(controller)
    if masterId then
        remaining = dischargeBatteryById(masterId, remaining)
    end
    for _, id in ipairs(slaves) do
        if remaining <= 0 then
            break
        end
        remaining = dischargeBatteryById(id, remaining)
    end
    return watts - remaining
end

local function getWindBatteryRoleById(batteryId)
    if not batteryId then
        return nil
    end
    local batteryObj = ECS.GetWindBatteryById and ECS.GetWindBatteryById(batteryId) or nil
    if not batteryObj then
        return nil
    end
    local md = getObjectModData(batteryObj)
    local battery = md and md.windBattery or nil
    return battery and battery.role or nil
end

local function getOrderedWindBatteryIds(controller)
    local ids = collectIds(controller and controller.windBatteries or {})
    local masterId = nil
    local slaves = {}
    for _, id in ipairs(ids) do
        local role = getWindBatteryRoleById(id)
        if role == "master" and not masterId then
            masterId = id
        else
            table.insert(slaves, id)
        end
    end
    if not masterId and #ids > 0 then
        masterId = ids[1]
        for i = 2, #ids do
            table.insert(slaves, ids[i])
        end
    end
    return masterId, slaves
end

local function chargeWindBatteryById(batteryId, watts)
    if not batteryId or watts <= 0 then
        return watts
    end
    local batteryObj = ECS.GetWindBatteryById and ECS.GetWindBatteryById(batteryId) or nil
    if not batteryObj then
        return watts
    end
    local battery = ensureWindBatteryMeta(batteryObj)
    local capacity = battery.capacity or (EnergyRouting.GetConfigValue("BaseWindBatteryCapacity") or 100000)
    local charge = battery.charge or 0
    local add = math.min(watts, math.max(0, capacity - charge))
    if add > 0 then
        battery.charge = charge + add
        battery.state = "charging"
        transmitObjectModData(batteryObj)
    end
    return watts - add
end

local function dischargeWindBatteryById(batteryId, watts)
    if not batteryId or watts <= 0 then
        return watts
    end
    local batteryObj = ECS.GetWindBatteryById and ECS.GetWindBatteryById(batteryId) or nil
    if not batteryObj then
        return watts
    end
    local battery = ensureWindBatteryMeta(batteryObj)
    local charge = battery.charge or 0
    local take = math.min(watts, math.max(0, charge))
    if take > 0 then
        battery.charge = charge - take
        battery.state = "discharging"
        transmitObjectModData(batteryObj)
    end
    return watts - take
end

local function applyWindChargeMasterFirst(controller, watts)
    if not controller or watts <= 0 then
        return 0
    end
    local remaining = watts
    local masterId, slaves = getOrderedWindBatteryIds(controller)
    if masterId then
        remaining = chargeWindBatteryById(masterId, remaining)
    end
    for _, id in ipairs(slaves) do
        if remaining <= 0 then
            break
        end
        remaining = chargeWindBatteryById(id, remaining)
    end
    return watts - remaining
end

local function applyWindDischargeMasterFirst(controller, watts)
    if not controller or watts <= 0 then
        return 0
    end
    local remaining = watts
    local masterId, slaves = getOrderedWindBatteryIds(controller)
    if masterId then
        remaining = dischargeWindBatteryById(masterId, remaining)
    end
    for _, id in ipairs(slaves) do
        if remaining <= 0 then
            break
        end
        remaining = dischargeWindBatteryById(id, remaining)
    end
    return watts - remaining
end
local function normalizeEdcBatteries(edc)
    if not edc then
        return
    end
    if not edc.batteries then
        edc.batteries = {}
        return
    end
    local normalized = {}
    for _, entry in ipairs(edc.batteries) do
        if type(entry) == "string" then
            table.insert(normalized, { id = entry, role = nil })
        elseif type(entry) == "table" and entry.id then
            table.insert(normalized, entry)
        end
    end
    edc.batteries = normalized
end

local function findEdcBattery(edc, batteryId)
    if not edc or not edc.batteries then
        return nil
    end
    for _, entry in ipairs(edc.batteries) do
        if entry.id == batteryId then
            return entry
        end
    end
    return nil
end

local function findMasterBatteryId(edc)
    if not edc or not edc.batteries then
        return nil
    end
    for _, entry in ipairs(edc.batteries) do
        if entry.role == "master" then
            return entry.id
        end
    end
    return nil
end

local function ensureMasterBattery(edc)
    if not edc or not edc.batteries or #edc.batteries == 0 then
        return nil
    end
    local masterId = findMasterBatteryId(edc)
    if masterId then
        return masterId
    end
    edc.batteries[1].role = "master"
    return edc.batteries[1].id
end

local function normalizeBatteryRoles(edc)
    if not edc or not edc.batteries then
        return nil
    end
    local masterId = nil
    for _, entry in ipairs(edc.batteries) do
        if entry.role == "master" then
            masterId = entry.id
            break
        end
    end
    if not masterId and #edc.batteries > 0 then
        edc.batteries[1].role = "master"
        masterId = edc.batteries[1].id
    end
    for _, entry in ipairs(edc.batteries) do
        if entry.id ~= masterId then
            entry.role = "slave"
        end
    end
    return masterId
end

local function setBatteryRole(batteryObj, role, controllerId)
    if not batteryObj then
        return false
    end
    local battery = ensureBatteryMeta(batteryObj)
    local changed = false
    if battery.controllerId ~= controllerId then
        battery.controllerId = controllerId
        changed = true
    end
    if battery.role ~= role then
        battery.role = role
        changed = true
    end
    local connected = controllerId ~= nil
    if battery.connected ~= connected then
        battery.connected = connected
        changed = true
    end
    if changed then
        transmitObjectModData(batteryObj)
    end
    return changed
end

local function clearBatteryRole(batteryObj)
    if not batteryObj then
        return false
    end
    local battery = ensureBatteryMeta(batteryObj)
    local changed = false
    if battery.controllerId ~= nil then
        battery.controllerId = nil
        changed = true
    end
    if battery.role ~= nil then
        battery.role = nil
        changed = true
    end
    if battery.connected ~= false then
        battery.connected = false
        changed = true
    end
    if changed then
        transmitObjectModData(batteryObj)
    end
    return changed
end

local function getWindMasterId(controller)
    local ids = collectIds(controller and controller.windBatteries or {})
    for _, id in ipairs(ids) do
        local batteryObj = ECS.GetWindBatteryById and ECS.GetWindBatteryById(id) or nil
        local md = batteryObj and getObjectModData(batteryObj) or nil
        local battery = md and md.windBattery or nil
        if battery and battery.role == "master" then
            return id
        end
    end
    return nil
end

local function normalizeWindBatteryRoles(controller)
    if not controller then
        return nil
    end
    local ids = collectIds(controller.windBatteries or {})
    if #ids == 0 then
        return nil
    end
    local masterId = getWindMasterId(controller) or ids[1]
    for _, id in ipairs(ids) do
        local batteryObj = ECS.GetWindBatteryById and ECS.GetWindBatteryById(id) or nil
        if batteryObj then
            local battery = ensureWindBatteryMeta(batteryObj)
            if battery then
                battery.controllerId = controller.networkId
                battery.connected = true
                if id == masterId then
                    battery.role = "master"
                else
                    battery.role = "slave"
                end
                transmitObjectModData(batteryObj)
            end
        end
    end
    return masterId
end

local function rebuildEdcBatteriesFromController(edc, controller)
    if not edc or not controller then
        return
    end
    normalizeEdcBatteries(edc)

    local controllerIds = collectIds(controller.batteries)
    local controllerSet = {}
    for _, id in ipairs(controllerIds) do
        controllerSet[id] = true
    end

    local existing = {}
    for _, entry in ipairs(edc.batteries) do
        existing[entry.id] = entry
    end

    local removedIds = {}
    local newList = {}
    for _, id in ipairs(controllerIds) do
        local entry = existing[id]
        if not entry then
            entry = { id = id, role = nil }
        end
        table.insert(newList, entry)
    end
    for id in pairs(existing) do
        if not controllerSet[id] then
            table.insert(removedIds, id)
        end
    end

    edc.batteries = newList
    local masterId = normalizeBatteryRoles(edc)

    local controllerId = controller.networkId or edc.id
    for _, entry in ipairs(edc.batteries) do
        local batteryObj = ECS.GetBatteryById and ECS.GetBatteryById(entry.id) or nil
        if batteryObj then
            setBatteryRole(batteryObj, entry.role, controllerId)
        end
    end
    for _, removedId in ipairs(removedIds) do
        local batteryObj = ECS.GetBatteryById and ECS.GetBatteryById(removedId) or nil
        if batteryObj then
            clearBatteryRole(batteryObj)
        end
    end
end

local function addId(list, value)
    if not list or not value then
        return false
    end
    if list[value] then
        return false
    end
    for _, v in ipairs(list) do
        if v == value then
            return false
        end
    end
    list[value] = true
    return true
end

local function removeId(list, value)
    if not list then
        return
    end
    list[value] = nil
    for i = #list, 1, -1 do
        if list[i] == value then
            table.remove(list, i)
        end
    end
end

local function getControllerId(obj)
    local md = getObjectModData(obj)
    return md and type(md.energyController) == "table" and md.energyController.networkId or nil
end

local function parseControllerCoordsFromId(controllerId)
    if type(controllerId) ~= "string" then
        return nil, nil, nil, nil
    end
    local x, y, z = EnergyNetwork.ParseCoordsFromId(controllerId, "network")
    if x then
        return x, y, z, "network"
    end
    x, y, z = EnergyNetwork.ParseCoordsFromId(controllerId, "energy_net")
    if x then
        return x, y, z, "energy_net"
    end
    return nil, nil, nil, nil
end

isControllerPrototypeObject = function(obj)
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.EnergyController" or fullType == "EnergyController" then
        return true
    end
    local spriteName = getSpriteName(obj)
    if spriteName and hasWorldItemBacking(obj) and string.find(spriteName, "EnergyController", 1, true) then
        return true
    end
    return false
end

getPanelId = function(obj)
    local square = getSquareFromObj(obj)
    if not square then
        return nil
    end
    return EnergyNetwork.MakePanelId(square:getX(), square:getY(), square:getZ())
end

getBatteryId = function(obj)
    local square = getSquareFromObj(obj)
    if not square then
        return nil
    end
    if not EnergyNetwork or not EnergyNetwork.MakeBatteryId then
        return nil
    end
    return EnergyNetwork.MakeBatteryId(square:getX(), square:getY(), square:getZ())
end

getWindId = function(obj)
    local square = getSquareFromObj(obj)
    if not square then
        return nil
    end
    return "wind_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ())
end

getWindBatteryId = function(obj)
    local square = getSquareFromObj(obj)
    if not square then
        return nil
    end
    return "wind_battery_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ())
end

getHydroId = function(obj)
    local square = getSquareFromObj(obj)
    if not square then
        local md = getObjectModData(obj)
        return md and md.hydro and md.hydro.id or nil
    end
    return "hydro_" .. tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ())
end

local function getLinkedControllerIdForKind(kind, md)
    if not md then
        return nil
    end
    if kind == "panel" then
        return (md.panel and md.panel.controllerId)
            or (md.energyPanel and md.energyPanel.controllerId)
            or (md.energy and md.energy.controllerId)
            or nil
    end
    if kind == "battery" then
        return (md.energy and md.energy.controllerId) or nil
    end
    if kind == "turbine" then
        return (md.wind and md.wind.controllerId) or nil
    end
    if kind == "hydro" then
        return (md.hydro and md.hydro.controllerId)
            or (md.energy and md.energy.controllerId)
            or nil
    end
    if kind == "windBattery" then
        return (md.windBattery and md.windBattery.controllerId)
            or (md.energy and md.energy.controllerId)
            or nil
    end
    return nil
end

local function getPendingObjectRemovalStore()
    ECS._pendingObjectRemovals = ECS._pendingObjectRemovals or {}
    return ECS._pendingObjectRemovals
end

local function makePendingObjectRemovalKey(kind, objectId)
    if not kind or not objectId then
        return nil
    end
    return tostring(kind) .. ":" .. tostring(objectId)
end

local function getPendingObjectRemovalEntry(kind, objectId)
    local key = makePendingObjectRemovalKey(kind, objectId)
    if not key then
        return nil
    end
    local store = ECS._pendingObjectRemovals
    return store and store[key] or nil
end

local function cancelPendingObjectRemoval(kind, objectId)
    local key = makePendingObjectRemovalKey(kind, objectId)
    if not key then
        return false
    end
    local store = ECS._pendingObjectRemovals
    if store and store[key] then
        store[key] = nil
        return true
    end
    return false
end

local function buildPendingObjectRemovalEntry(obj)
    if not obj then
        return nil
    end

    local square = getSquareFromObj(obj)
    local md = getObjectModData(obj)
    if not md then
        return nil
    end

    local kind = nil
    local objectId = nil
    if ECS.IsPanelObject(obj) then
        kind = "panel"
        objectId = getPanelId(obj)
    elseif ECS.IsBatteryObject(obj) then
        kind = "battery"
        objectId = getBatteryId(obj)
    elseif ECS.IsWindObject(obj) then
        kind = "turbine"
        objectId = getWindId(obj)
    elseif ECS.IsHydroObject(obj) then
        kind = "hydro"
        objectId = getHydroId(obj)
    elseif ECS.IsWindBatteryObject(obj) then
        kind = "windBattery"
        objectId = getWindBatteryId(obj)
    end

    if not kind or not objectId then
        return nil
    end

    local controllerId = getLinkedControllerIdForKind(kind, md)
    if not controllerId then
        return nil
    end

    return {
        kind = kind,
        objectId = objectId,
        controllerId = controllerId,
        x = square and square:getX() or nil,
        y = square and square:getY() or nil,
        z = square and square:getZ() or nil,
        dueAtMs = getWorldTimestampMs() + PENDING_LINK_REMOVE_CONFIRM_MS,
    }
end

local function queuePendingObjectRemoval(obj)
    local entry = buildPendingObjectRemovalEntry(obj)
    if not entry then
        return false
    end
    local key = makePendingObjectRemovalKey(entry.kind, entry.objectId)
    if not key then
        return false
    end
    local store = getPendingObjectRemovalStore()
    store[key] = entry
    return true
end

local function shouldSkipRestoreForPendingRemoval(obj, kind, objectId)
    local entry = getPendingObjectRemovalEntry(kind, objectId)
    if not entry then
        return false
    end

    local md = getObjectModData(obj)
    local linkedControllerId = getLinkedControllerIdForKind(kind, md)
    if linkedControllerId and linkedControllerId == entry.controllerId then
        cancelPendingObjectRemoval(kind, objectId)
        return false
    end

    return true
end

local function getLiveObjectForPendingRemoval(entry)
    if not entry or not entry.objectId then
        return nil
    end
    if entry.kind == "panel" and ECS.GetPanelById then
        return ECS.GetPanelById(entry.objectId)
    end
    if entry.kind == "battery" and ECS.GetBatteryById then
        return ECS.GetBatteryById(entry.objectId)
    end
    if entry.kind == "turbine" and ECS.GetWindById then
        return ECS.GetWindById(entry.objectId)
    end
    if entry.kind == "hydro" and ECS.GetHydroById then
        return ECS.GetHydroById(entry.objectId)
    end
    if entry.kind == "windBattery" and ECS.GetWindBatteryById then
        return ECS.GetWindBatteryById(entry.objectId)
    end
    return nil
end

local function clearLiveObjectLinkForPendingRemoval(obj, kind)
    if not obj then
        return
    end
    local md = getObjectModData(obj)
    if not md then
        return
    end

    if kind == "panel" then
        if md.panel then
            md.panel.controllerId = nil
        end
        if md.energyPanel then
            md.energyPanel.controllerId = nil
        end
        md.energy = md.energy or {}
        md.energy.type = "solar"
        md.energy.controllerId = nil
        md.energy.connected = false
    elseif kind == "battery" then
        md.energy = md.energy or {}
        md.energy.type = md.energy.type or "battery"
        md.energy.controllerId = nil
        md.energy.role = nil
        md.energy.connected = false
    elseif kind == "turbine" then
        md.wind = md.wind or {}
        md.wind.controllerId = nil
        md.wind.connected = false
        md.wind.currentProduction = 0
        md.energy = md.energy or {}
        md.energy.type = "wind"
        md.energy.controllerId = nil
        md.energy.connected = false
    elseif kind == "hydro" then
        md.hydro = md.hydro or {}
        md.hydro.controllerId = nil
        md.hydro.connected = false
        md.hydro.currentProduction = 0
        md.hydro.isActive = false
        md.energy = md.energy or {}
        md.energy.type = "hydro"
        md.energy.controllerId = nil
        md.energy.connected = false
    elseif kind == "windBattery" then
        md.windBattery = md.windBattery or {}
        md.windBattery.controllerId = nil
        md.windBattery.role = nil
        md.windBattery.connected = false
        md.windBattery.state = "idle"
        md.energy = md.energy or {}
        md.energy.controllerId = nil
        md.energy.connected = false
    else
        return
    end

    transmitObjectModData(obj)
end

local function refreshControllerAfterPendingRemoval(controllerId)
    if type(controllerId) ~= "string" then
        return
    end

    local controllerObj = getControllerById(controllerId)
    if controllerObj then
        local controller = ensureControllerMeta(controllerObj)
        local md = getObjectModData(controllerObj)
        if md then
            md.energyController = controller
        end
        transmitObjectModData(controllerObj)
        if ECS.TickController then
            ECS.TickController(controllerObj)
        end
    end

    if EnergyRouting and EnergyRouting.Server
        and EnergyRouting.Server.GetEDCById
        and EnergyRouting.Server.UpdateEDC then
        local edc = EnergyRouting.Server.GetEDCById(controllerId)
        if edc then
            EnergyRouting.Server.UpdateEDC(edc)
        end
    end
end

local function finalizePendingObjectRemoval(entry)
    if not entry or type(entry.controllerId) ~= "string" or not entry.objectId then
        return
    end

    local liveObj = getLiveObjectForPendingRemoval(entry)
    local liveControllerId = nil
    if liveObj then
        liveControllerId = getLinkedControllerIdForKind(entry.kind, getObjectModData(liveObj))
    end
    if liveObj and liveControllerId == entry.controllerId then
        return
    end

    if liveObj and (liveControllerId == nil or liveControllerId == entry.controllerId) then
        clearLiveObjectLinkForPendingRemoval(liveObj, entry.kind)
    end

    local controllerObj = getControllerById(entry.controllerId)
    if controllerObj then
        local controller = ensureControllerMeta(controllerObj)
        if entry.kind == "panel" then
            removeId(controller.panels, entry.objectId)
        elseif entry.kind == "battery" then
            removeId(controller.batteries, entry.objectId)
        elseif entry.kind == "turbine" then
            removeId(controller.windTurbines, entry.objectId)
        elseif entry.kind == "hydro" then
            removeId(controller.hydroTurbines, entry.objectId)
        elseif entry.kind == "windBattery" then
            removeId(controller.windBatteries, entry.objectId)
            normalizeWindBatteryRoles(controller)
        end

        local controllerMd = getObjectModData(controllerObj)
        if controllerMd then
            controllerMd.energyController = controller
        end
        transmitObjectModData(controllerObj)
    end

    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
        EnergyRouting.Server.RemoveLink(entry.controllerId, entry.kind, entry.objectId)
    end

    local sourceSquare = nil
    if entry.x ~= nil and entry.y ~= nil and entry.z ~= nil then
        sourceSquare = getSquare(entry.x, entry.y, entry.z)
    end
    returnCableForUnlink(sourceSquare, 1)
    refreshControllerAfterPendingRemoval(entry.controllerId)
end

function ECS.ProcessPendingObjectRemovals()
    local store = ECS._pendingObjectRemovals
    if not store then
        return
    end

    local nowMs = getWorldTimestampMs()
    for key, entry in pairs(store) do
        local dueAtMs = tonumber(entry and entry.dueAtMs) or 0
        if nowMs >= dueAtMs then
            local ok, err = pcall(finalizePendingObjectRemoval, entry)
            store[key] = nil
            if not ok then
                _ERS_RAW_PRINT("[SPESS][Server] finalizePendingObjectRemoval failed key="
                    .. tostring(key) .. " err=" .. tostring(err))
            end
        end
    end
end

function ECS.ConnectPanelToController(panelObj, controllerObj, player)
    if not panelObj or not controllerObj then
        return false
    end
    local panelSquare = getSquareFromObj(panelObj)
    local controllerSquare = getSquareFromObj(controllerObj)
    print("[EnergyController][Server] ConnectPanel request panelSq="
        .. tostring(panelSquare and (panelSquare:getX() .. "," .. panelSquare:getY() .. "," .. panelSquare:getZ()) or "nil")
        .. " controllerSq="
        .. tostring(controllerSquare and (controllerSquare:getX() .. "," .. controllerSquare:getY() .. "," .. controllerSquare:getZ()) or "nil"))
    if player and not playerHasCable(player) then
        return false
    end
    local controller = ensureControllerMeta(controllerObj)
    local panel = ensurePanelMeta(panelObj)
    if panel.controllerId then
        return false
    end
    local panelKind = getPanelKind(panelObj)
    local maxPanels = (panelKind == "mini")
        and getMiniPanelLimit()
        or getClampedLimit(EnergyNetwork.GetConfigValue("MaxPanels"), HARD_MAX_PANELS, HARD_MAX_PANELS)
    local linkedCount = countPanelIdsByKind(controller.panels, panelKind)
    if linkedCount >= maxPanels then
        print("[EnergyController][Server] ConnectPanel failed: max panels reached for type="
            .. tostring(panelKind) .. " (" .. tostring(linkedCount) .. "/" .. tostring(maxPanels) .. ")")
        return false
    end
    local panelSq = getSquareFromObj(panelObj)
    local controllerSq = getSquareFromObj(controllerObj)
    if not withinRadius(panelSq, controllerSq, EnergyNetwork.GetConfigValue("ControllerConnectRadius")) then
        return false
    end
    local panelId = getPanelId(panelObj)
    local panelMd = getObjectModData(panelObj)
    if not panelMd then
        return false
    end
    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    if player and not consumeCable(player) then
        return false
    end
    panel.controllerId = controller.networkId
    local energyPanel = ensureEnergyPanelMeta(panelObj)
    if energyPanel then
        energyPanel.controllerId = controller.networkId
    end
    panelMd.energy = panelMd.energy or {}
    panelMd.energy.type = "solar"
    panelMd.energy.controllerId = controller.networkId
    panelMd.energy.connected = true
    addId(controller.panels, panelId)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
        EnergyRouting.Server.RecordLink(controller.networkId, "panel", panelId)
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    transmitObjectModData(panelObj)
    -- Logs de depuración
    print("[EnergyController][Server] ConnectPanel SUCCESS. Panels count: " .. tostring(countIds(controller.panels)))
    print("[EnergyController][Server] ConnectPanel controllerId=" .. tostring(controller.networkId)
        .. " panelId=" .. tostring(panelId)
        .. " panels=" .. tostring(countIds(controller.panels))
        .. " batteries=" .. tostring(countIds(controller.batteries)))

    local edc = EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC
        and EnergyRouting.Server.GetOrCreateEDC(controller.networkId) or nil

    if edc and EnergyRouting.Server.UpdateEDC then
        EnergyRouting.Server.UpdateEDC(edc) -- debería terminar en BroadcastState
    end

    -- Fallback directo al player (SP/edge cases)
    local target = player or getSpecificPlayer(0)
    if edc and target and EnergyRouting.Server.SendStateToPlayer then
        EnergyRouting.Server.SendStateToPlayer(target, edc)
    end

    local md = getObjectModData(controllerObj)
    print("[EnergyController][Server] controller modData energyController=" .. tostring(type(md.energyController) == "table"))
    sendLinkSync(player, "panel", panelId, controller.networkId, true, controller.networkId)
    return true
end

function ECS.ConnectBatteryToController(batteryObj, controllerObj, player)
    if not batteryObj or not controllerObj then
        return false
    end
    local batterySquare = getSquareFromObj(batteryObj)
    local controllerSquare = getSquareFromObj(controllerObj)
    print("[EnergyController][Server] ConnectBattery request batterySq="
        .. tostring(batterySquare and (batterySquare:getX() .. "," .. batterySquare:getY() .. "," .. batterySquare:getZ()) or "nil")
        .. " controllerSq="
        .. tostring(controllerSquare and (controllerSquare:getX() .. "," .. controllerSquare:getY() .. "," .. controllerSquare:getZ()) or "nil"))
    if player and not playerHasCable(player) then
        return false
    end
    local controller = ensureControllerMeta(controllerObj)
    local battery = ensureBatteryMeta(batteryObj)
    if battery.controllerId then
        return false
    end
    local maxBatteries = getClampedLimit(
        EnergyNetwork.GetConfigValue("MaxBatteries"),
        HARD_MAX_BATTERIES,
        HARD_MAX_BATTERIES
    )
    if countIds(controller.batteries) >= maxBatteries then
        return false
    end
    local batterySq = getSquareFromObj(batteryObj)
    local controllerSq = getSquareFromObj(controllerObj)
    if not withinRadius(batterySq, controllerSq, EnergyNetwork.GetConfigValue("ControllerConnectRadius")) then
        return false
    end
    local batteryId = getBatteryId(batteryObj)
    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    if player and not consumeCable(player) then
        return false
    end
    battery.controllerId = controller.networkId
    battery.type = battery.type or "battery"
    battery.connected = true
    addId(controller.batteries, batteryId)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
        EnergyRouting.Server.RecordLink(controller.networkId, "battery", batteryId)
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    transmitObjectModData(batteryObj)
    -- Logs de depuración
    print("[EnergyController][Server] ConnectBattery SUCCESS. Batteries count: " .. tostring(countIds(controller.batteries)))
    print("[EnergyController][Server] ConnectBattery controllerId=" .. tostring(controller.networkId)
        .. " batteryId=" .. tostring(batteryId)
        .. " panels=" .. tostring(countIds(controller.panels))
        .. " batteries=" .. tostring(countIds(controller.batteries)))

    local edc = EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC
        and EnergyRouting.Server.GetOrCreateEDC(controller.networkId) or nil

    if edc then
        rebuildEdcBatteriesFromController(edc, controller)
        local entry = findEdcBattery(edc, batteryId)
        if entry then
            local masterId = ensureMasterBattery(edc)
            if masterId == entry.id then
                entry.role = "master"
            else
                entry.role = "slave"
            end
            normalizeBatteryRoles(edc)
            setBatteryRole(batteryObj, entry.role, controller.networkId)
        end
    end

    if edc and EnergyRouting.Server.UpdateEDC then
        EnergyRouting.Server.UpdateEDC(edc) -- debería terminar en BroadcastState
    end

    -- Fallback directo al player (SP/edge cases)
    local target = player or getSpecificPlayer(0)
    if edc and target and EnergyRouting.Server.SendStateToPlayer then
        EnergyRouting.Server.SendStateToPlayer(target, edc)
    end

    local md = getObjectModData(controllerObj)
    print("[EnergyController][Server] controller modData energyController=" .. tostring(type(md.energyController) == "table"))
    sendLinkSync(player, "battery", batteryId, controller.networkId, true, controller.networkId)
    return true
end

function ECS.ConnectWindToController(windObj, controllerObj, player)
    if not windObj or not controllerObj then
        print("[EnergyController][Server] ConnectWind failed: missing wind/controller object")
        return false
    end
    if player and not playerHasCable(player) then
        print("[EnergyController][Server] ConnectWind failed: missing cable")
        return false
    end
    local controller = ensureControllerMeta(controllerObj)
    local wind = ensureWindMeta(windObj)
    if not controller or not wind then
        print("[EnergyController][Server] ConnectWind failed: metadata unavailable")
        return false
    end
    local alreadyLinked = wind.controllerId == controller.networkId
    if wind.controllerId and not alreadyLinked then
        print("[EnergyController][Server] ConnectWind failed: turbine already linked to controller "
            .. tostring(wind.controllerId))
        return false
    end
    local windId = getWindId(windObj)
    if not alreadyLinked then
        local windKind = getWindKind(windObj)
        local maxTurbines = (windKind == "mini")
            and getMiniWindLimit()
            or getClampedLimit(
                EnergyRouting.GetConfigValue("MaxWindTurbines"),
                HARD_MAX_WIND_TURBINES,
                HARD_MAX_WIND_TURBINES
            )
        local linkedCount = countWindIdsByKind(controller.windTurbines, windKind)
        if linkedCount >= maxTurbines then
            print("[EnergyController][Server] ConnectWind failed: max turbines reached for type="
                .. tostring(windKind) .. " ("
                .. tostring(linkedCount) .. "/" .. tostring(maxTurbines) .. ")")
            return false
        end
        local windSq = getSquareFromObj(windObj)
        local controllerSq = getSquareFromObj(controllerObj)
        if not withinRadius(windSq, controllerSq, EnergyNetwork.GetConfigValue("ControllerConnectRadius")) then
            print("[EnergyController][Server] ConnectWind failed: out of range")
            return false
        end
        if player and not consumeCable(player) then
            print("[EnergyController][Server] ConnectWind failed: consume cable failed")
            return false
        end
        wind.controllerId = controller.networkId
    end
    wind.connected = true
    addId(controller.windTurbines, windId)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
        EnergyRouting.Server.RecordLink(controller.networkId, "turbine", windId)
    end
    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    transmitObjectModData(windObj)

    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC and EnergyRouting.Server.UpdateEDC then
        local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
        if edc then
            EnergyRouting.Server.UpdateEDC(edc)
            if EnergyRouting.Server.SendStateToPlayer then
                EnergyRouting.Server.SendStateToPlayer(player, edc)
            end
        end
    end
    sendLinkSync(player, "wind", windId, controller.networkId, true, controller.networkId)
    return true
end

function ECS.ConnectHydroToController(hydroObj, controllerObj, player)
    if not hydroObj or not controllerObj then
        print("[EnergyController][Server] ConnectHydro failed: missing hydro/controller object")
        return false
    end
    if player and not playerHasCable(player) then
        print("[EnergyController][Server] ConnectHydro failed: missing cable")
        return false
    end

    local controller = ensureControllerMeta(controllerObj)
    local hydro = ensureHydroMeta(hydroObj)
    if not controller or not hydro then
        print("[EnergyController][Server] ConnectHydro failed: metadata unavailable")
        return false
    end

    refreshHydroWaterState(hydroObj, hydro)
    if hydro.validWater == false then
        local function squareDebugText(sq)
            if not sq then
                return "nil"
            end
            local sx = sq.getX and sq:getX() or "?"
            local sy = sq.getY and sq:getY() or "?"
            local sz = sq.getZ and sq:getZ() or "?"
            local sprite = getFloorSpriteName(sq) or "nil"
            local amount = safeCall(sq, "getWaterAmount")
            local isWater = safeCall(sq, "isWater")
            local props = safeCall(sq, "getProperties")
            local flagWater = props and props.has and props:has(IsoFlagType.water) or false
            return tostring(sx) .. "," .. tostring(sy) .. "," .. tostring(sz)
                .. " sprite=" .. tostring(sprite)
                .. " waterAmount=" .. tostring(amount)
                .. " isWater=" .. tostring(isWater)
                .. " flagWater=" .. tostring(flagWater)
        end
        local hydroSq = getSquareFromObj(hydroObj)
        local waterSq = getSquareFromRef(hydro.waterSquare)
        local anchorSq = getSquareFromRef(hydro.anchorSquare)
        print("[EnergyController][Server] ConnectHydro debug: hydroSq={"
            .. squareDebugText(hydroSq)
            .. "} waterSq={"
            .. squareDebugText(waterSq)
            .. "} anchorSq={"
            .. squareDebugText(anchorSq)
            .. "} cachedSprite=" .. tostring(hydro.spriteType))
        if player and player.Say then
            player:Say("Colocar cerca de una fuente de agua")
        end
        print("[EnergyController][Server] ConnectHydro failed: invalid water sprite")
        return false
    end

    local alreadyLinked = hydro.controllerId == controller.networkId
    if hydro.controllerId and not alreadyLinked then
        print("[EnergyController][Server] ConnectHydro failed: turbine already linked to controller "
            .. tostring(hydro.controllerId))
        return false
    end

    local hydroId = getHydroId(hydroObj)
    if not hydroId then
        print("[EnergyController][Server] ConnectHydro failed: invalid hydro id")
        return false
    end
    if not alreadyLinked then
        local maxHydro = getClampedLimit(
            EnergyRouting.GetConfigValue("MaxHydroTurbines"),
            HARD_MAX_HYDRO_TURBINES,
            HARD_MAX_HYDRO_TURBINES
        )
        local hydroKind = getHydroKind(hydroObj)
        local linkedCount = countHydroIdsByKind(controller.hydroTurbines, hydroKind)
        if linkedCount >= maxHydro then
            print("[EnergyController][Server] ConnectHydro failed: max hydro reached for type="
                .. tostring(hydroKind) .. " ("
                .. tostring(linkedCount) .. "/" .. tostring(maxHydro) .. ")")
            return false
        end
        local hydroSq = getSquareFromObj(hydroObj)
        local controllerSq = getSquareFromObj(controllerObj)
        if not withinRadius(hydroSq, controllerSq, EnergyNetwork.GetConfigValue("ControllerConnectRadius")) then
            print("[EnergyController][Server] ConnectHydro failed: out of range")
            return false
        end
        if player and not consumeCable(player) then
            print("[EnergyController][Server] ConnectHydro failed: consume cable failed")
            return false
        end
        hydro.controllerId = controller.networkId
    end

    hydro.connected = true
    hydro.isActive = hydro.condition > 0 and hydro.validWater ~= false
    addId(controller.hydroTurbines, hydroId)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
        EnergyRouting.Server.RecordLink(controller.networkId, "hydro", hydroId)
    end

    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    local hydroMd = getObjectModData(hydroObj)
    if hydroMd then
        hydroMd.energy = hydroMd.energy or {}
        hydroMd.energy.type = "hydro"
        hydroMd.energy.controllerId = controller.networkId
        hydroMd.energy.connected = true
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    computeHydroProduction(hydroObj)
    transmitObjectModData(hydroObj)

    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC and EnergyRouting.Server.UpdateEDC then
        local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
        if edc then
            EnergyRouting.Server.UpdateEDC(edc)
            if EnergyRouting.Server.SendStateToPlayer then
                EnergyRouting.Server.SendStateToPlayer(player, edc)
            end
        end
    end
    sendLinkSync(player, "hydro", hydroId, controller.networkId, true, controller.networkId)
    return true
end

function ECS.ConnectWindBatteryToController(windBatteryObj, controllerObj, player)
    if not windBatteryObj or not controllerObj then
        print("[EnergyController][Server] ConnectWindBattery failed: missing battery/controller object")
        return false
    end
    if player and not playerHasCable(player) then
        print("[EnergyController][Server] ConnectWindBattery failed: missing cable")
        return false
    end
    local controller = ensureControllerMeta(controllerObj)
    local battery = ensureWindBatteryMeta(windBatteryObj)
    if not controller or not battery then
        print("[EnergyController][Server] ConnectWindBattery failed: metadata unavailable")
        return false
    end
    local alreadyLinked = battery.controllerId == controller.networkId
    if battery.controllerId and not alreadyLinked then
        print("[EnergyController][Server] ConnectWindBattery failed: battery already linked to controller "
            .. tostring(battery.controllerId))
        return false
    end
    if not alreadyLinked then
        local maxBatteries = getClampedLimit(
            EnergyRouting.GetConfigValue("MaxWindBatteries"),
            HARD_MAX_WIND_BATTERIES,
            HARD_MAX_WIND_BATTERIES
        )
        local linkedCount = countIds(controller.windBatteries)
        if linkedCount >= maxBatteries then
            print("[EnergyController][Server] ConnectWindBattery failed: max batteries reached ("
                .. tostring(linkedCount) .. "/" .. tostring(maxBatteries) .. ")")
            return false
        end
        local batterySq = getSquareFromObj(windBatteryObj)
        local controllerSq = getSquareFromObj(controllerObj)
        if not withinRadius(batterySq, controllerSq, EnergyNetwork.GetConfigValue("ControllerConnectRadius")) then
            print("[EnergyController][Server] ConnectWindBattery failed: out of range")
            return false
        end
        if player and not consumeCable(player) then
            print("[EnergyController][Server] ConnectWindBattery failed: consume cable failed")
            return false
        end
        battery.controllerId = controller.networkId
    end
    local batteryId = getWindBatteryId(windBatteryObj)
    battery.connected = true
    battery.state = "idle"
    addId(controller.windBatteries, batteryId)
    normalizeWindBatteryRoles(controller)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RecordLink then
        EnergyRouting.Server.RecordLink(controller.networkId, "windBattery", batteryId)
    end
    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    transmitObjectModData(windBatteryObj)

    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC and EnergyRouting.Server.UpdateEDC then
        local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
        if edc then
            EnergyRouting.Server.UpdateEDC(edc)
            if EnergyRouting.Server.SendStateToPlayer then
                EnergyRouting.Server.SendStateToPlayer(player, edc)
            end
        end
    end
    sendLinkSync(player, "windBattery", batteryId, controller.networkId, true, controller.networkId)
    return true
end

function ECS.DisconnectPanel(panelObj, controllerObj, player)
    if not panelObj or not controllerObj then
        return false
    end
    local controller = ensureControllerMeta(controllerObj)
    local panel = ensurePanelMeta(panelObj)
    local panelId = getPanelId(panelObj)
    removeId(controller.panels, panelId)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
        EnergyRouting.Server.RemoveLink(controller.networkId, "panel", panelId)
    end
    panel.controllerId = nil
    local panelMd = getObjectModData(panelObj)
    if not panelMd then
        return false
    end
    panelMd.energy = panelMd.energy or {}
    panelMd.energy.type = "solar"
    panelMd.energy.controllerId = nil
    panelMd.energy.connected = false
    local md = getObjectModData(panelObj)
    local energyPanel = md and md.energyPanel or nil
    if energyPanel then
        energyPanel.controllerId = nil
    end
    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    transmitObjectModData(panelObj)
    if player then
        returnCable(player)
    end
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC and EnergyRouting.Server.UpdateEDC then
        local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
        if edc then
            edc.panelCount = countIds(controller.panels)
            edc.batteryCount = countIds(controller.batteries)
            EnergyRouting.Server.UpdateEDC(edc)
        end
    end
    sendLinkSync(player, "panel", panelId, nil, false, controller.networkId)
    return true
end

function ECS.DisconnectBattery(batteryObj, controllerObj, player)
    if not batteryObj or not controllerObj then
        return false
    end
    local controller = ensureControllerMeta(controllerObj)
    local battery = ensureBatteryMeta(batteryObj)
    local batteryId = getBatteryId(batteryObj)
    removeId(controller.batteries, batteryId)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
        EnergyRouting.Server.RemoveLink(controller.networkId, "battery", batteryId)
    end
    battery.controllerId = nil
    battery.role = nil
    battery.type = battery.type or "battery"
    battery.connected = false
    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    transmitObjectModData(batteryObj)
    if player then
        returnCable(player)
    end
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC and EnergyRouting.Server.UpdateEDC then
        local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
        if edc then
            rebuildEdcBatteriesFromController(edc, controller)
            edc.panelCount = countIds(controller.panels)
            edc.batteryCount = countIds(controller.batteries)
            EnergyRouting.Server.UpdateEDC(edc)
        end
    end
    sendLinkSync(player, "battery", batteryId, nil, false, controller.networkId)
    return true
end

function ECS.DisconnectWind(windObj, controllerObj, player)
    if not windObj or not controllerObj then
        return false
    end
    local controller = ensureControllerMeta(controllerObj)
    local wind = ensureWindMeta(windObj)
    local windId = getWindId(windObj)
    removeId(controller.windTurbines, windId)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
        EnergyRouting.Server.RemoveLink(controller.networkId, "turbine", windId)
    end
    wind.controllerId = nil
    wind.connected = false
    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    transmitObjectModData(windObj)
    if player then
        returnCable(player)
    end
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC and EnergyRouting.Server.UpdateEDC then
        local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
        if edc then
            EnergyRouting.Server.UpdateEDC(edc)
        end
    end
    sendLinkSync(player, "wind", windId, nil, false, controller.networkId)
    return true
end

function ECS.DisconnectHydro(hydroObj, controllerObj, player)
    if not hydroObj or not controllerObj then
        return false
    end
    local controller = ensureControllerMeta(controllerObj)
    local hydro = ensureHydroMeta(hydroObj)
    local hydroId = getHydroId(hydroObj)
    removeId(controller.hydroTurbines, hydroId)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
        EnergyRouting.Server.RemoveLink(controller.networkId, "hydro", hydroId)
    end
    hydro.controllerId = nil
    hydro.connected = false
    hydro.currentProduction = 0
    local hydroMd = getObjectModData(hydroObj)
    if hydroMd and hydroMd.energy then
        hydroMd.energy.controllerId = nil
        hydroMd.energy.connected = false
    end
    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    transmitObjectModData(hydroObj)
    if player then
        returnCable(player)
    end
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC and EnergyRouting.Server.UpdateEDC then
        local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
        if edc then
            EnergyRouting.Server.UpdateEDC(edc)
        end
    end
    sendLinkSync(player, "hydro", hydroId, nil, false, controller.networkId)
    return true
end

function ECS.DisconnectWindBattery(windBatteryObj, controllerObj, player)
    if not windBatteryObj or not controllerObj then
        return false
    end
    local controller = ensureControllerMeta(controllerObj)
    local windBattery = ensureWindBatteryMeta(windBatteryObj)
    local windBatteryId = getWindBatteryId(windBatteryObj)
    removeId(controller.windBatteries, windBatteryId)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
        EnergyRouting.Server.RemoveLink(controller.networkId, "windBattery", windBatteryId)
    end
    windBattery.controllerId = nil
    windBattery.role = nil
    windBattery.connected = false
    windBattery.state = "idle"
    local controllerMd = getObjectModData(controllerObj)
    if not controllerMd then
        return false
    end
    controllerMd.energyController = controller
    transmitObjectModData(controllerObj)
    transmitObjectModData(windBatteryObj)
    if player then
        returnCable(player)
    end
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC and EnergyRouting.Server.UpdateEDC then
        local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
        if edc then
            EnergyRouting.Server.UpdateEDC(edc)
        end
    end
    sendLinkSync(player, "windBattery", windBatteryId, nil, false, controller.networkId)
    return true
end

function ECS.OnObjectAdded(obj)
    if ECS.IsWorldControllerObject(obj) or ECS.IsControllerObject(obj) then
        local square = getSquareFromObj(obj)
        if not square then
            return
        end
        local function squareHasAnotherInitializedController(container)
            if not container then
                return false
            end
            for i = 0, container:size() - 1 do
                local other = container:get(i)
                if other ~= obj and (ECS.IsWorldControllerObject(other) or ECS.IsControllerObject(other)) then
                    local md = getObjectModData(other)
                    if md and type(md.energyController) == "table" and md.energyController.networkId then
                        return true
                    end
                end
            end
            return false
        end
        if squareHasAnotherInitializedController(square:getObjects())
            or squareHasAnotherInitializedController(square:getWorldObjects()) then
            logEnergy("Skip duplicate controller init at "
                .. tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ()))
            return
        end
        local initialized = ECS.EnsureControllerForObject(obj)
        local controller = ensureControllerMeta(obj)
        if not controller or not controller.networkId then
            return
        end
        if cacheControllerById then
            cacheControllerById(controller.networkId, obj)
        else
            ECS._controllerLookupCache = ECS._controllerLookupCache or {}
            ECS._controllerLookupCache[controller.networkId] = obj
        end
        if initialized and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinksForController then
            EnergyRouting.Server.RestoreLinksForController(obj)
        end
        if initialized then
            transmitObjectModData(obj)
        end
        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RegisterEDC then
            local sqMd = square:getModData()
            if not (sqMd and sqMd.EnergyRoutingEDCId == controller.networkId) then
                EnergyRouting.Server.RegisterEDC(square, nil, controller.networkId)
            end
        end
        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC
            and EnergyRouting.Server.UpdateEDC then
            local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
            if edc then
                EnergyRouting.Server.UpdateEDC(edc)
            end
        end
    elseif ECS.IsPanelObject(obj) then
        ensurePanelMeta(obj)
        ensureEnergyPanelMeta(obj)
        transmitObjectModData(obj)
        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
            local panelId = getPanelId(obj)
            if panelId and not shouldSkipRestoreForPendingRemoval(obj, "panel", panelId) then
                EnergyRouting.Server.RestoreLinkForObject(obj, "panel", panelId)
            end
        end
    elseif ECS.IsBatteryObject(obj) then
        ensureBatteryMeta(obj)
        transmitObjectModData(obj)
        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
            local batteryId = getBatteryId(obj)
            if batteryId and not shouldSkipRestoreForPendingRemoval(obj, "battery", batteryId) then
                EnergyRouting.Server.RestoreLinkForObject(obj, "battery", batteryId)
            end
        end
    elseif ECS.IsWindObject(obj) then
        ensureWindMeta(obj)
        transmitObjectModData(obj)
        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
            local windId = getWindId(obj)
            if windId and not shouldSkipRestoreForPendingRemoval(obj, "turbine", windId) then
                EnergyRouting.Server.RestoreLinkForObject(obj, "turbine", windId)
            end
        end
    elseif ECS.IsHydroObject(obj) then
        ensureHydroMeta(obj)
        transmitObjectModData(obj)
        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
            local hydroId = getHydroId(obj)
            if hydroId and not shouldSkipRestoreForPendingRemoval(obj, "hydro", hydroId) then
                EnergyRouting.Server.RestoreLinkForObject(obj, "hydro", hydroId)
            end
        end
    elseif ECS.IsWindBatteryObject(obj) then
        ensureWindBatteryMeta(obj)
        transmitObjectModData(obj)
        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RestoreLinkForObject then
            local windBatteryId = getWindBatteryId(obj)
            if windBatteryId and not shouldSkipRestoreForPendingRemoval(obj, "windBattery", windBatteryId) then
                EnergyRouting.Server.RestoreLinkForObject(obj, "windBattery", windBatteryId)
            end
        end
    end
end

local function objectMatchesId(obj, prefix, id)
    if not obj or not id then
        return false
    end
    if prefix == "panel" then
        return getPanelId(obj) == id
    end
    if prefix == "battery" then
        return getBatteryId(obj) == id
    end
    if prefix == "wind" then
        return getWindId(obj) == id
    end
    if prefix == "wind_battery" then
        return getWindBatteryId(obj) == id
    end
    if prefix == "hydro" then
        return getHydroId(obj) == id
    end
    if prefix == "network" then
        return getControllerId(obj) == id
    end
    return false
end

local function findObjectById(id, prefix, predicate)
    local x, y, z = EnergyNetwork.ParseCoordsFromId(id, prefix)
    if not x then
        return nil
    end
    local square = getSquare(x, y, z)
    if not square then
        return nil
    end

    local worldObjects = square:getWorldObjects()
    if worldObjects then
        for i = 0, worldObjects:size() - 1 do
            local obj = worldObjects:get(i)
            if predicate(obj) then
                if objectMatchesId(obj, prefix, id) then
                    return obj
                end
            end
        end
    end

    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if predicate(obj) then
                if objectMatchesId(obj, prefix, id) then
                    return obj
                end
            end
        end
    end

    if square.getSpecialObjects then
        local specialObjects = square:getSpecialObjects()
        if specialObjects then
            for i = 0, specialObjects:size() - 1 do
                local obj = specialObjects:get(i)
                if predicate(obj) then
                    if objectMatchesId(obj, prefix, id) then
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

ECS._controllerLookupCache = ECS._controllerLookupCache or {}

local function isValidControllerLookup(obj, controllerId)
    if not obj or not controllerId then
        return false
    end
    if not (ECS.IsControllerObject(obj) or ECS.IsWorldControllerObject(obj) or isControllerPrototypeObject(obj)) then
        return false
    end
    local md = getObjectModData(obj)
    return md and type(md.energyController) == "table" and md.energyController.networkId == controllerId
end

local function getCachedControllerById(controllerId)
    local cache = ECS._controllerLookupCache
    if type(cache) ~= "table" then
        return nil
    end
    local cached = cache[controllerId]
    if isValidControllerLookup(cached, controllerId) then
        return cached
    end
    cache[controllerId] = nil
    return nil
end

cacheControllerById = function(controllerId, controllerObj)
    if type(controllerId) ~= "string" or not controllerObj then
        return
    end
    ECS._controllerLookupCache = ECS._controllerLookupCache or {}
    ECS._controllerLookupCache[controllerId] = controllerObj
end

local function clearCachedControllerByObject(obj)
    local cache = ECS._controllerLookupCache
    if type(cache) ~= "table" or not obj then
        return
    end
    for cachedId, cachedObj in pairs(cache) do
        if cachedObj == obj then
            cache[cachedId] = nil
        end
    end
end

local function resolveControllerFromPrototype(obj, controllerId)
    if not obj then
        return nil
    end
    if ECS.EnsureControllerForObject then
        ECS.EnsureControllerForObject(obj)
    end
    local md = getObjectModData(obj)
    if not md then
        return nil
    end
    if not md or type(md.energyController) ~= "table" then
        return nil
    end
    if md.energyController.networkId ~= controllerId then
        return nil
    end
    return obj
end

local function scanControllerContainer(container, controllerId, prototypeState)
    if not container then
        return nil
    end
    for i = 0, container:size() - 1 do
        local obj = container:get(i)
        if ECS.IsControllerObject(obj) or ECS.IsWorldControllerObject(obj) or isControllerPrototypeObject(obj) then
            local md = getObjectModData(obj)
            if md and type(md.energyController) == "table" and md.energyController.networkId == controllerId then
                return obj
            end
            if prototypeState and not prototypeState.value and isControllerPrototypeObject(obj) then
                prototypeState.value = obj
            end
        end
    end
    return nil
end

local function findControllerByNetworkId(controllerId)
    local cell = getCell()
    if not cell or not cell.getObjectList then
        return nil
    end
    local objects = cell:getObjectList()
    if not objects then
        return nil
    end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if ECS.IsControllerObject(obj) or ECS.IsWorldControllerObject(obj) or isControllerPrototypeObject(obj) then
            local md = getObjectModData(obj)
            if md and type(md.energyController) == "table" and md.energyController.networkId == controllerId then
                return obj
            end
        end
    end
    return nil
end

getControllerById = function(controllerId)
    if type(controllerId) ~= "string" then
        return nil
    end
    local cached = getCachedControllerById(controllerId)
    if cached then
        return cached
    end

    local x, y, z = parseControllerCoordsFromId(controllerId)
    if x then
        local square = getSquare(x, y, z)
        if square then
            local prototypeState = { value = nil }
            -- Prefer world objects first to avoid oscillating between different square representations in MP.
            local found = scanControllerContainer(square:getWorldObjects(), controllerId, prototypeState)
            if not found then
                found = scanControllerContainer(square:getObjects(), controllerId, prototypeState)
            end
            if not found and prototypeState.value then
                found = resolveControllerFromPrototype(prototypeState.value, controllerId)
            end
            if found then
                cacheControllerById(controllerId, found)
                return found
            end
        end
        -- network_* ids always carry coordinates; avoid global object-list scans on miss.
        return nil
    end

    local fallback = findControllerByNetworkId(controllerId)
    if fallback then
        local resolved = resolveControllerFromPrototype(fallback, controllerId)
        if resolved then
            cacheControllerById(controllerId, resolved)
            return resolved
        end
    end
    return nil
end

ECS.GetControllerById = getControllerById

local function getControllerObjForCommand(controllerId)
    if type(controllerId) ~= "string" then
        return nil
    end
    local controllerObj = getControllerById(controllerId)
    if controllerObj then
        return controllerObj
    end

    local x, y, z = parseControllerCoordsFromId(controllerId)
    if not x then
        return nil
    end
    local square = getSquare(x, y, z)
    if not square then
        return nil
    end

    local function tryInitFromContainer(container)
        if not container then
            return nil
        end
        for i = 0, container:size() - 1 do
            local obj = container:get(i)
            if ECS.IsControllerObject(obj) or ECS.IsWorldControllerObject(obj) or isControllerPrototypeObject(obj) then
                if ECS.EnsureControllerForObject then
                    ECS.EnsureControllerForObject(obj)
                end
                local md = getObjectModData(obj)
                if md and md.energyController and md.energyController.networkId == controllerId then
                    cacheControllerById(controllerId, obj)
                    return obj
                end
            end
        end
        return nil
    end

    controllerObj = tryInitFromContainer(square:getWorldObjects())
    if controllerObj then
        return controllerObj
    end
    controllerObj = tryInitFromContainer(square:getObjects())
    if controllerObj then
        return controllerObj
    end

    return getControllerById(controllerId)
end

function ECS.GetPanelById(panelId)
    return findObjectById(panelId, "panel", ECS.IsPanelObject)
end

function ECS.GetBatteryById(batteryId)
    return findObjectById(batteryId, "battery", ECS.IsBatteryObject)
end

function ECS.GetWindById(windId)
    return findObjectById(windId, "wind", ECS.IsWindObject)
end

function ECS.GetWindBatteryById(windBatteryId)
    return findObjectById(windBatteryId, "wind_battery", ECS.IsWindBatteryObject)
end

function ECS.GetHydroById(hydroId)
    return findObjectById(hydroId, "hydro", ECS.IsHydroObject)
end

local function getRepairProducerObject(args)
    if type(args) ~= "table" then
        return nil, nil
    end

    if args.producerType == "panel" and args.producerId then
        return findObjectById(args.producerId, "panel", ECS.IsPanelObject), "panel"
    end
    if args.producerType == "wind" and args.producerId then
        return findObjectById(args.producerId, "wind", ECS.IsWindObject), "wind"
    end
    if args.producerType == "hydro" and args.producerId then
        return findObjectById(args.producerId, "hydro", ECS.IsHydroObject), "hydro"
    end

    if args.panelId then
        return findObjectById(args.panelId, "panel", ECS.IsPanelObject), "panel"
    end
    if args.windId then
        return findObjectById(args.windId, "wind", ECS.IsWindObject), "wind"
    end
    if args.hydroId then
        return findObjectById(args.hydroId, "hydro", ECS.IsHydroObject), "hydro"
    end
    return nil, nil
end

local function getProducerControllerId(obj, producerType)
    local md = getObjectModData(obj)
    if not md then
        return nil
    end
    if producerType == "panel" then
        return (md.panel and md.panel.controllerId)
            or (md.energyPanel and md.energyPanel.controllerId)
            or (md.energy and md.energy.controllerId)
            or nil
    end
    if producerType == "wind" then
        return (md.wind and md.wind.controllerId) or nil
    end
    if producerType == "hydro" then
        return (md.hydro and md.hydro.controllerId)
            or (md.energy and md.energy.controllerId)
            or nil
    end
    return nil
end

local function validateControllerLinks(controllerObj)
    local controller = ensureControllerMeta(controllerObj)
    local controllerSq = getSquareFromObj(controllerObj)
    if not controllerSq then
        return controller
    end

    local radius = EnergyNetwork.GetConfigValue("ControllerConnectRadius")
    local panels = controller.panels or {}
    local currentPanels = collectIds(panels)
    for k in pairs(panels) do
        panels[k] = nil
    end
    for _, panelId in ipairs(currentPanels) do
        local px, py, pz = EnergyNetwork.ParseCoordsFromId(panelId, "panel")
        if px then
            local panelSq = getSquare(px, py, pz)
            if not panelSq then
                addId(panels, panelId)
            else
                local panelObj = ECS.FindObjectOnSquare(panelSq, ECS.IsPanelObject)
                if panelObj then
                    local panelMd = getObjectModData(panelObj)
                    local linkedId = panelMd and ((panelMd.panel and panelMd.panel.controllerId)
                        or (panelMd.energyPanel and panelMd.energyPanel.controllerId)
                        or (panelMd.energy and panelMd.energy.controllerId)) or nil
                    if withinRadius(panelSq, controllerSq, radius)
                        and linkedId == controller.networkId then
                        addId(panels, panelId)
                    else
                        local panel = ensurePanelMeta(panelObj)
                        panel.controllerId = nil
                        transmitObjectModData(panelObj)
                        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                            EnergyRouting.Server.RemoveLink(controller.networkId, "panel", panelId)
                        end
                        returnCable(nil)
                    end
                else
                    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controller.networkId, "panel", panelId)
                    end
                end
            end
        end
    end
    controller.panels = panels
    local panelCoreLimit = getClampedLimit(
        EnergyNetwork.GetConfigValue("MaxPanels"),
        HARD_MAX_PANELS,
        HARD_MAX_PANELS
    )
    local panelMiniLimit = getMiniPanelLimit()
    local keptPanelsByKind = { core = 0, mini = 0 }
    for _, panelId in ipairs(collectIds(controller.panels)) do
        local panelObj = findObjectById(panelId, "panel", ECS.IsPanelObject)
        local kind = getPanelKind(panelObj)
        local limit = (kind == "mini") and panelMiniLimit or panelCoreLimit
        keptPanelsByKind[kind] = (keptPanelsByKind[kind] or 0) + 1
        if limit >= 0 and keptPanelsByKind[kind] > limit then
            removeId(controller.panels, panelId)
            if panelObj then
                local panel = ensurePanelMeta(panelObj)
                panel.controllerId = nil
                local panelMd = getObjectModData(panelObj)
                if panelMd and panelMd.energy then
                    panelMd.energy.controllerId = nil
                    panelMd.energy.connected = false
                end
                if panelMd and panelMd.energyPanel then
                    panelMd.energyPanel.controllerId = nil
                end
                transmitObjectModData(panelObj)
            end
            if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                EnergyRouting.Server.RemoveLink(controller.networkId, "panel", panelId)
            end
        end
    end

    local batteries = controller.batteries or {}
    local currentBatteries = collectIds(batteries)
    for k in pairs(batteries) do
        batteries[k] = nil
    end
    for _, batteryId in ipairs(currentBatteries) do
        local bx, by, bz = EnergyNetwork.ParseCoordsFromId(batteryId, "battery")
        if bx then
            local batterySq = getSquare(bx, by, bz)
            if not batterySq then
                addId(batteries, batteryId)
            else
                local batteryObj = ECS.FindObjectOnSquare(batterySq, ECS.IsBatteryObject)
                if batteryObj then
                    local batteryMd = getObjectModData(batteryObj)
                    if withinRadius(batterySq, controllerSq, radius)
                        and batteryMd and batteryMd.energy and batteryMd.energy.controllerId == controller.networkId then
                        addId(batteries, batteryId)
                    else
                        local battery = ensureBatteryMeta(batteryObj)
                        battery.controllerId = nil
                        battery.role = nil
                        transmitObjectModData(batteryObj)
                        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                            EnergyRouting.Server.RemoveLink(controller.networkId, "battery", batteryId)
                        end
                        returnCable(nil)
                    end
                else
                    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controller.networkId, "battery", batteryId)
                    end
                end
            end
        end
    end
    controller.batteries = batteries

    local turbines = controller.windTurbines or {}
    local currentTurbines = collectIds(turbines)
    for k in pairs(turbines) do
        turbines[k] = nil
    end
    for _, windId in ipairs(currentTurbines) do
        local wx, wy, wz = EnergyNetwork.ParseCoordsFromId(windId, "wind")
        if wx then
            local windSq = getSquare(wx, wy, wz)
            if not windSq then
                addId(turbines, windId)
            else
                local windObj = ECS.FindObjectOnSquare(windSq, ECS.IsWindObject)
                if windObj then
                    local windMd = getObjectModData(windObj)
                    local linkedId = windMd and windMd.wind and windMd.wind.controllerId or nil
                    if withinRadius(windSq, controllerSq, radius) and linkedId == controller.networkId then
                        addId(turbines, windId)
                    else
                        local wind = ensureWindMeta(windObj)
                        wind.controllerId = nil
                        wind.connected = false
                        transmitObjectModData(windObj)
                        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                            EnergyRouting.Server.RemoveLink(controller.networkId, "turbine", windId)
                        end
                        returnCable(nil)
                    end
                else
                    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controller.networkId, "turbine", windId)
                    end
                end
            end
        end
    end
    controller.windTurbines = turbines
    local windCoreLimit = getClampedLimit(
        EnergyRouting.GetConfigValue("MaxWindTurbines"),
        HARD_MAX_WIND_TURBINES,
        HARD_MAX_WIND_TURBINES
    )
    local windMiniLimit = getMiniWindLimit()
    local keptWindByKind = { core = 0, mini = 0 }
    for _, windId in ipairs(collectIds(controller.windTurbines)) do
        local windObj = findObjectById(windId, "wind", ECS.IsWindObject)
        local kind = getWindKind(windObj)
        local limit = (kind == "mini") and windMiniLimit or windCoreLimit
        keptWindByKind[kind] = (keptWindByKind[kind] or 0) + 1
        if limit >= 0 and keptWindByKind[kind] > limit then
            removeId(controller.windTurbines, windId)
            if windObj then
                local wind = ensureWindMeta(windObj)
                wind.controllerId = nil
                wind.connected = false
                transmitObjectModData(windObj)
            end
            if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                EnergyRouting.Server.RemoveLink(controller.networkId, "turbine", windId)
            end
        end
    end

    local hydroTurbines = controller.hydroTurbines or {}
    local currentHydroTurbines = collectIds(hydroTurbines)
    for k in pairs(hydroTurbines) do
        hydroTurbines[k] = nil
    end
    for _, hydroId in ipairs(currentHydroTurbines) do
        local hx, hy, hz = EnergyNetwork.ParseCoordsFromId(hydroId, "hydro")
        if hx then
            local hydroSq = getSquare(hx, hy, hz)
            if not hydroSq then
                addId(hydroTurbines, hydroId)
            else
                local hydroObj = ECS.FindObjectOnSquare(hydroSq, ECS.IsHydroObject)
                if hydroObj then
                    local hydroMd = getObjectModData(hydroObj)
                    local linkedId = hydroMd and hydroMd.hydro and hydroMd.hydro.controllerId or nil
                    local hydroMeta = ensureHydroMeta(hydroObj)
                    local inValidWater = hydroMeta and hydroMeta.validWater ~= false
                    if withinRadius(hydroSq, controllerSq, radius) and linkedId == controller.networkId and inValidWater then
                        addId(hydroTurbines, hydroId)
                    else
                        if hydroMeta then
                            hydroMeta.controllerId = nil
                            hydroMeta.connected = false
                            hydroMeta.currentProduction = 0
                        end
                        transmitObjectModData(hydroObj)
                        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                            EnergyRouting.Server.RemoveLink(controller.networkId, "hydro", hydroId)
                        end
                        returnCable(nil)
                    end
                else
                    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controller.networkId, "hydro", hydroId)
                    end
                end
            end
        end
    end
    controller.hydroTurbines = hydroTurbines
    local hydroLimit = getClampedLimit(
        EnergyRouting.GetConfigValue("MaxHydroTurbines"),
        HARD_MAX_HYDRO_TURBINES,
        HARD_MAX_HYDRO_TURBINES
    )
    if hydroLimit >= 0 then
        local keptByKind = { core = 0, mini = 0 }
        for _, hydroId in ipairs(collectIds(controller.hydroTurbines)) do
            local hydroObj = findObjectById(hydroId, "hydro", ECS.IsHydroObject)
            local kind = getHydroKind(hydroObj)
            keptByKind[kind] = (keptByKind[kind] or 0) + 1
            if keptByKind[kind] > hydroLimit then
                removeId(controller.hydroTurbines, hydroId)
                if hydroObj then
                    local hydroMeta = ensureHydroMeta(hydroObj)
                    if hydroMeta then
                        hydroMeta.controllerId = nil
                        hydroMeta.connected = false
                        hydroMeta.currentProduction = 0
                    end
                    transmitObjectModData(hydroObj)
                end
                if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                    EnergyRouting.Server.RemoveLink(controller.networkId, "hydro", hydroId)
                end
            end
        end
    end

    local windBatteries = controller.windBatteries or {}
    local currentWindBatteries = collectIds(windBatteries)
    for k in pairs(windBatteries) do
        windBatteries[k] = nil
    end
    for _, windBatteryId in ipairs(currentWindBatteries) do
        local bx, by, bz = EnergyNetwork.ParseCoordsFromId(windBatteryId, "wind_battery")
        if bx then
            local batterySq = getSquare(bx, by, bz)
            if not batterySq then
                addId(windBatteries, windBatteryId)
            else
                local batteryObj = ECS.FindObjectOnSquare(batterySq, ECS.IsWindBatteryObject)
                if batteryObj then
                    local batteryMd = getObjectModData(batteryObj)
                    local linkedId = batteryMd and batteryMd.windBattery and batteryMd.windBattery.controllerId or nil
                    if withinRadius(batterySq, controllerSq, radius) and linkedId == controller.networkId then
                        addId(windBatteries, windBatteryId)
                    else
                        local windBattery = ensureWindBatteryMeta(batteryObj)
                        windBattery.controllerId = nil
                        windBattery.role = nil
                        windBattery.connected = false
                        windBattery.state = "idle"
                        transmitObjectModData(batteryObj)
                        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                            EnergyRouting.Server.RemoveLink(controller.networkId, "windBattery", windBatteryId)
                        end
                        returnCable(nil)
                    end
                else
                    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controller.networkId, "windBattery", windBatteryId)
                    end
                end
            end
        end
    end
    controller.windBatteries = windBatteries

    -- Backfill if lists are empty (common after reload if objects load later).
    if countIds(controller.panels) == 0 then
        for x = controllerSq:getX() - radius, controllerSq:getX() + radius do
            for y = controllerSq:getY() - radius, controllerSq:getY() + radius do
                local sq = getSquare(x, y, controllerSq:getZ())
                if sq then
                    local panelObj = ECS.FindObjectOnSquare(sq, ECS.IsPanelObject)
                    if panelObj then
                        local panelMd = getObjectModData(panelObj)
                        local linkedId = panelMd and ((panelMd.panel and panelMd.panel.controllerId)
                            or (panelMd.energyPanel and panelMd.energyPanel.controllerId)
                            or (panelMd.energy and panelMd.energy.controllerId)) or nil
                        if linkedId == controller.networkId then
                            addId(controller.panels, getPanelId(panelObj))
                        end
                    end
                end
            end
        end
    end

    if countIds(controller.batteries) == 0 then
        for x = controllerSq:getX() - radius, controllerSq:getX() + radius do
            for y = controllerSq:getY() - radius, controllerSq:getY() + radius do
                local sq = getSquare(x, y, controllerSq:getZ())
                if sq then
                    local batteryObj = ECS.FindObjectOnSquare(sq, ECS.IsBatteryObject)
                    if batteryObj then
                        local batteryMd = getObjectModData(batteryObj)
                        if batteryMd and batteryMd.energy and batteryMd.energy.controllerId == controller.networkId then
                            addId(controller.batteries, getBatteryId(batteryObj))
                        end
                    end
                end
            end
        end
    end

    if countIds(controller.windTurbines) == 0 then
        for x = controllerSq:getX() - radius, controllerSq:getX() + radius do
            for y = controllerSq:getY() - radius, controllerSq:getY() + radius do
                local sq = getSquare(x, y, controllerSq:getZ())
                if sq then
                    local windObj = ECS.FindObjectOnSquare(sq, ECS.IsWindObject)
                    if windObj then
                        local windMd = getObjectModData(windObj)
                        if windMd and windMd.wind and windMd.wind.controllerId == controller.networkId then
                            addId(controller.windTurbines, getWindId(windObj))
                        end
                    end
                end
            end
        end
    end

    if countIds(controller.hydroTurbines) == 0 then
        for x = controllerSq:getX() - radius, controllerSq:getX() + radius do
            for y = controllerSq:getY() - radius, controllerSq:getY() + radius do
                local sq = getSquare(x, y, controllerSq:getZ())
                if sq then
                    local hydroObj = ECS.FindObjectOnSquare(sq, ECS.IsHydroObject)
                    if hydroObj then
                        local hydroMd = getObjectModData(hydroObj)
                        local hydroMeta = ensureHydroMeta(hydroObj)
                        if hydroMeta and hydroMeta.validWater ~= false
                            and hydroMd and hydroMd.hydro and hydroMd.hydro.controllerId == controller.networkId then
                            addId(controller.hydroTurbines, getHydroId(hydroObj))
                        end
                    end
                end
            end
        end
    end

    if countIds(controller.windBatteries) == 0 then
        for x = controllerSq:getX() - radius, controllerSq:getX() + radius do
            for y = controllerSq:getY() - radius, controllerSq:getY() + radius do
                local sq = getSquare(x, y, controllerSq:getZ())
                if sq then
                    local windBatteryObj = ECS.FindObjectOnSquare(sq, ECS.IsWindBatteryObject)
                    if windBatteryObj then
                        local windBatteryMd = getObjectModData(windBatteryObj)
                        if windBatteryMd and windBatteryMd.windBattery and windBatteryMd.windBattery.controllerId == controller.networkId then
                            addId(controller.windBatteries, getWindBatteryId(windBatteryObj))
                        end
                    end
                end
            end
        end
    end

    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.MergeLinksFromController then
        EnergyRouting.Server.MergeLinksFromController(controller)
    end

    normalizeWindBatteryRoles(controller)

    return controller
end

local function distributeStorage(controller, totalStorage)
    local remaining = totalStorage
    local batteryIds = collectIds(controller.batteries)
    for _, batteryId in ipairs(batteryIds) do
        local batteryObj = findObjectById(batteryId, "battery", ECS.IsBatteryObject)
        if batteryObj then
            local battery = ensureBatteryMeta(batteryObj)
            local capacity = battery.capacity or EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
            local assigned = math.min(capacity, remaining)
            battery.storedEnergy = assigned
            remaining = remaining - assigned
            transmitObjectModData(batteryObj)
        end
    end
end

local _coreProducerDefinitionsRegistered = false

local function normalizeProducerCategory(category)
    local key = string.lower(tostring(category or "other"))
    if key == "solar" or key == "panel" then
        return "solar"
    end
    if key == "wind" or key == "turbine" or key == "aero" then
        return "wind"
    end
    if key == "hydro" or key == "hydraulic" or key == "water" then
        return "hydro"
    end
    return "other"
end

local function ensureCoreProducerDefinitionsRegistered()
    if _coreProducerDefinitionsRegistered then
        return
    end
    if not EnergyRouting or not EnergyRouting.API then
        return
    end
    if not EnergyRouting.Registry or not EnergyRouting.Registry.GetProducer then
        return
    end
    ensureCoreBatteryDefinitionsRegistered()
    if not EnergyRouting.Registry.GetProducer("core_solar_panel") then
        EnergyRouting.API.RegisterProducer({
            id = "core_solar_panel",
            displayName = "ERS Core Solar Panel",
            category = "solar",
            controllerListKey = "panels",
            idPrefix = "panel",
            IsObject = ECS.IsPanelObject,
            sortOrder = 10,
            CalculateOutput = function(producerObject, weather, network, context)
                local sunFactor = context and context.solarEfficiency or getSolarEfficiency()
                local bonus = context and context.solarNetworkBonus or 1
                return computePanelProduction(producerObject, sunFactor, bonus)
            end,
        })
    end
    if not EnergyRouting.Registry.GetProducer("core_wind_turbine") then
        EnergyRouting.API.RegisterProducer({
            id = "core_wind_turbine",
            displayName = "ERS Core Wind Turbine",
            category = "wind",
            controllerListKey = "windTurbines",
            idPrefix = "wind",
            IsObject = ECS.IsWindObject,
            sortOrder = 20,
            CalculateOutput = function(producerObject, weather, network, context)
                local windWeather = (context and context.windWeather) or getWindWeatherSnapshot()
                computeWindEfficiencyForCurrentWeather(producerObject, windWeather)
                local bonus = context and context.windNetworkBonus or 1
                return computeWindProduction(producerObject, windWeather and windWeather.multiplier or nil, bonus)
            end,
        })
    end
    if not EnergyRouting.Registry.GetProducer("core_hydro_turbine") then
        EnergyRouting.API.RegisterProducer({
            id = "core_hydro_turbine",
            displayName = "ERS Core Hydro Turbine",
            category = "hydro",
            controllerListKey = "hydroTurbines",
            idPrefix = "hydro",
            IsObject = ECS.IsHydroObject,
            sortOrder = 30,
            CalculateOutput = function(producerObject)
                return computeHydroProduction(producerObject)
            end,
        })
    end
    _coreProducerDefinitionsRegistered = true
end

local function buildProducerRuntimeContext(controller)
    local context = {}

    context.solarEfficiency = getSolarEfficiency()
    local connectedPanelCount = countPanelIdsByKind(controller and controller.panels or {}, "core")
    local maxPanels = getClampedLimit(
        EnergyNetwork.GetConfigValue("MaxPanels"),
        HARD_MAX_PANELS,
        HARD_MAX_PANELS
    )
    local connectedPanelsCapped = math.min(connectedPanelCount, maxPanels)
    local solarBonusCount = math.max(0, connectedPanelsCapped - 1)
    context.solarBonusPercent = solarBonusCount * 25
    context.solarNetworkBonus = 1 + (context.solarBonusPercent / 100)

    context.windWeather = getWindWeatherSnapshot()
    local connectedWindCount = countWindIdsByKind(controller and controller.windTurbines or {}, "core")
    local maxWindTurbines = getClampedLimit(
        EnergyRouting.GetConfigValue("MaxWindTurbines"),
        HARD_MAX_WIND_TURBINES,
        HARD_MAX_WIND_TURBINES
    )
    local connectedWindCapped = math.min(connectedWindCount, maxWindTurbines)
    local windBonusCount = math.max(0, connectedWindCapped - 1)
    context.windBonusPercent = windBonusCount * 25
    context.windNetworkBonus = 1 + (context.windBonusPercent / 100)

    context.weatherSnapshot = (EnergyRouting and EnergyRouting.Weather and EnergyRouting.Weather.GetWeatherSnapshot)
        and EnergyRouting.Weather.GetWeatherSnapshot()
        or { label = "Unknown" }
    context.network = {
        id = controller and controller.networkId or nil,
        controller = controller,
    }
    return context
end

local function collectObjectsForProducer(definition, controller, context)
    local objects = {}
    if type(definition) ~= "table" then
        return objects
    end

    if type(definition.CollectObjects) == "function" then
        local ok, result = pcall(definition.CollectObjects, definition, controller, context)
        if ok and type(result) == "table" then
            return result
        end
        if not ok then
            print("[ERS][Framework] CollectObjects error producer=" .. tostring(definition.id)
                .. " err=" .. tostring(result))
        end
        return objects
    end

    local listKey = definition.controllerListKey
    local idPrefix = definition.idPrefix
    local predicate = definition.IsObject
    if type(listKey) ~= "string" or type(idPrefix) ~= "string" or type(predicate) ~= "function" then
        return objects
    end

    local ids = collectIds(controller and controller[listKey] or {})
    for _, objectId in ipairs(ids) do
        local obj = findObjectById(objectId, idPrefix, predicate)
        if obj then
            table.insert(objects, obj)
        end
    end
    return objects
end

local function runProducerDefinition(definition, controller, context)
    local category = normalizeProducerCategory(definition and (definition.category or definition.kind or definition.energyType))
    local result = {
        id = definition and definition.id or "unknown",
        category = category,
        count = 0,
        production = 0,
    }
    if type(definition) ~= "table" or type(definition.CalculateOutput) ~= "function" then
        return result
    end

    local objects = collectObjectsForProducer(definition, controller, context)
    for _, obj in ipairs(objects) do
        if obj then
            local ok, output = pcall(
                definition.CalculateOutput,
                obj,
                context and context.weatherSnapshot or nil,
                context and context.network or nil,
                context,
                definition
            )
            if ok then
                local watts = tonumber(output) or 0
                if watts < 0 then
                    watts = 0
                end
                result.count = result.count + 1
                result.production = result.production + math.floor(watts + 0.5)
            else
                print("[ERS][Framework] CalculateOutput error producer=" .. tostring(definition.id)
                    .. " err=" .. tostring(output))
            end
        end
    end

    return result
end

local function computeControllerProductionByRegistry(controller, context)
    ensureCoreProducerDefinitionsRegistered()
    local snapshot = {
        totalProduction = 0,
        solarProduction = 0,
        windProduction = 0,
        hydroProduction = 0,
        otherProduction = 0,
        panelCount = 0,
        windCount = 0,
        hydroCount = 0,
        otherCount = 0,
        byProducer = {},
    }
    if not EnergyRouting or not EnergyRouting.Registry or not EnergyRouting.Registry.GetAllProducers then
        return snapshot
    end

    local producers = EnergyRouting.Registry.GetAllProducers()
    for _, definition in ipairs(producers or {}) do
        local producerResult = runProducerDefinition(definition, controller, context)
        snapshot.byProducer[producerResult.id] = producerResult
        snapshot.totalProduction = snapshot.totalProduction + producerResult.production
        if producerResult.category == "solar" then
            snapshot.solarProduction = snapshot.solarProduction + producerResult.production
            snapshot.panelCount = snapshot.panelCount + producerResult.count
        elseif producerResult.category == "wind" then
            snapshot.windProduction = snapshot.windProduction + producerResult.production
            snapshot.windCount = snapshot.windCount + producerResult.count
        elseif producerResult.category == "hydro" then
            snapshot.hydroProduction = snapshot.hydroProduction + producerResult.production
            snapshot.hydroCount = snapshot.hydroCount + producerResult.count
        else
            snapshot.otherProduction = snapshot.otherProduction + producerResult.production
            snapshot.otherCount = snapshot.otherCount + producerResult.count
        end
    end
    return snapshot
end

function ECS.TickController(controllerObj)
    if not controllerObj then
        return nil
    end

    ECS.EnsureControllerForObject(controllerObj)
    local controller = validateControllerLinks(controllerObj)
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC then
        local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
        if edc then
            rebuildEdcBatteriesFromController(edc, controller)
        end
    end
    local controllerSq = getSquareFromObj(controllerObj)
    if controllerSq and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RegisterEDC then
        local sqMd = controllerSq:getModData()
        if not (sqMd and sqMd.EnergyRoutingEDCId) then
            EnergyRouting.Server.RegisterEDC(controllerSq, nil, controller.networkId)
        end
    end
    local runtimeContext = buildProducerRuntimeContext(controller)
    local productionSnapshot = computeControllerProductionByRegistry(controller, runtimeContext)
    local efficiency = runtimeContext.solarEfficiency
    local solarBonusPercent = runtimeContext.solarBonusPercent or 0
    local windBonusPercent = runtimeContext.windBonusPercent or 0
    local windNetworkBonus = runtimeContext.windNetworkBonus or 1
    local weatherSnapshot = runtimeContext.weatherSnapshot or { label = "Unknown" }
    local panelCount = tonumber(productionSnapshot.panelCount) or 0
    local windCount = tonumber(productionSnapshot.windCount) or 0
    local hydroCount = tonumber(productionSnapshot.hydroCount) or 0
    local otherCount = tonumber(productionSnapshot.otherCount) or 0
    local solarProduction = tonumber(productionSnapshot.solarProduction) or 0
    local windProduction = tonumber(productionSnapshot.windProduction) or 0
    local hydroProduction = tonumber(productionSnapshot.hydroProduction) or 0
    local otherProduction = tonumber(productionSnapshot.otherProduction) or 0

    local solarCapacity = 0
    local solarStorage = 0
    local batteryIds = collectIds(controller.batteries)
    for _, batteryId in ipairs(batteryIds) do
        local batteryObj = findObjectById(batteryId, "battery", ECS.IsBatteryObject)
        if batteryObj then
            local battery = ensureBatteryMeta(batteryObj)
            local capacity = battery.capacity or EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
            solarCapacity = solarCapacity + capacity
            solarStorage = solarStorage + (battery.storedEnergy or 0)
        end
    end

    local windCapacity = 0
    local windStorage = 0
    local windBatteryIds = collectIds(controller.windBatteries)
    for _, windBatteryId in ipairs(windBatteryIds) do
        local windBatteryObj = findObjectById(windBatteryId, "wind_battery", ECS.IsWindBatteryObject)
        if windBatteryObj then
            local battery = ensureWindBatteryMeta(windBatteryObj)
            local capacity = battery.capacity or (EnergyRouting.GetConfigValue("BaseWindBatteryCapacity") or 100000)
            windCapacity = windCapacity + capacity
            windStorage = windStorage + (battery.charge or 0)
        end
    end

    -- Battery flow is handled after demand is known in ECS.ApplyConsumption.
    local newSolarStorage = EnergyNetwork.Clamp(solarStorage, 0, solarCapacity)
    local newWindStorage = EnergyNetwork.Clamp(windStorage, 0, windCapacity)
    local totalProduction = tonumber(productionSnapshot.totalProduction) or (solarProduction + windProduction + hydroProduction + otherProduction)
    local totalStorage = newSolarStorage + newWindStorage
    local totalCapacity = solarCapacity + windCapacity

    controller.totalProduction = totalProduction
    controller.totalStorage = totalStorage
    controller.totalCapacity = totalCapacity
    controller.solarProduction = solarProduction
    controller.windProduction = windProduction
    controller.hydroProduction = hydroProduction
    controller.otherProduction = otherProduction
    controller.otherCount = otherCount
    controller.windBonus = windNetworkBonus - 1
    controller.solarBonusPercent = solarBonusPercent
    controller.windBonusPercent = windBonusPercent
    controller.solarStorage = newSolarStorage
    controller.windStorage = newWindStorage
    controller.windCapacity = windCapacity
    controller.weather = weatherSnapshot.label or "Unknown"
    controller.priorityMode = controller.priorityMode or "Balanced"
    transmitObjectModData(controllerObj)

    logEnergy("TickController id=" .. tostring(controller.networkId)
        .. " panels=" .. tostring(panelCount)
        .. " turbines=" .. tostring(windCount)
        .. " hydro=" .. tostring(hydroCount)
        .. " other=" .. tostring(otherCount)
        .. " windBonus=" .. tostring(math.floor(windBonusPercent + 0.5)) .. "%"
        .. " solarBonus=" .. tostring(math.floor(solarBonusPercent + 0.5)) .. "%"
        .. " efficiency=" .. tostring(math.floor((efficiency or 0) * 100 + 0.5)) .. "%"
        .. " solarProduction=" .. tostring(math.floor(solarProduction))
        .. " windProduction=" .. tostring(math.floor(windProduction))
        .. " hydroProduction=" .. tostring(math.floor(hydroProduction))
        .. " otherProduction=" .. tostring(math.floor(otherProduction))
        .. " production=" .. tostring(math.floor(totalProduction))
        .. " solarStorage=" .. tostring(math.floor(newSolarStorage))
        .. " windStorage=" .. tostring(math.floor(newWindStorage))
        .. " storageAfter=" .. tostring(math.floor(totalStorage))
        .. " capacity=" .. tostring(math.floor(totalCapacity))
        .. " weather=" .. tostring(weatherSnapshot.label))

    return {
        production = totalProduction,
        solarProduction = solarProduction,
        windProduction = windProduction,
        hydroProduction = hydroProduction,
        otherProduction = otherProduction,
        storage = totalStorage,
        solarStorage = newSolarStorage,
        windStorage = newWindStorage,
        capacity = totalCapacity,
        panelCount = panelCount,
        solarBonusPercent = solarBonusPercent,
        windCount = windCount,
        hydroCount = hydroCount,
        otherCount = otherCount,
        windBonusPercent = windBonusPercent,
        windBatteryCount = countIds(controller.windBatteries),
        weather = weatherSnapshot.label or "Unknown",
    }
end

function ECS.TickControllers()
    local cell = getCell()
    if not cell then
        return
    end
    local objects = cell:getObjectList()
    if not objects then
        return
    end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if ECS.IsControllerObject(obj) or ECS.IsWorldControllerObject(obj) then
            ECS.TickController(obj)
        end
    end
end

function ECS.TickEnergyControllers()
    local tickMinutes = EnergyRouting.GetConfigValue("EnergyTickMinutes")
    if not tickMinutes or tickMinutes <= 0 then
        tickMinutes = 10
    end
    local server = EnergyRouting and EnergyRouting.Server or nil
    local vanillaLike = server and (server.USE_VANILLA_LIKE_ENERGY_FLOW == true or server.DEBUG_SQUARE_BUS_ONLY == true)
    if server and server._inTick == true then
        tickMinutes = 1
    end
    if vanillaLike then
        tickMinutes = 1
    end
    ECS._lastEnergyTickMinutes = ECS._lastEnergyTickMinutes or 0
    local nowMinutes = getWorldMinutes()
    if nowMinutes - ECS._lastEnergyTickMinutes < tickMinutes then
        return
    end
    ECS._lastEnergyTickMinutes = nowMinutes

    logEnergy("TickEnergyControllers now=" .. tostring(nowMinutes)
        .. " tickMinutes=" .. tostring(tickMinutes))

    local prevInTick = server and server._inTick or nil
    local skipRoutingUpdate = (server and server._inTick == true)
    if server then
        server._inTick = true
    end

    local usedEdcs = false
    if server and server.edcs then
        for _, edc in pairs(server.edcs) do
            if edc and type(edc.id) == "string" and string.find(edc.id, "^network_") then
                local shouldTickController = true
                local offIdleSkip = (edc.outputEnabled == false)
                    and (edc._ersSkipConsumerScanWhileOff == true)
                    and (edc._ersOffEnforcePending ~= true)
                if offIdleSkip then
                    local lastOffTickAt = tonumber(edc._offControllerTickAt) or -999999
                    if (nowMinutes - lastOffTickAt) < OFF_IDLE_CONTROLLER_TICK_INTERVAL_MINUTES then
                        shouldTickController = false
                    else
                        edc._offControllerTickAt = nowMinutes
                    end
                else
                    edc._offControllerTickAt = nil
                end

                if shouldTickController then
                    local controllerObj = getControllerById(edc.id)
                    if controllerObj then
                        ECS.TickController(controllerObj)
                        if (not skipRoutingUpdate) and server.UpdateEDC then
                            server.UpdateEDC(edc)
                        end
                        usedEdcs = true
                    end
                else
                    -- Mark handled so we do not enter expensive fallback sweeps.
                    usedEdcs = true
                end
            end
        end
    end

    if not usedEdcs then
        local cacheUsed = false
        local cache = ECS._controllerLookupCache
        if type(cache) == "table" then
            for cachedId, controllerObj in pairs(cache) do
                if isValidControllerLookup(controllerObj, cachedId) then
                    ECS.TickController(controllerObj)
                    if (not skipRoutingUpdate) and server and server.GetOrCreateEDC and server.UpdateEDC then
                        local edc = server.GetOrCreateEDC(cachedId)
                        if edc then
                            server.UpdateEDC(edc)
                        end
                    end
                    cacheUsed = true
                else
                    cache[cachedId] = nil
                end
            end
        end
        usedEdcs = cacheUsed
    end

    if not usedEdcs then
        -- In vanilla-like flow we skip full object-list fallback to avoid periodic stalls.
        if vanillaLike then
            if server then
                server._inTick = prevInTick
            end
            return
        end
        ECS._lastFullControllerSweepAt = ECS._lastFullControllerSweepAt or -99999
        if nowMinutes - ECS._lastFullControllerSweepAt < 60 then
            if server then
                server._inTick = prevInTick
            end
            return
        end
        ECS._lastFullControllerSweepAt = nowMinutes
        local cell = getCell()
        if not cell then
            if server then
                server._inTick = prevInTick
            end
            return
        end
        local objects = cell:getObjectList()
        if not objects then
            if server then
                server._inTick = prevInTick
            end
            return
        end
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if ECS.IsControllerObject(obj) or ECS.IsWorldControllerObject(obj) then
                ECS.TickController(obj)
                local controller = ensureControllerMeta(obj)
                if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.GetOrCreateEDC
                    and EnergyRouting.Server.UpdateEDC then
                    local edc = EnergyRouting.Server.GetOrCreateEDC(controller.networkId)
                    if edc and (not skipRoutingUpdate) then
                        EnergyRouting.Server.UpdateEDC(edc)
                    end
                end
            end
        end
    end

    if server then
        server._inTick = prevInTick
    end
end

function ECS.GetSnapshotForEDC(edc)
    if not edc or not edc.id then
        return { available = 0, production = 0, storage = 0, weather = "Offline", weatherApplied = true }
    end
    local controllerObj = getControllerById(edc.id)
    if not controllerObj then
        return { available = 0, production = 0, storage = 0, weather = "Offline", weatherApplied = true }
    end
    local controller = validateControllerLinks(controllerObj) or ensureControllerMeta(controllerObj)
    local runtimeContext = buildProducerRuntimeContext(controller)
    local productionSnapshot = computeControllerProductionByRegistry(controller, runtimeContext)
    local solarBonusPercent = runtimeContext.solarBonusPercent or 0
    local windBonusPercent = runtimeContext.windBonusPercent or 0
    local windNetworkBonus = runtimeContext.windNetworkBonus or 1
    local weatherSnapshot = runtimeContext.weatherSnapshot or { label = "Unknown" }
    local panelCount = tonumber(productionSnapshot.panelCount) or 0
    local windCount = tonumber(productionSnapshot.windCount) or 0
    local hydroCount = tonumber(productionSnapshot.hydroCount) or 0
    local otherCount = tonumber(productionSnapshot.otherCount) or 0
    local solarProduction = tonumber(productionSnapshot.solarProduction) or 0
    local windProduction = tonumber(productionSnapshot.windProduction) or 0
    local hydroProduction = tonumber(productionSnapshot.hydroProduction) or 0
    local otherProduction = tonumber(productionSnapshot.otherProduction) or 0

    local solarStorage = 0
    local solarCapacity = 0
    local batteryIds = collectIds(controller.batteries)
    for _, batteryId in ipairs(batteryIds) do
        local batteryObj = findObjectById(batteryId, "battery", ECS.IsBatteryObject)
        if batteryObj then
            local battery = ensureBatteryMeta(batteryObj)
            local capacity = battery.capacity or EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
            solarCapacity = solarCapacity + capacity
            solarStorage = solarStorage + (battery.storedEnergy or 0)
        end
    end

    local windStorage = 0
    local windCapacity = 0
    local windBatteryIds = collectIds(controller.windBatteries)
    for _, windBatteryId in ipairs(windBatteryIds) do
        local windBatteryObj = findObjectById(windBatteryId, "wind_battery", ECS.IsWindBatteryObject)
        if windBatteryObj then
            local battery = ensureWindBatteryMeta(windBatteryObj)
            local capacity = battery.capacity or (EnergyRouting.GetConfigValue("BaseWindBatteryCapacity") or 100000)
            windCapacity = windCapacity + capacity
            windStorage = windStorage + (battery.charge or 0)
        end
    end

    local totalProduction = tonumber(productionSnapshot.totalProduction) or (solarProduction + windProduction + hydroProduction + otherProduction)
    local totalStorage = solarStorage + windStorage
    local totalCapacity = solarCapacity + windCapacity
    controller.totalProduction = totalProduction
    controller.solarProduction = solarProduction
    controller.windProduction = windProduction
    controller.hydroProduction = hydroProduction
    controller.otherProduction = otherProduction
    controller.otherCount = otherCount
    controller.windBonus = windNetworkBonus - 1
    controller.solarBonusPercent = solarBonusPercent
    controller.windBonusPercent = windBonusPercent
    controller.totalStorage = totalStorage
    controller.solarStorage = solarStorage
    controller.windStorage = windStorage
    controller.totalCapacity = totalCapacity
    controller.windCapacity = windCapacity
    controller.weather = weatherSnapshot.label or "Unknown"
    transmitObjectModData(controllerObj)
    return {
        available = totalStorage,
        production = totalProduction,
        solarProduction = solarProduction,
        windProduction = windProduction,
        hydroProduction = hydroProduction,
        otherProduction = otherProduction,
        storage = totalStorage,
        solarStorage = solarStorage,
        windStorage = windStorage,
        panelCount = panelCount,
        solarBonusPercent = solarBonusPercent,
        batteryCount = countIds(controller.batteries),
        windCount = windCount,
        hydroCount = hydroCount,
        otherCount = otherCount,
        windBonusPercent = windBonusPercent,
        windBatteryCount = countIds(controller.windBatteries),
        weather = weatherSnapshot.label or "Unknown",
        weatherApplied = true,
    }
end

function ECS.ApplyConsumption(edc, consumption, production)
    if not edc or not edc.id then
        return nil
    end
    local controllerObj = getControllerById(edc.id)
    if not controllerObj then
        return nil
    end
    local controller = ensureControllerMeta(controllerObj)

    local function clampToInt(value)
        local n = tonumber(value) or 0
        if n <= 0 then
            return 0
        end
        return math.floor(n + 0.5)
    end

    local function getStorageTotals()
        local solar = 0
        for _, batteryId in ipairs(collectIds(controller.batteries)) do
            local batteryObj = findObjectById(batteryId, "battery", ECS.IsBatteryObject)
            local battery = batteryObj and ensureBatteryMeta(batteryObj) or nil
            solar = solar + ((battery and battery.storedEnergy) or 0)
        end
        local wind = 0
        for _, batteryId in ipairs(collectIds(controller.windBatteries)) do
            local batteryObj = findObjectById(batteryId, "wind_battery", ECS.IsWindBatteryObject)
            local battery = batteryObj and ensureWindBatteryMeta(batteryObj) or nil
            wind = wind + ((battery and battery.charge) or 0)
        end
        return solar, wind
    end

    local function setWindBatteryStateAll(state)
        for _, batteryId in ipairs(collectIds(controller.windBatteries)) do
            local batteryObj = findObjectById(batteryId, "wind_battery", ECS.IsWindBatteryObject)
            local battery = batteryObj and ensureWindBatteryMeta(batteryObj) or nil
            if battery and battery.state ~= state then
                battery.state = state
                transmitObjectModData(batteryObj)
            end
        end
    end

    local function computeBalancedDraw(demand, solarStorageNow, windStorageNow)
        local requested = clampToInt(demand)
        if requested <= 0 then
            return 0, 0
        end

        local solarNow = math.max(0, tonumber(solarStorageNow) or 0)
        local windNow = math.max(0, tonumber(windStorageNow) or 0)
        local available = solarNow + windNow
        if available <= 0 then
            return 0, 0
        end
        if requested > available then
            requested = clampToInt(available)
        end

        local solarProd = math.max(0, tonumber(controller.solarProduction) or 0)
        local windProd = math.max(0, tonumber(controller.windProduction) or 0)
        local totalProd = solarProd + windProd
        local storageSolarShare = (available > 0) and (solarNow / available) or 0.5
        local productionSolarShare = (totalProd > 0) and (solarProd / totalProd) or storageSolarShare
        local solarShare = (storageSolarShare * 0.35) + (productionSolarShare * 0.65)
        if solarNow <= 0 then
            solarShare = 0
        elseif windNow <= 0 then
            solarShare = 1
        else
            solarShare = math.max(0.10, math.min(0.90, solarShare))
        end

        local solarReserve = math.floor(solarNow * 0.15 + 0.5)
        local windReserve = math.floor(windNow * 0.15 + 0.5)
        local solarPrimaryAvail = math.max(0, solarNow - solarReserve)
        local windPrimaryAvail = math.max(0, windNow - windReserve)

        local targetSolar = requested * solarShare
        local drawSolar = math.min(targetSolar, solarPrimaryAvail)
        local drawWind = math.min(requested - drawSolar, windPrimaryAvail)

        local remaining = requested - drawSolar - drawWind
        if remaining > 0 then
            local solarLeft = math.max(0, solarNow - drawSolar)
            local windLeft = math.max(0, windNow - drawWind)
            if windProd >= solarProd then
                local addWind = math.min(remaining, windLeft)
                drawWind = drawWind + addWind
                remaining = remaining - addWind
                if remaining > 0 then
                    drawSolar = drawSolar + math.min(remaining, solarLeft)
                end
            else
                local addSolar = math.min(remaining, solarLeft)
                drawSolar = drawSolar + addSolar
                remaining = remaining - addSolar
                if remaining > 0 then
                    drawWind = drawWind + math.min(remaining, windLeft)
                end
            end
        end

        return clampToInt(drawSolar), clampToInt(drawWind)
    end

    local requestedConsumption = clampToInt(consumption)
    local currentProduction = math.max(0, tonumber(production) or tonumber(controller.totalProduction) or 0)
    local solarProduction = math.max(0, tonumber(controller.solarProduction) or 0)
    local windProduction = math.max(0, tonumber(controller.windProduction) or 0)

    setWindBatteryStateAll("idle")

    local chargedSolar = 0
    local chargedWind = 0
    local removedSolar = 0
    local removedWind = 0

    if currentProduction >= requestedConsumption then
        local surplus = currentProduction - requestedConsumption
        if surplus > 0 then
            local totalProd = solarProduction + windProduction
            local solarShare = (totalProd > 0) and (solarProduction / totalProd) or 0.5
            local solarTarget = surplus * solarShare
            local windTarget = surplus - solarTarget

            chargedSolar = applyChargeMasterFirst(controller, solarTarget)
            chargedWind = applyWindChargeMasterFirst(controller, windTarget)

            local chargedTotal = chargedSolar + chargedWind
            local remainingCharge = math.max(0, surplus - chargedTotal)
            if remainingCharge > 0 then
                if windProduction >= solarProduction then
                    local extraWind = applyWindChargeMasterFirst(controller, remainingCharge)
                    chargedWind = chargedWind + extraWind
                    remainingCharge = remainingCharge - extraWind
                    if remainingCharge > 0 then
                        chargedSolar = chargedSolar + applyChargeMasterFirst(controller, remainingCharge)
                    end
                else
                    local extraSolar = applyChargeMasterFirst(controller, remainingCharge)
                    chargedSolar = chargedSolar + extraSolar
                    remainingCharge = remainingCharge - extraSolar
                    if remainingCharge > 0 then
                        chargedWind = chargedWind + applyWindChargeMasterFirst(controller, remainingCharge)
                    end
                end
            end
        end
    else
        local deficit = requestedConsumption - currentProduction
        local solarBefore, windBefore = getStorageTotals()
        local plannedSolar, plannedWind = computeBalancedDraw(deficit, solarBefore, windBefore)

        removedSolar = applyDischargeMasterFirst(controller, plannedSolar)
        removedWind = applyWindDischargeMasterFirst(controller, plannedWind)

        local remaining = math.max(0, clampToInt(deficit) - clampToInt(removedSolar + removedWind))
        if remaining > 0 then
            local extraWind = applyWindDischargeMasterFirst(controller, remaining)
            removedWind = removedWind + extraWind
            remaining = math.max(0, remaining - clampToInt(extraWind))
        end
        if remaining > 0 then
            local extraSolar = applyDischargeMasterFirst(controller, remaining)
            removedSolar = removedSolar + extraSolar
        end
    end

    local solarStorage, windStorage = getStorageTotals()
    controller.solarStorage = solarStorage
    controller.windStorage = windStorage
    controller.totalStorage = solarStorage + windStorage

    if (chargedWind + removedWind) <= 0 then
        setWindBatteryStateAll("idle")
    end

    -- B42.13 dedicated can duplicate placed world-items when a complete item snapshot
    -- is pushed every energy heartbeat. Keep this path modData-only and throttled.
    ECS._lastControllerModSyncAt = ECS._lastControllerModSyncAt or {}
    local syncKey = tostring(controller.networkId or edc.id or "unknown")
    local nowMs = getWorldTimestampMs()
    local lastSyncMs = tonumber(ECS._lastControllerModSyncAt[syncKey]) or 0
    local syncIntervalMs = 2000
    if lastSyncMs <= 0 or (nowMs - lastSyncMs) >= syncIntervalMs then
        transmitObjectModData(controllerObj)
        ECS._lastControllerModSyncAt[syncKey] = nowMs
    end
    return controller.totalStorage
end

function ECS.OnObjectRemoved(obj)
    clearCachedControllerByObject(obj)
    if queuePendingObjectRemoval(obj) then
        return
    end
    if shouldPreserveLinksOnObjectRemoved(obj) then
        return
    end

    local function refreshControllerState(controllerId)
        if type(controllerId) ~= "string" then
            return
        end
        local controllerObj = getControllerById(controllerId)
        if controllerObj then
            local controller = ensureControllerMeta(controllerObj)
            local md = getObjectModData(controllerObj)
            if md then
                md.energyController = controller
            end
            transmitObjectModData(controllerObj)
            if ECS.TickController then
                ECS.TickController(controllerObj)
            end
        end
        if EnergyRouting and EnergyRouting.Server
            and EnergyRouting.Server.GetEDCById
            and EnergyRouting.Server.UpdateEDC then
            local edc = EnergyRouting.Server.GetEDCById(controllerId)
            if edc then
                EnergyRouting.Server.UpdateEDC(edc)
            end
        end
    end

    local function unlinkFromController(controllerId, kind, objectId, sourceSquare)
        if type(controllerId) ~= "string" then
            return
        end
        local controllerObj = getControllerById(controllerId)
        if controllerObj then
            local controller = ensureControllerMeta(controllerObj)
            if kind == "panel" and objectId then
                removeId(controller.panels, objectId)
            elseif kind == "battery" and objectId then
                removeId(controller.batteries, objectId)
            elseif kind == "turbine" and objectId then
                removeId(controller.windTurbines, objectId)
            elseif kind == "hydro" and objectId then
                removeId(controller.hydroTurbines, objectId)
            elseif kind == "windBattery" and objectId then
                removeId(controller.windBatteries, objectId)
                normalizeWindBatteryRoles(controller)
            end
            local cmd = getObjectModData(controllerObj)
            if cmd then
                cmd.energyController = controller
            end
            transmitObjectModData(controllerObj)
        end
        if objectId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
            EnergyRouting.Server.RemoveLink(controllerId, kind, objectId)
        end
        if objectId then
            returnCableForUnlink(sourceSquare, 1)
        end
        refreshControllerState(controllerId)
    end

    local function clearPanelConnection(target)
        local md = getObjectModData(target)
        if not md then
            return nil, nil
        end
        local controllerId = (md.panel and md.panel.controllerId)
            or (md.energyPanel and md.energyPanel.controllerId)
            or (md.energy and md.energy.controllerId)
            or nil
        local panelId = getPanelId(target)
        if md.panel then
            md.panel.controllerId = nil
        end
        if md.energyPanel then
            md.energyPanel.controllerId = nil
        end
        md.energy = md.energy or {}
        md.energy.type = "solar"
        md.energy.controllerId = nil
        md.energy.connected = false
        transmitObjectModData(target)
        return controllerId, panelId
    end

    local function clearBatteryConnection(target)
        local md = getObjectModData(target)
        if not md then
            return nil, nil
        end
        local controllerId = md.energy and md.energy.controllerId or nil
        local batteryId = getBatteryId(target)
        md.energy = md.energy or {}
        md.energy.type = md.energy.type or "battery"
        md.energy.controllerId = nil
        md.energy.role = nil
        md.energy.connected = false
        transmitObjectModData(target)
        return controllerId, batteryId
    end

    local function clearWindConnection(target)
        local md = getObjectModData(target)
        if not md then
            return nil, nil
        end
        local controllerId = md.wind and md.wind.controllerId or nil
        local windId = getWindId(target)
        md.wind = md.wind or {}
        md.wind.controllerId = nil
        md.wind.connected = false
        md.wind.currentProduction = 0
        md.energy = md.energy or {}
        md.energy.type = "wind"
        md.energy.controllerId = nil
        md.energy.connected = false
        transmitObjectModData(target)
        return controllerId, windId
    end

    local function clearHydroConnection(target)
        local md = getObjectModData(target)
        if not md then
            return nil, nil
        end
        local controllerId = (md.hydro and md.hydro.controllerId)
            or (md.energy and md.energy.controllerId)
            or nil
        local hydroId = getHydroId(target)
        md.hydro = md.hydro or {}
        md.hydro.controllerId = nil
        md.hydro.connected = false
        md.hydro.currentProduction = 0
        md.hydro.isActive = false
        md.energy = md.energy or {}
        md.energy.type = "hydro"
        md.energy.controllerId = nil
        md.energy.connected = false
        transmitObjectModData(target)
        return controllerId, hydroId
    end

    local function clearWindBatteryConnection(target)
        local md = getObjectModData(target)
        if not md then
            return nil, nil
        end
        local controllerId = (md.windBattery and md.windBattery.controllerId)
            or (md.energy and md.energy.controllerId)
            or nil
        local windBatteryId = getWindBatteryId(target)
        md.windBattery = md.windBattery or {}
        md.windBattery.controllerId = nil
        md.windBattery.role = nil
        md.windBattery.connected = false
        md.windBattery.state = "idle"
        md.energy = md.energy or {}
        md.energy.controllerId = nil
        md.energy.connected = false
        transmitObjectModData(target)
        return controllerId, windBatteryId
    end

    if ECS.IsControllerObject(obj) or ECS.IsWorldControllerObject(obj) or isControllerPrototypeObject(obj) then
        local sq = getSquareFromObj(obj)
        local controllerId = getControllerId(obj)
        if not controllerId and sq then
            local sqMd = sq:getModData()
            controllerId = sqMd and sqMd.EnergyRoutingEDCId or nil
        end
        if not controllerId then
            return
        end
        local cell = getCell()
        if not cell or not sq then
            return
        end

        local radius = EnergyNetwork.GetConfigValue("ControllerConnectRadius")
        local seen = {}
        local function processEntry(target)
            if not target or seen[target] then
                return
            end
            seen[target] = true
            if ECS.IsPanelObject(target) then
                local md = getObjectModData(target)
                local linkedId = md and ((md.panel and md.panel.controllerId)
                    or (md.energyPanel and md.energyPanel.controllerId)
                    or (md.energy and md.energy.controllerId)) or nil
                if linkedId == controllerId then
                    local _, panelId = clearPanelConnection(target)
                    if panelId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controllerId, "panel", panelId)
                    end
                    returnCableForUnlink(getSquareFromObj(target) or sq, 1)
                end
            elseif ECS.IsBatteryObject(target) then
                local md = getObjectModData(target)
                local linkedId = md and md.energy and md.energy.controllerId or nil
                if linkedId == controllerId then
                    local _, batteryId = clearBatteryConnection(target)
                    if batteryId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controllerId, "battery", batteryId)
                    end
                    returnCableForUnlink(getSquareFromObj(target) or sq, 1)
                end
            elseif ECS.IsWindObject(target) then
                local md = getObjectModData(target)
                local linkedId = md and md.wind and md.wind.controllerId or nil
                if linkedId == controllerId then
                    local _, windId = clearWindConnection(target)
                    if windId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controllerId, "turbine", windId)
                    end
                    returnCableForUnlink(getSquareFromObj(target) or sq, 1)
                end
            elseif ECS.IsHydroObject(target) then
                local md = getObjectModData(target)
                local linkedId = md and ((md.hydro and md.hydro.controllerId) or (md.energy and md.energy.controllerId)) or nil
                if linkedId == controllerId then
                    local _, hydroId = clearHydroConnection(target)
                    if hydroId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controllerId, "hydro", hydroId)
                    end
                    returnCableForUnlink(getSquareFromObj(target) or sq, 1)
                end
            elseif ECS.IsWindBatteryObject(target) then
                local md = getObjectModData(target)
                local linkedId = md and ((md.windBattery and md.windBattery.controllerId) or (md.energy and md.energy.controllerId)) or nil
                if linkedId == controllerId then
                    local _, windBatteryId = clearWindBatteryConnection(target)
                    if windBatteryId and EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveLink then
                        EnergyRouting.Server.RemoveLink(controllerId, "windBattery", windBatteryId)
                    end
                    returnCableForUnlink(getSquareFromObj(target) or sq, 1)
                end
            end
        end

        for x = sq:getX() - radius, sq:getX() + radius do
            for y = sq:getY() - radius, sq:getY() + radius do
                local targetSq = cell:getGridSquare(x, y, sq:getZ())
                if targetSq then
                    local objects = targetSq:getObjects()
                    if objects then
                        for i = 0, objects:size() - 1 do
                            processEntry(objects:get(i))
                        end
                    end
                    if targetSq.getSpecialObjects then
                        local special = targetSq:getSpecialObjects()
                        if special then
                            for i = 0, special:size() - 1 do
                                processEntry(special:get(i))
                            end
                        end
                    end
                    local worldObjects = targetSq:getWorldObjects()
                    if worldObjects then
                        for i = 0, worldObjects:size() - 1 do
                            processEntry(worldObjects:get(i))
                        end
                    end
                end
            end
        end

        if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveEDC then
            EnergyRouting.Server.RemoveEDC(controllerId)
        end
        return
    end

    if ECS.IsPanelObject(obj) then
        local controllerId, panelId = clearPanelConnection(obj)
        unlinkFromController(controllerId, "panel", panelId, getSquareFromObj(obj))
        return
    end
    if ECS.IsBatteryObject(obj) then
        local controllerId, batteryId = clearBatteryConnection(obj)
        unlinkFromController(controllerId, "battery", batteryId, getSquareFromObj(obj))
        return
    end
    if ECS.IsWindObject(obj) then
        local controllerId, windId = clearWindConnection(obj)
        unlinkFromController(controllerId, "turbine", windId, getSquareFromObj(obj))
        return
    end
    if ECS.IsHydroObject(obj) then
        local controllerId, hydroId = clearHydroConnection(obj)
        unlinkFromController(controllerId, "hydro", hydroId, getSquareFromObj(obj))
        return
    end
    if ECS.IsWindBatteryObject(obj) then
        local controllerId, windBatteryId = clearWindBatteryConnection(obj)
        unlinkFromController(controllerId, "windBattery", windBatteryId, getSquareFromObj(obj))
        return
    end
end

function ECS.OnClientCommand(module, command, player, args)
    if module ~= "EnergyRouting" and module ~= EnergyRouting.MOD_ID then
        return
    end

    if command == "ConnectPanelToControllerById" or command == "ConnectBatteryToControllerById"
        or command == "ConnectPanelToController" or command == "ConnectBatteryToController"
        or command == "ConnectWindToControllerById" or command == "ConnectHydroToControllerById"
        or command == "ConnectWindBatteryToControllerById" then
        print("[EnergyController][Server] CMD=" .. tostring(command))
    end

    if command == "ConnectPanelToControllerById" and args then
        local controllerObj = args.controllerId and getControllerObjForCommand(args.controllerId) or nil
        
        if controllerObj then
            local cmd = getObjectModData(controllerObj)
            if cmd and not cmd.energyController then
                ECS.EnsureControllerForObject(controllerObj)
            end
        end

        local panelObj = args.panelId and findObjectById(args.panelId, "panel", ECS.IsPanelObject) or nil

        if not controllerObj then
            print("[EnergyController][Server] controllerObj nil " .. tostring(args.controllerId))
            return
        end
        if not panelObj then
            print("[EnergyController][Server] panelObj nil " .. tostring(args.panelId))
            return
        end
        ECS.ConnectPanelToController(panelObj, controllerObj, player)
        return
    end

    if command == "ConnectBatteryToControllerById" and args then
        local controllerObj = args.controllerId and getControllerObjForCommand(args.controllerId) or nil
        
        if controllerObj then
            local cmd = getObjectModData(controllerObj)
            if cmd and not cmd.energyController then
                ECS.EnsureControllerForObject(controllerObj)
            end
        end

        local batteryObj = args.batteryId and findObjectById(args.batteryId, "battery", ECS.IsBatteryObject) or nil

        if not controllerObj then
            print("[EnergyController][Server] controllerObj nil " .. tostring(args.controllerId))
            return
        end
        if not batteryObj then
            print("[EnergyController][Server] batteryObj nil " .. tostring(args.batteryId))
            return
        end
        ECS.ConnectBatteryToController(batteryObj, controllerObj, player)
        return
    end

    if command == "ConnectWindToControllerById" and args then
        local controllerObj = args.controllerId and getControllerObjForCommand(args.controllerId) or nil
        if controllerObj then
            local cmd = getObjectModData(controllerObj)
            if cmd and not cmd.energyController then
                ECS.EnsureControllerForObject(controllerObj)
            end
        end
        local windObj = args.windId and findObjectById(args.windId, "wind", ECS.IsWindObject) or nil
        if not controllerObj then
            print("[EnergyController][Server] controllerObj nil " .. tostring(args.controllerId))
            return
        end
        if not windObj then
            print("[EnergyController][Server] windObj nil " .. tostring(args.windId))
            return
        end
        ECS.ConnectWindToController(windObj, controllerObj, player)
        return
    end

    if command == "ConnectHydroToControllerById" and args then
        local controllerObj = args.controllerId and getControllerObjForCommand(args.controllerId) or nil
        if controllerObj then
            local cmd = getObjectModData(controllerObj)
            if cmd and not cmd.energyController then
                ECS.EnsureControllerForObject(controllerObj)
            end
        end
        local hydroObj = args.hydroId and findObjectById(args.hydroId, "hydro", ECS.IsHydroObject) or nil
        if not controllerObj then
            print("[EnergyController][Server] controllerObj nil " .. tostring(args.controllerId))
            return
        end
        if not hydroObj then
            print("[EnergyController][Server] hydroObj nil " .. tostring(args.hydroId))
            return
        end
        ECS.ConnectHydroToController(hydroObj, controllerObj, player)
        return
    end

    if command == "ConnectWindBatteryToControllerById" and args then
        local controllerObj = args.controllerId and getControllerObjForCommand(args.controllerId) or nil
        if controllerObj then
            local cmd = getObjectModData(controllerObj)
            if cmd and not cmd.energyController then
                ECS.EnsureControllerForObject(controllerObj)
            end
        end
        local windBatteryObj = args.windBatteryId and findObjectById(args.windBatteryId, "wind_battery", ECS.IsWindBatteryObject) or nil
        if not controllerObj then
            print("[EnergyController][Server] controllerObj nil " .. tostring(args.controllerId))
            return
        end
        if not windBatteryObj then
            print("[EnergyController][Server] windBatteryObj nil " .. tostring(args.windBatteryId))
            return
        end
        ECS.ConnectWindBatteryToController(windBatteryObj, controllerObj, player)
        return
    end

    if command == "ConnectPanelToController" and args then
        local panelSq = args.panelSquare and getSquare(args.panelSquare.x, args.panelSquare.y, args.panelSquare.z)
        local controllerSq = args.controllerSquare and getSquare(args.controllerSquare.x, args.controllerSquare.y, args.controllerSquare.z)
        local panelObj = panelSq and ECS.FindObjectOnSquare and ECS.FindObjectOnSquare(panelSq, ECS.IsPanelObject) or nil
        local controllerObj = controllerSq and ECS.FindObjectOnSquare and ECS.FindObjectOnSquare(controllerSq, ECS.IsControllerObject) or nil
        if not controllerObj then
            print("[EnergyController][Server] ConnectPanel controllerObj=nil square")
            return
        end
        if not panelObj then
            print("[EnergyController][Server] ConnectPanel panelObj=nil square")
            return
        end
        ECS.ConnectPanelToController(panelObj, controllerObj, player)
        return
    end

    if command == "ConnectBatteryToController" and args then
        local batterySq = args.batterySquare and getSquare(args.batterySquare.x, args.batterySquare.y, args.batterySquare.z)
        local controllerSq = args.controllerSquare and getSquare(args.controllerSquare.x, args.controllerSquare.y, args.controllerSquare.z)
        local batteryObj = batterySq and ECS.FindObjectOnSquare and ECS.FindObjectOnSquare(batterySq, ECS.IsBatteryObject) or nil
        local controllerObj = controllerSq and ECS.FindObjectOnSquare and ECS.FindObjectOnSquare(controllerSq, ECS.IsControllerObject) or nil
        if not controllerObj then
            print("[EnergyController][Server] ConnectBattery controllerObj=nil square")
            return
        end
        if not batteryObj then
            print("[EnergyController][Server] ConnectBattery batteryObj=nil square")
            return
        end
        ECS.ConnectBatteryToController(batteryObj, controllerObj, player)
        return
    end

    if command == "EnsureController" and args then
        local controllerObj = args.controllerId and getControllerObjForCommand(args.controllerId) or nil
        if controllerObj then
            ECS.EnsureControllerForObject(controllerObj)
            transmitObjectModData(controllerObj)
            print("[EnergyController][Server] EnsureController (UI) " .. tostring(args.controllerId))
        else
            print("[EnergyController][Server] EnsureController controllerObj nil " .. tostring(args.controllerId))
        end
        return
    end

    if command == "RepairProducer" and args then
        local producerObj, producerType = getRepairProducerObject(args)
        if not producerObj then
            return
        end

        if not playerCanRepairProducer(player, producerType) then
            return
        end

        local md = getObjectModData(producerObj)
        if not md then
            return
        end
        local currentDegradation = tonumber(md.production and md.production.degradation)
            or tonumber(md.solar and md.solar.degradation)
            or tonumber(md.wind and md.wind.condition)
            or ((tonumber(md.hydro and md.hydro.condition) or 100) / 100)
            or 1.0
        if currentDegradation >= 0.9999 then
            return
        end

        if not consumeRepairProducerMaterials(player, producerType) then
            return
        end

        local repairStep = (producerType == "hydro") and 0.40 or PRODUCER_REPAIR_STEP
        local repaired = ECS.RepairProductionObject(producerObj, repairStep)
        if not repaired then
            return
        end

        local newMd = getObjectModData(producerObj)
        local newDeg = tonumber(newMd and newMd.production and newMd.production.degradation)
            or tonumber(newMd and newMd.solar and newMd.solar.degradation)
            or tonumber(newMd and newMd.wind and newMd.wind.condition)
            or ((tonumber(newMd and newMd.hydro and newMd.hydro.condition) or 100) / 100)
            or 1.0
        print("[SPESS][Repair] repaired type=" .. tostring(producerType)
            .. " id=" .. tostring(args.producerId or args.panelId or args.windId or args.hydroId)
            .. " degradation=" .. tostring(newDeg))

        local controllerId = getProducerControllerId(producerObj, producerType)
        if controllerId and EnergyRouting and EnergyRouting.Server then
            local edc = EnergyRouting.Server.GetEDCById and EnergyRouting.Server.GetEDCById(controllerId) or nil
            if not edc and EnergyRouting.Server.GetOrCreateEDC then
                edc = EnergyRouting.Server.GetOrCreateEDC(controllerId)
            end
            if edc and EnergyRouting.Server.UpdateEDC then
                EnergyRouting.Server.UpdateEDC(edc)
            end
            if edc and player and EnergyRouting.Server.SendStateToPlayer then
                EnergyRouting.Server.SendStateToPlayer(player, edc)
            end
        end
        return
    end

    if command == "DisconnectPanelFromController" and args then
        local panelSq = args.panelSquare and getSquare(args.panelSquare.x, args.panelSquare.y, args.panelSquare.z)
        local controllerSq = args.controllerSquare and getSquare(args.controllerSquare.x, args.controllerSquare.y, args.controllerSquare.z)
        local panelObj = panelSq and ECS.FindObjectOnSquare and ECS.FindObjectOnSquare(panelSq, ECS.IsPanelObject) or nil
        local controllerObj = controllerSq and ECS.FindObjectOnSquare and ECS.FindObjectOnSquare(controllerSq, ECS.IsControllerObject) or nil
        if panelObj and controllerObj then
            ECS.DisconnectPanel(panelObj, controllerObj, player)
        end
        return
    end

    if command == "DisconnectBatteryFromController" and args then
        local batterySq = args.batterySquare and getSquare(args.batterySquare.x, args.batterySquare.y, args.batterySquare.z)
        local controllerSq = args.controllerSquare and getSquare(args.controllerSquare.x, args.controllerSquare.y, args.controllerSquare.z)
        local batteryObj = batterySq and ECS.FindObjectOnSquare and ECS.FindObjectOnSquare(batterySq, ECS.IsBatteryObject) or nil
        local controllerObj = controllerSq and ECS.FindObjectOnSquare and ECS.FindObjectOnSquare(controllerSq, ECS.IsControllerObject) or nil
        if batteryObj and controllerObj then
            ECS.DisconnectBattery(batteryObj, controllerObj, player)
        end
        return
    end

    if command == "DisconnectWindFromController" and args then
        local windObj = args.windId and findObjectById(args.windId, "wind", ECS.IsWindObject) or nil
        local controllerObj = args.controllerId and getControllerObjForCommand(args.controllerId) or nil
        if windObj and controllerObj then
            ECS.DisconnectWind(windObj, controllerObj, player)
        end
        return
    end

    if command == "DisconnectHydroFromController" and args then
        local hydroObj = args.hydroId and findObjectById(args.hydroId, "hydro", ECS.IsHydroObject) or nil
        local controllerObj = args.controllerId and getControllerObjForCommand(args.controllerId) or nil
        if hydroObj and controllerObj then
            ECS.DisconnectHydro(hydroObj, controllerObj, player)
        end
        return
    end

    if command == "DisconnectWindBatteryFromController" and args then
        local windBatteryObj = args.windBatteryId and findObjectById(args.windBatteryId, "wind_battery", ECS.IsWindBatteryObject) or nil
        local controllerObj = args.controllerId and getControllerObjForCommand(args.controllerId) or nil
        if windBatteryObj and controllerObj then
            ECS.DisconnectWindBattery(windBatteryObj, controllerObj, player)
        end
        return
    end
end

function ECS.FindObjectOnSquare(square, predicate)
    if not square or not predicate then
        return nil
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if predicate(obj) then
            return obj
        end
    end
    if square.getSpecialObjects then
        local specialObjects = square:getSpecialObjects()
        for i = 0, specialObjects:size() - 1 do
            local obj = specialObjects:get(i)
            if predicate(obj) then
                return obj
            end
        end
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local obj = worldObjects:get(i)
        if predicate(obj) then
            return obj
        end
    end
    return nil
end

if Events.OnObjectAdded and Events.OnObjectAdded.Remove then
    Events.OnObjectAdded.Remove(ECS.OnObjectAdded)
end
Events.OnObjectAdded.Add(ECS.OnObjectAdded)
if Events.OnObjectAboutToBeRemoved then
    if Events.OnObjectAboutToBeRemoved.Remove then
        Events.OnObjectAboutToBeRemoved.Remove(ECS.OnObjectRemoved)
    end
    Events.OnObjectAboutToBeRemoved.Add(ECS.OnObjectRemoved)
elseif Events.OnObjectRemoved then
    if Events.OnObjectRemoved.Remove then
        Events.OnObjectRemoved.Remove(ECS.OnObjectRemoved)
    end
    Events.OnObjectRemoved.Add(ECS.OnObjectRemoved)
end
-- Keep a single object-added hook to avoid duplicate initialization storms in MP.
if Events.OnClientCommand and Events.OnClientCommand.Remove then
    Events.OnClientCommand.Remove(ECS.OnClientCommand)
end
Events.OnClientCommand.Add(ECS.OnClientCommand)
if Events.OnLoadMapZones then
    if Events.OnLoadMapZones.Remove then
        Events.OnLoadMapZones.Remove(ECS.BackfillControllers)
        Events.OnLoadMapZones.Remove(ECS.TryRestoreNetworks)
    end
    Events.OnLoadMapZones.Add(ECS.BackfillControllers)
    Events.OnLoadMapZones.Add(ECS.TryRestoreNetworks)
end
if Events.OnGameStart then
    if Events.OnGameStart.Remove then
        Events.OnGameStart.Remove(ECS.TryRestoreNetworks)
    end
    Events.OnGameStart.Add(ECS.TryRestoreNetworks)
end
if Events.EveryOneMinute then
    if Events.EveryOneMinute.Remove then
        Events.EveryOneMinute.Remove(ECS.TryRestoreNetworks)
    end
    Events.EveryOneMinute.Add(ECS.TryRestoreNetworks)
end
if Events.OnTick then
    if Events.OnTick.Remove then
        Events.OnTick.Remove(ECS.ProcessPendingObjectRemovals)
    end
    Events.OnTick.Add(ECS.ProcessPendingObjectRemovals)
end

if EnergyRouting and EnergyRouting.RegisterEnergyProvider then
    EnergyRouting.RegisterEnergyProvider(function(edc)
        return ECS.GetSnapshotForEDC(edc)
    end)
end

if EnergyRouting and EnergyRouting.RegisterEnergyConsumer then
    EnergyRouting.RegisterEnergyConsumer(function(edc, consumption, production)
        return ECS.ApplyConsumption(edc, consumption, production)
    end)
end

