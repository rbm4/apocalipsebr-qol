--***********************************************************************
-- Railroader / RR_Refuel  -- diesel refuelling from the depot's finite reserve.
--
-- PURE LUA, NO ENGINE DEPENDENCIES -- unit-tested in a bare interpreter
-- (tests/run_tests.lua). The client adapter (RR_Depot / the world-object menu)
-- supplies the loco's tank state (Engine.fuel / FUEL_CAP) and the depot reserve
-- (a number in the save's RR_World ModData); everything that decides HOW MUCH
-- diesel moves lives here as pure functions.
--
-- The story (Task: refuelling): a small branch-line depot has a bulk diesel tank
-- with whatever was left in it at the outbreak -- a FINITE reserve, rolled once
-- when the depot first materialises (rollReserve). The survivor tops the loco up
-- from it at the service point (d = DEPOT.distance); when the tank runs dry there
-- is no resupply yet, so fuel is a real resource to ration. There is intentionally
-- NO jerry-can top-up of the reserve (locked design decision) -- add one later if
-- the economy needs it.
--
-- THERE IS MORE THAN ONE TANK (owner, 2026-07-30). Every tank is a STATION in the
-- registry below, each with its OWN reserve rolled and persisted separately, so
-- draining one does not touch the other. The registry lives here, in pure code,
-- because the thing most likely to break silently with two tanks is *which* tank
-- the menu is talking to -- drain Valley Station's reserve while standing at
-- Muldraugh and nothing in-game would look wrong until the depot ran dry early.
-- So station lookup (nearestStation) and the "is she parked at THIS tank" test
-- (inZone) are pure functions with tests, not inline client arithmetic.
--
-- Units: fuel is in Engine units (FUEL_CAP = 600 = a full loco tank). The reserve
-- is measured in the same units; rollReserve expresses it as a multiple of a full
-- tank so it stays honest if FUEL_CAP is retuned.
--***********************************************************************

local Refuel = {}

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

--------------------------------------------------------------------------
-- Tunables.
--------------------------------------------------------------------------
-- How fast diesel flows into the loco (Engine units / second). At 30 u/s a full
-- 600-unit tank fills from empty in ~20 s -- long enough to feel like fuelling a
-- locomotive, short enough not to be a chore.
Refuel.RATE = 30

-- The depot's bulk reserve when the world first spawns it, as a multiple of a full
-- loco tank. min 2 .. max 4 tanks => a handful of line runs before the depot is dry
-- and the loco becomes a stranded asset unless it was parked back at the service
-- point. Rolled once (rollReserve) and stored per-save.
Refuel.RESERVE = { MIN_TANKS = 2.0, MAX_TANKS = 4.0 }

--------------------------------------------------------------------------
-- rollReserve(roll, fuelCap) -> the depot's starting diesel reserve (units).
-- roll in [0,1) (ZombRandFloat in-game, a fixed number in tests) picks linearly
-- between MIN_TANKS and MAX_TANKS full tanks. Date-independent: diesel that was in
-- the depot tank at the outbreak does not evaporate.
--------------------------------------------------------------------------
function Refuel.rollReserve(roll, fuelCap)
    local r   = clamp(tonumber(roll) or 0.5, 0, 1)
    local cap = tonumber(fuelCap) or 600
    local R   = Refuel.RESERVE
    return (R.MIN_TANKS + r * (R.MAX_TANKS - R.MIN_TANKS)) * cap
end

--------------------------------------------------------------------------
-- canRefuel(fuel, fuelCap, reserve) -> true if there is diesel to give AND room
-- to take it. The menu uses this to show/grey the "Refuel locomotive" option.
--------------------------------------------------------------------------
function Refuel.canRefuel(fuel, fuelCap, reserve)
    local f   = math.max(0, tonumber(fuel) or 0)
    local cap = tonumber(fuelCap) or 0
    local res = tonumber(reserve) or 0
    return res > 0 and f < cap - 1e-6
end

--------------------------------------------------------------------------
-- fillAmount(fuel, fuelCap, reserve) -> how much a full top-up would move right
-- now: limited by the tank's remaining room AND the reserve. Handy for sizing a
-- one-shot action (duration ~ amount / RATE).
--------------------------------------------------------------------------
function Refuel.fillAmount(fuel, fuelCap, reserve)
    local f   = math.max(0, tonumber(fuel) or 0)
    local cap = tonumber(fuelCap) or 0
    local res = math.max(0, tonumber(reserve) or 0)
    return math.max(0, math.min(cap - f, res))
end

--------------------------------------------------------------------------
-- transfer(fuel, fuelCap, reserve, dt, rate) -> added, newFuel, newReserve.
-- Moves rate*dt units of diesel from the depot reserve into the tank, capped by
-- both the tank's remaining room and the reserve. Per-tick drip: the client calls
-- it each frame of the timed action. rate defaults to Refuel.RATE.
--------------------------------------------------------------------------
function Refuel.transfer(fuel, fuelCap, reserve, dt, rate)
    local f   = math.max(0, tonumber(fuel) or 0)
    local cap = tonumber(fuelCap) or 0
    local res = math.max(0, tonumber(reserve) or 0)
    local step = math.max(0, (tonumber(rate) or Refuel.RATE) * (tonumber(dt) or 0))
    local added = math.min(step, math.max(0, cap - f), res)
    return added, clamp(f + added, 0, cap), res - added
end

--------------------------------------------------------------------------
-- THE STATION REGISTRY. One entry per bulk diesel tank in the world.
--
--   id         a stable key (goes in log lines and console helpers).
--   follows    "depot" = the anchor is not a fixed coordinate but the route point
--              RR_Depot.point() plus the client's TANK_OFFSET. Only the Muldraugh
--              depot works this way, because its tank is placed relative to the
--              service point the loco spawns at.
--   at         {x,y,z} of the tank's NW CORNER for a wayside tank at a fixed spot.
--              This is the one number to change to move a tank.
--   rail       {x,y,z} on the rails where the loco must stand to be fuelled. Not
--              derived from `at`: which track serves a tank is a map fact, not a
--              geometric one (Valley Station's tank stands BETWEEN two tracks -- the
--              main to its east and the terminal's platform road to its west -- and
--              only one of them is the one you fuel from).
--   zone       how far (tiles) the loco may sit from `rail` and still count as
--              "parked here"; nil = the client's default ServiceDepot.ZONE. Worth
--              setting where a second track runs within the default radius, so a
--              loco standing on the WRONG road cannot be fuelled from this tank.
--   mdReserve  / mdStand  the RR_World ModData keys holding this station's reserve
--              and its placed-tank coords. The Muldraugh entry KEEPS THE LEGACY
--              UNSUFFIXED KEYS ("rrFuelReserve"/"rrStand") so existing saves carry
--              their reserve and their already-placed tank across this change.
--   approach   how near (tiles) a survivor must come for a wayside tank to
--              materialise -- its chunk has to be streamed in first, the same
--              reason the loco spawns on approach (Task 1.J).
--------------------------------------------------------------------------
Refuel.STATIONS = {
    {
        id        = "muldraugh",
        follows   = "depot",
        mdReserve = "rrFuelReserve",     -- LEGACY key -- do not rename (save compat)
        mdStand   = "rrStand",           -- LEGACY key -- do not rename (save compat)
    },
    {
        id        = "valley",
        -- Valley Station freight terminal. Owner-picked spot, 2026-07-30.
        at        = { x = 12655, y = 4441, z = 0 },
        -- You fuel from the TERMINAL's PLATFORM ROAD, not from the main (owner,
        -- 2026-07-30). Two tracks pass this tank: route "main" runs dead straight
        -- along x = 12665 to its east, and the freight terminal's unloading-platform
        -- loop (`freight_terminal_1`) runs dead straight along x = 12651 to its west.
        -- The platform road is the one a loco is actually spotted on to be worked, so
        -- that is the rail she has to stand on -- 4 tiles west of the tank.
        rail      = { x = 12651, y = 4443, z = 0 },
        -- ...and the main line is only 14 tiles from that point, i.e. EXACTLY the
        -- default zone (inZone is inclusive at the radius), so without a tighter one a
        -- loco parked out on the main would qualify too and the distinction above
        -- would be decorative. 12 keeps a 2-tile margin while still letting a
        -- 15-tile body that overlaps the tank count as spotted.
        zone      = 12,
        mdReserve = "rrFuelReserve_valley",
        mdStand   = "rrStand_valley",
        approach  = 40,
    },
}

--------------------------------------------------------------------------
-- station(id) -> the registry entry, or nil.
--------------------------------------------------------------------------
function Refuel.station(id)
    for _, st in ipairs(Refuel.STATIONS) do
        if st.id == id then return st end
    end
    return nil
end

--------------------------------------------------------------------------
-- tankCentre(nwX, nwY, w, h) -> cx, cy
-- The middle of a w x h tank whose NW corner is (nwX, nwY). Menu distance is
-- measured from the centre, not the corner, so a survivor standing at the far end
-- of a 4-tile tank is still "at" it.
--------------------------------------------------------------------------
function Refuel.tankCentre(nwX, nwY, w, h)
    return (tonumber(nwX) or 0) + (tonumber(w) or 0) * 0.5,
           (tonumber(nwY) or 0) + (tonumber(h) or 0) * 0.5
end

--------------------------------------------------------------------------
-- standDistance(px, py, c) -> tiles from (px,py) to the NEAREST POINT of a tank.
-- `c` is one entry of the list nearestStation takes: { x, y } is the tank CENTRE and
-- the optional { w, h } its footprint in tiles.
--
-- With w/h the tank is an axis-aligned RECTANGLE and this is the standard point-to-box
-- distance -- 0 while standing on it, and "1 tile" means one tile of clearance from
-- the tank's EDGE. Without them it degrades to plain centre distance, which is what it
-- used to be everywhere. That distinction only started to matter when the menu reach
-- came down to arm's length (owner, 2026-07-30): measured to the middle of a 4x2 tank,
-- a reach of 1 is unreachable at the long sides (2 tiles of tank stand between the
-- survivor and the centre) while still being generous off the short ends. Same fix,
-- and the same reason, as RR_Body.hullDistance for the 15-tile loco.
--------------------------------------------------------------------------
function Refuel.standDistance(px, py, c)
    c = c or {}
    local dx = math.abs((tonumber(px) or 0) - (tonumber(c.x) or 0)) - (tonumber(c.w) or 0) * 0.5
    local dy = math.abs((tonumber(py) or 0) - (tonumber(c.y) or 0)) - (tonumber(c.h) or 0) * 0.5
    if dx < 0 then dx = 0 end
    if dy < 0 then dy = 0 end
    return math.sqrt(dx * dx + dy * dy)
end

--------------------------------------------------------------------------
-- inZone(ax, ay, bx, by, r) -> true if b is within r of a (plain circle).
--------------------------------------------------------------------------
function Refuel.inZone(ax, ay, bx, by, r)
    local dx = (tonumber(bx) or 0) - (tonumber(ax) or 0)
    local dy = (tonumber(by) or 0) - (tonumber(ay) or 0)
    local rr = tonumber(r) or 0
    return (dx * dx + dy * dy) <= rr * rr
end

--------------------------------------------------------------------------
-- nearestStation(px, py, centres, reach) -> id, dist
-- centres is what the client resolved this frame: a list of { id, x, y } tank
-- centres, each optionally carrying its footprint { w, h } so the distance is
-- measured to the tank's EDGE rather than its middle (standDistance). A station whose
-- tank is not placed yet simply is not in the list.
-- Returns the id of the NEAREST one within reach, and its distance; nil if none is
-- close. Nearest-wins matters: if two tanks are ever built within reach of each
-- other, the menu must still name exactly one reserve, and it must be the one the
-- survivor is standing at.
--------------------------------------------------------------------------
function Refuel.nearestStation(px, py, centres, reach)
    local bestId, bestD = nil, tonumber(reach) or 0
    for _, c in ipairs(centres or {}) do
        local d = Refuel.standDistance(px, py, c)
        if d <= bestD then bestId, bestD = c.id, d end
    end
    if not bestId then return nil end
    return bestId, bestD
end

RR = RR or {}
RR.Refuel = Refuel

return Refuel
