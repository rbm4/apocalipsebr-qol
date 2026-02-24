-- ****************************************************
-- Author：十叁
-- Date：2025.01.14
-- ****************************************************
-- 注意自己改一下 BasementPoliceCarSpawns 类名防止跟别人冲突，我就不发创意工坊了不然地图又要多一个前置
-- 文件放在lua\server 目录下 自行修改 BasementPoliceCarSpawns.CarLocationList 表的数据即可

BasementPoliceCarSpawns = BasementPoliceCarSpawns or {}
BasementPoliceCarSpawns.ModName = 'BasementPoliceCarSpawns'



BasementPoliceCarSpawns.DirRandom1 = 
{
	IsoDirections.S,
	IsoDirections.N,
}
BasementPoliceCarSpawns.DirRandom2 = 
{
	IsoDirections.E,
	IsoDirections.W,
}
--[[
EW方向坐标
    。
  。  。
。  。  。
  。  。  。
    *   。
      。
SN方向坐标
        。
      。  。
    。  。  。
  。  。  。
    。  *
      。
--]]
-- 
BasementPoliceCarSpawns.CarLocationList = 
{
	-- 坐标字符串                                车辆组名                            刷新概率     是否随机方向(根据dir前后随机)   方向          钥匙几率
	-- 地下室-1层
	['10220,10403,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10223,10403,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10227,10403,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10231,10403,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10235,10403,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10223,10392,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10227,10392,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10231,10392,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10227,10383,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.N, SpawnsKey = 10},
	['10231,10383,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.N, SpawnsKey = 10},
	['10235,10383,-1'] = {CarTypeList = VehicleZoneDistribution.police.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.N, SpawnsKey = 10},


	['10443,10290,-1'] = {CarTypeList = VehicleZoneDistribution.good.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10446,10290,-1'] = {CarTypeList = VehicleZoneDistribution.good.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.S, SpawnsKey = 10},
	['10424,10286,-1'] = {CarTypeList = VehicleZoneDistribution.good.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.W, SpawnsKey = 10},
	['10424,10276,-1'] = {CarTypeList = VehicleZoneDistribution.good.vehicles, SpawnsChance = 80, RandomDir = false, dir = IsoDirections.W, SpawnsKey = 10},
}

function BasementPoliceCarSpawns.GetCarFullType(charlist)
	local temp = {}
	for strType, v in pairs(charlist) do
		table.insert(temp,strType)
		--print(strType, v)
	end
	if #temp >= 1 then 
		local rannum = ZombRand(0,#temp) + 1
		return temp[rannum]
	end 
	
	return ''
end 


function BasementPoliceCarSpawns.RecordModData(strIndex)
	ModData.getOrCreate(BasementPoliceCarSpawns.ModName)[strIndex] = Calendar.getInstance():getTimeInMillis();
	ModData.transmit(BasementPoliceCarSpawns.ModName);
end 

function BasementPoliceCarSpawns.CheckSpawns(strIndex)
	return ModData.getOrCreate(BasementPoliceCarSpawns.ModName)[strIndex]
end 

function BasementPoliceCarSpawns.SpawnsPoliceCar(square)
	local x = square:getX()
	local y = square:getY()
	local z = square:getZ()
	local strIndex = tostring(x)..','..tostring(y)..','..tostring(z)
	if BasementPoliceCarSpawns.CarLocationList[strIndex] then 
		--print('aa:',strIndex)
		if not BasementPoliceCarSpawns.CheckSpawns(strIndex) then 
			local rannum = ZombRand(0,100) + 1
			if rannum <= BasementPoliceCarSpawns.CarLocationList[strIndex].SpawnsChance then 
				local strCarTyep = BasementPoliceCarSpawns.GetCarFullType(BasementPoliceCarSpawns.CarLocationList[strIndex].CarTypeList)
				if strCarTyep ~= '' then 
					local dir = IsoDirections.S
					if BasementPoliceCarSpawns.CarLocationList[strIndex].RandomDir then 
						local temp = nil 
						if BasementPoliceCarSpawns.CarLocationList[strIndex].dir == IsoDirections.S or 
							BasementPoliceCarSpawns.CarLocationList[strIndex].dir == IsoDirections.N then 
								temp = BasementPoliceCarSpawns.DirRandom1
						elseif BasementPoliceCarSpawns.CarLocationList[strIndex].dir == IsoDirections.W or 
							BasementPoliceCarSpawns.CarLocationList[strIndex].dir == IsoDirections.E then 
								temp = BasementPoliceCarSpawns.DirRandom2
						end 
						if temp == nil then 
							return 
						end 
						local nIndex = ZombRand(0,#temp) + 1
						dir = BasementPoliceCarSpawns.DirRandom[nIndex]
					else 
						dir = BasementPoliceCarSpawns.CarLocationList[strIndex].dir
					end 
					--print('add:',strCarTyep)
					local car = addVehicleDebug(strCarTyep, dir, nil, square)
					--car:repair()
					if car then 
						if dir == IsoDirections.N then
							car:setAngles(0, 180, 0)
						elseif dir == IsoDirections.S then
							car:setAngles(0, 0, 0)
						elseif dir == IsoDirections.E then
							car:setAngles(0, 90, 0)
						elseif dir == IsoDirections.W then
							car:setAngles(0, -90, 0)
						end
						local rankey = ZombRand(0,100) + 1
						if rankey <= BasementPoliceCarSpawns.CarLocationList[strIndex].SpawnsKey then 
							--car:putKeyInIgnition(car:createVehicleKey())
							local GloveBox = car:getPartById('GloveBox')
							if GloveBox then 
								local inv = GloveBox:getItemContainer()
								if inv then 
									--print('addKey')
									inv:AddItem(car:createVehicleKey())
								end 
							end 
						end 
					end 
					
					BasementPoliceCarSpawns.RecordModData(strIndex)
				end 
			else 
				BasementPoliceCarSpawns.RecordModData(strIndex)
			end 
		end 
	end 
end 


function BasementPoliceCarSpawns.LoadGridsquareAdd()
	--print('BasementPoliceCarSpawns.LoadGridsquareAdd')
	Events.LoadGridsquare.Add(BasementPoliceCarSpawns.SpawnsPoliceCar)
end 


Events.OnInitGlobalModData.Add(BasementPoliceCarSpawns.LoadGridsquareAdd)