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

EnergyRoutingTimedAction = ISBaseTimedAction:derive("EnergyRoutingTimedAction")

function EnergyRoutingTimedAction:new(player, command, args, targetSquare, time)
    local o = ISBaseTimedAction:new(player)
    setmetatable(o, self)
    self.__index = self
    o.command = command
    o.args = args
    o.targetSquare = targetSquare
    o.maxTime = time or 60
    if player and player:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end

function EnergyRoutingTimedAction:isValid()
    return self.character ~= nil and self.command ~= nil
end

function EnergyRoutingTimedAction:start()
    self:setActionAnim("Loot")
    self.character:reportEvent("Loot")
end

function EnergyRoutingTimedAction:perform()
    -- DEBUG bueno: imprime el contenido útil
    local cid = self.args and self.args.controllerId or "nil"
    local pid = self.args and self.args.panelId or "nil"
    local bid = self.args and self.args.batteryId or "nil"

    print("[EnergyRouting][Client] TimedAction perform command=" .. tostring(self.command)
        .. " controllerId=" .. tostring(cid)
        .. " panelId=" .. tostring(pid)
        .. " batteryId=" .. tostring(bid))

    if self.command then
        sendClientCommand(self.character, "EnergyRouting", self.command, self.args)
    end

    ISBaseTimedAction.perform(self)
end

EnergyRouting.TimedActions = EnergyRouting.TimedActions or {}

local function shouldQueueWalk(player, targetSquare)
    if not player or not targetSquare or not player.getSquare then
        return true
    end
    local playerSquare = player:getSquare()
    if not playerSquare then
        return true
    end
    if playerSquare == targetSquare then
        return false
    end
    if playerSquare.getZ and targetSquare.getZ and playerSquare:getZ() ~= targetSquare:getZ() then
        return true
    end
    local dx = math.abs((playerSquare:getX() or 0) - (targetSquare:getX() or 0))
    local dy = math.abs((playerSquare:getY() or 0) - (targetSquare:getY() or 0))
    return dx > 1 or dy > 1
end

function EnergyRouting.TimedActions.Queue(player, targetSquare, command, args, time)
    if not player or not targetSquare then
        return
    end
    if shouldQueueWalk(player, targetSquare) then
        ISTimedActionQueue.add(ISWalkToTimedAction:new(player, targetSquare))
    end
    ISTimedActionQueue.add(EnergyRoutingTimedAction:new(player, command, args, targetSquare, time))
end

