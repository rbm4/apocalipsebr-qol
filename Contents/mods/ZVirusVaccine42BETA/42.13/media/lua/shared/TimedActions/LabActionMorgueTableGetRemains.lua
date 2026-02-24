-- LabActionMorgueTableGetRemains.lua
-- TimedAction para pegar restos da mesa

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
    self:setActionAnim("SawSmallItemMetal")
    self.character:SetVariable("LootPosition", "Mid")
    self.sound = self.character:getEmitter():playSound("Sawing")
end

function LabActionMorgueTableGetRemains:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:playSound("PutItemInBag")
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    
    ISBaseTimedAction.stop(self)
end

function LabActionMorgueTableGetRemains:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end

    ISBaseTimedAction.perform(self)
end

-- envia comando ao servidor
function LabActionMorgueTableGetRemains:complete()
    local inv = self.character:getInventory()
    local hasSack = inv:containsTypeRecurse("Garbagebag")
                    or inv:containsTypeRecurse("Bag_TrashBag")
    
    local plasticList = inv:getItemsFromType("Plasticbag")
                        or inv:getItemsFromType("Plasticbag_Bags")
                        or inv:getItemsFromType("Plasticbag_Clothing")
    local hasTwoPlastics = plasticList and plasticList:size() >= 2
    
    -- Envia comando ao servidor
    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "GetRemains",
        {
            hasSack = hasSack,
            hasTwoPlastics = hasTwoPlastics,
            topX = self.top:getSquare():getX(),
            topY = self.top:getSquare():getY(),
            topZ = self.top:getSquare():getZ()
        }
    )
    
    return true
end

function LabActionMorgueTableGetRemains:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 160
end

function LabActionMorgueTableGetRemains:new(character, top, bottom)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    
    o.character = character
    o.top = top
    o.bottom = bottom
    
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    
    return o
end