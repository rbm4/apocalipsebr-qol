--***********************************************************************
-- Railroader / RR_LightsRender  -- puts RR_Lights' emitters on the map (Task 1.K)
--
-- The pure model (shared/Railroader/RR_Lights) says WHAT is lit and WHERE, as offsets
-- along the route. This adapter samples the spline at those offsets and keeps a real
-- IsoLightSource alive on each resulting tile. Lifecycle mirrors RR_Sound/RR_Collider:
-- RR_TrainEntity calls onSpawn / update / onRemove per loco record.
--
-- THE THREE ENGINE FACTS THIS FILE IS BUILT AROUND (all verified in the B42 decompile,
-- get them wrong and the lights silently do nothing):
--
--  1. A REGISTERED LIGHT CANNOT BE MOVED. LightingJNI hands the position to the native
--     lighting engine exactly once, in addLight(); there is no setLightPos and the
--     per-frame reconcile (LightingJNI.checkLights) diffs ONLY colour and active.
--     So setX/setY on a live IsoLightSource updates the Java object and moves nothing.
--     To move a light you must removeLamppost + addLamppost a light at the new tile.
--     COLOUR, though, *is* diffed -- so intensity changes at a standing loco are free,
--     and only actual movement costs a re-registration.
--
--  2. YOU CANNOT RE-ADD THE OBJECT YOU JUST REMOVED. IsoCell.removeLamppost(ls) does
--     not unregister anything; it only sets ls.life = 0 and leaves the reaping to the
--     next lighting pass. Vanilla (BaseVehicle.updateWorldLights, the police lightbar)
--     dodges this by double-buffering two IsoLightSource objects per lamp and resetting
--     life = -1 by hand on the one it re-adds. We do the simpler thing IsoFire does and
--     CONSTRUCT A FRESH IsoLightSource every time -- a new object already has life = -1,
--     so we never write the `life` field at all (there is no setter for it, and writing
--     a public Java field from Kahlua is not something to bet the feature on).
--
--  3. LIGHTING RUNS AT 15 Hz, NOT AT FRAME RATE (PerformanceSettings.lightingFps), and
--     every add/remove sets Core.dirtyGlobalLightsCount, which forces the native engine
--     into a full global relight instead of an incremental one. A loco at track speed
--     crosses a tile several times a second and carries up to six emitters, so
--     reconciling every tick would pin the lighting engine in permanent global-relight
--     for no visible gain. Hence MIN_INTERVAL below: we re-place lights at the rate the
--     engine can actually show them. The battery still drains every tick.
--
-- Chunk streaming: LightingJNI silently drops any light that fails isInBounds() (i.e.
-- once the loco's chunk is not loaded around a player), and there is no callback. We
-- therefore rebuild from scratch on spawn and on re-adoption; the in-session
-- chunk-unload case is the same open hole as the rest of Task 1.G and is not fixed here.
--***********************************************************************

print("[Railroader] RR_LightsRender.lua: loading...")
require("Railroader/RR_Spline")
require("Railroader/RR_Body")
require("Railroader/RR_Lights")

local LightsRender = {}
LightsRender.enabled     = true
LightsRender.MIN_INTERVAL = 1.0 / 15.0   -- s between re-placements; see fact (3) above
LightsRender.MAX_RADIUS   = 20           -- engine clamps permanent lights to this anyway

--------------------------------------------------------------------------
-- Which END of the loco is leading, as a sign in ROUTE-DISTANCE space. The loco is always
-- POSED along the +distance tangent whichever way it is rolling (it's a loco -- it has no
-- "wrong way round"), so the leading end is a property of the reverser, not of the pose.
-- Only the ground BEAM uses this; the painted lamps burn at both ends.
-- v1.0.3f: the sign is rec.faceSign -- motion-derived, deadbanded, neutral-keeps-last,
-- first-spawn-forward, persisted server-side and broadcast as fs. The old reverser-only
-- read killed the beam in neutral and could flicker on a lagging lever snapshot.
--------------------------------------------------------------------------
local function leadSign(rec)
    return ((rec.faceSign or 1) == -1) and -1 or 1
end

--------------------------------------------------------------------------
-- THE VISIBLE LAMPS: a texture swap, and nothing more.
--
-- The lenses are painted into the loco's own texture, so there is no lamp to position, no
-- grid square to keep it in, and no depth sort to lose. Being lit is just which of the
-- three skins is bound. This is the whole feature now -- it replaces ~120 lines of entity
-- spawning, pinning and orphan-sweeping that could never keep the lamp on the hood.
--
-- setSkinTextureName caches into the ModelSlot, so the model has to be rebuilt for the
-- swap to take: resetModelNextFrame() is the supported way (the updateModelTextures dirty
-- flag is NOT -- it routes through getHumanVisual(), which is null on an animal and NPEs).
-- We therefore only touch it when the skin ACTUALLY changes, i.e. on a keypress, never per
-- tick.
--------------------------------------------------------------------------
local function applySkin(rec)
    if not rec.animal then return end
    local want = RR.Lights.skin(rec.lightState, rec.engine)
    if want == rec.skin then return end
    rec.skin = want
    pcall(function()
        rec.animal:getAnimalVisual():setSkinTextureName(want)
        rec.animal:resetModelNextFrame()
    end)
end

--------------------------------------------------------------------------
-- Make one IsoLightSource at a tile. Fresh object every time -- see fact (2).
--------------------------------------------------------------------------
local function makeSource(cell, tx, ty, tz, r, g, b, radius)
    local ls
    local ok = pcall(function()
        ls = IsoLightSource.new(tx, ty, tz, r, g, b, radius)
    end)
    if not (ok and ls) then return nil end
    if not pcall(function() cell:addLamppost(ls) end) then return nil end
    return ls
end

--------------------------------------------------------------------------
-- Reconcile the live sources against what RR_Lights says should exist right now.
-- Emitter i keeps slot i, so a beam that stays the same length just gets its tiles
-- (or its colour) updated rather than being torn down and rebuilt.
--------------------------------------------------------------------------
local function reconcile(rec)
    local L    = rec.lights
    local cell = getCell()
    if not cell then return end

    local size = 0.7
    if rec.animal then pcall(function() size = rec.animal:getAnimalSize() end) end
    local len  = RR.Body.extents(size)

    local ems = RR.Lights.emitters(rec.lightState, rec.engine,
                                   { halfLen = len * 0.5, lead = leadSign(rec) })

    for i, em in ipairs(ems) do
        -- Sample the RAILS, not the body frame: the beam is supposed to follow the
        -- track round a curve (see the header of RR_Lights). sampleExt extrapolates
        -- past a buffer stop instead of piling the whole beam onto the last node.
        local p  = RR.Spline.sampleExt(rec.route, rec.distance + em.dOff)
        local tx = math.floor(p.x + (rec.ox or 0))
        local ty = math.floor(p.y + (rec.oy or 0))
        local tz = math.floor((p.z or 0) + (rec.oz or 0) + 0.5)
        local radius = math.floor(em.radius)
        if radius > LightsRender.MAX_RADIUS then radius = LightsRender.MAX_RADIUS end

        local cur = L.srcs[i]
        if cur and cur.tx == tx and cur.ty == ty and cur.tz == tz and cur.radius == radius then
            -- Same tile, same radius: colour is the ONE thing the engine will pick up
            -- in place (fact 1), so an intensity change costs nothing here.
            if cur.r ~= em.r or cur.g ~= em.g or cur.b ~= em.b then
                pcall(function()
                    cur.ls:setR(em.r); cur.ls:setG(em.g); cur.ls:setB(em.b)
                end)
                cur.r, cur.g, cur.b = em.r, em.g, em.b
            end
        else
            if cur and cur.ls then pcall(function() cell:removeLamppost(cur.ls) end) end
            local ls = makeSource(cell, tx, ty, tz, em.r, em.g, em.b, radius)
            L.srcs[i] = ls and { ls = ls, tx = tx, ty = ty, tz = tz, radius = radius,
                                 r = em.r, g = em.g, b = em.b, kind = em.kind } or nil
        end
    end

    -- Fewer emitters than last time (BRIGHT -> DIM, or the battery gave out): drop the tail.
    for i = #L.srcs, #ems + 1, -1 do
        local s = L.srcs[i]
        if s and s.ls then pcall(function() cell:removeLamppost(s.ls) end) end
        L.srcs[i] = nil
    end
end

--------------------------------------------------------------------------
-- Tear down every live source and empty the slot list. Used by onRemove (the
-- loco is gone) and rebuild (re-adoption -- the old session's sources, if any,
-- must not stay burning). A fresh IsoLightSource is made on the next reconcile.
--------------------------------------------------------------------------
local function clearSources(rec)
    local L = rec and rec.lights
    if not L or not L.srcs then return end
    local cell = getCell()
    for i = #L.srcs, 1, -1 do
        local s = L.srcs[i]
        if s and s.ls and cell then pcall(function() cell:removeLamppost(s.ls) end) end
        L.srcs[i] = nil
    end
end

--------------------------------------------------------------------------
-- onSpawn: give the record its switches and an empty source list.
--------------------------------------------------------------------------
function LightsRender.onSpawn(rec)
    if not (LightsRender.enabled and rec) then return end
    rec.lightState = rec.lightState or RR.Lights.newState()
    rec.lights     = { srcs = {}, acc = 0 }
    rec.skin       = nil            -- force applySkin to bind the right texture on tick 1
end

--------------------------------------------------------------------------
-- update: called each tick from RR_TrainEntity.onTick, after the pose is applied.
-- The battery is spent every tick (it's physics); the lights are re-placed at the rate
-- the lighting engine can actually render them (fact 3).
--------------------------------------------------------------------------
function LightsRender.update(rec, dt)
    if not (LightsRender.enabled and rec and rec.route) then return end
    if not rec.lights then LightsRender.onSpawn(rec) end
    local L = rec.lights

    if RR.Lights.tick(rec.lightState, rec.engine, dt) then
        print("[Railroader] lights: battery too low -- lights cut out.")
    end

    -- The painted lenses: a cheap string compare every tick, a model rebuild only when the
    -- switch actually moves.
    applySkin(rec)

    -- The world lights re-place at the rate the lighting engine can actually show them.
    L.acc = (L.acc or 0) + (dt or 0)
    if L.acc < LightsRender.MIN_INTERVAL then return end
    L.acc = 0
    reconcile(rec)
end

--------------------------------------------------------------------------
-- onRemove: called from TrainEntity.clear. Sources must go with the loco or they
-- stay burning on an empty patch of track.
--------------------------------------------------------------------------
function LightsRender.onRemove(rec)
    clearSources(rec)
    if rec then rec.lights = nil end
end

--------------------------------------------------------------------------
-- rebuild(rec): tear the sources down so the next update re-registers them from
-- scratch. Needed after a re-adoption (the loco's old lights, if any, belong to a
-- session that is gone) and any time we suspect the engine has culled them.
--------------------------------------------------------------------------
function LightsRender.rebuild(rec)
    if not rec then return end
    clearSources(rec)
    rec.skin       = nil                         -- re-bind the skin from the restored switches
    rec.lightState = rec.lightState or RR.Lights.newState()
    rec.lights     = rec.lights or { srcs = {}, acc = 0 }
    rec.lights.acc = LightsRender.MIN_INTERVAL   -- reconcile on the very next tick
end

--------------------------------------------------------------------------
-- Driver-facing switches. No key bindings yet (that's the next step, with the HUD) --
-- these are the entry points those keys will call, and they work from the console now:
--     RR.LightsRender.cycleHead(RR.TrainEntity.active[1])
--------------------------------------------------------------------------
function LightsRender.cycleHead(rec)
    if not (rec and rec.lightState) then return end
    RR.Lights.cycleHead(rec.lightState)
    if rec.lights then rec.lights.acc = LightsRender.MIN_INTERVAL end   -- show it now
    print("[Railroader] headlight: " .. RR.Lights.headLabel(rec.lightState, rec.engine))
end

--------------------------------------------------------------------------
-- setHead(rec, mode): drop the switch straight into one position (RR.Lights.OFF /
-- DIM / BRIGHT). What the cab radial menu calls -- see RR_CabMenu for why a menu must
-- not cycle. The F key keeps cycleHead above.
--------------------------------------------------------------------------
function LightsRender.setHead(rec, mode)
    if not (rec and rec.lightState) then return end
    RR.Lights.setHead(rec.lightState, mode)
    if rec.lights then rec.lights.acc = LightsRender.MIN_INTERVAL end   -- show it now
    print("[Railroader] headlight: " .. RR.Lights.headLabel(rec.lightState, rec.engine))
end

function LightsRender.toggleCab(rec)
    if not (rec and rec.lightState) then return end
    rec.lightState.cab = not rec.lightState.cab
    if rec.lights then rec.lights.acc = LightsRender.MIN_INTERVAL end
    print("[Railroader] cab light: " .. (rec.lightState.cab and "ON" or "off"))
end

RR = RR or {}
RR.LightsRender = LightsRender
print("[Railroader] RR_LightsRender.lua: loaded OK.")

return LightsRender
