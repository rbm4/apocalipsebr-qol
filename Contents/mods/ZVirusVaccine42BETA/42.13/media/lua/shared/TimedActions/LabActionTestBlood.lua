-- BloodTestAction_Client.lua
-- Timed Action para testar sangue no espectrometro

require "TimedActions/ISBaseTimedAction"

LabActionTestBlood = ISBaseTimedAction:derive("LabActionTestBlood")

local function IsNearSpectrometer()
    if LabRecipes_IsNearSpectrometer then
        return LabRecipes_IsNearSpectrometer(nil, nil)
    end
    return true
end

function LabActionTestBlood:isValid()
    if not self.character then return false end
    if not self.item then return false end
    
    return true
end

function LabActionTestBlood:serverStart()
    if not isServer() then
        return
    end
    
    if not self.character then
        self.netAction:forceComplete()
        return
    end
    
    if not self.item then
        self.netAction:forceComplete()
        return
    end
    
    local inv = self.character:getInventory()
    if not inv then
        self.netAction:forceComplete()
        return
    end
    
    local itemType = self.item:getType()
    local itemExists = inv:getItemFromType(itemType)
    
    if not itemExists then
        self.netAction:forceComplete()
        return
    end
end

function LabActionTestBlood:start()
    self.item:setJobType(getText("ContextMenu_TestBlood"))
    self.item:setJobDelta(0.0)
    self:setOverrideHandModels(nil, self.item)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.sound = self.character:getEmitter():playSound("Appliance_A")
end

function LabActionTestBlood:update()
    self.item:setJobDelta(self:getJobDelta())
end

function LabActionTestBlood:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end

    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function LabActionTestBlood:perform()
    self.item:setJobDelta(0.0)
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    
    ISBaseTimedAction.perform(self)
end

function LabActionTestBlood:complete()
    if not self.character then
        return true
    end
    
    if not self.item then
        return true
    end
    
    local itemType = self.item:getType()
    
    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "TestBlood",
        {
            itemType = itemType,
            playerOnline = self.character:getOnlineID()
        }
    )
    
    return true
end

function LabActionTestBlood:getDuration()
    if self.character:isTimedActionInstant() then 
        return 1 
    end
    
    return 220
end

function LabActionTestBlood:new(character, item)
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