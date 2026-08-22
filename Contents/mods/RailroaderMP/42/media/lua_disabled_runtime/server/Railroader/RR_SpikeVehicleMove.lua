--***********************************************************************
-- RailroaderMP / RR_SpikeVehicleMove  -- SPIKE ONLY (v1.0.3, removable)
--
-- Question: can a DEDICATED-SERVER Lua script move a BaseVehicle by writing
-- its position directly (setX/setY)? The car-pass-through fix is blocked
-- because server-side applyImpulseGeneric hits a SLEEPING Bullet body (log:
-- "isActive: false") and the force is dropped. If setX/setY sticks and
-- replicates, the whole car shove can be re-implemented kinematically in
-- pure Lua (train ~110 t vs car ~3 t) with NO physics dependency.
--
-- RESULT (2026-08): setX/setY succeed but do NOT persist -- the server's own
-- vehicle update overwrites the write within a tick (RECHECK shows the car back
-- on its old square). The car cannot be moved server-side, so the collision fix
-- landed as a HARD-STOP at the car (RR_ServerCollision v1.0.3c) and the AUTO
-- hook in hitCar was removed. This file is kept for manual retests only.
--
-- MANUAL trigger from a CLIENT lua console, standing near a PARKED car:
--   sendClientCommand("RailroaderMP", "spikeVehicle", { d = 5 })
--     d     = tiles to shift diagonally (+d on X and Y); default 5
--     i     = Nth nearby vehicle (the log lists them); default 1
--     z     = true to also test setZ(+0.5)
--
-- Read the SERVER log:
--   1. "BEFORE/AFTER" -- did setX/setY succeed and change getX/getY?
--   2. "RECHECK" 60 ticks later -- did the value STICK, or did the vehicle
--      sim / physics overwrite it back?
--   3. On the CLIENT: does the car visibly jump d tiles diagonally?
--      If getX changed server-side but the client shows nothing, the change
--      is not replicating (fallback: client relay or hard-stop).
--***********************************************************************
if isClient() then return end

local Spike = {}

local function nearVehicles(player, radius)
    local cell = getCell()
    if not cell then return {} end
    local out = {}
    -- B42.17+: getVehicles() returns a Set, not an ArrayList -- no get(i).
    -- Iterate whichever shape the build gives us (ArrayList / Set / table).
    local ok, vehicles = pcall(function() return cell:getVehicles() end)
    if ok and vehicles then
        local function consider(v)
            local dx, dy
            pcall(function() dx, dy = v:getX() - player:getX(), v:getY() - player:getY() end)
            if dx and dx * dx + dy * dy <= (radius or 30) ^ 2 then out[#out + 1] = v end
        end
        if vehicles.size and vehicles.get then
            local n = 0
            pcall(function() n = vehicles:size() end)
            for i = 0, n - 1 do
                local v
                pcall(function() v = vehicles:get(i) end)
                if v then consider(v) end
            end
        elseif vehicles.iterator then
            local it
            pcall(function() it = vehicles:iterator() end)
            if it and it.hasNext and it.next then
                while true do
                    local has = false
                    pcall(function() has = it:hasNext() end)
                    if not has then break end
                    local v
                    pcall(function() v = it:next() end)
                    if v then consider(v) end
                end
            end
        elseif type(vehicles) == "table" then
            for _, v in pairs(vehicles) do
                if v then consider(v) end
            end
        end
    end
    return out
end

local recheck = nil
Events.OnTick.Add(function()
    if not recheck then return end
    recheck.ticks = recheck.ticks - 1
    if recheck.ticks > 0 then return end
    local v = recheck.v
    print(string.format(
        "[RailroaderMP] spikeVehicle RECHECK (60 ticks later): id=%s script=%s pos=(%.2f, %.2f, %.2f)",
        tostring(recheck.id), tostring(recheck.script),
        v:getX(), v:getY(), v:getZ()))
    recheck = nil
end)

--------------------------------------------------------------------------
-- moveCar(v, d): the actual test -- write the vehicle's position directly and
-- schedule a 60-tick recheck to see whether the sim/physics overwrites it.
--------------------------------------------------------------------------
function Spike.moveCar(v, d)
    if not v then
        print("[RailroaderMP] spikeVehicle: no vehicle")
        return false
    end
    d = tonumber(d) or 5
    local id, script, ox, oy, oz
    pcall(function() id = v:getId() end)
    pcall(function() script = v:getScriptName() end)
    pcall(function() ox, oy, oz = v:getX(), v:getY(), v:getZ() end)
    print(string.format("[RailroaderMP] spikeVehicle BEFORE: id=%s script=%s pos=(%.2f, %.2f, %.2f)",
        tostring(id), tostring(script), ox or 0, oy or 0, oz or 0))

    local function probe(name, fn)
        local ok, res = pcall(fn)
        print("[RailroaderMP] spikeVehicle " .. name .. " -> ok=" .. tostring(ok)
              .. (ok and ("") or (" err=" .. tostring(res))))
        return ok
    end
    probe("setX(+d)", function() v:setX(ox + d) end)
    probe("setY(+d)", function() v:setY(oy + d) end)

    local nx, ny, nz
    pcall(function() nx, ny, nz = v:getX(), v:getY(), v:getZ() end)
    print(string.format("[RailroaderMP] spikeVehicle AFTER:  pos=(%.2f, %.2f, %.2f)",
        nx or 0, ny or 0, nz or 0))
    recheck = { v = v, ticks = 60, id = id, script = script }
    return true
end

--------------------------------------------------------------------------
-- onCarHit(car): convenience wrapper (no longer auto-called since v1.0.3c --
-- call it manually for a retest, e.g. RR.SpikeVehicleMove.onCarHit(car)).
--------------------------------------------------------------------------
function Spike.onCarHit(car)
    if not car then return end
    Spike.moveCar(car, 5)
end

local function spike(player, args)
    local list = nearVehicles(player, 30)
    print("[RailroaderMP] spikeVehicle: " .. #list .. " vehicle(s) within 30 tiles")
    for i, v in ipairs(list) do
        local id, script, x, y
        pcall(function() id = v:getId() end)
        pcall(function() script = v:getScriptName() end)
        pcall(function() x, y = v:getX(), v:getY() end)
        print(string.format("[RailroaderMP]   #%d id=%s script=%s pos=(%.2f, %.2f)",
            i, tostring(id), tostring(script), x or 0, y or 0))
    end
    local idx = tonumber(args.i) or 1
    local v = list[idx]
    if not v then
        print("[RailroaderMP] spikeVehicle: vehicle #" .. idx .. " not found")
        return
    end
    if args.z then
        local oz
        pcall(function() oz = v:getZ() end)
        local ok, res = pcall(function() v:setZ(oz + 0.5) end)
        print("[RailroaderMP] spikeVehicle setZ(+0.5) -> ok=" .. tostring(ok)
              .. (ok and ("") or (" err=" .. tostring(res))))
    end
    Spike.moveCar(v, tonumber(args.d) or 5)
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "RailroaderMP" or command ~= "spikeVehicle" then return end
    if not player then return end
    pcall(function() spike(player, args or {}) end)
end)

RR = RR or {}
RR.SpikeVehicleMove = Spike
print("[RailroaderMP] RR_SpikeVehicleMove loaded (spike only; auto-triggers on train-car impact, manual: sendClientCommand('RailroaderMP','spikeVehicle',{d=5}))")
