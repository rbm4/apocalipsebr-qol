
RaccoonCityItemsSpawns = RaccoonCityItemsSpawns or {}

RaccoonCityItemsSpawns.BoxCount = 0
RaccoonCityItemsSpawns.BoxCountMax = 45
RaccoonCityItemsSpawns.dabaojian = 0
RaccoonCityItemsSpawns.Katana = 0
RaccoonCityItemsSpawns.SamuraiEdgeNum = 0
RaccoonCityItemsSpawns.AdapterNum = 0


function RaccoonCityItemsSpawns.getRandomSubset(nMax, n)
    local used = {}
    local nType = 1
    -- 
    while nType <= n do
        local num = ZombRand(0,nMax) + 1
        -- 
        if not used[num] then
            used[num] = nType
			--print('mydebug:create Badge Spawns list -- Which box:',num,'  Badge type:', nType)
			nType = nType + 1
        end
    end
    
    return used
end


function RaccoonCityItemsSpawns.OnBadgeSpawns(roomName, containerType, container)
	-- 兼容某个MOD
	if containerType == "BatteryBank" then
		return -- 
	end
	-- 一个容器各刷个，剩下的交给自动刷
	if roomName:contains("rpackroom") then
		if containerType == "backpack_rack" then 
			local item = container:AddItem("ResidentEvilBackPack");
			--if item:getModData().Actuallca then
			--	--print('aa1:',item:getModData().Actuallca)
			--else 
			--	item:getModData().Actuallca = item:getCapacity()
			--end
			--item:setCapacity(60)
			--item:getModData().Actuallca = 60
			--if player:HasTrait("aa") then 
		end 
	elseif roomName:contains("foresthut") then -- 木工书
		if containerType == "crate" then 
			container:AddItem("ApocalypseMagazineWood");
		end 
	elseif roomName:contains("metalfence") then -- 金工书
		if containerType == "shelves" then 
			container:AddItem("ApocalypseMagazineMetal");
		end 
	elseif roomName:contains("passwordbook") then -- 密码本
		if containerType == "crate" then 
			container:AddItem("RaccoonCityPassWordBook");
		end 
	elseif roomName:contains("gunstorehide") then -- 枪店隐藏
		if containerType == "knifeshelf" and not SandboxVars.DisableDaBaoJian then 
			container:AddItem("dabaojian");
		end 
		if containerType == "militarycrate" and not SandboxVars.DisableDaBaoJian then 
			local rand = ZombRand(0, 100) + 1
			if rand <= 30 then 
				container:AddItem("dabaojian");
			end 
		end 
	elseif roomName:contains("biochemlab") then -- 疫苗所
		if containerType == "VaccineCabinet" and not SandboxVars.DisableVaccines then 
			container:AddItem("BiochemicalVaccines");
		end 
	elseif roomName:contains("secretslaughter") then -- 屠宰室
		if containerType == "metal_shelves" then 
			container:AddItem("LargeHook");
		end 
	elseif roomName:contains("DeanSecureRoom") then -- 校长密室
		if containerType == "crate" then 
			container:AddItem("ResidentEvilSuspenders");
		end 
	elseif roomName:contains("swordshop") then -- 刀店
		if containerType == "shelves" then 
			local gameTime = getGameTime()
			local modData = gameTime:getModData()
			if not modData.Katana then 
				modData.Katana = 0
			end 
			--if RaccoonCityItemsSpawns.Katana < 3 then -- 最多刷3把
			if modData.Katana < 3 then -- 最多刷3把
				local rand = ZombRand(0, 100) + 1
				if rand <= 10 then 
					container:AddItem("Katana");
					--RaccoonCityItemsSpawns.Katana = RaccoonCityItemsSpawns.Katana + 1
					modData.Katana = modData.Katana + 1
				end 
			end 
			if not SandboxVars.DisableDaBaoJian then 
				if not modData.dabaojian then 
					modData.dabaojian = 0
				end 
				if modData.dabaojian < 1 then -- 最多刷1把
					local rand = ZombRand(0, 100) + 1
					if rand <= 10 then 
						container:AddItem("dabaojian");
						modData.dabaojian = modData.dabaojian + 1
					end 
				end 
			end 
		end 
	elseif roomName:contains("tophidden") then -- 
		if containerType == "militarylocker" or containerType == "militarycrate" then 
			if not SandboxVars.DisableBenelli then 
				for i = 1,3 do 
					local rand = ZombRand(0, 100) + 1
					if rand <= 10 then 
						container:AddItem("benellim4super90");
					end 
				end 
			end 
			if not SandboxVars.DisableQiBao then 
				for i = 1,3 do 
					local rand = ZombRand(0, 100) + 1
					if rand <= 4 then 
						container:AddItem("qibaowangshengdadi");
					end 
				end 
			end 
		end 
		if containerType == "crate" and not SandboxVars.DisableSamuraiEdge then 
			container:AddItem("RPDGunModificationMagazine");
		end 
	elseif roomName:contains("SledgehammerRoom") then -- 
		if containerType == "counter" then 
			container:AddItem("Sledgehammer");
		end 
	elseif roomName:contains("HideTyrant") then -- 
		if containerType == "militarycrate" and not SandboxVars.DisableSamuraiEdge then 
			local gameTime = getGameTime()
			local modData = gameTime:getModData()
			if not modData.SamuraiEdgeNum then 
				modData.SamuraiEdgeNum = 0
			end 
			if not modData.AdapterNum then 
				modData.AdapterNum = 0
			end 
			if modData.SamuraiEdgeNum < 6 then 
				container:AddItem("SamuraiEdge")
				container:AddItem("SamuraiEdgeClip")
				modData.SamuraiEdgeNum = modData.SamuraiEdgeNum + 1
			else 
				local rand = ZombRand(0, 100) + 1
				if rand <= 30 then 
					container:AddItem("SamuraiEdge")
					container:AddItem("SamuraiEdgeClip")
				end 
			end 
			if modData.AdapterNum < 2 then 
				container:AddItem("SamuraiEdgeAdapter")
				container:AddItem("AdapterClip")
				modData.AdapterNum = modData.AdapterNum + 1
			else 
				local rand = ZombRand(0, 100) + 1
				if rand <= 10 then 
					container:AddItem("SamuraiEdgeAdapter")
					container:AddItem("AdapterClip")
				end 
			end 
		end 
	end 
	-- 第一次就随机好哪个箱子刷什么徽章
	--if not RaccoonCityItemsSpawns.RanList then
	--	RaccoonCityItemsSpawns.RanList = RaccoonCityItemsSpawns.getRandomSubset(RaccoonCityItemsSpawns.BoxCountMax,4)
	--end 
	if containerType == "badgebox" then 
		local gameTime = getGameTime()
		local modData = gameTime:getModData()
		if not modData.BoxCount then 
			modData.BoxCount = 0
		end 
		if not modData.RanList then 
			-- 第一次就随机好哪个箱子刷什么徽章
			modData.RanList = RaccoonCityItemsSpawns.getRandomSubset(RaccoonCityItemsSpawns.BoxCountMax,4)
		end 
		--RaccoonCityItemsSpawns.BoxCount = RaccoonCityItemsSpawns.BoxCount + 1
		modData.BoxCount = modData.BoxCount + 1
		--if RaccoonCityItemsSpawns.RanList[RaccoonCityItemsSpawns.BoxCount] and RaccoonCityItemsSpawns.RanList[RaccoonCityItemsSpawns.BoxCount] ~= 0 then 
		if modData.RanList[modData.BoxCount] and modData.RanList[modData.BoxCount] ~= 0 then 
			--if RaccoonCityItemsSpawns.RanList[RaccoonCityItemsSpawns.BoxCount] == 1 then 
			if modData.RanList[modData.BoxCount] == 1 then 
				container:AddItem("UnicornBadge")
				--print('mydebug:UnicornBadge Spawns boxnum:',RaccoonCityItemsSpawns.BoxCount)
			--elseif RaccoonCityItemsSpawns.RanList[RaccoonCityItemsSpawns.BoxCount] == 2 then 
			elseif modData.RanList[modData.BoxCount] == 2 then 
				container:AddItem("MaidenBadge")
				--print('mydebug:MaidenBadge Spawns boxnum:',RaccoonCityItemsSpawns.BoxCount)
			--elseif RaccoonCityItemsSpawns.RanList[RaccoonCityItemsSpawns.BoxCount] == 3 then 
			elseif modData.RanList[modData.BoxCount] == 3 then 
				container:AddItem("LionBadge")
				--print('mydebug:LionBadge Spawns boxnum:',RaccoonCityItemsSpawns.BoxCount)
			--elseif RaccoonCityItemsSpawns.RanList[RaccoonCityItemsSpawns.BoxCount] == 4 then 
			elseif modData.RanList[modData.BoxCount] == 4 then 
				container:AddItem("re2_09")
				--print('mydebug:re2_09 Spawns boxnum:',RaccoonCityItemsSpawns.BoxCount)
			end 
		end 
	end 
end 


Events.OnFillContainer.Add(RaccoonCityItemsSpawns.OnBadgeSpawns)



