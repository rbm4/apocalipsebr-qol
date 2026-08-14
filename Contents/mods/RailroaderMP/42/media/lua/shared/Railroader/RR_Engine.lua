--***********************************************************************
-- Railroader / RR_Engine  -- diesel-electric START + fuel/battery model
-- (engine-start mechanic). Models an EMD GP10 prime mover that must be
-- CRANKED to life by the driver instead of spawning already running.
--
-- PURE LUA, NO ENGINE DEPENDENCIES -- so it unit-tests in a bare interpreter
-- (tests/run_tests.lua). The client adapter (RR_Ride crank poll +
-- RR_TrainEntity per-tick) feeds it dt / a random roll / a weather env and
-- reads back the phase, the available power (warm-up), and fuel/battery.
--
-- Real diesel-electric start (simplified for gameplay): the driver first runs the
-- electric FUEL PRIME pump (it hums) to prime the fuel system, THEN the battery turns
-- the main generator as a starter motor to crank the diesel; it fires once fuel +
-- compression are there, then warms from a fast idle to full power. Reproduced as:
--   OFF --(hold starter)--> PRIMING (fuel pump hums, sips charge)
--   PRIMING, after PRIME_TIME --> CRANKING (starter turns, battery drains)
--   CRANKING, after CRANK_TIME --(roll vs startChance)--> WARMUP or back (fail)
--   WARMUP, after WARMUP_TIME --> RUNNING (full power)
-- Releasing the starter (crankReset) drops BOTH timers -- the next attempt re-primes.
-- A failed catch keeps the prime (you go on cranking a primed system).
-- Conditions gating a successful catch (all fold into startChance/tryStart):
--   * fuel > 0            (else it cranks but never fires)
--   * battery >= CRANK_MIN(else the starter won't even turn -- a dead "click")
--   * warm/dry/healthy    (cold, rain, worn engine, stale fuel each lower the
--                          catch chance -> may need several cranks)
-- A running engine burns fuel (idle floor + load) and RECHARGES its battery off
-- the generator, so the only real battery risk is the first/cold start.
-- (The reverser-in-Neutral interlock lives in the control layer, RR_Ride, since
-- it is a driver-UX gate, not prime-mover physics.)
--***********************************************************************

local Engine = {}

-- Tunables (GP10; playability first). One place for tests + in-game tuning.
local C = {
    NOTCH_MAX      = 8,        -- mirror RR_Drive throttle range (idle 0 .. Run 8)

    -- Condition (0..1). Below/at this the loco is IMMOBILIZED (Task 1.N step 5): a soft
    -- mechanical failure -- it makes NO tractive power (won't roll under throttle) even with
    -- the diesel running, yet stays ON the rails and still coasts/brakes. Distinct from a
    -- DERAIL (terminal, off-rails -- Step 6). Recoverable once a repair path exists. Kept a
    -- pure config value so maxNotch stays engine-free + unit-testable. 0.0 == "condition
    -- reached 0" (matches Obstacle.WRECK_AT); condition bottoms at exactly 0 via math.max.
    IMMOBILIZE_AT  = 0.0,

    -- ===== Condition DEGRADATION (Task 1.N step 5, owner spec 2026-07-24) =====
    -- Calibrated to be INVISIBLE up top (a healthy loco never throttles/stalls) and to
    -- bite hard low down: the player should FEEL the loco dying, not be nagged. Every
    -- curve here is a pure function unit-tested in run_tests.lua; the engine-side only
    -- rolls them. Expect to soften these after playtests (a stalled train mid-horde is an
    -- infarct, not a symptom) -- that is exactly why they live in ONE config block.
    TRACTION_FULL_AT   = 0.50,   -- cond >= this => full tractive effort (no debuff at all)
    TRACTION_FLOOR     = 0.30,   -- hard floor on the traction multiplier: a dying loco still crawls
    STALL_AT           = 0.25,   -- below this the engine can randomly stall (both triggers)
    STALL_UP_K         = 0.60,   -- throttle-up stall: chance = (STALL_AT-cond)*K   (0.20 cond => 3%)
    STALL_MIN_K        = 0.25,   -- per-minute-under-load stall: chance = (STALL_AT-cond)*K per 60 s
    STALL_CHECK_PERIOD = 60.0,   -- s of LOADED (in-traction) running between periodic stall rolls
    RESTART_COOL_MIN   = 5.0,    -- s min "cool-down" after a stall before the starter will turn
    RESTART_COOL_MAX   = 10.0,   -- s max
    START_COND_K       = 3.0,    -- gentle start-catch curve: clamp(0.5 + cond*K, 0, 1) (see below)
    SPUTTER_T1         = 0.40,   -- cond < this => light sputter (COSMETIC tiers, spec section 4)
    SPUTTER_T2         = 0.25,   -- cond < this => rougher + darker smoke
    SPUTTER_T3         = 0.10,   -- cond < this => constant misfire

    -- Fuel (abstract diesel units; a "full tank" at spawn). Idle sips; load gulps.
    FUEL_CAP       = 600,      -- units, full tank
    IDLE_BURN      = 0.03,     -- units/s at notch 0 (engine merely idling)
    LOAD_BURN      = 0.20,     -- extra units/s at full load (scales with load 0..1)

    -- Battery (0..1 state of charge).
    BATTERY_FULL   = 1.0,
    CRANK_MIN      = 0.15,     -- below this the starter won't turn (dead "click")
    CRANK_DRAIN    = 0.05,     -- charge/s drained while the starter cranks
    RECHARGE_RATE  = 0.02,     -- charge/s put back by the generator while running

    -- Timing.
    PRIME_TIME     = 1.5,      -- s the electric FUEL PRIME pump runs before the starter turns
    PRIME_DRAIN    = 0.01,     -- charge/s drained by the fuel pump (small next to the starter)
    CRANK_TIME     = 1.6,      -- s of continuous cranking before a catch is attempted
    WARMUP_TIME    = 4.0,      -- s from catch (fast idle) to full available power
    WARM_MIN_POWER = 0.35,     -- power fraction usable the instant it catches

    -- Start chance factors (all multiply a base; result clamped < 1).
    START_BASE     = 0.97,     -- warm, charged, healthy, good fuel
    BATT_MIN_FAC   = 0.40,     -- catch-chance multiplier at the crank-floor charge
    COLD_FULL_C    = 15,       -- at/above this air temp: no cold penalty
    COLD_ZERO_C    = -10,      -- at/below this: maximum cold penalty
    COLD_MIN_FAC   = 0.45,     -- catch-chance multiplier at the coldest
    WET_FAC        = 0.85,     -- multiplier while raining
}
Engine.C = C

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

--------------------------------------------------------------------------
-- newState: a fresh, COLD engine with a full tank and a charged battery.
--   phase : "off" | "priming" | "cranking" | "warmup" | "running"
--   running is a convenience mirror of (phase == "warmup" or "running").
--   condition / fuelQuality (0..1) are future maintenance/decay hooks; default
--   ideal so the base chance holds until those systems exist.
--------------------------------------------------------------------------
function Engine.newState()
    return {
        running     = false,
        phase       = "off",
        fuel        = C.FUEL_CAP,
        battery     = C.BATTERY_FULL,
        primeTime   = 0.0,
        crankTime   = 0.0,
        warmupTime  = 0.0,
        condition   = 1.0,
        fuelQuality = 1.0,
    }
end

--------------------------------------------------------------------------
-- canCrank(s, env): is there enough charge to physically turn the starter? Below
-- CRANK_MIN the driver gets only a dead click (handled in tryStart -> "flat") --
-- UNLESS an external source is jumping it (env.externalPower: a generator powering
-- the loco's square, or live grid power inside a building). A jump supplies the
-- cranking current directly, so a stone-dead bank still turns the starter. There is
-- no wayside battery charger on the K&L branch -- a flat bank is jumped, then the
-- engine's own generator (RECHARGE_RATE) brings it back once running.
--------------------------------------------------------------------------
function Engine.canCrank(s, env)
    if env and env.externalPower then return true end
    return (s.battery or 0) >= C.CRANK_MIN
end

--------------------------------------------------------------------------
-- canOperate(env): is whoever is at the controls ALLOWED to work this loco?
-- The Railroader licence (the rr:railroader trait, Task 1.F) enters the pure model
-- ONLY here, as a plain boolean on the env the caller already passes -- the module
-- never reads a player or the engine API, so it still unit-tests in bare Lua.
--
--   env.licensed == false  -> not allowed (no start, no tractive power)
--   env.licensed == true / absent / env nil -> allowed
-- Default-allow is deliberate: every pre-1.F caller (and every old unit test) keeps
-- its behaviour, and only the control layer that KNOWS the driver has to say "no".
--------------------------------------------------------------------------
function Engine.canOperate(env)
    return not (env and env.licensed == false)
end

--------------------------------------------------------------------------
-- coldFactor(tempC): 1 when warm (>= COLD_FULL_C), falling linearly to
-- COLD_MIN_FAC at/below COLD_ZERO_C. nil temp (no weather data) => 1 (no penalty).
--------------------------------------------------------------------------
function Engine.coldFactor(tempC)
    if tempC == nil then return 1.0 end
    if tempC >= C.COLD_FULL_C then return 1.0 end
    if tempC <= C.COLD_ZERO_C then return C.COLD_MIN_FAC end
    local f = (tempC - C.COLD_ZERO_C) / (C.COLD_FULL_C - C.COLD_ZERO_C)  -- 0..1
    return C.COLD_MIN_FAC + f * (1.0 - C.COLD_MIN_FAC)
end

--------------------------------------------------------------------------
-- startChance(s, env): probability [0..~0.99) that a crank attempt catches.
-- Product of independent factors: battery charge, engine condition, fuel
-- quality, cold, wet. env = { tempC=, wet=, externalPower= } (all optional).
-- Fuel PRESENCE is a hard gate handled in tryStart, not a probability here.
--------------------------------------------------------------------------
function Engine.startChance(s, env)
    env = env or {}
    -- battery: BATT_MIN_FAC at the crank floor -> 1 at full charge. A jump-start
    -- (env.externalPower) supplies the cranking current, so the bank's own charge no
    -- longer limits the crank -> treat the battery factor as full.
    local bf
    if env.externalPower then
        bf = 1
    else
        bf = clamp(((s.battery or 0) - C.CRANK_MIN) / (C.BATTERY_FULL - C.CRANK_MIN), 0, 1)
    end
    local batt = C.BATT_MIN_FAC + bf * (1.0 - C.BATT_MIN_FAC)
    -- Condition's effect on the catch chance uses the GENTLE degradation curve (owner spec
    -- 2026-07-24): no penalty until condition is low, then it bites -- so a worn-but-alive
    -- loco still restarts in 1-2 attempts (cond 0.10 => ~0.80). At/below IMMOBILIZE_AT it is
    -- 0 (out of order: can't start at all). Replaces the old raw linear cond multiplier,
    -- which made a low-condition loco effectively unstartable.
    local cond = Engine.conditionStartFactor(s.condition)
    local fq   = clamp(s.fuelQuality or 1, 0, 1)
    local cold = Engine.coldFactor(env.tempC)
    local wet  = env.wet and C.WET_FAC or 1.0

    local chance = C.START_BASE * batt * cond * fq * cold * wet
    return clamp(chance, 0, 0.99)
end

--------------------------------------------------------------------------
-- primeTick(s, dt): the FUEL PRIME pump is running THIS tick. On a real EMD the
-- driver primes the fuel system (an electric pump that hums) BEFORE the starter
-- turns -- so the prime must complete before cranking begins. Accumulates prime
-- time and sips a little charge. Sets phase = "priming".
--------------------------------------------------------------------------
function Engine.primeTick(s, dt)
    dt = dt or 0
    if s.running then return end
    s.phase     = "priming"
    s.primeTime = (s.primeTime or 0) + dt
    s.battery   = clamp((s.battery or 0) - C.PRIME_DRAIN * dt, 0, C.BATTERY_FULL)
end

--------------------------------------------------------------------------
-- primeReady(s): has the fuel pump primed long enough for the starter to engage?
-- (A failed catch does NOT clear the prime -- you keep cranking on a primed system.
-- Letting go of the starter does, via crankReset.)
--------------------------------------------------------------------------
function Engine.primeReady(s)
    return (s.primeTime or 0) >= C.PRIME_TIME
end

--------------------------------------------------------------------------
-- crankTick(s, dt): the starter is turning THIS tick. Drains the battery and
-- accumulates crank time (toward crankReady). Sets phase = "cranking".
--------------------------------------------------------------------------
function Engine.crankTick(s, dt)
    dt = dt or 0
    if s.running then return end
    s.phase     = "cranking"
    s.crankTime = (s.crankTime or 0) + dt
    s.battery   = clamp((s.battery or 0) - C.CRANK_DRAIN * dt, 0, C.BATTERY_FULL)
end

--------------------------------------------------------------------------
-- crankReady(s): has the starter turned long enough to attempt a catch?
--------------------------------------------------------------------------
function Engine.crankReady(s)
    return (s.crankTime or 0) >= C.CRANK_TIME
end

--------------------------------------------------------------------------
-- crankReset(s): the driver let go of the starter (or a catch was resolved).
-- Zeroes the crank AND prime timers (letting go drops the fuel pump too, so the
-- next attempt re-primes); a still-off engine returns to "off".
--------------------------------------------------------------------------
function Engine.crankReset(s)
    s.crankTime = 0
    s.primeTime = 0
    if not s.running then s.phase = "off" end
end

--------------------------------------------------------------------------
-- tryStart(s, env, roll): resolve one catch attempt (call when crankReady).
--   roll : a random number in [0,1) supplied by the caller (ZombRandFloat
--          in-game; a fixed value in tests) -> deterministic + pure.
-- Returns one of: "started" | "failed" | "nofuel" | "flat" | "nolicense".
--   nolicense: the driver isn't a Railroader (env.licensed == false) -> never fires.
--   nofuel : cranks but no fuel to fire -> stays off.
--   flat   : not enough charge to turn the starter (dead click).
--   started: caught -> phase "warmup", running true.
--   failed : didn't catch this time (crank more; battery already drained).
-- Always zeroes crankTime so the next attempt needs a fresh CRANK_TIME.
--------------------------------------------------------------------------
function Engine.tryStart(s, env, roll)
    -- Licence gate first: the control layer already refuses to crank, this is the
    -- backstop so no path can start a loco for an unlicensed driver.
    if not Engine.canOperate(env) then
        s.crankTime = 0
        return "nolicense"
    end
    if (s.fuel or 0) <= 0 then
        s.crankTime = 0
        return "nofuel"
    end
    if not Engine.canCrank(s, env) then
        s.crankTime = 0
        return "flat"
    end
    s.crankTime = 0
    if (roll or 0) < Engine.startChance(s, env) then
        s.running    = true
        s.phase      = "warmup"
        s.warmupTime = 0
        -- The prime is CONSUMED by a catch: the pump stops once the diesel runs on its
        -- own. A failed catch keeps it (see primeReady), a successful one must not --
        -- a leftover primeTime reads as "the starter is turning" to the fast-forward
        -- interlock, which then pinned a parked, idling loco to 1x for the whole session.
        s.primeTime  = 0
        return "started"
    end
    s.phase = "cranking"   -- keep the loop going if the driver holds the starter
    return "failed"
end

--------------------------------------------------------------------------
-- warmupTick(s, dt): advance the post-catch fast-idle warm-up; promote to
-- "running" (full power) once WARMUP_TIME has elapsed.
--------------------------------------------------------------------------
function Engine.warmupTick(s, dt)
    if s.phase ~= "warmup" then return end
    s.warmupTime = (s.warmupTime or 0) + (dt or 0)
    if s.warmupTime >= C.WARMUP_TIME then
        s.phase = "running"
    end
end

--------------------------------------------------------------------------
-- warmFactor(s): fraction of full power currently available (0..1). 0 when off;
-- ramps WARM_MIN_POWER -> 1 across the warm-up; 1 once fully running.
--------------------------------------------------------------------------
function Engine.warmFactor(s)
    if not s.running then return 0 end
    if s.phase == "running" then return 1 end
    local f = clamp((s.warmupTime or 0) / C.WARMUP_TIME, 0, 1)
    return C.WARM_MIN_POWER + f * (1.0 - C.WARM_MIN_POWER)
end

--------------------------------------------------------------------------
-- maxNotch(s, env): the highest throttle notch the prime mover will honour right
-- now. Full range once running; capped (but always >= 1 so it can crawl) during
-- warm-up; 0 when off. The control layer clamps the driver's lever to this.
-- env is optional -- an UNLICENSED driver (env.licensed == false) gets notch 0: an
-- already-running loco still coasts and brakes under them, it just makes no power.
--
-- IMMOBILIZATION (Task 1.N step 5): a loco whose condition has fallen to 0 (<= IMMOBILIZE_AT)
-- also gets notch 0 -- a SOFT mechanical failure. This gate sits BEFORE the running check so it
-- bites even on a diesel that is warm and running: the loco won't roll under throttle, but still
-- coasts and brakes. Pure input on s.condition, so the module stays engine-free and unit-testable.
-- (Engine-side, owner 2026-07-24: the client STALLS a running diesel the tick condition hits 0 --
-- RR_TrainEntity -- and startChance is then 0, so it can't be cranked back until repaired.)
-- Recoverable once a repair path exists; NOT a derail (that is terminal + off-rails, Step 6).
--------------------------------------------------------------------------
function Engine.maxNotch(s, env)
    if not Engine.canOperate(env) then return 0 end
    if (s.condition or 1) <= (C.IMMOBILIZE_AT or 0) then return 0 end
    if not s.running then return 0 end
    if s.phase == "running" then return C.NOTCH_MAX end
    return math.max(1, math.floor(Engine.warmFactor(s) * C.NOTCH_MAX + 1e-9))
end

--------------------------------------------------------------------------
-- Condition DEGRADATION curves (Task 1.N step 5, owner spec 2026-07-24). All PURE, so
-- unit-tested in bare Lua; the engine-side (RR_TrainEntity / RR_Ride) rolls them.
--------------------------------------------------------------------------

-- tractionMult(cond): multiplier on max tractive effort (and on V_MAX) from condition.
-- Flat 1.0 while healthy (cond >= TRACTION_FULL_AT), then LINEAR 1.0 -> 0.5 down to cond 0,
-- with a hard TRACTION_FLOOR so even a wrecked-but-alive loco can still crawl home (a floor
-- is what keeps "low condition" a warning, not a synonym for death).
--   cond 1.0..0.5 => 1.00 · 0.40 => 0.90 · 0.25 => 0.75 · 0.10 => 0.60 · 0 => 0.50 (>= floor)
function Engine.tractionMult(cond)
    cond = clamp(cond or 1, 0, 1)
    if cond >= C.TRACTION_FULL_AT then return 1.0 end
    local m = 0.5 + (cond / C.TRACTION_FULL_AT) * 0.5   -- 1.0 at FULL_AT -> 0.5 at 0
    if m < C.TRACTION_FLOOR then m = C.TRACTION_FLOOR end
    return m
end

-- conditionStartFactor(cond): condition's contribution to the START catch chance (a factor
-- folded into startChance). Gentle: clamp(0.5 + cond*START_COND_K, 0, 1) -- saturates to 1
-- (no penalty) by cond ~0.17, is ~0.80 at cond 0.10, ~0.59 at 0.03. At/below IMMOBILIZE_AT
-- the loco is OUT OF ORDER -> 0 (cannot be started until repaired).
function Engine.conditionStartFactor(cond)
    cond = cond or 1
    if cond <= (C.IMMOBILIZE_AT or 0) then return 0 end
    return clamp(0.5 + cond * C.START_COND_K, 0, 1)
end

-- stallChanceThrottleUp(cond): probability [0..1] that DEMANDING more power (a notch-up)
-- kills a worn engine. Zero at/above STALL_AT; below it grows linearly.
--   cond 0.20 => 0.03 · 0.15 => 0.06 · 0.10 => 0.09 · 0.05 => 0.12 · 0.01 => ~0.14
function Engine.stallChanceThrottleUp(cond)
    cond = clamp(cond or 1, 0, 1)
    if cond >= C.STALL_AT then return 0 end
    return (C.STALL_AT - cond) * C.STALL_UP_K
end

-- stallChancePerMin(cond): probability [0..1] the engine dies during ONE periodic check
-- (once per STALL_CHECK_PERIOD of in-traction running). Zero at/above STALL_AT.
--   cond 0.10 => ~0.0375 (a stall every ~27 min of running) · 0.05 => 0.05 (~20 min)
function Engine.stallChancePerMin(cond)
    cond = clamp(cond or 1, 0, 1)
    if cond >= C.STALL_AT then return 0 end
    return (C.STALL_AT - cond) * C.STALL_MIN_K
end

-- sputterTier(cond): COSMETIC severity 0..3 for the audio/visual precursors (spec section 4)
-- -- 0 healthy, 1 occasional cough (< SPUTTER_T1), 2 rough + darker smoke (< SPUTTER_T2),
-- 3 constant misfire (< SPUTTER_T3). Pure tier only; the actual sound/particles are wired
-- engine-side (deferred follow-up). 0 when out of order (a dead engine doesn't sputter).
function Engine.sputterTier(cond)
    cond = clamp(cond or 1, 0, 1)
    if cond <= (C.IMMOBILIZE_AT or 0) then return 0 end
    if cond < C.SPUTTER_T3 then return 3 end
    if cond < C.SPUTTER_T2 then return 2 end
    if cond < C.SPUTTER_T1 then return 1 end
    return 0
end

--------------------------------------------------------------------------
-- runTick(s, dt, load): a running engine burns fuel (idle floor + load) and the
-- generator tops the battery back up. load = 0..1 (notchEff / NOTCH_MAX).
-- Returns true if the tank JUST ran dry this tick (caller stalls the engine).
--------------------------------------------------------------------------
function Engine.runTick(s, dt, load)
    if not s.running then return false end
    dt = dt or 0
    local l    = clamp(load or 0, 0, 1)
    local burn = (C.IDLE_BURN + C.LOAD_BURN * l) * dt
    local had  = (s.fuel or 0) > 0
    s.fuel     = clamp((s.fuel or 0) - burn, 0, C.FUEL_CAP)
    s.battery  = clamp((s.battery or 0) + C.RECHARGE_RATE * dt, 0, C.BATTERY_FULL)
    return had and s.fuel <= 0
end

--------------------------------------------------------------------------
-- stop(s): normal shutdown (driver) or a stall (out of fuel). Back to cold OFF;
-- fuel/battery are preserved.
--------------------------------------------------------------------------
function Engine.stop(s)
    s.running    = false
    s.phase      = "off"
    s.primeTime  = 0
    s.crankTime  = 0
    s.warmupTime = 0
end

--------------------------------------------------------------------------
-- forceStart(s): DEBUG bypass (the G auto-cruise) -- skip the crank/warm-up and
-- put the engine straight into full-power RUNNING.
--------------------------------------------------------------------------
function Engine.forceStart(s)
    s.running    = true
    s.phase      = "running"
    s.warmupTime = C.WARMUP_TIME
    s.primeTime  = 0
    s.crankTime  = 0
end

--------------------------------------------------------------------------
-- phaseLabel(s): short HUD string for the current phase.
--------------------------------------------------------------------------
function Engine.phaseLabel(s)
    local p = s and s.phase or "off"
    if p == "off"      then return "OFF"     end
    if p == "priming"  then return "PRIME"   end
    if p == "cranking" then return "START"   end
    if p == "warmup"   then return "WARMING" end
    if p == "running"  then return "RUNNING" end
    return p
end

RR = RR or {}
RR.Engine = Engine

return Engine
