
RaccoonCityPoliceDecryption = RaccoonCityPoliceDecryption or {}

RaccoonCityPoliceDecryption.SpriteList = {}

RaccoonCityPoliceDecryption.Debug = false


function RaccoonCityPoliceDecryption:AddSprite(x, y, z, SpriteName,player)
	local _square1 = getCell():getGridSquare(x, y, z)
	local cursor1 = ISBrushToolTileCursor:new(SpriteName, SpriteName, player)
	cursor1:create(_square1:getX(), _square1:getY(), _square1:getZ(), nil, SpriteName)
end 


function RaccoonCityPoliceDecryption:RemoveSprite(x, y, z, SpriteName)
    local _square = getCell():getGridSquare(x, y, z)
    local sqObjs     = _square:getObjects()
    local tbl        = {}
    for i = 0, sqObjs:size() - 1 do
        if not instanceof(sqObjs:get(i), "IsoWorldInventoryObject") then
            table.insert(tbl, sqObjs:get(i))
        end
    end
    for k, v in pairs(tbl) do
        if v:getSprite() ~= nil and v:getSprite():getName() == SpriteName then
            if isClient() then
                sledgeDestroy(v)
            else
                _square:transmitRemoveItemFromSquare(v)
            end
        end
    end
end


function RaccoonCityPoliceDecryption.removeItem(item, player)
    if item:getWorldItem() ~= nil then
        item:getWorldItem():getSquare():transmitRemoveItemFromSquare(item:getWorldItem());
        item:getWorldItem():removeFromWorld()
        item:getWorldItem():removeFromSquare()
        item:getWorldItem():setSquare(nil)
        -- getPlayerLoot(player):refreshBackpacks()
        return
    end

    if item:isEquipped() then
        local playerObj = item:getContainer():getParent()

        item:getContainer():setDrawDirty(true);
        item:setJobDelta(0.0);
        playerObj:removeWornItem(item)

        local hotbar = getPlayerHotbar(playerObj:getPlayerNum())
        local fromHotbar = false;
        if hotbar then
            fromHotbar = hotbar:isItemAttached(item);
        end

        if fromHotbar then
            hotbar.chr:setAttachedItem(item:getAttachedToModel(), item);
            playerObj:resetEquippedHandsModels()
        end

        if item == playerObj:getPrimaryHandItem() then
            if (item:isTwoHandWeapon() or item:isRequiresEquippedBothHands()) and
                item == playerObj:getSecondaryHandItem() then
                playerObj:setSecondaryHandItem(nil);
            end
            playerObj:setPrimaryHandItem(nil);
        end
        if item == playerObj:getSecondaryHandItem() then
            if (item:isTwoHandWeapon() or item:isRequiresEquippedBothHands()) and item == playerObj:getPrimaryHandItem() then
                playerObj:setPrimaryHandItem(nil);
            end
            playerObj:setSecondaryHandItem(nil);
        end
    end

    if isClient() and not instanceof(item:getOutermostContainer():getParent(), "IsoPlayer") and
        item:getContainer():getType() ~= "floor" then
        item:getContainer():removeItemOnServer(item);
    end

    item:getContainer():DoRemoveItem(item);
end

-- 
function RaccoonCityPoliceDecryption.onClickPut(_playerNum, tSquare)
	local player = getSpecificPlayer(_playerNum)
	
	local px = math.floor(player:getX())
	local py = math.floor(player:getY())
	local pz = math.floor(player:getZ())
	if pz ~= 0 then 
		--HaloTextHelper.addText(player, getText("IGUI_PlayerText_OutOfRange"), HaloTextHelper.getColorRed())
		HaloTextHelper.addBadText(player, getText("IGUI_PlayerText_OutOfRange"));
		return
	end 

	if not (px >= 10215 and px <= 10223 and py >= 10378 and py <= 10389) then 
		--HaloTextHelper.addText(player, getText("IGUI_PlayerText_OutOfRange"), HaloTextHelper.getColorRed())
		HaloTextHelper.addBadText(player, getText("IGUI_PlayerText_OutOfRange"));
		return
	end 
	
	local inv = player:getInventory()
	
	--local Unicorn = inv:getItemCountFromTypeRecurse('Base.UnicornBadge')
	--local Maiden = inv:getItemCountFromTypeRecurse('Base.MaidenBadge')
	--local Lion = inv:getItemCountFromTypeRecurse('Base.LionBadge')
	local Unicorn = inv:getItemFromType('UnicornBadge')
	local Maiden = inv:getItemFromType('MaidenBadge')
	local Lion = inv:getItemFromType('LionBadge')
	--if Unicorn > 0 and Maiden > 0 and Lion > 0 then 
	if Unicorn and Maiden and Lion then 
		--inv:Remove('UnicornBadge')
		--inv:Remove('MaidenBadge')
		--inv:Remove('LionBadge')
		
		--inv:DoRemoveItem(Unicorn)
		--inv:DoRemoveItem(Maiden)
		--inv:DoRemoveItem(Lion)
		
		local removelist = {}
		local it = inv:getItems();
		
		for j = 0, it:size()-1 do
			local item = it:get(j);
			local strType = item:getType()
			if strType == 'UnicornBadge' or strType == 'MaidenBadge' or strType == 'LionBadge' then 
				table.insert(removelist, item)
			end 
		end
		for _, item in ipairs(removelist) do
			inv:DoRemoveItem(item)
		end 

		if not RaccoonCityPoliceDecryption.Debug then 
			-- 文字提示
			--HaloTextHelper.addText(player, getText("IGUI_PlayerText_ActivateMechanism"), HaloTextHelper.getColorRed())
			HaloTextHelper.addGoodText(player, getText("IGUI_PlayerText_ActivateMechanism"));
			-- 播放音效
			player:getEmitter():playSoundImpl("badgeorgan", IsoObject.new())
			-- 处理机关处
			RaccoonCityPoliceDecryption:RemoveSprite(10218,10384,0, 'shisan_rpd_109')
			RaccoonCityPoliceDecryption:AddSprite(10218,10384,0, 'shisan_rpd_71' , player)
			-- 删除地板
			RaccoonCityPoliceDecryption:RemoveSprite(10233,10384,3, 'd_shisan_floor_01_49')
			RaccoonCityPoliceDecryption:RemoveSprite(10233,10383,3, 'd_shisan_floor_01_49')
			RaccoonCityPoliceDecryption:RemoveSprite(10232,10384,3, 'd_shisan_floor_01_49')
			RaccoonCityPoliceDecryption:RemoveSprite(10232,10383,3, 'd_shisan_floor_01_49')
			RaccoonCityPoliceDecryption:RemoveSprite(10231,10384,3, 'd_shisan_floor_01_49')
			RaccoonCityPoliceDecryption:RemoveSprite(10231,10383,3, 'd_shisan_floor_01_49')
			-- 添加梯子
			RaccoonCityPoliceDecryption:AddSprite(10233,10384,2, 'fixtures_stairs_01_16' , player)
			RaccoonCityPoliceDecryption:AddSprite(10233,10383,2, 'fixtures_stairs_01_16' , player)
			RaccoonCityPoliceDecryption:AddSprite(10232,10384,2, 'fixtures_stairs_01_17' , player)
			RaccoonCityPoliceDecryption:AddSprite(10232,10383,2, 'fixtures_stairs_01_17' , player)
			RaccoonCityPoliceDecryption:AddSprite(10231,10384,2, 'fixtures_stairs_01_18' , player)
			RaccoonCityPoliceDecryption:AddSprite(10231,10383,2, 'fixtures_stairs_01_18' , player)
		
			
			-- 生成僵尸
			for i = 1,50 do 
				-- 大厅
				local rx1 = ZombRand(10219, 10235)
				local ry1 = ZombRand(10380, 10389)
				if isClient() then
					--print("server");
					sendClientCommand("RaccoonCityCommand", "addZombies", {outfit = 'Police', x = rx1, y = ry1 , z = 2,count = 1,femaleChance = 50});
				else
					--print("client");
					addZombiesInOutfit(rx1, ry1, 2, 1, 'Police', 50)
				end
				-- 隐藏房间10213 10387   10222 10380
				local rx2 = ZombRand(10213, 10222)
				local ry2 = ZombRand(10380, 10387)
				if isClient() then
					--print("server");
					sendClientCommand("RaccoonCityCommand", "addZombies", {outfit = 'Police', x = rx2, y = ry2 , z = 3,count = 1,femaleChance = 50});
				else
					--print("client");
					addZombiesInOutfit(rx2, ry2, 3, 1, 'Police', 50)
				end
			end 
			if isClient() then
				--print("server");
				sendClientCommand("RaccoonCityCommand", "addZombies", {outfit = 'Police', x = rx2, y = ry2 , z = 3,count = 10,femaleChance = 50});
			else
				--print("client");
				addZombiesInOutfit(10227, 10384, 3, 10, 'Police', 50)
			end
		end 
	
	else 
		--HaloTextHelper.addText(player, getText("IGUI_PlayerText_ItemLack"), HaloTextHelper.getColorRed())
		HaloTextHelper.addBadText(player, getText("IGUI_PlayerText_ItemLack"));
	end 
end

function RaccoonCityPoliceDecryption.OnPutMenu(_playerNum, _context, _worldObjects,strSprite)
	if strSprite and strSprite == 'shisan_rpd_109' then
		_context:addOption(getText('ContextMenu_PutTheBadgeIn'), _playerNum, RaccoonCityPoliceDecryption.onClickPut , tSquare)
	end
end 


