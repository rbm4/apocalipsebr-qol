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
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISWalkToTimedAction"
require "TimedActions/ISTimedActionQueue"

EnergyRouting = EnergyRouting or {}
EnergyRouting.RepairTimedActions = EnergyRouting.RepairTimedActions or {}

local function getObjectModData(obj)
    if not obj then
        return nil
    end
    local item = (obj.getItem and obj:getItem()) or (obj.getInventoryItem and obj:getInventoryItem()) or nil
    if item and item.getModData then
        return item:getModData()
    end
    return obj.getModData and obj:getModData() or nil
end

local function makeId(prefix, obj)
    if not obj or not obj.getSquare then
        return nil
    end
    local sq = obj:getSquare()
    if not sq then
        return nil
    end
    return prefix .. "_" .. tostring(sq:getX()) .. "_" .. tostring(sq:getY()) .. "_" .. tostring(sq:getZ())
end

local function resolveProducerPayload(obj)
    if not obj then
        return nil
    end
    local md = getObjectModData(obj) or {}
    if EnergyRouting.isSolarPanel and EnergyRouting.isSolarPanel(obj) then
        local panelId = md.panel and md.panel.panelId or makeId("panel", obj)
        if not panelId then
            return nil
        end
        return {
            producerType = "panel",
            producerId = panelId,
        }
    end
    if EnergyRouting.isWindTurbine and EnergyRouting.isWindTurbine(obj) then
        local windId = md.wind and md.wind.id or makeId("wind", obj)
        if not windId then
            return nil
        end
        return {
            producerType = "wind",
            producerId = windId,
        }
    end
    if EnergyRouting.isHydroTurbine and EnergyRouting.isHydroTurbine(obj) then
        local hydroId = md.hydro and md.hydro.id or makeId("hydro", obj)
        if not hydroId then
            return nil
        end
        return {
            producerType = "hydro",
            producerId = hydroId,
        }
    end
    return nil
end

EnergyRoutingRepairProducerAction = ISBaseTimedAction:derive("EnergyRoutingRepairProducerAction")

function EnergyRoutingRepairProducerAction:new(character, object, time)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.object = object
    o.maxTime = time or 200
    if character and character.isTimedActionInstant and character:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end

function EnergyRoutingRepairProducerAction:isValid()
    if not self.character or not self.object then
        return false
    end
    if not (self.object.getSquare and self.object:getSquare()) then
        return false
    end
    if EnergyRouting.canRepairProducer and not EnergyRouting.canRepairProducer(self.character, self.object) then
        return false
    end
    return resolveProducerPayload(self.object) ~= nil
end

function EnergyRoutingRepairProducerAction:start()
    self:setActionAnim("Fix")
    self.character:reportEvent("EventFixingItem")
end

function EnergyRoutingRepairProducerAction:perform()
    local payload = resolveProducerPayload(self.object)
    if payload then
        sendClientCommand(self.character, (EnergyRouting and EnergyRouting.MOD_ID) or "EnergyRouting", "RepairProducer", payload)
        print("[SPESS][Repair] queued command type=" .. tostring(payload.producerType) .. " id=" .. tostring(payload.producerId))
    end
    ISBaseTimedAction.perform(self)
end

function EnergyRouting.RepairTimedActions.Queue(playerObj, object, time)
    if not playerObj or not object or not object.getSquare then
        return
    end
    local square = object:getSquare()
    if not square then
        return
    end
    ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, square))
    ISTimedActionQueue.add(EnergyRoutingRepairProducerAction:new(playerObj, object, time or 200))
end

