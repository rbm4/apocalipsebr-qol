--***********************************************************************
-- Railroader / RR_Lights  -- locomotive lighting model (Task 1.K), PURE
--
-- What a GP7/GP10 actually carried, and what we reproduce:
--   * HEADLIGHT, one per END (the loco is bidirectional): a Pyle-National case with
--     TWO sealed beams, wired across the ~74 V bus. Three-position switch
--     OFF / DIM / BRIGHT -- "dim" is a real running position (meeting a train at
--     night so you don't blind the other crew, and yard work), not just "half off".
--     Only the LEADING end burns; the trailing one is switched off by the crew.
--   * NUMBER BOARDS: the lit boxes carrying the road number ("800"), backlit by
--     small incandescents. On whenever the loco is working.
--   * CAB LIGHT: dome light. Deliberately NOT on while running at night -- the crew
--     keeps the cab dark to see out -- so it's a separate switch, off by default.
--   * CLASS LIGHTS: deliberately absent. GP7s had them (white/green/red lenses for
--     train class), but the signalling practice died in the '60s and the Paducah GP10
--     rebuilds plated them over.
--   * DITCH LIGHTS: deliberately absent. Not required in the US until the 1996-97 FRA
--     rule; the game is July 1993. A K&L GP10 would not have them.
--
-- POWER (this is the whole gameplay hook): the bus is the BATTERY, topped up by an
-- auxiliary generator off the prime mover. So -- exactly like the vanilla car --
-- lights are FREE while the engine runs (the generator carries them) and eat the
-- BATTERY when it doesn't. Leave the headlight on in a parked loco and you come back
-- to a starter that won't turn.
--
-- ENGINE-FREE, so it unit-tests in a bare interpreter (tests/run_tests.lua). This
-- module answers two questions and nothing else:
--     "given the switches and the battery, what is actually lit?"  -> effective()
--     "where do the light sources go, relative to the loco?"       -> emitters()
-- Turning emitters into real IsoLightSources on the map is the client adapter's job
-- (client/Railroader/RR_LightsRender.lua).
--
-- WHY THE BEAM IS A CHAIN OF POINT LIGHTS (verified against the B42 decompile):
-- PZ has two lighting systems. IsoLightSource -- the only one reachable from Lua --
-- is a RADIAL point light on an integer tile: no direction, no cone, no angle (the
-- native addLight() takes only x/y/z/radius/rgb). The real cone light is the "torch"
-- (LightingJNI.updateTorch), which is what a flashlight and a car headlight both are,
-- and LightingJNI.checkLights() only ever walks IsoPlayer.players[] and
-- IsoCell.getVehicles(). Our loco is an IsoAnimal in neither list, and LightingJNI is
-- not exposed to Lua -- so a true cone is IMPOSSIBLE here, not merely awkward.
-- We therefore fake the beam as a row of point lights laid ON THE SPLINE ahead of the
-- nose. Offsets below are ROUTE DISTANCES, not body-frame offsets, on purpose: the
-- beam then bends with the rails through a curve, which is what a real headlight
-- (bolted to the frame, sweeping the outside of the curve) conspicuously does NOT do.
-- We get an arguably better-looking lie than the thing we couldn't have.
--***********************************************************************

RR = RR or {}

local Lights = {}

-- Headlight switch positions (the real three-position control).
Lights.OFF    = 0
Lights.DIM    = 1
Lights.BRIGHT = 2

local C = {
    -- Colour saturation cap. LightingJNI clamps each channel to min(ch * 2, 1), so
    -- ANY channel above 0.5 saturates to full white and the tint is lost. 0.5 is
    -- therefore "maximum brightness that still has a colour".
    MAX_CH = 0.5,

    -- Warm sealed-beam white. Same tint vanilla gives a car headlight
    -- (VehicleLight defaults r=1.0 g=0.8235 b=0.7059).
    BEAM_COLOR  = { 1.00, 0.82, 0.71 },
    BOARD_COLOR = { 1.00, 0.95, 0.85 },   -- number boards: near-white incandescent
    CAB_COLOR   = { 1.00, 0.86, 0.66 },   -- cab dome: warmer, dimmer

    -- The beam, as { aheadOfNose (tiles), radius (tiles), intensity 0..1 }.
    -- `ahead` is measured from where the beam STARTS, not from the nose -- BEAM_GAP below
    -- pushes the whole beam that many tiles past the front of the loco, so the lit ground
    -- begins one tile BEYOND the lamp instead of right under it (the lamp itself is now
    -- painted on the model, so the beam no longer has to mark where it is).
    -- Radius is capped at 20 by the engine for permanent lights; we stay well under.
    -- v1.0.3f: BRIGHT extended 18 -> 32 tiles and every tier got brighter + wider
    -- (owner: "灯光需要更明亮、距离更远").
    BEAM_GAP    = 2.0,   -- tiles from the nose to the first beam light (live-tunable)
    BEAM_BRIGHT = {
        {  0.0, 6, 1.00 },
        {  8.0, 8, 0.90 },
        { 16.0, 8, 0.72 },
        { 24.0, 7, 0.55 },
        { 32.0, 6, 0.42 },
    },
    -- DIM is not "BRIGHT * 0.5": it's a genuinely SHORT beam, because that is what the
    -- position is for -- lighting the ground just ahead without throwing light down the
    -- track into someone's eyes.
    BEAM_DIM = {
        {  0.0, 4, 0.70 },
        {  6.0, 5, 0.50 },
        { 12.0, 5, 0.34 },
    },

    BOARD_RADIUS    = 2,     BOARD_INTENSITY = 0.35,
    CAB_RADIUS      = 4,     CAB_INTENSITY   = 0.50,
    BOARD_INSET     = 0.5,   -- tiles in from the nose/tail, where the boards sit

    -- Battery draw, charge/s (battery is 0..1, as in RR_Engine). Only ever charged
    -- while the engine is OFF -- a running generator carries the whole load for free,
    -- which is both how the prototype works and what vanilla does to a car
    -- (Vehicles.Update.Headlight only bills you when isEngineRunning() is false).
    -- Scale: bright headlight alone takes a full battery down to the CUTOFF below in
    -- ~15 real minutes of standing.
    DRAW_BRIGHT = 0.00060,
    DRAW_DIM    = 0.00030,
    DRAW_CAB    = 0.00015,
    DRAW_BOARDS = 0.00010,

    -- Lights cut out at this charge and refuse to come back on -- they may NOT drain
    -- the battery below the level that still cranks the engine.
    -- WHY: there is no way to charge a battery in the mod yet (Task 1.J spawns rolled
    -- batteries against exactly this floor, RR_Spawn). Without the cutoff, leaving the
    -- headlight on would permanently brick the only loco in the save with no recovery.
    -- The number mirrors RR_Spawn's floor: Engine.C.CRANK_MIN (0.15) plus three crank
    -- attempts' drain (3 * CRANK_DRAIN * CRANK_TIME = 3 * 0.05 * 1.6 = 0.24), rounded
    -- up. DROP THIS (and RR_Spawn's) the day battery charging lands -- at that point
    -- flattening the battery with your own headlight should absolutely be allowed to
    -- strand you.
    CUTOFF = 0.44,
}
Lights.C = C

-- v1.0.3f: which end the HEADLIGHT faces. +1 = toward increasing route distance
-- ("forward"), -1 = the other end. The loco's POSE always faces the +distance
-- tangent, so the leading end is a property of MOTION, not of the model:
--   moving     -> the direction of travel (deadbanded so a creep never flickers)
--   standing   -> the reverser's direction (about to move that way)
--   neutral    -> the LAST direction (a standing loco keeps its headlight end)
--   first spawn -> +1 (forward), the owner's spec
Lights.FACE_V = 0.3      -- m/s: below this, speed does not decide the beam end

function Lights.faceSign(v, reverser, last)
    if math.abs(v or 0) > Lights.FACE_V then return (v > 0) and 1 or -1 end
    if (reverser or 0) ~= 0 then return (reverser > 0) and 1 or -1 end
    return (last == -1) and -1 or 1
end

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

--------------------------------------------------------------------------
-- newState: the switches as the driver left them. A loco found in the world is dark
-- (nobody has been in the cab for a year), but its number boards light the moment
-- there is power -- they have no switch of their own in our model, they ARE "the
-- loco is electrically alive".
--------------------------------------------------------------------------
function Lights.newState()
    return {
        head   = Lights.OFF,   -- OFF | DIM | BRIGHT -- applies to the LEADING end
        cab    = false,        -- dome light
        boards = true,         -- number boards
    }
end

--------------------------------------------------------------------------
-- nextHead(l): where the switch WOULD land if you cycled it -- without moving it.
-- The cab radial menu spends ONE slice on the headlight and labels it with the
-- position the click LANDS on (vanilla's idiom: a car's slice reads "Headlights On"
-- when they are off). Label and command therefore have to come from the same answer,
-- or a slice could say one thing and do another; this is that answer.
--------------------------------------------------------------------------
function Lights.nextHead(l)
    return (((l and l.head) or 0) + 1) % 3
end

--------------------------------------------------------------------------
-- cycleHead(l): the three-position switch, OFF -> DIM -> BRIGHT -> OFF. The way a
-- hand on the real lever moves it, and what the F key does.
--------------------------------------------------------------------------
function Lights.cycleHead(l)
    l.head = Lights.nextHead(l)
    return l.head
end

--------------------------------------------------------------------------
-- setHead(l, mode): put the switch in a GIVEN position. A menu is a list of results,
-- not a lever: picking "bright" must land on BRIGHT whatever the switch was doing
-- before. An unknown position is IGNORED rather than wrapped -- a caller asking for a
-- position that doesn't exist is a bug, and quietly landing on a different one would
-- hide it. Returns the position the switch is in afterwards.
--------------------------------------------------------------------------
function Lights.setHead(l, mode)
    if not l then return nil end
    if mode == Lights.OFF or mode == Lights.DIM or mode == Lights.BRIGHT then
        l.head = mode
    end
    return l.head
end

--------------------------------------------------------------------------
-- powered(eng): is there enough bus voltage to run lights at all?
-- A running engine always powers them (generator). A dead one powers them only while
-- the battery is above the crank-protection floor.
--------------------------------------------------------------------------
function Lights.powered(eng)
    if not eng then return false end
    if eng.running then return true end
    return (eng.battery or 0) > C.CUTOFF
end

--------------------------------------------------------------------------
-- effective(l, eng): what is ACTUALLY lit, after the power gate. Never mutates the
-- switches -- a flat battery doesn't flip the driver's switch back, it just stops
-- answering it, and the light returns by itself once the engine runs. Returns a state
-- table of the same shape as newState().
--------------------------------------------------------------------------
function Lights.effective(l, eng)
    if not (l and Lights.powered(eng)) then
        return { head = Lights.OFF, cab = false, boards = false }
    end
    return { head = l.head or Lights.OFF, cab = l.cab or false, boards = l.boards or false }
end

--------------------------------------------------------------------------
-- draw(l, eng): battery draw in charge/s for the CURRENTLY LIT set. Zero while the
-- engine runs (the generator carries it) and zero when the power gate is shut.
--------------------------------------------------------------------------
function Lights.draw(l, eng)
    if eng and eng.running then return 0 end
    local e = Lights.effective(l, eng)
    local d = 0
    if e.head == Lights.BRIGHT then d = d + C.DRAW_BRIGHT
    elseif e.head == Lights.DIM then d = d + C.DRAW_DIM end
    if e.cab    then d = d + C.DRAW_CAB    end
    if e.boards then d = d + C.DRAW_BOARDS end
    return d
end

--------------------------------------------------------------------------
-- tick(l, eng, dt): spend one tick of battery on the lights. Mutates eng.battery
-- only (RR_Engine owns the battery; this is the one thing outside it that spends
-- charge, so it stays a plain subtraction rather than a new Engine entry point).
-- Returns true on the tick the lights JUST cut out, so the caller can tell the driver.
--------------------------------------------------------------------------
function Lights.tick(l, eng, dt)
    if not (l and eng) then return false end
    local was = Lights.powered(eng)
    local d = Lights.draw(l, eng) * (dt or 0)
    if d > 0 then
        eng.battery = clamp((eng.battery or 0) - d, 0, 1)
    end
    return was and not Lights.powered(eng)
end

--------------------------------------------------------------------------
-- emitters(l, eng, ctx): the light sources to place, as offsets ALONG THE ROUTE from
-- the loco's centre distance. The caller samples its spline at (centreDistance + dOff)
-- and puts an IsoLightSource there.
--
--   ctx.halfLen : half the body length in tiles (RR.Body.extents(size) / 2)
--   ctx.lead    : which end is leading, in ROUTE-DISTANCE sign: +1 = the end toward
--                 increasing distance, -1 = the other. (The loco is always POSED along
--                 the +distance tangent regardless of which way it is travelling, so
--                 "which end leads" is a property of the reverser/speed, not the pose.
--                 The caller passes it; nil/0 means "no end leads" -> no headlight,
--                 which is exactly right for a loco standing in neutral.)
--
-- Each emitter: { dOff, radius, r, g, b, kind }.
-- rgb are already engine-ready (tint * intensity * MAX_CH), i.e. pass straight to
-- IsoLightSource. kind is for the adapter's debug/logging only.
--------------------------------------------------------------------------
function Lights.emitters(l, eng, ctx)
    local out = {}
    local e   = Lights.effective(l, eng)
    local hl  = (ctx and ctx.halfLen) or 0
    local s   = (ctx and ctx.lead) or 0

    local function put(dOff, radius, color, intensity, kind)
        out[#out + 1] = {
            dOff   = dOff,
            radius = radius,
            r = color[1] * intensity * C.MAX_CH,
            g = color[2] * intensity * C.MAX_CH,
            b = color[3] * intensity * C.MAX_CH,
            kind = kind,
        }
    end

    -- Headlight: only on the leading end, and only if an end IS leading.
    if e.head ~= Lights.OFF and s ~= 0 then
        local beam = (e.head == Lights.BRIGHT) and C.BEAM_BRIGHT or C.BEAM_DIM
        for _, b in ipairs(beam) do
            local ahead, radius, intensity = b[1], b[2], b[3]
            -- hl + BEAM_GAP clears the loco itself; +ahead runs down the rails from there.
            put(s * (hl + C.BEAM_GAP + ahead), radius, C.BEAM_COLOR, intensity, "beam")
        end
    end

    -- Number boards: BOTH ends, always, whenever the loco has power. They are how you
    -- spot the thing sitting in the dark shed before you ever touch the headlight.
    if e.boards then
        local inset = hl - C.BOARD_INSET
        if inset < 0 then inset = 0 end
        put( inset, C.BOARD_RADIUS, C.BOARD_COLOR, C.BOARD_INTENSITY, "board")
        put(-inset, C.BOARD_RADIUS, C.BOARD_COLOR, C.BOARD_INTENSITY, "board")
    end

    -- Cab dome light: the cab is at the loco's centre in our model.
    if e.cab then
        put(0, C.CAB_RADIUS, C.CAB_COLOR, C.CAB_INTENSITY, "cab")
    end

    return out
end

--------------------------------------------------------------------------
-- THE VISIBLE LAMPS -- painted on the locomotive's own texture.
--
-- The IsoLightSource chain above lights the WORLD; it does nothing for the loco's own
-- model, which stays as dark as the night around it. PZ gives a non-vehicle model no
-- emissive channel at all: `animalEffect.frag` hard-clamps a lit model to its own albedo,
-- and the vehicle TextureLights path is a VehicleModelInstance field gated on
-- `effect.isVehicleShader()`. So a headlight has to be BOTH painted and specially shaded.
--
-- WE TRIED IT THE OTHER WAY, TWICE. The lens was a separate world entity carrying a
-- full-bright mesh. That fights the engine on every axis at once -- its own position, its
-- own grid square, its own depth sort -- and it lost: the lamp hung in mid-air off the
-- nose, then buried itself inside the hood, then jumped somewhere new on every toggle.
-- A headlight is part of the locomotive. So now it IS part of the locomotive: the twin
-- sealed-beam lenses are painted into the loco's texture (stamped in 3D, then carried
-- through the shattered UV atlas by a baked Generated-coordinate pass), and they can never
-- be in the wrong place because they are not placed at all.
--
-- Being LIT is then a property of WHICH TEXTURE IS BOUND, and swapping the skin is the one
-- per-instance channel PZ offers from Lua (AnimalVisual.setSkinTextureName +
-- resetModelNextFrame). Three variants -- and the switch position is literally how many of
-- the two sealed beams are burning, which is what the real switch physically does:
--     OFF    -> both lenses dark glass
--     DIM    -> the upper beam lit
--     BRIGHT -> both beams lit
-- The lit lenses are painted in KEY MAGENTA; our shader (42/media/shaders/rr_loco.frag)
-- renders any magenta texel FULL-BRIGHT, ignoring the world lighting. That is what makes
-- the lamp actually bright at midnight rather than merely painted.
--
-- BOTH ENDS of the loco are painted, and both light together. The two ends are
-- geometrically near-identical, so nothing in the mesh says which one is "forward" --
-- lighting only the leading end would be a coin flip. It also halves the number of texture
-- variants and means the reverser never triggers a model rebuild.
--------------------------------------------------------------------------
Lights.SKIN = {
    OFF    = "RR_LocoTest",
    DIM    = "RR_LocoTest_dim",
    BRIGHT = "RR_LocoTest_bright",
}

--------------------------------------------------------------------------
-- skin(l, eng): the texture the loco should be wearing right now. Follows effective(), so
-- a headlight the battery is refusing to answer shows dark glass, and the lamps come back
-- by themselves once the engine runs.
--------------------------------------------------------------------------
function Lights.skin(l, eng)
    local e = Lights.effective(l, eng)
    if e.head == Lights.BRIGHT then return Lights.SKIN.BRIGHT end
    if e.head == Lights.DIM    then return Lights.SKIN.DIM    end
    return Lights.SKIN.OFF
end

--------------------------------------------------------------------------
-- headLabel(l, eng) / label(l, eng): short HUD strings. headLabel reports what is
-- REALLY happening, so a switch that the battery is refusing to answer reads "DEAD"
-- rather than lying about being on.
--------------------------------------------------------------------------
function Lights.headLabel(l, eng)
    local want = l and l.head or Lights.OFF
    if want == Lights.OFF then return "OFF" end
    if not Lights.powered(eng) then return "DEAD" end
    return (want == Lights.BRIGHT) and "BRIGHT" or "DIM"
end

RR.Lights = Lights
return Lights
