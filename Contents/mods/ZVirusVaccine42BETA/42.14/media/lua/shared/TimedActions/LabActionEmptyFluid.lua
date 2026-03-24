-- LabActionEmptyFluid.lua
-- Custom TA for emptying lab fluid containers, to add dirty variants of the items when emptied.
-- I considered just hooking into the vanilla empty action, but it felt cleaner to just make a new one that I have full control over.
-- If anything breaks with future updates, we just disable the menu override that allows this action to be used and players can still empty fluids, just without the dirty variants.

require "TimedActions/ISBaseTimedAction"

LabActionEmptyFluid = ISBaseTimedAction:derive("LabActionEmptyFluid")

local labDirtyItems = {
    ["LabItems.LabFlask"]    = "LabItems.LabFlaskDirty",
    ["LabItems.LabTestTube"] = "LabItems.LabTestTubeDirty",
}

local labCleanFluids = {
    ["Water"]         = true,
    ["PurifiedWater"] = true,
}

function LabActionEmptyFluid:isValid()
    return self.item ~= nil
end

function LabActionEmptyFluid:waitToStart()
    return self.character:shouldBeTurning()
end

function LabActionEmptyFluid:start()
    self:setActionAnim(CharacterActionAnims.Pour)
    self:setAnimVariable("PourType", self.item:getPourType())
    self.item:setJobType(getText("IGUI_JobType_PourOut"))
    self.item:setJobDelta(0.0)
    self.sound = self.character:playSound(self.item:getPourLiquidOnGroundSound())
    self:setOverrideHandModels(self.item, nil)
end

function LabActionEmptyFluid:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function LabActionEmptyFluid:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.perform(self)
end

function LabActionEmptyFluid:complete()
    local inv = self.item:getContainer()
    if not inv then return true end

    local dirtyVariant = labDirtyItems[self.item:getFullType()]
    local isClean = labCleanFluids[self.fluidType] or false

    if dirtyVariant and not isClean then
        inv:Remove(self.item)
        sendRemoveItemFromContainer(inv, self.item)

        local dirtyItem = inv:AddItem(dirtyVariant)
        if dirtyItem then
            sendAddItemToContainer(inv, dirtyItem)
        end
    else
        local fc = self.item:getFluidContainer()
        if fc then
            fc:Empty()
            if isServer() then
                self.item:syncItemFields()
            end
        end
    end

    return true
end

function LabActionEmptyFluid:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return ISFluidUtil.getMinTransferActionTime()
end

function LabActionEmptyFluid:new(character, item, fluidType)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.fluidType = fluidType or ""
    o.maxTime = o:getDuration()
    return o
end