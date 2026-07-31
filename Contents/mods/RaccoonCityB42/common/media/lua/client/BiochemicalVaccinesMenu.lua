

BiochemicalVaccinesMenu = BiochemicalVaccinesMenu or {}

-- 判断物品是否在地面
function BiochemicalVaccinesMenu.IsOnground(item,_playerNum)
	local player = getSpecificPlayer(_playerNum)
	local px = math.floor(player:getX())
	local py = math.floor(player:getY())
	local pz = math.floor(player:getZ())
	for x = px - 1, px + 1 do
		for y = py - 1, py + 1 do
			local square = getCell():getGridSquare(x,y,pz)
			local wobs = square and square:getWorldObjects() or nil
			if wobs ~= nil then
				for i = 1,wobs:size() do
					local obj = wobs:get(i-1)
					local itemobj = obj:getItem()
					if itemobj == item then 
						--print('true')
						return true
					end 
				end
			end
		end
	end
	return false
end

-- 右键菜单
BiochemicalVaccinesMenu.onRightClickVaccine = function(_playerNum , context, items)
	--local playerInv = getSpecificPlayer(_playerNum):getInventory()

	local item = nil
	for i,v in ipairs(items) do
		if instanceof(v, "InventoryItem") then
			item = v
		else
			item = v.items[1];
		end
		if item:getType() == "BiochemicalVaccines" then
			if not BiochemicalVaccinesMenu.IsOnground(item,_playerNum) then
				context:addOption(getText("ContextMenu_BiochemicalVaccines"), item, BiochemicalVaccinesMenu.onVaccination, _playerNum)
				--break
			end 
			break
		end
	end
end

-- 
BiochemicalVaccinesMenu.RecoveryInfection = function(player)
	local bodyDamage = player:getBodyDamage()
	if bodyDamage:isInfected() then
		--print('Recovery infection')
		for i = 0, bodyDamage:getBodyParts():size() - 1 do
			local bodyPart = bodyDamage:getBodyParts():get(i)
			bodyPart:SetInfected(false)
		end
		bodyDamage:setInfected(false)
		player:getStats():set(CharacterStat.ZOMBIE_INFECTION, 0)
		--bodyDamage:setInfectionLevel(0)
		bodyDamage:setInfectionTime(-1.0)
		bodyDamage:setInfectionMortalityDuration(-1.0)
	end
end



-- 打疫苗
BiochemicalVaccinesMenu.onVaccination = function(item, _playerNum)
	local playerObj = getSpecificPlayer(_playerNum)
	-- 使用物品
	item:Use();
	-- 恢复
	--playerObj:getBodyDamage():RestoreToFullHealth() -- 这个有点变态
	
	if isClient() then
		--print("server");
		sendClientCommand("RaccoonCityCommand", "useVaccines", nil);
		
	else
		BiochemicalVaccinesMenu.RecoveryInfection(playerObj)
		--print('client')
	end
	
	--BiochemicalVaccinesMenu.RecoveryInfection(playerObj)
	
	playerObj:getEmitter():playSoundImpl("injection", IsoObject.new())
	HaloTextHelper.addGoodText(playerObj, getText("IGUI_PlayerText_Vaccination"));
end

Events.OnFillInventoryObjectContextMenu.Add(BiochemicalVaccinesMenu.onRightClickVaccine);