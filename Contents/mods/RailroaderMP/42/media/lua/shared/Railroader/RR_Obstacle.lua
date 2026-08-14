--***********************************************************************
-- Railroader / RR_Obstacle  -- obstacles on the rails: pure policy (Task 1.N)
--
-- Engine-free classification + speed policy + condition-damage for a loco that
-- drives into a world obstacle. The counterpart to RR_Body/RR_Crush: this module
-- decides WHAT an obstacle is and WHAT a strike does; the engine sweep
-- (client/RR_ObstacleSweep) reads the real IsoObject/IsoGridSquare/BaseVehicle,
-- fills a plain-data descriptor, calls these, then applies the outcome (destroy /
-- shove / wreck the obstacle + feed Delta-v back into RR_Drive + debit condition).
-- No engine calls here -> Kahlua-safe, unit-tested (tests/run_tests.lua).
--
-- Five classes (owner-finalised taxonomy -- see docs/OBSTACLE_DESIGN.md):
--   NEGLIGIBLE : characters/animals (RR_Crush handles those), low clutter -> no effect.
--   SMASHABLE  : light breakable -- map fence (fencing_*), HitByCar prop (cone/sign),
--                player-built IsoThumpable/IsoWindow/IsoDoor, and a TREE (IsoTree: a 112 t
--                loco fells it, it does not stop it). Destroyed at ANY speed (even a
--                crawl), no condition damage, no speed loss; loco keeps rolling.
--   CONCRETE   : destructible concrete (cube / road barrier / slab, StopCar flag). STOPS only
--                at a creep (< BARRIER.V_STOP); above it is destroyed with NO speed loss and a
--                SMALL condition hit (1-5%). (Class tag CLASS.BARRIER.)
--   VEHICLE    : a BaseVehicle overlaps -- shoved off the rails (low) or wrecked (high),
--                loco keeps rolling. (Step 4.)
--   HARD       : ONLY a comparable-mass body -- a vanilla railcar / another loco -- blocks with
--                NO destroy path. The loco HARD-STOPS at contact; at speed -> derail. (There is
--                no buffer stop / immovable anchored concrete on the map: those don't exist.)
--
-- INVERTED FALLBACK (owner 2026-07-29): the default for an UNRECOGNISED solid is now
-- SMASHABLE, not HARD -- see Obstacle.SOLID_IS_HARD below. The world holds far too many
-- one-off props to enumerate, and the old `solid => HARD` default meant every un-enumerated
-- one of them STOPPED a 112 t locomotive dead (owner in-game: an ordinary BARREL parked the
-- loco). Rolling stock is the ONLY thing that stops us, so it is now the only thing named.
--
-- DERAILMENT is condition-INDEPENDENT and DETERMINISTIC (owner decision A, 2026-07-24 --
-- supersedes the old condition-driven model; see docs/OBSTACLE_DESIGN.md "Derailment").
-- It is the TERMINAL off-rails state, triggered by two immediate, condition-free events:
--   1. running off an authored BROKEN (open) rail end while moving (shouldDerailEnd), and
--   2. a very strong HARD impact at/above V_DERAIL_IMPACT (shouldDerailImpact).
-- `impactDamage` feeds ONLY `condition` (Step 5 immobilization), NEVER a derail. The
-- probabilistic per-class `derailChance` lattice below is NOT consumed for execution -- it
-- is kept for a FUTURE plan (owner B: derail as a managed risk on VEHICLE/CONCRETE too,
-- once a re-railing recovery mechanic lands).
--***********************************************************************

RR = RR or {}

local Obstacle = {}

-- Class tags (strings: easy to test/print/switch on).
Obstacle.CLASS = {
    NEGLIGIBLE = "negligible",
    SMASHABLE  = "smashable",
    VEHICLE    = "vehicle",
    BARRIER    = "barrier",     -- concrete road block (StopCar/Stone): punched THROUGH at
                                -- speed with real condition damage, but STOPS a creep
    HARD       = "hard",
}

-- Speed thresholds (m/s, |v|). V_MIN mirrors Body.CRUSH.V_MIN: below it the loco is
-- parked/creeping and any contact is just a hard stop (nothing destroyed) -- the same
-- "a standstill must not be destructive" rule the crush sweep uses. V_WRECK is the
-- VEHICLE cutover: below it a car is shoved off the rails, at/above it the car is
-- wrecked (setSmashed). Kept here so the whole policy tunes in one place.
Obstacle.THRESH = {
    V_MIN   = 1.0,
    V_WRECK = 4.0,
    -- DERAIL triggers (Task 1.N step 6, owner decision A 2026-07-24). Derailment is the
    -- TERMINAL off-rails state and is DETERMINISTIC + condition-independent:
    --   * a very strong HARD impact at/above V_DERAIL_IMPACT (high -- ~the crush V_GORE 8 m/s
    --     tier; you must deliberately run a railcar down at speed to reach it), and
    --   * running off an authored BROKEN (open) rail end while moving faster than V_DERAIL_ENDMIN.
    -- The probabilistic per-class lattice (derailChance below) is NOT consumed for execution --
    -- it is kept for a FUTURE plan (owner B: derail as a managed risk on all hard classes, once a
    -- re-railing recovery mechanic exists). See docs/OBSTACLE_DESIGN.md "Derailment".
    V_DERAIL_IMPACT = 8.0,   -- m/s (28.8 km/h) -- HARD-only; ~Body.CRUSH.V_GORE
    V_DERAIL_ENDMIN = 0.5,   -- m/s -- above this, reaching a broken open end derails (below = clamp-stop)
}

-- Fraction of the loco's speed bled by a NON-stopping strike (momentum transfer, not
-- energy: Delta-v ~ m_obstacle/m_loco * e -- a 112 t loco barely notices a 1.5 t car, so
-- these are deliberately tiny). A HARD/creep strike is a full stop (dvFrac = 1.0),
-- handled in effect() not here.
Obstacle.DV = {
    SMASH = 0.02,   -- fence/window/door shattered
    SHOVE = 0.05,   -- car knocked off the rails
    WRECK = 0.08,   -- car crushed and thrown
    BARRIER = 0.0,  -- concrete block: NO speed loss (owner spec) -- a 112 t loco is unfazed
}

-- BARRIER = destructible CONCRETE (cube / road barrier / slab). Owner-finalised 2026-07-23:
-- the loco STOPS only below V_STOP; above it the block is destroyed with NO speed loss
-- (DV.BARRIER = 0). Two curves make the choice interesting:
--   * CONDITION damage MONOTONIC (impact energy grows with speed): 1% @10 -> 5% @80+ km/h.
--   * DERAIL chance a HUMP (peak at MID speed): ~5% low -> ~13% mid (peak) -> ~5% high ->
--     ~2-3% max. So: creep = stop, MID = max derail risk, FULL speed = costs more condition
--     but SAFEST (lowest derail). DERAIL_BANDS = {speed_m_s, probability}.
Obstacle.BARRIER = {
    V_STOP   = 10 / 3.6,   -- 10 km/h: below = stop, block SURVIVES, no damage/derail
    V_MAXDMG = 80 / 3.6,   -- 80 km/h: condition damage caps at DMG_MAX at/above here
    DMG_MIN  = 0.01,       -- 1% at V_STOP
    DMG_MAX  = 0.05,       -- 5% at/above V_MAXDMG
    DERAIL_BANDS = {
        { 10 / 3.6,  0.03 },   -- 10 km/h
        { 17 / 3.6,  0.05 },   -- ~low band (5%)
        { 37 / 3.6,  0.13 },   -- ~mid band PEAK (13%)
        { 50 / 3.6,  0.07 },
        { 65 / 3.6,  0.05 },   -- ~high band (5%)
        { 80 / 3.6,  0.035 },
        { 130 / 3.6, 0.02 },   -- ~max band (2-3%)
    },
}

-- HARD = the hardest hit in the game (comparable-mass body: railcar / another loco). The loco
-- ALWAYS hard-stops; the strike also does big CONDITION damage (cab/nose) AND rolls a DERAIL
-- (derailChance). Owner spec: creep 0, low ~2-5%, med ~15-25%, high/max 30%+. Piecewise-linear.
Obstacle.HARD = {
    BANDS = {
        { 10 / 3.6,  0.02 },   -- 10 km/h: 2%
        { 25 / 3.6,  0.05 },   -- 25:  5% (low band top)
        { 37 / 3.6,  0.15 },   -- 37:  15%
        { 50 / 3.6,  0.25 },   -- 50:  25% (mid band top)
        { 65 / 3.6,  0.32 },   -- 65:  32%
        { 80 / 3.6,  0.40 },   -- 80:  40% (high)
        { 120 / 3.6, 0.50 },   -- 120: 50% (max)
    },
}

-- Small condition damage a VEHICLE (car) does the loco -- "few %", ramped a little by speed.
Obstacle.VEHICLE_DMG = { V_MIN = 10 / 3.6, V_MAX = 80 / 3.6, DMG_MIN = 0.01, DMG_MAX = 0.03 }

-- DERAIL ROLL (probability 0..1) -- the SECOND cell parameter of the ORIGINAL probabilistic
-- taxonomy. **DEFERRED (owner A, 2026-07-24):** Step 6 does NOT consume this -- derailment is a
-- DETERMINISTIC threshold (shouldDerailImpact / shouldDerailEnd + THRESH.V_DERAIL_*). This table
-- and derailChance() are retained, still unit-tested, for a FUTURE plan (owner B: bring the
-- probabilistic risk back on VEHICLE/CONCRETE once a re-railing recovery mechanic exists). Until
-- then nothing rolls it. HARD ramps 0 -> 1.0; VEHICLE small; everything else 0.
Obstacle.DERAIL = {
    -- HARD: 0 below 50 km/h (creep/low/med never derail) -> ~50% at 65 (high band) -> 100%
    -- at/above 80 (max). So high = a real ~50% roll, max = certain.
    HARD    = { V0 = 50 / 3.6, V1 = 80 / 3.6, P1 = 1.0 },
    VEHICLE = { V0 = 50 / 3.6, P = 0.05 },                 -- ~5% flat above 50 km/h
}

Obstacle.WRECK_AT = 0.0   -- condition <= this => out of order (engine dead) -- see Derailment

-- What an UNRECOGNISED solid square means (owner decision, 2026-07-29). Historically
-- `solid` with no destroy path fell through to HARD -- "if we don't know it, it stops us".
-- That inverted the truth of the object: the map is full of small props (a barrel, a crate,
-- a bin, a lamp post) that carry a solidity flag and nothing else, and each one of them
-- brought a locomotive to a stand. The owner's rule is the opposite one and it is a much
-- shorter list: **the loco flattens everything except rolling stock**. So HARD is now
-- reserved for an EXPLICIT `railcar` hint (the sweep names it by sprite) and every other
-- solid is SMASHABLE. Set true to restore the pre-2026-07-29 behaviour.
Obstacle.SOLID_IS_HARD = false

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

--------------------------------------------------------------------------
-- classify(info) -> a CLASS. `info` is a plain-data descriptor the engine sweep fills
-- from the real object/square (NO engine handles here). Recognised fields (all optional
-- booleans, default false):
--   vehicle   : a BaseVehicle overlaps the square (sq:getVehicleContainer() ~= nil)
--   thumpable : IsoThumpable or IsoDoor (has IHasHealth -> a Damage/destroy path)
--   window    : IsoWindow (smashWindow path)
--   hitByCar  : plain IsoObject carrying the HitByCar sprite flag (vanilla car-breakable)
--   tree      : an IsoTree (map vegetation) -- felled by the loco, never a stop. Trees are
--               `solid`, so WITHOUT this flag the fallback rule below read them as HARD:
--               the габарит clipping one roadside holly on the inside of a 45deg corner
--               DERAILED the loco at 74 km/h (owner in-game 2026-07-29, e_americanholly_1_3
--               at 6526,14620). A car cannot fell a tree (IsoTree.HitByVehicle barely
--               scratches it) -- a locomotive can, so this is ours, not vanilla's, policy.
--   barrier   : a concrete road block (StopCar sprite flag, Material Stone) -- punched
--               through at speed with real condition damage, but stops a creep
--   solid     : the square/object blocks (isSolid / collideN|collideW) and is NOT breakable
--   railcar   : a vanilla parked-railcar / another loco (the ONLY HARD hint -- the sweep
--               names it by sprite, since nothing else on the map has comparable mass)
-- Precedence encodes the engine reality: a DESTROYABLE thing (has a Lua break path) is
-- SMASHABLE even if it is also solid (a brick wall we can Damage); a BARRIER is a solid
-- concrete block we still punch through at speed; HARD is reserved for ROLLING STOCK.
-- `railcar` is tested FIRST: on a railcar square the sweep suppresses the generic
-- flatten target, but a genuinely-typed smashable there (a shed door on the rails) must
-- still not read as a railcar, so it keeps its own earlier branch.
-- Everything else that merely reads `solid` is SMASHABLE (Obstacle.SOLID_IS_HARD).
--------------------------------------------------------------------------
function Obstacle.classify(info)
    info = info or {}
    if info.vehicle then return Obstacle.CLASS.VEHICLE end
    if info.thumpable or info.window or info.hitByCar or info.tree then
        return Obstacle.CLASS.SMASHABLE
    end
    if info.barrier then return Obstacle.CLASS.BARRIER end
    if info.railcar then return Obstacle.CLASS.HARD end
    if info.solid then
        if Obstacle.SOLID_IS_HARD then return Obstacle.CLASS.HARD end
        return Obstacle.CLASS.SMASHABLE          -- unrecognised prop: the loco flattens it
    end
    return Obstacle.CLASS.NEGLIGIBLE
end

--------------------------------------------------------------------------
-- effect(class, absSpeed) -> { action, dvFrac, destroy, stop }
--   action : "none" | "stop" | "smash" | "shove" | "wreck"
--   dvFrac : fraction of |speed| the loco loses this strike (1.0 = full stop)
--   destroy: the obstacle should be destroyed/smashed/wrecked
--   stop   : hard stop at contact (clamp distance, zero velocity) -- never tunnel past
-- Motion/destruction ONLY. Condition damage is impactDamage(); derailment is decided by
-- the sweep when condition hits WRECK_AT, not here.
--------------------------------------------------------------------------
function Obstacle.effect(class, absSpeed)
    local av = absSpeed or 0
    local T  = Obstacle.THRESH
    local DV = Obstacle.DV
    local C  = Obstacle.CLASS

    if class == C.NEGLIGIBLE then
        return { action = "none", dvFrac = 0.0, destroy = false, stop = false }
    end

    -- SMASHABLE (fence/cone/sign): smashed at ANY speed -- even a crawling loco flattens a
    -- fence (owner spec 2026-07-23). No creep-stop, so this is BEFORE the V_MIN rule below.
    if class == C.SMASHABLE then
        return { action = "smash", dvFrac = DV.SMASH, destroy = true, stop = false }
    end

    -- VEHICLE (car on the rails): crumple + throw at ANY speed of contact (owner 2026-07:
    -- "мнём машину при касании на любой скорости"). Like SMASHABLE, handled BEFORE the V_MIN
    -- stop -- even a creep touch wrecks the car and the loco clears it and rolls on, rather than
    -- stopping. Always a wreck; the throw magnitude + the impact sound scale with speed in the
    -- engine (the throw is floored so a slow touch still clears the car off the rails).
    if class == C.VEHICLE then
        return { action = "wreck", dvFrac = DV.WRECK, destroy = true, stop = false }
    end

    -- Parked/creeping into anything HEAVIER (concrete/railcar) is just a hard stop; nothing
    -- heavy is destroyed at a standstill (the crush "a wall, not a weapon" rule). (VEHICLE is
    -- handled above -- it wrecks even at a creep.)
    if av < T.V_MIN then
        return { action = "stop", dvFrac = 1.0, destroy = false, stop = true }
    end

    if class == C.HARD then
        -- Immovable, no destroy path: always a hard stop. Condition damage (impactDamage)
        -- is what escalates a fast HARD strike to the terminal wreck.
        return { action = "stop", dvFrac = 1.0, destroy = false, stop = true }
    end

    if class == C.BARRIER then
        -- Concrete road block: STOPS a creep (below V_STOP, higher than V_MIN -- a low-speed
        -- loco just upирается and the block survives), PUNCHES THROUGH above it (destroyed,
        -- big speed bleed, real condition damage via impactDamage).
        if av < Obstacle.BARRIER.V_STOP then
            return { action = "stop", dvFrac = 1.0, destroy = false, stop = true }
        end
        return { action = "smash", dvFrac = DV.BARRIER, destroy = true, stop = false }
    end

    -- (VEHICLE is handled at the top now -- always a wreck, at any speed.)

    -- Unknown class: safe default -- treat as a hard stop, destroy nothing.
    return { action = "stop", dvFrac = 1.0, destroy = false, stop = true }
end

-- Piecewise-linear interpolation over a sorted {x, y} band table, clamped at both ends.
local function bandLerp(bands, x)
    if x <= bands[1][1] then return bands[1][2] end
    local n = #bands
    if x >= bands[n][1] then return bands[n][2] end
    for i = 1, n - 1 do
        local x0, y0 = bands[i][1], bands[i][2]
        local x1, y1 = bands[i + 1][1], bands[i + 1][2]
        if x >= x0 and x < x1 then
            if x1 <= x0 then return y1 end
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
        end
    end
    return bands[n][2]
end

--------------------------------------------------------------------------
-- impactDamage(class, absSpeed) -> Delta-condition (0..1), the amount to SUBTRACT from the
-- loco's `condition` for this strike. Owner-finalised curves (see the class config above):
--   SMASHABLE  : 0        (light -- no condition cost)
--   CONCRETE   : a HUMP   (0 at creep, peaks ~13% in the mid band, ~2-3% at max)
--   VEHICLE    : few %    (small ramp)
--   HARD       : big      (0 creep -> ~50% at max; the hardest hit)
--------------------------------------------------------------------------
function Obstacle.impactDamage(class, absSpeed)
    local av = absSpeed or 0
    local C  = Obstacle.CLASS

    if class == C.BARRIER then
        local B = Obstacle.BARRIER
        if av < B.V_STOP then return 0.0 end                    -- creep: stops, no damage
        local span = B.V_MAXDMG - B.V_STOP                      -- MONOTONIC 1% -> 5% (energy)
        local t = (span > 0) and clamp((av - B.V_STOP) / span, 0, 1) or 1.0
        return B.DMG_MIN + (B.DMG_MAX - B.DMG_MIN) * t
    end
    if class == C.HARD then
        if av < Obstacle.THRESH.V_MIN then return 0.0 end       -- parked bump: ~0
        return bandLerp(Obstacle.HARD.BANDS, av)
    end
    if class == C.VEHICLE then
        local V = Obstacle.VEHICLE_DMG
        if av < V.V_MIN then return 0.0 end
        local span = V.V_MAX - V.V_MIN
        local t = (span > 0) and clamp((av - V.V_MIN) / span, 0, 1) or 1.0
        return V.DMG_MIN + (V.DMG_MAX - V.DMG_MIN) * t
    end
    return 0.0   -- NEGLIGIBLE, SMASHABLE
end

--------------------------------------------------------------------------
-- derailChance(class, absSpeed) -> probability [0..1] that this strike DERAILS the loco (the
-- second cell parameter -- the "risk"). HARD ramps 0 -> 1.0 across high speed; VEHICLE has a
-- small flat chance a car jams under a truck; everything else is 0. The sweep rolls this;
-- the terminal wreck state itself is Step 6.
--------------------------------------------------------------------------
function Obstacle.derailChance(class, absSpeed)
    local av = absSpeed or 0
    local C  = Obstacle.CLASS
    local D  = Obstacle.DERAIL
    if class == C.BARRIER then
        -- Concrete: a HUMP peaking at mid speed (max risk in the middle). 0 below V_STOP.
        if av < Obstacle.BARRIER.V_STOP then return 0.0 end
        return bandLerp(Obstacle.BARRIER.DERAIL_BANDS, av)
    end
    if class == C.HARD then
        local h = D.HARD
        if av <= h.V0 then return 0.0 end
        if av >= h.V1 then return h.P1 end
        return h.P1 * (av - h.V0) / (h.V1 - h.V0)
    end
    if class == C.VEHICLE then
        return (av >= D.VEHICLE.V0) and D.VEHICLE.P or 0.0
    end
    return 0.0
end

--------------------------------------------------------------------------
-- shouldDerailImpact(class, absSpeed) -> bool: does THIS collision derail the loco? The
-- DETERMINISTIC impact trigger (Task 1.N step 6, owner A): only a HARD strike (railcar /
-- another loco), only at/above V_DERAIL_IMPACT. VEHICLE / BARRIER / SMASHABLE never derail
-- under this model (the probabilistic derailChance lattice is deferred -- see THRESH). Pure,
-- so the execution layer (RR_TrainEntity) just asks and acts.
--------------------------------------------------------------------------
function Obstacle.shouldDerailImpact(class, absSpeed)
    return class == Obstacle.CLASS.HARD and (absSpeed or 0) >= Obstacle.THRESH.V_DERAIL_IMPACT
end

--------------------------------------------------------------------------
-- shouldDerailEnd(absSpeed) -> bool: reaching a BROKEN (open) rail end at this speed derails.
-- The caller decides the reached end is `open` (authored, matched by coordinate); this is only
-- the SPEED gate -- a buffered end always clamp-stops, and even an open end below V_DERAIL_ENDMIN
-- just clamp-stops (you rolled to the very end at a crawl). Pure.
--------------------------------------------------------------------------
function Obstacle.shouldDerailEnd(absSpeed)
    return (absSpeed or 0) >= Obstacle.THRESH.V_DERAIL_ENDMIN
end

--------------------------------------------------------------------------
-- wrecks(condition) -> true when the loco is OUT OF ORDER (engine dead) at this condition.
-- NOTE: since the revised design a DERAIL is a DETERMINISTIC trigger (shouldDerailImpact /
-- shouldDerailEnd), NOT condition-driven; this predicate only marks the "condition hit 0 ->
-- won't run" soft-immobilize state (Step 5), which is on-rails + recoverable, not a derail.
--------------------------------------------------------------------------
function Obstacle.wrecks(condition)
    return (condition or 1.0) <= Obstacle.WRECK_AT
end

RR.Obstacle = Obstacle
return Obstacle
