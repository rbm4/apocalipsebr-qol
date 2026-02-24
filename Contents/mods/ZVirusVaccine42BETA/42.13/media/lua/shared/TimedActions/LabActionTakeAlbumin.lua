-- LabActionTakeAlbumin_Client.lua

require "TimedActions/ISBaseTimedAction"

LabActionTakeAlbumin = ISBaseTimedAction:derive("LabActionTakeAlbumin")

function LabActionTakeAlbumin:isValid()
    return self.character:getInventory():contains(self.pills)
end

function LabActionTakeAlbumin:update()
    self.pills:setJobDelta(self:getJobDelta())
end

function LabActionTakeAlbumin:start()
    self.pills:setJobType(getText("ContextMenu_Take_pills"))
    self.pills:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.TakePills)
    self:setOverrideHandModels(nil, self.pills)
    self.character:playSound("Pills_A")
end

function LabActionTakeAlbumin:stop()
    ISBaseTimedAction.stop(self)
    self.pills:setJobDelta(0.0)
end

function LabActionTakeAlbumin:perform()
    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "TakeAlbumin",
        {
            pillsType = self.pills:getType()
        }
    )
    
    self.pills:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function LabActionTakeAlbumin:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 100
end

function LabActionTakeAlbumin:new(character, pills)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    
    o.character = character
    o.pills = pills
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = o:getDuration()
    
    return o
end