--***********************************************************************
-- Railroader / RR_TrackGraph  (switches / turnouts -- the track GRAPH)
--
-- The track is a GRAPH, not one polyline:
--   * edge   = a named polyline. Its own node order names its two ends:
--              "start" (nodes[1]) and "end" (nodes[#nodes]).
--   * switch = a turnout at a point `at` with THREE legs. A leg is an
--              { edge = <id>, toward = "start"|"end" } pair: the direction the leg
--              leaves `at` along that edge.
--                throat  -- the POINTS end: the only leg where the switch decides
--                through -- where a FACING train goes when the switch is NORMAL
--                diverge -- where a FACING train goes when it is REVERSE
--
-- Facing vs trailing is NOT a property of a switch -- it is WHICH LEG YOU ARRIVE
-- ON, so it is derived here, never registered:
--   arrive on the throat        -> FACING:   the state picks through / diverge
--   arrive on through / diverge -> TRAILING: you always come out at the throat and
--                                 the state does not change your path.
-- (Run-through -- taking a trailing switch set against you -- is deferred; the walk
-- already knows the arrival leg, so it is one check away in the junction step.)
--
-- materialize() walks the graph from the net's ORIGIN, consulting switch states at
-- each junction, and returns ONE node list -- fed to the plain RR_TrackData.buildRoute.
-- So RR_Spline / RR_Body / the collider / crush are untouched: they still only ever
-- see a built polyline (model B).
--
-- Distance stays anchored at the origin (main node[1] = the depot), so a loco's
-- `distance`, the depot spawn and the save data all keep their meaning. Throwing a
-- switch re-materializes the path; the drive layer only re-points a loco's route
-- while it is still on the SHARED PREFIX of the old and new paths
-- (sharedPrefixDist), so a body that already committed past a fork never teleports.
--
-- KNOWN LIMIT (deferred): the path is materialized from the origin travelling
-- FORWARD, so a switch whose throat faces away from the origin is passed trailing
-- and its branch is not reachable by BACKING into it. Backing into a siding needs
-- per-loco materialization from (edge, position, direction) + a graph-position save
-- format; not needed by the current topology.
--***********************************************************************

print("[Railroader] RR_TrackGraph.lua: loading...")
local Geom      = RR and RR.Geom      or require("Railroader/RR_Geom")
local TrackData = RR and RR.TrackData or require("Railroader/RR_TrackData")
local Spline    = RR and RR.Spline    or require("Railroader/RR_Spline")

local TrackGraph = {}
-- netId -> { edges = { edgeId -> nodes }, switches = { sw, ... },
--            origin = { edge, toward }, states = { swId -> "normal"|"reverse" },
--            _built = { stateKey -> built route }, _edges = { edgeId -> built edge } }
TrackGraph.defs = {}

local EPS       = 1e-3
local MAX_HOPS  = 64      -- junction traversals per walk (loop guard)
local MAX_NODES = 4096

--------------------------------------------------------------------------
-- projectOnSeg: project (px,py) onto segment a->b. Returns (t clamped to [0,1],
-- distance from the point to the projection). Pure geometry.
--------------------------------------------------------------------------
local function projectOnSeg(ax, ay, bx, by, px, py)
    local dx, dy = bx - ax, by - ay
    local L2 = dx * dx + dy * dy
    if L2 < 1e-9 then return 0, Geom.dist2d(ax, ay, px, py) end
    local t = ((px - ax) * dx + (py - ay) * dy) / L2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return t, Geom.dist2d(ax + t * dx, ay + t * dy, px, py)
end

--------------------------------------------------------------------------
-- locateSeg(nodes, at): the segment index i whose body passes closest to `at`,
-- plus the fraction t along it and that distance. A switch is authored to sit ON
-- a segment, so the match is exact.
--------------------------------------------------------------------------
function TrackGraph.locateSeg(nodes, at)
    local bestI, bestT, bestD = 1, 0, math.huge
    for i = 1, #nodes - 1 do
        local a, b = nodes[i], nodes[i + 1]
        local t, d = projectOnSeg(a.x, a.y, b.x, b.y, at.x, at.y)
        if d < bestD then bestD, bestI, bestT = d, i, t end
    end
    return bestI, bestT, bestD
end

--------------------------------------------------------------------------
-- posOn(builtEdge, at): arc length along that edge to the point `at`.
--------------------------------------------------------------------------
local function posOn(builtEdge, at)
    local i, t = TrackGraph.locateSeg(builtEdge.nodes, at)
    return (builtEdge.cum[i] or 0) + t * (builtEdge.segLen[i] or 0)
end

--------------------------------------------------------------------------
-- materialize(edgeNodeMap, switches, states, origin): walk the graph and return
-- the single node list a loco starting at `origin` follows. PURE (no engine, no
-- registry) -> unit-tested offline.
--   edgeNodeMap = { edgeId -> { {x,y,z,name?}, ... } }
--   origin      = { edge = <id>, toward = "start"|"end" }
--------------------------------------------------------------------------
function TrackGraph.materialize(edgeNodeMap, switches, states, origin)
    states   = states or {}
    switches = switches or {}

    -- Build each edge once so we can talk in arc length along it.
    local built = {}
    for id, nodes in pairs(edgeNodeMap) do
        if type(nodes) == "table" and #nodes >= 2 then
            built[id] = TrackData.buildRoute(nodes, { looped = false })
        end
    end
    local originEdge = built[origin and origin.edge]
    if not originEdge then return {} end

    -- Index switches per edge they touch, by arc position, so the walk can ask
    -- "what is the next junction ahead of me on this edge".
    local byEdge = {}
    for _, sw in ipairs(switches) do
        local seen = {}
        for _, legName in ipairs({ "throat", "through", "diverge" }) do
            local leg = sw[legName]
            if leg and built[leg.edge] and not seen[leg.edge] then
                seen[leg.edge] = true
                byEdge[leg.edge] = byEdge[leg.edge] or {}
                table.insert(byEdge[leg.edge], { sw = sw, s = posOn(built[leg.edge], sw.at) })
            end
        end
    end
    for _, list in pairs(byEdge) do
        table.sort(list, function(a, b) return a.s < b.s end)
    end

    local out = {}
    local function push(p, name)
        if not p then return end
        local last = out[#out]
        if last and Geom.dist2d(last.x, last.y, p.x, p.y) <= EPS then return end
        out[#out + 1] = { x = p.x, y = p.y, z = p.z or 0, name = name }
    end

    local edgeId = origin.edge
    local dir    = (origin.toward == "start") and -1 or 1
    local s      = origin.s or ((dir > 0) and 0 or originEdge.length)
    local fromSw = nil   -- the junction we just left: don't re-trigger on it

    for _ = 1, MAX_HOPS do
        local e = built[edgeId]
        if not e then break end

        -- Next junction ahead on this edge, in our direction of travel.
        local nxt
        for _, ent in ipairs(byEdge[edgeId] or {}) do
            if ent.sw ~= fromSw then
                if dir > 0 and ent.s > s + EPS then
                    if (not nxt) or ent.s < nxt.s then nxt = ent end
                elseif dir < 0 and ent.s < s - EPS then
                    if (not nxt) or ent.s > nxt.s then nxt = ent end
                end
            end
        end
        local sTarget = nxt and nxt.s or ((dir > 0) and e.length or 0)

        -- Emit: where we stand, the edge's own nodes we pass, then the target point.
        push(Spline.sample(e, s))
        if dir > 0 then
            for i = 1, e.count do
                local ci = e.cum[i]
                if ci and ci > s + EPS and ci < sTarget - EPS then push(e.nodes[i], e.nodes[i].name) end
            end
        else
            for i = e.count, 1, -1 do
                local ci = e.cum[i]
                if ci and ci < s - EPS and ci > sTarget + EPS then push(e.nodes[i], e.nodes[i].name) end
            end
        end
        push(Spline.sample(e, sTarget), nxt and (nxt.sw.id .. "_at") or nil)

        if not nxt then break end                 -- edge ran out: dead end / buffer stop
        if #out >= MAX_NODES then break end

        -- At the junction. Which leg did we arrive on? We came from the part of this
        -- edge BEHIND us, i.e. the leg leaving `at` opposite to our travel direction.
        local sw           = nxt.sw
        local arriveToward = (dir > 0) and "start" or "end"
        local function isArrivalLeg(leg)
            return leg and leg.edge == edgeId and leg.toward == arriveToward
        end

        local exit
        if isArrivalLeg(sw.throat) then
            -- FACING: we came up the points -- the switch decides.
            exit = (states[sw.id] == "reverse") and sw.diverge or sw.through
        else
            -- TRAILING: arrived on through/diverge -- always out at the throat, and
            -- the state is irrelevant to our path (run-through check would go here).
            exit = sw.throat
        end
        if not (exit and built[exit.edge]) then break end

        edgeId = exit.edge
        dir    = (exit.toward == "end") and 1 or -1
        s      = posOn(built[edgeId], sw.at)
        fromSw = sw
    end

    return out
end

--------------------------------------------------------------------------
-- materializeThrough(edgeMap, switches, states, here): the node list a loco AT
-- `here = {edge, s, dir}` follows, extending BOTH ways -- forward in `dir` (ahead)
-- and backward in -dir (behind, giving the rear-truck tail AND the track it would
-- take if reversed). Returns (nodes, sHere) where sHere is the loco's arc position
-- on the returned polyline. Centering on the loco is what lets a re-materialize be
-- pose-continuous (sHere maps back to the same world point) and what makes a switch
-- facing AGAINST the travel direction reachable: once the loco is past it, the
-- behind-walk arrives on its throat -> facing -> its branch is included. PURE.
--------------------------------------------------------------------------
function TrackGraph.materializeThrough(edgeMap, switches, states, here)
    local dir          = (here.dir and here.dir < 0) and -1 or 1
    local aheadToward  = (dir > 0) and "end" or "start"
    local behindToward = (dir > 0) and "start" or "end"
    local ahead  = TrackGraph.materialize(edgeMap, switches, states, { edge = here.edge, s = here.s, toward = aheadToward })
    local behind = TrackGraph.materialize(edgeMap, switches, states, { edge = here.edge, s = here.s, toward = behindToward })

    local nodes = {}
    for i = #behind, 1, -1 do nodes[#nodes + 1] = behind[i] end   -- behind reversed, ends at the loco
    local sHere = 0
    for i = 1, #behind - 1 do
        sHere = sHere + Geom.dist2d(behind[i].x, behind[i].y, behind[i + 1].x, behind[i + 1].y)
    end
    for i = 2, #ahead do nodes[#nodes + 1] = ahead[i] end          -- ahead, skipping the shared loco point
    return nodes, sHere
end

--------------------------------------------------------------------------
-- graphLocate(edgeMap, x, y): reverse lookup -- the edge whose body passes closest
-- to (x,y), with the arc position `s` along it and the unit tangent there (pointing
-- toward the edge's "end"). Used to re-anchor a loco from its true world position
-- (so persistence needs no graph coords: the IsoAnimal's saved x,y is enough).
--------------------------------------------------------------------------
function TrackGraph.graphLocate(edgeMap, x, y)
    local best
    for id, nodes in pairs(edgeMap) do
        if type(nodes) == "table" and #nodes >= 2 then
            local i, t, d = TrackGraph.locateSeg(nodes, { x = x, y = y })
            if (not best) or d < best.d then
                local a, b = nodes[i], nodes[i + 1]
                local tx, ty = Geom.normalize2d(b.x - a.x, b.y - a.y)
                local s = 0
                for k = 1, i - 1 do s = s + Geom.dist2d(nodes[k].x, nodes[k].y, nodes[k + 1].x, nodes[k + 1].y) end
                s = s + t * Geom.dist2d(a.x, a.y, b.x, b.y)
                best = { edge = id, s = s, tx = tx, ty = ty, d = d }
            end
        end
    end
    return best
end

--------------------------------------------------------------------------
-- sharedPrefixDist(routeA, routeB): the distance up to which two BUILT routes are
-- the same physical path (arc length to the last identical node). Beyond it they
-- differ, so re-pointing a loco there would move it to another track. PURE.
--------------------------------------------------------------------------
function TrackGraph.sharedPrefixDist(a, b)
    if not (a and b) then return 0 end
    local n, k = math.min(a.count, b.count), 0
    for i = 1, n do
        local na, nb = a.nodes[i], b.nodes[i]
        if Geom.dist2d(na.x, na.y, nb.x, nb.y) > EPS then break end
        k = i
    end
    if k == 0 then return 0 end
    return a.cum[k] or 0
end

--------------------------------------------------------------------------
-- Registry / state.
--   register(netId, { edges = { id -> nodes }, switches = {...}, origin = {...} })
-- The net's OWN id doubles as an edge: its nodes come from the authored route
-- registry (RR.Routes) unless `edges[netId]` overrides it. Origin defaults to that
-- edge travelled from its start, so distance 0 stays "main node[1]" (the depot).
--------------------------------------------------------------------------
function TrackGraph.register(netId, def)
    assert(type(netId) == "string", "RR_TrackGraph.register: netId must be a string")
    assert(type(def) == "table", "RR_TrackGraph.register: def must be a table")
    local d = TrackGraph.defs[netId] or { states = {} }
    d.edges    = def.edges or {}
    d.switches = def.switches or {}
    d.origin   = def.origin or { edge = netId, toward = "end" }
    d.states   = d.states or {}
    for _, sw in ipairs(d.switches) do
        assert(sw.id and sw.at and sw.throat and sw.through and sw.diverge,
               "RR_TrackGraph: a switch needs id, at, throat, through, diverge")
        if d.states[sw.id] == nil then d.states[sw.id] = "normal" end
    end
    d._built = {}
    TrackGraph.defs[netId] = d
    print("[Railroader] track graph: net '" .. netId .. "' -- "
          .. tostring(#d.switches) .. " switch(es).")
    return d
end

function TrackGraph.has(netId)      return TrackGraph.defs[netId] ~= nil end
function TrackGraph.switches(netId) local d = TrackGraph.defs[netId]; return d and d.switches or {} end
function TrackGraph.states(netId)   local d = TrackGraph.defs[netId]; return d and d.states or {} end

function TrackGraph.getState(netId, switchId)
    local d = TrackGraph.defs[netId]
    return (d and d.states[switchId]) or "normal"
end

function TrackGraph.setState(netId, switchId, state)
    local d = TrackGraph.defs[netId]
    if not d then return false end
    d.states[switchId] = (state == "reverse") and "reverse" or "normal"
    return true
end

function TrackGraph.toggleState(netId, switchId)
    local nxt = (TrackGraph.getState(netId, switchId) == "reverse") and "normal" or "reverse"
    TrackGraph.setState(netId, switchId, nxt)
    return nxt
end

-- A stable key for the current switch states (cache key + change detection).
function TrackGraph.stateKey(netId)
    local d = TrackGraph.defs[netId]
    if not d then return "" end
    local ids = {}
    for _, sw in ipairs(d.switches) do ids[#ids + 1] = sw.id end
    table.sort(ids)
    for k, id in ipairs(ids) do ids[k] = id .. "=" .. (d.states[id] or "normal") end
    return table.concat(ids, ",")
end

--------------------------------------------------------------------------
-- edgeNodeMapFor: the net's edges, with its own id filled in from RR.Routes.
--------------------------------------------------------------------------
local function edgeNodeMapFor(netId, d)
    local map = {}
    for id, nodes in pairs(d.edges or {}) do map[id] = nodes end
    if not map[netId] then
        local Routes = RR and RR.Routes
        local base   = Routes and Routes.get(netId)
        if base then map[netId] = base.nodes end
    end
    return map
end

--------------------------------------------------------------------------
-- netEdges(netId): the net's edge map (its own id filled in from RR.Routes).
--------------------------------------------------------------------------
function TrackGraph.netEdges(netId)
    local d = TrackGraph.defs[netId]
    if not d then return {} end
    return edgeNodeMapFor(netId, d)
end

--------------------------------------------------------------------------
-- buildThrough(netId, here): the BUILT route (+ the loco's arc position on it) for
-- a loco AT `here = {edge, s, dir}`, materialized both ways under the current switch
-- states. This is the per-loco, position-anchored path (vs buildActive's fixed
-- depot-forward one). Returns (route, sHere) or (nil) if it can't be built.
--------------------------------------------------------------------------
function TrackGraph.buildThrough(netId, here)
    local d = TrackGraph.defs[netId]
    if not d then return nil end
    local nodes, sHere = TrackGraph.materializeThrough(TrackGraph.netEdges(netId), d.switches, d.states, here)
    if #nodes < 2 then return nil end
    return TrackData.buildRoute(nodes, { looped = false }), sHere
end

--------------------------------------------------------------------------
-- buildActive(netId): the BUILT route a loco on this net follows under the current
-- switch states, cached per stateKey. Needs RR.Routes for the net's own edge.
-- (Fixed depot-forward path -- kept for forkDist / debug spawn placement.)
--------------------------------------------------------------------------
function TrackGraph.buildActive(netId)
    local d = TrackGraph.defs[netId]
    if not d then
        local Routes = RR and RR.Routes
        return Routes and Routes.get(netId) or nil
    end
    local key = TrackGraph.stateKey(netId)
    if d._built[key] then return d._built[key] end

    local nodes = TrackGraph.materialize(edgeNodeMapFor(netId, d), d.switches, d.states, d.origin)
    if #nodes < 2 then
        local Routes = RR and RR.Routes
        return Routes and Routes.get(netId) or nil
    end
    local built = TrackData.buildRoute(nodes, { looped = false })
    d._built[key] = built
    return built
end

--------------------------------------------------------------------------
-- forkDist(netId, switchId): distance along the CURRENT active path to a switch's
-- point, or nil. Used to place/spawn a loco just before a given switch.
--------------------------------------------------------------------------
function TrackGraph.forkDist(netId, switchId)
    local d = TrackGraph.defs[netId]
    if not d then return nil end
    local route = TrackGraph.buildActive(netId)
    if not route then return nil end
    for _, sw in ipairs(d.switches) do
        if sw.id == switchId then return posOn(route, sw.at) end
    end
    return nil
end

RR = RR or {}
RR.TrackGraph = TrackGraph
print("[Railroader] RR_TrackGraph.lua: loaded OK")
return TrackGraph
