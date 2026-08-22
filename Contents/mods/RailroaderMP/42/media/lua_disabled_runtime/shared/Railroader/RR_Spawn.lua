--***********************************************************************
-- Railroader / RR_Spawn  -- WHERE the world's first loco stands, and in WHAT
-- SHAPE the survivor finds it. (Task 1.J: world spawn, not a debug key.)
--
-- PURE LUA, NO ENGINE DEPENDENCIES -- unit-tested in a bare interpreter
-- (tests/run_tests.lua). The client adapter (RR_Depot) supplies the world clock
-- (days since the apocalypse) and the random rolls (ZombRandFloat); everything
-- that decides *what state the loco is in* lives here as pure functions.
--
-- The story: at the outbreak, Knox & Louisville #800 was inside the covered
-- engine shed at the Muldraugh depot -- shut down, parked, waiting for a crew
-- that never came. So:
--   * WHERE  : DEPOT.distance tiles along route "main" from its first node --
--              i.e. inside the shed, NOT on the yard throat.
--   * FUEL   : whatever was left in the tank when it was stabled. A depot unit is
--              normally fuelled at the end of a run, but a unit stabled for shop
--              work may be nearly dry -> a weighted tier roll (FUEL_TIERS).
--              Fuel does not evaporate, so this does NOT depend on the date.
--   * BATTERY: DOES depend on the date. A lead-acid bank with the engine dead
--              self-discharges (plus parasitic loads); the later you find the
--              loco, the flatter it is -- exponential decay with TAU_DAYS.
--   * DIESEL AGEING: fuel goes stale over many months (microbial growth, waxing)
--              -> Engine.fuelQuality drops, lowering the catch chance.
--***********************************************************************

local Engine = (RR and RR.Engine) or require("Railroader/RR_Engine")

local Spawn = {}

--------------------------------------------------------------------------
-- The depot. distance is measured ALONG route "main" from node[1] (the yard
-- end), so the loco always lands ON the rails inside the engine shed, whatever
-- the route's exact geometry.
--------------------------------------------------------------------------
Spawn.DEPOT = {
    routeId  = "main",
    distance = 23173,  -- along "main" to the depot service point. Sampling the spline,
                       -- this = (11606, ~9851) on the depot straight, near its south
                       -- end (the "depot" node at 11606,9859, where the main bends SE
                       -- onto the prepended clockwise section). The main runs THROUGH
                       -- the depot, so the loco is both spawned AND serviced here
                       -- (refuel + jump-start) -- a dead/dry find is revived on the
                       -- spot -- and its body stays on the rails (straight north,
                       -- diagonal south). On this straight 1 tile ~= 1 d, so nudge in
                       -- whole tiles. (Was 23278 north exit -> 23192 -> 23164, 28 tiles
                       -- south each time per the target tank spot. 2026-07-23: +9 -> 23173
                       -- to CANCEL the arc-length shift when the cw_end open-end node moved
                       -- y6883->6874 for Task 1.N derailment -- keeps the depot/tank put.)
    radius   = 40,     -- the loco materialises once the survivor is this close (tiles)
}

--------------------------------------------------------------------------
-- daysSinceApo(worldAgeHours, timeSinceApoOption): days elapsed since the
-- outbreak, NOT since the character spawned. This is exactly the vanilla
-- formula (ISButtonPrompt.lua / ISWorldObjectContextMenuLogic): the sandbox
-- "time since the apocalypse" option is an enum where 1 = day 0 and each further
-- step is one month, and the save's own age is added on top.
--------------------------------------------------------------------------
function Spawn.daysSinceApo(worldAgeHours, timeSinceApoOption)
    local hours = tonumber(worldAgeHours) or 0
    local opt   = tonumber(timeSinceApoOption) or 1
    local days  = hours / 24.0 + (opt - 1) * 30.0
    if days < 0 then days = 0 end
    return days
end

--------------------------------------------------------------------------
-- FUEL. How likely is it that the loco is fuelled at all? Weighted tiers -- the
-- typical find is a half tank (it was stabled part-way through a duty cycle);
-- a full tank and a dry tank are both rare. Weights must sum to 1.
--   dry   10%  : fumes -- a few minutes of running, then it stalls on you
--   low   25%  : enough to shunt around the yard, not to run the line
--   half  40%  : the usual find
--   good  20%  : a decent day's work in the tank
--   full   5%  : fuelled and ready the night the world ended
-- => P(enough fuel to actually go somewhere, i.e. > 25%) ~= 65%.
-- The "dry" band now bottoms out at a TRULY empty tank (lo = 0.00): refuelling
-- exists (RR_Refuel, from the depot reserve at the service point), so an empty tank
-- is a problem to solve, not a dead end. It is still capped low, so a "dry" find is
-- fumes at most and always needs a trip to the pump.
--------------------------------------------------------------------------
Spawn.FUEL_TIERS = {
    { name = "dry",  w = 0.10, lo = 0.00, hi = 0.05 },
    { name = "low",  w = 0.25, lo = 0.05, hi = 0.25 },
    { name = "half", w = 0.40, lo = 0.25, hi = 0.60 },
    { name = "good", w = 0.20, lo = 0.60, hi = 0.90 },
    { name = "full", w = 0.05, lo = 0.90, hi = 1.00 },
}

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

--------------------------------------------------------------------------
-- fuelFraction(rollTier, rollWithin) -> fraction 0..1, tierName.
-- Two independent rolls in [0,1): which tier, then where inside that tier's
-- band. Pure -> the caller feeds ZombRandFloat in-game, fixed numbers in tests.
--------------------------------------------------------------------------
function Spawn.fuelFraction(rollTier, rollWithin)
    local r    = clamp(tonumber(rollTier) or 0, 0, 1)
    local w    = clamp(tonumber(rollWithin) or 0, 0, 1)
    local acc  = 0
    for _, t in ipairs(Spawn.FUEL_TIERS) do
        acc = acc + t.w
        if r < acc then
            return t.lo + w * (t.hi - t.lo), t.name
        end
    end
    local last = Spawn.FUEL_TIERS[#Spawn.FUEL_TIERS]        -- rounding guard
    return last.lo + w * (last.hi - last.lo), last.name
end

--------------------------------------------------------------------------
-- BATTERY. Tunables for the self-discharge model.
--------------------------------------------------------------------------
Spawn.BATT = {
    TAU_DAYS = 100,    -- e-folding time of a dead-engine lead-acid bank
    VAR      = 0.15,   -- +/- spread (some cells hold charge better)
    -- NO playability floor any more. A flat bank can be JUMP-STARTED off external
    -- power (a generator, or live grid inside a building) -- see RR_Engine.canCrank
    -- (env.externalPower) -- so a years-flat find is a puzzle to solve, not a dead
    -- end. It can sit BELOW Engine.CRANK_MIN -- a dead "click" until it is jumped.
}

--------------------------------------------------------------------------
-- battery(days, roll) -> state of charge 0..1 on the day the loco is found.
-- Exponential self-discharge from a full bank, jittered by +/- VAR, clamped only
-- to [0,1]. Rough shape with TAU=100: day 0 ~ full · day 30 ~ 0.74 · day 60 ~ 0.55
-- · day 90 ~ 0.41 · day 180 ~ 0.17 · day 300 ~ 0.05 -> from a few months out you
-- find a tired battery that needs cranking, and a really old find is flat below the
-- crank threshold and must be jump-charged before it will even turn the starter.
--------------------------------------------------------------------------
function Spawn.battery(days, roll)
    local d    = math.max(0, tonumber(days) or 0)
    local r    = clamp(tonumber(roll) or 0.5, 0, 1)
    local base = math.exp(-d / Spawn.BATT.TAU_DAYS)
    local var  = (1 - Spawn.BATT.VAR) + 2 * Spawn.BATT.VAR * r       -- 0.85 .. 1.15
    return clamp(base * var, 0, Engine.C.BATTERY_FULL)
end

--------------------------------------------------------------------------
-- DIESEL AGEING. Fresh for the first FRESH_DAYS, then degrading linearly to MIN
-- by STALE_DAYS (water, microbial growth, waxing in a half-empty tank). Feeds
-- Engine.fuelQuality, which multiplies the catch chance -- old fuel means more
-- cranking, never an impossible start.
--------------------------------------------------------------------------
Spawn.FUELQ = { FRESH_DAYS = 90, STALE_DAYS = 540, MIN = 0.60 }

function Spawn.fuelQuality(days)
    local d = math.max(0, tonumber(days) or 0)
    local F = Spawn.FUELQ
    if d <= F.FRESH_DAYS then return 1.0 end
    if d >= F.STALE_DAYS then return F.MIN end
    local t = (d - F.FRESH_DAYS) / (F.STALE_DAYS - F.FRESH_DAYS)     -- 0..1
    return 1.0 - t * (1.0 - F.MIN)
end

--------------------------------------------------------------------------
-- condition(roll) -> 0.85..1.00. A stabled unit is in serviceable shape; this is
-- the hook a future maintenance/wear system takes over.
--------------------------------------------------------------------------
function Spawn.condition(roll)
    return 0.85 + 0.15 * clamp(tonumber(roll) or 0.5, 0, 1)
end

--------------------------------------------------------------------------
-- rollEngine(days, rolls) -> a COLD Engine state describing the loco as found.
--   rolls = { fuelTier, fuelWithin, battery, condition }, each in [0,1)
--           (ZombRandFloat in-game; fixed values in tests). Missing entries
--           default to 0.5, so rollEngine(days) alone gives the median loco.
-- Returns state, info -- info = { fuelTier=, fuelFrac=, days= } for the log.
--------------------------------------------------------------------------
function Spawn.rollEngine(days, rolls)
    rolls = rolls or {}
    local s = Engine.newState()                      -- cold: off, phase "off"
    local frac, tier = Spawn.fuelFraction(rolls[1] or 0.5, rolls[2] or 0.5)
    s.fuel        = frac * Engine.C.FUEL_CAP
    s.battery     = Spawn.battery(days, rolls[3] or 0.5)
    s.fuelQuality = Spawn.fuelQuality(days)
    s.condition   = Spawn.condition(rolls[4] or 0.5)
    return s, { fuelTier = tier, fuelFrac = frac, days = days }
end

RR = RR or {}
RR.Spawn = Spawn

return Spawn
