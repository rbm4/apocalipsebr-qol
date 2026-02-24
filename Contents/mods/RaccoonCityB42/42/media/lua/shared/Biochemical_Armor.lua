
Biochemical_Armor = Biochemical_Armor or {}


Biochemical_Armor.getModDataList = function(object)
    if not object:getModData().CarData then
        object:getModData().CarData = {}
    end
    return object:getModData().CarData
end

-- 进车记录数据并插入需要装甲的部位
Biochemical_Armor.Biochemical_VehicleEnter = function(player)
	--print('Biochemical_VehicleEnter')
	local modData = Biochemical_Armor.getModDataList(player)
	local vehicle = player:getVehicle()
	local ArmorParts = {}
	
	for i = 1, vehicle:getPartCount() do
		local part = vehicle:getPartByIndex(i - 1)
		if part:getTable("Biochemical_Armor") then
			table.insert(ArmorParts, part)
		end
	end
	
	modData.VehicleObject = 
	{
		objVehicle = vehicle,
		tPartList = ArmorParts
	}
end 

-- 将被保护部件的耐久消耗转化为装甲部件耐久消耗(改成保险杠保护全车)
Biochemical_Armor.DurableConvert = function(vehicle, armorpart)
	--print('aa--------')
	if armorpart:getTable("Biochemical_Armor") then
		local item = armorpart:getInventoryItem()
		if item then 
			local ArmorTable = armorpart:getTable("Biochemical_Armor")
			
			-- 全TMD保护
			local sPartList = {
			ArmorTable.part1, 
			ArmorTable.part2, 
			ArmorTable.part3,
			ArmorTable.part4,
			ArmorTable.part5,
			ArmorTable.part6,
			ArmorTable.part7,
			ArmorTable.part8,
			ArmorTable.part9,
			ArmorTable.part10,
			ArmorTable.part11,
			ArmorTable.part12,
			ArmorTable.part13,
			ArmorTable.part14,
			ArmorTable.part15,
			ArmorTable.part16,
			ArmorTable.part17,
			ArmorTable.part18,
			}
			for _, tPart in ipairs(sPartList) do
				local PartID = vehicle:getPartById(tPart)
				if PartID then 
					local modData = Biochemical_Armor.getModDataList(PartID)
					if modData.durable and modData.diff then 
						
						if PartID:getCondition() < modData.durable then 
							local nArmorDurable = armorpart:getCondition()
							-- 装甲不炸被装甲部件永远不掉耐久
							if nArmorDurable > 0 then 
								local nDiff = modData.durable - PartID:getCondition() 
								if nDiff >= 5 then 
									nDiff = 1
								end 
								--print('--------modData.diff=',modData.diff)
								modData.diff = modData.diff + nDiff
								if modData.diff > 45 then 
									--print('dayu 100')
									if nArmorDurable >= 1 then 
										-- 读取装甲率 也就是耐久消耗的减少百分比
										local nRate = ArmorTable.Biochemical_ArmorRate[item:getType()]
										--print(nRate)
										PartID:setCondition(modData.durable) 
										-- 懒得算直接就是1
										local nDeduct = nArmorDurable - 1
										--print('--------nDeduct=',nDeduct)
										armorpart:setCondition(nDeduct) -- 扣除装甲耐久（×消耗比率）
									else 
										-- 耐久最后一次掉为0的时候将没扣完的数值扣到被保护的部件上
										local nDeduct = 0
										if modData.durable >= 1 then 
											nDeduct = modData.durable - 1
										end 
										PartID:setCondition(nDeduct) 
										armorpart:setCondition(0)
										--print('last')
									end 
									modData.diff = 0
								else 
									-- 没到一定的耐久消耗就先恢复到记录的耐久
									PartID:setCondition(modData.durable) 
								end 
							else 
								--print('end-----------------')
								-- 装甲掉完了就只做记录
								modData.durable = PartID:getCondition()
							end 
						end 
					else 
						-- 先设置为当前耐久
						modData.durable = PartID:getCondition()
						modData.diff = 0
					end 
				end 
			end 
		end 
	end 
end 

-- 一直更新的事件
Biochemical_Armor.Biochemical_PlayerUpdate = function(player)
	--print('Biochemical_PlayerUpdate')
    local vehicle = player:getVehicle()
    if not vehicle then return end
	
	local modData = Biochemical_Armor.getModDataList(player)
	local vehicleObject = modData.VehicleObject
	if vehicleObject then
		if vehicleObject.objVehicle == vehicle then
			for i = 1, #vehicleObject.tPartList do
				local armorpart = vehicleObject.tPartList[i]
				Biochemical_Armor.DurableConvert(vehicle, armorpart)
			end
		end
	end
	-- 后备箱懒得弄装甲了直接不掉耐久吧
	if vehicle and vehicle:getScriptName() == 'Base.Biochemical_PickupTruck' then
		local TruckBedPart = vehicle:getPartById('TruckBed')
		local ndurable = TruckBedPart:getCondition()
		if (ndurable ~= 100) then
			--print('100')
			sendClientCommand(player, "vehicle", "setPartCondition", { vehicle = vehicle:getId(), part = TruckBedPart:getId(), condition = 100 })
		end 
	end
end 




Events.OnEnterVehicle.Add(Biochemical_Armor.Biochemical_VehicleEnter)
Events.OnPlayerUpdate.Add(Biochemical_Armor.Biochemical_PlayerUpdate)