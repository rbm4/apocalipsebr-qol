--***********************************************************************
-- Railroader / RR_Crush  -- run zombies AND animals over with the locomotive (Task 1.H)
--
-- Wild animals (deer/rabbit/...) are handled like a car hitting them: mark roadkill
-- + spawn the ground carcass (IsoDeadBody). The vanilla roadKill flag makes the
-- corpse butcher for only a few hunger units of meat -- no custom meat math needed.
-- (getAnimals() also holds our rr_loco/rr_collider -- those are skipped by prefix.)
--
-- The collider (RR_Collider) keeps zombies from passing THROUGH the loco; this
-- layer kills the ones the moving loco runs INTO. We cannot use the vanilla
-- vehicle-hit path (IsoGameCharacter.onHitByVehicle needs a BaseVehicle for
-- CombatManager.checkPVP, and there is none -- locked decision), so we reproduce
-- the OUTCOME with the public zombie methods that DO work without a vehicle:
--   * IsoZombie.knockDown(hitFromBehind)     -- stagger/floor, chance of crawler
--   * IsoGameCharacter.Kill(killer)          -- death, credited to the driver
-- Verified in the B42 decompile (see docs/ENGINE_NOTES.md "crush zombies").
--
-- Each tick, for each active loco, we gate on |speed| (a PARKED loco must not be
-- lethal -- it is just a wall), gather the cell's zombies, cull to the footprint
-- bbox, and for each body inside the RR.Body footprint apply the speed tier from
-- the PURE RR.Body policy (knockDown below V_KILL, Kill at/above it). A per-record
-- "struck" set dedups knockdowns so we hit each body once per contact (kills need
-- no dedup -- a dead body drops out next tick). Ragdoll "fly-off" is deliberately
-- NOT here: it is a Bullet-physics effect tied to a vehicle collision body and is
-- single-player-only -- infeasible without Java (see docs/CRUSH_DESIGN.md).
--
-- Lifecycle mirrors RR.Collider: RR_TrainEntity.onTick calls Crush.update per rec
-- AFTER the pose/speed is updated. Crush.enabled=false disables the whole system.
--***********************************************************************

print("[Railroader] RR_Crush.lua: loading...")
require("Railroader/RR_Body")

local Crush = {}
Crush.enabled  = true
Crush.animals  = true          -- also run over wild animals (deer/rabbit/...) as roadkill
Crush.OWN_PREFIX = "rr_"       -- skip our OWN animals (rr_loco visual, rr_collider segments)

local function sgn(x)
    if x > 0 then return 1 elseif x < 0 then return -1 else return 0 end
end

--------------------------------------------------------------------------
-- Roadkill one animal exactly as a car does (verified in the B42 decompile against
-- IsoAnimal.Hit(vehicle,...)): mark it roadkill, splatter blood, then spawn the
-- ground carcass. IsoDeadBody.new(a, false) == (a, false, true): adds the corpse to
-- the square + fires OnDeadBodySpawn AND removes the live animal (the canonical
-- vanilla ground-corpse idiom, e.g. RDSRatInfested). The roadKill flag is copied
-- onto the corpse modData by setAnimalBodyData, and ButcheringUtil then halves the
-- meat + drops meatRatio to 0.2-0.4 -> only a few hunger units of meat, as asked.
--------------------------------------------------------------------------
local function roadkillAnimal(a, speed)
    pcall(function() a:setIsRoadKill(true) end)
    pcall(function() a:addBloodFromVehicleImpact(speed) end)   -- same splatter as a car
    pcall(function() IsoDeadBody.new(a, false) end)            -- ground carcass; removes the animal
end

--------------------------------------------------------------------------
-- The IsoGameCharacter to credit a kill to: the local player IF they are driving
-- THIS loco (so zombie-kill count + XP land), else nil (autopilot/debug cruise --
-- Kill(nil) is a valid unattributed death).
--------------------------------------------------------------------------
local function killerFor(rec)
    if RR and RR.Ride and RR.Ride.current == rec then
        local p; pcall(function() p = getPlayer() end)
        return p
    end
    return nil
end

--------------------------------------------------------------------------
-- update: run the crush sweep for one loco record. Called each tick from
-- RR_TrainEntity.onTick after the loco pose/speed is applied.
--------------------------------------------------------------------------
function Crush.update(rec, dt)
    if not (Crush.enabled and RR and RR.Body and rec and rec.animal) then return end

    local v  = rec.speed or 0
    local av = (v < 0) and -v or v
    -- Parked/creeping: no crush. Drop any stale contact set so the next real hit
    -- knocks down again rather than being skipped as "already struck".
    if av < RR.Body.CRUSH.V_MIN then
        rec._struck = nil
        return
    end

    local pose = rec.lastPose
    if not pose then return end

    local size = 0.7
    pcall(function() size = rec.animal:getAnimalSize() end)

    -- Cull radius around the loco centre: half the body length + a margin. A body
    -- outside this circle cannot be inside the oriented footprint box.
    local len   = RR.Body.extents(size)
    local reach = len * 0.5 + 2.0
    local reach2 = reach * reach

    local cell = getCell()
    if not cell then return end
    local zlist = cell:getZombieList()
    if not zlist then return end

    local killer = killerFor(rec)
    local struck = rec._struck or {}
    local seen   = {}
    local killedThisTick = false

    for i = 0, zlist:size() - 1 do
        local z = zlist:get(i)
        local dead = true
        pcall(function() dead = z:isDead() end)
        if z and not dead then
            local zx, zy = 0, 0
            pcall(function() zx = z:getX(); zy = z:getY() end)
            local dx, dy = zx - pose.x, zy - pose.y
            if dx * dx + dy * dy <= reach2 then
                local inside = RR.Body.contains(pose, size, zx, zy)
                if inside then
                    local id
                    pcall(function() id = z:getID() end)
                    if id then seen[id] = true end
                    local effect = RR.Body.crushEffect(av)
                    if effect == "kill" or effect == "gib" then
                        pcall(function() z:knockDown(false) end)          -- floored pose for the kill
                        pcall(function() z:Kill(killer, effect == "gib") end)  -- bGory at speed
                        killedThisTick = true
                    elseif effect == "knockdown" then
                        if not (id and struck[id]) then
                            if id then struck[id] = true end
                            pcall(function() z:knockDown(false) end)
                        end
                    end
                end
            end
        end
    end

    -- Wild animals (deer/rabbit/...) -> roadkill, exactly like a car. getAnimals()
    -- ALSO holds OUR rr_loco visual + rr_collider segments, so skip the OWN_PREFIX
    -- types. TWO-PHASE: gather victims first, THEN kill -- roadkillAnimal removes the
    -- animal from the cell list (IsoDeadBody ctor), and mutating the list mid-iterate
    -- would skip/OOB.
    if Crush.animals and IsoDeadBody then
        local alist = cell:getAnimals()
        if alist then
            local victims
            for i = 0, alist:size() - 1 do
                local a = alist:get(i)
                if a then
                    local t; pcall(function() t = a:getAnimalType() end)
                    local mine = t and string.sub(t, 1, #Crush.OWN_PREFIX) == Crush.OWN_PREFIX
                    local dead = true
                    pcall(function() dead = a:isDead() end)
                    if a and not mine and not dead then
                        local ax, ay = 0, 0
                        pcall(function() ax = a:getX(); ay = a:getY() end)
                        local dx, dy = ax - pose.x, ay - pose.y
                        if dx * dx + dy * dy <= reach2 and RR.Body.contains(pose, size, ax, ay) then
                            victims = victims or {}
                            victims[#victims + 1] = a
                        end
                    end
                end
            end
            if victims then
                for _, a in ipairs(victims) do roadkillAnimal(a, av) end
                killedThisTick = true
            end
        end
    end

    -- Impact thud on a kill, throttled so a whole crowd going under in one tick is
    -- a single thud rather than a wall of overlapping one-shots.
    rec._crushSndCd = (rec._crushSndCd or 0) - (dt or 0)
    if killedThisTick and rec._crushSndCd <= 0 then
        rec._crushSndCd = (RR.SoundConfig and RR.SoundConfig.CRUSH_MIN_INTERVAL) or 0.12
        if RR.Sound and RR.Sound.crushImpact then pcall(function() RR.Sound.crushImpact(rec) end) end
    end

    -- Forget bodies no longer under the loco so a fresh contact re-triggers.
    for id in pairs(struck) do
        if not seen[id] then struck[id] = nil end
    end
    rec._struck = struck
end

RR = RR or {}
RR.Crush = Crush
print("[Railroader] RR_Crush.lua: loaded OK (V_MIN=" .. RR.Body.CRUSH.V_MIN
      .. " V_KILL=" .. RR.Body.CRUSH.V_KILL .. " m/s; animals="
      .. tostring(Crush.animals) .. ").")

return Crush
