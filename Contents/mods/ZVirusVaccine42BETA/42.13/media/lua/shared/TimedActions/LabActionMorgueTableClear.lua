-- LabActionMorgueTableClear_Client.lua
-- TimedAction para limpar mesa

require "TimedActions/ISBaseTimedAction"

LabActionMorgueTableClear = ISBaseTimedAction:derive("LabActionMorgueTableClear")

-- Predicado: bleach suficiente (≥ 0.2L)
local function predicateBleachEnough(item)
    if not item then return false end
    if not item:hasComponent(ComponentType.FluidContainer) then return false end
    
    local fc = item:getFluidContainer()
    if not fc then return false end
    
    return fc:contains(Fluid.Bleach) and (fc:getAmount() >= 0.2)
end

function LabActionMorgueTableClear:isValid()
    local inv = self.character:getInventory()
    
    -- Bleach suficiente
    local bleach = inv:getFirstEvalRecurse(predicateBleachEnough)
    if not bleach then return false end
    
    -- Pano ou toalha
    if not (inv:containsTypeRecurse("DishCloth") or inv:containsTypeRecurse("BathTowel")) then
        return false
    end
    
    return true
end

function LabActionMorgueTableClear:waitToStart()
    self.character:faceThisObject(self.bottom)
    return self.character:shouldBeTurning()
end

function LabActionMorgueTableClear:update()
    self.character:faceThisObject(self.bottom)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function LabActionMorgueTableClear:start()
    local inv = self.character:getInventory()
    self.bleach = inv:getFirstEvalRecurse(predicateBleachEnough)
    
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.sound = self.character:playSound("CleanBloodBleach")
    
    -- Bleach aparece na mão secundária (visual)
    if self.bleach then
        self:setOverrideHandModels(nil, self.bleach)
    end
end

function LabActionMorgueTableClear:stop()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self)
end

function LabActionMorgueTableClear:perform()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.perform(self)
end

function LabActionMorgueTableClear:complete()
    local inv = self.character:getInventory()
    local bleach = inv:getFirstEvalRecurse(predicateBleachEnough)
    
    if bleach then
        local fc = bleach:getFluidContainer()
        if fc and fc:getAmount() >= 0.2 then
            fc:removeFluid(0.2, false)
            syncItemFields(self.character, bleach)
        end
    end
    
    -- Envia comando ao servidor para lógica adicional (limpar mesa, etc)
    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "ClearTable",
        {
            topX = self.top:getSquare():getX(),
            topY = self.top:getSquare():getY(),
            topZ = self.top:getSquare():getZ()
        }
    )
    
    return true
end

function LabActionMorgueTableClear:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 150
end

function LabActionMorgueTableClear:new(character, top, bottom)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    
    o.character = character
    o.top = top
    o.bottom = bottom
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    
    return o
end