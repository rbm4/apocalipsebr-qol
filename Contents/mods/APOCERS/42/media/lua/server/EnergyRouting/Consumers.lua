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

EnergyRouting = EnergyRouting or {}
EnergyRouting.Consumers = EnergyRouting.Consumers or {}

local Consumers = EnergyRouting.Consumers

Consumers.registry = Consumers.registry or {}
Consumers.byController = Consumers.byController or {}
Consumers.MAX_RANGE = Consumers.MAX_RANGE or (EnergyRouting.CONTROLLER_RADIUS or 20)
Consumers._reclassLogById = Consumers._reclassLogById or {}

local function safeCall(obj, method, ...)
    if obj and obj[method] then
        local ok, result = pcall(obj[method], obj, ...)
        if ok then
            return result
        end
    end
    return nil
end

local function isInstanceOf(obj, className)
    if not obj or not className or not instanceof then
        return false
    end
    local ok, result = pcall(instanceof, obj, className)
    return ok and result == true
end

local function hasPropertyFlag(props, key)
    if not props or not key then
        return false
    end
    local ok = false
    if props.Is then
        local success, result = pcall(props.Is, props, key)
        ok = success and result == true
    end
    if not ok and props.is then
        local success, result = pcall(props.is, props, key)
        ok = success and result == true
    end
    return ok
end

local function propertyContains(props, key, needle)
    if not props or not key or not needle then
        return false
    end
    local value = nil
    if props.Val then
        value = safeCall(props, "Val", key)
    end
    if value == nil and props.value then
        value = safeCall(props, "value", key)
    end
    if value == nil then
        return false
    end
    local probe = string.lower(tostring(value))
    local wanted = string.lower(tostring(needle))
    return string.find(probe, wanted, 1, true) ~= nil
end

local function hasContainerType(obj, containerType)
    if not obj or not containerType then
        return false
    end
    local wanted = string.lower(tostring(containerType))
    local function matchesTypeName(candidateType)
        if not candidateType then
            return false
        end
        local probe = string.lower(tostring(candidateType))
        return probe == wanted or probe:find(wanted, 1, true) ~= nil
    end

    if obj.getContainerByType and safeCall(obj, "getContainerByType", containerType) then
        return true
    end

    local direct = safeCall(obj, "getContainer")
    local directType = direct and safeCall(direct, "getType") or nil
    if matchesTypeName(directType) then
        return true
    end

    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    local itemContainer = item and safeCall(item, "getContainer") or nil
    local itemContainerType = itemContainer and safeCall(itemContainer, "getType") or nil
    if matchesTypeName(itemContainerType) then
        return true
    end

    local count = safeCall(obj, "getContainerCount")
    if type(count) == "number" and count > 0 and obj.getContainerByIndex then
        for i = 0, count - 1 do
            local candidate = safeCall(obj, "getContainerByIndex", i)
            local candidateType = candidate and safeCall(candidate, "getType") or nil
            if matchesTypeName(candidateType) then
                return true
            end
        end
    end

    return false
end

local function isRefrigerationLikeObject(obj)
    if not obj then
        return false
    end
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item then
        local fullType = safeCall(item, "getFullType")
        local displayName = safeCall(item, "getDisplayName") or safeCall(item, "getName")
        local probe = string.lower(tostring(fullType or "")) .. " " .. string.lower(tostring(displayName or ""))
        if probe:find("fridge", 1, true)
            or probe:find("freezer", 1, true)
            or probe:find("refrigerator", 1, true)
            or probe:find("cooler", 1, true) then
            return true
        end
    end
    local props = safeCall(obj, "getProperties")
    if hasPropertyFlag(props, "IsFridge")
        or propertyContains(props, "container", "fridge")
        or propertyContains(props, "container", "freezer") then
        return true
    end
    return hasContainerType(obj, "fridge") or hasContainerType(obj, "freezer")
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

local function getObjectSquare(obj)
    return safeCall(obj, "getSquare")
end

local function getBuildingKeyFromSquare(square)
    if not square then
        return nil
    end
    local building = safeCall(square, "getBuilding")
    if not building then
        local room = safeCall(square, "getRoom")
        building = room and safeCall(room, "getBuilding") or nil
    end
    if not building then
        return nil
    end
    local buildingId = safeCall(building, "getID")
    if buildingId ~= nil then
        return tostring(buildingId)
    end
    return tostring(building)
end

local function normalizeGroup(groupId)
    if not groupId then
        return nil
    end
    local probe = string.lower(tostring(groupId))
    if EnergyRouting.GroupsById and EnergyRouting.GroupsById[probe] then
        return probe
    end
    if EnergyRouting.GroupsList then
        for _, group in ipairs(EnergyRouting.GroupsList) do
            if string.lower(group.name or "") == probe then
                return group.id
            end
        end
    end
    return nil
end

local function normalizeConsumption(watts, groupId)
    if type(watts) ~= "number" then
        watts = tonumber(watts) or 0
    end
    if EnergyRouting and EnergyRouting.NormalizeGroupConsumption then
        return EnergyRouting.NormalizeGroupConsumption(groupId, watts)
    end
    if watts <= 0 then
        return 1
    end
    return watts
end

local function defaultGroupWatts(groupId)
    local defaults = EnergyRouting and EnergyRouting.GroupDefaultWatts or nil
    local watts = defaults and defaults[groupId] or nil
    watts = tonumber(watts) or 0
    if watts <= 0 then
        watts = 100
    end
    return watts
end

local function appendProbePart(parts, value)
    if value == nil then
        return
    end
    local text = tostring(value)
    if text ~= "" then
        table.insert(parts, string.lower(text))
    end
end

local function buildProbeText(obj)
    if not obj then
        return ""
    end
    local parts = {}
    local sprite = safeCall(obj, "getSprite")
    appendProbePart(parts, sprite and safeCall(sprite, "getName") or nil)
    appendProbePart(parts, safeCall(obj, "getName"))
    appendProbePart(parts, safeCall(obj, "getObjectName"))

    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item then
        appendProbePart(parts, safeCall(item, "getFullType"))
        appendProbePart(parts, safeCall(item, "getDisplayName"))
        appendProbePart(parts, safeCall(item, "getName"))
        appendProbePart(parts, safeCall(item, "getType"))
    end

    appendProbePart(parts, tostring(obj))
    return table.concat(parts, " ")
end

local function probeIndicatesRefrigeration(probe)
    if type(probe) ~= "string" or probe == "" then
        return false
    end
    return probe:find("fridge", 1, true) ~= nil
        or probe:find("freezer", 1, true) ~= nil
        or probe:find("isfridge", 1, true) ~= nil
        or probe:find("refrigerator", 1, true) ~= nil
        or probe:find("refrigeration", 1, true) ~= nil
end

local function isPassiveTelevisionObject(obj)
    if not obj then
        return false
    end
    if isInstanceOf(obj, "IsoTelevision") then
        return true
    end
    local props = safeCall(obj, "getProperties")
    if not props then
        return false
    end
    local isoType = nil
    if props.Val then
        isoType = safeCall(props, "Val", "IsoType")
    end
    if isoType == nil and props.value then
        isoType = safeCall(props, "value", "IsoType")
    end
    if isoType and string.lower(tostring(isoType)):find("isotelevision", 1, true) then
        return true
    end
    return false
end

local function isBatteryRadioObject(obj)
    if not obj then
        return false
    end
    if isInstanceOf(obj, "IsoRadio") then
        return true
    end
    local props = safeCall(obj, "getProperties")
    if not props then
        return false
    end
    local signal = nil
    if props.Val then
        signal = safeCall(props, "Val", "signal")
    end
    if signal == nil and props.value then
        signal = safeCall(props, "value", "signal")
    end
    if signal and string.lower(tostring(signal)):find("radio", 1, true) then
        return true
    end
    return false
end

local FORGE_EXCLUSION_TOKENS = {
    "forge",
    "forja",
    "herreria",
    "blacksmith",
    "smithing",
    "smithy",
    "smelter",
    "bloomery",
}

local function probeHasAnyToken(probe, tokens)
    if type(probe) ~= "string" or probe == "" then
        return false
    end
    for _, token in ipairs(tokens or {}) do
        if token and token ~= "" and probe:find(token, 1, true) then
            return true
        end
    end
    return false
end

local function hasPositiveRuntimePowerUsage(obj)
    if not obj then
        return false
    end
    local power = tonumber(safeCall(obj, "getPower")) or 0
    if power > 0 then
        return true
    end
    local usage = tonumber(safeCall(obj, "getPowerUsage")) or 0
    if usage > 0 then
        return true
    end
    local baseUsage = tonumber(safeCall(obj, "getPowerUsageBase")) or 0
    return baseUsage > 0
end

local function isNonElectricForgeObject(obj)
    if not obj then
        return false
    end
    local probe = buildProbeText(obj)
    if not probeHasAnyToken(probe, FORGE_EXCLUSION_TOKENS) then
        return false
    end
    if hasPositiveRuntimePowerUsage(obj) then
        return false
    end
    local props = safeCall(obj, "getProperties")
    if hasPropertyFlag(props, "electricity") or hasPropertyFlag(props, "Electricity") then
        return false
    end
    return true
end

function Consumers.isExcludedObject(obj)
    if not obj then
        return false
    end
    if isPassiveTelevisionObject(obj) or isBatteryRadioObject(obj) then
        return true
    end
    return isNonElectricForgeObject(obj)
end

local function sanitizeIdPart(value)
    return string.gsub(tostring(value or ""), "[^%w_%-]", "_")
end

function Consumers.GetObjectId(obj)
    if not obj then
        return nil
    end
    local md = getObjectModData(obj)
    if md and type(md.EnergyRoutingConsumerId) == "string" then
        return md.EnergyRoutingConsumerId
    end

    local sq = getObjectSquare(obj)
    if not sq then
        return nil
    end

    local suffix = nil
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    local itemId = item and safeCall(item, "getID") or nil
    if type(itemId) == "number" and itemId >= 0 then
        suffix = "item_" .. tostring(itemId)
    end

    if not suffix then
        local objectIndex = safeCall(obj, "getObjectIndex")
        if type(objectIndex) == "number" and objectIndex >= 0 then
            suffix = "idx_" .. tostring(objectIndex)
        end
    end

    if not suffix then
        local sprite = safeCall(obj, "getSprite")
        local spriteName = sprite and safeCall(sprite, "getName") or nil
        suffix = sanitizeIdPart(spriteName or safeCall(obj, "getObjectName") or safeCall(obj, "getName") or "object")
    end

    local id = string.format(
        "consumer_%d_%d_%d_%s",
        sq:getX(),
        sq:getY(),
        sq:getZ(),
        suffix
    )
    if md then
        md.EnergyRoutingConsumerId = id
    end
    return id
end

function Consumers.ClassifyConsumer(obj)
    if not obj then
        return nil, nil
    end
    if Consumers.isExcludedObject(obj) then
        return nil, nil
    end

    local sprite = safeCall(obj, "getSprite")
    local spriteName = sprite and safeCall(sprite, "getName") or nil
    local probe = buildProbeText(obj)
    local groupId, watts = nil, nil

    if isRefrigerationLikeObject(obj) then
        return "refrigeration", normalizeConsumption(defaultGroupWatts("refrigeration"), "refrigeration")
    end

    if EnergyRouting.ClassifyObject then
        if probe ~= "" then
            groupId, watts = EnergyRouting.ClassifyObject(probe)
        end
        if not groupId then
            groupId, watts = EnergyRouting.ClassifyObject(spriteName)
        end
    end

    if probeIndicatesRefrigeration(probe) then
        groupId = "refrigeration"
        if tonumber(watts) == nil or tonumber(watts) <= 0 then
            watts = defaultGroupWatts("refrigeration")
        end
    end

    if groupId then
        local normalized = normalizeGroup(groupId)
        if normalized then
            watts = tonumber(watts) or 0
            if watts <= 0 then
                watts = defaultGroupWatts(normalized)
            end
            return normalized, normalizeConsumption(watts, normalized)
        end
    end

    local server = EnergyRouting.Server
    if server and server.ClassifyDevice then
        local classified = normalizeGroup(server.ClassifyDevice(obj))
        if classified then
            local usage = server.GetDevicePowerUsage and server.GetDevicePowerUsage(obj) or nil
            usage = tonumber(usage) or 0
            if usage <= 0 then
                usage = defaultGroupWatts(classified)
            end
            return classified, normalizeConsumption(usage, classified)
        end
    end

    return nil, nil
end

local function clearControllerBucket(controllerId, consumerId)
    if not controllerId or not consumerId then
        return
    end
    local bucket = Consumers.byController[controllerId]
    if not bucket then
        return
    end
    bucket[consumerId] = nil
    for _ in pairs(bucket) do
        return
    end
    Consumers.byController[controllerId] = nil
end

local function markControllerDirty(controllerId, reason)
    if not controllerId then
        return
    end
    local server = EnergyRouting and EnergyRouting.Server or nil
    if server and server.MarkConsumersDirtyById then
        server.MarkConsumersDirtyById(controllerId, reason)
    end
end

local function assignController(entry, controllerId)
    if not entry then
        return
    end
    local previous = entry.controllerId
    if previous ~= controllerId then
        clearControllerBucket(previous, entry.id)
        markControllerDirty(previous, "consumer_reassigned_out")
    end

    entry.controllerId = controllerId
    if not controllerId then
        return
    end

    local bucket = Consumers.byController[controllerId]
    if not bucket then
        bucket = {}
        Consumers.byController[controllerId] = bucket
    end
    bucket[entry.id] = true
    if previous ~= controllerId then
        markControllerDirty(controllerId, "consumer_reassigned_in")
    end
end

local function refreshEntryClassification(entry)
    if not entry or not entry.object then
        return
    end
    if Consumers.isExcludedObject(entry.object) then
        local hadGroup = entry.group ~= nil or entry.consumption ~= nil
        entry.group = nil
        entry.consumption = nil
        local md = getObjectModData(entry.object)
        if md then
            md.EnergyRoutingGroup = nil
            md.EnergyRoutingConsumption = nil
        end
        if hadGroup then
            markControllerDirty(entry.controllerId, "consumer_excluded")
        end
        return
    end

    local inferredGroup, inferredConsumption = Consumers.ClassifyConsumer(entry.object)
    local currentGroup = normalizeGroup(entry.group)
    local inferred = normalizeGroup(inferredGroup)
    if not currentGroup and not inferred then
        return
    end

    local groupId = inferred or currentGroup
    if not groupId then
        return
    end

    local watts = tonumber(entry.consumption) or 0
    local inferredWatts = tonumber(inferredConsumption) or 0
    if inferred and inferred ~= currentGroup then
        watts = inferredWatts
    end
    if watts <= 0 then
        watts = defaultGroupWatts(groupId)
    end

    local changed = (entry.group ~= groupId) or (tonumber(entry.consumption) ~= tonumber(watts))
    entry.group = groupId
    entry.consumption = normalizeConsumption(watts, groupId)

    local md = getObjectModData(entry.object)
    if md then
        md.EnergyRoutingGroup = entry.group
        md.EnergyRoutingConsumption = entry.consumption
    end

    if changed then
        markControllerDirty(entry.controllerId, "consumer_reclassified")
        local key = entry.id or tostring(entry.object)
        local sig = tostring(currentGroup or "nil") .. "->" .. tostring(groupId)
            .. ":" .. tostring(math.floor(tonumber(entry.consumption) or 0))
        if Consumers._reclassLogById[key] ~= sig then
            Consumers._reclassLogById[key] = sig
            print("[SPESS][Consumers] reclass id=" .. tostring(key)
                .. " from=" .. tostring(currentGroup or "nil")
                .. " to=" .. tostring(groupId)
                .. " watts=" .. tostring(math.floor(tonumber(entry.consumption) or 0)))
        end
    end
end

function Consumers.FindControllerInRange(square, maxRange)
    if not square then
        return nil, nil
    end

    local server = EnergyRouting.Server
    if server and server.FindControllerInRange then
        local controllerObj, controllerId = server.FindControllerInRange(square, maxRange)
        return controllerObj, controllerId
    end

    local range = tonumber(maxRange) or Consumers.MAX_RANGE
    local rangeSq = range * range
    local bestId = nil
    local bestDist = nil
    local bestObj = nil
    local bestPriority = -1
    local sourceBuildingKey = getBuildingKeyFromSquare(square)
    local sourceZ = square:getZ()
    local sourceX = square:getX()
    local sourceY = square:getY()
    local cell = getCell and getCell() or nil
    local edcBuildingKeyCache = {}

    if server and server.edcs then
        for edcId, edc in pairs(server.edcs) do
            if edc and edc.x and edc.y then
                local dx = edc.x - sourceX
                local dy = edc.y - sourceY
                local distSq = dx * dx + dy * dy
                if distSq <= rangeSq then
                    local sameFloor = (edc.z == sourceZ)
                    local sameBuilding = false
                    if sourceBuildingKey and cell and edc.z ~= nil then
                        local cached = edcBuildingKeyCache[edcId]
                        if cached == nil then
                            local edcSq = cell:getGridSquare(edc.x, edc.y, edc.z)
                            cached = getBuildingKeyFromSquare(edcSq) or false
                            edcBuildingKeyCache[edcId] = cached
                        end
                        sameBuilding = (cached ~= false) and (cached == sourceBuildingKey)
                    end

                    local priority = 0
                    if sameBuilding then
                        priority = 2
                    elseif sameFloor then
                        priority = 1
                    end

                    if priority > bestPriority or (priority == bestPriority and (not bestDist or distSq < bestDist)) then
                        bestPriority = priority
                        bestId = edcId
                        bestDist = distSq
                    end
                end
            end
        end
    end

    if bestId and server and server.GetControllerObject then
        bestObj = server.GetControllerObject(bestId)
    end
    return bestObj, bestId
end

function Consumers.GetControllerForConsumer(obj, maxRange)
    local sq = getObjectSquare(obj)
    if not sq then
        return nil
    end
    local _, controllerId = Consumers.FindControllerInRange(sq, maxRange or Consumers.MAX_RANGE)
    return controllerId
end

local function canBeConsumer(obj)
    if not obj then
        return false
    end

    local server = EnergyRouting.Server
    if server and server.IsEDCObject and server.IsEDCObject(obj) then
        return false
    end

    if EnergyController and EnergyController.Server then
        local ecs = EnergyController.Server
        if (ecs.IsControllerObject and ecs.IsControllerObject(obj))
            or (ecs.IsWorldControllerObject and ecs.IsWorldControllerObject(obj))
            or (ecs.IsPanelObject and ecs.IsPanelObject(obj))
            or (ecs.IsBatteryObject and ecs.IsBatteryObject(obj))
            or (ecs.IsWindObject and ecs.IsWindObject(obj))
            or (ecs.IsWindBatteryObject and ecs.IsWindBatteryObject(obj)) then
            return false
        end
    end

    local groupId = select(1, Consumers.ClassifyConsumer(obj))
    return groupId ~= nil
end

function Consumers.RegisterConsumer(obj, group, consumption)
    local forcedGroup = normalizeGroup(group)
    if not obj then
        return nil
    end
    if not canBeConsumer(obj) and not forcedGroup then
        return nil
    end

    local objectId = Consumers.GetObjectId(obj)
    if not objectId then
        return nil
    end

    local inferredGroup, inferredConsumption = Consumers.ClassifyConsumer(obj)
    local groupId = forcedGroup or inferredGroup
    if not groupId then
        return nil
    end

    local watts = normalizeConsumption(consumption or inferredConsumption or defaultGroupWatts(groupId), groupId)
    local entry = Consumers.registry[objectId] or { id = objectId }
    entry.object = obj
    entry.group = groupId
    entry.consumption = watts

    local sq = getObjectSquare(obj)
    if sq then
        entry.x = sq:getX()
        entry.y = sq:getY()
        entry.z = sq:getZ()
    end

    assignController(entry, Consumers.GetControllerForConsumer(obj, Consumers.MAX_RANGE))
    Consumers.registry[objectId] = entry

    local md = getObjectModData(obj)
    if md then
        md.EnergyRoutingGroup = groupId
        md.EnergyRoutingConsumption = watts
        md.EnergyRoutingConsumerId = objectId
        md.EnergyRoutingConsumerControllerId = entry.controllerId
    end
    markControllerDirty(entry.controllerId, "consumer_registered")
    return entry
end

function Consumers.UnregisterConsumer(objOrId)
    local consumerId = nil
    if type(objOrId) == "string" then
        consumerId = objOrId
    else
        local md = getObjectModData(objOrId)
        if md and type(md.EnergyRoutingConsumerId) == "string" then
            consumerId = md.EnergyRoutingConsumerId
            md.EnergyRoutingConsumerControllerId = nil
        else
            consumerId = Consumers.GetObjectId(objOrId)
        end
    end

    if not consumerId then
        return
    end
    local entry = Consumers.registry[consumerId]
    if not entry then
        return
    end

    local previousControllerId = entry.controllerId
    clearControllerBucket(entry.controllerId, consumerId)
    Consumers.registry[consumerId] = nil
    markControllerDirty(previousControllerId, "consumer_unregistered")
end

function Consumers.GetByController(controllerId)
    local results = {}
    if not controllerId then
        return results
    end

    local bucket = Consumers.byController[controllerId]
    if not bucket then
        return results
    end

    local ids = {}
    for consumerId in pairs(bucket) do
        table.insert(ids, consumerId)
    end

    for _, consumerId in ipairs(ids) do
        local entry = Consumers.registry[consumerId]
        if not entry or not entry.object then
            clearControllerBucket(controllerId, consumerId)
        else
            refreshEntryClassification(entry)
            if not normalizeGroup(entry.group) then
                Consumers.UnregisterConsumer(consumerId)
            else
                local controllerForEntry = Consumers.GetControllerForConsumer(entry.object, Consumers.MAX_RANGE)
                if controllerForEntry ~= controllerId then
                    assignController(entry, controllerForEntry)
                    local md = getObjectModData(entry.object)
                    if md then
                        md.EnergyRoutingConsumerControllerId = controllerForEntry
                    end
                elseif canBeConsumer(entry.object) then
                    table.insert(results, entry)
                else
                    Consumers.UnregisterConsumer(consumerId)
                end
            end
        end
    end

    return results
end

function Consumers.RestoreFromEDCs(edcs)
    if type(edcs) ~= "table" then
        return
    end
    for controllerId, edc in pairs(edcs) do
        local consumers = edc and edc.consumers
        if type(consumers) == "table" then
            for consumerId, data in pairs(consumers) do
                if type(data) == "table" then
                    local groupId = normalizeGroup(data.group)
                    if groupId then
                        local entry = Consumers.registry[consumerId] or { id = consumerId }
                        entry.group = groupId
                        entry.consumption = normalizeConsumption(data.consumption, groupId)
                        entry.object = entry.object or nil
                        entry.x = data.x
                        entry.y = data.y
                        entry.z = data.z
                        Consumers.registry[consumerId] = entry
                        assignController(entry, controllerId)
                    end
                end
            end
        end
    end
end

function EnergyRouting.RegisterConsumer(obj, group, consumption)
    return Consumers.RegisterConsumer(obj, group, consumption)
end

function EnergyRouting.UnregisterConsumer(obj)
    return Consumers.UnregisterConsumer(obj)
end

function EnergyRouting.GetControllerForConsumer(obj)
    return Consumers.GetControllerForConsumer(obj, Consumers.MAX_RANGE)
end

function Consumers.isPassiveObject(obj)
    return isPassiveTelevisionObject(obj)
end

function Consumers.detectPassive(obj)
    if not isPassiveTelevisionObject(obj) then
        return false
    end
    return safeCall(obj, "isTurnedOn") == true
end

local function onObjectAdded(obj)
    Consumers.RegisterConsumer(obj)
end

local function onObjectRemoved(obj)
    Consumers.UnregisterConsumer(obj)
end

if Events and Events.OnObjectAdded then
    Events.OnObjectAdded.Add(onObjectAdded)
end
if Events and Events.OnObjectAddedToWorld then
    Events.OnObjectAddedToWorld.Add(onObjectAdded)
end
if Events and Events.OnObjectAddedToSquare then
    Events.OnObjectAddedToSquare.Add(onObjectAdded)
end
if Events and Events.OnLoadIsoObject then
    Events.OnLoadIsoObject.Add(onObjectAdded)
end
if Events and Events.OnObjectAboutToBeRemoved then
    Events.OnObjectAboutToBeRemoved.Add(onObjectRemoved)
elseif Events and Events.OnObjectRemoved then
    Events.OnObjectRemoved.Add(onObjectRemoved)
end

