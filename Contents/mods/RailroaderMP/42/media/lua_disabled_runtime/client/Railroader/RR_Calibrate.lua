--***********************************************************************
-- Railroader / RR_Calibrate  -- in-game per-orientation alignment tool
--
-- The loco is anchored at ONE point on the spline; depending on the rail
-- ORIENTATION it can sit a fraction of a tile off the visual rails (a shift that
-- looks "up"/"down" on screen and differs per slope). This debug tool lets you
-- nudge the rendered loco with the numpad until it sits on the rails, storing the
-- correction PER TRAVEL DIRECTION, then dump the calibrated offsets to console so
-- they can be baked into the script.
--
-- WHY PER-DIRECTION (not one local-frame constant): the rail GAUGE differs by
-- orientation (isometric sprites) and there is an isometric render shift that is its
-- own function of heading -- neither follows the "rotate a fixed local vector" law,
-- so a single constant cannot fit them. Rails are strictly 8-way, so a table of <= 8
-- entries is COMPLETE (every possible segment direction has one). Authoring runs
-- along the camera-NEAR rail, so each direction's offset just seats the near wheel on
-- the near rail; opposite travel directions get their own row (the shift flips with
-- facing).
--
-- Numpad keys (while a loco is spawned; O to spawn, G to drive between segments).
-- Nudge is in the LOCO's frame so alignment on a diagonal is unambiguous:
--   4 / 6  -> ACROSS the rail (left / right of travel) -- the only axis that centres
--   8 / 2  -> ALONG the rail  (forward / back)         -- does NOT change centring
--   7 / 1  -> +Z / -Z (height)       5 -> DUMP all offsets to console
--   0      -> reset the CURRENT direction to zero        + / - -> step size
--
-- offsetFor(dirX,dirY) is read by RR_TrainEntity.applyPose every tick; it returns
-- the offset of the nearest-matching calibrated direction (0,0,0 if none), so an
-- empty table = no effect until you calibrate.
--***********************************************************************

RR = RR or {}
local Calib = {}
RR.Calib = Calib

Calib.enabled = true
Calib.step    = 0.05
-- Baked calibration: one entry per rail direction. dx,dy = unit travel vector;
-- ox,oy,oz = world offset to add. Fill via the numpad tool + NUMPAD5 dump.
-- THE 2026-07-29 PASS WAS A UNIFORM OVERSHOOT -- read this before re-tuning anything.
-- Three cardinal rows were re-measured twice, in different sessions, at different places.
-- Every one went ~0.15 tile too far NORTH on 07-29 and came back on 07-30:
--
--     row   2026-07-20    2026-07-29        2026-07-30 (current)   cell rebuilt by 42.20?
--     N     -0.450        -0.600  seg 47    -0.500  seg 74         yes (38_31)
--     E     -0.450        -0.650  seg 50    -0.500  seg 50         YES (39_31)
--     W     -0.400        -0.550  seg 35    -0.400  seg 35         NO  (38_34, byte-identical)
--
-- B42.20 stable landed mid-day 2026-07-29 (world_*.lotpack mtime 18:35) and rebuilt 33 of
-- the 73 cells our routes pass through -- so for E and N the 07-20 numbers are stale by
-- definition, measured on a map that no longer exists. But the W row settles it: cell
-- 38_34 is byte-identical across the update, and W still swung -0.400 -> -0.550 -> -0.400.
-- The 07-29 calibration session ran at 20:27, i.e. AFTER the 18:35 rebuild, so its -0.650
-- and the next day's -0.500 are BOTH new-map readings and still disagree by 0.15.
-- => the map change is real but is NOT what moved these numbers. Something at SESSION
-- level shifted how far off the model looked -- prime suspect ZOOM, because in isometric
-- PZ all four cardinal offsets reduce to the same screen-VERTICAL correction (world
-- (0,-0.5) and (-0.5,0) raise the model by the same screen dy), so a fixed pixel-space
-- model offset would need a different WORLD compensation per zoom level, identically for
-- every direction. UNVERIFIED -- test by parking and changing zoom.
-- Until it is settled: re-tune at ONE reference zoom, and distrust a pass that moves
-- every row the same way. Separately, the rebuilt cells need a geometry re-check (the
-- authored polyline, not this table): see docs/ROADMAP.md.
Calib.entries = {
    { dx =  0.0000, dy = -1.0000, ox = -0.500, oy =  0.000, oz = 0.000 },  -- N  (2026-07-29: re-tuned from zero at seg 74; the old +0.150 along-rail term is gone -- it never centred anything)
    { dx =  0.7071, dy = -0.7071, ox =  0.036, oy =  0.036, oz = 0.000 },  -- NE (2026-07-29: within ONE nudge of zero -- walked +0.036/0/+0.036 and back; treat as "no measurable offset")
    { dx =  1.0000, dy =  0.0000, ox =  0.000, oy = -0.500, oz = 0.000 },  -- E  (2026-07-30 @x=11772, seg 50)
    { dx = -1.0000, dy =  0.0000, ox =  0.000, oy = -0.400, oz = 0.000 },  -- W  (2026-07-30 @x=11586, seg 35 -- back to the original value)
    { dx =  0.0000, dy =  1.0000, ox = -0.450, oy =  0.000, oz = 0.000 },  -- S
    { dx = -0.7071, dy =  0.7071, ox =  0.106, oy =  0.106, oz = 0.000 },  -- SW (small perpendicular ~0.15 -- trusted)
    { dx = -0.7071, dy = -0.7071, ox =  0.530, oy = -0.530, oz = 0.000 },  -- NW (stationary; ~0.53 perp, matches SE ~0.56 -- both screen-vertical diagonals take the larger isometric offset)
    { dx =  0.7071, dy =  0.7071, ox =  0.567, oy = -0.565, oz = 0.000 },  -- SE (~0.57 perp; matches NW ~0.53 -- both screen-vertical). Earlier opposite reading was a mis-measured segment (right rail), since fixed.
}

local function normalize(x, y)
    local l = math.sqrt(x * x + y * y)
    if l < 1e-6 then return 0, 0 end
    return x / l, y / l
end

local function bestEntry(dx, dy)
    local best, bestDot = nil, -2
    for _, e in ipairs(Calib.entries) do
        local dot = e.dx * dx + e.dy * dy
        if dot > bestDot then bestDot, best = dot, e end
    end
    return best, bestDot
end

-- Read by applyPose. Returns world (ox, oy, oz) offset for a travel direction.
-- The TWO calibrated entries nearest the heading (by dot), nearest first.
local function twoNearest(dx, dy)
    local e1, d1, e2, d2 = nil, -2, nil, -2
    for _, e in ipairs(Calib.entries) do
        local dot = e.dx * dx + e.dy * dy
        if dot > d1 then
            e2, d2 = e1, d1
            e1, d1 = e, dot
        elseif dot > d2 then
            e2, d2 = e, dot
        end
    end
    return e1, d1, e2, d2
end

-- Read by applyPose. Returns the world (ox,oy,oz) render offset for a travel
-- direction. BETWEEN two calibrated directions (i.e. mid-turn) it INTERPOLATES the
-- two nearest entries by angle, so the offset transitions smoothly instead of
-- snapping at the 22.5-deg boundary (that snap was the sideways jump on turns). On a
-- calibrated direction (a straight) it returns that entry exactly.
function Calib.offsetFor(dirX, dirY)
    if not Calib.enabled or #Calib.entries == 0 then return 0, 0, 0 end
    local dx, dy = normalize(dirX, dirY)
    local e1, d1, e2, d2 = twoNearest(dx, dy)
    -- Nearest calibrated direction must be within ~45 deg, else no data -> 0
    -- (reversing / off-axis motion doesn't inherit a mismatched offset).
    if not e1 or d1 < 0.7 then return 0, 0, 0 end
    -- On (or almost on) a calibrated direction, or no usable neighbour: use it as-is.
    if d1 > 0.9995 or not e2 or d2 < 0.7 then
        return e1.ox, e1.oy, e1.oz or 0
    end
    -- Mid-turn: blend the two nearest by angular proximity (closer -> heavier).
    local a1 = math.acos(d1 > 1 and 1 or d1)   -- angle to e1 (rad)
    local a2 = math.acos(d2 > 1 and 1 or d2)   -- angle to e2
    local tot = a1 + a2
    if tot < 1e-6 then return e1.ox, e1.oy, e1.oz or 0 end
    local w1, w2 = a2 / tot, a1 / tot           -- weights sum to 1
    return w1 * e1.ox + w2 * e2.ox,
           w1 * e1.oy + w2 * e2.oy,
           w1 * (e1.oz or 0) + w2 * (e2.oz or 0)
end

-- Current loco travel direction (from the first active entity's last pose).
local function currentDir()
    local T = RR.TrainEntity
    local e = T and T.active and T.active[1]
    if e and e.lastPose then
        local dx, dy = normalize(e.lastPose.dirX or 0, e.lastPose.dirY or 0)
        if dx ~= 0 or dy ~= 0 then return dx, dy end
    end
    return nil
end

-- Get or create the entry matching the current direction (tight tolerance so each
-- distinct rail heading gets its own row).
local function editEntry()
    local dx, dy = currentDir()
    if not dx then return nil end
    local e, dot = bestEntry(dx, dy)
    if e and dot > 0.9995 then return e end
    e = { dx = dx, dy = dy, ox = 0, oy = 0, oz = 0 }
    table.insert(Calib.entries, e)
    return e
end

-- Where the loco stands right now (for the log, so two same-direction segments that
-- want different offsets can be told apart afterwards). x,y = rendered pose centre;
-- seg/dist index the CURRENT built route; route = which route/branch it is on.
local function currentPos()
    local T = RR.TrainEntity
    local e = T and T.active and T.active[1]
    if not e then return nil end
    local lp = e.lastPose
    local x, y
    if e.animal then pcall(function() x, y = e.animal:getX(), e.animal:getY() end) end
    return {
        x = (lp and lp.x) or x, y = (lp and lp.y) or y,
        seg = lp and lp.seg, dist = lp and lp.distance,
        route = e.routeId or e.baseId,
    }
end

local function report(e)
    local p = currentPos()
    if p and p.x then
        print(string.format(
            "[Railroader] CALIB dir=(%.3f,%.3f) off=(%.3f,%.3f,%.3f) @pos=(%.2f,%.2f) seg=%s dist=%.1f route=%s step=%.3f",
            e.dx, e.dy, e.ox, e.oy, e.oz, p.x, p.y, tostring(p.seg), p.dist or -1,
            tostring(p.route), Calib.step))
    else
        print(string.format("[Railroader] CALIB dir=(%.3f,%.3f) off=(%.3f,%.3f,%.3f) step=%.3f (no loco pos)",
              e.dx, e.dy, e.ox, e.oy, e.oz, Calib.step))
    end
end

-- Nudge in the LOCO frame: lat = across the rail (left +), fwd = along it, dz = height.
-- Converted to the stored world (ox,oy) via the current heading, so on a diagonal ONE
-- pair moves the loco perpendicular (the only thing that centres it) and the other just
-- slides it along the rail -- no more "both pairs align it" ambiguity.
local function nudge(lat, fwd, dz)
    local dx, dy = currentDir()
    if not dx then print("[Railroader] CALIB: no active loco (press O first)"); return end
    local e = editEntry()
    if not e then return end
    e.ox = e.ox + (fwd * dx + lat * (-dy)) * Calib.step
    e.oy = e.oy + (fwd * dy + lat * ( dx)) * Calib.step
    e.oz = e.oz + dz * Calib.step
    report(e)
end

-- Reset the CURRENT direction's offset to zero (all axes). Other directions untouched.
local function resetCurrent()
    local e = editEntry()
    if not e then print("[Railroader] CALIB: no active loco (press O first)"); return end
    e.ox, e.oy, e.oz = 0, 0, 0
    print("[Railroader] CALIB: current direction reset to 0")
    report(e)
end

local function dump()
    print("[Railroader] ===== CALIB DUMP (paste into RR_Calibrate.lua  Calib.entries) =====")
    if #Calib.entries == 0 then print("[Railroader]   (no entries yet)") end
    for _, e in ipairs(Calib.entries) do
        print(string.format("[Railroader]   { dx=%.4f, dy=%.4f, ox=%.3f, oy=%.3f, oz=%.3f },",
              e.dx, e.dy, e.ox, e.oy, e.oz))
    end
    print("[Railroader] =====================================================================")
end

local function onKey(key)
    -- NOTE the two different switches. `Calib.enabled` governs the BAKED offsets below --
    -- live geometry every pose (model, collider, crush, obstacle sweep) is built on, so it
    -- stays TRUE in a shipping build. RR.Debug governs only the numpad NUDGER, which must
    -- never answer a stray keypress in the field (numpad 8/2/4/6 would silently walk the
    -- locomotive off its own rails).
    if not (RR.Debug and RR.Debug.isOn()) then return end
    if not Calib.enabled then return end
    local K = Keyboard
    if     key == K.KEY_NUMPAD8 then nudge( 0,  1,  0)   -- along rail: forward
    elseif key == K.KEY_NUMPAD2 then nudge( 0, -1,  0)   -- along rail: back
    elseif key == K.KEY_NUMPAD4 then nudge( 1,  0,  0)   -- across rail: left of travel
    elseif key == K.KEY_NUMPAD6 then nudge(-1,  0,  0)   -- across rail: right of travel
    elseif key == K.KEY_NUMPAD7 then nudge( 0,  0,  1)   -- +z
    elseif key == K.KEY_NUMPAD1 then nudge( 0,  0, -1)   -- -z
    elseif key == K.KEY_NUMPAD5 then dump()
    elseif key == K.KEY_NUMPAD0 then resetCurrent()
    elseif key == K.KEY_ADD      then Calib.step = Calib.step * 2; print("[Railroader] CALIB step=" .. Calib.step)
    elseif key == K.KEY_SUBTRACT then Calib.step = Calib.step / 2; print("[Railroader] CALIB step=" .. Calib.step)
    end
end

Events.OnKeyStartPressed.Add(onKey)

print("[Railroader] calibrate: baked offsets ACTIVE; the numpad nudger is a gated dev tool (RR.Debug.set(true) -- 4/6=across-rail 8/2=along-rail 7/1=Z 5=dump 0=reset +/-=step)")
