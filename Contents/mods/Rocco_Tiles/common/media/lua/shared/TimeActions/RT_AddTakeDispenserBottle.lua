require "TimedActions/ISBaseTimedAction"

RT_AddTakeDispenserBottle = ISBaseTimedAction:derive("RT_AddTakeDispenserBottle")

function RT_AddTakeDispenserBottle:isValid()
	return self.waterdispenser:hasComponent(ComponentType.FluidContainer) ~= bottle
end

function RT_AddTakeDispenserBottle:waitToStart()
    self.character:faceThisObject(self.waterdispenser)
    return self.character:shouldBeTurning()
end

function RT_AddTakeDispenserBottle:update()
    self.character:faceThisObject(self.waterdispenser)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function RT_AddTakeDispenserBottle:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end

function RT_AddTakeDispenserBottle:stop()
    ISBaseTimedAction.stop(self)
end

function RT_AddTakeDispenserBottle:perform()
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function RT_AddTakeDispenserBottle:complete()
	local rawSprite = self.waterdispenser:getSpriteName()
	if not self.bottle then
		-- ADD ITEM --
		local newBottle = self.character:getInventory():AddItem("Base.WaterDispenserBottle")
		newBottle:getFluidContainer():copyFluidsFrom(self.waterdispenser:getFluidContainer())
		sendAddItemToContainer(self.character:getInventory(), newBottle)
		-- REMOVE OBJECT --
		self.square:transmitRemoveItemFromSquare(self.waterdispenser)
		self.square:RemoveTileObject(self.waterdispenser)
		-- ADD OBJECT --
		local sprite = "Roccos_Tiles_Appliances_01_3"
		local objectStyle = "new"
		-- New
		if rawSprite == "Roccos_Tiles_Appliances_01_7" then
			sprite = "Roccos_Tiles_Appliances_01_3"
			objectStyle = "new"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_5" then
			sprite = "Roccos_Tiles_Appliances_01_1"
			objectStyle = "new"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_6" then
			sprite = "Roccos_Tiles_Appliances_01_2"
			objectStyle = "new"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_4" then
			sprite = "Roccos_Tiles_Appliances_01_0"
			objectStyle = "new"
		-- Old
		elseif rawSprite == "Roccos_Tiles_Appliances_01_15" then
			sprite = "Roccos_Tiles_Appliances_01_11"
			objectStyle = "old"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_13" then
			sprite = "Roccos_Tiles_Appliances_01_9"
			objectStyle = "old"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_14" then
			sprite = "Roccos_Tiles_Appliances_01_10"
			objectStyle = "old"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_12" then
			sprite = "Roccos_Tiles_Appliances_01_8"
			objectStyle = "old"
		end
		local entityName = objectStyle == "old" and "Old_WaterDispenserNoBottle" or "New_WaterDispenserNoBottle"
		local newdispenser = self.square:addWorkstationEntity(entityName, sprite)
		newdispenser:sync()
	else
		-- REMOVE OBJECT --
		self.square:transmitRemoveItemFromSquare(self.waterdispenser)
		self.square:RemoveTileObject(self.waterdispenser)
		-- ADD OBJECT --
		local sprite = "Roccos_Tiles_Appliances_01_7"
		local objectStyle = "new"
		-- New
		if rawSprite == "Roccos_Tiles_Appliances_01_3" then
			sprite = "Roccos_Tiles_Appliances_01_7"
			objectStyle = "new"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_1" then
			sprite = "Roccos_Tiles_Appliances_01_5"
			objectStyle = "new"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_2" then
			sprite = "Roccos_Tiles_Appliances_01_6"
			objectStyle = "new"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_0" then
			sprite = "Roccos_Tiles_Appliances_01_4"
			objectStyle = "new"
		-- Old
		elseif rawSprite == "Roccos_Tiles_Appliances_01_11" then
			sprite = "Roccos_Tiles_Appliances_01_15"
			objectStyle = "old"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_9" then
			sprite = "Roccos_Tiles_Appliances_01_13"
			objectStyle = "old"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_10" then
			sprite = "Roccos_Tiles_Appliances_01_14"
			objectStyle = "old"
		elseif rawSprite == "Roccos_Tiles_Appliances_01_8" then
			sprite = "Roccos_Tiles_Appliances_01_12"
			objectStyle = "old"
		end
		local entityName = objectStyle == "old" and "Old_WaterDispenser" or "New_WaterDispenser"
		local newdispenser = self.square:addWorkstationEntity(entityName, sprite)
		if newdispenser and newdispenser:hasComponent(ComponentType.FluidContainer) then
			newdispenser:getFluidContainer():setInputLocked(false)
			newdispenser:getFluidContainer():copyFluidsFrom(self.bottle:getFluidContainer())
			newdispenser:getFluidContainer():setInputLocked(true)
		end
		-- transmitCompleteItemToClients has already been sent in the addWorkstationEntity function
		newdispenser:sync()
		-- REMOVE ITEM --
		sendRemoveItemFromContainer(self.character:getInventory(), self.bottle)
		self.character:getInventory():Remove(self.bottle)
	end

    return true
end

function RT_AddTakeDispenserBottle:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 30
end

function RT_AddTakeDispenserBottle:new(character, waterdispenser, bottle)
    local o = ISBaseTimedAction.new(self, character)
    o.maxTime = o:getDuration()
	o.character = character
    o.waterdispenser = waterdispenser
	o.square = waterdispenser:getSquare()
    o.bottle = bottle
    return o
end
