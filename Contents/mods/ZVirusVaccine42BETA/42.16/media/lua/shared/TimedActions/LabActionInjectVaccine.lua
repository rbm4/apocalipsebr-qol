-- VaccineAction_Client.lua
-- TimedAction para animacao

require "TimedActions/ISBaseTimedAction"

LabActionInjectVaccine = ISBaseTimedAction:derive("LabActionInjectVaccine")

function LabActionInjectVaccine:isValid()
    return self.character and self.item and self.character:getInventory():contains(self.item)
end

function LabActionInjectVaccine:update()
    self.item:setJobDelta(self:getJobDelta())
end

function LabActionInjectVaccine:start()
    self.item:setJobType(getText("ContextMenu_Inject"))
    self.item:setJobDelta(0.0)
    self:setOverrideHandModels(nil, self.item)
    self:setActionAnim("ApplyAlcohol")
    self.character:SetVariable("LootPosition", "Mid")
end

function LabActionInjectVaccine:stop()
    self.character:playSound("Injection_A")
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function LabActionInjectVaccine:perform()
    local itemType = self.item:getType()
    
    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "InjectVaccine",
        {
            itemType = itemType,
            playerOnline = self.character:getOnlineID()
        }
    )
    
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function LabActionInjectVaccine:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 120
end

function LabActionInjectVaccine:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = o:getDuration()
    return o
end