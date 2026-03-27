-- Shared definitions for the solar energy network
EnergyNetwork = EnergyNetwork or {}

EnergyNetwork.VERSION = "1.0"
EnergyNetwork.MOD_ID = "EnergyRouting"

EnergyNetwork.Defaults = {
    MaxPanels = 4,
    MaxBatteries = 2,
    BaseBatteryCapacity = 100000,
    BaseChargeRate = 5,
    PanelBonusH = 0.25,
    PanelBonusV = 0.35,
    PanelConnectRadius = 8,
    BatteryConnectRadius = 6,
    ControllerConnectRadius = 20,
    TickMinutes = 10,
    ConditionLossRate = 0.0005,
    RepairMin = 0.20,
    RepairMax = 0.40,
    MaxRepairCondition = 0.99,
}

local function safeNumber(value, fallback)
    if type(value) == "number" then
        return value
    end
    return fallback
end

function EnergyNetwork.GetSandboxVar(name, defaultValue)
    local vars = SandboxVars and SandboxVars.EnergyNetwork
    if vars and vars[name] ~= nil then
        return vars[name]
    end
    return defaultValue
end

function EnergyNetwork.GetConfigValue(name)
    return EnergyNetwork.GetSandboxVar(name, EnergyNetwork.Defaults[name])
end

function EnergyNetwork.MakeNetId(x, y, z)
    return "energy_net_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(z)
end

function EnergyNetwork.MakeBatteryId(x, y, z)
    return "battery_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(z)
end

function EnergyNetwork.MakePanelId(x, y, z)
    return "panel_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(z)
end

function EnergyNetwork.ParseCoordsFromId(id, prefix)
    if not id then
        return nil
    end
    local pattern = "^" .. prefix .. "_(-?%d+)_(-?%d+)_(-?%d+)$"
    local xs, ys, zs = string.match(id, pattern)
    if not xs or not ys or not zs then
        return nil
    end
    return tonumber(xs), tonumber(ys), tonumber(zs)
end

function EnergyNetwork.GetConditionMultiplier(condition)
    local cond = safeNumber(condition, 1.0)
    if cond >= 0.75 then
        return 1.0
    elseif cond >= 0.50 then
        return 0.90
    elseif cond >= 0.25 then
        return 0.75
    end
    return 0.50
end

function EnergyNetwork.Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function EnergyNetwork.HasOutput(obj)
    if not obj or not obj.getModData then
        return false
    end
    local md = obj:getModData()
    return md and md.output and md.output.type ~= nil
end

function EnergyNetwork.HasInput(obj)
    if not obj or not obj.getModData then
        return false
    end
    local md = obj:getModData()
    return md and md.input and md.input.type ~= nil
end

function EnergyNetwork.Connect(panelObj, batteryObj)
    if not panelObj or not batteryObj then
        return false
    end
    if not panelObj.getModData or not batteryObj.getModData then
        return false
    end
    local pSq = panelObj.getSquare and panelObj:getSquare() or nil
    local bSq = batteryObj.getSquare and batteryObj:getSquare() or nil
    if not pSq or not bSq then
        return false
    end

    local pMD = panelObj:getModData()
    local bMD = batteryObj:getModData()

    pMD.output = {
        type = "battery",
        target = { x = bSq:getX(), y = bSq:getY(), z = bSq:getZ() },
    }

    bMD.input = {
        type = "solar",
        source = { x = pSq:getX(), y = pSq:getY(), z = pSq:getZ() },
    }

    if panelObj.transmitCompleteItemToClients then
        panelObj:transmitCompleteItemToClients()
    elseif panelObj.transmitModData then
        panelObj:transmitModData()
    end

    if batteryObj.transmitCompleteItemToClients then
        batteryObj:transmitCompleteItemToClients()
    elseif batteryObj.transmitModData then
        batteryObj:transmitModData()
    end

    return true
end

function EnergyNetwork.Disconnect(panelObj, batteryObj)
    if not panelObj or not batteryObj then
        return false
    end
    if not panelObj.getModData or not batteryObj.getModData then
        return false
    end

    local pMD = panelObj:getModData()
    local bMD = batteryObj:getModData()
    pMD.output = nil
    bMD.input = nil

    if panelObj.transmitCompleteItemToClients then
        panelObj:transmitCompleteItemToClients()
    elseif panelObj.transmitModData then
        panelObj:transmitModData()
    end

    if batteryObj.transmitCompleteItemToClients then
        batteryObj:transmitCompleteItemToClients()
    elseif batteryObj.transmitModData then
        batteryObj:transmitModData()
    end

    return true
end
