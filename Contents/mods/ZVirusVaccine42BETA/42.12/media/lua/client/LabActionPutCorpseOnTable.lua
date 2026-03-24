require "TimedActions/ISBaseTimedAction"

LabActionPutCorpseOnTable = ISBaseTimedAction:derive("LabActionPutCorpseOnTable")

function LabActionPutCorpseOnTable:isValid()
    return true
end

function LabActionPutCorpseOnTable:waitToStart()
    self.character:faceThisObject(self.bottom)
    return self.character:shouldBeTurning()
end

function LabActionPutCorpseOnTable:update()
    self.character:faceThisObject(self.bottom)
end

function LabActionPutCorpseOnTable:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:playSound("PutItemInBag")
end

function LabActionPutCorpseOnTable:stop()
    ISBaseTimedAction.stop(self)
end

function LabActionPutCorpseOnTable:perform()
    local corpse = self.corpse
    local md = self.top:getModData()

    -- (1) TRANSFERE DADOS DO CADÁVER REAL PARA A MESA
    md.Zombie    = corpse:isZombie()
    md.Skeleton  = corpse:isSkeleton()
    md.Autopsy   = corpse:getModData().Autopsy or false
    md.DeathTime = LabRecipes_GetObjValue(corpse, "deathTime")

    -- (2) REMOVE O CADÁVER DO MUNDO
    corpse:removeFromWorld()
    corpse:removeFromSquare()

    -- (3) TROCA O SPRITE PARA “CORPSE”
    Lab_MorgueTableSwap(self.top, self.bottom, "Corpse")

    -- (4) FINALIZA A AÇÃO + FALA DO PERSONAGEM
    local key = "IGUI_PlayerText_MorguePlace" .. tostring(ZombRand(1,5))
    self.character:Say(getText(key))
    ISBaseTimedAction.perform(self)
end

function LabActionPutCorpseOnTable:new(character, top, bottom, corpse)
    local o = ISBaseTimedAction.new(self, character)

    o.top = top
    o.bottom = bottom
    o.corpse = corpse
    o.maxTime = 130
    o.stopOnWalk = true
    o.stopOnRun = true

    return o
end
