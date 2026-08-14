--***********************************************************************
-- Railroader / RR_TrainEntity
--
-- Spawns a custom moving entity (B42 animal = IsoPlayer subclass) and drives it
-- along a route by SETTING its position from the spline every tick (animal AI is
-- suppressed). Two spawn modes:
--   * spawnOnRoute(id)  -> spawn at a REAL route's node[1] in TRUE world coords
--                          (Task 1.B; no player offset).
--   * spawnDemo()       -> spawn the hardcoded demo polyline OFFSET to the player
--                          (legacy vertical-slice test, when no real route exists).
--
-- Grounded in decompiled B42 (rev 964): IsoAnimal extends IsoPlayer (full
-- movement / 3D render / depth sort); global spawn addAnimal(cell,x,y,z,type,
-- breed)+addToWorld(); setForwardDirection(dx,dy) for facing; behavior
-- setBlockMovement(true) to hold the line (auto-clears ~8s -> re-assert per tick).
--***********************************************************************

print("[Railroader] RR_TrainEntity.lua: loading...")
require("Railroader/RR_Spline")
require("Railroader/RR_Body")
require("Railroader/RR_DemoRoute")
require("Railroader/RR_Routes")
require("Railroader/RR_TrackGraph")
require("Railroader/RR_Drive")
require("Railroader/RR_Engine")
require("Railroader/RR_Lights")

local Spline    = RR.Spline
local DemoRoute = RR.DemoRoute
local Drive     = RR.Drive
local Engine    = RR.Engine
local Lights    = RR.Lights
print("[Railroader] RR_TrainEntity.lua: loaded OK (Spline=" .. tostring(Spline ~= nil)
      .. " DemoRoute=" .. tostring(DemoRoute ~= nil) .. " Drive=" .. tostring(Drive ~= nil) .. ")")

local TrainEntity = {}
TrainEntity.active     = {}          -- list of { animal=, route=, routeId=, distance=, drive=, reverser=, throttle=, brakeInput=, ... }
TrainEntity.captured   = {}          -- in-session coord capture (J key) for authoring routes
TrainEntity.animalType = "rr_loco"   -- custom skinned-model type (Task 1.A-art); falls back to cow
TrainEntity.adopted    = {}          -- session set: animalId -> true (dedupe re-adoption on load; Task 1.G)

local ROUTE_DEMO = "@demo"           -- modData routeId sentinel for the offset demo polyline

-- Forward declaration: reanchor is defined lower (it uses onTick-era helpers) but is
-- called from spawn / reacquire above it, so the upvalue must exist first.
local reanchor

--------------------------------------------------------------------------
-- Suppress the animal's own wander/pathfinding. Kahlua cannot write Java fields,
-- so use setBlockMovement(true). It auto-clears after ~8s in
-- BaseAnimalBehavior.wanderIdle, so we re-assert it every tick (see onTick).
--------------------------------------------------------------------------
local function suppressAI(animal, behavior)
    pcall(function() animal:setGodMod(true) end)        -- no damage/death interfering (player path)
    -- IsoAnimal has its OWN huntable health that godMod does NOT protect -- only invincibility
    -- does (IsoAnimal.setHealth drops health only when !isInvincible, IsoAnimal.java:1192; a
    -- vehicle Hit() sets health 0, IsoAnimal.Hit). Use the IsoAnimal setter setIsInvincible --
    -- NOT setInvincible: the IsoGameCharacter setInvincible is capability-gated and SILENTLY
    -- FORCES the flag back to false for a plain animal (IsoGameCharacter.java:14128), which is
    -- why the loco still "died" after collisions. setIsInvincible writes the field directly.
    -- (isDead() for an animal is just health<=0 -- no BodyDamage -- so guarding health suffices.)
    -- Without this a thrown/wrecked car colliding with the loco drained its health to 0 over
    -- several hits -> isDead() -> the rider was ejected every tick (board/step-off loop, loco
    -- braked to a stop, could not re-board). Revive a pre-fix loco that already died.
    pcall(function() animal:setIsInvincible(true) end)
    pcall(function() if (animal:getHealth() or 1) <= 0 then animal:setHealth(100) end end)
    if behavior then
        pcall(function() behavior:setBlockMovement(true) end)
    end
end

--------------------------------------------------------------------------
-- Half the truck-centre spacing for this loco, in tiles (cached per record). The
-- loco is a rigid body on two trucks, so its pose is the CHORD between the rail
-- points at distance +/- this -- that is what stops the body snapping through the
-- 45-degree kink where map rails turn. See RR.Spline.bodyPose / RR.Body.
--------------------------------------------------------------------------
local function halfWheelbase(rec)
    if rec.hw then return rec.hw end
    local size = 0.7
    if rec.animal then pcall(function() size = rec.animal:getAnimalSize() end) end
    rec.hw = (RR.Body and RR.Body.halfWheelbase(size)) or 0
    return rec.hw
end

--------------------------------------------------------------------------
-- Distance -> the pose we actually render/collide with: the rigid-body (two-truck)
-- pose, in WORLD coords (route-local + the record's world offset).
--------------------------------------------------------------------------
local function poseFor(rec, distance)
    local pose = Spline.bodyPose(rec.route, distance, halfWheelbase(rec))
    pose.x = pose.x + (rec.ox or 0)
    pose.y = pose.y + (rec.oy or 0)
    pose.z = pose.z + (rec.oz or 0)
    return pose
end

--------------------------------------------------------------------------
-- Snap an entity onto a pose produced by the spline.
--------------------------------------------------------------------------
local function applyPose(animal, pose)
    -- Per-direction render alignment offset (RR_Calibrate tool). World tiles.
    -- Mutates the pose table so RR_Ride (reads e.lastPose) keeps the rider aligned.
    if RR.Calib then
        local ox, oy, oz = RR.Calib.offsetFor(pose.dirX or 0, pose.dirY or 0)
        pose.x = pose.x + ox
        pose.y = pose.y + oy
        pose.z = pose.z + (oz or 0)
    end
    animal:setX(pose.x)
    animal:setY(pose.y)
    animal:setZ(pose.z)
    -- Face the spline direction (v1.0.2 fix, matches the reference mod): the
    -- visible 3D model yaw is the AnimationPlayer angle, normally synced from the
    -- forward vector by the character update path -- which is gated for our
    -- AI-suppressed, manually-positioned animal. setTargetAndCurrentDirection sets
    -- the vector AND snaps the AnimationPlayer angle, so the box rotates to match
    -- the rails immediately. Snapping suits a rigid train.
    animal:setTargetAndCurrentDirection(pose.dirX, pose.dirY)
end

--------------------------------------------------------------------------
-- Persistence (Task 1.G). The loco is a REAL IsoAnimal, so PZ saves & reloads it
-- on its own -- BUT its load path (IsoAnimal.load) restores only an 8-way
-- IsoDirections facing and nothing re-drives it, so after a reload the loco sits
-- at the right SPOT yet rotated wrong (not along the rails) and inert. The fix is
-- data, not a Java hook: stash the route id + signed distance (+ world offset for
-- the demo route) into the animal's modData -- which IsoAnimal.save/load DOES
-- round-trip -- and on load re-adopt the orphaned animal back into `active`
-- (see reacquire). onTick then snaps it to the exact spline pose again, which
-- restores the correct rail-aligned facing and driving. Keys are rr*-prefixed to
-- avoid clobbering vanilla animal modData (skinned/AnimalType/...).
--------------------------------------------------------------------------
local function stashState(e)
    if not e.animal then return end
    local md = e.animal:getModData()
    md.rrLoco     = true
    md.rrRouteId  = e.routeId
    md.rrDistance = e.distance
    md.rrOx       = e.ox
    md.rrOy       = e.oy
    md.rrOz       = e.oz
    md.rrReverser = e.reverser
    md.rrRider    = e.rider and true or false   -- was the player seated as driver at save? (re-mount on reload)
    -- The exact facing vector we posed with this tick. PZ's IsoAnimal.load restores
    -- only an 8-way IsoDirections facing -- too coarse to re-pick a branch's travel
    -- sign on reload -- so the tangent we actually rendered is the authority reanchor
    -- reads back (see adoptAnimal). rrDistance alone is NOT enough on a switch route:
    -- it is an arc length on the per-loco through-route, meaningless on the base route.
    if e.lastPose then
        md.rrDirX = e.lastPose.dirX
        md.rrDirY = e.lastPose.dirY
    end
    -- Engine start state (engine-start mechanic): persist so a loco saved running
    -- reloads running, and fuel/battery survive across sessions.
    if e.engine then
        md.rrEngineOn = e.engine.running and true or false
        md.rrFuel     = e.engine.fuel
        md.rrBattery  = e.engine.battery
        -- Rolled at world spawn (RR_Spawn: stale diesel / how well the unit was
        -- kept), so they must round-trip too -- otherwise a reload would silently
        -- hand the player a fresh-fuel, mint-condition loco.
        md.rrFuelQ    = e.engine.fuelQuality
        md.rrCond     = e.engine.condition
    end
    -- Derailment (Task 1.N step 6): a derailed loco is TERMINAL -- persist the flag AND the
    -- frozen off-rail pose so reacquire restores the exact wreck spot/facing and never resumes
    -- driving. Distance/route are meaningless once off the rails, so the pose IS the state.
    md.rrDerailed = e.derailed and true or false
    if e.derailed and e.derailPose then
        md.rrDerailX  = e.derailPose.x
        md.rrDerailY  = e.derailPose.y
        md.rrDerailZ  = e.derailPose.z
        md.rrDerailDX = e.derailPose.dirX
        md.rrDerailDY = e.derailPose.dirY
    end
    -- Light switches (Task 1.K). Persisting these is the whole point of the battery
    -- drain: park at dusk with the headlight on, save, come back tomorrow to a loco
    -- that won't crank. Without the round-trip the mistake would silently un-make
    -- itself on reload.
    if e.lightState then
        md.rrHead      = e.lightState.head or 0
        md.rrCabLight  = e.lightState.cab and true or false
    end
    -- Cooling-water temperature (Task 1.P). Worth a round-trip because the block cools
    -- over ~40 minutes of game time: park a hot loco, reload, and it should still be
    -- warm enough to heat the cab -- not reset to the temperature of the air.
    if e.cab and e.cab.waterC then md.rrWaterC = e.cab.waterC end
end

--------------------------------------------------------------------------
-- Core spawn: put one entity on a BUILT route at (ox,oy,oz) offset, at signed
-- distance opts.distance along the route (default 0 = node[1]) and with the
-- engine state opts.engine (default a fresh cold full-tank one).
-- Returns the active record, or nil on failure. Shared by all spawn modes.
--------------------------------------------------------------------------
local function spawnEntityOnBuiltRoute(route, ox, oy, oz, label, routeId, opts)
    local player = getPlayer()
    if not player then return nil end
    opts = opts or {}
    local cell  = getCell()
    local dist  = opts.distance or 0
    -- Spawn tile = the CENTRE point at that distance (the rigid-body pose needs the
    -- animal's size, which only exists once it is spawned -- onTick/applyPose below
    -- immediately re-poses it properly).
    local start = Spline.sample(route, dist)
    local sx, sy, sz = start.x + ox, start.y + oy, (start.z or 0) + oz

    -- Resolve type + a real breed (nil breed NPEs inside IsoAnimal.init).
    local animalType = TrainEntity.animalType
    local adef = AnimalDefinitions.getDef(animalType)
    if not adef then
        print("[Railroader] type '" .. tostring(animalType) .. "' not defined; falling back to cow")
        animalType = "cow"
        adef = AnimalDefinitions.getDef(animalType)
        if not adef then print("[Railroader] cow def missing too; abort"); return nil end
    end
    local breed = adef:getRandomBreed()

    local animal = addAnimal(cell, math.floor(sx), math.floor(sy), math.floor(sz),
                             animalType, breed)
    if not animal then
        print("[Railroader] addAnimal returned nil (water/chickenpocalypse guard?)")
        return nil
    end
    animal:addToWorld()   -- register on the grid square (risk #1)
    local behavior = animal:getBehavior()
    suppressAI(animal, behavior)

    local rec = {
        animal   = animal,
        behavior = behavior,
        route    = route,
        routeId  = routeId,              -- for modData persistence / re-adoption (Task 1.G)
        baseId   = routeId,              -- base route for the switch graph (RR_TrackGraph)
        distance = dist,
        -- Drive-loop state (Task 1.D). Spawns PARKED & idle: reverser Neutral,
        -- throttle 0, no brake. Physics lives in the pure RR_Drive module; the
        -- control inputs below are written by G (debug cruise) or RR_Ride (manual).
        drive      = Drive.newState(),   -- { v (m/s), brakeLevel }
        -- Engine spawns COLD. The driver must crank it (hold W in the cab); until
        -- running, throttle delivers no power (see onTick's effective-throttle gate).
        -- Fuel/battery/fuel-age come from the caller: the world spawn (RR_Depot)
        -- rolls them from RR_Spawn, while the debug spawns get a fresh full tank.
        engine     = opts.engine or Engine.newState(),
        reverser   = 0,                  -- -1 R / 0 N / +1 F
        throttle   = 0,                  -- 0 (idle) .. 8 (Run 8)
        brakeInput = 0,                  -- 0..1 requested independent brake
        speed      = 0,                  -- m/s, mirror of drive.v for HUD
        ox = ox, oy = oy, oz = oz,
        label = label,
    }
    table.insert(TrainEntity.active, rec)
    pcall(function() TrainEntity.adopted[animal:getAnimalID()] = true end)  -- own this loco this session
    -- Snap to the exact rigid-body pose right away (the addAnimal tile above is only
    -- the rounded centre point), so the loco is rail-aligned on the very first frame
    -- it is drawn -- it must not appear askew inside the shed and straighten later.
    local pose = poseFor(rec, rec.distance)
    applyPose(animal, pose)
    rec.lastPose = pose
    reanchor(rec)                                     -- adopt the switch-graph route (no-op if no graph)
    stashState(rec)                                   -- seed modData so a save right after spawn persists
    if RR.Sound then RR.Sound.onSpawn(rec) end        -- attach engine sound (Task 1.E)
    if RR.Collider then RR.Collider.onSpawn(rec) end  -- build the physical collider chain
    if RR.LightsRender then RR.LightsRender.onSpawn(rec) end  -- headlight/boards (Task 1.K)
    if RR.CabClimate then RR.CabClimate.onSpawn(rec) end      -- cab shelter/warmth (Task 1.P)
    return rec
end

--------------------------------------------------------------------------
-- spawnOnRouteAt(id, distance, engine, label): spawn on a registered REAL route
-- in true world coords, `distance` tiles along it, with a caller-supplied engine
-- state. This is the WORLD spawn path (RR_Depot: the loco found in the shed) --
-- no teleport, no assumptions: the caller must already have the chunk loaded
-- (it only fires when the player is standing nearby).
--------------------------------------------------------------------------
function TrainEntity.spawnOnRouteAt(routeId, distance, engine, label)
    if RR.MP and RR.MP.blocked() then return nil end   -- connected client: never spawn (RR_MP)
    routeId = routeId or (RR.Routes and RR.Routes.DEFAULT_ID)
    if not (RR.Routes and RR.Routes.exists(routeId)) then
        print("[Railroader] no route '" .. tostring(routeId)
              .. "' registered. Capture coords with J, then edit RR_RealRoutes.lua.")
        return nil
    end
    local route = RR.Routes.get(routeId)
    return spawnEntityOnBuiltRoute(route, 0, 0, 0, label or ("route:" .. routeId), routeId,
                                   { distance = distance or 0, engine = engine })
end

--------------------------------------------------------------------------
-- spawnOnRoute(id): DEBUG spawn at node[1] of a real route, teleporting the
-- player beside it first (the loco lands at a fixed world point the player may
-- be chunks away from, and addAnimal/addToWorld need that chunk streamed in;
-- teleportTo is the vanilla debug-tool call). Fresh full tank, charged battery.
-- The real, in-game way a loco appears is RR_Depot (shed spawn on approach).
--------------------------------------------------------------------------
function TrainEntity.spawnOnRoute(routeId)
    routeId = routeId or (RR.Routes and RR.Routes.DEFAULT_ID)
    if not (RR.Routes and RR.Routes.exists(routeId)) then
        print("[Railroader] no route '" .. tostring(routeId) .. "' registered.")
        return nil
    end
    local s = RR.Routes.get(routeId).nodes[1]
    local player = getPlayer()
    if player then
        pcall(function() player:teleportTo(s.x + 3, s.y, s.z or 0) end)
    end
    local rec = TrainEntity.spawnOnRouteAt(routeId, 0, nil, "debug:" .. routeId)
    if rec then
        print("[Railroader] DEBUG-spawned COLD loco ON route '" .. routeId .. "' at world ("
              .. s.x .. "," .. s.y .. "," .. (s.z or 0) .. "); teleported player beside it."
              .. " E = board, then reverser N + HOLD W to start. (G = debug cruise.)")
    end
    return rec
end

--------------------------------------------------------------------------
-- spawnDemo(): legacy vertical-slice test. Spawns the demo polyline OFFSET to
-- the player (its route-local coords sit near (0,0), i.e. the map void).
--------------------------------------------------------------------------
function TrainEntity.spawnDemo(offsetToPlayer)
    local player = getPlayer()
    if not player then return nil end
    local route = DemoRoute.build()
    local start = route.nodes[1]
    local ox, oy, oz = 0, 0, 0
    if offsetToPlayer ~= false then
        ox, oy, oz = player:getX() - start.x, player:getY() - start.y, 0
    end
    local rec = spawnEntityOnBuiltRoute(route, ox, oy, oz, "demo", ROUTE_DEMO)
    if rec then
        print("[Railroader] spawned COLD demo entity (parked, offset to player). E = board, then N + HOLD W to start. (G = debug cruise.)")
    end
    return rec
end

--------------------------------------------------------------------------
-- spawn(): legacy debug spawn (real route if registered, else the offset demo).
-- No longer bound to a key: the loco now enters the world only through the depot
-- (RR_Depot -- it is standing in the shed when you first walk in). Kept for the
-- console / a route with no depot authored.
--------------------------------------------------------------------------
function TrainEntity.spawn()
    local id = RR.Routes and RR.Routes.DEFAULT_ID
    if RR.Routes and id and RR.Routes.exists(id) then
        return TrainEntity.spawnOnRoute(id)
    end
    print("[Railroader] no real route yet -> spawning offset DEMO. (Author one in RR_RealRoutes.lua.)")
    return TrainEntity.spawnDemo()
end

--------------------------------------------------------------------------
-- Seconds elapsed this tick, frame-rate INDEPENDENT (Task 1.D). getMultiplier()
-- ~= 0.8 * fpsMultiplier * gameSpeed, so /DT_PER_MULT (48) yields real seconds at
-- 1x game speed. Falls back to a 60fps/1x value off-engine.
--
-- TWO steps come out of it (RR_Drive.dtGame / dtSim):
--   * dtGame -- game time, scales with fast-forward: fuel, battery, warm-up.
--   * dtSim  -- capped at DT_MAX: physics, pose, collider, crush. Fast-forward (or a
--     frame hitch) would otherwise hand us a ~0.7 s step = a 20 m jump per tick, and
--     the crush/collider sweep only samples the footprint ONCE per tick -> the body
--     teleports through zombies and through route corners. While the loco is being
--     DRIVEN the game is held at 1x anyway (RR_Ride, mirroring CarController), so
--     the cap only ever bites on a hitch or on a driverless debug cruise.
--------------------------------------------------------------------------
local function currentMult()
    local gt = getGameTime and getGameTime()
    local mult = 0.8
    if gt then pcall(function() mult = gt:getMultiplier() end) end
    return mult
end

--------------------------------------------------------------------------
-- Rebuild the BUILT route a persisted loco was on. Real routes are re-registered
-- from RR_RealRoutes.lua every session, so RR.Routes.get resolves them; the demo
-- polyline is rebuilt from RR_DemoRoute. Returns nil if the id is unknown now
-- (e.g. a route the player deleted) -- caller then leaves that loco untouched.
--------------------------------------------------------------------------
local function buildRouteFor(routeId)
    if routeId == ROUTE_DEMO then return DemoRoute.build() end
    if RR.Routes and RR.Routes.exists(routeId) then return RR.Routes.get(routeId) end
    return nil
end

--------------------------------------------------------------------------
-- Re-adopt one loaded rr_loco animal that carries our modData back into `active`.
-- Idempotent per session via TrainEntity.adopted[animalId] (animalId persists
-- across reload, so a fresh Lua state -- i.e. a real save reload -- re-adopts,
-- while repeat scans in the same session don't duplicate). Snaps the loco to its
-- exact spline pose right away, which is what corrects the reload rotation.
--------------------------------------------------------------------------
local function adoptAnimal(animal)
    if not animal then return false end
    local md = animal:getModData()
    if not (md and md.rrLoco) then return false end        -- not one of ours
    local id = animal:getAnimalID()
    if TrainEntity.adopted[id] then return false end        -- already owned this session

    local routeId = md.rrRouteId or (RR.Routes and RR.Routes.DEFAULT_ID)
    local route   = buildRouteFor(routeId)
    if not route then
        print("[Railroader] reload: loco animalId=" .. tostring(id)
              .. " references unknown route '" .. tostring(routeId) .. "'; leaving it as-is.")
        return false
    end

    local behavior = animal:getBehavior()
    suppressAI(animal, behavior)

    -- Restore the engine's start state (engine-start mechanic). A loco saved with
    -- the engine RUNNING reloads running & warm (resumes parked, v=0, throttle 0
    -- like the drive state), so the driver isn't forced to re-crank on every load;
    -- fuel & battery carry over. A cold-saved loco reloads cold.
    local engine = Engine.newState()
    engine.fuel        = tonumber(md.rrFuel)    or engine.fuel
    engine.battery     = tonumber(md.rrBattery) or engine.battery
    engine.fuelQuality = tonumber(md.rrFuelQ)   or engine.fuelQuality
    engine.condition   = tonumber(md.rrCond)    or engine.condition
    -- Don't resume running an out-of-order loco (condition 0): it would only stall on the
    -- first tick (immobilization stall, below) and honk its shutdown on load. Reloads cold.
    -- A DERAILED loco (Task 1.N step 6) is likewise dead: engine stays OFF on reload.
    if md.rrEngineOn and not md.rrDerailed
       and (engine.condition or 1) > (Engine.C.IMMOBILIZE_AT or 0) then
        Engine.forceStart(engine)
    end

    -- Light switches come back exactly as they were left (Task 1.K) -- including a
    -- headlight left burning, which is the whole reason the battery drains.
    local lightState = Lights.newState()
    lightState.head = tonumber(md.rrHead) or Lights.OFF
    lightState.cab  = md.rrCabLight and true or false

    local rec = {
        animal   = animal,
        behavior = behavior,
        route    = route,
        routeId  = routeId,
        baseId   = routeId,              -- base route for the switch graph (RR_TrackGraph)
        engine   = engine,
        distance = tonumber(md.rrDistance) or 0,
        -- Resume PARKED (v=0, throttle idle, no brake input) for safety: a loco
        -- that was cruising at save time won't lurch off the instant you load in.
        -- Reverser is preserved so the driver's last direction is remembered.
        drive      = Drive.newState(),
        reverser   = tonumber(md.rrReverser) or 0,
        throttle   = 0,
        brakeInput = 0,
        speed      = 0,
        ox = tonumber(md.rrOx) or 0,
        oy = tonumber(md.rrOy) or 0,
        oz = tonumber(md.rrOz) or 0,
        rider = md.rrRider and true or false,   -- restore seated-driver state (Task 1.G)
        lightState = lightState,                -- restore the light switches (Task 1.K)
        label = "reloaded:" .. tostring(routeId),
    }
    -- Derailment (Task 1.N step 6): a loco saved DERAILED comes back off the rails at its
    -- exact frozen pose, engine off, controls dead -- never resumes driving. The pose is the
    -- authority (route/distance are meaningless off-rail); fall back to the animal's own saved
    -- x,y if a coord is missing.
    if md.rrDerailed then
        rec.derailed  = true
        rec.derailPose = {
            x    = tonumber(md.rrDerailX)  or animal:getX(),
            y    = tonumber(md.rrDerailY)  or animal:getY(),
            z    = tonumber(md.rrDerailZ)  or (animal:getZ() or 0),
            dirX = tonumber(md.rrDerailDX) or 1,
            dirY = tonumber(md.rrDerailDY) or 0,
        }
    end
    if not route.looped then
        if rec.distance < 0 then rec.distance = 0
        elseif rec.distance > route.length then rec.distance = route.length end
    end

    table.insert(TrainEntity.active, rec)
    TrainEntity.adopted[id] = true

    -- Re-anchor onto the switch graph from the animal's TRUE saved pose -- BEFORE we
    -- pose it. On a branch, rrDistance is an arc length measured on the per-loco
    -- through-route, so applying it to the freshly-built BASE route lands dozens of
    -- tiles off with the wrong tangent. The IsoAnimal's own saved x,y (+ the facing
    -- vector we stashed) is the authority: graphLocate re-derives the correct
    -- route/distance/orientation from it. This MUST run before any applyPose -- a pose
    -- applied here would overwrite getX/getForwardDirection, so reanchor would then
    -- locate from the already-corrupted point (that was the reload-drift bug). No-op
    -- without a graph, where rrDistance is portable and stays correct as-is.
    do
        local wx, wy = animal:getX() - (rec.ox or 0), animal:getY() - (rec.oy or 0)
        local fx, fy = tonumber(md.rrDirX), tonumber(md.rrDirY)
        if not fx then
            pcall(function() local d = animal:getForwardDirection(); if d then fx, fy = d:getX(), d:getY() end end)
        end
        reanchor(rec, wx, wy, fx, fy)
    end

    -- Now snap to the exact pose THIS tick so the facing is fixed immediately (don't wait for
    -- the next onTick pass). A DERAILED loco snaps to its FROZEN off-rail pose (not the spline,
    -- which would flash it back onto the rails for a frame); otherwise reanchor above already set
    -- rec.route / rec.distance to the branch the loco was actually on.
    local pose
    if rec.derailed and rec.derailPose then
        local dp = rec.derailPose
        pose = { x = dp.x, y = dp.y, z = dp.z, dirX = dp.dirX, dirY = dp.dirY }
    else
        pose = poseFor(rec, rec.distance)
    end
    applyPose(animal, pose)
    rec.lastPose = pose

    if RR.Sound then RR.Sound.onSpawn(rec) end
    if RR.Collider then RR.Collider.onSpawn(rec) end
    -- Re-adoption, not a fresh spawn: rebuild rather than onSpawn, because any light
    -- this loco had belongs to a session that is gone (the engine culls IsoLightSources
    -- whose tile leaves the loaded chunk map, and gives us no callback when it does).
    -- The switches themselves are NOT persisted yet -- a reloaded loco comes back dark.
    if RR.LightsRender then RR.LightsRender.rebuild(rec) end
    -- Cab climate (Task 1.P): the water temperature carries over, so a loco parked hot
    -- reloads hot. The heat source itself is NOT persisted (nothing world-side is) --
    -- onSpawn starts with none and the first reconcile places it.
    if RR.CabClimate then RR.CabClimate.onSpawn(rec, tonumber(md.rrWaterC)) end

    -- If the player was seated as driver at save time, put them back in the cab
    -- (setBlockMovement + camera pin + controls). rec.lastPose is set above, so the
    -- remount snaps them onto the seat rather than leaving them standing inside.
    if rec.rider and RR.Ride and RR.Ride.mountRecord then
        pcall(function() RR.Ride.mountRecord(rec, true) end)
    end

    print("[Railroader] re-adopted loco animalId=" .. tostring(id) .. " on route '" .. routeId
          .. "' at distance " .. string.format("%.1f", rec.distance) .. " (orientation restored).")
    return true
end

--------------------------------------------------------------------------
-- Scan the loaded cell for orphaned rr_loco animals and re-adopt them. Cheap
-- (usually 0-1 locos); runs on a ~1s interval from onTick + once on game start so
-- it fires after a reload once the loco's chunk has streamed in.
--------------------------------------------------------------------------
function TrainEntity.reacquire()
    if RR.MP and RR.MP.blocked() then return 0 end     -- connected client: don't adopt a
                                                       -- replicated rr_loco and start posing it
    local cell = getCell()
    if not cell then return 0 end
    local list = cell:getAnimals()
    if not list then return 0 end
    local n = 0
    for i = 0, list:size() - 1 do
        if adoptAnimal(list:get(i)) then n = n + 1 end
    end
    -- After (re-)adoption, cull stray collider segments left over from a prior
    -- session (they persist as animals but nothing re-pins them; see sweepOrphans).
    -- Runs every scan; owned/fresh segments are kept, so it's a no-op once clean.
    if RR.Collider and RR.Collider.sweepOrphans then pcall(RR.Collider.sweepOrphans) end
    return n
end

--------------------------------------------------------------------------
-- Re-anchor a loco's ACTIVE route on the switch graph, CENTRED on its current
-- world position and heading. Because the new route passes through the loco's exact
-- position (at arc sHere), swapping to it is always pose-continuous -- no teleport,
-- no "committed-past-the-fork" gate needed. This is also what makes a switch facing
-- AGAINST travel usable: re-anchoring once the loco is past it puts that switch on
-- the behind-walk, so backing up takes its branch (RR.TrackGraph.materializeThrough).
--
-- Called on the events that can change which rails are reachable: a switch thrown,
-- the loco reversing its travel direction, and spawn/reload. Optional wx,wy,fx,fy
-- override the position/facing (used on reload from the IsoAnimal's saved pose).
--------------------------------------------------------------------------
function reanchor(e, wx, wy, fx, fy)
    if not (e.baseId and RR.TrackGraph and RR.TrackGraph.has(e.baseId)) then return end
    if not wx then
        if not e.route then return end
        local p = Spline.sample(e.route, e.distance or 0)
        wx, wy = p.x - (e.ox or 0), p.y - (e.oy or 0)
    end
    if not fx then
        fx = (e.lastPose and e.lastPose.dirX) or 1
        fy = (e.lastPose and e.lastPose.dirY) or 0
    end
    local loc = RR.TrackGraph.graphLocate(RR.TrackGraph.netEdges(e.baseId), wx, wy)
    if not loc then return end
    local dir = ((fx * loc.tx + fy * loc.ty) >= 0) and 1 or -1
    local route, sHere = RR.TrackGraph.buildThrough(e.baseId, { edge = loc.edge, s = loc.s, dir = dir })
    if not route then return end
    e.route         = route
    e.distance      = sHere
    e.routeStateKey = RR.TrackGraph.stateKey(e.baseId)
end

--------------------------------------------------------------------------
-- BROKEN (open) rail ends (Task 1.N step 6). A handful of authored end nodes carry
-- `open = true` in RR_RealRoutes.lua (cw_end, brandenburg, freight_terminal_2_end, ...) --
-- torn-up rails with no buffer. Reaching one AT SPEED derails; every other end clamp-stops.
--
-- The flag lives on route/edge NODE tables but does NOT survive RR_TrackGraph.materialize
-- (its push() copies only x/y/z/name), so a per-loco through-route loses it. We instead match
-- the reached endpoint against the authored open-end COORDINATES -- robust to materialization.
-- Built once (routes are registered at load, before any loco moves) and cached.
--------------------------------------------------------------------------
TrainEntity.DERAIL_OFFSET   = 1.5   -- tiles: small lateral off-rail shove for the frozen wreck pose
TrainEntity.DERAIL_YAW_DEG  = 22    -- deg: yaw the frozen heading off the rail line so the wreck sits
                                    -- at an ANGLE (jackknife), not merely shifted parallel. 0 = old parallel slide.
TrainEntity.DERAIL_SETTLE_TIME = 0.4  -- s: slide/rotate from the on-rail pose to the final wreck pose
                                      -- (ease-out lurch) instead of teleporting. 0 = instant snap.
local OPEN_END_TOL = 3.0          -- tiles: proximity match of a route end to an authored open end
local _openEnds
local function openEndList()
    if _openEnds then return _openEnds end
    _openEnds = {}
    local function scan(nodes)
        if type(nodes) ~= "table" then return end
        for _, n in ipairs(nodes) do
            if n.open then _openEnds[#_openEnds + 1] = { x = n.x, y = n.y } end
        end
    end
    if RR.Routes and RR.Routes.defs then
        for _, def in pairs(RR.Routes.defs) do scan(def and def.nodes) end
    end
    if RR.TrackGraph and RR.TrackGraph.defs then
        for _, d in pairs(RR.TrackGraph.defs) do
            for _, nodes in pairs(d.edges or {}) do scan(nodes) end
        end
    end
    return _openEnds
end
local function isOpenEndNear(wx, wy)
    for _, oe in ipairs(openEndList()) do
        local dx, dy = oe.x - wx, oe.y - wy
        if dx * dx + dy * dy <= OPEN_END_TOL * OPEN_END_TOL then return true end
    end
    return false
end

--------------------------------------------------------------------------
-- derail(e, absV, cause): put a loco into the TERMINAL off-rails state (Task 1.N step 6).
-- Condition-INDEPENDENT (distinct from the Step-5 immobilize soft-lock): the loco DETACHES
-- from the spline and freezes at a dead off-rail pose (captured here = the current pose nudged
-- a little sideways off the rails), engine OFF, controls refuse (HUD DERAILED). It is an
-- IsoAnimal, so this is state + a small displacement + an impact one-shot -- NOT a deformed
-- mesh (a wreck mesh is a later art task, honest about the limit as the crush doc is about
-- ragdoll). The depot-spawn flag stays SET (no replacement). Idempotent.
--------------------------------------------------------------------------
function TrainEntity.derail(e, absV, cause)
    if not e or e.derailed then return end
    absV = absV or math.abs((e.drive and e.drive.v) or 0)
    -- Freeze at the current pose + a small lateral off-rail displacement (doc: state +
    -- displacement, not a mesh). poseFor gives a fresh table, so mutating it is safe.
    local pose = poseFor(e, e.distance)
    -- Capture the ON-RAILS pose (pre-displacement) as the START of the settle slide.
    local startPose = { x = pose.x, y = pose.y, z = pose.z, dirX = pose.dirX, dirY = pose.dirY }
    local rx, ry = -(pose.dirY or 0), (pose.dirX or 0)      -- right of travel
    local rl = math.sqrt(rx * rx + ry * ry)
    if rl > 1e-6 then rx, ry = rx / rl, ry / rl else rx, ry = 1, 0 end
    local off = TrainEntity.DERAIL_OFFSET or 1.5
    pose.x = pose.x + rx * off
    pose.y = pose.y + ry * off
    -- Yaw the frozen heading toward the off-rail side (the same (rx,ry) it slid) so the wreck sits
    -- at an ANGLE instead of exactly parallel to the rails -- a real derail jackknifes, a pure
    -- lateral slide reads as "still on the line". +yaw rotates the tangent toward the right vector
    -- (rx,ry), so the nose kicks the way the body went. A little random spread per wreck; dirX/dirY
    -- start as the exact rail tangent. Baked into e.derailPose (persisted), so reload keeps this angle.
    local fx, fy = pose.dirX or 0, pose.dirY or 0
    local yaw = math.rad(TrainEntity.DERAIL_YAW_DEG or 0)
    if yaw ~= 0 then
        pcall(function() yaw = yaw * ZombRandFloat(0.6, 1.15) end)   -- spread; deterministic 1.0 in tests
        local c, s = math.cos(yaw), math.sin(yaw)
        pose.dirX = fx * c - fy * s
        pose.dirY = fx * s + fy * c
    end
    e.derailPose = pose
    -- Settle slide: animate startPose -> derailPose over DERAIL_SETTLE_TIME instead of snapping
    -- (a lurch off the rails reads better than a teleport). Transient (NOT persisted): a reload
    -- mid-slide just shows the final wreck pose. 0 => instant.
    local dur = TrainEntity.DERAIL_SETTLE_TIME or 0
    e.derailAnim = (dur > 0) and { t = 0, dur = dur, from = startPose } or nil
    e.derailed   = true
    if e.drive then e.drive.v = 0; e.drive.brakeLevel = 0 end
    e.throttle   = 0
    -- Release the brake at the wreck. Drive.step no longer runs once derailed, so it can't ramp
    -- brakeLevel back down -- if the driver held Space at the moment of the derail it would stay
    -- "applied" forever and the brake apply/squeal LOOP (Sound.update reads e.drive.brakeLevel)
    -- would play non-stop. Zero both the input and the ramped level here; tickDerailed re-asserts
    -- them each tick so a still-held Space (RR_Ride keeps polling) can't re-apply it.
    e.brakeInput = 0
    -- Engine dies (organs fail). Same shutdown as a stall -- no shutdown honk here: the derail
    -- one-shot IS the sound event.
    if e.engine and Engine then Engine.stop(e.engine) end
    -- Derail one-shot: blast + metal-debris collapse layered on the speed tier (RR_Sound already
    -- supports the `derailed` flag). Reused for both triggers (impact + broken end).
    if RR.Sound and RR.Sound.hardImpact then
        pcall(function() RR.Sound.hardImpact(e, absV, true) end)
    end
    -- Zombie-audible half, scaled by the CAUSE (this is the only place that knows it):
    -- a strike hard enough to put 112 t on the ground is horn-loud, whereas running off a
    -- broken open end just drops the wheels into the ballast -- a grind, not a bang. Passing
    -- the contact class ("hard") vs nil is what selects DERAIL_IMPACT vs DERAIL_ALONE.
    if RR.Sound and RR.Sound.impactNoise then
        local kind = (cause == "hard impact") and "hard" or nil
        pcall(function() RR.Sound.impactNoise(e, kind, absV, nil, nil, nil, true) end)
    end
    stashState(e)   -- persist immediately so a save right after the wreck keeps it derailed
    print(string.format("[Railroader] DERAILED (%s) at v=%.2f m/s (%.0f km/h) -- terminal, off the rails.",
          tostring(cause or "?"), absV, absV * 3.6))
end

--------------------------------------------------------------------------
-- tickDerailed(e, dt): per-tick handling for a DERAILED loco. The driving pipeline is
-- SKIPPED (no Drive.step / ObstacleSweep / reanchor / end-clamp / throttle -- organs fail),
-- but we STILL applyPose the FROZEN pose so the alpha/cull pin, the collider pin and the
-- rider pin keep working against a frozen frame instead of vanishing (the animal would
-- otherwise drift off under its own AI). A copy is posed each tick so the per-direction
-- Calib offset applyPose adds can't accumulate into e.derailPose.
--------------------------------------------------------------------------
local function tickDerailed(e, dt, dtGame)
    if e.behavior then pcall(function() e.behavior:setBlockMovement(true) end) end
    local dp = e.derailPose
    if not dp then return end
    -- Settle slide (DERAIL_SETTLE_TIME): ease-out from the on-rail START pose to the final wreck
    -- pose over a few ticks, so the loco lurches off the rails instead of teleporting. dt is the
    -- capped sim step (fast-forward/hitch safe). Once done, e.derailAnim is cleared and every
    -- later tick poses the final wreck pose directly.
    local pose
    local anim = e.derailAnim
    if anim then
        anim.t = (anim.t or 0) + (dt or 0)
        local u = anim.t / (anim.dur or 1)
        if u >= 1 then u = 1; e.derailAnim = nil end
        local eu = 1 - (1 - u) * (1 - u)                       -- ease-out (fast then settle)
        local f  = anim.from
        local dx = f.dirX + (dp.dirX - f.dirX) * eu            -- nlerp the heading (small angle => fine)
        local dy = f.dirY + (dp.dirY - f.dirY) * eu
        local dl = math.sqrt(dx * dx + dy * dy)
        if dl > 1e-6 then dx, dy = dx / dl, dy / dl else dx, dy = dp.dirX, dp.dirY end
        pose = { x = f.x + (dp.x - f.x) * eu, y = f.y + (dp.y - f.y) * eu,
                 z = (f.z or 0) + ((dp.z or 0) - (f.z or 0)) * eu, dirX = dx, dirY = dy }
    else
        pose = { x = dp.x, y = dp.y, z = dp.z, dirX = dp.dirX, dirY = dp.dirY }
    end
    applyPose(e.animal, pose)
    pcall(function() e.animal:setAlphaAndTarget(1.0) end)
    e.speed    = 0
    e.lastPose = pose
    -- Keep the controls dead against the frozen wreck. RR_Ride.onTick loads BEFORE us and may
    -- re-poll a still-held Space into e.brakeInput; force everything to rest here (before
    -- Sound.update, which reads e.drive.brakeLevel) so the brake apply/squeal loop stays silent.
    e.brakeInput = 0
    e.throttle   = 0
    if e.drive then e.drive.brakeLevel = 0 end
    if RR.Ride and RR.Ride.current == e and RR.Ride.pinRider then
        RR.Ride.pinRider(e)
    end
    stashState(e)
    if RR.Sound then RR.Sound.update(e, dt) end        -- engine off => loops silenced, mix stays coherent
    if RR.Collider then RR.Collider.update(e, dt) end  -- keep the collider pinned to the wreck
    if RR.LightsRender then RR.LightsRender.update(e, dt) end
    -- Cab shelter/warmth (Task 1.P) keeps running on a wreck: it is still a cab with a
    -- roof and a seat in it, and the block goes on giving up its heat for half an hour
    -- after the engine died. Same call as the driving path, so a driver who survived the
    -- derail can sit out the rain in it -- which is the same reason he is allowed to
    -- sleep in it (RR_SleepRules).
    if RR.CabClimate then RR.CabClimate.update(e, dtGame or dt) end
    -- No Crush: a stationary derailed loco is a wall, not a weapon.
end

--------------------------------------------------------------------------
-- Per-tick driver. Integrates each entity's physics (RR_Drive) into a signed 1D
-- distance and snaps it onto the spline pose. Open routes stop hard at the ends
-- (buffer stop): distance is clamped and speed zeroed so it can't "wind up".
--------------------------------------------------------------------------
local reacquireTick = 0
local function onTick()
    if RR.MPClient or (RR.MP and RR.MP.blocked()) then return end
                                                       -- server owns the drive/pose/crush loop in MP
    -- Re-adopt persisted locos after a reload / chunk stream-in (Task 1.G). Must
    -- run BEFORE the empty-active early-out: on load `active` is empty until we do.
    reacquireTick = reacquireTick + 1
    if reacquireTick >= 60 then
        reacquireTick = 0
        pcall(TrainEntity.reacquire)
    end

    if #TrainEntity.active == 0 then return end
    local mult   = currentMult()
    local dtGame = Drive.dtGame(mult)   -- clock time: fuel / battery / warm-up
    local dt     = Drive.dtSim(mult)    -- motion step, capped (see currentMult)
    for _, e in ipairs(TrainEntity.active) do
        if e.animal and not e.animal:isDead() and e.derailed then
            -- TERMINAL off-rails state (Task 1.N step 6): skip the whole driving pipeline, just
            -- pin the frozen wreck pose (+ collider/rider/alpha). Same-depth elseif below keeps
            -- the driving branch un-re-indented.
            tickDerailed(e, dt, dtGame)
        elseif e.animal and not e.animal:isDead() then
            -- Re-assert AI suppression: setBlockMovement auto-clears after ~8s.
            if e.behavior then pcall(function() e.behavior:setBlockMovement(true) end) end

            -- Post-stall restart cool-down (Task 1.N step 5): tick down on GAME time so it
            -- also elapses under fast-forward. The starter is gated on it in RR_Ride.
            if (e._restartCooldown or 0) > 0 then
                e._restartCooldown = math.max(0, e._restartCooldown - dtGame)
            end

            -- Engine gate (engine-start mechanic): a running engine burns fuel by
            -- load, recharges its battery, and warms up (limiting power for a few
            -- seconds after catching). When NOT running the throttle delivers no
            -- tractive power at all -- but the loco can still coast and be braked,
            -- so an off engine on a grade will roll. Fuel exhaustion stalls it.
            local effThrottle = e.throttle or 0
            local eng = e.engine
            if eng then
                if eng.running then
                    -- Chemistry runs on GAME time: an idling loco left under x40
                    -- fast-forward drinks its tank 40x faster, like a running car.
                    Engine.warmupTick(eng, dtGame)
                    local load = ((e.drive and e.drive.notchEff) or 0) / Drive.C.NOTCH_MAX
                    if Engine.runTick(eng, dtGame, load) then  -- tank just ran dry
                        Engine.stop(eng)
                        if RR.Sound and RR.Sound.engineStall then pcall(function() RR.Sound.engineStall(e) end) end
                        print("[Railroader] engine STALLED (out of fuel).")
                    end

                    -- Periodic UNDER-LOAD stall (Task 1.N step 5): a worn engine can die at
                    -- random while pulling. ONLY while in traction (throttle > 0) and below
                    -- STALL_AT -- an idling/coasting loco must never die on its own (that just
                    -- annoys). The timer accrues GAME time of loaded running; every
                    -- STALL_CHECK_PERIOD it rolls stallChancePerMin. reacquire still leaves eng
                    -- valid here (we're inside `if eng.running`).
                    if eng.running and (e.throttle or 0) > 0
                       and (eng.condition or 1) < Engine.C.STALL_AT then
                        e._stallTimer = (e._stallTimer or 0) + dtGame
                        if e._stallTimer >= Engine.C.STALL_CHECK_PERIOD then
                            e._stallTimer = 0
                            local pd = Engine.stallChancePerMin(eng.condition)
                            if pd > 0 and ZombRandFloat(0, 1) < pd then
                                TrainEntity.stallEngine(e, "load")
                            end
                        end
                    end
                    -- Licence gate (Task 1.F): an unlicensed driver in the seat gets notch
                    -- 0 -- a running loco still coasts and brakes under them, it just makes
                    -- no tractive power. An EMPTY cab (debug G cruise) is unrestricted.
                    -- IMMOBILIZATION (Task 1.N step 5): maxNotch ALSO returns 0 when condition
                    -- has fallen to 0, so a run-down loco makes no power even while the diesel
                    -- runs -- the immobilize gate lives inside maxNotch (pure), so this line
                    -- (already the running-throttle clamp) needs no change to honour it.
                    local env = e.rider and { licensed = e.licensed ~= false } or nil
                    effThrottle = math.min(effThrottle, Engine.maxNotch(eng, env))
                else
                    effThrottle = 0
                end
            end

            -- Condition traction debuff (Task 1.N step 5): a worn engine makes less tractive
            -- effort and can't reach line speed. tractionMult is 1.0 while healthy (cond >= 0.5),
            -- ramping to ~0.5 as condition dies (floored so it can always crawl home). Fed as a
            -- pure input into RR_Drive (scales force + caps V_MAX).
            local tractionMult = eng and Engine.tractionMult(eng.condition or 1) or 1.0
            local controls = { reverser = e.reverser, throttle = effThrottle,
                               brakeInput = e.brakeInput, tractionMult = tractionMult }
            local d0 = e.distance
            local delta = Drive.step(e.drive, controls, dt)
            e.distance = e.distance + delta

            -- Obstacles on the rails (Task 1.N):
            --   step 2 HARD  -- a solid tile / railcar / concrete under the leading edge
            --                   halts the loco AT contact (clamp distance, zero velocity),
            --                   no phasing through.
            --   step 3 SMASH -- a fence/gate/window/door is DESTROYED and the loco keeps
            --                   rolling, bleeding a small fraction of its speed (dvFrac);
            --                   distance is NOT clamped.
            -- Sub-samples the swept span so a thin obstacle between ticks is not skipped.
            -- Runs BEFORE pose/collider/crush so the outcome is what gets rendered.
            -- (Shove/wreck for cars land in a later step.)
            if RR.ObstacleSweep then
                local res = RR.ObstacleSweep.update(e, d0, e.distance, dt)
                if res and res.stopped then
                    e.distance = res.distance
                    e.drive.v  = 0
                    delta      = e.distance - d0     -- keep moveSign/reanchor consistent
                elseif res and res.dvFrac and res.dvFrac > 0 then
                    -- Smashed something: shed a little speed, keep rolling (distance stands).
                    e.drive.v = e.drive.v * (1 - res.dvFrac)
                end

                -- HARD impact (railcar / another loco): apply CONDITION damage (Step 5) and, if
                -- the hit is strong enough, DERAIL (Step 6, owner decision A) -- ONCE per contact,
                -- using the speed AT impact. The _hardImpactDone latch is cleared the moment the
                -- loco is not HARD-stopped, so holding the throttle against a railcar (tiny lurches,
                -- ~0 damage) never re-drains condition -- only a genuine run-up does.
                -- Derail is DETERMINISTIC + condition-independent: |v| >= V_DERAIL_IMPACT (high) and
                -- CONFIRMED HARD inside the swept chord (Obs.shouldDerailImpact). No probabilistic
                -- roll (deferred to a future re-railing plan, owner B). The false-derail surface is
                -- exactly the sweep's HARD-detect quality (high threshold, anti-tunnel, no rr_ animals).
                local Obs = RR.Obstacle
                local hardStop = res and res.stopped and Obs and res.impactClass == Obs.CLASS.HARD
                if hardStop then
                    if not e._hardImpactDone then
                        local v   = res.impactV or 0
                        local dmg = Obs.impactDamage(Obs.CLASS.HARD, v)
                        if dmg > 0 and e.engine and e.engine.condition then
                            e.engine.condition = math.max(0, e.engine.condition - dmg)
                        end
                        e._hardImpactDone = true
                        local willDerail = Obs.shouldDerailImpact(Obs.CLASS.HARD, v)
                        print(string.format(
                            "[Railroader] HARD impact: v=%.2f m/s (%.0f km/h) dmg=%.3f cond=%.2f%s",
                            v, v * 3.6, dmg, (e.engine and e.engine.condition) or -1,
                            willDerail and " -> DERAIL (>= V_DERAIL_IMPACT)" or ""))
                        -- ALWAYS-ON trigger diagnostic (what did the sweep call HARD?): which scan
                        -- fired, which solidity flag, the world tile, and every sprite on it. Lets a
                        -- FALSE HARD (e.g. the loco's own switch/track read via HARD_USE_COLLIDE) be
                        -- identified from one crash, without the per-tick Sweep.debug spam.
                        local liveSize = -1
                        pcall(function() liveSize = e.animal:getAnimalSize() end)
                        print(string.format(
                            "[Railroader] HARD trigger: via=%s flags=%s tile(%.0f,%.0f) lat=%.2f/halfW=%.2f size=%.3f sprites=[%s]",
                            tostring(res.impactVia or "?"), tostring(res.impactFlags or "?"),
                            res.impactX or 0, res.impactY or 0,
                            res.impactW or 0, res.impactHalfW or 0, liveSize, tostring(res.impactSprites or "")))
                        if willDerail then
                            -- derail() plays the derail one-shot (blast + debris over the tier).
                            TrainEntity.derail(e, v, "hard impact")
                        elseif RR.Sound and RR.Sound.hardImpact then
                            -- Just the tiered crash foley -- no derail layer (once per contact).
                            pcall(function() RR.Sound.hardImpact(e, v, false) end)
                        end
                    end
                else
                    e._hardImpactDone = false   -- moving / smashing / creep-stop: re-arm
                end
            end

            -- Immobilization STALL (Task 1.N step 5, owner 2026-07-24): the moment condition
            -- reaches 0 -- from a collision debit above (HARD/VEHICLE/BARRIER) or a debug set --
            -- a still-running diesel is SHUT DOWN, via the SAME path as a fuel stall / a driver's
            -- HOLD-S: Engine.stop + RR.Sound.engineStop. engineStop is a fire-and-forget one-shot
            -- on the loco's ANIMAL emitter (Sound.update only zeroes the world-emitter loops, never
            -- stopAll), so the multi-second shutdown spin-down PLAYS TO COMPLETION on its own.
            -- Guarded by eng.running so it fires exactly once (stop clears running); at condition 0
            -- startChance is 0, so it also can't be cranked back until a repair path exists.
            if eng and eng.running and (eng.condition or 1) <= (Engine.C.IMMOBILIZE_AT or 0) then
                Engine.stop(eng)
                if RR.Sound and RR.Sound.engineStop then pcall(function() RR.Sound.engineStop(e) end) end
                -- Immobilization does NOT brake: the loco keeps its momentum and coasts (speed
                -- logged so an eventual halt can be told from the coast -- if it stops it was an
                -- external obstacle, not this).
                print(string.format("[Railroader] condition 0 -> engine SHUT DOWN (out of order, coasting). speed=%.2f m/s",
                    (e.drive and e.drive.v) or 0))
            end

            -- Re-anchor the route on the switch graph when what's reachable can change:
            -- a switch was thrown, or the loco reversed its travel direction (the latter
            -- is how backing past a facing-against switch reaches its branch). Centred
            -- on the loco's position, so it never teleports (see reanchor).
            if e.baseId and RR.TrackGraph and RR.TrackGraph.has(e.baseId) then
                local moveSign = (delta > 1e-6) and 1 or ((delta < -1e-6) and -1 or 0)
                local stateChanged = RR.TrackGraph.stateKey(e.baseId) ~= e.routeStateKey
                local reversed = (moveSign ~= 0 and e.railDir and moveSign ~= e.railDir)
                if stateChanged or reversed then
                    reanchor(e)
                end
                if moveSign ~= 0 then e.railDir = moveSign end
            end

            if not e.route.looped then
                local hitStart = e.distance < 0
                local hitEnd   = e.distance > e.route.length
                if hitStart or hitEnd then
                    local clampD = hitStart and 0 or e.route.length
                    -- BROKEN open rail end (Task 1.N step 6): reaching an authored open end while
                    -- moving derails; a buffered/normal end (or an open end at a crawl) clamp-stops
                    -- safely as before. Match the reached ENDPOINT (route centreline at the clamp,
                    -- + world offset) against the authored open-end coords -- the `open` node flag
                    -- doesn't survive graph materialization, so we go by coordinate.
                    local absV = math.abs(e.drive.v or 0)
                    if not e.derailed and RR.Obstacle and RR.Obstacle.shouldDerailEnd(absV) then
                        local ep = Spline.sample(e.route, clampD)
                        local ex = ep.x + (e.ox or 0)
                        local ey = ep.y + (e.oy or 0)
                        if isOpenEndNear(ex, ey) then
                            TrainEntity.derail(e, absV, "broken rail end")
                        end
                    end
                    e.distance = clampD
                    e.drive.v  = 0
                end
            end
            e.speed = e.drive.v

            -- Rigid-body (two-truck) pose, already world-offset. Chording the rails
            -- between the trucks is what keeps the body from snapping through the
            -- 45-degree kink at a route corner (RR.Spline.bodyPose).
            local pose = poseFor(e, e.distance)
            applyPose(e.animal, pose)
            -- Force full visibility (defeat inherited animal culling). A character's
            -- render alpha is judged by IsoGameCharacter.TestIfSeen against its ORIGIN
            -- point only (getX/getY = body centre): if that single square is behind the
            -- driver / outside his vision cone, updateSeenVisibility sets targetAlpha=0
            -- and the WHOLE 15-tile mesh fades out. Harmless while the driver sat ON the
            -- centre (dist~=0 => always "seen"), but any off-centre cab seat exposes it.
            -- setAlphaAndTarget pins both current + target to 1 each tick, overriding the
            -- cull before render. Two array writes; the engine runs TestIfSeen regardless,
            -- so this adds no LOS work. Collider segments stay invisible (not touched).
            pcall(function() e.animal:setAlphaAndTarget(1.0) end)
            e.lastPose = pose          -- exposed for the rider probe (RR_Ride)
            -- Pin a seated driver to the loco THIS frame, right after the pose is set,
            -- so the camera (which tracks the player's instantaneous getX) and the loco
            -- share the SAME pose in the SAME frame. Pinning from RR_Ride's own OnTick
            -- ran a frame early (it loads before us) -> camera lagged the loco by v*dt ->
            -- speed-scaled jitter along the travel axis. See RR_Ride.pinRider.
            if RR.Ride and RR.Ride.current == e and RR.Ride.pinRider then
                RR.Ride.pinRider(e)
            end
            stashState(e)              -- keep modData current so a save at any moment persists (Task 1.G)
            if RR.Sound then RR.Sound.update(e, dt) end       -- drive the sound layer (Task 1.E)
            if RR.Collider then RR.Collider.update(e, dt) end -- re-pin collider segments
            if RR.Crush then RR.Crush.update(e, dt) end       -- run over zombies (Task 1.H)
            if RR.LightsRender then RR.LightsRender.update(e, dt) end  -- headlight/boards (Task 1.K)
            -- Cab shelter/warmth (Task 1.P). dtGAME, like fuel and the battery: the
            -- cooling water is chemistry, not motion, so it warms and cools at the
            -- fast-forwarded rate rather than the capped physics one.
            if RR.CabClimate then RR.CabClimate.update(e, dtGame) end
        end
    end
end
Events.OnTick.Add(onTick)

-- After a save is loaded, try once as soon as the game is up (the periodic scan
-- in onTick is the safety net if the loco's chunk hasn't streamed in yet).
Events.OnGameStart.Add(function() pcall(TrainEntity.reacquire) end)

--------------------------------------------------------------------------
-- Remove all spawned entities (so you can re-run cleanly).
--------------------------------------------------------------------------
function TrainEntity.clear()
    for _, e in ipairs(TrainEntity.active) do
        if RR.Sound then RR.Sound.onRemove(e) end      -- stop loops + free emitter (Task 1.E)
        if RR.Collider then RR.Collider.onRemove(e) end -- despawn collider segments
        if RR.LightsRender then RR.LightsRender.onRemove(e) end  -- drop the light sources (Task 1.K)
        if RR.CabClimate then RR.CabClimate.onRemove(e) end      -- drop the cab heat source (Task 1.P)
        if e.animal then
            -- Drop the persistence flag so a removed loco is NOT re-adopted next scan.
            pcall(function() e.animal:getModData().rrLoco = false end)
            pcall(function() e.animal:removeFromWorld(); e.animal:removeFromSquare() end)
        end
    end
    TrainEntity.active  = {}
    TrainEntity.adopted = {}   -- release session ownership so re-spawns can be re-adopted
    -- Debug convenience: clearing also forgets that the world's depot loco was ever
    -- spawned, so walking back into the shed re-spawns a fresh one (new fuel/battery
    -- rolls). Without this, P would permanently delete the only loco in the save.
    if RR.Depot and RR.Depot.forget then pcall(RR.Depot.forget) end
    print("[Railroader] cleared entities.")
end

--------------------------------------------------------------------------
-- stallEngine(e, reason): the engine DIES while running at low condition (Task 1.N step 5) --
-- a throttle-up stall or a periodic under-load stall (NOT the condition-0 out-of-order stop,
-- which is terminal). Shared outcome:
--   * Engine.stop -> tractive power gone; the loco COASTS, brakes still work.
--   * lever dropped to idle so the restart doesn't lurch the moment it catches.
--   * a 5-10 s RESTART COOL-DOWN before the starter will turn again (gated in RR_Ride); the
--     restart itself is the normal crank, whose catch chance already follows the gentle
--     conditionStartFactor curve (so at low condition it may take 1-2 attempts).
--   * the same shutdown one-shot as any stop (plays to completion on the animal emitter).
-- reason is just for the log. Cooldown is randomised per stall.
--------------------------------------------------------------------------
function TrainEntity.stallEngine(e, reason)
    local eng = e and e.engine
    if not (eng and eng.running and Engine) then return end
    Engine.stop(eng)
    e.throttle    = 0            -- drop the lever: restart from idle, no lurch
    e._stallTimer = 0
    local lo, hi = Engine.C.RESTART_COOL_MIN or 5, Engine.C.RESTART_COOL_MAX or 10
    local cd = lo
    pcall(function() cd = ZombRandFloat(lo, hi) end)
    e._restartCooldown = cd
    if RR.Sound and RR.Sound.engineStop then pcall(function() RR.Sound.engineStop(e) end) end
    if e.rider then
        pcall(function()
            local p = getPlayer()
            if p then HaloTextHelper.addBadText(p, getText("IGUI_RR_Stalled")) end
        end)
    end
    print(string.format("[Railroader] engine STALLED (%s, condition %.2f) -- cooling down %.1fs before restart.",
          tostring(reason), eng.condition or -1, cd))
end

--------------------------------------------------------------------------
-- G = DEBUG auto-cruise (drive with nobody in the cab). Manual driving from the
-- seat (RR_Ride, W/S/R/Space) writes the same control inputs. "Start" = reverser
-- Forward + notch 4; "Stop" = idle throttle + full brake (coasts/brakes to rest).
--------------------------------------------------------------------------
function TrainEntity.setMoving(on)
    for _, e in ipairs(TrainEntity.active) do
        if on then
            -- Debug bypass of the start mechanic: cruise should "just go", so skip
            -- the crank/warm-up and put the engine straight into full-power running.
            if e.engine and Engine then Engine.forceStart(e.engine) end
            e.reverser = 1; e.throttle = 4; e.brakeInput = 0
        else
            e.throttle = 0; e.brakeInput = 1     -- brake to a stop, keep reverser
        end
    end
    print("[Railroader] debug cruise " .. (on and "STARTED (notch 4 F)" or "STOPPED (braking)"))
end

function TrainEntity.toggleMoving()
    local any = false
    for _, e in ipairs(TrainEntity.active) do if (e.throttle or 0) > 0 then any = true; break end end
    TrainEntity.setMoving(not any)
end

--------------------------------------------------------------------------
-- DEBUG (Task 1.N step 6): force the ridden loco (else the first active one) into the
-- terminal DERAILED state from the console, to verify the frozen off-rail pose / engine off /
-- dead controls / HUD DERAILED / save-reload persistence without having to stage a real crash.
--   RR.TrainEntity.forceDerail()
--------------------------------------------------------------------------
function TrainEntity.forceDerail()
    local e = (RR.Ride and RR.Ride.current) or TrainEntity.active[1]
    if not e then print("[Railroader] forceDerail: no active loco."); return end
    TrainEntity.derail(e, math.abs((e.drive and e.drive.v) or 0), "debug")
end

--------------------------------------------------------------------------
-- Coord capture (Task 1.B authoring aid; precursor to the 1.C editor).
-- J: record the player's current tile and reprint the whole list in paste-ready
--    node form. H: clear the list. Copy the printed lines into RR_RealRoutes.lua.
--------------------------------------------------------------------------
local function round3(v) return math.floor(v * 1000 + 0.5) / 1000 end

-- Snap tolerances (tiles). ANY captured node within SNAP_RADIUS of an existing
-- authored line magnetises onto it -- so a branch START placed ~on its junction and
-- a branch END merging into another line both snap, while mid-branch nodes on new
-- rail never do (a 45-deg turnout is already ~0.7 tile clear one node out). Kept
-- TIGHT so it only fires when you deliberately stand on the line -- it can't grab a
-- parallel track. Shift+J forces a snap up to SNAP_FORCE_MAX to rescue a near miss.
local SNAP_RADIUS    = 0.1
local SNAP_FORCE_MAX = 2.0

-- projectPointOnPolyline: nearest point on a node list to (px,py). Returns qx,qy,dist.
local function projectPointOnPolyline(nodes, px, py)
    local bx, by, bd
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
        local d = math.sqrt(ex * ex + ey * ey)
        if (not bd) or d < bd then bd, bx, by = d, qx, qy end
    end
    return bx, by, bd
end

-- nearestAuthored: closest point across ALL authored geometry (registered routes +
-- every track-graph edge) to (px,py). Returns { x, y, d, id } or nil. This is what
-- lets a new branch magnetise onto an already-drawn line at a shared junction.
local function nearestAuthored(px, py)
    local best
    local function consider(id, nodes)
        if type(nodes) ~= "table" or #nodes < 2 then return end
        local x, y, d = projectPointOnPolyline(nodes, px, py)
        if x and ((not best) or d < best.d) then best = { x = x, y = y, d = d, id = id } end
    end
    if RR.Routes and RR.Routes.defs then
        for id, def in pairs(RR.Routes.defs) do consider(id, def and def.nodes) end
    end
    if RR.TrackGraph and RR.TrackGraph.defs and RR.TrackGraph.netEdges then
        for netId in pairs(RR.TrackGraph.defs) do
            for eid, nodes in pairs(RR.TrackGraph.netEdges(netId)) do consider(eid, nodes) end
        end
    end
    return best
end

-- railSpriteUnderFoot: name of a "railroad" sprite on the player's tile, or nil.
-- A centreline capture must be taken standing ON a rail; this flags an off-rail J.
local function railSpriteUnderFoot(p)
    local cell = getCell()
    if not cell then return nil end
    local sq = cell:getGridSquare(math.floor(p:getX()), math.floor(p:getY()),
                                  math.floor(p:getZ() + 0.5))
    if not sq then return nil end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local spr = objs:get(i):getSprite()
        local name = spr and spr:getName() or nil
        if name and string.find(name, "railroad") then return name end
    end
    return nil
end

-- captureCoord(forceSnap): record the player's sub-tile position as a route node.
-- Any node within SNAP_RADIUS of an authored line auto-snaps onto it (junction start
-- or merge end); forceSnap (Shift+J) snaps up to SNAP_FORCE_MAX to rescue a near miss.
function TrainEntity.captureCoord(forceSnap)
    local p = getPlayer()
    if not p then return end
    -- Keep the SUB-TILE float: the whole point of standing centred between the
    -- rails is to trace the true centreline, so we must NOT floor to a tile corner.
    -- Round to 0.001 tile (well below what matters) purely to keep the paste tidy.
    local x = round3(p:getX())
    local y = round3(p:getY())
    local z = math.floor(p:getZ() + 0.5)           -- ground rails: keep z integral
    local rail = railSpriteUnderFoot(p)

    -- Magnetise onto existing geometry at a shared junction (branch start) or a merge
    -- (branch end). Tight radius: only a node deliberately placed on the line snaps.
    local near    = nearestAuthored(x, y)
    local snapped = false
    if near then
        local tol = forceSnap and SNAP_FORCE_MAX or SNAP_RADIUS
        if near.d <= tol then
            x, y, snapped = round3(near.x), round3(near.y), true
        end
    end

    table.insert(TrainEntity.captured, { x = x, y = y, z = z })
    if snapped then
        print(string.format("[Railroader] captured node #%d SNAPPED->'%s' (moved %.3f) at (%.3f, %.3f, %d)  rail=%s",
              #TrainEntity.captured, near.id, near.d, x, y, z, rail or "NONE"))
    else
        -- Only hint about a nearby authored line when it is close enough that a snap
        -- would make sense (a non-first node next to a junction it should merge into).
        local hint = ""
        if near and near.d <= SNAP_FORCE_MAX then
            hint = string.format("  [near '%s' %.2f away -- Shift+J to snap]", near.id, near.d)
        end
        print(string.format("[Railroader] captured node #%d at (%.3f, %.3f, %d)  rail=%s%s",
              #TrainEntity.captured, x, y, z, rail or "NONE <-- off-rail?", hint))
    end
    print("[Railroader] ----- paste into RR_RealRoutes.lua  nodes = { ... } -----")
    for _, c in ipairs(TrainEntity.captured) do
        print(string.format("        { x = %.3f, y = %.3f, z = %d },", c.x, c.y, c.z))
    end
    print("[Railroader] ----- end (" .. #TrainEntity.captured .. " nodes) -----")
end

function TrainEntity.clearCaptured()
    TrainEntity.captured = {}
    print("[Railroader] captured node list cleared.")
end

--------------------------------------------------------------------------
-- Tile/sprite dump (switch authoring aid). T: print the sprite name of every
-- IsoObject on the player's tile and its 8 neighbours, flagging railroad ones.
-- Stand ON or next to a switch stand to read off its exact sprite -- the index
-- encodes the facing, so this is how we learn the name of each of the two
-- orientations for both placement and the context-menu anchor.
--------------------------------------------------------------------------
function TrainEntity.dumpTiles()
    local p = getPlayer()
    if not p then return end
    local cell = getCell()
    if not cell then return end
    local px = math.floor(p:getX())
    local py = math.floor(p:getY())
    local pz = math.floor(p:getZ() + 0.5)
    print("[Railroader] ----- tile dump around (" .. px .. "," .. py .. "," .. pz .. ") -----")
    for dy = -1, 1 do
        for dx = -1, 1 do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    local spr = o:getSprite()
                    local name = spr and spr:getName() or nil
                    if name then
                        local flag = string.find(name, "railroad") and "   <-- RAILROAD" or ""
                        print(string.format("  (%d,%d) obj[%d] %s%s", px + dx, py + dy, i, name, flag))
                    end
                end
            end
        end
    end
    print("[Railroader] ----- end tile dump -----")
end

--------------------------------------------------------------------------
-- Switch throw (debug; precursor to the context menu). N: toggle the switch
-- nearest the player between NORMAL (straight/main) and REVERSE (diverge onto the
-- branch). A loco approaching the fork picks up the new state and takes the chosen
-- track (see reanchor). State is persisted across reload (RR_SwitchPersist).
--------------------------------------------------------------------------
function TrainEntity.toggleNearestSwitch()
    if not RR.TrackGraph then print("[Railroader] no track graph loaded."); return end
    local p = getPlayer()
    if not p then return end
    local px, py = p:getX(), p:getY()
    local bestBase, bestSw, bestD
    for baseId, def in pairs(RR.TrackGraph.defs) do
        for _, sw in ipairs(def.switches) do
            local dx, dy = sw.at.x - px, sw.at.y - py
            local d = dx * dx + dy * dy
            if (not bestD) or d < bestD then bestD, bestBase, bestSw = d, baseId, sw end
        end
    end
    if not bestSw then print("[Railroader] no switches registered."); return end
    local nxt = RR.TrackGraph.toggleState(bestBase, bestSw.id)
    if RR.SwitchPersist then pcall(RR.SwitchPersist.save) end   -- persist across reload
    print(string.format("[Railroader] switch '%s' (%s) -> %s  [%.0f tiles away]",
          bestSw.id, bestBase, nxt, math.sqrt(bestD)))
    pcall(function() HaloTextHelper.addText(p, bestSw.id .. ": " .. nxt) end)
end

--------------------------------------------------------------------------
-- spawnAtSwitch(switchId, before): DEBUG console aid for testing a turnout far
-- from the depot. Teleports the player to just south of the switch and spawns a
-- WARM, forward-ready loco `before` tiles (default 40) before the fork, so you can
-- board (E), throttle up (W), throw the switch (N), and watch it take the branch.
--   RR.TrainEntity.spawnAtSwitch("s1")
--------------------------------------------------------------------------
function TrainEntity.spawnAtSwitch(switchId, before)
    before = before or 40
    if not RR.TrackGraph then print("[Railroader] no track graph."); return end
    local baseId, sw
    for bId, def in pairs(RR.TrackGraph.defs) do
        for _, s in ipairs(def.switches) do
            if s.id == switchId then baseId, sw = bId, s end
        end
    end
    if not sw then print("[Railroader] no switch '" .. tostring(switchId) .. "'."); return end
    local fd = RR.TrackGraph.forkDist(baseId, switchId)
    if not fd then print("[Railroader] cannot resolve fork distance."); return end
    local dist = math.max(0, fd - before)
    local p = getPlayer()
    -- "Before" the fork is at higher y (forward travel runs toward decreasing y),
    -- so drop the player just south of it where the loco's spawn tile streams in.
    if p then pcall(function() p:teleportTo(sw.at.x + 3, sw.at.y + before, sw.at.z or 0) end) end
    local engine = Engine.newState()
    Engine.forceStart(engine)
    local rec = TrainEntity.spawnOnRouteAt(baseId, dist, engine, "swtest:" .. switchId)
    if rec then rec.reverser = 1 end   -- reverser F: ready to drive forward at the fork
    print(string.format("[Railroader] spawned WARM loco %d tiles before switch '%s' (dist %.0f). "
          .. "E=board, W=throttle, N=throw switch.", before, switchId, dist))
    return rec
end

--------------------------------------------------------------------------
-- teleportToSwitch(switchId, before): bring BOTH the player and the loco to a
-- switch for testing (P key). If a loco already exists on that base route it is
-- re-placed `before` tiles (default 40) ahead of the fork, stopped and pointed
-- forward; otherwise a fresh warm loco is spawned there (spawnAtSwitch). The
-- player is dropped beside it unless they're seated (the rider pin follows).
--------------------------------------------------------------------------
function TrainEntity.teleportToSwitch(switchId, before)
    switchId = switchId or "s1"
    before   = before or 40
    if not RR.TrackGraph then print("[Railroader] no track graph."); return end
    local baseId, sw
    for bId, def in pairs(RR.TrackGraph.defs) do
        for _, s in ipairs(def.switches) do
            if s.id == switchId then baseId, sw = bId, s end
        end
    end
    if not sw then print("[Railroader] no switch '" .. tostring(switchId) .. "'."); return end
    local fd = RR.TrackGraph.forkDist(baseId, switchId)
    if not fd then print("[Railroader] cannot resolve fork distance."); return end
    local dist = math.max(0, fd - before)

    -- Find an existing loco on this base route.
    local rec
    for _, e in ipairs(TrainEntity.active) do
        if e.baseId == baseId and e.animal and not e.animal:isDead() then rec = e; break end
    end
    if not rec then
        return TrainEntity.spawnAtSwitch(switchId, before)   -- none yet: spawn one there
    end

    -- Re-place the existing loco `before` tiles before the fork, stopped, facing fwd.
    -- Put it on the depot-forward reference route at `dist` first, then re-anchor onto
    -- the per-loco graph route at that spot (fd/dist are arc lengths on that reference).
    local refRoute = RR.TrackGraph.buildActive(baseId)
    if refRoute then rec.route = refRoute; rec.distance = dist end
    rec.throttle   = 0
    rec.brakeInput = 0
    rec.reverser   = 1
    rec.railDir    = nil                       -- forget travel dir so the next move re-anchors clean
    if rec.drive then rec.drive.v = 0 end
    local pose = poseFor(rec, rec.distance)
    applyPose(rec.animal, pose)
    rec.lastPose = pose
    reanchor(rec)                              -- rebuild the switch-graph route centred here
    local pose2 = poseFor(rec, rec.distance)
    applyPose(rec.animal, pose2)
    rec.lastPose = pose2
    stashState(rec)

    -- Drop the player beside the loco (unless seated -- then the pin follows it).
    local p = getPlayer()
    if p and not (RR.Ride and RR.Ride.current == rec) then
        pcall(function() p:teleportTo(sw.at.x + 3, sw.at.y + before, sw.at.z or 0) end)
    end
    print(string.format("[Railroader] moved loco + player to switch '%s' (dist %.0f, %d tiles before fork).",
          switchId, dist, before))
    return rec
end

--------------------------------------------------------------------------
-- Debug keybinds -- ALL of them are gated on RR.Debug (off in a shipping/field build;
-- `RR.Debug.set(true)` in the console re-arms them). Driving keys live in RR_Ride and
-- are never gated.
--   G = debug cruise (auto-drive)   C = clear (also re-arms the depot spawn)
--   P = teleport player + loco to switch s1 (spawns one warm if none exists)
--   N = throw the nearest switch (NORMAL <-> REVERSE)   T = dump nearby tile sprites
--   J = capture player coord (author routes)   H = clear captured list
--   (O = teleport to the depot shed -- lives in RR_Depot, which also spawns the
--    loco there on approach; E = board and W/S/R/Space = driving live in RR_Ride)
--------------------------------------------------------------------------
local function onKey(key)
    if not (RR.Debug and RR.Debug.isOn()) then return end   -- field mode: no dev keys
    if key == Keyboard.KEY_G then TrainEntity.toggleMoving() end
    if key == Keyboard.KEY_P then TrainEntity.teleportToSwitch("s1") end
    if key == Keyboard.KEY_C then TrainEntity.clear() end
    if key == Keyboard.KEY_J then
        local force = Keyboard.isKeyDown(Keyboard.KEY_LSHIFT)
                      or Keyboard.isKeyDown(Keyboard.KEY_RSHIFT)
        TrainEntity.captureCoord(force)
    end
    if key == Keyboard.KEY_H then TrainEntity.clearCaptured() end
    if key == Keyboard.KEY_T then TrainEntity.dumpTiles() end
    if key == Keyboard.KEY_N then TrainEntity.toggleNearestSwitch() end
end
Events.OnKeyPressed.Add(onKey)
print("[Railroader] ready. Drive: E to board, then W/S throttle, R reverser, Space brake, F lights, Q horn, L bell."
      .. " (dev keys are gated -- RR.Debug.set(true) to re-arm)")

RR = RR or {}
RR.TrainEntity = TrainEntity

return TrainEntity
