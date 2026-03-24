require "TimedActions/ISBaseTimedAction"

LabActionMorgueTableGetRemains = ISBaseTimedAction:derive("LabActionMorgueTableGetRemains")

function LabActionMorgueTableGetRemains:isValid()
    return true
end

function LabActionMorgueTableGetRemains:waitToStart()
    self.character:faceThisObject(self.bottom)
    return self.character:shouldBeTurning()
end

function LabActionMorgueTableGetRemains:update()
    self.character:faceThisObject(self.bottom)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function LabActionMorgueTableGetRemains:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:playSound("PutItemInBag")

    -- mãos livres
    self.character:setPrimaryHandItem(nil)
    self.character:setSecondaryHandItem(nil)
end

function LabActionMorgueTableGetRemains:stop()
    ISBaseTimedAction.stop(self)
end

function LabActionMorgueTableGetRemains:perform()
    local inv = self.character:getInventory()
    local said = false

    -- 1) VERIFICA QUAL RECIPIENTE O JOGADOR TEM
    -- Garbagebag (1x)
    local sack = inv:getFirstTypeRecurse("Garbagebag")

    -- Plasticbag (precisa de 2 unid.)
    local plasticList = inv:getItemsFromType("Plasticbag")
    local hasTwoPlastics = plasticList and plasticList:size() >= 2

    -- 2) REMOVER ITENS VAZIOS E ADICIONAR "WITH REMAINS"
    if sack then
        -- 1 saco de lixo
        inv:RemoveOneOf("Garbagebag")
        local newItem = inv:AddItem("LabItems.LabGarbageBagWithRemains")
        self.character:setPrimaryHandItem(newItem)

        -- fala
        local key = "IGUI_PlayerText_MorgueGetRemains" .. tostring(ZombRand(1,5))
        self.character:Say(getText(key))
        said = true

    elseif hasTwoPlastics then
        -- Remove duas sacolas
        inv:RemoveOneOf("Plasticbag")
        inv:RemoveOneOf("Plasticbag")

        -- Adiciona 2 sacolas com restos
        local newA = inv:AddItem("LabItems.LabPlasticBagWithRemains")
        local newB = inv:AddItem("LabItems.LabPlasticBagWithRemains")

        self.character:setPrimaryHandItem(newA)
        self.character:setSecondaryHandItem(newB)

        -- fala
        local key = "IGUI_PlayerText_MorgueGetRemains" .. tostring(ZombRand(1,5))
        self.character:Say(getText(key))
        said = true
    end

    if not said then
        self.character:Say(getText("IGUI_PlayerText_MorgueNoContainer"))
    end


    -- 3) MUDAR SPRITE DA MESA
    Lab_MorgueTableSwap(self.top, self.bottom, "Dirty")

    ISBaseTimedAction.perform(self)
end

function LabActionMorgueTableGetRemains:new(character, top, bottom)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.top = top
    o.bottom = bottom

    o.maxTime = 160
    o.stopOnWalk = true
    o.stopOnRun = true

    return o
end