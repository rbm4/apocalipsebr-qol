--***********************************************************************
-- Railroader / RR_Spline
-- THE CORE: distance along a route -> world pose (x, y, z + heading).
--
-- This is the simple, testable heart of the mod. Everything else (the entity,
-- the cars, the player seating) is built on top of this one function. It has NO
-- engine dependencies so it can be unit-tested in a bare Lua interpreter.
--
-- Interpolation is currently LINEAR (piecewise straight segments). This means
-- heading is constant within a segment and changes discretely at nodes -- which
-- is exactly right for rails laid as straight runs between hand-placed nodes,
-- and keeps the math trivially verifiable. Catmull-Rom smoothing can replace
-- sampleLinear later without changing the public API or callers.
--***********************************************************************

local Geom      = RR and RR.Geom      or require("Railroader/RR_Geom")
local TrackData = RR and RR.TrackData or require("Railroader/RR_TrackData")

local Spline = {}

--------------------------------------------------------------------------
-- sample: the one function that matters.
--   route : a route built by RR.TrackData.buildRoute
--   d     : distance travelled along the route (any real; normalized inside)
--
-- Returns a pose table:
--   { x, y, z,            -- world position (interpolated)
--     dirX, dirY,         -- unit forward vector in world space
--     heading,            -- forward angle, radians, math convention (0=+X, CCW)
--     seg, t,             -- which segment and fractional position (for debug)
--     distance }          -- the normalized distance actually sampled
--
-- The pose is engine-agnostic. Mapping heading -> PZ's IsoDirections / animation
-- angle happens in the entity adapter (RR_TrainEntity), never here.
--------------------------------------------------------------------------
function Spline.sample(route, d)
    local dn = TrackData.normalizeDistance(route, d)
    local seg, t, a, b = TrackData.locate(route, dn)

    local x = Geom.lerp(a.x, b.x, t)
    local y = Geom.lerp(a.y, b.y, t)
    local z = Geom.lerp(a.z, b.z, t)

    local dirX, dirY = Geom.normalize2d(b.x - a.x, b.y - a.y)
    local heading = Geom.heading2d(a.x, a.y, b.x, b.y)

    return {
        x = x, y = y, z = z,
        dirX = dirX, dirY = dirY,
        heading = heading,
        seg = seg, t = t,
        distance = dn,
    }
end

--------------------------------------------------------------------------
-- sampleExt: sample(), but on an OPEN route a distance outside [0, length] is
-- EXTRAPOLATED along the straight end tangent instead of clamped onto the end node.
-- Needed because a body anchored at its centre has geometry (trucks, collider
-- segments) that hangs past the route data at the buffer stops -- clamping would
-- pile it all up on the last node. Looped routes just wrap, so they use sample().
--------------------------------------------------------------------------
function Spline.sampleExt(route, d)
    local len = route.length or 0
    if route.looped or (d >= 0 and d <= len) then
        return Spline.sample(route, d)
    end
    local edge = (d < 0) and 0 or len
    local over = d - edge                      -- signed overhang past that end
    local p = Spline.sample(route, edge)
    p.x = p.x + over * p.dirX
    p.y = p.y + over * p.dirY
    p.distance = d
    return p
end

--------------------------------------------------------------------------
-- bodyPose: the pose of a RIGID body of wheelbase 2*hw whose two trucks ride the
-- rail at (d - hw) and (d + hw). Position is the midpoint of the trucks; heading is
-- the CHORD between them, not the tangent at d.
--
-- WHY (the corner problem): map rails kink by a hard 45 deg at a node. With a
-- centre-tangent pose the heading is a step function -- a 15-tile loco snaps through
-- 45 deg in a single tick, throwing its nose off the new rails and then its tail off
-- the old ones. The chord makes the heading a CONTINUOUS function of d: it rotates
-- gradually while the front truck is past the kink and the rear one isn't, i.e. over
-- the whole wheelbase of travel, and the body overhangs the corner the way a real
-- long-frame loco does. Residual corner-cutting of the centre is ~hw*sin(theta/2),
-- inherent to any rigid body on a kinked path (a fillet on the polyline would
-- shrink it further -- see docs/ARCHITECTURE.md).
--
-- hw = 0 (or nil) degrades exactly to sample(), so callers without a body keep the
-- old behaviour. Returns the same pose shape as sample(); .distance/.seg/.t refer to
-- the CENTRE (they parameterize travel, and the chord midpoint is not on the rail).
--------------------------------------------------------------------------
function Spline.bodyPose(route, d, hw)
    local centre = Spline.sample(route, d)
    hw = hw or 0
    if hw <= 1e-6 then return centre end

    local dn = centre.distance
    local f = Spline.sampleExt(route, dn + hw)
    local r = Spline.sampleExt(route, dn - hw)

    local dirX, dirY = Geom.normalize2d(f.x - r.x, f.y - r.y)
    -- Degenerate chord (both trucks on one point -- a route shorter than the body, or
    -- a hairpin folding the body onto itself): keep the centre tangent.
    if dirX == 0 and dirY == 0 then
        dirX, dirY = centre.dirX, centre.dirY
    end

    return {
        x = (f.x + r.x) * 0.5,
        y = (f.y + r.y) * 0.5,
        z = (f.z + r.z) * 0.5,
        dirX = dirX, dirY = dirY,
        heading = Geom.heading2d(0, 0, dirX, dirY),
        seg = centre.seg, t = centre.t,
        distance = dn,
    }
end

--------------------------------------------------------------------------
-- sampleCar: convenience for multi-car consists. Each car rides the SAME route
-- at a fixed distance behind the lead: carDistance = leadDistance - offset.
-- (Architectural decision: each car is its own entity trailing by a distance
-- offset.) Offsets are clamped/wrapped by normalizeDistance just like any
-- distance, so a car spawned before the lead has moved simply sits at the route
-- start (open) or wraps onto the tail (looped).
--------------------------------------------------------------------------
function Spline.sampleCar(route, leadDistance, offset)
    return Spline.sample(route, leadDistance - offset)
end

RR = RR or {}
RR.Spline = Spline

return Spline
