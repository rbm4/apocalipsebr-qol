--***********************************************************************
-- Railroader / RR_MapAudit  -- "what does the WORLD look like under our geometry?"
--
-- WHY THIS EXISTS: every route node, every switch coordinate and the depot spawn
-- distance were authored by hand against ONE version of the vanilla map. When TIS
-- rebuild a town (B42.20 reworks Muldraugh, West Point, Riverside, Rosewood, Fallas
-- Lake, Ekron and Dixie), the rails under our polyline can move, the engine shed can
-- be rebuilt, the turnout tilesheet can be renumbered -- and NOTHING throws. The loco
-- keeps driving, because a route is data, not tiles; it just drives over grass, or
-- stops dead against a wall that was not there yesterday.
--
-- So: take a snapshot of the world along our own geometry BEFORE the update, take the
-- same snapshot after, and diff the two files. What changed is exactly the work list.
--
-- HOW IT WORKS: a rolling background sweep. Every tick it advances a cursor along the
-- registered routes, probes a bounded number of tiles (centreline + both габарит flanks)
-- and records the ones that happen to be STREAMED IN -- a square outside the loaded
-- window reads nil and is simply retried on a later pass. So you fill the snapshot by
-- driving/walking the line; status() tells you how much you have covered and which
-- stretches are still missing.
--
-- USE (console; no key binding, so nothing here can be hit by accident):
--     RR.MapAudit.start()                  -- begin sweeping (also prints every ~30 s)
--     RR.MapAudit.scanSwitches()           -- probe all 61 authored switch tiles that are loaded
--     RR.MapAudit.scanBox(11606,9859,0,20) -- one-shot box dump (e.g. the depot shed)
--     RR.MapAudit.status()                 -- coverage per route + the gaps
--     RR.MapAudit.save("pre4220")          -- write Zomboid/rr_map_audit_pre4220.tsv
--     RR.MapAudit.stop() / .reset()
--
-- The file is tab-separated and sorted, so a plain text diff of the "before" and "after"
-- runs is the report. Per tile we keep: is there an `industry_railroad_*` sprite, the
-- solidity flags, how many objects, and a digest of the sorted sprite names. Full names
-- are kept for the tiles that matter (no rail under the centreline, or something solid),
-- because those are the ones you will have to go and look at.
--***********************************************************************

print("[Railroader] RR_MapAudit.lua: loading...")

require("Railroader/RR_Routes")
require("Railroader/RR_Spline")
require("Railroader/RR_TrackData")
require("Railroader/RR_TrackGraph")

RR = RR or {}

local Audit = {}

-- Lateral offsets sampled at each step, in tiles from the route centreline. 0 = between
-- the rails; +/-2.0 straddles the габарит (hull half-width ~1.87), i.e. the strip the
-- obstacle sweep actually reads. This is where trackside landscaping shows up.
Audit.LANE_OFFSETS = { -2.0, 0.0, 2.0 }
Audit.STEP         = 1.0      -- distance step along the route, tiles
Audit.PER_TICK     = 400      -- probes per tick (a probe = one tile); bounded work
Audit.MAX_RECORDS  = 60000    -- safety cap -- stop recording rather than eat the heap
Audit.NAME_CAP     = 12       -- keep at most this many sprite names per tile
Audit.RAIL_PREFIX  = "industry_railroad"   -- same test the obstacle sweep uses

local running   = false
local recs      = {}          -- key "x,y,z" -> record table
local nrecs     = 0
local hitD      = {}          -- label -> { [d] = true } for the CENTRE lane (coverage)
local order     = nil         -- sweep targets: { {id=label, route=built}, ... }
local ci        = 1           -- cursor: index into `order`
local cd        = 0           -- cursor: distance along that route
local passes    = 0
local lastPrint = 0

--------------------------------------------------------------------------
-- targets(): every piece of authored geometry there is, as built routes --
-- the registered routes (RR.Routes) AND every TrackGraph edge (the branches,
-- depot sidings, hangar leads and terminal loops live only in the graph, not in
-- RR.Routes). Built once and cached; sorted for a deterministic sweep order.
--------------------------------------------------------------------------
local function targets()
    if order then return order end
    order = {}
    local seen = {}
    local function add(label, route)
        if route and not seen[label] then
            seen[label] = true
            order[#order + 1] = { id = label, route = route }
        end
    end
    pcall(function()
        for _, id in ipairs(RR.Routes.ids()) do add(id, RR.Routes.get(id)) end
    end)
    pcall(function()
        if not (RR.TrackGraph and RR.TrackGraph.defs) then return end
        for netId in pairs(RR.TrackGraph.defs) do
            for edgeId, nodes in pairs(RR.TrackGraph.netEdges(netId)) do
                if type(nodes) == "table" and #nodes >= 2 then
                    local ok, built = pcall(RR.TrackData.buildRoute, nodes, { looped = false })
                    if ok then add(netId .. ":" .. edgeId, built) end
                end
            end
        end
    end)
    table.sort(order, function(a, b) return a.id < b.id end)
    print(string.format("[Railroader] map audit: %d authored lines to sweep.", #order))
    return order
end

--------------------------------------------------------------------------
-- Cheap deterministic digest of a string (Kahlua is Lua 5.1: no bitwise ops).
-- Only the first 400 chars are folded in -- enough to catch any tile change.
--------------------------------------------------------------------------
local function digest(s)
    local h = 5381
    local n = #s
    if n > 400 then n = 400 end
    for i = 1, n do
        h = (h * 33 + string.byte(s, i)) % 2147483647
    end
    return h
end

--------------------------------------------------------------------------
-- probe(tx, ty, tz) -> record or nil (nil = the square is not streamed in).
-- Every world read is pcall-wrapped: one bad object must never kill the sweep.
--------------------------------------------------------------------------
local function probe(tx, ty, tz)
    local sq
    pcall(function()
        local cell = getCell()
        if cell then sq = cell:getGridSquare(tx, ty, tz) end
    end)
    if not sq then return nil end

    local names, rail, nobj = {}, 0, 0
    pcall(function()
        local objs = sq:getObjects()
        if not objs then return end
        nobj = objs:size()
        for i = 0, objs:size() - 1 do
            local o  = objs:get(i)
            local sp = o and o:getSprite()
            local nm = sp and sp:getName()
            if nm then
                names[#names + 1] = nm
                if string.sub(nm, 1, #Audit.RAIL_PREFIX) == Audit.RAIL_PREFIX then rail = 1 end
            end
        end
    end)
    table.sort(names)
    if #names > Audit.NAME_CAP then
        local trimmed = {}
        for i = 1, Audit.NAME_CAP do trimmed[i] = names[i] end
        trimmed[Audit.NAME_CAP + 1] = "+" .. (#names - Audit.NAME_CAP)
        names = trimmed
    end
    local joined = table.concat(names, "|")

    local sol, st = 0, 0
    pcall(function() if sq:isSolid()      then sol = 1 end end)
    pcall(function() if sq:isSolidTrans() then st  = 1 end end)

    return { x = tx, y = ty, z = tz, rail = rail, sol = sol, st = st,
             nobj = nobj, hash = digest(joined), names = joined }
end

--------------------------------------------------------------------------
-- record(rec, routeId, d, lane, force): store a probe, keyed by tile. `force` keeps the
-- full sprite-name list; otherwise names are kept only for the tiles worth walking to --
-- a centreline tile with NO rail under it, or anything solid.
--------------------------------------------------------------------------
local function record(rec, routeId, d, lane, force)
    if not rec then return false end
    local key = rec.x .. "," .. rec.y .. "," .. rec.z
    if recs[key] then return false end
    if nrecs >= Audit.MAX_RECORDS then return false end
    rec.route = routeId
    rec.d     = d
    rec.lane  = lane
    local interesting = force or rec.sol == 1 or rec.st == 1
                        or (lane == 0 and rec.rail == 0)
    if not interesting then rec.names = "" end
    recs[key] = rec
    nrecs = nrecs + 1
    return true
end

--------------------------------------------------------------------------
-- The rolling sweep. Advances the cursor along the current route, probing
-- Audit.PER_TICK tiles per tick and wrapping to the next route at the end.
--------------------------------------------------------------------------
local function sweepTick()
    if not running then return end
    local list = targets()
    if #list == 0 then return end

    local budget = Audit.PER_TICK
    while budget > 0 do
        local t       = list[ci]
        local routeId = t and t.id
        local route   = t and t.route
        if not route then
            ci = ci + 1; cd = 0
            if ci > #list then ci = 1; passes = passes + 1 end
            budget = budget - 1
        else
            local len = route.length or 0
            if cd > len then
                ci = ci + 1; cd = 0
                if ci > #list then ci = 1; passes = passes + 1 end
            else
                local pose = RR.Spline.sample(route, cd)
                local fx, fy = pose.dirX or 1, pose.dirY or 0
                -- left-hand normal of the forward vector
                local nx, ny = -fy, fx
                local di = math.floor(cd + 0.5)
                for li = 1, #Audit.LANE_OFFSETS do
                    local off = Audit.LANE_OFFSETS[li]
                    local tx  = math.floor(pose.x + nx * off)
                    local ty  = math.floor(pose.y + ny * off)
                    local tz  = math.floor((pose.z or 0) + 0.5)
                    local key = tx .. "," .. ty .. "," .. tz
                    if not recs[key] then
                        local r = probe(tx, ty, tz)
                        if r then
                            record(r, routeId, di, off, false)
                            if off == 0 then
                                hitD[routeId] = hitD[routeId] or {}
                                hitD[routeId][di] = true
                            end
                        end
                        budget = budget - 1
                    end
                end
                cd = cd + Audit.STEP
                budget = budget - 1
            end
        end
    end

    -- Heartbeat, so a long cruise tells you it is still collecting.
    lastPrint = lastPrint + 1
    if lastPrint >= 1800 then      -- ~30 s at 60 fps
        lastPrint = 0
        print(string.format("[Railroader] map audit: %d tiles recorded, pass %d", nrecs, passes))
    end
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------
function Audit.start()
    if running then print("[Railroader] map audit: already running."); return end
    running   = true
    lastPrint = 0
    Events.OnTick.Add(sweepTick)
    print("[Railroader] map audit: STARTED. Drive/walk the line; RR.MapAudit.status() for "
          .. "coverage, RR.MapAudit.save(\"tag\") when done.")
end

function Audit.stop()
    if not running then return end
    running = false
    Events.OnTick.Remove(sweepTick)
    print(string.format("[Railroader] map audit: STOPPED (%d tiles recorded).", nrecs))
end

function Audit.reset()
    recs, nrecs, hitD = {}, 0, {}
    order, ci, cd, passes = nil, 1, 0, 0
    print("[Railroader] map audit: cleared.")
end

--------------------------------------------------------------------------
-- scanBox(x, y, z, r): one-shot dump of every loaded tile in a (2r+1) square. This is
-- how you capture the engine shed itself -- the doorway the collide-gate is tuned to.
-- Full sprite names are kept for every tile in the box.
--------------------------------------------------------------------------
function Audit.scanBox(x, y, z, r)
    x, y, z, r = math.floor(x or 0), math.floor(y or 0), math.floor(z or 0), math.floor(r or 10)
    local got, miss = 0, 0
    for ty = y - r, y + r do
        for tx = x - r, x + r do
            local key = tx .. "," .. ty .. "," .. z
            local old = recs[key]
            local re  = probe(tx, ty, z)
            if not re then
                miss = miss + 1
            elseif old then
                -- Already recorded by the sweep (names possibly stripped): keep its
                -- route/d/lane provenance but upgrade it to the full name list.
                re.route, re.d, re.lane = old.route, old.d, old.lane
                recs[key] = re
                got = got + 1
            else
                record(re, "BOX:" .. x .. "," .. y, 0, 0, true)
                got = got + 1
            end
        end
    end
    print(string.format("[Railroader] map audit: box (%d,%d,%d) r=%d -> %d tiles read, %d not loaded.",
                        x, y, z, r, got, miss))
    return got, miss
end

--------------------------------------------------------------------------
-- scanSwitches(): probe every authored switch coordinate (`at`, and the `place` target
-- tiles we stamp turnout sprites onto). Loaded ones are recorded with full names and
-- reported; the rest are listed so you know where still to walk.
--------------------------------------------------------------------------
function Audit.scanSwitches()
    if not (RR.TrackGraph and RR.TrackGraph.defs) then
        print("[Railroader] map audit: no TrackGraph loaded."); return
    end
    local got, miss, norail = 0, 0, {}
    for netId, def in pairs(RR.TrackGraph.defs) do
        for _, sw in ipairs(def.switches or {}) do
            local targets = {}
            if sw.at then targets[#targets + 1] = { x = sw.at.x, y = sw.at.y, z = sw.at.z or 0, what = "at" } end
            local p = sw.place
            if p then
                if p.sprite then targets[#targets + 1] = { x = p.x, y = p.y, z = p.z or 0, what = p.sprite } end
                if p.sprites then
                    for _, s in ipairs(p.sprites) do
                        targets[#targets + 1] = { x = p.x + (s.dx or 0), y = p.y + (s.dy or 0),
                                                  z = p.z or 0, what = s.sprite }
                    end
                end
            end
            for _, t in ipairs(targets) do
                local r = probe(math.floor(t.x), math.floor(t.y), math.floor(t.z))
                if r then
                    record(r, "SW:" .. netId .. ":" .. tostring(sw.id) .. ":" .. t.what, 0, 0, true)
                    got = got + 1
                    if r.rail == 0 then norail[#norail + 1] = tostring(sw.id) .. "@" .. t.what end
                else
                    miss = miss + 1
                end
            end
        end
    end
    print(string.format("[Railroader] map audit: switches -> %d tiles read, %d not loaded.", got, miss))
    if #norail > 0 then
        print("[Railroader] map audit: switch tiles with NO railroad sprite: " .. table.concat(norail, " "))
    end
    return got, miss
end

--------------------------------------------------------------------------
-- status(): coverage per route, plus the first few uncovered stretches (so you know
-- which way to drive next). Coverage counts CENTRE-lane samples only.
--------------------------------------------------------------------------
function Audit.status()
    print(string.format("[Railroader] map audit: %s, %d tiles recorded, %d full passes.",
                        running and "RUNNING" or "stopped", nrecs, passes))
    for _, t in ipairs(targets()) do
        local id    = t.id
        local len   = math.floor(t.route.length or 0)
        local hits  = hitD[id] or {}
        local n, gaps, gapStart = 0, {}, nil
        for d = 0, len do
            if hits[d] then
                n = n + 1
                if gapStart then
                    gaps[#gaps + 1] = gapStart .. "-" .. (d - 1)
                    gapStart = nil
                end
            else
                if not gapStart then gapStart = d end
            end
        end
        if gapStart then gaps[#gaps + 1] = gapStart .. "-" .. len end
        local pct = (len > 0) and (100.0 * n / (len + 1)) or 0
        local gapTxt = ""
        if #gaps > 0 then
            local show = {}
            for i = 1, math.min(4, #gaps) do show[i] = gaps[i] end
            gapTxt = "  gaps: " .. table.concat(show, ", ") .. ((#gaps > 4) and (" (+" .. (#gaps - 4) .. ")") or "")
        end
        print(string.format("   %-24s len %6d  covered %5.1f%%%s", id, len, pct, gapTxt))
    end
end

--------------------------------------------------------------------------
-- save(tag): write the snapshot to  <Zomboid>/rr_map_audit_<tag>.tsv  -- sorted, so the
-- "before" and "after" files diff line-for-line.
--------------------------------------------------------------------------
function Audit.save(tag)
    tag = tostring(tag or "snapshot")
    local list = {}
    for _, r in pairs(recs) do list[#list + 1] = r end
    table.sort(list, function(a, b)
        if a.route ~= b.route then return a.route < b.route end
        if a.d ~= b.d then return a.d < b.d end
        if a.lane ~= b.lane then return a.lane < b.lane end
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)

    local fname = "rr_map_audit_" .. tag .. ".tsv"
    local w = getFileWriter(fname, true, false)
    if not w then print("[Railroader] map audit: could not open " .. fname); return end
    w:write("# rr_map_audit v1\ttag=" .. tag .. "\ttiles=" .. nrecs .. "\r\n")
    w:write("# route\td\tlane\tx\ty\tz\trail\tsolid\tsolidtrans\tnobj\thash\tnames\r\n")
    for i = 1, #list do
        local r = list[i]
        w:write(string.format("%s\t%d\t%.1f\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\r\n",
                              r.route, r.d, r.lane, r.x, r.y, r.z,
                              r.rail, r.sol, r.st, r.nobj, r.hash, r.names))
    end
    w:close()
    print(string.format("[Railroader] map audit: wrote %d tiles to <Zomboid>/%s", #list, fname))
    return #list
end

RR.MapAudit = Audit
print("[Railroader] RR_MapAudit.lua: loaded OK (console: RR.MapAudit.start() / .save(\"tag\"))")
return Audit
