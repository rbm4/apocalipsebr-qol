--***********************************************************************
-- Railroader / RR_ServiceActions  -- the depot-service timed (progress-bar) actions,
-- modelled on RR_FuelActions:
--   * RR_DepotRefuelAction   -- depot reserve -> loco tank    (RR_Refuel)
--   * RR_FillFromDepotAction -- depot reserve -> fuel container (RR_DieselFluid)
--
-- The refuel applies INCREMENTALLY across the bar (tied to getJobDelta), so an
-- interrupted action only consumes what actually flowed -- the reserve is never
-- billed for diesel the tank did not receive. Duration scales with the amount moved.
-- SP-focused. (Battery charging is gone: a flat bank is jump-started off external
-- power via the normal crank, not a timed action here.)
--***********************************************************************

require "TimedActions/ISBaseTimedAction"

local Refuel = require("Railroader/RR_Refuel")
local Engine = require("Railroader/RR_Engine")
local Diesel = require("Railroader/RR_DieselFluid")

local function fuelCap()    return (Engine and Engine.C and Engine.C.FUEL_CAP) or 600 end

local MS_PER_UNIT   = 1000 / Refuel.RATE    -- diesel units -> ms
local MS_PER_LITRE  = 150                    -- can fill feel (matches RR_FuelActions)

-- Fluid identity -- the depot reserve is DIESEL, so a container filled from it comes
-- out holding diesel, empty or not. (Same rule and same former bug as RR_FuelActions:
-- an empty container used to fall back to vanilla Petrol.)
local function dieselFluid()
    return (Fluid and Fluid.Get and Fluid.Get(Diesel.FLUID)) or Diesel.FLUID
end

local function fluidName(fc)
    local prim = fc and fc:getPrimaryFluid()
    return prim and prim:getFluidTypeString() or nil
end

-- reserveOf(action): the diesel left in THIS action's tank. Every action carries the
-- station it was opened at (there is more than one bulk tank on the line now), so a
-- fill can only ever spend the reserve of the tank the survivor walked up to. A nil
-- station falls back to the depot, which is what an old-style call meant.
local function reserveOf(a)
    if not RR.ServiceDepot then return 0 end
    return RR.ServiceDepot.getReserve(a and a.station) or 0
end

--========================================================================
-- RR_DepotRefuelAction  -- depot reserve -> loco tank
--========================================================================
RR_DepotRefuelAction = ISBaseTimedAction:derive("RR_DepotRefuelAction")

function RR_DepotRefuelAction:new(character, rec, station)
    local o = ISBaseTimedAction.new(self, character)
    o.rec              = rec
    o.station          = station          -- WHICH tank pays for this fill
    o.stopOnWalk       = true
    o.stopOnRun        = true
    o.caloriesModifier = 1.5
    local reserve = reserveOf(o)
    local fuel    = (rec and rec.engine and rec.engine.fuel) or 0
    o.startFuel   = fuel
    o.total       = Refuel.fillAmount(fuel, fuelCap(), reserve)   -- units that will move
    o.applied     = 0
    o.maxTime     = math.max(1, o.total * MS_PER_UNIT)
    return o
end

function RR_DepotRefuelAction:isValid()
    if not (self.rec and self.rec.engine and self.rec.animal and not self.rec.animal:isDead()) then return false end
    local reserve = reserveOf(self)
    return self.total > 0 and Refuel.canRefuel(self.rec.engine.fuel or 0, fuelCap(), reserve)
end

function RR_DepotRefuelAction:waitToStart()
    self.character:faceThisObject(self.rec.animal)
    return self.character:shouldBeTurning()
end

-- move the increment of diesel that "flowed" since the last frame.
local function pushFuel(self)
    if RR.MPClient then return end
    local want = self.total * self:getJobDelta()
    local add  = want - self.applied
    if add > 1e-6 then
        self.rec.engine.fuel = math.min(fuelCap(), self.startFuel + want)
        if RR.ServiceDepot then RR.ServiceDepot.addReserve(self.station, -add) end
        self.applied = want
    end
end

function RR_DepotRefuelAction:update()
    self.character:faceThisObject(self.rec.animal)
    pushFuel(self)
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function RR_DepotRefuelAction:start()
    pcall(function() self:setActionAnim("TakeGasFromVehicle") end)
    -- Vanilla vehicle-at-the-pump refuel sound, via the world emitter (character:playSound
    -- is silent on the player in this B42 build -- see RR_Sound.actionLoopStart).
    if RR.Sound then
        self.sound = RR.Sound.actionLoopStart(self.character:getX(), self.character:getY(),
                     self.character:getZ(), "VehicleAddFuelFromGasPump")
    end
end

function RR_DepotRefuelAction:stop()
    if self.sound and RR.Sound then RR.Sound.actionLoopStop(self.sound); self.sound = nil end
    ISBaseTimedAction.stop(self)
end

function RR_DepotRefuelAction:perform()
    if self.sound and RR.Sound then RR.Sound.actionLoopStop(self.sound); self.sound = nil end
    self:getJobDelta()             -- ensure delta is 1 at completion
    pushFuel(self)
    if RR.MPClient and self.rec.id then
        sendClientCommand(self.character, "RailroaderMP", "fuel", {
            id = self.rec.id, op = "depot", station = self.station and self.station.id,
        })
    end
    pcall(function()
        if HaloTextHelper then HaloTextHelper.addText(self.character, getText("IGUI_RR_DepotRefuelled")) end
    end)
    ISBaseTimedAction.perform(self)
end

--========================================================================
-- RR_FillFromDepotAction  -- depot reserve -> a fuel container (carry fuel out).
-- The depot reserve is a units source exactly like the loco tank, so this reuses
-- the pure, unit-tested Diesel.siphon (units source -> can litres).
--========================================================================
RR_FillFromDepotAction = ISBaseTimedAction:derive("RR_FillFromDepotAction")

function RR_FillFromDepotAction:new(character, item, station)
    local o = ISBaseTimedAction.new(self, character)
    o.item             = item
    o.station          = station          -- WHICH tank pays for this fill
    o.fc               = item and item:getFluidContainer() or nil
    o.stopOnWalk       = true
    o.stopOnRun        = true
    o.caloriesModifier = 1.5
    local reserve = reserveOf(o)
    local cur     = o.fc and o.fc:getAmount() or 0
    local cap     = o.fc and o.fc:getCapacity() or 0
    local plan    = Diesel.siphon(reserve, cur, cap)
    o.maxTime     = math.max(1, plan.addedLitres * MS_PER_LITRE)
    return o
end

function RR_FillFromDepotAction:isValid()
    if not (self.item and self.fc) then return false end
    if not Diesel.acceptsFluid(fluidName(self.fc)) then return false end
    local reserve = reserveOf(self)
    return reserve > 0 and Diesel.canSiphon(reserve, self.fc:getAmount(), self.fc:getCapacity())
end

function RR_FillFromDepotAction:update()
    self.item:setJobDelta(self:getJobDelta())
    self.item:setJobType(getText("IGUI_RR_DepotFillCan"))
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function RR_FillFromDepotAction:start()
    self.item:setJobDelta(0.0)
    pcall(function() self:setActionAnim("TakeGasFromVehicle") end)
    pcall(function() self:setOverrideHandModels(nil, self.item:getStaticModel()) end)
    -- Vanilla "fill a canister at the pump" sound, world-emitter path (see above).
    if RR.Sound then
        self.sound = RR.Sound.actionLoopStart(self.character:getX(), self.character:getY(),
                     self.character:getZ(), "CanisterAddFuelFromGasPump")
    end
end

function RR_FillFromDepotAction:stop()
    if self.sound and RR.Sound then RR.Sound.actionLoopStop(self.sound); self.sound = nil end
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function RR_FillFromDepotAction:perform()
    if self.sound and RR.Sound then RR.Sound.actionLoopStop(self.sound); self.sound = nil end
    self.item:setJobDelta(0.0)
    if RR.MPClient then
        sendClientCommand(self.character, "RailroaderMP", "fuel", {
            id = 0, op = "depotCan", station = self.station and self.station.id, itemId = self.item:getID(),
        })
        ISBaseTimedAction.perform(self)
        return
    end
    local reserve = reserveOf(self)
    local res = Diesel.siphon(reserve, self.fc:getAmount(), self.fc:getCapacity())
    if res.addedLitres > 0 and Diesel.acceptsFluid(fluidName(self.fc)) then
        self.fc:addFluid(dieselFluid(), res.addedLitres)
        if RR.ServiceDepot then RR.ServiceDepot.setReserve(self.station, res.newFuel) end
        pcall(function() self.item:syncItemFields() end)
    end
    pcall(function()
        if HaloTextHelper then HaloTextHelper.addText(self.character, getText("IGUI_RR_DepotCanFilled")) end
    end)
    ISBaseTimedAction.perform(self)
end

--========================================================================
-- RR_RepairAction  -- wrench repair with a progress bar: 5 IN-GAME minutes
-- per repair (maxTime 300 -- the same value the vanilla B42 engine-repair
-- action uses for one repair, ISVehicleMechanics.onRepairEngine), then the
-- server is asked to add +5 durability points (0.05 on the 0..1 condition).
-- The server stays authoritative (wrench condition, "already serviced", the
-- actual +5) -- this action is just the visible read bar + the request.
--========================================================================
RR_RepairAction = ISBaseTimedAction:derive("RR_RepairAction")

function RR_RepairAction:new(character, rec, wrench)
    local o = ISBaseTimedAction.new(self, character)
    o.rec               = rec
    o.wrench            = wrench
    o.stopOnWalk        = true
    o.stopOnRun         = true
    o.caloriesModifier  = 4
    o.jobType           = getText("IGUI_RR_RepairOption")
    o.maxTime           = 300   -- 5 in-game minutes (matches vanilla ISRepairEngine)
    return o
end

function RR_RepairAction:isValid()
    return self.rec ~= nil and self.rec.engine ~= nil and self.rec.animal ~= nil
        and not self.rec.animal:isDead()
        and self.wrench ~= nil and self.character:getInventory():containsID(self.wrench:getID())
end

function RR_RepairAction:waitToStart()
    self.character:faceThisObject(self.rec.animal)
    return self.character:shouldBeTurning()
end

function RR_RepairAction:update()
    self.character:faceThisObject(self.rec.animal)
    self.character:setMetabolicTarget(Metabolics.MediumWork)
end

function RR_RepairAction:start()
    -- Vanilla engine-repair animation, wrench in hand.
    pcall(function() self:setActionAnim("VehicleWorkOnMid") end)
    pcall(function() self:setOverrideHandModels(self.wrench, nil) end)
end

function RR_RepairAction:stop()
    ISBaseTimedAction.stop(self)
end

function RR_RepairAction:perform()
    if self.rec and self.rec.id and self.wrench then
        sendClientCommand(self.character, "RailroaderMP", "fuel", {
            id = self.rec.id, op = "repair", itemId = self.wrench:getID(),
        })
    end
    ISBaseTimedAction.perform(self)
end

print("[Railroader] RR_ServiceActions.lua: loaded OK")
