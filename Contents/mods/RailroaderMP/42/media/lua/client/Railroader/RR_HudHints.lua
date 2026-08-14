--***********************************************************************
-- Railroader / RR_HudHints  -- the control stand's teaching layer (Task 2.D)
--
-- A first-time driver has no way to guess the order of operations: the diesel can
-- only be started with the reverser CENTRED, so every player without exception
-- ends up with a running engine, a throttle that climbs, and a locomotive that
-- will not move. The panel therefore names the next action, in the box where that
-- action lives -- see RR_HudModel.hint for the state machine.
--
-- The one rule that matters: A HINT MUST RETIRE. Somebody with fifty hours in the
-- cab should not be told to press R every time they sit down. Each hint has an id
-- and is flagged the first time the player performs it; after that it never shows
-- again. Flags live in the save's global ModData under "RR_World" -- the same
-- channel the depot spawn and the photo album already use -- so they survive
-- reload and are per-save, not per-boot.
--
-- WHICH hint to show is decided in the pure model (unit-tested, engine-free).
-- WHETHER it has already been earned is decided here, because that needs ModData.
--***********************************************************************

local Hints = {}

local MD_TAG = "RR_World"
local MD_KEY = "rrHudHints"

-- Every hint the stand can raise. Order is the order they are earned in.
Hints.IDS = { "start", "reverser", "throttle", "stop" }

local cache          -- the flag table, read once per session
local prevRunning    -- for spotting the running -> off edge (the shutdown hint)

local function flags()
    if cache then return cache end
    pcall(function()
        local wd = ModData.getOrCreate(MD_TAG)
        if wd then
            wd[MD_KEY] = wd[MD_KEY] or {}
            cache = wd[MD_KEY]
        end
    end)
    cache = cache or {}      -- if ModData is unavailable, hints just never persist
    return cache
end

function Hints.done(id)
    return flags()[id] == true
end

function Hints.mark(id)
    local f = flags()
    if f[id] then return false end
    f[id] = true
    print("[Railroader] hint learned: " .. tostring(id))
    return true
end

--------------------------------------------------------------------------
-- observe(e): retire hints by watching what the driver actually does, rather
-- than by hooking every call site. One place to read, nothing to keep in sync.
--------------------------------------------------------------------------
function Hints.observe(e)
    if not e then return end
    local eng     = e.engine
    local running = eng ~= nil and (eng.phase == "running" or eng.phase == "warmup")

    if running then Hints.mark("start") end
    if (e.reverser or 0) ~= 0 then Hints.mark("reverser") end
    if (e.throttle or 0) > 0 then Hints.mark("throttle") end
    -- the shutdown hint is earned on the running -> off edge, which is the only
    -- moment that says the driver did it on purpose
    if prevRunning and not running and eng and eng.phase == "off" then
        Hints.mark("stop")
    end
    prevRunning = running
end

-- markFromState(e): call after an action that should retire a hint immediately
-- rather than on the next tick (the reverser, which the player may cycle back to
-- neutral in the same breath).
function Hints.markFromState(e)
    if e and (e.reverser or 0) ~= 0 then Hints.mark("reverser") end
end

-- doneSet(): the shape RR_HudModel.hint expects.
function Hints.doneSet()
    local f, out = flags(), {}
    for _, id in ipairs(Hints.IDS) do out[id] = (f[id] == true) end
    return out
end

-- Debug/testing: bring the whole teaching layer back for this save.
function Hints.reset()
    local f = flags()
    for _, id in ipairs(Hints.IDS) do f[id] = nil end
    print("[Railroader] control-stand hints reset -- they will show again.")
end

Events.OnGameStart.Add(function() cache = nil; prevRunning = nil end)

RR = RR or {}
RR.HudHints = Hints

return Hints
