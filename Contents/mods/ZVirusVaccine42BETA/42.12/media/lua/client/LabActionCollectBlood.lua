require "TimedActions/ISBaseTimedAction"

LabActionCollectBlood = ISBaseTimedAction:derive("LabActionCollectBlood")

function LabActionCollectBlood:isValid()
    return self.character and self.item and self.character:getInventory():contains(self.item)
end

function LabActionCollectBlood:start()
    self.item:setJobType(getText("ContextMenu_CollectBlood"))
    self.item:setJobDelta(0.0)

    self:setOverrideHandModels(nil, self.item)
    self:setActionAnim("ApplyAlcohol")
    self.character:SetVariable("LootPosition", "Mid")
	--self.character:playSound("Appliance_A")
end

function LabActionCollectBlood:update()
    self.item:setJobDelta(self:getJobDelta())
end

function LabActionCollectBlood:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function LabActionCollectBlood:perform()
    self.item:setJobDelta(0.0)
    
	local phrases = {
		"IGUI_PlayerText_PainFromNeedle1",
		"IGUI_PlayerText_PainFromNeedle2",
		"IGUI_PlayerText_PainFromNeedle3",
		"IGUI_PlayerText_PainFromNeedle4",
		"IGUI_PlayerText_PainFromNeedle5",
	}

	local pick = phrases[ZombRand(#phrases) + 1]
	self.character:Say(getText(pick))
	
    local player = self.character
    local body = player:getBodyDamage()
    local inv  = player:getInventory()

    -- Cria a seringa com sangue
    local newItem = nil

    if self.item:getType() == "LabSyringeReusable" then
        newItem = inv:AddItem("LabItems.CmpSyringeReusableWithBlood")
    else
        newItem = inv:AddItem("LabItems.CmpSyringeWithBlood")
    end
    -- Copia os dados de infecção
    if newItem then
        local md = newItem:getModData()

        md.IsInfected = body:isInfected()
        md.InfectionRate = body:isInfected() and LabRecipes_InfectionRate(player) or 0
    end

    -- Consome a seringa original
    self.item:Use()

    -- dano leve por coleta
    body:ReduceGeneralHealth(5)

    ISBaseTimedAction.perform(self)
	
	-- Remove 1 Algodão com Álcool
	local cotton = inv:FindAndReturn("AlcoholedCottonBalls")
	if cotton then
		inv:Remove(cotton)
	else
		print("[Lab] ERRO: Algodão com álcool não encontrado para remoção!")
	end
end

function LabActionCollectBlood:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.item = item
    o.maxTime = 90
    o.stopOnWalk = true
    o.stopOnRun = true

    return o
end
