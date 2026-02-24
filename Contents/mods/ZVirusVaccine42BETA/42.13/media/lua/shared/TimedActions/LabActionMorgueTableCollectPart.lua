-- LabActionMorgueTableCollectPart_Client.lua
-- TimedAction para coletar partes específicas do corpo

require "TimedActions/ISBaseTimedAction"

LabActionMorgueTableCollectPart = ISBaseTimedAction:derive("LabActionMorgueTableCollectPart")

function LabActionMorgueTableCollectPart:isValid()
    return self.top and self.bottom and self.itemType ~= nil
end

function LabActionMorgueTableCollectPart:waitToStart()
    self.character:faceThisObject(self.bottom)
    return self.character:shouldBeTurning()
end

function LabActionMorgueTableCollectPart:update()
    self.character:faceThisObject(self.bottom)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function LabActionMorgueTableCollectPart:start()
    self:setActionAnim("SawSmallItemMetal")
    self.character:SetVariable("LootPosition", "Mid")
    self.sound = self.character:getEmitter():playSound("Sawing")
end

function LabActionMorgueTableCollectPart:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:playSound("PutItemInBag")
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    
    ISBaseTimedAction.stop(self)
end

function LabActionMorgueTableCollectPart:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    
    ISBaseTimedAction.perform(self)
end

function LabActionMorgueTableCollectPart:complete()
    local inv = self.character:getInventory()
    local hasSack = inv:containsTypeRecurse("Garbagebag")
                    or inv:containsTypeRecurse("Bag_TrashBag")
    
    local plasticList = inv:getItemsFromType("Plasticbag")
                        or inv:getItemsFromType("Plasticbag_Bags")
                        or inv:getItemsFromType("Plasticbag_Clothing")
    local hasTwoPlastics = plasticList and plasticList:size() >= 2
    
    local hasScalpel = inv:containsTypeRecurse("Scalpel")
    local hasSaw = inv:containsTypeRecurse("Saw")
    
    if not hasScalpel or not hasSaw or not (hasSack or hasTwoPlastics) then
        return true
    end
    
    -- Envia comando ao servidor
    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "CollectBodyPart",
        {
            hasSack = hasSack,
            hasTwoPlastics = hasTwoPlastics,
            topX = self.top:getSquare():getX(),
            topY = self.top:getSquare():getY(),
            topZ = self.top:getSquare():getZ(),
            itemType = self.itemType
        }
    )
   
    return true
end

function LabActionMorgueTableCollectPart:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 220
end

function LabActionMorgueTableCollectPart:new(character, top, bottom, itemType)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    
    o.character = character
    o.top = top
    o.bottom = bottom
    o.itemType = itemType
    
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    
    return o
end