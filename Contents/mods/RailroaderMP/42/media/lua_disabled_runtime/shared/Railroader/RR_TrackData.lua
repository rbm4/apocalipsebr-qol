--***********************************************************************
-- Railroader / RR_TrackData
-- Route data model + distance parameterization.
--
-- Architectural decision (do not revisit): the TRACK IS DATA, not map tiles.
-- A route is a polyline of nodes with world coords (x, y, z) laid by hand along
-- existing rails. Motion is 1D: a scalar "distance travelled along the route".
--
-- This module owns the data structures and the precomputed arc-length table that
-- lets us turn a distance into a (segment, t) pair in O(log n). The actual
-- distance -> pose sampling lives in RR_Spline so the interpolation method can be
-- swapped (linear now, Catmull-Rom later) without touching the data model.
--
-- SCOPE: a single polyline. The graph layer (switches/branches, named stops) is
-- designed-for but not built here yet -- see TrackGraph notes at the bottom.
--***********************************************************************

local Geom = RR and RR.Geom or require("Railroader/RR_Geom")

local TrackData = {}

--------------------------------------------------------------------------
-- TrackNode: a single point on the route.
--   { x = <float tile>, y = <float tile>, z = <int/float floor>, name = <opt> }
-- We keep nodes as plain tables so they round-trip trivially through save data
-- and network packets later.
--------------------------------------------------------------------------
function TrackData.node(x, y, z, name)
    return { x = x, y = y, z = z or 0, name = name }
end

--------------------------------------------------------------------------
-- Route: an ordered list of nodes plus a precomputed cumulative arc-length
-- table. Call RR.TrackData.buildRoute(nodes, opts) to construct.
--
-- Produced fields:
--   route.nodes    -> the node list (not copied; treat as immutable)
--   route.cum[i]   -> arc length from node 1 to node i        (cum[1] = 0)
--   route.segLen[i]-> length of segment node i -> node i+1     (i in 1..n-1)
--   route.length   -> total route length
--   route.looped   -> bool; if true, distance wraps modulo length and a closing
--                     segment from node n back to node 1 is included.
--   route.count    -> number of nodes
--------------------------------------------------------------------------
function TrackData.buildRoute(nodes, opts)
    opts = opts or {}
    assert(type(nodes) == "table" and #nodes >= 2,
        "RR_TrackData.buildRoute: need at least 2 nodes")

    local route = {
        nodes  = nodes,
        cum    = {},
        segLen = {},
        looped = opts.looped == true,
        count  = #nodes,
    }

    local n = #nodes
    route.cum[1] = 0
    local total = 0
    for i = 1, n - 1 do
        local a, b = nodes[i], nodes[i + 1]
        local L = Geom.dist2d(a.x, a.y, b.x, b.y)
        route.segLen[i] = L
        total = total + L
        route.cum[i + 1] = total
    end

    if route.looped then
        -- Closing segment node n -> node 1.
        local a, b = nodes[n], nodes[1]
        local L = Geom.dist2d(a.x, a.y, b.x, b.y)
        route.segLen[n] = L
        total = total + L
        -- No extra cum entry: cum has n entries (0..pre-close total). The closing
        -- segment occupies distances [cum[n], total).
    end

    route.length = total
    return route
end

--------------------------------------------------------------------------
-- normalizeDistance: map an arbitrary distance into the valid travel range.
--   looped  -> wrap modulo length (so a train can circle forever)
--   open    -> clamp to [0, length]
--------------------------------------------------------------------------
function TrackData.normalizeDistance(route, d)
    if route.looped then
        d = d % route.length
        if d < 0 then d = d + route.length end
        return d
    end
    if d < 0 then return 0 end
    if d > route.length then return route.length end
    return d
end

--------------------------------------------------------------------------
-- locate: distance -> (segIndex, t) where t in [0,1] along that segment.
-- Binary search over the cumulative table. O(log n).
--
-- Returns segIndex in 1..(n-1) for open routes, or 1..n for looped routes
-- (the n-th segment being the closing one). t is the fractional position.
--------------------------------------------------------------------------
function TrackData.locate(route, d)
    d = TrackData.normalizeDistance(route, d)
    local n = route.count

    -- Looped distance beyond cum[n] lies on the closing segment n -> 1.
    if route.looped and d >= route.cum[n] then
        local segStart = route.cum[n]
        local L = route.segLen[n]
        local t = (L > 1e-9) and ((d - segStart) / L) or 0
        return n, t, route.nodes[n], route.nodes[1]
    end

    -- Binary search: largest i with cum[i] <= d, clamped so a segment exists.
    local lo, hi = 1, n            -- search node index
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if route.cum[mid] <= d then lo = mid else hi = mid - 1 end
    end
    local i = lo
    if i >= n then i = n - 1 end   -- clamp end-of-route onto last real segment

    local segStart = route.cum[i]
    local L = route.segLen[i]
    local t = (L > 1e-9) and ((d - segStart) / L) or 0
    if t > 1 then t = 1 end        -- guard the exact-end case
    return i, t, route.nodes[i], route.nodes[i + 1]
end

RR = RR or {}
RR.TrackData = TrackData

--------------------------------------------------------------------------
-- FUTURE: TrackGraph (switches / branches / stations).
-- A graph generalizes the polyline: nodes may have >1 outgoing edge, and a
-- concrete "route" becomes a chosen path through the graph. Because motion is
-- already a 1D distance over a sequence of nodes, a switch is just "which node
-- list do we build the active route from at this junction". Named stops are
-- nodes tagged with .name used as target distances. Nothing in RR_Spline needs
-- to change: it only ever sees a built route. Deferred until the vertical slice
-- (single hardcoded polyline) proves out.
--------------------------------------------------------------------------

return TrackData
