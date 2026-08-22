--***********************************************************************
-- Railroader / RR_BodyDebug  -- footprint (габарит) measurement tool
--
-- WHY: the collider (zombies/player can't pass through the loco) must match the
-- loco's REAL in-world footprint, but PZ exposes no model bounding box to Lua and
-- the model-script `scale` is ignored on the animal path. The only scale that
-- applies is the animal render transform: chrXfrm.scale(1.5 * getAnimalSize())
-- (IsoAnimal.java:2642). So the in-world extent is:
--
--     extent_tiles = MESH_BBOX_units * 1.5 * animal:getAnimalSize()
--
-- MESH_BBOX_units is the exported FBX vertex bbox (a fixed property of the current
-- committed mesh). This tool reads getAnimalSize() LIVE, computes the footprint,
-- PRINTS the numbers, and HIGHLIGHTS the covered tiles + the suggested collider
-- capsule so the numbers can be eyeballed against the rendered model. If the
-- highlighted tiles hug the model, the constants are right; if not, we learn the
-- true size and update the constants (or the collider derives from getSize()).
--
-- DRAW METHOD: getWorldMarkers():addGridSquareMarker (a per-tile circle highlight),
-- the same call vanilla debug UIs use (ISTilesPickerDebugUI/ISSpawnHordeUI). NOTE:
-- LineDrawer (zombie.debug) is NOT exposed to Lua -- an earlier attempt drew
-- nothing because of that. Markers are tile-quantised, which is fine: the collider
-- cares which tiles the body covers. Markers render only on the player's own
-- z-level. They are persistent handles (removed explicitly), refreshed every few
-- ticks so a slow-moving loco's overlay keeps up.
--
-- Toggle:  U  (prints once immediately, then a throttled readout + tile overlay)
--***********************************************************************

print("[Railroader] RR_BodyDebug.lua: loading...")

local BodyDebug = {}
BodyDebug.enabled = false
BodyDebug.tick    = 0
BodyDebug.markers = {}     -- live GridSquareMarker handles (for removal)
BodyDebug.lastSig = nil    -- last drawn layout signature (redraw only on change)

--------------------------------------------------------------------------
-- Exported-FBX vertex bounding box of the CURRENT loco mesh (RR_LocoTest.fbx),
-- in Blender/mesh units. Source: docs/ENGINE_NOTES.md ("match the new exported
-- FBX's vertex bbox... X≈3.56, Y≈17.10 long axis, Z≈4.55"). UPDATE THESE if the
-- mesh is re-exported with a different bbox.
--   MESH_LONG = travel/long axis (Y)   -> footprint LENGTH (along facing)
--   MESH_WIDE = across  axis    (X)    -> footprint WIDTH
--   MESH_TALL = vertical axis   (Z)    -> footprint HEIGHT
--------------------------------------------------------------------------
local MESH_LONG = 17.10
local MESH_WIDE = 3.56
local MESH_TALL = 4.55

-- Animal render transform multiplier (IsoAnimal.java:2642). getAnimalSize() is
-- read live; this is the constant part.
local RENDER_MULT = 1.5

-- Per-tile highlight size (radius of the circle sprite drawn on each tile).
local TILE_MARK_SIZE = 0.5

--------------------------------------------------------------------------
-- Compute the footprint of one active loco record. Returns a table or nil.
--------------------------------------------------------------------------
local function measure(e)
    local a = e.animal
    if not a then return nil end

    -- Live render size. getAnimalSize() == getData().getSize() (IsoAnimal:1614),
    -- clamped to [minSize,maxSize]; = 0.7 for rr_loco, but read it, don't assume.
    local size = 0.7
    pcall(function() size = a:getAnimalSize() end)
    local sc = RENDER_MULT * size

    local len = MESH_LONG * sc
    local wid = MESH_WIDE * sc
    local hgt = MESH_TALL * sc

    -- Anchor = the (calibrated) animal position; the recipe puts the bone head at
    -- the mesh centre, so this ~= the model centre.
    local cx, cy, cz = a:getX(), a:getY(), a:getZ()

    -- Facing (long axis). Prefer the spline heading written by RR_TrainEntity; it
    -- is what the model yaw is snapped to. Fall back to forward direction, then N.
    local fx, fy = 0, -1
    local pose = e.lastPose
    if pose and pose.dirX and pose.dirY and (pose.dirX ~= 0 or pose.dirY ~= 0) then
        fx, fy = pose.dirX, pose.dirY
    else
        pcall(function()
            local d = a:getForwardDirection()
            if d then fx, fy = d:getX(), d:getY() end
        end)
    end
    local flen = math.sqrt(fx * fx + fy * fy)
    if flen < 1e-6 then fx, fy = 0, -1; flen = 1 end
    fx, fy = fx / flen, fy / flen
    local rx, ry = -fy, fx      -- right = forward rotated 90 deg

    -- The box is centred on the HULL centreline, not the raw anchor: RR_Body.LAT_BIAS is
    -- the tiles the drawn body sits off its own anchor across the rails. This overlay is
    -- the instrument that bias is calibrated with, so it must show the biased box (and
    -- the obstacle sweep's own gauge edges, below) against the model.
    local bias = (RR.Body and RR.Body.LAT_BIAS) or 0
    local hx, hy = cx + bias * rx, cy + bias * ry

    -- The obstacle sweep's LATERAL half-span (what actually reacts to the world): the
    -- footprint half-width less WIDTH_TRIM, or a hard LOCO_HALFW override.
    local S = RR.ObstacleSweep
    local sweepHalfW = wid * 0.5
    if S then
        sweepHalfW = S.LOCO_HALFW or (wid * 0.5 - (S.WIDTH_TRIM or 0))
        if sweepHalfW < 0.5 then sweepHalfW = 0.5 end
    end

    return {
        size = size, sc = sc, len = len, wid = wid, hgt = hgt,
        cx = cx, cy = cy, cz = cz, fx = fx, fy = fy, rx = rx, ry = ry,
        bias = bias, hx = hx, hy = hy, sweepHalfW = sweepHalfW,
    }
end

--------------------------------------------------------------------------
-- Remove all live tile markers.
--------------------------------------------------------------------------
local function clearMarkers()
    local wm
    pcall(function() wm = getWorldMarkers() end)
    if wm then
        for _, h in ipairs(BodyDebug.markers) do
            pcall(function() wm:removeGridSquareMarker(h) end)
        end
    end
    BodyDebug.markers = {}
end

--------------------------------------------------------------------------
-- Add one tile highlight at (tx,ty,tz) with colour (r,g,b), size s.
--------------------------------------------------------------------------
local function markTile(wm, cell, tx, ty, tz, r, g, b, s)
    local sq
    pcall(function() sq = cell:getGridSquare(tx, ty, tz) end)
    if not sq then return end
    -- doAlpha=FALSE => sprite renders at full alpha immediately. With doAlpha=true
    -- the marker fades IN slowly (fadeSpeed 0.006 from alpha 0); because we re-add
    -- on movement the alpha would keep resetting to ~0 and stay invisible.
    local h
    pcall(function() h = wm:addGridSquareMarker(sq, r, g, b, false, s) end)
    if h then table.insert(BodyDebug.markers, h) end
end

--------------------------------------------------------------------------
-- Highlight every tile whose centre falls inside the oriented footprint
-- rectangle (green), plus the suggested collider segment centres (yellow).
--------------------------------------------------------------------------
local function drawMarkers(m)
    local wm, cell
    pcall(function() wm = getWorldMarkers() end)
    pcall(function() cell = getCell() end)
    if not (wm and cell) then return end

    local hl, hw = m.len * 0.5, m.wid * 0.5
    local tz = math.floor(m.cz + 0.5)

    -- Footprint tiles: scan the AABB, test each tile centre against the oriented
    -- rectangle (project onto forward/right axes). Centred on the HULL centreline
    -- (m.hx/m.hy = anchor + LAT_BIAS across the rails).
    local bound = math.ceil(hl + hw) + 1
    local minx, maxx = math.floor(m.hx) - bound, math.floor(m.hx) + bound
    local miny, maxy = math.floor(m.hy) - bound, math.floor(m.hy) + bound
    for ix = minx, maxx do
        for iy = miny, maxy do
            local dx, dy = (ix + 0.5) - m.hx, (iy + 0.5) - m.hy
            local pf = dx * m.fx + dy * m.fy
            local pr = dx * m.rx + dy * m.ry
            if math.abs(pf) <= hl and math.abs(pr) <= hw then
                markTile(wm, cell, ix, iy, tz, 0.1, 0.9, 0.2, TILE_MARK_SIZE)
            end
        end
    end

    -- OBSTACLE-SWEEP GAUGE (cyan): the two flank lines the sweep actually probes along,
    -- at +/- sweepHalfW from the hull centreline. This is the pair to eyeball for the
    -- "one side reaches further than the other" question: with LAT_BIAS right, the two
    -- cyan lines sit equally far off the drawn body's sides all the way down its length.
    local step = 1.0
    local n = math.floor(m.len / step)
    for i = 0, n do
        local off = -hl + i * step
        for _, lat in ipairs({ m.sweepHalfW, -m.sweepHalfW }) do
            local gx = math.floor(m.hx + off * m.fx + lat * m.rx)
            local gy = math.floor(m.hy + off * m.fy + lat * m.ry)
            markTile(wm, cell, gx, gy, tz, 0.0, 0.8, 1.0, 0.45)
        end
    end

    -- Suggested collider capsule: N segment centres along the length (yellow,
    -- bigger), radius = half-width. This is where collider segments would sit.
    local radius = hw
    local nseg = math.max(2, math.floor(m.len / radius + 0.5))
    for i = 0, nseg - 1 do
        local frac = (nseg == 1) and 0.5 or (i / (nseg - 1))
        local off  = -hl + frac * m.len
        local sx   = math.floor(m.hx + off * m.fx)
        local sy   = math.floor(m.hy + off * m.fy)
        markTile(wm, cell, sx, sy, tz, 1.0, 0.9, 0.0, 0.8)
    end
end

--------------------------------------------------------------------------
-- Print the numbers for one loco (throttled caller decides when).
--------------------------------------------------------------------------
local function report(idx, m)
    local radius = m.wid * 0.5
    local nseg   = math.max(2, math.floor(m.len / radius + 0.5))
    local collisionSize = (m.size > 1e-6) and (radius / m.size) or 0
    print(string.format(
        "[Railroader] FOOTPRINT #%d  size=%.3f  scale=%.3f", idx, m.size, m.sc))
    print(string.format(
        "[Railroader]   length=%.2f tiles  width=%.2f  height=%.2f  (mesh %.2f x %.2f x %.2f units)",
        m.len, m.wid, m.hgt, MESH_LONG, MESH_WIDE, MESH_TALL))
    print(string.format(
        "[Railroader]   centre=(%.2f,%.2f,%.2f)  facing=(%.2f,%.2f)",
        m.cx, m.cy, m.cz, m.fx, m.fy))
    print(string.format(
        "[Railroader]   lateral: LAT_BIAS=%.2f -> hull centre=(%.2f,%.2f)  sweep gauge=+/-%.2f (cyan)  -- nudge RR.Body.LAT_BIAS until both cyan lines clear the drawn body equally",
        m.bias or 0, m.hx or m.cx, m.hy or m.cy, m.sweepHalfW or 0))
    print(string.format(
        "[Railroader]   -> collider capsule: %d segments  radius=%.2f  (segment collisionSize=%.2f at size=%.2f)",
        nseg, radius, collisionSize, m.size))
end

--------------------------------------------------------------------------
-- Per-tick driver (only while enabled): measure all locos, redraw the overlay
-- ONLY when the layout changed (position/facing) so a parked loco draws once and
-- doesn't churn markers; print ~1x/s.
--------------------------------------------------------------------------
local function onTick()
    if not BodyDebug.enabled then return end
    local active = (RR and RR.TrainEntity and RR.TrainEntity.active) or {}
    if #active == 0 then return end

    BodyDebug.tick = BodyDebug.tick + 1
    local doPrint = (BodyDebug.tick % 60) == 0

    local mlist, sig = {}, {}
    for i, e in ipairs(active) do
        if e.animal and not e.animal:isDead() then
            local m = measure(e)
            if m then
                mlist[i] = m
                -- signature = floored tile centre + tenths of facing + the lateral knobs
                -- (so a live RR.Body.LAT_BIAS / WIDTH_TRIM tweak redraws immediately
                -- instead of waiting for the loco to move)
                sig[#sig + 1] = string.format("%d,%d,%.0f,%.0f,%.2f,%.2f",
                    math.floor(m.hx), math.floor(m.hy), m.fx * 10, m.fy * 10,
                    m.bias or 0, m.sweepHalfW or 0)
            end
        end
    end
    local sigStr = table.concat(sig, "|")

    if sigStr ~= BodyDebug.lastSig then
        clearMarkers()
        for _, m in pairs(mlist) do drawMarkers(m) end
        BodyDebug.lastSig = sigStr
    end
    if doPrint then
        for i, m in pairs(mlist) do report(i, m) end
    end
end
Events.OnTick.Add(onTick)

--------------------------------------------------------------------------
-- Toggle on U. Prints once immediately + draws once so you get feedback without
-- waiting for the throttled tick.
--------------------------------------------------------------------------
function BodyDebug.toggle()
    BodyDebug.enabled = not BodyDebug.enabled
    BodyDebug.tick = 0
    BodyDebug.lastSig = nil
    if BodyDebug.enabled then
        local hasWM = false
        pcall(function() hasWM = getWorldMarkers() ~= nil end)
        print("[Railroader] footprint debug ON. tiles=green, sweep gauge flanks=cyan, capsule-centres=yellow. worldMarkers="
              .. tostring(hasWM))
        local active = (RR and RR.TrainEntity and RR.TrainEntity.active) or {}
        if #active == 0 then
            print("[Railroader]   (no loco spawned -- press O first)")
        else
            clearMarkers()
            for i, e in ipairs(active) do
                if e.animal then
                    local m = measure(e)
                    if m then report(i, m); drawMarkers(m) end
                end
            end
        end
    else
        clearMarkers()
        print("[Railroader] footprint debug OFF.")
    end
end

local function onKey(key)
    if not (RR.Debug and RR.Debug.isOn()) then return end   -- field mode: no overlay key
    if key == Keyboard.KEY_U then BodyDebug.toggle() end
end
Events.OnKeyPressed.Add(onKey)

RR = RR or {}
RR.BodyDebug = BodyDebug
print("[Railroader] RR_BodyDebug.lua: loaded OK (U = footprint overlay -- a gated dev key, RR.Debug.set(true)).")

return BodyDebug
