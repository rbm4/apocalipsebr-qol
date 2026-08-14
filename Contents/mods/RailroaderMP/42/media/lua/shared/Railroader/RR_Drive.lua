--***********************************************************************
-- Railroader / RR_Drive
-- Longitudinal train physics for the drive loop (Task 1.D), modelling an
-- **EMD GP10** (diesel-electric road switcher; the v1 locomotive).
--
-- PURE LUA, NO ENGINE DEPENDENCIES -- so it unit-tests in a bare interpreter
-- (tests/run_tests.lua). The engine adapter (RR_TrainEntity / RR_Ride) feeds it
-- control inputs + a time step and applies the resulting distance to the spline.
--
-- Physics (per tick), all SI (metres, seconds, Newtons, kg):
--   a = ( reverser*TE(notch,|v|) - sign(v)*R(|v|) - sign(v)*Brake ) / MASS
--   v += a*dt ; clamp |v| <= V_MAX ; distanceMetres += v*dt
-- Diesel-electric => constant-power tractive effort that FALLS with speed
-- (TE = min(adhesion cap, power/v)) => brisk start, tapering accel. Heavy mass +
-- modest brake => long stopping distance. Low Davis rolling resistance => a long,
-- slow coast. See docs/ROADMAP.md Task 1.D for the GP10 targets these numbers hit.
--
-- Units bridge (see docs/ARCHITECTURE.md + this module's C table):
--   * 1 map tile == 1 metre  (METERS_PER_TILE), consistent with the model pipeline.
--   * dt seconds/tick == getGameTime():getMultiplier() / DT_PER_MULT   (adapter side)
--     (getMultiplier ~= 0.8*fps*gameSpeed => /48 ~= real seconds at 1x, and speeds
--      up with the game-speed controls; frame-rate independent).
--***********************************************************************

local Drive = {}

-- Tunables (GP10, locomotive only; cars are deferred -- decision 4). Exposed so
-- unit tests and in-game tuning touch ONE place. Playability first, then realism.
local C = {
    MASS            = 114000,     -- kg  (~114 t, loco only)
    NOTCH_MAX       = 8,          -- throttle Run 1..8 (+ idle 0)
    TE0             = 250000,     -- N   starting tractive effort at notch 8 (adhesion cap)
    P8              = 1.35e6,     -- W   traction power at notch 8 (gross-ish, tunable)
    -- Top speed = the prototype's gear-ratio limit (a hard clamp, not a power
    -- limit): a GP7/GP10 on standard 62:15 freight gearing tops out at 65 mph.
    -- The old 16 m/s (~36 mph) cap was an untested guess inherited from the
    -- handcar prototype, on the theory that PZ couldn't stream chunks fast
    -- enough -- vanilla cars run at this speed, so we hold the prototype figure
    -- and lower it only if streaming is measured to break.
    V_MAX           = 29,         -- m/s hard clamp (~104 km/h, ~65 mph)
    V_POWER_EPS     = 1.0,        -- m/s floor for power/v (keeps TE finite near v=0)

    -- Diesel-electric LOAD LAG: throttle doesn't deliver its notch's power
    -- instantly (generator excitation ramps). We ease an effective notch toward
    -- the lever so slamming Run 8 doesn't yank the loco -- it leans into it.
    NOTCH_RAMP      = 2.0,        -- notches/sec (0->8 in ~4 s)

    -- Davis resistance R(v) = A + B*|v| + C*v^2  (N), one loco.
    RES_A           = 3000,
    RES_B           = 120,
    RES_C           = 5,

    BRAKE_MAX       = 180000,     -- N   full independent (air) brake force
    -- Brake lever ramp (per second) so it feels pneumatic, not instant.
    BRAKE_APPLY_RATE   = 1.2,     -- fraction/sec toward full while applying
    BRAKE_RELEASE_RATE = 1.5,     -- fraction/sec toward 0 while releasing

    METERS_PER_TILE = 1.0,        -- 1 tile == 1 m (matches Blender-metre model scale)
    DT_PER_MULT     = 48.0,       -- dt_seconds = getMultiplier() / DT_PER_MULT

    -- Largest MOTION step we ever integrate in one tick. getMultiplier() carries the
    -- game-speed control (x5/x20/x40) and any frame hitch, so a raw dt can reach ~0.7 s
    -- -- at V_MAX that is a 20 m jump per tick, i.e. the body teleports through zombies
    -- (RR_Crush sweeps the footprint ONCE per tick) and past route corners. Capping the
    -- step at 0.05 s bounds one tick to <= 1.5 m, comfortably under a body length.
    -- Only the physics/pose path is capped -- the engine's fuel/battery/warm-up run on
    -- the raw game-time dt, so a loco idling under fast-forward still burns its diesel.
    DT_MAX          = 0.05,       -- s

    -- Below this the loco counts as standing still (fast-forward interlock).
    V_IDLE          = 0.05,       -- m/s
}
Drive.C = C

local function sgn(x)
    if x > 0 then return 1 elseif x < 0 then return -1 else return 0 end
end

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

--------------------------------------------------------------------------
-- newState: fresh drive state for one locomotive.
--   v          : signed speed along the route, m/s (+ = forward along route)
--   brakeLevel : ramped internal brake fraction 0..1 (NOT the raw key input)
--------------------------------------------------------------------------
function Drive.newState()
    return { v = 0.0, brakeLevel = 0.0, notchEff = 0.0 }
end

--------------------------------------------------------------------------
-- tractiveEffort(notch, v): TE magnitude (N) at throttle `notch` (0..8) and
-- speed magnitude |v|. Diesel-electric: flat adhesion cap at low speed, then
-- constant-power hyperbola P/v that falls as speed rises. Scales ~linearly with
-- notch (real EMD steps are non-linear; linear is fine + tunable for playability).
-- Independent of travel direction (the reverser applies the sign in accel()).
--------------------------------------------------------------------------
function Drive.tractiveEffort(notch, v)
    notch = clamp(notch or 0, 0, C.NOTCH_MAX)
    if notch <= 0 then return 0 end
    local frac = notch / C.NOTCH_MAX
    local cap  = C.TE0 * frac
    local pwr  = (C.P8 * frac) / math.max(math.abs(v or 0), C.V_POWER_EPS)
    return math.min(cap, pwr)
end

--------------------------------------------------------------------------
-- resistance(v): Davis rolling+aero drag, N, always >= 0 (magnitude; opposes
-- motion). Uses |v| so it is symmetric for forward/reverse travel.
--------------------------------------------------------------------------
function Drive.resistance(v)
    local a = math.abs(v or 0)
    return C.RES_A + C.RES_B * a + C.RES_C * a * a
end

--------------------------------------------------------------------------
-- accel(state, controls): instantaneous acceleration (m/s^2) for the CURRENT
-- state.v and state.brakeLevel. Pure (no dt, no mutation) so tests can assert it.
--   controls = { reverser = -1|0|1, throttle = 0..8 }
-- Resistance + brake oppose motion; at v==0 they oppose the impending drive
-- direction but are capped so they can't spontaneously push a parked loco.
--------------------------------------------------------------------------
function Drive.accel(state, controls)
    local v        = state.v or 0
    local reverser = controls.reverser or 0
    local throttle = controls.throttle or 0
    -- Condition traction debuff (Task 1.N step 5): a worn loco makes less tractive effort.
    -- controls.tractionMult (default 1 = healthy) scales the drive force; the same factor
    -- caps V_MAX in step(). Pure input, so the module stays engine-free + unit-tested.
    local tmult    = controls.tractionMult or 1

    local drive  = reverser * Drive.tractiveEffort(throttle, v) * tmult   -- signed, along route
    local resist = Drive.resistance(v) + (state.brakeLevel or 0) * C.BRAKE_MAX  -- magnitude

    local resistForce
    if v > 0 then
        resistForce = -resist
    elseif v < 0 then
        resistForce = resist
    else
        -- Parked: resistance is static -- it opposes the drive force but only up
        -- to its own magnitude (it can't launch the loco backwards).
        resistForce = -sgn(drive) * math.min(resist, math.abs(drive))
    end

    return (drive + resistForce) / C.MASS
end

--------------------------------------------------------------------------
-- step(state, controls, dt): advance one tick. Ramps the brake lever toward the
-- key input, integrates v (frame-rate-independent via dt), clamps to +/-V_MAX,
-- and prevents resistance/brake from rolling the loco backwards through 0.
--   controls = { reverser=-1|0|1, throttle=0..8, brakeInput=0..1 }
--   dt       = seconds elapsed this tick
-- Mutates state.v and state.brakeLevel; RETURNS distance travelled this tick in
-- TILES (signed; caller does route.distance += result).
--------------------------------------------------------------------------
function Drive.step(state, controls, dt)
    dt = dt or 0
    if dt <= 0 then return 0 end

    -- Ramp the pneumatic brake lever toward the requested input.
    local target = clamp(controls.brakeInput or 0, 0, 1)
    local bl = state.brakeLevel or 0
    if target > bl then
        bl = math.min(target, bl + C.BRAKE_APPLY_RATE * dt)
    elseif target < bl then
        bl = math.max(target, bl - C.BRAKE_RELEASE_RATE * dt)
    end
    state.brakeLevel = bl

    -- Ramp the effective throttle notch toward the lever (diesel-electric load lag).
    local wantNotch = clamp(controls.throttle or 0, 0, C.NOTCH_MAX)
    local ne = state.notchEff or 0
    if wantNotch > ne then
        ne = math.min(wantNotch, ne + C.NOTCH_RAMP * dt)
    elseif wantNotch < ne then
        ne = math.max(wantNotch, ne - C.NOTCH_RAMP * dt)
    end
    state.notchEff = ne

    -- Physics uses the RAMPED notch (accel() stays pure; we feed it the eff notch).
    local eff = { reverser = controls.reverser, throttle = ne, tractionMult = controls.tractionMult }
    local v0 = state.v or 0
    local a  = Drive.accel(state, eff)
    local v1 = v0 + a * dt

    -- Zero-cross guard: resistance/brake must not reverse travel direction. If v
    -- flipped sign and there is no tractive force actively driving into the new
    -- direction, the loco has simply stopped -> clamp to 0. (Reverser changes are
    -- gated to |v|~=0 in the control layer, so a genuine powered reversal only
    -- starts from rest and is unaffected by this guard.)
    if v0 ~= 0 and sgn(v1) ~= 0 and sgn(v1) ~= sgn(v0) then
        local drive = (eff.reverser or 0) * Drive.tractiveEffort(eff.throttle, v0)
        if sgn(drive) ~= sgn(v1) then
            v1 = 0
        end
    end

    -- Cap top speed by the condition traction multiplier too (spec: vmax * tractionMult) --
    -- cheap and immediately felt (a dying loco can't reach line speed). Healthy => full V_MAX.
    local vmax = C.V_MAX * clamp(controls.tractionMult or 1, 0, 1)
    v1 = clamp(v1, -vmax, vmax)
    state.v = v1

    -- distance this tick, in tiles
    return (v1 * dt) / C.METERS_PER_TILE
end

--------------------------------------------------------------------------
-- TIME STEP. Two dts come out of the one engine multiplier:
--
--   dtGame(mult) -- seconds of GAME time this tick. Scales with the game-speed
--                   controls, so processes that should follow the clock (fuel burn,
--                   battery, warm-up) advance 40x under x40 fast-forward.
--   dtSim(mult)  -- the same thing capped at C.DT_MAX, for MOTION (physics, pose,
--                   collider, crush). A fast-forwarded or hitching frame must not
--                   integrate a 20 m step: the crush/collider sweep is per-tick, so a
--                   long jump tunnels straight through zombies and route corners.
--
-- The cap is a backstop, not the mechanism: needsRealtime() below drops the game back
-- to 1x whenever the loco is actually being driven, exactly as vanilla does for cars.
--------------------------------------------------------------------------
function Drive.dtGame(mult)
    local dt = (mult or 0.8) / C.DT_PER_MULT
    if dt < 0 or dt ~= dt then return 0 end     -- guard NaN / a negative multiplier
    return dt
end

function Drive.dtSim(mult)
    local dt = Drive.dtGame(mult)
    if dt > C.DT_MAX then return C.DT_MAX end
    return dt
end

--------------------------------------------------------------------------
-- needsRealtime(state, controls): is the cab being WORKED right now? True when the
-- loco is rolling, or the driver has a hand on the throttle / brake / starter.
--
-- Vanilla parity: PZ does not disable the fast-forward buttons in a car -- it snaps
-- the speed back to 1 from the vehicle controller the moment the driver applies gas,
-- reverse or brake (CarController.java:258 -> SpeedControls.SetCurrentGameSpeed(1)).
-- The control layer (RR_Ride) calls this and does the same. Parked with your hands
-- off, fast-forward in the cab stays legal -- waiting out the night in the shed is a
-- fair use, and a stopped loco integrates nothing.
--------------------------------------------------------------------------
function Drive.needsRealtime(state, controls)
    controls = controls or {}
    if math.abs((state and state.v) or 0) > C.V_IDLE then return true end
    if (controls.throttle   or 0) ~= 0 then return true end
    if (controls.brakeInput or 0) ~= 0 then return true end
    if controls.cranking then return true end
    return false
end

--------------------------------------------------------------------------
-- Small helpers for the HUD / control layer (pure, so also testable).
--------------------------------------------------------------------------
-- mps -> mph and km/h
function Drive.mph(v)  return (v or 0) * 2.2369363 end
function Drive.kmh(v)  return (v or 0) * 3.6 end

--------------------------------------------------------------------------
-- nextReverser(r): where the R key puts the handle next -- N -> F -> R -> N.
--
-- Deliberately NOT the lever's own sweep (F -> N -> R). The diesel can only be
-- started with the reverser CENTRED, so N is where every driver stands the first
-- time they reach for this key, and the sweep order sent that first press to
-- REVERSE -- with the control stand printing "PRESS R" at exactly that moment.
--
-- A real lever cannot jump R -> F without passing N, so the sweep was only half a
-- lever anyway (it wrapped). With one key and three positions the property worth
-- having is that the FIRST press does the common thing.
--------------------------------------------------------------------------
function Drive.nextReverser(r)
    r = r or 0
    if r == 0 then return 1 elseif r > 0 then return -1 else return 0 end
end

-- Reverser label from the signed value.
function Drive.reverserLabel(r)
    if (r or 0) > 0 then return "F" elseif (r or 0) < 0 then return "R" else return "N" end
end

--------------------------------------------------------------------------
-- faceSign(reverser, prev): which way along the rails the DRIVER looks, as a sign
-- in +distance space (the loco's pose is always the +distance tangent -- it has no
-- wrong way round -- so the direction of travel is a property of the handle, exactly
-- like RR_LightsRender.leadSign).
--
-- The handle, not the velocity: an engineer turns round when he SELECTS reverse, not
-- when the wheels finally start turning, and reading velocity would spin the body
-- back and forth around a standstill.
--
-- NEUTRAL keeps `prev`. N is not a third direction to face -- it is where the handle
-- rests to start or shut down the diesel, and snapping the driver round every time
-- he centres it would be motion sickness for no information. Defaults to FORWARD,
-- which is where a driver who has never touched the handle is looking.
--------------------------------------------------------------------------
function Drive.faceSign(r, prev)
    r = r or 0
    if r > 0 then return 1 end
    if r < 0 then return -1 end
    return (prev == -1) and -1 or 1
end

RR = RR or {}
RR.Drive = Drive

return Drive
