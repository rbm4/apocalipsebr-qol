local MOD = "FuelStackFix"

local DEBUG = getCore():getDebug()

local function dlog(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][C] " .. tostring(msg))
    end
end

require "TimedActions/ISAddFuelAction"
require "TimedActions/ISBBQAddFuel"
require "EuryBugs/FuelStackFix"

FuelStackFixStartAction = ISBaseTimedAction:derive("FuelStackFixStartAction")

function FuelStackFixStartAction:new(player, tid)
    local o = ISBaseTimedAction.new(self, player)
    o.tid = tid
    o.maxTime = 1
    return o
end

function FuelStackFixStartAction:isValid()
    return true
end

function FuelStackFixStartAction:start()
    if FuelStackFix and self.tid then
        FuelStackFix.queueNext(self.tid)
    end
end

function FuelStackFixStartAction:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================================
-- Client-side fuel chain state
-- ============================================================================

-- ============================================================================
-- Chain control
-- ============================================================================

function FuelStackFix.start(player, target, actionClass, plan)
    FuelStackFix.active = {}
    local tid = FuelStackFix.getTargetKey(target)
    if not tid then return end

    if FuelStackFix.active[tid] then return end

    if type(plan) ~= "table" or #plan <= 0 then
        dlog("start abort empty plan tid=" .. tid)
        return
    end

    FuelStackFix.active[tid] = {
        player = player,
        target = target,
        actionClass = actionClass,
        plan = plan, -- array of { t=fullType, a=fuelAmt }
        idx = 1,
        running = false,
        starterQueued = true,
    }

    dlog("chain started tid=" .. tid .. " steps=" .. tostring(#plan))

    -- Always queue a starter action so it runs after any transfers/unequips already queued
    ISTimedActionQueue.add(FuelStackFixStartAction:new(player, tid))
end

function FuelStackFix.queueNext(tid)
    local st = FuelStackFix.active[tid]
    if not st then return end

    if (not st.plan) or (st.idx > #st.plan) then
        dlog("chain complete tid=" .. tid)
        FuelStackFix.active[tid] = nil
        return
    end

    if st.running then return end

    st.running = true
    local remaining = (#st.plan - st.idx + 1)
    dlog("queueNext tid=" .. tid .. " remaining=" .. tostring(remaining))

    local step = st.plan[st.idx]
    local stepType = step and step.t or nil
    local stepAmt  = step and step.a or nil

    if not (stepType and stepAmt) then
        dlog("queueNext abort bad step tid=" .. tid .. " idx=" .. tostring(st.idx))
        FuelStackFix.active[tid] = nil
        return
    end

    local inv = st.player:getInventory()
    local liveItem = inv and inv:FindAndReturn(stepType) or nil
    if not liveItem then
        dlog("queueNext abort: no live item for type " .. tostring(stepType))
        FuelStackFix.active[tid] = nil
        return
    end

    ISTimedActionQueue.add(
        st.actionClass:new(
            st.player,
            st.target,
            liveItem,
            stepAmt
        )
    )
end

FuelStackFix._deferred = FuelStackFix._deferred or {}

function FuelStackFix.deferQueue(tid)
    if FuelStackFix._deferred[tid] then return end
    FuelStackFix._deferred[tid] = true

    local function onTick()
        Events.OnTick.Remove(onTick)
        FuelStackFix._deferred[tid] = nil
        FuelStackFix.queueNext(tid)
    end

    Events.OnTick.Add(onTick)
end

function FuelStackFix.onStepComplete(tid)
    local st = FuelStackFix.active[tid]
    if not st then return end

    st.running = false
    st.idx = (st.idx or 1) + 1

    local remaining = (st.plan and (#st.plan - st.idx + 1)) or 0
    dlog("stepComplete tid=" .. tid .. " remaining=" .. tostring(remaining))

    -- Defer to next tick so the previous NetTimedAction is fully removed
    if st.plan and st.idx <= #st.plan then
        FuelStackFix.deferQueue(tid)
    else
        dlog("chain complete tid=" .. tid)
        FuelStackFix.active[tid] = nil
    end
end


function FuelStackFix.cancel(tid)
    if FuelStackFix.active[tid] then
        dlog("chain cancelled tid=" .. tid)
        FuelStackFix.active[tid] = nil
    end
end

-- ============================================================================
-- Server → client completion signal
-- ============================================================================

local function onServerCommand(module, command, args)
    if module ~= MOD then return end
    if command ~= "FuelStepComplete" then return end

    FuelStackFix.onStepComplete(args.key)
end

Events.OnServerCommand.Add(onServerCommand)

dlog("Client patch installed")