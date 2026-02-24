-- LabActionPutCorpseOnTable_Client.lua
-- TimedAction para colocar cadáver na mesa

require "TimedActions/ISBaseTimedAction"

LabActionPutCorpseOnTable = ISBaseTimedAction:derive("LabActionPutCorpseOnTable")

function LabActionPutCorpseOnTable:isValid()
    return self.corpse ~= nil and self.top ~= nil and self.bottom ~= nil
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
    ISBaseTimedAction.perform(self)
end

function LabActionPutCorpseOnTable:complete()
    -- Captura dados do cadáver
    local corpseId = 0
    if self.corpse.getOnlineID then
        corpseId = self.corpse:getOnlineID()
    end
    
    -- Helper para extrair ModData
    local cmd = {}
    if self.corpse.getModData then
        local ok, md = pcall(function() return self.corpse:getModData() end)
        if ok and md then cmd = md end
    end
    
    -- Captura flags
    local isZombie = false
    if self.corpse.isZombie then
        local ok, res = pcall(function() return self.corpse:isZombie() end)
        if ok then isZombie = res end
    end
    
    local isSkeleton = false
    if self.corpse.isSkeleton then
        local ok, res = pcall(function() return self.corpse:isSkeleton() end)
        if ok then isSkeleton = res end
    end
    
    -- Death time
    local deathTime = nil
    if self.corpse.getDeathTime then
        local ok, t = pcall(function() return self.corpse:getDeathTime() end)
        if ok and t then deathTime = t end
    end
    if not deathTime then
        deathTime = cmd.deathTime or cmd.DeathTime or cmd.death_time
    end
    
    -- Envia comando ao servidor
    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "PutCorpseOnTable",
        {
            corpseId = corpseId,
            isZombie = isZombie,
            isSkeleton = isSkeleton,
            deathTime = deathTime,
            wasAutopsied = cmd.Autopsy or false,
            topX = self.top:getSquare():getX(),
            topY = self.top:getSquare():getY(),
            topZ = self.top:getSquare():getZ(),
            corpseX = self.corpse:getSquare():getX(),
            corpseY = self.corpse:getSquare():getY(),
            corpseZ = self.corpse:getSquare():getZ()
        }
    )
    
    return true
end

function LabActionPutCorpseOnTable:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 130
end

function LabActionPutCorpseOnTable:new(character, top, bottom, corpse)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    
    o.character = character
    o.top = top
    o.bottom = bottom
    o.corpse = corpse
    
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    
    return o
end