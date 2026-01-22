require "TimedActions/ISBaseTimedAction"

TCISConvertAppliance = ISBaseTimedAction:derive("TCISConvertAppliance");

function TCISConvertAppliance:isValid()
    return true;
end

function TCISConvertAppliance:update()
    self.item:setJobDelta(self:getJobDelta());
    self.character:setMetabolicTarget(Metabolics.UsingTools);
end

function TCISConvertAppliance:start()
	self.item:setJobDelta(0.0);
    self:setActionAnim(CharacterActionAnims.Craft);
end

function TCISConvertAppliance:stop()
    self.item:setJobDelta(0.0);
    ISBaseTimedAction.stop(self);
end

function TCISConvertAppliance:complete()
    local newItem = self.container:AddItem(self.newItemName)
    if newItem then
        self.container:Remove(self.item);
        sendAddItemToContainer(self.container, newItem);
        sendRemoveItemFromContainer(self.container,self.item);
        return true
    else
        print ('tsarLib ERROR failed adding item from convert appliance '..tostring(self.newItemName))
    end
    return false
end

function TCISConvertAppliance:perform()
    ISBaseTimedAction.perform(self);
end

function TCISConvertAppliance:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 500
end

function TCISConvertAppliance:new(character, item, newItemName)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character;
    o.item = item;
    o.newItemName = newItemName;
    o.container = item:getContainer();
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = false;
    o.maxTime = o:getDuration();
    o.forceProgressBar = true;
    return o;
end
