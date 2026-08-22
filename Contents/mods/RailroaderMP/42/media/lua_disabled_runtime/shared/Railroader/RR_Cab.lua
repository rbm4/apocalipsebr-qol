--***********************************************************************
-- Railroader / RR_Cab  -- the cab as SHELTER and as a WARM place (Task 1.P)
--
-- PURE LUA, NO ENGINE DEPENDENCIES -- unit-tested in a bare interpreter
-- (tests/run_tests.lua), exactly like RR_Drive / RR_Engine / RR_SleepRules. The
-- adapter that reads the live weather, hangs the heat source on the world and owns
-- the rain-shelter marker is client/Railroader/RR_CabClimate.lua.
--
-- WHAT THIS MODELS, AND WHY IT IS SHAPED LIKE THIS
--
-- A GP7 cab is a steel box with a roof, glass, and a HOT WATER HEATER fed off the
-- diesel's cooling system (a real item in every first-generation EMD cab kit). That
-- gives three distinct effects, and the engine grants them through two DIFFERENT
-- channels -- which is why they are modelled separately here:
--
--   1. RAIN. Handled entirely by the shelter marker in the adapter (a character-level
--      vanilla flag), not by this module. No temperature involved.
--   2. WIND. An outdoor square gets Temperature.WindchillCelsiusKph applied
--      (ClimateManager.getAirTemperatureForSquare). A closed steel cab kills wind
--      chill outright -- even with the diesel DEAD. So a cold cab is NOT "the same as
--      outside": it is outside-air temperature with the wind taken out.
--   3. HEAT. Only while the engine's cooling water is actually hot. That is the whole
--      reason waterC exists: the heater cannot warm anything before the block does,
--      so a freshly-caught diesel gives you nothing for the first several minutes,
--      and a shut-down one keeps giving for half an hour. Engine.WARMUP_TIME (4 s) is
--      a POWER ramp -- an electrical/governor thing -- and says nothing about heat.
--
-- WHY WATER TEMPERATURE AND NOT "CAB TEMPERATURE": there was no cab-air thermometer
-- in a GP7. There WAS a cooling-water temperature gauge on the instrument panel in
-- front of the engineman (EMD SW8/E8 operator's manuals). So waterC is the number the
-- driver is allowed to see, and cab comfort is read off the vanilla moodles, the way
-- the crew read it off their own skin.
--
-- SUMMER IS DEFERRED (owner, 2026-07-28). A steel cab with a running 567 under a July
-- sun is an oven, and hyperthermia is the natural counterweight to free warmth. Not
-- built yet: cabTempC never returns MORE than ambient, so the cab can only ever help.
-- See docs/CAB_CLIMATE_DESIGN.md "Deferred upgrades" -- the knobs (CAB_RISE_C /
-- COMFORT_C plus a solar term) are all in this file, and the heater valve that makes
-- overheating a decision rather than a punishment is designed there too.
--***********************************************************************

local Cab = {}

local C = {
    -- ===== Cooling water (the gauge) =====
    OPERATING_C = 82,    -- degC a healthy 567 settles at (~180 F -- the gauge's normal band)
    HEAT_MIN_C  = 30,    -- below this the heater core moves no useful heat at all
    -- Time constants, in GAME seconds (the adapter feeds dtGame, so fast-forward heats
    -- and cools at the fast-forwarded rate -- same contract as fuel burn). One dtGame
    -- second is ~one REAL second at 1x -- measured off a field log: the 1.5 s FUEL PRIME
    -- took 91 ticks, i.e. 0.0165 dt per tick at 60 tick/s.
    --
    -- CALIBRATED AGAINST A DEATH (2026-07-28). The first field run killed the driver of
    -- hypothermia in a cab with the diesel running. The model was working exactly as
    -- written -- and that was the bug: at TAU_WARM 420 with the heater gated at 40 degC,
    -- a cold block needed ~5 minutes of continuous running before it delivered ANY heat
    -- at all, and the longest run in that session was 3.2 minutes. A dead zone that long
    -- is indistinguishable from a broken feature, and here it was lethal. Now, from
    -- freezing: first warmth at ~1 min, ~15 degC by 3 min, full comfort by ~7 min. Still
    -- unmistakably a warm-up ritual -- just not a death sentence.
    TAU_WARM    = 150,   -- ~2.5 min to 63% of operating from cold
    TAU_COOL    = 1200,  -- ~20 min: an 8x asymmetry, because a loaded engine dumps heat in
                         -- and a dead one only loses it by convection

    -- ===== Cab air =====
    -- COMFORT_C is deliberately vanilla's own indoor number: ClimateManager pins a
    -- powered room to 22 degC, so a heated cab lands exactly where a lit house does --
    -- warm, not tropical.
    COMFORT_C   = 22,
    CAB_RISE_C  = 30,    -- max lift over ambient at full water temp (reaches 22 from -8)

    -- ===== Heat source (the engine-side channel) =====
    -- IsoCell.getHeatSourceHighestTemperature does NOT use the source temperature raw:
    -- outdoors it adds mod = clamp(air - 30, -15, +5) before lerping by distance. So a
    -- campfire's 35 is only 20 degC at freezing. heatSourceTemp() inverts that, which is
    -- why "just use 35 like a fire" is wrong here.
    SRC_RADIUS  = 2,     -- tiles: the cab and one square of spill (also warms someone stood beside it)
    MOD_PIVOT_C = 30,
    MOD_LO      = -15,
    MOD_HI      = 5,
}
Cab.C = C

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

--------------------------------------------------------------------------
-- newState(ambientC): a loco found standing in the weather -- its water is at air
-- temperature, because it has been sitting there since the apocalypse. Missing
-- weather data => a mild 10 degC rather than nil (every consumer wants a number).
--------------------------------------------------------------------------
function Cab.newState(ambientC)
    return { waterC = ambientC or 10 }
end

--------------------------------------------------------------------------
-- tick(s, dt, env) -> waterC
--   env.running  -- is the diesel turning (warmup counts: it is burning fuel)
--   env.ambientC -- outside air temperature, degC
-- First-order approach toward the target with a clamped step, so a huge dt (a
-- fast-forward tick, a hitch) can never overshoot past the target.
--------------------------------------------------------------------------
function Cab.tick(s, dt, env)
    if not s then return nil end
    env = env or {}
    local amb = env.ambientC or 10
    if s.waterC == nil then s.waterC = amb end
    local target = env.running and C.OPERATING_C or amb
    local tau    = env.running and C.TAU_WARM or C.TAU_COOL
    local k = (dt or 0) / tau
    if k > 1 then k = 1 elseif k < 0 then k = 0 end
    s.waterC = s.waterC + (target - s.waterC) * k
    return s.waterC
end

--------------------------------------------------------------------------
-- heatFrac(waterC) -> 0..1: how much of the heater's authority the water can back
-- right now. 0 below HEAT_MIN_C (lukewarm water heats nothing), 1 at operating.
--------------------------------------------------------------------------
function Cab.heatFrac(waterC)
    if waterC == nil then return 0 end
    return clamp((waterC - C.HEAT_MIN_C) / (C.OPERATING_C - C.HEAT_MIN_C), 0, 1)
end

--------------------------------------------------------------------------
-- cabTempC(waterC, ambientC) -> the air temperature INSIDE the cab, degC.
--
--   * floor at ambient -- the cab never reads colder than outside, which is how the
--     wind chill gets cancelled (the engine only ever takes the MAX of air and heat
--     source, and ambient here is the raw, un-windchilled air).
--   * ceiling at COMFORT_C -- the heater is a heater, not a furnace.
--   * never ABOVE ambient in hot weather: summer overheating is deferred, so when
--     ambient is already past COMFORT_C the cab is simply ambient-without-wind.
--------------------------------------------------------------------------
function Cab.cabTempC(waterC, ambientC)
    local amb = ambientC or 10
    local warmed = amb + Cab.heatFrac(waterC) * C.CAB_RISE_C
    if warmed > C.COMFORT_C then warmed = C.COMFORT_C end
    if warmed < amb then warmed = amb end
    return warmed
end

--------------------------------------------------------------------------
-- heatSourceMod(ambientC): the engine's own outdoor correction, reproduced so we can
-- cancel it (IsoCell.getHeatSourceHighestTemperature).
--------------------------------------------------------------------------
function Cab.heatSourceMod(ambientC)
    return clamp((ambientC or 10) - C.MOD_PIVOT_C, C.MOD_LO, C.MOD_HI)
end

--------------------------------------------------------------------------
-- heatSourceTemp(cabC, ambientC) -> the INTEGER temperature to build the
-- IsoHeatSource with, such that a character standing on the source's own tile reads
-- exactly cabC. Inverts the mod above; IsoHeatSource takes an int, so the cab
-- temperature lands within half a degree of the model's.
--
-- The mod is derived from the RAW air temperature while the engine derives it from
-- the wind-chilled one. That is exact everywhere it matters: the two differ only in
-- cold weather, where the clamp has already bottomed out at MOD_LO for both.
--------------------------------------------------------------------------
function Cab.heatSourceTemp(cabC, ambientC)
    local t = (cabC or 0) - Cab.heatSourceMod(ambientC)
    return math.floor(t + 0.5)
end

--------------------------------------------------------------------------
-- wants(s, ambientC, rider) -> true if a heat source is worth having on the world
-- right now. Two reasons, and only two:
--   * somebody is in the cab -- even a stone-cold cab blocks the wind for them;
--   * the water is still hot -- a shut-down loco goes on radiating, so a survivor
--     stood next to it gets the warmth (and can dry off) without a rider aboard.
-- Anything else: no source, no work, nothing on the heat-source list.
--------------------------------------------------------------------------
function Cab.wants(s, ambientC, rider)
    if rider then return true end
    return Cab.heatFrac(s and s.waterC) > 0
end

--------------------------------------------------------------------------
-- waterLabel(waterC): the word for the cooling-water gauge. COLD -> WARMING ->
-- NORMAL -> HOT, matching the bands a driver actually reads off the panel.
-- (The HUD row that shows this is part of the HUD rework -- docs/HUD_DESIGN.md.)
--------------------------------------------------------------------------
function Cab.waterLabel(waterC)
    local w = waterC or 0
    if w < C.HEAT_MIN_C           then return "COLD"    end
    if w < C.OPERATING_C - 10     then return "WARMING" end
    if w <= C.OPERATING_C + 13    then return "NORMAL"  end
    return "HOT"
end

RR = RR or {}
RR.Cab = Cab

return Cab
