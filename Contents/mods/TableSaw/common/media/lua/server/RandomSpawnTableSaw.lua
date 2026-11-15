
RandomSpawnTableSaw = RandomSpawnTableSaw or {}

RandomSpawnTableSaw.RoomList = 
{
	['garagestorage'] = true,
	['toolstore'] = true,
	['factory'] = true,
	['warehouse'] = true,
	['loggingfactory'] = true,
	['loggingtruck'] = true,
	['batfactory'] = true,
}


-- 
function RandomSpawnTableSaw.spawnTableSaw(square)

	local tableSaw = IsoObject.new(square:getCell(), square, 'TableSaw_0')
    tableSaw:createContainersFromSpriteProperties()
	for i = 1, tableSaw:getContainerCount() do
		local container = tableSaw:getContainerByIndex(i - 1);
		container:setExplored(true);
	end
	
	local modData = tableSaw:getModData();
	--modData.Durable = ZombRandFloat(95.00,100.00)
	modData.Durable = TableSawMaxDurable - ZombRandFloat(0.00,20.00)
	local rand = ZombRand(0,100)
	if rand <= 10 then 
		modData.SawBladeDurable = 0.0 
	else 
		modData.SawBladeDurable = ZombRandFloat(10.00,SawBladeMaxDurable) 
	end 
	
	square:AddSpecialObject(tableSaw)
	--tableSaw:transmitCompleteItemToServer()
	tableSaw:transmitCompleteItemToClients()
end

-- 
function RandomSpawnTableSaw.onSeeNewRoom(room)
	local roomType = room:getName()
	--print('first:',roomType)
	if RandomSpawnTableSaw.RoomList[roomType] then 
		local rand = ZombRand(0,100)
		if rand <= 2 then 
			local square = room:getRandomFreeSquare()
			if square then
				RandomSpawnTableSaw.spawnTableSaw(square)
			end 
		end 
	end
end

-- 
function RandomSpawnTableSaw.init()
	Events.OnSeeNewRoom.Add(RandomSpawnTableSaw.onSeeNewRoom)
end


Events.OnSGlobalObjectSystemInit.Add(RandomSpawnTableSaw.init)
