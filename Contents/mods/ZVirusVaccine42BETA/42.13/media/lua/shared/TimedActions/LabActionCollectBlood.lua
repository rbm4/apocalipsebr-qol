-- LabActionCollectBlood_Client.lua
-- TimedAction para coleta de sangue

require "TimedActions/ISBaseTimedAction"

LabActionCollectBlood = ISBaseTimedAction:derive("LabActionCollectBlood")

function LabActionCollectBlood:isValid()
    if not self.character or not self.item then return false end
    
    local inv = self.character:getInventory()
    if not inv or not inv:contains(self.item) then return false end
    
    if not inv:contains("AlcoholedCottonBalls") then return false end
    
    return true
end

function LabActionCollectBlood:start()
    self.item:setJobType(getText("ContextMenu_LabCollectBloodBlood"))
    self.item:setJobDelta(0.0)
    self:setOverrideHandModels(nil, self.item)
    self:setActionAnim("ApplyAlcohol")
    self.character:SetVariable("LootPosition", "Mid")
	self.character:reportEvent("EventLootItem")
end

function LabActionCollectBlood:serverStart()
    if isServer() then
        if not self.item then
            self.netAction:forceComplete()
            return
        end

        emulateAnimEvent(self.netAction, 700, "bloodCollected", nil)
    end
end

function LabActionCollectBlood:update()
    self.item:setJobDelta(self:getJobDelta())
end

function LabActionCollectBlood:stop()
    self.character:playSound("Injection_A")
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function LabActionCollectBlood:perform()
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function LabActionCollectBlood:complete()
    local player = self.character
    if not player then return true end

    sendClientCommand(
        player,
        "ZVirusVaccine42BETA",
        "CollectBlood",
        {
            itemType = self.item:getType(),
            playerOnline = player:getOnlineID()
        }
    )

    return true
end

function LabActionCollectBlood:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 90
end

function LabActionCollectBlood:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()

    return o
end