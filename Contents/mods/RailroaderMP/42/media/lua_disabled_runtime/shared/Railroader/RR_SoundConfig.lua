--***********************************************************************
-- Railroader / RR_SoundConfig  -- PURE data + mixing math for the sound layer
-- (Task 1.E). NO ENGINE DEPENDENCIES, so it unit-tests in a bare interpreter
-- (tests/run_tests.lua). The client adapter RR_Sound.lua owns the emitter and
-- calls these to decide per-tick volumes/pitches from the drive state.
--
-- Engine model (diesel-electric): the prime mover RPM is set by the THROTTLE
-- NOTCH, not speed. We keep idle + run1..4 loops all playing and crossfade their
-- VOLUMES by notchEff (0..8) with a triangular window -- so only the 1-2 loops
-- nearest the current notch are audible, gliding smoothly as you notch up. The
-- loops' own recorded loudness (idle quiet -> run4 loud) carries the dynamics.
--***********************************************************************

local Cfg = {}

-- Sound-script names (declared in media/scripts/railroader_sounds.txt).
Cfg.names = {
    engineStart = "RR_EngineStart",   -- catch one-shot (crank -> fires)
    engineStop  = "RR_EngineStop",    -- shutdown / stall spin-down
    enginePrime = "RR_EnginePrime",   -- electric FUEL PRIME pump hum, loops before the starter turns
    engineCrank = "RR_EngineCrank",   -- starter motor loop while cranking (engine-start mechanic)
    startFail   = "RR_StartFail",     -- failed catch / dead-battery click
    engineIdle  = "RR_EngineIdle",
    engineRun   = { "RR_EngineRun1", "RR_EngineRun2", "RR_EngineRun3", "RR_EngineRun4" },
    wheelRoll   = "RR_WheelRoll",
    clacks      = { "RR_Clack1", "RR_Clack2", "RR_Clack3", "RR_Clack4" },
    hornStart   = "RR_HornStart",   -- attack (one-shot on press)
    hornLoop    = "RR_HornLoop",    -- sustained loop while held
    hornStop    = "RR_HornStop",    -- release tail (one-shot on release)
    bell        = "RR_Bell",
    brakeApply  = "RR_BrakeApply",
    brakeSqueal = "RR_BrakeSqueal",
    brakeRelease= "RR_BrakeRelease",
    compressor  = "RR_Compressor",
    crushHit    = "VehicleHitCharacter",   -- vanilla one-shot: loco runs a zombie over (Task 1.H)
    -- HARD collision (Task 1.N): loco strikes a railcar / another loco. Tiered by the
    -- speed at contact, from the vanilla vehicle-crash foley (light/medium/heavy car
    -- crash) PLUS a dull heavy metal THUD (gives it the "hit a solid steel obstacle"
    -- character the plain car-crush lacks) and, only on an actual derail, a deep wreck
    -- boom. All are vanilla registered GameSounds, so they play by name on the animal
    -- emitter (same proven path as the VEHICLE crash + engine one-shots).
    -- (owner 2026-07-24: the old `MetalGateBreak` clang read as hitting a CHAIN-LINK FENCE,
    --  wrong for a railcar -- swapped to `ZombieThumpMetal`, a blunt steel-on-steel thud.)
    hardCrashLight  = "VehicleCrash1",        -- Vehicle/Crash/Light
    hardCrashMedium = "VehicleCrash2",        -- Vehicle/Crash/Medium
    hardCrashHeavy  = "VehicleCrash",         -- Vehicle/Crash/Heavy
    hardThud        = "ZombieThumpMetal",     -- Zombie/Thump/Metal -- dull heavy hit on solid steel
    hardWreckBoom   = "BurnedObjectExploded", -- Object/Burned/Explode (dmax 1000) -- deep explosive boom
    hardWreckBlast  = "PipeBombExplode",      -- Weapon/Throwable/PipeBomb/Explode (dmax 1000) -- sharp blast
    hardWreckDebris = "ZombieThumpMetalPoleFenceDamageCollapse", -- metal debris collapse (derail)
}

-- HARD collision tiers (Task 1.N): a loco driving into a railcar / another loco. The
-- impact SOUND escalates with the speed at contact, mirroring the HARD condition-damage
-- and derail bands in RR_Obstacle: a light metallic bump at a crawl, a heavy crunch at
-- speed, and -- only when the strike actually DERAILS the loco -- a catastrophic wreck
-- boom layered on top. Thresholds in m/s (|v|); V_HEAVY == the HARD derail-risk band
-- start (RR_Obstacle.DERAIL.HARD.V0 = 50 km/h), so the loudest crash and the derail line up.
Cfg.HARD_IMPACT = {
    V_MED   = 25 / 3.6,   -- >= 25 km/h: strong impact (medium crunch + more metal)
    V_HEAVY = 50 / 3.6,   -- >= 50 km/h: crash (heavy) -- also where derail becomes possible
    MASTER  = 1.0,
    THUD_LIGHT   = 0.6,   -- metal-thud volume (fraction of MASTER) per tier
    THUD_MEDIUM  = 0.8,
    THUD_HEAVY   = 1.0,
}

-- IMPACT world noise (zombie attraction on a COLLISION). The crash foley above is FMOD
-- playback, which the AI cannot hear -- without a WorldSoundManager event zombies stand
-- around while a 112 t loco demolishes a car next to them. These are ONE-SHOT radii (in
-- tiles, same scale as NOISE_* above), fired once per contact from RR_ObstacleSweep and
-- Sound.hardImpact. Being one-shots they can sit higher than the sustained engine floor:
-- a crash is a single bang, not a wake of aggro dragged across the map.
-- Tiers mirror the ones the foley already uses, so the sound you hear and the noise the
-- zombies hear escalate together.
Cfg.IMPACT_NOISE = {
    MIN_INTERVAL = 0.15,  -- s between impact events (a fence line is one bang, not five)
    SMASHABLE = 40,       -- fence / cone / window / door goes under -- a crunch, quieter than idle+
    BARRIER   = 80,       -- concrete block punched through by 112 t
    VEHICLE   = { 60, 110, 170 },   -- touch / shove / wreck (a launched car ~ a rifle shot)
    HARD      = { 90, 160, 230 },   -- light / medium / heavy, by HARD_IMPACT.V_MED / V_HEAVY
    -- DERAIL is NOT one loud thing (owner 2026-07-27). Leaving the rails is only as loud as
    -- what put you there:
    DERAIL_ALONE  = 60,   -- ran off a broken OPEN rail end: the wheels drop off the railhead
                          -- into the ballast and it ploughs to a stop. A grind and a lurch,
                          -- not a bang -- quieter than the engine that was pulling it.
    DERAIL_IMPACT = 250,  -- a COLLISION heavy enough to put 112 t on the ground: on a par with
                          -- the horn, the loudest thing the loco can do on purpose.
    -- Speed tiers for VEHICLE. Mirrors RR_Obstacle.THRESH.V_MIN / V_WRECK -- duplicated as
    -- plain numbers so this module stays dependency-free (the sweep passes |v| in m/s).
    V_SHOVE = 1.0,
    V_WRECK = 4.0,
}

---------------------------------------------------------------------------
-- impactNoiseRadius(kind, absSpeed, derailed) -> radius in TILES for the one-shot
-- WorldSoundManager event fired on a collision. `kind` is one of "smashable" / "barrier" /
-- "vehicle" / "hard" -- the RR_Obstacle classes that actually make CONTACT. Anything else
-- (nil included) means "no contact"; with derailed=false that is silence.
--
-- The derail is scaled by what caused it, not by the derail itself:
--   contact + derailed : DERAIL_IMPACT -- the strike put it on the ground (~ the horn)
--   no contact, derailed: DERAIL_ALONE -- it simply ran off a broken open end into the
--                         ballast, which is a grind, not an explosion
-- (Callers: RR_ObstacleSweep passes the class it struck; TrainEntity.derail passes "hard"
-- for the impact trigger and nil for the broken-end trigger, which is where it knows the
-- cause. Sound.hardImpact only emits for the non-derail case, so a derail is never double-
-- counted.)
---------------------------------------------------------------------------
function Cfg.impactNoiseRadius(kind, absSpeed, derailed)
    local N = Cfg.IMPACT_NOISE
    local v = math.abs(absSpeed or 0)
    local r, contact = 0, true
    if kind == "smashable" then
        r = N.SMASHABLE
    elseif kind == "barrier" then
        r = N.BARRIER
    elseif kind == "vehicle" then
        if     v >= N.V_WRECK then r = N.VEHICLE[3]
        elseif v >= N.V_SHOVE then r = N.VEHICLE[2]
        else                       r = N.VEHICLE[1] end
    elseif kind == "hard" then
        local H = Cfg.HARD_IMPACT
        if     v >= H.V_HEAVY then r = N.HARD[3]
        elseif v >= H.V_MED   then r = N.HARD[2]
        else                       r = N.HARD[1] end
    else
        contact = false                           -- unknown / no class
    end
    if derailed then
        r = math.max(r, contact and N.DERAIL_IMPACT or N.DERAIL_ALONE)
    elseif not contact then
        return 0                                  -- nothing struck, nothing to hear
    end
    return math.floor(r + 0.5)
end

-- Crush impact (Task 1.H): one-shot when the loco kills a zombie. Throttled so a
-- whole crowd going under in one tick is a single thud, not a wall of overlaps.
Cfg.CRUSH_MASTER       = 1.0
Cfg.CRUSH_MIN_INTERVAL = 0.12   -- seconds between impact one-shots

-- Engine crossfade anchors on the notchEff axis [0..8]: idle at 0, the 4 run
-- loops spread evenly to 8 (run4 = top). Triangular window of half-width SPACING.
Cfg.ENGINE_ANCHORS = { 0, 2, 4, 6, 8 }   -- [1]=idle, [2..5]=run1..4
Cfg.ENGINE_SPACING = 2.0
Cfg.ENGINE_MASTER  = 0.88   -- #4 balance (owner-set): diesel level (was 1.1, -20%)
Cfg.NOTCH_MAX      = 8

-- Starter crank (engine-start mechanic): the looped starter-motor sound while the
-- driver holds W to crank a cold engine, plus its failed-catch/click one-shot.
Cfg.CRANK_MASTER   = 0.8
Cfg.PRIME_MASTER   = 0.7   -- the fuel-pump hum: present but quieter than the starter
-- Start-sequence smoothing (Task 1.E polish). The prime/crank loops crossfade by engine
-- phase instead of hard start/stop, and the engine layer swells in on catch, so the
-- sequence prime -> crank -> catch -> idle flows as one continuous event.
Cfg.START_FADE  = 0.18   -- s: prime<->crank crossfade + their fade-in/out
Cfg.ENGINE_FADE = 0.45   -- s: the idle/run layer swells in on catch (and out on shutdown)

-- Wheels (steel roll): silent below MIN, ramps volume + pitch to FULL (= V_MAX).
-- Balance (#4, first pass 2026-07-25): in the GP7 CAB the prime mover dominates and the
-- wheel/rail noise sits well under it; 0.40 keeps the roll present without competing with
-- the diesel. (Engine 0.9 >> wheels 0.40 > clacks 0.20.) Tune by ear against the engine.
Cfg.WHEEL_MIN_MPS   = 0.5
Cfg.WHEEL_FULL_MPS  = 29.0     -- RR_Drive V_MAX
Cfg.WHEEL_MASTER    = 1.0   -- #4: rolling bed level (owner-set)
Cfg.WHEEL_PITCH_MIN = 0.85
Cfg.WHEEL_PITCH_MAX = 1.40

-- Rail-joint clacks -- modelled on the REAL sound a 4-axle Geep made on 1990s jointed
-- track, verified by simulating the geometry. Two facts make it authentic:
--   * Standard jointed rail = 39 ft (11.9 m) lengths (RAIL_LEN).
--   * The two rails are laid with STAGGERED joints -- the right rail's joints sit half a
--     rail (RAIL_STAGGER) ahead of the left's. This is universal jointed-track practice.
-- So EACH of the 4 axles has a LEFT wheel (crosses left-rail joints) and a RIGHT wheel
-- (crosses right-rail joints, offset by RAIL_STAGGER) -> 8 clack sources. The result is
-- NOT widely-spaced "da-dunk ... da-dunk" truck pairs (that was an earlier stylisation);
-- it's the real dense, even, faintly-syncopated clatter: within one rail the gaps run
-- 2.45 / 0.76 / 2.45 / 0.29 (x2) -- a steady ~2.45 m pulse with tight doublets woven in,
-- ~7-9 hits/s at branch speed. RR_Sound expands the 4 axles x 2 rails into 8 sources.
Cfg.RAIL_LEN      = 11.9                          -- 39 ft jointed rail
Cfg.RAIL_STAGGER  = 5.95                          -- right rail's joints offset half a rail (staggered)
Cfg.AXLE_OFFSETS  = { 0.0, 2.74, 9.45, 12.19 }   -- 4 axles, 2 trucks (B-B); wheelbase 2.74, centres 9.45
Cfg.CLACK_MIN_MPS = 0.8
Cfg.CLACK_MASTER  = 0.16   -- #4: clack level (owner-set)

-- Brakes.
Cfg.BRAKE_MASTER          = 0.9
Cfg.BRAKE_APPLY_MIN       = 0.05   -- brakeLevel above which the air hiss is audible
Cfg.BRAKE_SQUEAL_MIN_LVL  = 0.20   -- squeal needs at least this much brake
Cfg.BRAKE_SQUEAL_MIN_MPS  = 0.30   -- and some motion
Cfg.BRAKE_SQUEAL_MAX_MPS  = 6.00   -- but only at LOW speed
Cfg.BRAKE_RELEASE_EDGE    = 0.30   -- falling through this level fires the release one-shot

-- World noise (zombie attraction), radii in TILES. FMOD audio (what the player
-- hears) does NOT attract zombies -- only a WorldSoundManager event (the global
-- addSound) does. The loco emits one such event every WORLD_SOUND_PERIOD seconds
-- with a radius = the loudest CURRENT source, so a parked idle draws a little, full
-- throttle draws a lot, and the horn is a deliberate horde-caller. A loco is LOUD.
--
-- Scale note: these are NOT real-world distances. A GP7 (567B, Roots-blown two-stroke,
-- no muffler) runs ~93 dB(A) at 30 m at notch 8 and its horn ~110 dB(A) -- audible for
-- ~2 km and ~5 km respectively, and a PZ tile is ~1 m. Vanilla compresses acoustics by
-- the same order (a shotgun is 200 tiles, really 2-4 km), so we match VANILLA's scale
-- and keep the RATIOS honest. The ratios that matter, from the dB deltas:
--   idle -> notch 8   = 23 dB ~ 5x distance   (30 -> 110, kept)
--   notch 8 -> horn   = 17 dB ~ 4-7x distance (110 -> 250; the horn must clearly
--                       dominate the engine, or notching up is as suicidal as leaning
--                       on the whistle -- that was the bug in the old 150/250)
-- NOISE_CRANK is deliberately ABOVE its acoustics (a real starter is ~85 dB(A) at 30 m,
-- i.e. mid-notch): a cold night start being a magnet is a gameplay choice, not physics.
-- Side effect of the drop above: cranking now TIES notch 8. Intentional for now -- lower
-- it to ~90 if a cold start should read as quieter than a loco working under full load.
Cfg.WORLD_SOUND_PERIOD = 0.5    -- s between noise events
Cfg.NOISE_IDLE       = 30       -- parked, engine idling
Cfg.NOISE_ENGINE_MAX = 110      -- full throttle (notch 8)
Cfg.NOISE_SPEED_MAX  = 90       -- at V_MAX (rolling/wheel/clack noise)
Cfg.NOISE_BELL       = 80       -- bell ringing
Cfg.NOISE_HORN       = 250      -- horn held (gunshot-loud; pulls the horde)
Cfg.NOISE_CRANK      = 110      -- starter cranking a cold engine (a cold night start is a magnet)
Cfg.NOISE_PRIME      = 45       -- fuel-pump hum before the starter turns (modest, but audible)

-- Bell / horn / compressor.
Cfg.BELL_MASTER       = 0.7
Cfg.HORN_MASTER       = 1.95   -- owner-set (+50% from 1.3)
Cfg.HORN_ATTACK       = 0.07   -- s for the loop to swell in as the real attack sample fades out
Cfg.HORN_RELEASE      = 0.06   -- s to FADE the loop out on release (not a hard stop -> that
                               -- mid-cycle cut was an audible click/spike, worse at high master)
Cfg.COMPRESSOR_PERIOD = 55.0   -- seconds between compressor runs
Cfg.COMPRESSOR_MASTER = 0.5

-- Sound propagation classes (simulated distance falloff, doc §7.1):
--   ambient  (engine idle/run, wheel, prime, crank, clacks, compressor) -> 0 at 50 tiles
--   brake    (apply hiss, low-speed squeal, release)                    -> 0 at 100 tiles
--   horn/bell (air devices)                                             -> 0 at 200 tiles
-- Linear rolloff from 1 at distance 0 to 0 at maxRange.
Cfg.RANGE_AMBIENT = 50
Cfg.RANGE_BRAKE   = 100
Cfg.RANGE_HORN    = 200

-- distanceGain(dist, maxRange) -> 1 at 0, linear falloff to 0 at maxRange (PURE).
function Cfg.distanceGain(dist, maxRange)
    dist = tonumber(dist) or 0
    if dist <= 0 then return 1 end
    maxRange = tonumber(maxRange) or 0
    if maxRange <= 0 or dist >= maxRange then return 0 end
    return 1 - dist / maxRange
end

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

--------------------------------------------------------------------------
-- engineMix(notchEff) -> { idle, run1, run2, run3, run4 } volumes.
-- Triangular crossfade around the anchors, EQUAL-POWER normalised: sqrt(Σ w^2) ==
-- ENGINE_MASTER. This matters -- the loops are UNCORRELATED, so their powers add;
-- amplitude-sum normalisation (Σw == MASTER) made the blend halfway between two
-- anchors ~3 dB QUIETER than either anchor (two half-amplitude loops sum to less
-- power than one full loop), so odd notches dipped and idle sounded louder than
-- notch 1-2. Equal-power keeps the blend as loud as the anchors -> a smooth,
-- monotonic loudness rise across the notches. At an exact anchor one loop == MASTER.
--------------------------------------------------------------------------
function Cfg.engineMix(notchEff)
    local x = clamp(notchEff or 0, 0, Cfg.NOTCH_MAX)
    local w, sumsq = {}, 0
    for i = 1, #Cfg.ENGINE_ANCHORS do
        local d  = math.abs(x - Cfg.ENGINE_ANCHORS[i]) / Cfg.ENGINE_SPACING
        local wi = 1 - d
        if wi < 0 then wi = 0 end
        w[i]  = wi
        sumsq = sumsq + wi * wi
    end
    if sumsq <= 0 then w[1] = 1; sumsq = 1 end   -- safety (shouldn't happen on [0,8])
    local norm = Cfg.ENGINE_MASTER / math.sqrt(sumsq)
    for i = 1, #w do w[i] = w[i] * norm end
    return w
end

--------------------------------------------------------------------------
-- wheelMix(speed) -> volume, pitch.  |v|<MIN => silent. Ramps linearly to FULL.
--------------------------------------------------------------------------
function Cfg.wheelMix(speed)
    local s = math.abs(speed or 0)
    if s < Cfg.WHEEL_MIN_MPS then
        return 0, Cfg.WHEEL_PITCH_MIN
    end
    local f = clamp((s - Cfg.WHEEL_MIN_MPS) / (Cfg.WHEEL_FULL_MPS - Cfg.WHEEL_MIN_MPS), 0, 1)
    return f * Cfg.WHEEL_MASTER,
           Cfg.WHEEL_PITCH_MIN + f * (Cfg.WHEEL_PITCH_MAX - Cfg.WHEEL_PITCH_MIN)
end

--------------------------------------------------------------------------
-- brakeMix(brakeLevel, speed) -> applyVol, squealVol.
--   apply  : air hiss, proportional to brake pressure (moving only; silent at rest).
--   squeal : metallic shoe squeal, only under brake at LOW speed, louder as it
--            slows toward a stop.
--------------------------------------------------------------------------
function Cfg.brakeMix(brakeLevel, speed)
    local bl = clamp(brakeLevel or 0, 0, 1)
    local s  = math.abs(speed or 0)

    local apply = 0
    if s > 0 and bl > Cfg.BRAKE_APPLY_MIN then apply = bl * Cfg.BRAKE_MASTER end

    local squeal = 0
    if bl > Cfg.BRAKE_SQUEAL_MIN_LVL
       and s > Cfg.BRAKE_SQUEAL_MIN_MPS and s < Cfg.BRAKE_SQUEAL_MAX_MPS then
        local sf = 1 - (s - Cfg.BRAKE_SQUEAL_MIN_MPS)
                       / (Cfg.BRAKE_SQUEAL_MAX_MPS - Cfg.BRAKE_SQUEAL_MIN_MPS)
        squeal = clamp(sf, 0, 1) * bl * Cfg.BRAKE_MASTER
    end
    return apply, squeal
end

--------------------------------------------------------------------------
-- clackOffsets(): the 8 wheel positions (m along the loco) whose crossing of a rail
-- joint makes a clack -- each axle's LEFT wheel (left-rail joints) and RIGHT wheel
-- (right-rail joints, which are STAGGERED half a rail ahead). A wheel at offset o clacks
-- when (distance + o) passes a multiple of RAIL_LEN; a right wheel's joints are shifted
-- by RAIL_STAGGER, i.e. its EFFECTIVE offset is o - RAIL_STAGGER (same floor() logic).
-- Pure + order-stable so RR_Sound can keep one joint-index per entry across ticks.
--------------------------------------------------------------------------
function Cfg.clackOffsets()
    local out = {}
    local stag = Cfg.RAIL_STAGGER or 0
    for i = 1, #Cfg.AXLE_OFFSETS do
        local a = Cfg.AXLE_OFFSETS[i]
        out[#out + 1] = a            -- left wheel
        out[#out + 1] = a - stag     -- right wheel (staggered joints)
    end
    return out
end

--------------------------------------------------------------------------
-- worldNoiseRadius(notchEff, speed, bellOn, hornOn) -> radius in tiles for the
-- zombie-attracting WorldSoundManager event. = the loudest current contributor
-- (engine scales with throttle from an idle floor; wheels with speed; bell/horn
-- add their own), so every loco sound attracts at some distance and the horn most.
--------------------------------------------------------------------------
-- The engine contribution (idle floor + throttle) applies ONLY when the prime mover
-- is actually `running` -- a SHUT-DOWN loco makes no engine sound, so it must not draw
-- zombies via a phantom idle floor. This mirrors the engine AUDIO gate in RR_Sound:
-- if you can't hear the diesel, neither can the horde. The other sources are engine-
-- independent and still count when off: `cranking` (the starter motor is loud even
-- before the diesel catches -- a cold night start draws attention), rolling/`speed`
-- (a loco coasting with the engine dead still clatters on the rail), and the player-
-- triggered bell/horn. A stopped, silent, parked loco returns 0 (RR_Sound then skips
-- addSound entirely -> no attraction).
function Cfg.worldNoiseRadius(notchEff, speed, bellOn, hornOn, cranking, running, priming)
    local n = clamp((notchEff or 0) / Cfg.NOTCH_MAX, 0, 1)
    local s = clamp(math.abs(speed or 0) / Cfg.WHEEL_FULL_MPS, 0, 1)
    local r = 0
    if running then
        r = Cfg.NOISE_IDLE + n * (Cfg.NOISE_ENGINE_MAX - Cfg.NOISE_IDLE)     -- engine idle floor + throttle
    end
    r = math.max(r, s * Cfg.NOISE_SPEED_MAX)                                 -- rolling/wheel noise (even coasting)
    if priming  then r = math.max(r, Cfg.NOISE_PRIME) end                    -- fuel pump hums before the starter
    if cranking then r = math.max(r, Cfg.NOISE_CRANK) end
    if bellOn then r = math.max(r, Cfg.NOISE_BELL) end
    if hornOn then r = math.max(r, Cfg.NOISE_HORN) end
    return math.floor(r + 0.5)
end

--------------------------------------------------------------------------
-- hardImpactLayers(absSpeed, derailed) -> ordered array of { name, volume } one-shots to
-- play for a HARD strike (railcar / another loco), tiered by the speed at contact:
--   < V_MED   : light car-crash  + a soft metal thud           (простой удар на небольшой скорости)
--   < V_HEAVY : medium crash     + a louder metal thud          (сильный удар + небольшие разрушения)
--   >= V_HEAVY: heavy crash + full metal thud + a deep EXPLOSIVE BOOM   (звук жёсткого крушения)
-- On an actual DERAIL a metal-debris COLLAPSE is layered on TOP of whichever tier fired -- off the
-- rails + heavier than a plain hard hit. (The explosive pipe-bomb blast was dropped, owner 2026-07-24
-- -- it read wrong for a derail.) Pure + order-stable so the adapter
-- just plays the list. The audible tier is chosen by which crash EVENT (a lone
-- animal:playSound ignores per-handle volume); the `volume` fields matter only on the
-- world-emitter fallback path and for any future mixing.
--------------------------------------------------------------------------
function Cfg.hardImpactLayers(absSpeed, derailed)
    local v = math.abs(absSpeed or 0)
    local H = Cfg.HARD_IMPACT
    local M = H.MASTER
    local layers = {}
    if v >= H.V_HEAVY then
        -- CRASH: a wall of sound -- heavy impact + metal rupture + a deep explosive boom. The boom
        -- is UNCONDITIONAL at this tier: it used to be gated on the probabilistic derail roll, which
        -- rarely fires at 50-65 km/h (0 at 50 -> 1.0 at 80), so a fast HARD hit sounded no bigger
        -- than a medium one (owner 2026-07-24: "high-speed HARD isn't a hard-crash sound"). A violent
        -- impact should sound catastrophic whether or not the loco technically leaves the rails.
        layers[#layers + 1] = { name = Cfg.names.hardCrashHeavy,  volume = M }
        layers[#layers + 1] = { name = Cfg.names.hardThud,        volume = H.THUD_HEAVY  * M }
        layers[#layers + 1] = { name = Cfg.names.hardWreckBoom,   volume = M }
    elseif v >= H.V_MED then
        layers[#layers + 1] = { name = Cfg.names.hardCrashMedium, volume = M }
        layers[#layers + 1] = { name = Cfg.names.hardThud,        volume = H.THUD_MEDIUM * M }
    else
        layers[#layers + 1] = { name = Cfg.names.hardCrashLight,  volume = M }
        layers[#layers + 1] = { name = Cfg.names.hardThud,        volume = H.THUD_LIGHT  * M }
    end
    -- DERAIL: the loco actually leaves the rails -- a metal-debris COLLAPSE layered on TOP of
    -- whichever tier fired, so a genuine wreck is unmistakably heavier than a plain hard hit.
    -- (The sharp explosive blast `hardWreckBlast`/PipeBombExplode was removed -- owner 2026-07-24:
    -- a pipe-bomb bang reads wrong for a derail; the debris collapse alone carries it. The name is
    -- kept in Cfg.names, unused, so it can be re-added if a proper crash-blast sample lands.)
    if derailed then
        layers[#layers + 1] = { name = Cfg.names.hardWreckDebris, volume = M }
    end
    return layers
end

RR = RR or {}
RR.SoundConfig = Cfg

return Cfg
