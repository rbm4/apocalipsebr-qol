require "TimedActions/ISBaseTimedAction"

LabActionMorgueTableClear = ISBaseTimedAction:derive("LabActionMorgueTableClear")

-- Predicado para BLEACH suficiente (≥ 0.2 litros)
local function predicateBleachEnough(item)
    if not item then return false end
    if not item:hasComponent(ComponentType.FluidContainer) then return false end

    local fc = item:getFluidContainer()
    if not fc then return false end

    -- contém bleach e tem ao menos 0.2L
    return fc:contains(Fluid.Bleach) and (fc:getAmount() >= 0.2)
end

-- VALIDAÇÃO
function LabActionMorgueTableClear:isValid()
    local inv = self.character:getInventory()

    -- Bleach suficiente
    local bleach = inv:getFirstEvalRecurse(predicateBleachEnough)
    if not bleach then return false end

    -- pano ou toalha
    if not (inv:containsTypeRecurse("DishCloth") or inv:containsTypeRecurse("BathTowel")) then
        return false
    end

    return true
end

-- TURNO INICIAL
function LabActionMorgueTableClear:waitToStart()
    self.character:faceThisObject(self.bottom)
    return self.character:shouldBeTurning()
end

-- UPDATE
function LabActionMorgueTableClear:update()
    self.character:faceThisObject(self.bottom)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

-- START (animação + bleach na mão)
function LabActionMorgueTableClear:start()
    local inv = self.character:getInventory()

    -- capturar bleach com fluido
    self.bleach = inv:getFirstEvalRecurse(predicateBleachEnough)

    -- Animação
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:playSound("CleanBloodBleach")

    -- bleach aparece na mão secundária
    if self.bleach then
        self:setOverrideHandModels(nil, self.bleach)
    end
end

-- STOP
function LabActionMorgueTableClear:stop()
    ISBaseTimedAction.stop(self)
end

-- COMPLETE (consome o fluido + troca sprite)
function LabActionMorgueTableClear:complete()
    -- consumir 0.2 L de bleach
    if self.bleach and self.bleach:getFluidContainer() then
        local fc = self.bleach:getFluidContainer()
        fc:adjustAmount(fc:getAmount() - 0.2)
    end

    -- trocar Dirty → Empty
    Lab_MorgueTableSwap(self.top, self.bottom, "Empty")

    -- Falas
    local key = "IGUI_PlayerText_MorgueClean" .. tostring(ZombRand(1,5))
    self.character:Say(getText(key))

    return true
end

-- PERFORM
function LabActionMorgueTableClear:perform()
    ISBaseTimedAction.perform(self)
end

-- CONSTRUTOR
function LabActionMorgueTableClear:new(character, top, bottom)
    local o = ISBaseTimedAction.new(self, character)

    o.top = top
    o.bottom = bottom

    o.maxTime = 150
    o.stopOnWalk = true
    o.stopOnRun  = true

    return o
end