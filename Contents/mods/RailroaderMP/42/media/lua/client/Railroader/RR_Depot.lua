--***********************************************************************
-- Railroader / RR_Depot  -- how a loco ACTUALLY enters the world (Task 1.J).
--
-- Until now the only loco in the game appeared because you pressed a debug key.
-- Now the world owns it: Knox & Louisville #800 has been standing in the covered
-- engine shed at the MULDRAUGH DEPOT since the outbreak -- cold, with whatever
-- fuel was left in it and a battery that has been quietly going flat ever since.
-- It materialises ONCE, the first time a survivor comes within RR_Spawn.DEPOT.radius
-- of the shed, and never again (a flag in the save's global ModData).
--
-- Why an approach trigger and not a spawn at world creation: the loco is a real
-- IsoAnimal on a real grid square, so its chunk has to be streamed in for
-- addAnimal/addToWorld to land it. Standing near it guarantees exactly that --
-- the same reason the debug spawn used to teleport the player first.
--
-- WHERE it stands and WHAT SHAPE it is in are pure, unit-tested decisions in
-- RR_Spawn (shared/). This file is only the engine adapter: world clock, random
-- rolls, distance check, persistence flag.
--
-- Debug key:  O = teleport TO THE LOCO wherever it currently stands; if none exists
--             yet, to the depot shed instead (which does NOT spawn -- the approach does).
--***********************************************************************

print("[Railroader] RR_Depot.lua: loading...")
require("Railroader/RR_Spawn")
require("Railroader/RR_Routes")
require("Railroader/RR_Spline")

local Spawn  = RR.Spawn
local Spline = RR.Spline

local Depot = {}

-- Global (per-save) mod data. ModData.getOrCreate is the vanilla "has this unique
-- thing already been placed?" channel -- see ProfessionVehicles.lua /
-- "UniqueVehiclesSpawned" -- and it round-trips through the save.
local MD_TAG = "RR_World"

local function worldData()
    local wd = nil
    pcall(function() wd = ModData.getOrCreate(MD_TAG) end)
    return wd
end

--------------------------------------------------------------------------
-- Days since the APOCALYPSE (not since this character spawned). Vanilla formula
-- (ISButtonPrompt.lua): the save's own age plus the sandbox "time since the
-- apocalypse" enum, where 1 = day 0 and every further step is one month.
--------------------------------------------------------------------------
function Depot.daysSinceApo()
    local hours, opt = 0, 1
    pcall(function() hours = getGameTime():getWorldAgeHours() end)
    pcall(function() opt   = getSandboxOptions():getTimeSinceApo() end)
    return Spawn.daysSinceApo(hours, opt)
end

--------------------------------------------------------------------------
-- point(): the world spot inside the shed -- the rail point DEPOT.distance tiles
-- along route "main" from its first node. Returns x, y, z (nil if no route).
--------------------------------------------------------------------------
function Depot.point()
    local D = Spawn.DEPOT
    if not (RR.Routes and RR.Routes.exists(D.routeId)) then return nil end
    local route = RR.Routes.get(D.routeId)
    local p = Spline.sample(route, math.min(D.distance, route.length))
    return p.x, p.y, p.z or 0
end

--------------------------------------------------------------------------
-- forget(): re-arm the world spawn (debug -- the P key clears the loco and calls
-- this, so walking back into the shed produces a fresh one with new rolls).
--------------------------------------------------------------------------
function Depot.forget()
    local wd = worldData()
    if wd then wd.rrLocoSpawned = false end
    -- also reset the service point: pull the pump and clear the diesel reserve so a
    -- fresh approach re-rolls everything (debug parity with the loco re-roll).
    if RR.ServiceDepot then pcall(function() RR.ServiceDepot.forget() end) end
    print("[Railroader] depot: world spawn re-armed (walk into the shed again).")
end

--------------------------------------------------------------------------
-- gotoDepot(): the O key. Teleports the survivor to the shed (streams the chunk
-- in); the approach trigger below then does the actual spawning, exactly as it
-- would if they had walked there.
--------------------------------------------------------------------------
function Depot.gotoDepot()
    local x, y, z = Depot.point()
    if not x then
        print("[Railroader] depot: route '" .. tostring(Spawn.DEPOT.routeId)
              .. "' is not registered -- nothing to teleport to.")
        return
    end
    local p = getPlayer()
    if p then pcall(function() p:teleportTo(x + 3, y, z) end) end
    print(string.format("[Railroader] depot: teleported to the engine shed (%.0f,%.0f,%.0f).", x, y, z))
end

--------------------------------------------------------------------------
-- locoPoint(): where the loco ACTUALLY is right now -- x, y, z, rec (nil if there
-- is none). Reads the animal's live world position, so it is right in every state:
-- on the spline, parked, or frozen off-rail after a derailment. Falls back to the
-- spline sample if the getters refuse (virtualized animal after a chunk unload).
--------------------------------------------------------------------------
function Depot.locoPoint()
    local TE = RR.TrainEntity
    if not (TE and TE.active) then return nil end
    for _, e in ipairs(TE.active) do
        local a = e.animal
        local alive = false
        if a then pcall(function() alive = not a:isDead() end) end
        if alive then
            local x, y, z
            pcall(function() x, y, z = a:getX(), a:getY(), a:getZ() end)
            if (not x) and e.route and e.distance then
                pcall(function()
                    local p = Spline.sample(e.route, e.distance)
                    x, y, z = p.x, p.y, p.z or 0
                end)
            end
            if x then return x, y, z or 0, e end
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- gotoLoco(): the O key when a loco exists. Teleports the survivor beside it --
-- the shed is only its birthplace, so once K&L 800 has been driven anywhere a
-- "goto depot" lands you on empty rails. Returns false when there is no loco to
-- go to (the caller then falls back to the shed, which is where one appears).
--------------------------------------------------------------------------
function Depot.gotoLoco()
    local x, y, z, rec = Depot.locoPoint()
    if not x then return false end
    local p = getPlayer()
    if not p then return false end
    if RR.Ride and RR.Ride.current == rec then
        print("[Railroader] depot: you are already in the cab.")
        return true
    end
    pcall(function() p:teleportTo(x + 3, y, z) end)
    print(string.format("[Railroader] depot: teleported to the loco (%.0f,%.0f,%.0f)%s.",
          x, y, z, (rec and rec.derailed) and " -- DERAILED" or ""))
    return true
end

--------------------------------------------------------------------------
-- DEBUG fence-test spawn (Task 1.N step 3). O drops a FRESH loco on route "main" at
-- the nearest distance to this world point and teleports the hero beside it, so we can
-- drive into fences to verify SMASHABLE. Point sits on the long straight x=12665 run of
-- "main". Change FENCE_TEST.{x,y} to test elsewhere; set FENCE_TEST.enabled=false to
-- give the O key its normal "goto Muldraugh depot shed" behaviour back.
--------------------------------------------------------------------------
-- OFF for field/beta play: while enabled it hijacked O (hero + a FRESH loco dropped at the
-- test point, wiping the one standing in the shed) and switched the obstacle sweep's
-- per-tick logging on. Both are development-only. Flip enabled=true with RR.Debug.set(true)
-- when returning to obstacle work.
Depot.FENCE_TEST = { enabled = false, debug = true, routeId = "main", x = 12738, y = 2436 }

-- distanceOnRoute(route, px, py): arc-length distance (route coord) of the nearest point
-- on the route polyline to (px,py). Mirrors projectPointOnPolyline but accumulates via
-- route.cum (RR_TrackData) so the result is a distance spawnOnRouteAt can consume.
local function distanceOnRoute(route, px, py)
    local nodes = route.nodes
    local bestD2, bestDist
    for i = 1, #nodes - 1 do
        local a, b = nodes[i], nodes[i + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local L2 = dx * dx + dy * dy
        local t = 0
        if L2 > 1e-9 then
            t = ((px - a.x) * dx + (py - a.y) * dy) / L2
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
        end
        local qx, qy = a.x + t * dx, a.y + t * dy
        local ex, ey = qx - px, qy - py
        local d2 = ex * ex + ey * ey
        if (not bestD2) or d2 < bestD2 then
            bestD2   = d2
            bestDist = (route.cum[i] or 0) + t * math.sqrt(L2)
        end
    end
    return bestDist
end

--------------------------------------------------------------------------
-- gotoFenceTest(): the O key while FENCE_TEST.enabled. Teleports the hero to the test
-- point (streams the chunk in) and spawns a fresh cold loco there, clearing any existing
-- one first so O always gives a clean test rig.
--------------------------------------------------------------------------
function Depot.gotoFenceTest()
    local FT = Depot.FENCE_TEST
    if not (RR.Routes and RR.Routes.exists(FT.routeId)) then
        print("[Railroader] fence-test: route '" .. tostring(FT.routeId) .. "' not registered.")
        return
    end
    if not (RR.TrainEntity and RR.TrainEntity.spawnOnRouteAt) then
        print("[Railroader] fence-test: TrainEntity not ready.")
        return
    end
    -- Turn on the obstacle-sweep debug logs automatically, so testing is push-O-and-drive
    -- with no console typing. (Set FENCE_TEST.debug = false to spawn without the logs.)
    if RR.ObstacleSweep and FT.debug ~= false then RR.ObstacleSweep.debug = true end

    local route = RR.Routes.get(FT.routeId)
    local dist  = distanceOnRoute(route, FT.x, FT.y)
    local z = 0
    pcall(function() z = Spline.sample(route, dist).z or 0 end)

    local p = getPlayer()
    if p then pcall(function() p:teleportTo(FT.x + 3, FT.y, z) end) end

    if RR.TrainEntity.active and #RR.TrainEntity.active > 0 and RR.TrainEntity.clear then
        pcall(function() RR.TrainEntity.clear() end)     -- always a clean rig on O
    end

    local rec = RR.TrainEntity.spawnOnRouteAt(FT.routeId, dist, nil, "fencetest")
    if rec then
        print(string.format(
            "[Railroader] fence-test: FRESH loco on '%s' at d=%.1f (world %.0f,%.0f,%.0f). "
            .. "E=board, reverser N + HOLD W=start (or G=cruise). Sweep debug logs are ON.",
            FT.routeId, dist, FT.x, FT.y, z))
    else
        print("[Railroader] fence-test: spawn FAILED (chunk not streamed yet?) -- press O again.")
    end
end

--------------------------------------------------------------------------
-- trySpawn(): the approach trigger. Spawns the depot loco if, and only if:
--   * this save has never spawned it (persistent flag),
--   * no loco is already active this session,
--   * the survivor is within DEPOT.radius of the shed AND its square is loaded.
-- Fuel / battery / diesel age are rolled from RR_Spawn against the world clock.
--------------------------------------------------------------------------
function Depot.trySpawn()
    if isClient() then return false end
    if RR.MP and RR.MP.blocked() then return false end   -- one loco per WORLD, and a client
                                                         -- cannot know it already exists (RR_MP)
    if not (RR.TrainEntity and RR.TrainEntity.spawnOnRouteAt) then return false end
    local wd = worldData()
    if wd and wd.rrLocoSpawned then return false end
    if #RR.TrainEntity.active > 0 then return false end

    local x, y, z = Depot.point()
    if not x then return false end

    local p = getPlayer()
    if not p then return false end
    local dx, dy = p:getX() - x, p:getY() - y
    if (dx * dx + dy * dy) > (Spawn.DEPOT.radius * Spawn.DEPOT.radius) then return false end

    -- The square must actually be streamed in, or addAnimal/addToWorld has nothing
    -- to stand on. Inside the radius it normally is; this is the cheap guard.
    local sq = nil
    pcall(function() sq = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z)) end)
    if not sq then return false end

    local days = Depot.daysSinceApo()
    local rolls = {
        ZombRandFloat(0, 1),   -- which fuel tier
        ZombRandFloat(0, 1),   -- where inside that tier
        ZombRandFloat(0, 1),   -- battery spread
        ZombRandFloat(0, 1),   -- mechanical condition
    }
    local eng, info = Spawn.rollEngine(days, rolls)

    local rec = RR.TrainEntity.spawnOnRouteAt(Spawn.DEPOT.routeId, Spawn.DEPOT.distance,
                                              eng, "depot")
    if not rec then
        print("[Railroader] depot: spawn FAILED (addAnimal returned nil?) -- will retry on the next pass.")
        return false
    end

    if wd then
        wd.rrLocoSpawned = true          -- one loco per world; never spawn it again
        wd.rrLocoSpawnDay = days
    end
    -- Depot service point (refuel reserve + pump object). Rolls the depot's diesel
    -- reserve once and stamps the pump beside the track at d = DEPOT.distance.
    if RR.ServiceDepot then pcall(function() RR.ServiceDepot.onSpawn(ZombRandFloat(0, 1)) end) end
    print(string.format(
        "[Railroader] depot: found K&L 800 in the shed on day %.0f since the apocalypse -- "
        .. "fuel %s (%.0f%%), battery %.0f%%, diesel quality %.0f%%, condition %.0f%%.",
        days, info.fuelTier, info.fuelFrac * 100, eng.battery * 100,
        eng.fuelQuality * 100, eng.condition * 100))
    return true
end

--------------------------------------------------------------------------
-- Poll on a ~1s cadence (the check is a distance compare against one point --
-- and it stops running the moment the loco exists).
--------------------------------------------------------------------------
local tick = 0
local function onTick()
    tick = tick + 1
    if tick < 60 then return end
    tick = 0
    pcall(Depot.trySpawn)
end
Events.OnTick.Add(onTick)

local function onKey(key)
    if not (RR.Debug and RR.Debug.isOn()) then return end   -- field mode: walk to the depot
    if key == Keyboard.KEY_O then
        if Depot.FENCE_TEST and Depot.FENCE_TEST.enabled then
            Depot.gotoFenceTest()          -- DEBUG: hero + fresh loco at the fence-test point
        elseif not Depot.gotoLoco() then   -- normal: straight to the loco, wherever it stands
            Depot.gotoDepot()              -- none yet: to the shed; it spawns on approach
        end
    end
end
Events.OnKeyPressed.Add(onKey)

RR = RR or {}
RR.Depot = Depot
print("[Railroader] RR_Depot.lua: loaded OK (K&L 800 materialises on approach to the Muldraugh shed; O = gated dev teleport to the loco, else to the shed)")

return Depot
