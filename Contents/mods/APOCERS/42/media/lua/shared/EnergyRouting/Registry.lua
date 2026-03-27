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
EnergyRouting = EnergyRouting or {}
EnergyRouting.Registry = EnergyRouting.Registry or {}

local Registry = EnergyRouting.Registry

Registry.producers = Registry.producers or {}
Registry.batteries = Registry.batteries or {}

local function normalizeId(value)
    if value == nil then
        return nil
    end
    local id = tostring(value)
    if id == "" then
        return nil
    end
    return id
end

local function cloneTable(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

function Registry.RegisterProducer(data)
    if type(data) ~= "table" then
        return false
    end
    local id = normalizeId(data.id)
    if not id then
        return false
    end
    if type(data.CalculateOutput) ~= "function" then
        print("[ERS][Registry] RegisterProducer rejected: missing CalculateOutput for id=" .. tostring(id))
        return false
    end
    if Registry.producers[id] then
        print("[ERS][Registry] Producer ID already registered: " .. tostring(id))
        return false
    end
    local entry = cloneTable(data)
    entry.id = id
    Registry.producers[id] = entry
    return true
end

function Registry.RegisterBattery(data)
    if type(data) ~= "table" then
        return false
    end
    local id = normalizeId(data.id)
    if not id then
        return false
    end
    if Registry.batteries[id] then
        print("[ERS][Registry] Battery ID already registered: " .. tostring(id))
        return false
    end
    local entry = cloneTable(data)
    entry.id = id
    Registry.batteries[id] = entry
    return true
end

function Registry.UnregisterProducer(id)
    id = normalizeId(id)
    if not id then
        return false
    end
    Registry.producers[id] = nil
    return true
end

function Registry.UnregisterBattery(id)
    id = normalizeId(id)
    if not id then
        return false
    end
    Registry.batteries[id] = nil
    return true
end

function Registry.GetProducer(id)
    id = normalizeId(id)
    return id and Registry.producers[id] or nil
end

function Registry.GetBattery(id)
    id = normalizeId(id)
    return id and Registry.batteries[id] or nil
end

function Registry.GetAllProducers()
    local result = {}
    for _, producer in pairs(Registry.producers) do
        table.insert(result, producer)
    end
    table.sort(result, function(a, b)
        local aOrder = tonumber(a and a.sortOrder) or 1000
        local bOrder = tonumber(b and b.sortOrder) or 1000
        if aOrder == bOrder then
            return tostring(a and a.id or "") < tostring(b and b.id or "")
        end
        return aOrder < bOrder
    end)
    return result
end

function Registry.GetAllBatteries()
    local result = {}
    for _, battery in pairs(Registry.batteries) do
        table.insert(result, battery)
    end
    table.sort(result, function(a, b)
        local aOrder = tonumber(a and a.sortOrder) or 1000
        local bOrder = tonumber(b and b.sortOrder) or 1000
        if aOrder == bOrder then
            return tostring(a and a.id or "") < tostring(b and b.id or "")
        end
        return aOrder < bOrder
    end)
    return result
end

