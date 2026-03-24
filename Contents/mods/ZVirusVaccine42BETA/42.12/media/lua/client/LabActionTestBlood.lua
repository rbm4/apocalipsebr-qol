require "TimedActions/ISBaseTimedAction"

LabActionTestBlood = ISBaseTimedAction:derive("LabActionTestBlood")

-- Helpers locais
local function IsNearSpectrometer()
    return LabRecipes_IsNearSpectrometer(nil, nil)
end

-- Validação
function LabActionTestBlood:isValid()
    return self.character
       and self.item
       and self.character:getInventory():contains(self.item)
end

function LabActionTestBlood:update()
    self.item:setJobDelta(self:getJobDelta())
end

-- Início da ação
function LabActionTestBlood:start()
    self.item:setJobType(getText("ContextMenu_TestBlood"))
    self.item:setJobDelta(0.0)

    self:setOverrideHandModels(nil, self.item)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:playSound("Appliance_A")
end

-- Cancelamento
function LabActionTestBlood:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

-- Execução final
function LabActionTestBlood:perform()
    self.item:setJobDelta(0.0)

    local player = self.character
    local inv = player:getInventory()

    -- 1) Verificar se está perto do Spectrometer
    if not IsNearSpectrometer() then
        player:Say(getText("IGUI_PlayerText_NeedSpectrometer"))
        ISBaseTimedAction.perform(self)
        return
    end

    -- 2) Ler os dados coletados no momento da coleta
    local md = self.item:getModData()
    if not md or md.IsInfected == nil then
        player:Say(getText("IGUI_PlayerText_InvalidSample"))
        ISBaseTimedAction.perform(self)
        return
    end

    local infected = md.IsInfected
    local rate = math.floor((md.InfectionRate or 0) * 100)
    local result = nil

    -- 3) Criar resultado
    if infected then
        result = inv:AddItem("LabItems.LabTestResultPositive")
        if result then
            local baseName = result:getDisplayName()
            result:setName(baseName .. " (" .. tostring(rate) .. "%)")
        end
    else
        inv:AddItem("LabItems.LabTestResultNegative")
    end

    -- 4) Converter seringa (descartável ou reutilizável)
    local t = self.item:getType()

    if t == "CmpSyringeReusableWithBlood" then
        inv:AddItem("LabItems.LabSyringeReusableUsed")
    else
        inv:AddItem("LabItems.LabSyringeUsed")
    end

    self.item:Use()

    -- Debug opcional
    if LabRecipes_PrintTestInfo then
        LabRecipes_PrintTestInfo(player, result)
    end

    ISBaseTimedAction.perform(self)
end

-- Construtor
function LabActionTestBlood:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.item = item
    o.maxTime = 600 -- 3 segundos
    o.stopOnWalk = true
    o.stopOnRun = true

    return o
end
