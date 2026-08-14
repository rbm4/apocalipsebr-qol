if isClient() then return end

require("Railroader/RR_Body")
require("Railroader/RR_Obstacle")

local Collision = {}

-- v1.0.8 (SP v1.0.2 crush port): a loco keeps counting as "rolling" for
-- ROLL_GRACE seconds after dropping below V_ROLL, so a body it floored while
-- moving -- whose isOnFloor flag lands up to ~0.8 s later via the fall anim --
-- is still crushed when the loco brakes to a stop ON it. A loco parked long
-- enough for the grace to lapse is harmless to everything.
Collision.ROLL_GRACE = 1.0

--------------------------------------------------------------------------
-- v1.0.3 (car pass-through fix, FINAL FORM v1.0.3d): the server used to SMASH a
-- struck car but never MOVE it, and the per-tick 0.8 bleed lost to a held high
-- throttle (tractive effort at Run 8 balanced the bleed at ~0.18 m/s) -- so the
-- loco crept THROUGH the car (owner report: "持续高油门会慢慢穿过汽车").
--
-- Two server-side ways to MOVE the car were tried and BOTH failed (spike
-- RR_SpikeVehicleMove, 2026-08):
--   * applyImpulseGeneric / setActiveInBullet -- the dedicated server keeps a
--     parked car's Bullet body ASLEEP ("applyImpulseGeneric! ... isActive:
--     false") and never steps it, so the force is dropped and the car never
--     moves (the SP client can shove cars because its physics is live);
--   * vehicle:setX/setY -- succeeds (getX/getY change immediately) but the
--     server's own vehicle update overwrites the write within a tick (the
--     spike's 60-tick RECHECK shows the car back on its old square).
--
-- FINAL FALLBACK: a struck car stays on the rails -- wreck it ONCE and HARD-STOP
-- the loco at it. The stop holds while the car is in the probe (probing at ANY
-- speed, so a stopped loco cannot lurch through on the next throttle tick) and
-- releases automatically when the car leaves the probe (a player tows/pushes
-- the wreck off, or it is removed). No pass-through, no physics dependency.
--
-- v1.0.3d (relative-speed damage + car-vs-train): condition damage now uses the
-- RELATIVE closing speed (loco speed minus the car's speed along the rails), not
-- the loco's own speed -- a car moving WITH the loco barely dents it, a parked or
-- oncoming car hits full force. The CAR takes condition damage too (0 at a 5 km/h
-- crawl, full wreck at 60 km/h closing speed). A car that DRIVES INTO the loco
-- (body overlap -- side/rear hits, not the nose probe) is damaged once and
-- STOPPED: a MOVING car's Bullet body is active, so the outward impulse actually
-- lands (the parked-car impulse was dropped -- see above). The stop re-applies
-- every tick while the car stays against the loco, so a driver mashing the
-- throttle cannot push through.

local function noteErr(e, tag, err)
    local seen = Collision._errs or {}
    Collision._errs = seen
    local key = tostring((e and e.id) or "?")
    if not seen[key] then
        seen[key] = true
        print("[RailroaderMP] RR_ServerCollision " .. tag .. " failed: " .. tostring(err))
    end
end

local function safe(tag, fn, e)
    local ok, err = pcall(fn)
    if not ok then noteErr(e, tag, err) end
    return ok
end

--------------------------------------------------------------------------
-- v1.0.2 defensive pass: the old version called every engine API bare inside a
-- single outer pcall (RR_ServerTrain.stepOnce). One unavailable call on the
-- dedicated server (e.g. z:Kill(nil,...)) threw EVERY tick and the pcall
-- silently swallowed it -- no eject, no crush, no obstacle sweep at all ("zombies
-- and players walk through, no damage"). Now every engine interaction is wrapped
-- individually (same style as the SP client RR_Crush), and the first failure per
-- loco is PRINTED so a residual problem shows in the server log instead of dying
-- silently. A slow/stationary loco is a wall again too (ejectZombies): the server
-- never spawned the invisible rr_collider segments, so below V_MIN nothing held
-- bodies out of the hull.
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- v1.0.2 (engine-phase wall): the hard eject sweep alone cannot stop a zombie --
-- the zombie AI / movement resolution runs AFTER Lua OnTick, so a teleport-eject
-- is overwritten before it replicates and the body walks straight through (the
-- reported "zombies still pass through"). The SP mod solved the same problem with
-- the invisible rr_collider segment chain: those animals are collidable with
-- blockMovement=false, so the ENGINE's separate() push -- which runs inside the
-- character movement resolution, exactly like vehicle collision -- shoves zombies
-- and remote players out of the hull every tick, in the phase that sticks. We
-- spawn the chain on the server (invisible by design: static blank model, zero
-- shadow, silent) and pin it every sim tick alongside the loco.
--------------------------------------------------------------------------
local Wall = { segments = {} }   -- loco id -> { animal, along, lateral }[]

local function wallBreed()
    local adef = AnimalDefinitions and AnimalDefinitions.getDef("rr_collider")
    if not adef then return nil end
    local ok, breed = pcall(function() return adef:getRandomBreed() end)
    if ok then return breed end
    return nil
end

function Collision.onSpawn(e)
    if not (e and e.animal) then return end
    if Wall.segments[e.id] then return end
    local breed = wallBreed()
    if not breed then return end
    local cell = getCell()
    if not cell then return end
    local size = 0.7
    pcall(function() size = e.animal:getAnimalSize() end)
    local grid = RR.Body.segmentGrid(size)
    local segs = {}
    local px, py, pz = e.animal:getX(), e.animal:getY(), e.animal:getZ()
    for _, slot in ipairs(grid) do
        local animal
        local ok = pcall(function()
            animal = addAnimal(cell, math.floor(px), math.floor(py), math.floor(pz or 0), "rr_collider", breed)
        end)
        if ok and animal then
            pcall(function() animal:addToWorld() end)
            pcall(function() animal:setGodMod(true) end)
            pcall(function() animal:setIsInvincible(true) end)
            pcall(function() animal:setInvisible(true, true) end)
            -- Stop the player tripping/failing over the segments (SP did the same:
            -- overlapping several segments at once would otherwise fire setBumpFall).
            pcall(function() animal:setNpc(true) end)
            pcall(function()
                local md = animal:getModData()
                md.rrWall = true
                md.rrWallLoco = e.id
            end)
            segs[#segs + 1] = { animal = animal, along = slot.along, lateral = slot.lateral }
        end
    end
    Wall.segments[e.id] = segs
    print("[RailroaderMP] wall segments: " .. tostring(#segs) .. " for loco " .. tostring(e.id))
end

local function pinWall(e)
    local segs = Wall.segments[e.id]
    if not segs then return end
    local pose = e.pose
    if not pose then return end
    local fx, fy = pose.dirX or 0, pose.dirY or -1
    if fx == 0 and fy == 0 then fx, fy = 0, -1 end
    local rx, ry = -fy, fx
    for _, s in ipairs(segs) do
        local x = pose.x + s.along * fx + s.lateral * rx
        local y = pose.y + s.along * fy + s.lateral * ry
        safe("pinWall", function()
            s.animal:setX(x); s.animal:setY(y); s.animal:setZ(pose.z or 0)
            s.animal:setTargetAndCurrentDirection(fx, fy)
        end, e)
    end
end

function Collision.removeWall(e)
    local segs = e and Wall.segments[e.id]
    if not segs then return end
    Wall.segments[e.id] = nil
    for _, s in ipairs(segs) do
        pcall(function() s.animal:removeFromWorld() end)
        pcall(function() s.animal:removeFromSquare() end)
    end
end

--------------------------------------------------------------------------
-- dropWalls(e): remove every rr_collider animal in the loaded cell that claims
-- this loco as its owner, whether or not it is part of the CURRENT chain.
-- Called before re-creating a fresh chain (restart adopt / chunk re-bind): a
-- PREVIOUS session's rr_collider segments are persisted in the save with the
-- same rrWallLoco, and if they are left alone they linger as invisible
-- blockers beside the re-created chain ("重启后原地留下碰撞箱").
--------------------------------------------------------------------------
function Collision.dropWalls(e)
    if not (e and e.id) then return end
    local cell = getCell()
    local list = cell and cell:getAnimals()
    if not list then return end
    for index = 0, list:size() - 1 do
        local w = list:get(index)
        local wm = w and w:getModData()
        if wm and wm.rrWall and wm.rrWallLoco == e.id then
            pcall(function() w:removeFromWorld() end)
            pcall(function() w:removeFromSquare() end)
        end
    end
end

--------------------------------------------------------------------------
-- sweepOrphanWalls: remove rr_collider segments whose owner loco is gone (crash
-- leftovers, re-saves, deduped duplicates). MEMBERSHIP check, not just owner:
-- only the animals in the LIVE chains (Wall.segments) are ours -- after a
-- restart / re-bind, old-session rr_collider animals persist in the save with
-- the same rrWallLoco, and an owner-exists test would keep them forever as
-- invisible blockers. Called from RR_ServerTrain on start and periodically
-- alongside reacquire.
--------------------------------------------------------------------------
function Collision.sweepOrphanWalls()
    local cell = getCell()
    local animals = cell and cell:getAnimals()
    if not animals then return end
    local owned = {}
    for _, segs in pairs(Wall.segments) do
        for _, s in ipairs(segs) do
            local id
            if s.animal then pcall(function() id = s.animal:getAnimalID() end) end
            if id then owned[id] = true end
        end
    end
    local victims = {}
    for i = 0, animals:size() - 1 do
        local a = animals:get(i)
        local md = a and a:getModData()
        if md and md.rrWall then
            local id
            pcall(function() id = a:getAnimalID() end)
            if not (id and owned[id]) then victims[#victims + 1] = a end
        end
    end
    for _, a in ipairs(victims) do
        print("[RailroaderMP] removing orphan wall segment " .. tostring(a:getAnimalID()))
        pcall(function() a:removeFromWorld() end)
        pcall(function() a:removeFromSquare() end)
    end
end

local function size(e)
    local v = 0.7
    pcall(function() v = e.animal:getAnimalSize() end)
    return v
end

local function inside(e, obj)
    return e.pose and obj and RR.Body.contains(e.pose, size(e), obj:getX(), obj:getY())
end

local function impact(e, kind, downed)
    safe("impact", function()
        local args = { id = e.id, kind = kind }
        -- v1.0.8: a DOWNED crush kill (body pulped on the ground) flags the event
        -- so every client can play the blood-splatter squelch -- a dedicated
        -- server has no audio, so the foley travels as data.
        if downed then args.downed = true end
        sendServerCommand("RailroaderMP", "impact", args)
    end, e)
end

local function aboard(e, p)
    local onlineId = p and p:getOnlineID()
    return onlineId and (onlineId == e.driver or (e.passengers and e.passengers[onlineId]))
end

--------------------------------------------------------------------------
-- ejectTarget: nearest-hull-edge push for a body centre at (ox, oy) -- the SP
-- RR_Collider.ejectIntruders algorithm ported to the server (least penetration:
-- sideways vs off-the-end, EJECT_MARGIN). Returns nx, ny, or nil when the body
-- is not inside the oriented footprint. The keep-out box is inflated by
-- RR.Body.REPEL_EXTRA (zombies only -- this is the zombie sweep's eject target;
-- remote players are walled by the engine-phase segments, see pinWall). The
-- server is authoritative for remote players and zombies; the OWNER of a player
-- still needs the client-side twin (RR_MPClient.ejectLocalPlayer) because the
-- engine does not mirror server-set positions of the local player back to its
-- own screen.
--------------------------------------------------------------------------
local function ejectTarget(e, ox, oy, oz)
    local pose = e.pose
    if not pose then return nil end
    if oz ~= nil and (pose.z or 0) ~= nil and math.abs(oz - (pose.z or 0)) >= 1 then return nil end
    local fx, fy = pose.dirX or 0, pose.dirY or -1
    if fx == 0 and fy == 0 then fx, fy = 0, -1 end
    local rx, ry = -fy, fx
    local len, wid = RR.Body.extents(size(e))
    local hl, hw = len * 0.5, wid * 0.5
    local bias = RR.Body.LAT_BIAS or 0
    local r = RR.Body.REPEL_EXTRA or 0
    local ehl, ehw = hl + r, hw + r
    local dx, dy = ox - pose.x, oy - pose.y
    local pf = dx * fx + dy * fy
    local pr = dx * rx + dy * ry - bias
    if math.abs(pf) >= ehl or math.abs(pr) >= ehw then return nil end
    -- v1.0.8 (SP v1.0.2 clamp fix): the target lands ON the test boundary -- no
    -- EJECT_MARGIN overshoot. The old +0.15 left a dead band [box, box+0.15] an
    -- intruder could creep through between ticks -- the SP "walk in, get flung
    -- out" sawtooth. With target == test the clamp puts the body back on the
    -- same line every tick, so it simply cannot advance (a vanilla wall).
    if (ehw - math.abs(pr)) <= (ehl - math.abs(pf)) then
        local npr = ((pr >= 0) and 1 or -1) * ehw + bias
        return pose.x + pf * fx + npr * rx, pose.y + pf * fy + npr * ry
    end
    local npf = ((pf >= 0) and 1 or -1) * ehl
    return pose.x + npf * fx + (pr + bias) * rx, pose.y + npf * fy + (pr + bias) * ry
end

--------------------------------------------------------------------------
-- ejectZombies: the wall at ANY speed. The server never spawned the invisible
-- rr_collider push segments, so without this a body stands inside the hull and
-- rides along (or walks straight through). crush() runs first and kills/knocks
-- down; this ejects whatever is still inside. TWO-PHASE like crush: setX changes
-- square membership and would invalidate the iteration.
--------------------------------------------------------------------------
local function ejectZombies(e)
    local cell = getCell()
    local zombies = cell and cell:getZombieList()
    if not zombies then return end
    local victims = {}
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if z then
            local dead = true
            safe("zombieDead", function() dead = z:isDead() end, e)
            if not dead then
                local nx, ny = ejectTarget(e, z:getX(), z:getY(), z:getZ())
                if nx then victims[#victims + 1] = { z = z, nx = nx, ny = ny } end
            end
        end
    end
    for _, v in ipairs(victims) do
        safe("ejectZombie", function()
            v.z:setX(v.nx); v.z:setY(v.ny)
            v.z:setNextX(v.nx); v.z:setNextY(v.ny)
            -- v1.0.8 (SP EJECT_SYNC_LAST): re-stamp where it came FROM so nothing
            -- rolls back to a position inside the hull.
            v.z:setLastX(v.nx); v.z:setLastY(v.ny)
        end, e)
    end
end

--------------------------------------------------------------------------
-- killZombie: on a DEDICATED SERVER a kill must go through z:dieNetwork() or the
-- clients never see the death (reference: Military Tool Kit server kills zombies
-- with zombie:dieNetwork(killer, nil, bGory, nil) -- "dieNetwork mata com
-- sincronização de rede"). z:Kill(nil,...) is the SP client path; server-side it
-- can throw OR silently leave the client unaware. We knock the body down, kill
-- through dieNetwork (crediting the driver when present), and belt-and-braces
-- force the networked death if the body is still alive.
--------------------------------------------------------------------------
-- v1.0.8 (SP v1.0.2): a DOWNED kill is always the gory one -- a wheel does not
-- need speed help (vanilla's car kills a prone body gory at any impact speed) --
-- and a body already on the floor is in the right pose: re-knocking it would
-- restart the fall under the wheels.
local function killZombie(e, z, speed, policy, downed)
    local function zombieDead()
        local dead = true
        pcall(function() dead = z:isDead() end)
        return dead
    end
    local killer
    if e.driver then
        safe("killZombieKiller", function() killer = getPlayerByOnlineID(e.driver) end, e)
    end
    local bGory = (downed and true) or speed >= policy.V_GORE
    local ok = safe("killZombie", function()
        if not downed then z:knockDown(false) end
        z:dieNetwork(killer, nil, bGory, nil)
    end, e)
    if not ok or not zombieDead() then
        safe("killZombieFallback", function()
            z:setHealth(0)
            z:dieNetwork(killer, nil, bGory, nil)
        end, e)
    end
end

--------------------------------------------------------------------------
-- isDown(z): is this zombie already on the ground (under the wheels rather than
-- against the frame)? Reads only REAL engine state -- the floor flag is an ANIM
-- event that lands late (staggerAndFall.xml SetOnFloor at TimePc 0.5), so keying
-- on isKnockedDown would collapse the knockdown tier into "everything dies";
-- keying on the floor spends the fall (a corner-clip can clear the footprint and
-- survive as a crawler -- the designed outcome).
--------------------------------------------------------------------------
local function isDown(z)
    local down = false
    pcall(function()
        down = z:isOnFloor() or z:isCrawling() or z:isGettingUp()
    end)
    return down and true or false
end

--------------------------------------------------------------------------
-- runOverFoley(z, speed, downed): vanilla run-over blood, applied JUST BEFORE
-- dieNetwork (the body is still alive, so its own emitter is still up). This is
-- the same call a car makes; it self-gates on speed, so a DOWNED kill is booked
-- at V_GORE -- the wheel does not care how slowly it arrived. The squelch sound
-- travels as the impact event's `downed` flag (a dedicated server has no audio);
-- each client plays it locally.
--------------------------------------------------------------------------
local function runOverFoley(z, speed, downed)
    local bloodV = downed and math.max(speed, (RR.Body.CRUSH.V_GORE or 8)) or speed
    pcall(function() z:addBloodFromVehicleImpact(bloodV) end)
end

local function crush(e, dt)
    local speed = math.abs(e.drive.v or 0)
    local policy = RR.Body.CRUSH
    -- v1.0.8 (SP v1.0.2): the rolling gate is V_ROLL, not V_MIN, with a
    -- ROLL_GRACE timer. Between V_ROLL and V_MIN the loco still runs over a body
    -- that is already DOWN (crushEffect -> "gib" at any rolling speed); it just
    -- is not fast enough to floor a standing one ("none" -> falls through to the
    -- keep-out eject exactly as before). Fully parked (and past the grace): no
    -- crush at all, and the stale contact set is dropped so the next real hit
    -- knocks down again instead of being skipped as "already struck".
    local rolling = speed >= policy.V_ROLL
    if rolling then
        e._rollGrace = Collision.ROLL_GRACE
    else
        local g = (e._rollGrace or 0) - (dt or 0)
        e._rollGrace = (g > 0) and g or 0
    end
    local grace = (not rolling) and (e._rollGrace or 0) > 0
    if not (rolling or grace) then
        e._struck = nil
        return
    end
    local cell = getCell()
    local zombies = cell and cell:getZombieList()
    if zombies then
        -- TWO-PHASE (crash fix, server log "Index N out of bounds for length N"):
        -- dieNetwork removes the zombie from the cell list immediately, so killing
        -- inside the iteration loop throws IndexOutOfBounds on the next get() and
        -- aborts crush every tick. Collect inside bodies first, then apply.
        local victims = {}
        for i = 0, zombies:size() - 1 do
            local z = zombies:get(i)
            if z then
                local dead = true
                safe("zombieDead", function() dead = z:isDead() end, e)
                if not dead and inside(e, z) then victims[#victims + 1] = z end
            end
        end
        local struck = e._struck or {}
        local seen = {}
        for _, z in ipairs(victims) do
            local id
            pcall(function() id = z:getID() end)
            if id then seen[id] = true end
            local down = isDown(z)
            -- Inside the grace the loco has already stopped, so |v| alone would
            -- read "none". A body it stopped ON was still run over, so the DOWNED
            -- policy is evaluated at the threshold speed; standing bodies keep
            -- the real |v| and are therefore untouched by a standstill.
            local effAv = (down and grace) and policy.V_ROLL or speed
            local effect = RR.Body.crushEffect(effAv, down)
            if effect == "kill" or effect == "gib" then
                runOverFoley(z, speed, down)
                killZombie(e, z, speed, policy, down)
                impact(e, "crush", down)
            elseif effect == "knockdown" then
                if not (id and struck[id]) then
                    if id then struck[id] = true end
                    safe("knockDown", function() z:knockDown(false) end, e)
                    impact(e, "crush", false)
                end
            end
        end
        -- Forget bodies no longer under the loco so a fresh contact re-triggers.
        for id in pairs(struck) do
            if not seen[id] then struck[id] = nil end
        end
        e._struck = struck
    end
    -- Players: only a standing-speed kill (V_KILL) can crush a player -- the
    -- downed tiers do not apply (a player is never knocked down by the loco).
    local players = getOnlinePlayers()
    if players and speed >= policy.V_KILL then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and not aboard(e, p) and p:getHealth() > 0 and inside(e, p) then
                safe("playerKill", function()
                    p:setHealth(0)
                    p:transmitStats()
                end, e)
                impact(e, "crush", false)
            end
        end
    end
    local animals = cell and cell:getAnimals()
    -- Still gated on V_MIN, NOT the sweep's V_ROLL: wild animals have no
    -- down/standing tiers -- anything in the box is roadkill, and an inching
    -- loco must not start killing deer.
    if animals and IsoDeadBody and speed >= policy.V_MIN then
        local victims = {}
        for i = 0, animals:size() - 1 do
            local a = animals:get(i)
            local t = a and a:getAnimalType() or ""
            if a and not a:isDead() and string.sub(t, 1, 3) ~= "rr_" and inside(e, a) then
                victims[#victims + 1] = a
            end
        end
        for _, a in ipairs(victims) do
            safe("roadkill", function()
                a:setIsRoadKill(true)
                a:addBloodFromVehicleImpact(speed)
                IsoDeadBody.new(a, false)
            end, e)
            impact(e, "crush", false)
        end
    end
end

local function breakObject(e, obj, sq)
    if instanceof(obj, "IsoThumpable") then
        safe("thumpable", function()
            obj:Damage(5000)
            obj:animalHit(e.animal)
        end, e)
    elseif instanceof(obj, "IsoDoor") then safe("door", function() obj:destroy() end, e)
    elseif instanceof(obj, "IsoWindow") then safe("window", function() obj:smashWindow() end, e)
    elseif instanceof(obj, "IsoTree") then safe("tree", function() obj:toppleTree(e.animal) end, e)
    else safe("removeObject", function() sq:transmitRemoveItemFromSquare(obj) end, e) end
end

--------------------------------------------------------------------------
-- blocksMovement(o): per-OBJECT solidity, the proven-safe B42 read (mirrors
-- RR_ObstacleSweep.blocksMovement). v1.0.3e: the old string read
-- props:has("solid") throws or fails on wall sprites in this build, which is
-- why the loco phased straight through map walls and player-built walls.
--------------------------------------------------------------------------
local function blocksMovement(o)
    local blocks = false
    pcall(function()
        local pr = o and o:getProperties()
        if not pr then return end
        blocks = pr:has(IsoFlagType.solid) or pr:has(IsoFlagType.solidtrans)
              or pr:has(IsoFlagType.collideN) or pr:has(IsoFlagType.collideW)
    end)
    return blocks
end

--------------------------------------------------------------------------
-- hasRailSprite(sq): any industry_railroad_* sprite on the square (rail floor,
-- switches and metal railcar walls all carry the tileset prefix).
--------------------------------------------------------------------------
local function hasRailSprite(sq)
    local hit = false
    pcall(function()
        local objs = sq and sq:getObjects()
        if not objs then return end
        for oi = 0, objs:size() - 1 do
            local o = objs:get(oi)
            local sp = o and o:getSprite()
            local nm = sp and sp:getName()
            if nm and string.sub(nm, 1, 17) == "industry_railroad" then hit = true; return end
        end
    end)
    return hit
end

--------------------------------------------------------------------------
-- railcarStandIn(sq, obj): rolling stock, or the wall sprites the dev/builders
-- use to SIMULATE parked freight cars on the rails (SP railcarOn): an
-- industry_railroad_* blocking body, or a carpentry_01_16 boxcar wall standing
-- on a rail square. Everything else that blocks is flattened, not stopped.
--------------------------------------------------------------------------
local function railcarStandIn(sq, obj)
    local sp = obj and obj:getSprite()
    local nm = sp and sp:getName()
    if not nm then return false end
    if string.sub(nm, 1, 17) == "industry_railroad" then return true end
    if nm == "carpentry_01_16" then return hasRailSprite(sq) end
    return false
end

local function stopHard(e)
    local speed = math.abs(e.drive.v or 0)
    e.drive.v = 0
    e.engine.condition = math.max(0, (e.engine.condition or 0) - RR.Obstacle.impactDamage(RR.Obstacle.CLASS.HARD, speed))
    if RR.Obstacle.shouldDerailImpact(RR.Obstacle.CLASS.HARD, speed) then
        e.derailed = true
        -- v1.0.5 (derail = dead engine): kill the prime mover the tick the loco
        -- leaves the rails, so the state stream carries engineOn=false and every
        -- client silences the engine hum on the wreck. Matches the SP rule
        -- (RR_TrainEntity.derail); before this an MP wreck sat there idling.
        if e.engine and RR.Engine and RR.Engine.stop then
            pcall(function() RR.Engine.stop(e.engine) end)
        end
    end
    impact(e, "hard")
end

local function vehicleAhead(e, pose, sign)
    local len, wid = RR.Body.extents(size(e))
    local fx, fy = pose.dirX or 0, pose.dirY or -1
    local rx, ry = -fy, fx
    local cell = getCell()
    if not cell then return nil end
    for _, lateral in ipairs({ 0, wid * 0.5, -wid * 0.5 }) do
        local x = math.floor(pose.x + fx * sign * (len * 0.5 + 0.5) + rx * lateral)
        local y = math.floor(pose.y + fy * sign * (len * 0.5 + 0.5) + ry * lateral)
        local sq = cell:getGridSquare(x, y, math.floor(pose.z or 0))
        local car
        if sq then safe("vehicleContainer", function() car = sq:getVehicleContainer() end, e) end
        if car then return car end
    end
    return nil
end

--------------------------------------------------------------------------
-- carSeen(e, car): has this car object already been wrecked? Keyed by the car
-- OBJECT (Kahlua == is reliable for the same Java vehicle); a wreck's REPLACED
-- object is latched too (setSmashed returns a fresh vehicle). The list lives
-- only while the car is in the probe -- obstacle() clears it when the car clears.
--------------------------------------------------------------------------
local function carSeen(e, car)
    if not e._hitCars then return false end
    for i = 1, #e._hitCars do
        if e._hitCars[i] == car then return true end
    end
    return false
end

--------------------------------------------------------------------------
-- carAlong(e, car): the car's speed projected on the loco's forward axis
-- (m/s, + = moving WITH the loco). getCurrentSpeedKmHour is signed server-side
-- (official server scripts use it); the heading is a coarse IsoDirections
-- projection. Returns 0 for a parked car (dot term vanishes either way).
--------------------------------------------------------------------------
local function carAlong(e, car)
    local kmh = 0
    safe("carSpeed", function() kmh = car:getCurrentSpeedKmHour() or 0 end, e)
    local vc = (kmh or 0) / 3.6
    local fx, fy = e.pose.dirX or 0, e.pose.dirY or -1
    local dot = 0
    pcall(function()
        local dir = car:getDir()
        local ddx, ddy
        if     dir == IsoDirections.N  then ddx, ddy = 0, -1
        elseif dir == IsoDirections.NE then ddx, ddy = 0.7071, -0.7071
        elseif dir == IsoDirections.E  then ddx, ddy = 1, 0
        elseif dir == IsoDirections.SE then ddx, ddy = 0.7071, 0.7071
        elseif dir == IsoDirections.S  then ddx, ddy = 0, 1
        elseif dir == IsoDirections.SW then ddx, ddy = -0.7071, 0.7071
        elseif dir == IsoDirections.W  then ddx, ddy = -1, 0
        elseif dir == IsoDirections.NW then ddx, ddy = -0.7071, -0.7071
        end
        if ddx then dot = ddx * fx + ddy * fy end
    end)
    return vc * dot
end

--------------------------------------------------------------------------
-- relSpeed(e, car): closing speed along the rail axis (m/s). When the heading
-- probe failed (dot == 0), fall back to the worst case |loco| + |car| -- never
-- UNDER-damages; a parked car still resolves to exactly |loco speed|.
--------------------------------------------------------------------------
local function relSpeed(e, car)
    local vt = e.drive.v or 0
    local along = carAlong(e, car)
    if along == 0 then
        local kmh = 0
        safe("carSpeed", function() kmh = car:getCurrentSpeedKmHour() or 0 end, e)
        return math.abs(vt) + math.abs(kmh or 0) / 3.6
    end
    return math.abs(vt - along)
end

--------------------------------------------------------------------------
-- carImpactFrac(relS): fraction of the CAR's condition lost, 0 below a 5 km/h
-- crawl -> 1.0 (full wreck) at a 60 km/h closing speed. The loco is 110 t; the
-- car takes almost all of a collision's energy, so its curve is much steeper
-- than the loco's VEHICLE impactDamage (which stays 1-3%).
--------------------------------------------------------------------------
local function carImpactFrac(relS)
    local v = relS or 0
    if v <= 5 / 3.6 then return 0 end
    local t = math.min(1, (v - 5 / 3.6) / ((60 - 5) / 3.6))
    return t
end

--------------------------------------------------------------------------
-- carImpact(e, car, relS): apply ONE relative-speed impact to both vehicles --
-- the loco debits its condition through RR.Obstacle.impactDamage(VEHICLE, relS);
-- the car loses carImpactFrac of EVERY part's condition (full wreck at/above the
-- 60 km/h tier: setSmashed + parts to 0, the old behaviour). Impact event once.
-- Returns the (possibly NEW, setSmashed-replaced) car for the latch.
--------------------------------------------------------------------------
local function carImpact(e, car, relS)
    local dmg = RR.Obstacle.impactDamage(RR.Obstacle.CLASS.VEHICLE, relS) or 0
    if dmg > 0 and e.engine then
        e.engine.condition = math.max(0, (e.engine.condition or 0) - dmg)
    end
    local frac = carImpactFrac(relS)
    local target = car
    if frac >= 1 then
        local newCar = car
        safe("smashed", function() newCar = car:setSmashed("Front") or car end, e)
        target = (newCar ~= nil and newCar ~= car) and newCar or car
        if target == car then
            for i = 0, car:getPartCount() - 1 do
                local part = car:getPartByIndex(i)
                safe("part", function() part:setCondition(0) end, e)
            end
        end
    elseif frac > 0 then
        for i = 0, car:getPartCount() - 1 do
            local part = car:getPartByIndex(i)
            safe("part", function()
                part:setCondition(math.max(0, (part:getCondition() or 0) * (1 - frac)))
            end, e)
        end
    end
    impact(e, "vehicle")
    return target
end

--------------------------------------------------------------------------
-- stopCar(e, car): cancel a MOVING car's velocity with an impulse outward from
-- the loco body (least-penetration edge -- the same choice as ejectTarget), so a
-- car driving into the loco is stopped and pushed clear. A MOVING car's Bullet
-- body is ACTIVE, so unlike the parked-car case the impulse actually lands.
-- Re-applied every tick by the callers while the car stays against the loco.
--------------------------------------------------------------------------
local function stopCar(e, car)
    local kmh = 0
    safe("carSpeed", function() kmh = car:getCurrentSpeedKmHour() or 0 end, e)
    local vc = math.abs(kmh or 0) / 3.6
    if vc <= 0.4 then return end                    -- parked/creep: nothing to stop
    local pose = e.pose
    if not pose then return end
    local mass = 1000
    safe("carMass", function() mass = car:getFudgedMass() or 1000 end, e)
    local fx, fy = pose.dirX or 0, pose.dirY or -1
    if fx == 0 and fy == 0 then fx, fy = 0, -1 end
    local rx, ry = -fy, fx
    local len, wid = RR.Body.extents(size(e))
    local hl, hw = len * 0.5, wid * 0.5
    local bias = RR.Body.LAT_BIAS or 0
    local ox, oy, oz
    safe("carPos", function() ox, oy, oz = car:getX(), car:getY(), car:getZ() end, e)
    if not ox then return end
    local dx, dy = ox - pose.x, oy - pose.y
    local pf = dx * fx + dy * fy
    local pr = dx * rx + dy * ry - bias
    local nx, ny
    if (hw - math.abs(pr)) <= (hl - math.abs(pf)) then
        nx, ny = ((pr >= 0) and 1 or -1) * rx, ((pr >= 0) and 1 or -1) * ry
    else
        nx, ny = ((pf >= 0) and 1 or -1) * fx, ((pf >= 0) and 1 or -1) * fy
    end
    safe("carStop", function()
        car:applyImpulseGeneric(ox, oy, oz, nx, ny, 0, mass * vc * 1.2)
    end, e)
end

--------------------------------------------------------------------------
-- eachVehicle(cell, fn): iterate every vehicle in the cell, whatever
-- collection IsoCell.getVehicles() returns in this B42 build. 42.16 and
-- earlier returned an ArrayList (size/get(i)); since 42.17 it returns a
-- java.util.Set, which has NO get(i) -- the old `vehicles:get(i)` loop threw
-- "Object tried to call nil in pcall" every tick a loco was active. Support
-- both shapes (plus a plain Lua-table fallback), all through pcall.
--------------------------------------------------------------------------
local function eachVehicle(cell, fn)
    if not (cell and cell.getVehicles and fn) then return end
    local ok, vehicles = pcall(function() return cell:getVehicles() end)
    if not ok or not vehicles then return end
    if vehicles.size and vehicles.get then
        local n = 0
        pcall(function() n = vehicles:size() end)
        for i = 0, n - 1 do
            local v
            pcall(function() v = vehicles:get(i) end)
            if v then fn(v) end
        end
        return
    end
    if vehicles.iterator then
        local it
        pcall(function() it = vehicles:iterator() end)
        if it and it.hasNext and it.next then
            while true do
                local has = false
                pcall(function() has = it:hasNext() end)
                if not has then break end
                local v
                pcall(function() v = it:next() end)
                if v then fn(v) end
            end
            return
        end
    end
    if type(vehicles) == "table" then
        for _, v in pairs(vehicles) do
            if v then fn(v) end
        end
    end
end

--------------------------------------------------------------------------
-- carBodyHit(e): a car that DRIVES INTO the loco BODY (side/rear -- the nose
-- probe only covers ahead). Damage once per car (latch); the outward stop
-- re-applies every tick while the car overlaps and is still moving, so it can
-- never push through. The latch clears when no car overlaps the body.
--------------------------------------------------------------------------
local function carBodyHit(e)
    local cell = getCell()
    if not cell then return end
    local any = false
    eachVehicle(cell, function(v)
        if inside(e, v) then
            any = true
            if not bodyCarSeen(e, v) then
                local rs = relSpeed(e, v)
                if rs > 0.3 then
                    local target = carImpact(e, v, rs)
                    e._bodyCars = e._bodyCars or {}
                    e._bodyCars[#e._bodyCars + 1] = target or v
                    if target and target ~= v then e._bodyCars[#e._bodyCars + 1] = v end
                end
            end
            stopCar(e, v)
        end
    end)
    if not any then e._bodyCars = nil end
end

local function bodyCarSeen(e, car)
    if not e._bodyCars then return false end
    for i = 1, #e._bodyCars do
        if e._bodyCars[i] == car then return true end
    end
    return false
end

local function obstacle(e)
    if not e.pose then return end
    local speed = math.abs(e.drive.v or 0)
    local sign = (e.drive.v or 0) >= 0 and 1 or -1
    -- Car probe runs at ANY speed (v1.0.3c): after the hard stop the loco sits at
    -- speed 0, but the next throttle tick would accelerate it INTO the car unless
    -- the hold is re-applied every tick. Probing before the speed gate keeps it.
    local car = vehicleAhead(e, e.pose, sign)
    if car then
        -- First contact: ONE relative-speed impact (latched by object; a
        -- setSmashed-replaced car is latched too). While the car stays in the
        -- probe the loco HARD-STOPS at it -- the server cannot move a PARKED car
        -- (spike: setX reverts, impulse is dropped) -- and a MOVING car driving
        -- into the loco is stopped outward every tick (its body is active).
        if not carSeen(e, car) then
            local target = carImpact(e, car, relSpeed(e, car))
            e._hitCars = e._hitCars or {}
            e._hitCars[#e._hitCars + 1] = target or car
            if target and target ~= car then e._hitCars[#e._hitCars + 1] = car end
        end
        stopCar(e, car)
        e.drive.v = 0
        return
    end
    e._hitCars = nil   -- car cleared (towed/removed): re-arm the latch, release
    if speed <= 0.05 then return end
    local len = RR.Body.extents(size(e))
    local x = math.floor(e.pose.x + e.pose.dirX * sign * (len * 0.5 + 0.5))
    local y = math.floor(e.pose.y + e.pose.dirY * sign * (len * 0.5 + 0.5))
    local sq = getCell():getGridSquare(x, y, math.floor(e.pose.z or 0))
    if not sq then return end
    local objects = sq:getObjects()
    if not objects then return end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local md = obj and obj:getModData()
        if md and md.rrFuelStand then stopHard(e); return end
        if obj and (instanceof(obj, "IsoThumpable") or instanceof(obj, "IsoDoor") or instanceof(obj, "IsoWindow") or instanceof(obj, "IsoTree")) then
            breakObject(e, obj, sq); e.drive.v = e.drive.v * 0.98; impact(e, "object"); return
        end
        if obj then
            local props = obj:getSprite() and obj:getSprite():getProperties()
            if props and props:has("HitByCar") then
                breakObject(e, obj, sq); e.drive.v = e.drive.v * 0.98; impact(e, "object"); return
            end
            -- v1.0.3e (walls/buildings): per-object flag read (see blocksMovement)
            -- -- NOT props:has("solid"), which fails in this build and let the loco
            -- pass through every wall. A blocking railcar stand-in (dev's parked
            -- freight-car walls) is a HARD stop; any other blocker is flattened
            -- ("the loco flattens everything except rolling stock", SP policy).
            if blocksMovement(obj) then
                if railcarStandIn(sq, obj) then
                    stopHard(e)
                else
                    breakObject(e, obj, sq)
                    pcall(function() sq:RecalcAllWithNeighbours(true) end)
                    e.drive.v = e.drive.v * 0.98
                    impact(e, "object")
                end
                return
            end
        end
    end
end

function Collision.update(e, pose, dt)
    -- One authoritative collision pass per sim tick, called from
    -- RR_ServerTrain.stepOnce with the CURRENT sim pose. Order: pin the
    -- invisible engine-phase wall first (it must exist before any eject
    -- targets are computed), then run the four subsystems independently --
    -- each is pcall-isolated so one failing API (or an API that exists only
    -- in some B42 builds) can never silently skip the others.
    e.pose = pose
    pinWall(e)
    -- Each subsystem is independent: a failure in one must not skip the others.
    safe("crush", function() crush(e, dt) end, e)
    safe("ejectZombies", function() ejectZombies(e) end, e)
    safe("carBodyHit", function() carBodyHit(e) end, e)
    safe("obstacle", function() obstacle(e) end, e)
end

RR.ServerCollision = Collision
return Collision
