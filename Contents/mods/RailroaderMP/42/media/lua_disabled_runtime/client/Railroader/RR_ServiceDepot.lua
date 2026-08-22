--***********************************************************************
-- Railroader / RR_ServiceDepot  -- CLIENT adapter for the FUELLING STATIONS: the
-- bulk diesel tanks standing on the line, the 4x2 tank object that anchors each
-- one, and the two right-click actions the survivor gets at a tank:
--   * "Refuel locomotive from the tank" -- this tank's reserve -> loco tank
--                                      (RR_Refuel), the SECOND fuel source alongside
--                                      the field can-pour (RR_DieselFluidBridge).
--   * "Fill container from the tank"    -- this tank's reserve -> a fuel container, to
--                                      carry diesel out to a stranded loco.
-- Battery charging is NOT here: a flat bank is JUMP-STARTED off external power (a
-- generator or live grid) via the normal crank, not a depot charger -- there is no
-- wayside charger on the K&L branch (see RR_Ride.hasExternalPower / RR_Engine).
--
-- TWO TANKS (owner, 2026-07-30): the Muldraugh depot service point and the VALLEY
-- STATION freight terminal. Each is a station in the pure registry
-- RR_Refuel.STATIONS, and each holds its OWN reserve under its own ModData key, so
-- draining one never touches the other. The depot's tank is placed relative to the
-- service point the loco spawns at (`follows = "depot"`, rolled from RR_Depot's
-- spawn); a wayside tank sits at fixed coordinates and materialises on APPROACH,
-- for the same reason the loco does -- its chunk has to be streamed in before we
-- can put an IsoObject on a square.
--
-- All "how much moves" math and all "which tank am I at" logic is the pure,
-- unit-tested RR_Refuel / RR_DieselFluid; this file only rolls/holds the reserves
-- (in the save's global RR_World ModData, beside the world-spawn flag), stamps the
-- tanks, gates the menu, and queues the timed actions (RR_ServiceActions).
-- SP-focused, like the rest of the mod.
--***********************************************************************

print("[Railroader] RR_ServiceDepot.lua: loading...")

local Refuel = require("Railroader/RR_Refuel")
local Engine = require("Railroader/RR_Engine")

local ServiceDepot = {}

-- Every fuelling station is the vanilla 4x2 horizontal diesel tank, captured 1:1
-- from a Build 42.19 Louisville fuel yard. TANK_LAYOUT lists,
-- per tile, the sprites stacked on it (ox = east, oy = south from the tank's NW
-- corner). It draws from the PLAYER's own game sprites, so it renders as the tank
-- in-game even though our local (older) sprite pack maps these indices to something
-- else. Set PLACE_STAND false to suppress it.
ServiceDepot.PLACE_STAND = true

-- NW-corner offset from the service point (tiles) -- the DEPOT station only, whose
-- anchor is a route point rather than a fixed coordinate. The depot straight runs
-- N-S, so the tank sits a few tiles EAST on the open apron, clear of the loco
-- габарит; its 4-tile long axis runs E-W with the pump end toward the approaching
-- survivor. dy=0 puts the NW corner level with the spawn point. Tune with the
-- footprint overlay (U) if it fouls the body. A wayside station's `at` IS its NW
-- corner and this offset does not apply to it.
ServiceDepot.TANK_OFFSET = { dx = 3, dy = 0 }
ServiceDepot.TANK_W      = 4     -- footprint (for the menu-distance centre)
ServiceDepot.TANK_H      = 2

ServiceDepot.TANK_LAYOUT = {
    { ox = 0, oy = 0, sprites = { "industry_02_33", "industry_02_68" } },
    { ox = 1, oy = 0, sprites = { "industry_02_26", "industry_02_69" } },
    { ox = 2, oy = 0, sprites = { "industry_02_70" } },
    { ox = 3, oy = 0, sprites = { "industry_02_71" } },
    { ox = 0, oy = 1, sprites = { "industry_02_64" } },
    { ox = 1, oy = 1, sprites = { "industry_02_65" } },
    { ox = 2, oy = 1, sprites = { "industry_02_66" } },
    { ox = 3, oy = 1, sprites = { "industry_02_67" } },
}

-- How near the tank the survivor must stand for the menu (tiles), and how far the
-- loco may sit from the station's rail point and still count as "parked here" (its
-- 15-tile body must overlap the point). ZONE is the DEFAULT: a station may name its
-- own tighter `zone` when a second track runs inside this radius (Valley Station
-- does -- you fuel from the platform road, not from the main 14 tiles away).
--
-- REACH is ARM'S LENGTH (owner, 2026-07-30): measured to the nearest EDGE of the 4x2
-- tank (Refuel.standDistance, fed the footprint by stationNear), so 1.0 means the
-- survivor is standing on a tile that touches the tank -- a neighbour tile puts him
-- 0.5 away straight on and ~0.71 diagonally, while the next ring out is already 1.5.
-- It was 5 tiles to the tank's CENTRE, i.e. ~3 tiles of clear ground on the long sides
-- and ~4 off the ends: you could fill a can from a tank you were nowhere near, with
-- nothing on screen to say which tank was paying for it.
ServiceDepot.REACH = 1.0
ServiceDepot.ZONE  = 14

local MD_TAG = "RR_World"

local function fuelCap() return (Engine and Engine.C and Engine.C.FUEL_CAP) or 600 end

--------------------------------------------------------------------------
-- RR_World ModData: each station's diesel reserve + where its tank got placed.
--------------------------------------------------------------------------
local function worldData()
    local wd = nil
    pcall(function() wd = ModData.getOrCreate(MD_TAG) end)
    return wd
end

-- resolve a station argument: an entry, an id string, or nil = the depot (station 1).
-- A NUMBER means an old-style call like setReserve(600) from the console; treat it as
-- the depot's reserve and say so rather than silently reading a station named 600.
function ServiceDepot.stationOf(st)
    if type(st) == "table" then return st end
    if type(st) == "string" then return Refuel.station(st) end
    return Refuel.STATIONS[1]
end

function ServiceDepot.getReserve(st)
    local s  = ServiceDepot.stationOf(st)
    if RR.MPClient and s then return RR.MPClient.reserves[s.id] or 0 end
    local wd = worldData()
    if not (s and wd) then return 0 end
    return wd[s.mdReserve] or 0
end

function ServiceDepot.setReserve(st, v)
    if RR.MPClient then return end
    if type(st) == "number" then          -- legacy console call: setReserve(units)
        v, st = st, nil
    end
    local s  = ServiceDepot.stationOf(st)
    local wd = worldData()
    if s and wd then wd[s.mdReserve] = math.max(0, v or 0) end
end

function ServiceDepot.addReserve(st, delta)
    if RR.MPClient then return end
    if type(st) == "number" then          -- legacy console call: addReserve(units)
        delta, st = st, nil
    end
    local s = ServiceDepot.stationOf(st)
    ServiceDepot.setReserve(s, ServiceDepot.getReserve(s) + (delta or 0))
end

--------------------------------------------------------------------------
-- Where a station is. Two answers, and they are NOT the same point:
--   standAnchor(st) -> the tank's NW corner (where the sprites are / the menu is)
--   railPoint(st)   -> the spot on the rails the loco must be parked at
--------------------------------------------------------------------------
-- the NW corner the tank was ACTUALLY placed at (from the save), else where it
-- WOULD go. Preferring the saved coords means moving a station's `at` never
-- orphans a tank already stamped into someone's world.
function ServiceDepot.standAnchor(st)
    local s = ServiceDepot.stationOf(st)
    if not s then return nil end
    local wd = worldData()
    local saved = wd and wd[s.mdStand]
    if saved then return saved.x, saved.y, saved.z or 0 end
    if s.at then return s.at.x, s.at.y, s.at.z or 0 end
    if s.follows == "depot" and RR.Depot and RR.Depot.point then
        local px, py, pz = RR.Depot.point()
        if px then
            return math.floor(px) + ServiceDepot.TANK_OFFSET.dx,
                   math.floor(py) + ServiceDepot.TANK_OFFSET.dy,
                   math.floor(pz or 0)
        end
    end
    return nil
end

-- the tank centre (menu distance is measured from here, not the corner).
function ServiceDepot.standCentre(st)
    local x, y, z = ServiceDepot.standAnchor(st)
    if not x then return nil end
    local cx, cy = Refuel.tankCentre(x, y, ServiceDepot.TANK_W, ServiceDepot.TANK_H)
    return cx, cy, z
end

-- where the loco has to stand. A wayside station names its own rail point; the depot
-- station uses the service point itself (which is what the old route-distance test
-- measured against -- the depot ready track is straight, so the two agree).
function ServiceDepot.railPoint(st)
    local s = ServiceDepot.stationOf(st)
    if not s then return nil end
    if s.rail then return s.rail.x, s.rail.y, s.rail.z or 0 end
    if s.follows == "depot" and RR.Depot and RR.Depot.point then
        return RR.Depot.point()
    end
    return nil
end

-- how far from railPoint(st) the loco still counts as spotted at this tank.
function ServiceDepot.zoneOf(st)
    local s = ServiceDepot.stationOf(st)
    return (s and tonumber(s.zone)) or ServiceDepot.ZONE
end

--------------------------------------------------------------------------
-- serviceLoco(st): the active loco PARKED at THIS station (within ZONE of the
-- station's rail point, speed ~ 0), or nil. Driving away removes the options.
--
-- This is a WORLD-distance test, not a route-distance one: with more than one tank
-- on the line, "how far along route main" cannot tell the depot from Valley
-- Station, and a tank on a terminal siding is not on route "main" at all. It is also
-- what enforces WHICH TRACK serves a tank -- at Valley the platform road and the main
-- are 14 tiles apart, so the station's own tighter `zone` is the whole gate.
--------------------------------------------------------------------------
function ServiceDepot.serviceLoco(st)
    if not (RR and RR.TrainEntity and RR.TrainEntity.active) then return nil end
    local ax, ay = ServiceDepot.railPoint(st)
    if not ax then return nil end
    local zone = ServiceDepot.zoneOf(st)
    for _, rec in ipairs(RR.TrainEntity.active) do
        if rec.engine and rec.animal and not rec.animal:isDead() then
            local lx, ly
            pcall(function() lx, ly = rec.animal:getX(), rec.animal:getY() end)
            local v = math.abs((rec.drive and rec.drive.v) or rec.speed or 0)
            if lx and v < 0.2 and Refuel.inZone(ax, ay, lx, ly, zone) then
                return rec
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- placeStand(st): stamp the 4x2 tank at this station, once. Each sprite becomes a
-- tagged IsoObject; they save with the chunk, so on reload they are already there
-- and we do not re-place them.
--------------------------------------------------------------------------
function ServiceDepot.placeStand(st)
    if not ServiceDepot.PLACE_STAND then return false end
    local s  = ServiceDepot.stationOf(st)
    local wd = worldData()
    if not (s and wd) then return false end
    if wd[s.mdStand] then return false end                 -- already standing
    local bx, by, bz = ServiceDepot.standAnchor(s)
    if not bx then return false end
    bx, by, bz = math.floor(bx), math.floor(by), math.floor(bz or 0)

    -- ALL EIGHT SQUARES FIRST. A half-streamed chunk would otherwise stamp half a
    -- tank and bank the spot, leaving a permanently broken object -- and the
    -- approach poll would never come back to finish it. Missing ground is
    -- temporary, so bail and let the next poll try again.
    for _, tile in ipairs(ServiceDepot.TANK_LAYOUT) do
        if not getSquare(bx + tile.ox, by + tile.oy, bz) then
            print(string.format("[Railroader] tank '%s': tile (%d,%d,%d) not streamed in yet -- will retry",
                  s.id, bx + tile.ox, by + tile.oy, bz))
            return false
        end
    end

    local placed = 0
    for _, tile in ipairs(ServiceDepot.TANK_LAYOUT) do
        local sq = getSquare(bx + tile.ox, by + tile.oy, bz)
        if sq then
            for _, sprName in ipairs(tile.sprites) do
                if not getSprite(sprName) then
                    print("[Railroader] tank '" .. s.id .. "': sprite '" .. sprName .. "' not found -- skipped")
                else
                    local obj = IsoObject.new(sq, sprName, sprName)
                    pcall(function() obj:getModData().rrFuelStand = true end)
                    sq:AddTileObject(obj)
                    if isClient() then pcall(function() obj:transmitCompleteItemToServer() end) end
                    if isServer() then pcall(function() obj:transmitCompleteItemToClients() end) end
                    pcall(function() triggerEvent("OnObjectAdded", obj) end)
                    placed = placed + 1
                end
            end
        end
    end
    wd[s.mdStand] = { x = bx, y = by, z = bz }
    print(string.format("[Railroader] tank '%s' placed at NW (%d,%d,%d), %d sprites",
          s.id, bx, by, bz, placed))
    return true
end

--------------------------------------------------------------------------
-- removeStand(st): pull every tagged tank sprite across its footprint (debug --
-- forget() re-arms a station).
--------------------------------------------------------------------------
function ServiceDepot.removeStand(st)
    local s  = ServiceDepot.stationOf(st)
    local wd = worldData()
    if not (s and wd and wd[s.mdStand]) then return end
    local p = wd[s.mdStand]
    for _, tile in ipairs(ServiceDepot.TANK_LAYOUT) do
        local sq = getSquare(p.x + tile.ox, p.y + tile.oy, p.z)
        if sq and sq:getObjects() then
            local objs = sq:getObjects()
            for i = objs:size() - 1, 0, -1 do
                local o = objs:get(i)
                local tagged = false
                pcall(function() tagged = o and o:getModData() and o:getModData().rrFuelStand == true end)
                if tagged then pcall(function() sq:transmitRemoveItemFromSquare(o) end) end
            end
        end
    end
    wd[s.mdStand] = nil
end

--------------------------------------------------------------------------
-- rollReserve(st, roll): give a station its one-time diesel reserve. Each tank
-- rolls independently, so what Valley Station holds says nothing about the depot.
--------------------------------------------------------------------------
function ServiceDepot.rollReserve(st, roll)
    local s  = ServiceDepot.stationOf(st)
    local wd = worldData()
    if not (s and wd) then return end
    if wd[s.mdReserve] ~= nil then return end
    wd[s.mdReserve] = Refuel.rollReserve(roll or 0.5, fuelCap())
    print(string.format("[Railroader] tank '%s': diesel reserve rolled = %.0f units (~%.1f tanks)",
          s.id, wd[s.mdReserve], wd[s.mdReserve] / fuelCap()))
end

--------------------------------------------------------------------------
-- onSpawn(roll): called by RR_Depot the moment the world loco materialises -- roll
-- the DEPOT station's reserve once, then stamp its tank. Wayside stations are not
-- touched here; they wait for a survivor to walk up to them (tryPlaceWayside).
--------------------------------------------------------------------------
function ServiceDepot.onSpawn(roll)
    local depot = Refuel.STATIONS[1]
    ServiceDepot.rollReserve(depot, roll)
    ServiceDepot.placeStand(depot)
end

--------------------------------------------------------------------------
-- tryPlaceWayside(): the approach trigger for tanks at fixed coordinates. Rolls the
-- reserve and stamps the tank the first time a survivor comes near enough for the
-- chunk to be streamed in. Polled ~1/s and cheap: a distance compare per station
-- that stops doing anything once the tank stands.
--------------------------------------------------------------------------
function ServiceDepot.tryPlaceWayside()
    if RR.MP and RR.MP.blocked() then return end     -- client-side tank placement = desync (RR_MP)
    local wd = worldData()
    if not wd then return end
    local p = getPlayer()
    if not p then return end
    for _, s in ipairs(Refuel.STATIONS) do
        if s.at and not wd[s.mdStand] then
            local dx, dy = s.at.x - p:getX(), s.at.y - p:getY()
            local r = s.approach or 40
            if (dx * dx + dy * dy) <= r * r then
                local sq = nil
                pcall(function() sq = getCell():getGridSquare(s.at.x, s.at.y, s.at.z or 0) end)
                if sq then
                    ServiceDepot.rollReserve(s, ZombRandFloat(0, 1))
                    ServiceDepot.placeStand(s)
                end
            end
        end
    end
end

--------------------------------------------------------------------------
-- forget(): wipe EVERY station's reserve + tank so the debug re-arm starts the
-- fuel economy fresh (RR_Depot.forget calls this).
--------------------------------------------------------------------------
function ServiceDepot.forget()
    local wd = worldData()
    for _, s in ipairs(Refuel.STATIONS) do
        ServiceDepot.removeStand(s)
        if wd then wd[s.mdReserve] = nil end
    end
end

--------------------------------------------------------------------------
-- report(): console helper -- every station, its reserve and whether its tank has
-- been placed yet. The one command that answers "which tank did I just drain".
--------------------------------------------------------------------------
function ServiceDepot.report()
    local cap = fuelCap()
    for _, s in ipairs(Refuel.STATIONS) do
        local x, y, z = ServiceDepot.standAnchor(s)
        local res = ServiceDepot.getReserve(s)
        local wd  = worldData()
        local rx, ry = ServiceDepot.railPoint(s)
        print(string.format("[Railroader] tank '%s': reserve %.0f u (~%.1f tanks) · %s · NW %s · rail %s r=%d · loco spotted: %s",
              s.id, res, res / cap,
              (wd and wd[s.mdStand]) and "placed" or "not placed yet",
              x and string.format("(%d,%d,%d)", x, y, z or 0) or "unknown",
              rx and string.format("(%d,%d)", rx, ry) or "unknown",
              ServiceDepot.zoneOf(s),
              ServiceDepot.serviceLoco(s) and "yes" or "no"))
    end
end

--------------------------------------------------------------------------
-- gotoStation(id): gated dev teleport to a tank, so a station can be tested without
-- driving the length of the map. Debug-gated like the movement keys -- it is a tool,
-- not a mechanic.
--------------------------------------------------------------------------
function ServiceDepot.gotoStation(id)
    if not (RR.Debug and RR.Debug.isOn()) then
        print("[Railroader] gotoStation: debug is off (RR.Debug.set(true) to enable).")
        return
    end
    local s = ServiceDepot.stationOf(id)
    if not s then print("[Railroader] gotoStation: no station '" .. tostring(id) .. "'."); return end
    local x, y, z = ServiceDepot.standCentre(s)
    if not x then print("[Railroader] gotoStation: station '" .. s.id .. "' has no anchor yet."); return end
    local p = getPlayer()
    if p then pcall(function() p:teleportTo(x, y + 3, z or 0) end) end
    print(string.format("[Railroader] gotoStation: '%s' (%.0f,%.0f,%.0f).", s.id, x, y, z or 0))
end

--------------------------------------------------------------------------
-- The service menu. Right-click near a tank:
--   "Refuel locomotive from the tank"  (greyed: no loco here / dry tank / loco full)
--   "Fill container from the tank"     (greyed: dry tank / no usable container)
-- Which tank is decided by the pure Refuel.nearestStation, so the option can only
-- ever spend the reserve of the tank the survivor is standing at.
--------------------------------------------------------------------------
local function greyOut(opt, why)
    opt.notAvailable = true
    local tt = ISWorldObjectContextMenu.addToolTip and ISWorldObjectContextMenu.addToolTip() or nil
    if tt then tt.description = why; opt.toolTip = tt end
end

-- the station whose tank the player is standing at, or nil. Each entry carries the
-- tank's FOOTPRINT as well as its centre, so REACH is measured from the edge of the
-- 4x2 tank the survivor can see and not from a point two tiles inside it.
function ServiceDepot.stationNear(player)
    local centres = {}
    for _, s in ipairs(Refuel.STATIONS) do
        local cx, cy = ServiceDepot.standCentre(s)
        if cx then
            centres[#centres + 1] = { id = s.id, x = cx, y = cy,
                                      w = ServiceDepot.TANK_W, h = ServiceDepot.TANK_H }
        end
    end
    local id = Refuel.nearestStation(player:getX(), player:getY(), centres, ServiceDepot.REACH)
    return id and Refuel.station(id) or nil
end

local function onFillWorldContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    if RR.MP and RR.MP.blocked() and not RR.MPClient then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local station = ServiceDepot.stationNear(player)
    if not station then return end

    local rec     = ServiceDepot.serviceLoco(station)
    local reserve = ServiceDepot.getReserve(station)

    -- REFUEL from this tank's reserve
    do
        local opt = context:addOption(getText("IGUI_RR_DepotRefuel"), player, function()
            local r = ServiceDepot.serviceLoco(station)
            if r and RR_DepotRefuelAction then
                ISTimedActionQueue.add(RR_DepotRefuelAction:new(player, r, station))
            end
        end)
        if not rec then
            greyOut(opt, getText("IGUI_RR_DepotNoLoco"))
        elseif reserve <= 0 then
            greyOut(opt, getText("IGUI_RR_DepotDry"))
        elseif not Refuel.canRefuel(rec.engine.fuel or 0, fuelCap(), reserve) then
            greyOut(opt, getText("IGUI_RR_DepotTankFull"))
        end
    end

    -- (Battery charging removed: a flat bank is JUMP-STARTED off external power -- a
    -- generator or live grid -- via the normal crank, not a depot charger. See
    -- RR_Ride.hasExternalPower / RR_Engine.canCrank(env.externalPower).)

    -- FILL a container from this tank's reserve (carry diesel out to a stranded loco).
    -- No loco needed -- this is just the bulk tank -> your can.
    do
        local inv = player:getInventory()
        local can = (RR.DieselFluid and RR.DieselFluid.bestSiphonCan)
                    and RR.DieselFluid.bestSiphonCan(inv) or nil
        local opt = context:addOption(getText("IGUI_RR_DepotFillCan"), player, function()
            local c = (RR.DieselFluid and RR.DieselFluid.bestSiphonCan)
                      and RR.DieselFluid.bestSiphonCan(player:getInventory())
            if c and RR_FillFromDepotAction then
                ISTimedActionQueue.add(RR_FillFromDepotAction:new(player, c, station))
            end
        end)
        if reserve <= 0 then
            greyOut(opt, getText("IGUI_RR_DepotDry"))
        elseif not can then
            greyOut(opt, getText("IGUI_RR_DepotNoContainer"))
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldContextMenu)

-- Approach poll for the wayside tanks (~1s cadence, same shape as RR_Depot's spawn
-- trigger). Goes quiet for good once every fixed-coordinate tank stands.
local tick = 0
local function onTick()
    tick = tick + 1
    if tick < 60 then return end
    tick = 0
    pcall(ServiceDepot.tryPlaceWayside)
end
Events.OnTick.Add(onTick)

RR = RR or {}
RR.ServiceDepot = ServiceDepot

print("[Railroader] RR_ServiceDepot.lua: loaded OK (" .. #Refuel.STATIONS .. " fuelling station(s))")
return ServiceDepot
