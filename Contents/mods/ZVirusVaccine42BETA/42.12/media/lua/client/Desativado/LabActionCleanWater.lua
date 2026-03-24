--[[require "TimedActions/ISBaseTimedAction"

LabActionCleanWater = ISBaseTimedAction:derive("LabActionCleanWater")


------------------------------------------------------------
-- Verifica se a água é tainted usando sistema B42
------------------------------------------------------------
local function IsTaintedWater_B42(item)
    if not item or not item.getFluidContainer then return false end

    local fc = item:getFluidContainer()
    if not fc then return false end

    local fluids = fc:getContents()
    if not fluids or fluids:size() ~= 1 then return false end  -- deve ter só 1 fluido

    local entry = fluids:get(0)
    if not entry then return false end

    local fluid = entry:getFluid()
    if not fluid then return false end

    return fluid:getFullName() == "Base.TaintedWater"
end


------------------------------------------------------------
-- Purificação de água usando sistema B42
------------------------------------------------------------
local function PurifyFluidContainer_B42(item)
    if not item or not item.getFluidContainer then return end

    local fc = item:getFluidContainer()
    if not fc then return end

    local fluids = fc:getContents()
    if not fluids or fluids:size() ~= 1 then return end  -- não purifica mistura

    local entry = fluids:get(0)
    if not entry then return end

    local fluid = entry:getFluid()
    if not fluid then return end

    if fluid:getFullName() ~= "Base.TaintedWater" then
        return  -- não purifica outros fluidos
    end

    local amt = entry:getAmount()

    -- limpar conteúdo e adicionar água limpa
    fc:clearContents()
    fc:addFluid(Fluid.new("Base.Water"), amt)
end


------------------------------------------------------------
-- Versão antiga (B41 - fallback)
------------------------------------------------------------
local function PurifyLegacyWater(item)
    if not item.setTaintedWater then return end
    item:setTaintedWater(false)
end


------------------------------------------------------------
-- Conta comprimidos de cloro no inventário
------------------------------------------------------------
function LabRecipes_CountDrainablePieces(inv, typeName)
    if not inv then return 0 end

    local count = 0
    local items = inv:getItems()

    for i = 0, items:size()-1 do
        local it = items:get(i)
        if it then
            if it:getType() == typeName then
                local uses = math.floor(it:getUsedDelta() / it:getUseDelta() + 0.5)
                count = count + uses
            elseif it:getCategory() == "Container" then
                count = count + LabRecipes_CountDrainablePieces(it:getItemContainer(), typeName)
            end
        end
    end

    return count
end


------------------------------------------------------------
-- Validação
------------------------------------------------------------
function LabActionCleanWater:isValid()
    if not self.waterSource then return false end

    local inv = self.character:getInventory()
    if not inv then return false end

    local tablets = LabRecipes_CountDrainablePieces(inv, "CmpChlorineTablets")
    if tablets < self.tablets then return false end

    -- sistema novo
    if IsTaintedWater_B42(self.waterSource) then return true end

    -- fallback antigo
    if self.waterSource.isTaintedWater and self.waterSource:isTaintedWater() then
        return true
    end

    return false
end


------------------------------------------------------------
-- Update
------------------------------------------------------------
function LabActionCleanWater:update()
    if self.waterSource.setJobDelta then
        self.waterSource:setJobDelta(self:getJobDelta())
    end
end


------------------------------------------------------------
-- Start
------------------------------------------------------------
function LabActionCleanWater:start()
    if self.waterSource.setJobType then
        self.waterSource:setJobType(getText("ContextMenu_LabClearWater"))
    end
    if self.waterSource.setJobDelta then
        self.waterSource:setJobDelta(0.0)
    end

    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(nil, "PillBottle")
    self.character:playSound("Mixing_B")
end


------------------------------------------------------------
-- Stop
------------------------------------------------------------
function LabActionCleanWater:stop()
    ISBaseTimedAction.stop(self)
    if self.waterSource.setJobDelta then
        self.waterSource:setJobDelta(0.0)
    end
end


------------------------------------------------------------
-- Consome comprimidos de cloro
------------------------------------------------------------
function LabActionCleanWater:useTablets(container)
    local items = container:getItems()
    if not items then return end

    for i = 0, items:size()-1 do
        if self.tablets <= 0 then return end

        local it = items:get(i)
        if it then
            if it:getCategory() == "Container" then
                self:useTablets(it:getItemContainer())

            elseif it:getType() == "CmpChlorineTablets" then
                while self.tablets > 0 and math.floor(it:getUsedDelta() / it:getUseDelta() + 0.5) > 0 do
                    self.tablets = self.tablets - 1
                    it:Use()
                end
            end
        end
    end
end


------------------------------------------------------------
-- Perform
------------------------------------------------------------
function LabActionCleanWater:perform()
    -- gráfico do container
    if self.waterSource.getContainer then
        local c = self.waterSource:getContainer()
        if c and c.setDrawDirty then
            c:setDrawDirty(true)
        end
    end

    if self.waterSource.setJobDelta then
        self.waterSource:setJobDelta(0.0)
    end

    -- sistema B42
    if self.waterSource.getFluidContainer then
        PurifyFluidContainer_B42(self.waterSource)
    else
        -- fallback antigo
        PurifyLegacyWater(self.waterSource)
    end

    -- consome comprimidos
    self:useTablets(self.character:getInventory())

    ISBaseTimedAction.perform(self)
end


------------------------------------------------------------
-- NEW()
------------------------------------------------------------
function LabActionCleanWater:new(character, waterSource, tablets)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.waterSource = waterSource
    o.tablets = tablets

    o.maxTime = 200
    o.stopOnWalk = true
    o.stopOnRun = true

    return o
end]]