--***********************************************************************
-- Railroader / RR_SwitchPersist  (Task 1.C-adjacent: switch state survives reload)
--
-- RR_TrackGraph keeps switch states in memory only (d.states[swId]) -- deliberately,
-- so the graph module stays engine-free and unit-tested. This client adapter is the
-- ONE place that talks to the engine's save channel: it mirrors those states into the
-- save's global ModData ("RR_World", the same per-save table the depot spawn flag and
-- the photo-album flag live in) and reads them back on load.
--
-- Why this matters for the reload fix (see RR_TrainEntity.adoptAnimal): a loco's
-- position/orientation are re-derived geometrically and no longer depend on switch
-- state, but which BRANCH lies ahead of it does. Without this, every switch reverted
-- to NORMAL on load, so a loco parked facing a diverging route came back pointed down
-- the main line the moment it moved. Now the lever position is remembered too.
--
-- Shape:  wd.rrSwitches = { [netId] = { [switchId] = "normal"|"reverse" } }
--
-- Load runs on OnGameStart. Ordering vs RR_TrainEntity's reacquire is not load-bearing:
-- if a loco is re-adopted before states load, setState below changes the net's stateKey,
-- which the per-tick reanchor guard detects (stateKey ~= routeStateKey) and rebuilds the
-- loco's route under the loaded states on the next tick. Saves are explicit, from the
-- two (and only two) places a state actually changes: ISRRThrowSwitch:perform (the menu
-- throw) and TrainEntity.toggleNearestSwitch (the debug N key).
--***********************************************************************

print("[Railroader] RR_SwitchPersist.lua: loading...")
require("Railroader/RR_TrackGraph")

local SwitchPersist = {}
local MD_TAG = "RR_World"

local function worldData()
    local wd = nil
    pcall(function() wd = ModData.getOrCreate(MD_TAG) end)
    return wd
end

--------------------------------------------------------------------------
-- save(): dump every registered net's current switch states into ModData. Cheap
-- (a handful of switches); called after a throw, not per tick.
--------------------------------------------------------------------------
function SwitchPersist.save()
    if not (RR.TrackGraph and RR.TrackGraph.defs) then return end
    local wd = worldData()
    if not wd then return end
    wd.rrSwitches = wd.rrSwitches or {}
    for netId, def in pairs(RR.TrackGraph.defs) do
        local netTbl = {}
        for _, sw in ipairs(def.switches) do
            netTbl[sw.id] = def.states[sw.id] or "normal"
        end
        wd.rrSwitches[netId] = netTbl
    end
end

--------------------------------------------------------------------------
-- load(): push saved states back into the graph. Only ids the graph still knows are
-- applied (a switch removed from the def is ignored, not resurrected).
--------------------------------------------------------------------------
function SwitchPersist.load()
    if not (RR.TrackGraph and RR.TrackGraph.defs) then return end
    local wd = worldData()
    if not (wd and wd.rrSwitches) then return end
    local n = 0
    for netId, netTbl in pairs(wd.rrSwitches) do
        if RR.TrackGraph.has(netId) and type(netTbl) == "table" then
            for swId, state in pairs(netTbl) do
                if RR.TrackGraph.setState(netId, swId, state) then n = n + 1 end
            end
        end
    end
    if n > 0 then print("[Railroader] switch states restored: " .. n .. " switch(es).") end
end

Events.OnGameStart.Add(function() pcall(SwitchPersist.load) end)

RR = RR or {}
RR.SwitchPersist = SwitchPersist
print("[Railroader] RR_SwitchPersist.lua: loaded OK")
return SwitchPersist
