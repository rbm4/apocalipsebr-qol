ISBuildTableSaw = ISBuildingObject:derive('ISBuildTableSaw')


local function setFurnitureData(ISItem)
	local ObjectList = Building_Data.BuildingList[ISItem.tabindex].subBuildData[ISItem.listindex].ItemDate[ISItem.sel]
	if not Building_Data.BuildingList[ISItem.tabindex] then 
		return false
	end 
	if not Building_Data.BuildingList[ISItem.tabindex].subBuildData[ISItem.listindex] then 
		return false
	end 
	if not Building_Data.BuildingList[ISItem.tabindex].subBuildData[ISItem.listindex].ItemDate[ISItem.sel] then 
		return false
	end 
	local MaterialList = ObjectList.NeedMaterials
	
	for i, _MaterialData in pairs (MaterialList) do
		local str = ''
		local materialType = _MaterialData.tMaterial
		if SandboxVars.BuildingCraftMaterialChange then 
			if materialType == 'Base.BucketConcreteFull' or materialType == 'Base.Sandbag' or materialType == 'Base.Dirtbag' or materialType == 'Base.Gravelbag' then 
				materialType = 'Base.Plank'
			end 
		end 
		if Building_Data.MaterialIsUse[materialType] then 
			str = 'use:'
		else 
			str = 'need:'
		end 
		str = str .. materialType
		--print('str:',str)
		ISItem.modData[str] = _MaterialData.Amount
	end 
	
	local SkillXpName = ObjectList.SkillXpName
	if SkillXpName ~= '' then 
		ISItem.modData[SkillXpName] = ObjectList.SkillXp
	end 
	return true
end 

local function consumeMaterial(ISItem)
	if not ISItem or not ISItem.player then return {}; end
	if not isServer() and ISBuildMenu.cheat then
		return SawBladeMaxDurable;
	end
	local playerObj = ISItem.player
	if not isServer() then
		--print('ISItem.player:',ISItem.player)
	    playerObj = getSpecificPlayer(ISItem.player)
	else 
		--print('setFurnitureData')
		setFurnitureData(ISItem)
	end
	
	local playerInv = playerObj:getInventory()
	local modData = ISItem.modData;
	local removedFromGround = false
	local Durable = SawBladeMaxDurable - ZombRandFloat(0.00,8.00)
	--local consumedItems = {}
	for index, value in pairs(modData) do
		if luautils.stringStarts(index, "need:") then
			local itemFullType = luautils.split(index, ":")[2];
			local itemType = luautils.split(itemFullType, "%.")[2]
			local itemCount = tonumber(value);
			local items = playerInv:getSomeTypeEvalRecurse(itemFullType, buildUtil.predicateMaterial, itemCount)
			for i=1,items:size() do
				local item = items:get(i-1)
				if item:getType() == 'Base.CircularSawblade' then 
					--print('itemtype:',item:getType())
					local data = item:getModData()
					if data.Durable then 
						Durable = data.Durable
					end 
				end 
				playerObj:removeFromHands(item)
				if item:getContainer() then
					sendRemoveItemFromContainer(item:getContainer(), item);
					item:getContainer():Remove(item);
				else
					sendRemoveItemFromContainer(playerInv, item);
					playerInv:Remove(item)
				end
				itemCount = itemCount - 1
				--table.insert(consumedItems, item)
			end
			-- if we didn't have all the required material inside our inventory, it's because the missing materials are on the ground, we gonna check them
			-- for each missing material in inventory
			if itemCount > 0 then
				-- check a 3x3 square around the building
				local groundItems = buildUtil.getMaterialOnGround(ISItem.sq)
				local items = groundItems[itemFullType]
				if items then
					local count = math.min(itemCount, #items)
					for i=1,count do
						local item = items[i]
						local worldObj = item:getWorldItem()
						if worldObj:getType() == 'Base.CircularSawblade' then 
							--print('worldObjtype:',worldObj:getType())
							local data = worldObj:getModData()
							if data.Durable then 
								Durable = data.Durable
							end 
						end 
						--table.insert(consumedItems, item)
						worldObj:getSquare():transmitRemoveItemFromSquare(worldObj)
					end
					itemCount = itemCount - count
					removedFromGround = true
				end
			end
			if itemCount > 0 and itemFullType == "Base.Nails" then
				buildUtil.openNailsBoxMy(ISItem)
				items = playerInv:getSomeTypeEvalRecurse(itemFullType, buildUtil.predicateMaterial, itemCount)
				for i=1,items:size() do
					local item = items:get(i-1)
					playerObj:removeFromHands(item)
					if item:getContainer() then
						sendRemoveItemFromContainer(item:getContainer(), item);
						item:getContainer():Remove(item);
					else
						sendRemoveItemFromContainer(playerInv, item);
						playerInv:Remove(item)
					end
					itemCount = itemCount - 1
					--table.insert(consumedItems, item)
				end
			elseif itemCount > 0 and itemFullType == "Base.Screws" then -- ScrewsBox
				buildUtil.openScrewsBoxMy(ISItem)
				items = playerInv:getSomeTypeEvalRecurse(itemFullType, buildUtil.predicateMaterial, itemCount)
				for i=1,items:size() do
					local item = items:get(i-1)
					playerObj:removeFromHands(item)
					if item:getContainer() then
						sendRemoveItemFromContainer(item:getContainer(), item);
						item:getContainer():Remove(item);
					else
						sendRemoveItemFromContainer(playerInv, item);
						playerInv:Remove(item)
					end
					itemCount = itemCount - 1
					--table.insert(consumedItems, item)
				end
			end
			if itemCount > 0 then
				print('ERROR: consumeMaterial() did not find all required materials!')
			end
		end
		if luautils.stringStarts(index, "use:") then
			local itemFullType = luautils.split(index, ":")[2];
			local itemType = luautils.split(itemFullType, "%.")[2]
			local uses = tonumber(value);
			local remaining = uses
			local items = playerInv:getAllTypeRecurse(itemFullType)
			for i=1,items:size() do
				local item = items:get(i-1)
				if item:getCurrentUses() > 0 then
					remaining = remaining - buildUtil.useDrainable(item, remaining)
					--table.insert(consumedItems, item)
					if remaining <= 0 then
						break
					end
				end
			end
			if remaining > 0 then
				local groundItems = buildUtil.getMaterialOnGround(ISItem.sq)
				local items = groundItems[itemFullType]
				if items then
					for _,item in ipairs(items) do
						if item:getCurrentUses() > 0 then
							remaining = remaining - buildUtil.useDrainable(item, remaining)
							--table.insert(consumedItems, item)
							removedFromGround = true
							if remaining <= 0 then
								break
							end
						end
					end
				end
			end
		end
		if luautils.stringStarts(index, "xp:") then
			local skill = luautils.split(index, ":")[2];
			local xp = tonumber(value);
			addXp(playerObj, Perks.FromString(skill), xp)
		end
	end
	if removedFromGround then
		if isServer() then
			sendServerCommand(playerObj, 'ui', 'dirtyUI', { });
		else
			ISInventoryPage.dirtyUI();
		end
	end
	return Durable
end

function ISBuildTableSaw:create(x, y, z, north, sprite)
	local cell = getWorld():getCell()
	self.sq = cell:getGridSquare(x, y, z)
	local SawBladeDurable = consumeMaterial(self)

	self.javaObject = IsoThumpable.new(cell, self.sq, sprite, north, self);
	buildUtil.setInfo(self.javaObject, self);
	self.javaObject:setMaxHealth(self:getHealth());
	
	self.javaObject:setHealth(self.javaObject:getMaxHealth());
	self.javaObject:setBreakSound(IsoThumpable.GetBreakFurnitureSound(sprite));
	
	local modData = self.javaObject:getModData();
	--modData.Durable = ZombRandFloat(95.00,100.00)
	modData.Durable = TableSawMaxDurable - ZombRandFloat(0.00,5.00)
	modData.SawBladeDurable = SawBladeDurable
	
	if SandboxVars.IsAllCustomizeSizeCapacity then
		self.capacity = SandboxVars.AllCustomizeSizeCapacity;
		self.javaObject:createContainersFromSpriteProperties();
		
		for i = 1, self.javaObject:getContainerCount() do
			local container = self.javaObject:getContainerByIndex(i - 1);
			container:setCapacity(self.capacity);
			container:setExplored(true);
		end 
	else 
		local objSprite = getSprite(sprite);
		if objSprite then
			local objProps = objSprite:getProperties();
			if objProps then
				local isset = false
				self.capacity = tonumber(objProps:get("ContainerCapacity"))
				if not self.capacity then 
					self.capacity = 50
				end 
			end 
		end 
		if not self.capacity or self.capacity == 0 then 
			self.capacity = 50
		end 
		self.javaObject:createContainersFromSpriteProperties();
		for i = 1, self.javaObject:getContainerCount() do
			local container = self.javaObject:getContainerByIndex(i - 1);
			container:setCapacity(self.capacity);
			container:setExplored(true);
		end 
	end 
	self.sq:AddSpecialObject(self.javaObject);
	
	self.javaObject:transmitCompleteItemToClients();
	
	self.sq:RecalcProperties();
	self.sq:RecalcAllWithNeighbours(true);
end

function ISBuildTableSaw:getHealth()
	return 100 + buildUtil.getWoodHealth(self);
end

function ISBuildTableSaw:isValid(square)
	if not ISBuildingObject.isValid(self, square) then
		return false
	end
	return true
end

function ISBuildTableSaw:render(x, y, z, square)
	--ISBuildingObject.render(self, x, y, z, square)
	
	local spriteName = self:getSprite()
	if not self.RENDER_SPRITE then
		self.RENDER_SPRITE = IsoSprite.new()
	end
	if self.RENDER_SPRITE_NAME ~= spriteName then
		self.RENDER_SPRITE:LoadSingleTexture(spriteName)
		self.RENDER_SPRITE_NAME = spriteName
	end
	
	local sharedSprite = getSprite(spriteName)
	if not (square and sharedSprite) then
		self.RENDER_SPRITE:RenderGhostTile(x, y, z)
		return
	end
	
	local offsetY = 0
	local props = ISMoveableSpriteProps.new(sharedSprite)
	local objProps = sharedSprite:getProperties();
	if objProps then 
		if objProps:has("IsStackable") then
			offsetY = props:getTotalTableHeight(square)
		
		elseif objProps:has("IsTableTop") then
			local surfaceHeight = tonumber(objProps:get("Surface")) or 0
			local furnitureHeight = props:getTotalTableHeight(square)
			offsetY = furnitureHeight - surfaceHeight
		
		else
			-- 保持默认offsetY=0
		end
	end 
	
	local r, g, b, a = 1, 1, 1, 1.0
	if not self:isValid(square) then
		r, g, b, a = 0.65, 0.2, 0.2, 1.0
	end
	
	-- 执行渲染
	self.RENDER_SPRITE:RenderGhostTileColor(x, y, z, 0, offsetY * Core.getTileScale(), r, g, b, a)
end

function ISBuildTableSaw:new(sprite, northSprite,eastSprite,southSprite, tabindex, listindex, sel)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o:init()
	o:setSprite(sprite)
	o:setNorthSprite(northSprite)
	o.eastSprite = eastSprite;
	o.southSprite = southSprite;
    --o:setEastSprite(eastSprite);   -- 
    --o:setSouthSprite(southSprite); -- 
	
	o.tabindex = tabindex
	o.listindex = listindex
	o.sel = sel
	
	if SandboxVars.IsAllTileInvincible then 
		o.isThumpable = false;
	end 
	
	o.canBeAlwaysPlaced = true;
	o.needToBeAgainstWall = false
	o.name = 'TableSaw'
	return o
end