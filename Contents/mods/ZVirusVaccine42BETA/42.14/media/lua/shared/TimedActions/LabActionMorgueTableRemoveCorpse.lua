-- LabActionMorgueTableRemoveCorpse.lua
-- TimedAction para remover cadáver da mesa

require "TimedActions/ISBaseTimedAction"

LabActionMorgueTableRemoveCorpse = ISBaseTimedAction:derive("LabActionMorgueTableRemoveCorpse")

function LabActionMorgueTableRemoveCorpse:isValid()
    return true
end

function LabActionMorgueTableRemoveCorpse:waitToStart()
    self.character:faceThisObject(self.bottom)
    return self.character:shouldBeTurning()
end

function LabActionMorgueTableRemoveCorpse:update()
    self.character:faceThisObject(self.bottom)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function LabActionMorgueTableRemoveCorpse:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:playSound("PutItemInBag")
end

function LabActionMorgueTableRemoveCorpse:stop()
    ISBaseTimedAction.stop(self)
end

function LabActionMorgueTableRemoveCorpse:perform()
    ISBaseTimedAction.perform(self)
end

function LabActionMorgueTableRemoveCorpse:complete()
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
        "RemoveCorpseFromTable",
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

function LabActionMorgueTableRemoveCorpse:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 160
end

function LabActionMorgueTableRemoveCorpse:new(character, top, bottom)
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