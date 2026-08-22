--***********************************************************************
-- Railroader / RR_Body  -- loco footprint & collider-segment geometry (PURE)
--
-- Engine-free geometry shared by the collider (RR_Collider) and the future
-- "crush zombies" sweep. Given only the loco's render size it yields:
--   * extents(size)         -> in-world length/width/height (tiles)
--   * segmentOffsets(size)  -> signed distances along the travel axis at which to
--                              place collision segments so their SEG_RADIUS circles
--                              overlap into a capsule covering the whole body.
--
-- WHY these numbers (verified, see docs/ENGINE_NOTES.md):
--   The model-script `scale` is ignored on the animal path; the ONLY scale that
--   applies is the animal render transform 1.5 * getAnimalSize()
--   (IsoAnimal.java:2642). So in-world extent = MESH_bbox * 1.5 * size. The MESH
--   bbox is the exported FBX vertex bbox of RR_LocoTest.fbx. LIVE size = 0.7
--   (loco.minSize = maxSize = 0.7 pin getAnimalSize there; the older "0.604" once
--   in these docs is STALE), so the footprint is 17.96 x 3.74 tiles. NOTE the mesh
--   bbox OVERHANGS the visible hull (~15 x 3, the old J-capture): ~1.5 empty tiles
--   per END and ~0.6 per SIDE, which the obstacle sweep trims back to the drawn
--   hull with NOSE_TRIM / WIDTH_TRIM. UPDATE MESH if the mesh changes.
--
-- No engine calls here (Kahlua-safe, unit-testable). Callers read size/pose off
-- the animal and feed the results into the spline.
--***********************************************************************

RR = RR or {}

local Body = {}

-- Exported-FBX vertex bbox of RR_LocoTest.fbx, in mesh units.
Body.MESH = { long = 17.10, wide = 3.56, tall = 4.55 }   -- long=Y(travel) wide=X tall=Z
Body.RENDER_MULT = 1.5                                    -- IsoAnimal.java:2642

-- TRUCKS (bogies). A locomotive is a RIGID body carried by two trucks, so its pose
-- is the CHORD between two points on the rail, not the tangent at its centre. This
-- is what makes corners look right: our routes follow map rails, which kink by a
-- hard 45 deg at a node, and a centre-tangent pose snaps the whole 15-tile body
-- through that angle in one tick (nose swings off the rails, then the tail does).
-- With a chord the yaw is spread over the wheelbase (the front truck is already
-- round the corner while the rear one isn't), and the body overhangs the curve
-- exactly like a real loco. Spacing = truck-centre to truck-centre as a fraction of
-- body length (EMD GP7: 31 ft centres on a ~50 ft frame => ~0.61).
Body.TRUCK_SPACING_FRAC = 0.61

-- Per-segment collision radius (tiles) = half the loco width, so a single row of
-- circles forms a capsule as wide as the body. width = collisionSize * size, so
-- KEEP IN SYNC with rr_collider collisionSize in RR_ColliderDefinitions.lua
-- (that type is size 1.0, so collisionSize must equal SEG_RADIUS).
Body.SEG_RADIUS  = 1.6
Body.SEG_SPACING = 2.2               -- along-body centre spacing (< 2R => overlap)
Body.MAX_SEGMENTS = 16               -- safety cap (per row)

-- Lateral rows across the WIDTH. A single centred row of radius-1.6 circles already
-- spans the full 3.2-tile width IF centred, but in practice the anchor sits slightly
-- off-centre; two rows straddling the centreline guarantee both flanks are covered
-- (a zombie bit the driver through the far side with one row). Rows are placed at
-- +/- ROW_LAT_FACTOR * width from the centreline.
Body.ROWS = 2
Body.ROW_LAT_FACTOR = 0.25           -- rows at +/- quarter-width

-- LATERAL CENTRE BIAS (tiles, + = RIGHT of travel). THE ONE PLACE the body box is
-- re-centred across its width.
-- WHY: the animal ANCHOR (what every pose is built on) is not exactly the drawn hull's
-- centreline -- the mesh's own lateral centre sits a little off the bone, and the animal
-- renders with an isometric shift the RR_Calibrate table corrects per direction. The box
-- itself is symmetric (+/- wid/2 about the anchor), so any anchor-vs-hull offset shows up
-- as a габарит that is NARROWER on one side of the drawn loco than the other -- owner
-- in-game 2026-07-27: "по правому борту габарит немного меньше, чем по левому". Shifting
-- the CENTRE (rather than widening one flank) keeps the box the true body width and just
-- puts it back on the hull.
-- Applied by Body.toLocal (=> contains/crush), Body.rowLaterals (=> collider segments),
-- RR_Collider.ejectIntruders, RR_ObstacleSweep's lateral probes and the U overlay -- so
-- every consumer of "where the loco is, across the rails" agrees.
-- CALIBRATE in-game (live: `RR.Body.LAT_BIAS = 0.25` in the console, then U):
--   press U -> the overlay draws the box CENTRED ON THE HULL plus the sweep's gauge edges
--   (cyan) along both flanks. Nudge LAT_BIAS until the two cyan lines sit equally far off
--   the drawn body sides. + moves the box RIGHT of travel, - moves it LEFT.
-- Bake the settled value here. 0 = box centred on the anchor (pre-2026-07-27 behaviour).
Body.LAT_BIAS = 0.0

-- ZOMBIE keep-out buffer (tiles) added AROUND the eject box (RR_Collider /
-- RR_ServerCollision.ejectTarget), on top of the mesh bbox + EJECT_MARGIN.
-- WHY: a zombie whose CENTRE only clears the hull edge can still lunge into the
-- cab and bite a seated player (owner: "坐在车上有可能被僵尸攻击到"). The buffer
-- pushes zombie centres further out on every side. ZOMBIES ONLY -- the player
-- wall stays hull-exact, so the boarding/fuelling standoffs don't change.
-- Tune in-game: bigger = safer seats (and emptier trackside).
Body.REPEL_EXTRA = 0.5

--------------------------------------------------------------------------
-- In-world extents (tiles) for a given render size.
--------------------------------------------------------------------------
function Body.extents(size)
    local sc = Body.RENDER_MULT * (size or 0.7)
    return Body.MESH.long * sc, Body.MESH.wide * sc, Body.MESH.tall * sc
end

--------------------------------------------------------------------------
-- Half the truck-centre spacing (tiles): the distance from the body centre to each
-- truck. Feed it to RR.Spline.bodyPose as the chord half-length. 0 would degrade
-- the pose back to the old centre-tangent snap.
--------------------------------------------------------------------------
function Body.halfWheelbase(size)
    local len = Body.extents(size)
    return len * Body.TRUCK_SPACING_FRAC * 0.5
end

--------------------------------------------------------------------------
-- Signed distances (tiles, centre-relative, - = toward the tail) at which to put
-- collider segments. End segments are inset by SEG_RADIUS so the capsule's round
-- caps sit at the nose/tail rather than poking past them. Returns { 0 } for a body
-- too short to need more than one circle.
--------------------------------------------------------------------------
function Body.segmentOffsets(size)
    local len  = Body.extents(size)
    local half = len * 0.5
    local usable = len - 2 * Body.SEG_RADIUS         -- span between inset end caps
    if usable <= 0 then return { 0 } end

    local n = 1 + math.floor(usable / Body.SEG_SPACING + 0.5)
    if n < 2 then return { 0 } end
    if n > Body.MAX_SEGMENTS then n = Body.MAX_SEGMENTS end

    local first = -half + Body.SEG_RADIUS
    local step  = usable / (n - 1)
    local out = {}
    for i = 0, n - 1 do out[#out + 1] = first + i * step end
    return out
end

--------------------------------------------------------------------------
-- SEAT: where the driver rides, as body-local offsets from the pose CENTRE.
-- Without this the rider pins to the geometric centre of the ~15-tile body, which
-- reads as "standing on the running board mid-hood". The GP7 cab sits toward one
-- end (behind the short hood) with a raised floor; these place the driver there.
-- All are fractions of the matching extent, so the seat scales with render size.
--   SEAT_ALONG_FRAC : fraction of body LENGTH, + = toward the facing/nose end.
--                     Flip the SIGN if the driver ends up on the long-hood end.
--   SEAT_LAT_FRAC   : fraction of body WIDTH, + = right of travel (engineer's side).
--   SEAT_LIFT_FRAC  : fraction of body HEIGHT to raise the driver to the cab floor.
--------------------------------------------------------------------------
-- An off-centre seat would normally expose an engine culling bug (the loco mesh
-- fades out when the driver faces AWAY from the animal's origin -- inherited animal
-- visibility culling, IsoGameCharacter.TestIfSeen judges the whole body by its origin
-- point). Defeated by pinning the loco's render alpha to 1 each tick in
-- RR_TrainEntity.onTick (setAlphaAndTarget), so the seat is free to move.
Body.SEAT_ALONG_FRAC = 0.22    -- ~cab centre: a bit over a fifth of the length off centre
Body.SEAT_LAT_FRAC   = 0.0     -- centred across the width
Body.SEAT_LIFT_FRAC  = 0.0     -- no height lift by default

--------------------------------------------------------------------------
-- Body-local seat offset (tiles) for a render size: along (+ toward facing/nose),
-- lateral (+ right of travel), lift (+ up). Callers turn along/lateral into world
-- coords via the spline pose's forward + right vectors.
--------------------------------------------------------------------------
function Body.seatOffset(size)
    local len, wid, tall = Body.extents(size)
    return len  * (Body.SEAT_ALONG_FRAC or 0),
           wid  * (Body.SEAT_LAT_FRAC   or 0),
           tall * (Body.SEAT_LIFT_FRAC  or 0)
end

--------------------------------------------------------------------------
-- Passenger seat offsets (tiles, body-local) ADDED on top of the cab seat.
-- Shared by the client (rider render pin) and the server (authoritative seat
-- pin in RR_ServerTrain) so both sides place bodies at the identical point.
--------------------------------------------------------------------------
Body.PASSENGER_SEATS = {
    { u = -1.2, w = -0.55 }, { u = -1.2, w = 0.55 },
    { u = -2.3, w = -0.55 }, { u = -2.3, w = 0.55 },
    { u = -3.4, w = 0.0 },
}

--------------------------------------------------------------------------
-- seatWorld(pose, size, seat) -> x, y, z  (PURE)
-- The world point a body sits at for a loco pose (body CENTRE, chord heading).
-- `seat` 0 = the cab (driver), 1..n = passenger seats. The body-local offset is
-- turned into world coords with the pose's forward + right vectors (right =
-- forward rotated -90, matching RR_Collider / Body.toLocal). The pose direction
-- is fixed to the route (NOT flipped by the reverser -- see RR_LightsRender
-- leadSign), so the cab end is stable when reversing.
--------------------------------------------------------------------------
function Body.seatWorld(pose, size, seat)
    pose = pose or {}
    local u, w, lift = Body.seatOffset(size or 0.7)
    local passenger = (seat or 0) > 0 and (Body.PASSENGER_SEATS[seat] or { u = 0, w = 0 }) or nil
    if passenger then
        u = u + passenger.u
        w = w + passenger.w
    end
    local fx, fy = pose.dirX or 0, pose.dirY or 0
    local rx, ry = -fy, fx                       -- right of travel
    return (pose.x or 0) + u * fx + w * rx,
           (pose.y or 0) + u * fy + w * ry,
           (pose.z or 0) + (lift or 0)
end

--------------------------------------------------------------------------
-- Lateral row offsets (tiles, centre-relative, + = right of travel) across the
-- width. { 0 } for a single row; symmetric rows straddling the centreline for >1.
--------------------------------------------------------------------------
function Body.rowLaterals(size)
    local b = Body.LAT_BIAS or 0                 -- rows straddle the HULL centreline
    local rows = Body.ROWS or 1
    if rows <= 1 then return { b } end
    local _, wid = Body.extents(size)
    local lat = wid * (Body.ROW_LAT_FACTOR or 0.25)
    if rows == 2 then return { b - lat, b + lat } end
    -- general: spread `rows` evenly across [-lat, +lat]
    local out = {}
    for i = 0, rows - 1 do out[#out + 1] = b - lat + (2 * lat) * i / (rows - 1) end
    return out
end

--------------------------------------------------------------------------
-- CRUSH (Task 1.H): pure geometry + speed policy for running zombies over. The
-- engine sweep (client/RR_Crush) reads size/pose/speed off the loco, calls these
-- to decide who is under the body and what happens to them, then applies the
-- engine effect (knockDown / Kill). No engine calls here -> unit-tested.
--
-- Speed tiers (m/s, |v|), see docs/CRUSH_DESIGN.md:
--   < V_MIN   : nothing (the collider's separate() shove already handles a parked
--               or crawling loco -- a standstill must NOT be lethal).
--   V_MIN..V_KILL : knockDown (staggered/floored, chance to become a crawler).
--   V_KILL..V_GORE : lethal (Kill, credited to the driver).
--   >= V_GORE : lethal + gory (Kill with bGory -- extra blood/gibs at speed).
-- A body that is ALREADY DOWN gets its own, much harsher rule (`downed` argument
-- to crushEffect): it lies UNDER the wheels, not against the frame -- below V_KILL
-- the standing tier only floors a zombie, and a floored one used to ride under the
-- whole body and then STAND UP INSIDE the hull. Down + any rolling wheel = dead
-- (always the gory kill, exactly like vanilla's car: IsoGameCharacter
-- onHitByVehicleApplyDamage separates isProne and finishes with the one-argument
-- gory Kill); only a loco actually standing still (< V_ROLL) is harmless to it.
-- Ordered against the vanilla vehicle-hit shape (IsoZombie.postHitByVehicleUpdate-
-- Stance): stagger from ~2, knockdown from ~3.5 -- we sit a touch lower so the loco
-- reads as heavier/deadlier than a car.
--------------------------------------------------------------------------
Body.CRUSH = {
    V_ROLL = 0.2,    -- below this the loco counts as STANDING STILL (nothing rolls over)
    V_MIN  = 1.0,    -- below this: no crush of a STANDING body (the loco is just a wall)
    V_KILL = 4.0,    -- at/above this |v|: a standing body inside the footprint dies
    V_GORE = 8.0,    -- at/above this |v|: the kill is gory (bGory)
}

--------------------------------------------------------------------------
-- World point -> body-local coords along the loco's facing. Returns:
--   u = longitudinal (+ toward the nose / facing dir), w = lateral (+ right).
-- pose.dirX/dirY is the unit spline tangent (see RR_Spline); the right vector is
-- forward rotated -90 deg, matching RR_Collider.pinSegment.
-- `w` is measured from the HULL centreline, i.e. the anchor shifted by LAT_BIAS, so
-- |w| <= wid/2 is symmetric about the DRAWN body on both flanks (see LAT_BIAS).
--------------------------------------------------------------------------
function Body.toLocal(pose, x, y)
    local fx, fy = pose.dirX or 0, pose.dirY or -1
    local dx, dy = x - pose.x, y - pose.y
    local u = dx * fx + dy * fy
    local w = dx * (-fy) + dy * fx - (Body.LAT_BIAS or 0)
    return u, w
end

--------------------------------------------------------------------------
-- Is world point (x,y) inside the loco footprint box for this render size?
-- The footprint is the mesh bbox (extents), treated as an oriented rectangle --
-- ample for a train and cheaper/steadier than a capsule. Returns inside, u, w.
--------------------------------------------------------------------------
function Body.contains(pose, size, x, y)
    local len, wid = Body.extents(size)
    local u, w = Body.toLocal(pose, x, y)
    local inside = math.abs(u) <= len * 0.5 and math.abs(w) <= wid * 0.5
    return inside, u, w
end

--------------------------------------------------------------------------
-- DRAWN HULL vs mesh bbox. Body.extents is the exported FBX vertex bbox, which
-- OVERHANGS the visible loco (~1.5 empty tiles per END, ~0.3 per SIDE -- U-overlay
-- confirmed 2026-07-27). The obstacle sweep already trims it back with its own
-- NOSE_TRIM/WIDTH_TRIM knobs; these are the SAME numbers, owned here so anything
-- that has to answer "how far is the player from the loco's SIDE?" (the E-key
-- boarding reach) keys to the body the player can actually see rather than to a
-- box with a tile and a half of air on each end.
-- Keep in sync with RR_ObstacleSweep.NOSE_TRIM / .WIDTH_TRIM.
--------------------------------------------------------------------------
Body.END_TRIM  = 1.5      -- tiles of bbox air per END (nose/tail)
Body.SIDE_TRIM = 0.3      -- tiles of bbox air per SIDE (grab-irons/steps)

--------------------------------------------------------------------------
-- Extents of the DRAWN hull (tiles): the mesh bbox less the trims, floored so a
-- silly trim can never invert the box.
--------------------------------------------------------------------------
function Body.hullExtents(size)
    local len, wid, tall = Body.extents(size)
    len = len - 2 * (Body.END_TRIM  or 0)
    wid = wid - 2 * (Body.SIDE_TRIM or 0)
    if len < 0.1 then len = 0.1 end
    if wid < 0.1 then wid = 0.1 end
    return len, wid, tall
end

--------------------------------------------------------------------------
-- hullDistance(pose, size, x, y) -> dist, u, w
-- Distance (tiles) from a world point to the NEAREST POINT of the drawn hull,
-- treated as an oriented rectangle (0 when the point is inside/on it). This is the
-- "how close am I standing to the loco" measure: distance to the CENTRE is useless
-- for a 15-tile body -- the same 8 tiles is arm's length at the cab door and two
-- car-lengths off the nose.
-- Standard point-to-box distance in body-local coords (RR_Body.toLocal, so LAT_BIAS
-- applies and the flanks are symmetric about the drawn hull).
--------------------------------------------------------------------------
function Body.hullDistance(pose, size, x, y)
    local len, wid = Body.hullExtents(size)
    local u, w = Body.toLocal(pose, x, y)
    local du = math.abs(u) - len * 0.5
    local dw = math.abs(w) - wid * 0.5
    if du < 0 then du = 0 end
    if dw < 0 then dw = 0 end
    return math.sqrt(du * du + dw * dw), u, w
end

--------------------------------------------------------------------------
-- Speed policy: what happens to a body inside the footprint at travel speed |v|.
-- Returns "none" | "knockdown" | "kill" | "gib" (gib = kill with gore).
-- `downed` = the body is already on the ground (floored / crawler / getting up), so
-- it is under the wheels rather than against the frame: no knockdown tier, always
-- the gory kill, and the only speed it survives is a loco that is not moving at all.
-- Called with one argument it is the original standing-body policy, unchanged.
--------------------------------------------------------------------------
function Body.crushEffect(absSpeed, downed)
    local C = Body.CRUSH
    if downed then
        if absSpeed < C.V_ROLL then return "none" end
        return "gib"          -- under the wheels: always the gory kill, as vanilla's car does
    end
    if absSpeed < C.V_MIN  then return "none" end
    if absSpeed < C.V_KILL then return "knockdown" end
    if absSpeed < C.V_GORE then return "kill" end
    return "gib"
end

--------------------------------------------------------------------------
-- Full collider layout: a grid of { along, lateral } offsets (tiles) relative to
-- the body centre. `along` runs down the travel axis, `lateral` across it. Callers
-- turn each into a world point via the spline pose (along) + right-vector (lateral).
--------------------------------------------------------------------------
function Body.segmentGrid(size)
    local along = Body.segmentOffsets(size)
    local lats  = Body.rowLaterals(size)
    local grid = {}
    for _, a in ipairs(along) do
        for _, l in ipairs(lats) do
            grid[#grid + 1] = { along = a, lateral = l }
        end
    end
    return grid
end

--------------------------------------------------------------------------
-- smoothFacing(rec, dirX, dirY, dt) -> sx, sy, changed
-- Ultra-low-speed turning-stutter fix: the visible yaw is the AnimationPlayer
-- angle, snapped every tick by setTargetAndCurrentDirection. At a crawl the
-- target heading barely moves, but re-snapping it every tick re-triggers the
-- (cow-derived, clip-less) animation state machine and reads as stutter; at
-- speed the motion masks it. We exponential-smooth the direction (FACING_TAU)
-- and only hand the engine a NEW angle once it has moved >= FACING_DEADBAND,
-- so the yaw GLIDES through corners at any speed. Physics never sees this --
-- callers keep using the raw spline pose for collision/crush/rider pinning.
--------------------------------------------------------------------------
local FACING_TAU      = 0.04    -- s: smoothing time constant (~25 Hz knee)
local FACING_DEADBAND = 0.003   -- rad (~0.17 deg): below this, skip the snap

function Body.smoothFacing(rec, dirX, dirY, dt)
    local sx, sy = rec._visDirX, rec._visDirY
    if not (sx and sy) then
        rec._visDirX, rec._visDirY = dirX or 0, dirY or -1
        rec._appliedDirX, rec._appliedDirY = rec._visDirX, rec._visDirY
        return rec._visDirX, rec._visDirY, true
    end
    local k = 1 - math.exp(-(dt or (1 / 60)) / FACING_TAU)
    if k > 1 then k = 1 end
    local nx = sx + ((dirX or 0) - sx) * k
    local ny = sy + ((dirY or -1) - sy) * k
    local len = math.sqrt(nx * nx + ny * ny)
    if len > 1e-6 then nx, ny = nx / len, ny / len
    else nx, ny = dirX or 0, dirY or -1 end
    rec._visDirX, rec._visDirY = nx, ny
    -- deadband: |cross| of unit vectors == |sin(delta)| ~= delta for small angles
    local ax, ay = rec._appliedDirX, rec._appliedDirY
    if ax and ay and (ax * ny - ay * nx) ^ 2 <= FACING_DEADBAND * FACING_DEADBAND then
        return nx, ny, false
    end
    rec._appliedDirX, rec._appliedDirY = nx, ny
    return nx, ny, true
end

RR.Body = Body
return Body
