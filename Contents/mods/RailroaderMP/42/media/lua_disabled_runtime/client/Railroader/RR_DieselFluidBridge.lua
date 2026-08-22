--***********************************************************************
-- Railroader / RR_DieselFluidBridge  -- CLIENT adapter that puts a fuel menu ON THE
-- LOCOMOTIVE (right-click the loco in the world, exactly like a car), and moves the
-- modded `Diesel` fluid between the player's cans and the loco's abstract fuel tank
-- (RR_Engine.fuel). Two directions, both TIMED ACTIONS (RR_FuelActions):
--   * "Pour diesel into locomotive"   can -> loco  (no tool)
--   * "Siphon diesel from locomotive" loco -> can  (needs a HOSE, like a car)
--
-- Like the vehicle menu, the options live on the vehicle/loco, and the CAN + HOSE
-- are found automatically in the player's inventory. Detection of the clicked loco
-- mirrors ISVehicleMenu: `IsoObjectPicker.Instance:PickTarget(mouse)` returns the
-- IsoMovingObject under the cursor (our loco is an IsoAnimal), with a nearest-loco
-- fallback so a near-miss click still works.
--
-- All "how much moves" math is the pure, unit-tested RR_DieselFluid; this file only
-- picks the loco/can/hose, gates the menu, and hands the transfer to the timed
-- actions. Instant Bridge.*Now() helpers remain for console debugging.
--***********************************************************************

print("[Railroader] RR_DieselFluidBridge.lua: loading...")

local Diesel = require("Railroader/RR_DieselFluid")
local Engine = require("Railroader/RR_Engine")
require("Railroader/RR_Body")     -- hull geometry for the reach test (RR.Body)

local Bridge = {}

-- How close (tiles) the player must be to a loco to fuel it -- measured from the
-- loco's DRAWN HULL (hullDistTo below), not from the animal's centre.
--
-- ARM'S LENGTH (owner, 2026-07-30). It was 8 tiles TO THE CENTRE, which for a ~15-tile
-- body is not one reach but several: ~6.4 tiles of clear ground abeam the cab, and
-- barely half a tile past the nose. Hull-relative, one number means the same thing all
-- the way round the loco -- and it is the same number, and the same geometry, as the
-- E-key boarding reach (RR_Ride.MOUNT_REACH): if you are close enough to climb aboard,
-- you are close enough to tip a can in.
--
-- WHY 2.0 AND NOT 1.0: the collider's hard keep-out sweep (RR_Collider.ejectIntruders)
-- pushes anything that is not the driver out to the MESH BBOX edge + EJECT_MARGIN, and
-- the bbox overhangs the drawn hull by RR_Body.END_TRIM (1.5) at each end. So the
-- closest a survivor can physically stand is ~0.45 tiles off the flank but ~1.65 off
-- the nose -- a reach of 1.0 would work alongside the loco and silently refuse at the
-- ends, which reads as a bug. 2.0 clears the standoff everywhere and still means "you
-- are standing at the loco".
Bridge.REACH_TILES = 2.0

-- Any FluidContainer counts as the vessel -- not just the modded can. Vanilla
-- PetrolCan, a plastic bottle, whatever the survivor has. What is IN it is another
-- matter: the loco burns DIESEL ONLY (Diesel.isDiesel / Diesel.acceptsFluid), so
-- petrol is neither a valid source to pour nor a valid target to siphon into.

local function fuelCap()
    return (Engine and Engine.C and Engine.C.FUEL_CAP) or 600
end

-- the modded `Diesel` FluidType object to hand to FluidContainer:addFluid. B42 keys
-- modded fluids by their script name, so Fluid.Get(name) resolves ours; the raw
-- string is the last-ditch fallback if the lookup is unavailable.
function Bridge.dieselFluid()
    return (Fluid and Fluid.Get and Fluid.Get(Diesel.FLUID)) or Diesel.FLUID
end

--------------------------------------------------------------------------
-- Can inspection.
--------------------------------------------------------------------------
-- true if the item can hold fluid (has a FluidContainer). No specific item type is
-- required -- any container works; the FLUID is what we are strict about.
function Bridge.isOurCan(item)
    return item ~= nil and item.getFluidContainer ~= nil and item:getFluidContainer() ~= nil
end

-- the FluidType name currently in the container ("Diesel", "Petrol", ...), or nil
-- when it is empty / not a container at all.
function Bridge.fluidName(item)
    if not Bridge.isOurCan(item) then return nil end
    local prim = item:getFluidContainer():getPrimaryFluid()
    if not prim then return nil end
    return prim:getFluidTypeString()
end

-- litres of DIESEL currently in the container (0 if empty or holding anything else).
function Bridge.canLitres(item)
    if not Diesel.isDiesel(Bridge.fluidName(item)) then return 0 end
    return item:getFluidContainer():getAmount()
end

-- free room to siphon diesel into (litres). Only an EMPTY container or one already
-- holding diesel qualifies -- we won't top up a petrol can (or a water bottle) with
-- diesel, the same rule the fluid's empty BlendWhiteList states.
function Bridge.canFree(item)
    if not Bridge.isOurCan(item) then return 0 end
    if not Diesel.acceptsFluid(Bridge.fluidName(item)) then return 0 end
    return item:getFluidContainer():getFreeCapacity()
end

-- the diesel can in inventory with the MOST diesel (to pour), or nil.
function Bridge.bestPourCan(inv)
    if not inv then return nil end
    local items, best, bestL = inv:getItems(), nil, 0
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local l = Bridge.canLitres(it)
        if l > bestL then best, bestL = it, l end
    end
    return best
end

-- the diesel can in inventory with the MOST free room (to siphon into), or nil.
function Bridge.bestSiphonCan(inv)
    if not inv then return nil end
    local items, best, bestF = inv:getItems(), nil, 0
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if Bridge.isOurCan(it) then
            local f = Bridge.canFree(it)
            if f > bestF then best, bestF = it, f end
        end
    end
    return best
end

--------------------------------------------------------------------------
-- findHose(inv) -> a siphon hose, or nil. Prefers the vanilla SIPHON_GAS tag (any
-- siphon-capable item counts), falls back to the concrete RubberHose type.
--------------------------------------------------------------------------
function Bridge.findHose(inv)
    if not inv then return nil end
    if ItemTag and ItemTag.SIPHON_GAS then
        local ok, h = pcall(function() return inv:getFirstTagRecurse(ItemTag.SIPHON_GAS) end)
        if ok and h then return h end
    end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it.getFullType and it:getFullType() == "Base.RubberHose" then return it end
        -- Tag fallback: B42 InventoryItem.hasTag takes an ItemTag ENUM ONLY -- there is
        -- no hasTag(String) overload (verified in the decompiled source). Passing a
        -- String throws "No implementation found for hasTag(Clothing, String)", and a
        -- failed Java invocation leaves the Kahlua call-frame corrupted, so EVERY later
        -- Java call in the session dies with "callFrame is null" -- which on the
        -- exit-to-menu Lua reload cascades into thousands of "derive of non-table"
        -- errors. pcall does NOT undo that VM corruption, so we must never make the
        -- bad call: use the enum. (The primary getFirstTagRecurse above already covers
        -- tagged items container-wide; this is belt-and-suspenders for a bare item.)
        if ItemTag and ItemTag.SIPHON_GAS and it.hasTag then
            local ok, tagged = pcall(function() return it:hasTag(ItemTag.SIPHON_GAS) end)
            if ok and tagged then return it end
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- Loco lookup.
--------------------------------------------------------------------------
-- the active loco record whose animal is `animal`, or nil.
function Bridge.recForAnimal(animal)
    if not animal or not RR or not RR.TrainEntity or not RR.TrainEntity.active then return nil end
    for _, rec in ipairs(RR.TrainEntity.active) do
        if rec.animal == animal then return rec end
    end
    return nil
end

-- Distance (tiles) from the player to a loco record's DRAWN HULL -- 0 while standing
-- on the body itself. The pose is the one RR_TrainEntity applied this tick
-- (rec.lastPose, calibration included), so the box is where the model is; a record
-- with no pose yet (spawned this frame) falls back to centre distance less the hull
-- half-length. Same helper, same geometry and the same reasoning as the E-key boarding
-- reach in RR_Ride: for a 15-tile body, distance to the CENTRE is not a reach at all.
local function distTo(player, rec)
    if not rec.animal then return nil end
    local size = 0.7
    pcall(function() size = rec.animal:getAnimalSize() end)
    if rec.lastPose and RR.Body and RR.Body.hullDistance then
        return (RR.Body.hullDistance(rec.lastPose, size, player:getX(), player:getY()))
    end
    local dx = rec.animal:getX() - player:getX()
    local dy = rec.animal:getY() - player:getY()
    local d  = math.sqrt(dx * dx + dy * dy)
    local half = 0
    if RR.Body and RR.Body.hullExtents then half = RR.Body.hullExtents(size) * 0.5 end
    return math.max(0, d - half)
end

-- nearest active loco within maxTiles, or nil.
function Bridge.nearestLoco(player, maxTiles)
    if not player or not RR or not RR.TrainEntity or not RR.TrainEntity.active then return nil end
    local best, bestD = nil, (maxTiles or Bridge.REACH_TILES)
    for _, rec in ipairs(RR.TrainEntity.active) do
        if rec.animal and rec.engine and not rec.animal:isDead() then
            local d = distTo(player, rec)
            if d and d <= bestD then best, bestD = rec, d end
        end
    end
    return best
end

-- the loco the player clicked on (PickTarget under the mouse), if it is one of ours
-- and within reach; else the nearest loco within reach. nil if none is close.
function Bridge.targetLoco(player)
    if IsoObjectPicker and IsoObjectPicker.Instance and getMouseXScaled then
        local ok, picked = pcall(function()
            return IsoObjectPicker.Instance:PickTarget(getMouseXScaled(), getMouseYScaled())
        end)
        if ok and picked then
            local rec = Bridge.recForAnimal(picked)
            if rec and rec.engine and not rec.animal:isDead() and distTo(player, rec) <= Bridge.REACH_TILES then
                return rec
            end
        end
    end
    return Bridge.nearestLoco(player, Bridge.REACH_TILES)
end

--------------------------------------------------------------------------
-- halo(player, text, good).
--------------------------------------------------------------------------
function Bridge.halo(player, text, good)
    if not player or not HaloTextHelper then return end
    if good then HaloTextHelper.addText(player, text)
    else HaloTextHelper.addBadText(player, text) end
end

--------------------------------------------------------------------------
-- Instant console/debug transfers (no timed action).
--------------------------------------------------------------------------
function Bridge.pourNow(player, item, rec)
    if not (item and rec and rec.engine) then return 0 end
    local fc = item:getFluidContainer()
    -- canLitres, not fc:getAmount() -- a container of petrol has litres but no diesel.
    local res = Diesel.pour(rec.engine.fuel, fuelCap(), Bridge.canLitres(item))
    if res.addedUnits <= 1e-6 then return 0 end
    fc:removeFluid(res.drawnLitres); rec.engine.fuel = res.newFuel
    return res.addedUnits
end

function Bridge.siphonNow(player, item, rec)
    if not (item and rec and rec.engine) then return 0 end
    if not Diesel.acceptsFluid(Bridge.fluidName(item)) then return 0 end
    local fc = item:getFluidContainer()
    local res = Diesel.siphon(rec.engine.fuel, fc:getAmount(), fc:getCapacity())
    if res.addedLitres <= 1e-6 then return 0 end
    fc:addFluid(Bridge.dieselFluid(), res.addedLitres); rec.engine.fuel = res.newFuel
    return res.drawnUnits
end

function Bridge.refuelNearestLoco(player)
    player = player or getPlayer()
    if not player then return 0 end
    local rec = Bridge.nearestLoco(player, Bridge.REACH_TILES)
    if not rec then Bridge.halo(player, getText("IGUI_RR_DieselNoLoco"), false); return 0 end
    local can = Bridge.bestPourCan(player:getInventory())
    if not can then Bridge.halo(player, getText("IGUI_RR_DieselNoCan"), false); return 0 end
    local added = Bridge.pourNow(player, can, rec)
    Bridge.halo(player, getText(added > 0 and "IGUI_RR_DieselPoured" or "IGUI_RR_DieselNoRoom"), added > 0)
    return added
end

--------------------------------------------------------------------------
-- The loco's world context menu: right-click the loco ->
--   "Pour diesel into locomotive"   (greyed: no diesel can / tank full)
--   "Siphon diesel from locomotive" (greyed: no hose / no empty can / tank empty)
-- The can + hose are found automatically in the player's inventory.
--------------------------------------------------------------------------
local function greyOut(opt, why)
    opt.notAvailable = true
    local tt = ISWorldObjectContextMenu.addToolTip and ISWorldObjectContextMenu.addToolTip() or nil
    if not tt and ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.addToolTip then
        tt = ISInventoryPaneContextMenu.addToolTip()
    end
    if tt then tt.description = why; opt.toolTip = tt end
end

local function onFillWorldContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    if RR.MP and RR.MP.blocked() and not RR.MPClient then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local rec = Bridge.targetLoco(player)
    if not rec or not rec.engine then return end

    local cap  = fuelCap()
    local fuel = rec.engine.fuel or 0
    local inv  = player:getInventory()

    -- POUR  can -> loco
    do
        local can = Bridge.bestPourCan(inv)
        local opt = context:addOption(getText("IGUI_RR_DieselPourOption"), player, function()
            local c = Bridge.bestPourCan(player:getInventory())
            if c then ISTimedActionQueue.add(RR_PourDieselAction:new(player, c, rec)) end
        end)
        if not can then
            greyOut(opt, getText("IGUI_RR_DieselNoCan"))
        elseif not Diesel.canPour(fuel, cap, Bridge.canLitres(can)) then
            greyOut(opt, getText("IGUI_RR_DieselNoRoom"))
        end
    end

    -- SIPHON  loco -> can  (needs a hose)
    do
        local can  = Bridge.bestSiphonCan(inv)
        local hose = Bridge.findHose(inv)
        local opt = context:addOption(getText("IGUI_RR_DieselSiphonOption"), player, function()
            local c = Bridge.bestSiphonCan(player:getInventory())
            if c then ISTimedActionQueue.add(RR_SiphonDieselAction:new(player, c, rec)) end
        end)
        if not hose then
            greyOut(opt, getText("IGUI_RR_DieselNeedHose"))
        elseif not can then
            greyOut(opt, getText("IGUI_RR_DieselNeedCan"))
        elseif not Diesel.canSiphon(fuel, Bridge.canLitres(can), can:getFluidContainer():getCapacity()) then
            greyOut(opt, getText("IGUI_RR_DieselLocoEmpty"))
        end
    end

    do
        -- findWrench: recursive through bags (a wrench in a backpack is still a
        -- wrench; FindAndReturn only scans the inventory root). Falls back to
        -- FindAndReturn for safety.
        local function findWrench(inv2)
            if not inv2 then return nil end
            if ItemTag and ItemTag.Wrench and inv2.getFirstTagRecurse then
                local ok, h = pcall(function() return inv2:getFirstTagRecurse(ItemTag.Wrench) end)
                if ok and h then return h end
            end
            if inv2.getFirstTypeRecurse then
                local ok, h = pcall(function() return inv2:getFirstTypeRecurse("Base.Wrench") end)
                if ok and h then return h end
            end
            if inv2.FindAndReturn then
                local ok, h = pcall(function() return inv2:FindAndReturn("Base.Wrench") end)
                if ok and h then return h end
            end
            return nil
        end
        local wrench = findWrench(inv)
        local opt = context:addOption(getText("IGUI_RR_RepairOption"), player, function()
            local w = findWrench(player:getInventory())
            if w and rec.id then
                -- v1.0.5: repair is a TIMED ACTION now -- a 5 in-game-minute
                -- progress bar (RR_RepairAction), then the server applies the
                -- +5 durability points and answers with the "serviced" halo.
                ISTimedActionQueue.add(RR_RepairAction:new(player, rec, w))
            end
        end)
        -- Grey ONLY when there is no wrench. Whether the loco still needs repair
        -- is the server's call (the client's condition copy can be stale in MP) --
        -- it answers with a halo either way, so a click is never a silent no-op.
        if not wrench then greyOut(opt, getText("IGUI_RR_WrenchRequired")) end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldContextMenu)

RR = RR or {}
RR.DieselFluid = Bridge

print("[Railroader] RR_DieselFluidBridge.lua: loaded OK")
return Bridge
