--***********************************************************************
-- Railroader / RR_DieselFluid  -- the bridge between B42's fluid system and
-- the loco's abstract fuel tank.
--
-- PURE LUA, NO ENGINE DEPENDENCIES -- unit-tested in a bare interpreter
-- (tests/run_tests.lua). Everything that decides HOW MUCH diesel moves when you
-- pour a can into the loco lives here as pure functions; the client adapter
-- (RR_DieselFluidBridge) supplies the real FluidContainer amount and the loco's
-- Engine.fuel, and writes the results back.
--
-- WHY A BRIDGE AT ALL. B42 has a first-class fluid system (verified in the
-- decompile: `fluid Diesel { ... }` registers as FluidType.Modded, persists by
-- name, and every `component FluidContainer` item can hold it -- see
-- docs/ROADMAP.md Task 1.L). But a FluidContainer lives on an InventoryItem or an
-- IsoObject, and the loco is an IsoAnimal -- neither. So the design is:
--   * DIESEL-AS-FLUID lives on PORTABLE ITEMS (the diesel can) -- real litres you
--     can carry, pour, and one day loot / fill at a pump.
--   * The LOCO TANK stays the abstract Engine.fuel number RR_Engine already uses.
--   * Pouring a can into the loco is the one place the two meet: this module
--     converts litres -> Engine units and clamps to the tank's free room.
-- This complements RR_Refuel (the depot's bulk reserve -> loco). That path is the
-- home-base fill; a diesel can is the emergency top-up you carry.
--
-- UNITS. The game's fluid amount is in LITRES (verified: FluidContainer.getAmount()
-- * 1000 == millilitres, ISFarmingMenu.lua; PetrolCan capacity 10.0 == 10 L).
-- Engine.fuel is in abstract game units (FUEL_CAP = 600 == a full loco tank).
-- UNITS_PER_LITRE converts between them. This is a GAMEPLAY knob, NOT physical
-- realism: a real GP7 tank is ~6400 L, which would make a 20 L jerry can ~2 units
-- (~0.3% of the tank) and pointless. We deliberately make a can matter -- at the
-- default a full 20 L can is ~10% of a tank -- and keep the honest number here so
-- it is easy to retune.
--***********************************************************************

local Diesel = {}

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

--------------------------------------------------------------------------
-- Tunables.
--------------------------------------------------------------------------
-- Engine fuel units gained per litre of diesel poured. At 3.0 a full 20 L can
-- (RR_DieselCan capacity) restores 60 units == 10% of a 600-unit tank, so a
-- handful of found cans is a meaningful reserve but the depot tank (RR_Refuel)
-- is still the real supply. NOT physical -- see the unit note above.
Diesel.UNITS_PER_LITRE = 3.0

-- The diesel can's real capacity in litres (matches the FluidContainer Capacity
-- in railroader_fluids.txt; kept here so the pure tests and the script agree).
Diesel.CAN_CAPACITY_L = 20.0

-- The ONE fluid the loco's tank deals in, by the FluidType name B42 keys and
-- persists modded fluids under -- the `fluid Diesel` block in
-- media/scripts/railroader_fluids.txt. A GP7 burns diesel and nothing else: petrol
-- neither goes in nor comes out (owner, 2026-07-30). This string is the single
-- source of truth for both directions, so the fuelling menu and the timed actions
-- can never disagree about what is in the hose.
Diesel.FLUID = "Diesel"

--------------------------------------------------------------------------
-- isDiesel(fluidTypeString) -> true only for our diesel.
-- acceptsFluid(fluidTypeString) -> true if a container currently holding this fluid
--   may be filled with diesel: EMPTY (nil / "") or already diesel. Anything else --
--   petrol, water, whisky -- is refused rather than contaminated, matching the empty
--   BlendWhiteList on the fluid definition.
-- Both take the STRING from FluidContainer:getPrimaryFluid():getFluidTypeString()
-- (nil when the container is empty), so they stay engine-free and testable.
--------------------------------------------------------------------------
function Diesel.isDiesel(name)
    return name == Diesel.FLUID
end

function Diesel.acceptsFluid(name)
    if name == nil or name == "" then return true end
    return Diesel.isDiesel(name)
end

--------------------------------------------------------------------------
-- litresToUnits(l) / unitsToLitres(u) -- the raw conversion, exposed for the HUD
-- and for tests. Both floor at 0.
--------------------------------------------------------------------------
function Diesel.litresToUnits(l, unitsPerLitre)
    local upl = tonumber(unitsPerLitre) or Diesel.UNITS_PER_LITRE
    return math.max(0, (tonumber(l) or 0)) * upl
end

function Diesel.unitsToLitres(u, unitsPerLitre)
    local upl = tonumber(unitsPerLitre) or Diesel.UNITS_PER_LITRE
    if upl <= 0 then return 0 end
    return math.max(0, (tonumber(u) or 0)) / upl
end

--------------------------------------------------------------------------
-- canPour(fuel, fuelCap, canLitres) -> true if there is diesel in the can AND room
-- in the tank. The menu uses this to show/grey the "Pour into locomotive" option.
--------------------------------------------------------------------------
function Diesel.canPour(fuel, fuelCap, canLitres)
    local f   = math.max(0, tonumber(fuel) or 0)
    local cap = tonumber(fuelCap) or 0
    local can = tonumber(canLitres) or 0
    return can > 1e-6 and f < cap - 1e-6
end

--------------------------------------------------------------------------
-- pour(fuel, fuelCap, canLitres, unitsPerLitre) -> result table:
--   { addedUnits, drawnLitres, newFuel, newCanLitres }
-- Empties as much of the can into the tank as will fit: limited by BOTH the tank's
-- free room (converted to litres) and the litres actually in the can. One-shot;
-- the client applies it, then writes newFuel to the loco and removes drawnLitres
-- from the can's FluidContainer. Idempotent on a full tank or an empty can (all
-- zeros, no state change).
--------------------------------------------------------------------------
function Diesel.pour(fuel, fuelCap, canLitres, unitsPerLitre)
    local upl = tonumber(unitsPerLitre) or Diesel.UNITS_PER_LITRE
    local f   = math.max(0, tonumber(fuel) or 0)
    local cap = math.max(0, tonumber(fuelCap) or 0)
    local can = math.max(0, tonumber(canLitres) or 0)

    local roomUnits  = math.max(0, cap - f)
    local roomLitres = (upl > 0) and (roomUnits / upl) or 0
    local drawn      = math.min(can, roomLitres)
    local added      = drawn * upl

    return {
        addedUnits   = added,
        drawnLitres  = drawn,
        newFuel      = clamp(f + added, 0, cap),
        newCanLitres = can - drawn,
    }
end

--------------------------------------------------------------------------
-- canSiphon(fuel, canLitres, canCap) -> true if the loco has diesel to give AND the
-- can has room to take it. The menu uses this to show/grey "Siphon diesel".
--------------------------------------------------------------------------
function Diesel.canSiphon(fuel, canLitres, canCap)
    local f   = math.max(0, tonumber(fuel) or 0)
    local can = math.max(0, tonumber(canLitres) or 0)
    local cap = math.max(0, tonumber(canCap) or 0)
    return f > 1e-6 and can < cap - 1e-6
end

--------------------------------------------------------------------------
-- siphon(fuel, canLitres, canCap, unitsPerLitre) -> result table:
--   { drawnUnits, addedLitres, newFuel, newCanLitres }
-- The inverse of pour(): drains the loco tank into the can through a hose. Limited
-- by BOTH the diesel actually in the loco (converted to litres) and the can's free
-- room. One-shot; the client applies it, subtracts drawnUnits from the loco and adds
-- addedLitres to the can's FluidContainer. Idempotent on an empty loco or a full can.
--------------------------------------------------------------------------
function Diesel.siphon(fuel, canLitres, canCap, unitsPerLitre)
    local upl = tonumber(unitsPerLitre) or Diesel.UNITS_PER_LITRE
    local f   = math.max(0, tonumber(fuel) or 0)
    local can = math.max(0, tonumber(canLitres) or 0)
    local cap = math.max(0, tonumber(canCap) or 0)

    local locoLitres = (upl > 0) and (f / upl) or 0
    local canFree    = math.max(0, cap - can)
    local moved      = math.min(locoLitres, canFree)
    local drawn      = moved * upl

    return {
        drawnUnits   = drawn,
        addedLitres  = moved,
        newFuel      = clamp(f - drawn, 0, f),
        newCanLitres = clamp(can + moved, 0, cap),
    }
end

RR = RR or {}
RR.DieselFluidMath = Diesel

return Diesel
