-- LabActionTakeShatteredGlass.lua
-- DUAS classes: ISRemoveBrokenGlass e ISPickupBrokenGlass
-- Ambas são idênticas às originais, mas adicionam o item do mod ao inventário

require "TimedActions/ISBaseTimedAction"

---------------------------------------------------------
-- ISRemoveBrokenGlass (remover vidro de janela)
---------------------------------------------------------

ISRemoveBrokenGlass = ISBaseTimedAction:derive("ISRemoveBrokenGlass")

function ISRemoveBrokenGlass:isValid()
	return self.window:getObjectIndex() ~= -1 and self.window:isSmashed() and not self.window:isGlassRemoved()
end

function ISRemoveBrokenGlass:waitToStart()
	self.character:faceThisObject(self.window)
	return self.character:shouldBeTurning()
end

function ISRemoveBrokenGlass:update()
	self.character:faceThisObject(self.window)

    self.character:setMetabolicTarget(Metabolics.LightWork);
end

function ISRemoveBrokenGlass:start()
    self.window:getSquare():playSound("RemoveBrokenGlass");
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 6, 1)
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Mid")
	self:setOverrideHandModels(nil, nil)
	self.character:reportEvent("EventLootItem");
end

function ISRemoveBrokenGlass:stop()
	ISBaseTimedAction.stop(self)
end

function ISRemoveBrokenGlass:perform()

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function ISRemoveBrokenGlass:complete()
    -- Remover vidro da janela
    if self.window.removeBrokenGlass then
        self.window:removeBrokenGlass()
    else
        self.window:setShattered(false)
    end
    
   	if isServer() then
		self.window:sync()
	end
    
    -- Adicionar item ao inventário
    local inv = self.character:getInventory()
    local item = inv:AddItem("LabItems.MatShatteredGlass")
    
    if item then
        sendAddItemToContainer(inv, item)
    end
    
    self.character:playSound("Shatter_B")
    
    return true
end

function ISRemoveBrokenGlass:getDuration()
	if self.character:isTimedActionInstant() then
		return 1;
	end
	return 100
end

function ISRemoveBrokenGlass:new(character, window)
	local o = ISBaseTimedAction.new(self, character);
	o.window = window
	o.maxTime = o:getDuration()
    o.caloriesModifier = 8;
    return o
end

---------------------------------------------------------
-- ISPickupBrokenGlass (pegar vidro do chão)
---------------------------------------------------------

ISPickupBrokenGlass = ISBaseTimedAction:derive("ISPickupBrokenGlass")

function ISPickupBrokenGlass:isValid()
	return true
end

function ISPickupBrokenGlass:waitToStart()
	self.character:faceThisObject(self.glass)
	return self.character:shouldBeTurning()
end

function ISPickupBrokenGlass:update()
	self.character:faceThisObject(self.glass)
end

function ISPickupBrokenGlass:start()
    self.glass:getSquare():playSound("RemoveBrokenGlass");
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 20, 1)
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Low")
	self:setOverrideHandModels(nil, nil)
	self.character:reportEvent("EventLootItem");
end

function ISPickupBrokenGlass:stop()
	ISBaseTimedAction.stop(self)
end

function ISPickupBrokenGlass:perform()
	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function ISPickupBrokenGlass:complete()
    if self.glass and self.square then
        self.square:transmitRemoveItemFromSquare(self.glass)
        self.glass:removeFromWorld()
        self.glass:removeFromSquare()
    end

    local inv = self.character:getInventory()
    local item = inv:AddItem("LabItems.MatShatteredGlass")

    if item then
        sendAddItemToContainer(inv, item)
    end

    return true
end

function ISPickupBrokenGlass:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 100
end

function ISPickupBrokenGlass:new(character, glass)
    local o = ISBaseTimedAction.new(self, character);
	o.glass = glass
    o.square = glass:getSquare()
    o.caloriesModifier = 8;
    o.maxTime = o:getDuration();
    return o
end