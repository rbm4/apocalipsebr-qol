--***********************************************************************
-- Railroader / RR_FuelActions  -- the two timed (progress-bar) actions that move
-- diesel between a can and the loco, modelled on the vanilla vehicle fuel actions
-- (ISAddGasolineToVehicle / ISTakeGasolineFromVehicle):
--   * RR_PourDieselAction   -- can -> loco  (no tool; you tip a can in)
--   * RR_SiphonDieselAction -- loco -> can  (needs a hose, like siphoning a car)
--
-- The loco tank is the abstract RR_Engine.fuel (units); the can is a real B42
-- FluidContainer (litres). All the "how much moves" arithmetic is the pure,
-- unit-tested RR_DieselFluid; these actions only drive the animation/progress bar
-- and apply the computed transfer on perform(). SP-focused (the mod's MP path is a
-- known open item); no netAction split.
--
-- Duration scales with the litres moved (like the vanilla `take * 50` ms), so a
-- fuller can/tank takes proportionally longer. Cancels if the player walks away.
--***********************************************************************

require "TimedActions/ISBaseTimedAction"

local Diesel = require("Railroader/RR_DieselFluid")
local Engine = require("Railroader/RR_Engine")

local MS_PER_LITRE = 150   -- feel: a full 20 L can ~= 3 s

local function fuelCap()
    return (Engine and Engine.C and Engine.C.FUEL_CAP) or 600
end

--------------------------------------------------------------------------
-- Fluid identity. The loco burns DIESEL ONLY, in both directions: we pour only
-- diesel in, and what comes out of the hose is diesel -- never vanilla Petrol,
-- whatever the receiving container happens to be. (This is where the "siphoned the
-- 800 into a plastic bottle and got GASOLINE" bug lived: an empty container used to
-- fall back to Fluid.Petrol, so the bottle came out labelled Gasoline.)
--------------------------------------------------------------------------
-- the modded `Diesel` FluidType object for addFluid (B42 keys modded fluids by name).
local function dieselFluid()
    return (Fluid and Fluid.Get and Fluid.Get(Diesel.FLUID)) or Diesel.FLUID
end

-- the fluid name in a container, or nil when empty.
local function fluidName(fc)
    local prim = fc and fc:getPrimaryFluid()
    return prim and prim:getFluidTypeString() or nil
end

-- litres of DIESEL in the container (0 for petrol/water/empty).
local function dieselLitres(fc)
    if not fc then return 0 end
    if not Diesel.isDiesel(fluidName(fc)) then return 0 end
    return fc:getAmount()
end

--========================================================================
-- RR_PourDieselAction  -- can -> loco
--========================================================================
RR_PourDieselAction = ISBaseTimedAction:derive("RR_PourDieselAction")

function RR_PourDieselAction:new(character, item, rec)
    local o = ISBaseTimedAction.new(self, character)
    o.item        = item                                   -- the diesel can
    o.rec         = rec                                    -- loco record
    o.fc          = item and item:getFluidContainer() or nil
    o.stopOnWalk  = true
    o.stopOnRun   = true
    o.caloriesModifier = 2.0
    local fuel  = (rec and rec.engine and rec.engine.fuel) or 0
    local plan  = Diesel.pour(fuel, fuelCap(), dieselLitres(o.fc))
    o.maxTime   = math.max(1, plan.drawnLitres * MS_PER_LITRE)
    return o
end

function RR_PourDieselAction:isValid()
    return self.item ~= nil and self.rec ~= nil and self.rec.engine ~= nil and self.fc ~= nil
        and self.rec.animal ~= nil and not self.rec.animal:isDead()
        and Diesel.canPour(self.rec.engine.fuel, fuelCap(), dieselLitres(self.fc))
end

function RR_PourDieselAction:waitToStart()
    self.character:faceThisObject(self.rec.animal)
    return self.character:shouldBeTurning()
end

function RR_PourDieselAction:update()
    self.character:faceThisObject(self.rec.animal)
    self.item:setJobDelta(self:getJobDelta())
    self.item:setJobType(getText("IGUI_RR_DieselPourOption"))
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function RR_PourDieselAction:start()
    self.item:setJobDelta(0.0)
    pcall(function() self:setActionAnim("TakeGasFromVehicle") end)
    pcall(function() self:setOverrideHandModels(nil, self.item:getStaticModel()) end)
    -- Vanilla "pour a can into the tank" sound, via the world emitter (character:playSound
    -- is silent on the player in this B42 build -- see RR_Sound.actionLoopStart).
    if RR.Sound then
        self.sound = RR.Sound.actionLoopStart(self.character:getX(), self.character:getY(),
                     self.character:getZ(), "VehicleAddFuelFromCanister")
    end
end

function RR_PourDieselAction:stop()
    if self.sound and RR.Sound then RR.Sound.actionLoopStop(self.sound); self.sound = nil end
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function RR_PourDieselAction:perform()
    if self.sound and RR.Sound then RR.Sound.actionLoopStop(self.sound); self.sound = nil end
    self.item:setJobDelta(0.0)
    if RR.MPClient and self.rec.id then
        sendClientCommand(self.character, "RailroaderMP", "fuel", {
            id = self.rec.id, op = "pour", itemId = self.item:getID(),
        })
        ISBaseTimedAction.perform(self)
        return
    end
    local res = Diesel.pour(self.rec.engine.fuel, fuelCap(), dieselLitres(self.fc))
    if res.addedUnits > 0 then
        self.fc:removeFluid(res.drawnLitres)
        self.rec.engine.fuel = res.newFuel
        pcall(function() self.item:syncItemFields() end)
    end
    ISBaseTimedAction.perform(self)
end

--========================================================================
-- RR_SiphonDieselAction  -- loco -> can (needs a hose)
--========================================================================
RR_SiphonDieselAction = ISBaseTimedAction:derive("RR_SiphonDieselAction")

function RR_SiphonDieselAction:new(character, item, rec)
    local o = ISBaseTimedAction.new(self, character)
    o.item        = item                                   -- the (empty/part) can
    o.rec         = rec                                    -- loco record
    o.fc          = item and item:getFluidContainer() or nil
    o.stopOnWalk  = true
    o.stopOnRun   = true
    o.caloriesModifier = 2.0
    local fuel  = (rec and rec.engine and rec.engine.fuel) or 0
    local cap   = o.fc and o.fc:getCapacity() or 0
    local cur   = o.fc and o.fc:getAmount() or 0
    local plan  = Diesel.siphon(fuel, cur, cap)
    o.maxTime   = math.max(1, plan.addedLitres * MS_PER_LITRE)
    return o
end

function RR_SiphonDieselAction:isValid()
    if not (self.item and self.rec and self.rec.engine and self.fc) then return false end
    if not self.rec.animal or self.rec.animal:isDead() then return false end
    -- an empty container or one already holding diesel; never a petrol can
    if not Diesel.acceptsFluid(fluidName(self.fc)) then return false end
    return Diesel.canSiphon(self.rec.engine.fuel, self.fc:getAmount(), self.fc:getCapacity())
end

function RR_SiphonDieselAction:waitToStart()
    self.character:faceThisObject(self.rec.animal)
    return self.character:shouldBeTurning()
end

function RR_SiphonDieselAction:update()
    self.character:faceThisObject(self.rec.animal)
    self.item:setJobDelta(self:getJobDelta())
    self.item:setJobType(getText("IGUI_RR_DieselSiphonOption"))
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function RR_SiphonDieselAction:start()
    self.item:setJobDelta(0.0)
    pcall(function() self:setActionAnim("TakeGasFromVehicle") end)
    pcall(function() self:setOverrideHandModels(nil, self.item:getStaticModel()) end)
    -- Vanilla siphon sound, world-emitter path (see RR_PourDieselAction:start).
    if RR.Sound then
        self.sound = RR.Sound.actionLoopStart(self.character:getX(), self.character:getY(),
                     self.character:getZ(), "CanisterAddFuelSiphon")
    end
end

function RR_SiphonDieselAction:stop()
    if self.sound and RR.Sound then RR.Sound.actionLoopStop(self.sound); self.sound = nil end
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function RR_SiphonDieselAction:perform()
    if self.sound and RR.Sound then RR.Sound.actionLoopStop(self.sound); self.sound = nil end
    self.item:setJobDelta(0.0)
    if RR.MPClient and self.rec.id then
        sendClientCommand(self.character, "RailroaderMP", "fuel", {
            id = self.rec.id, op = "siphon", itemId = self.item:getID(),
        })
        ISBaseTimedAction.perform(self)
        return
    end
    local res = Diesel.siphon(self.rec.engine.fuel, self.fc:getAmount(), self.fc:getCapacity())
    if res.addedLitres > 0 and Diesel.acceptsFluid(fluidName(self.fc)) then
        -- what comes out of a diesel loco is DIESEL, into any container -- an empty
        -- one included. (isValid already refused a container of anything else.)
        self.fc:addFluid(dieselFluid(), res.addedLitres)
        self.rec.engine.fuel = res.newFuel
        pcall(function() self.item:syncItemFields() end)
    end
    ISBaseTimedAction.perform(self)
end

print("[Railroader] RR_FuelActions.lua: loaded OK")
