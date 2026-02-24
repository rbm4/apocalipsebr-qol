require "PasswordDoorCore"
require "RaccoonCityFlirt"
require "RaccoonCityMyGo"
require "RaccoonCityPoliceDecryption"
require "Re2Jigsaw"


RaccoonCityRightClickMenu = RaccoonCityRightClickMenu or {}




function RaccoonCityRightClickMenu.onClickRight(_playerNum, _context, _worldObjects)
	--print('dd_playerNum：',_playerNum)
	local player = getSpecificPlayer(_playerNum)
	if player:getVehicle() then return end
	
	-- 获取选中世界对象数据
	local tSquare = nil
	for i,v in ipairs(_worldObjects) do
		local square = v:getSquare();
		if square then
			tSquare = square
			break
		end
	end
	
	-- 遍历数据List
	if tSquare then
		local objList = tSquare:getObjects()
		for i = 0, objList:size() - 1 do
			local obj = objList:get(i)
			if obj:getSprite() ~= nil then
				local strSprite = obj:getSprite():getName()
				--print(strSprite)
				-- 比对瓷砖名
				if strSprite and strSprite ~= '' then
				
					-- 密码门
					PasswordDoorCore.PasswordDoorMenu(_playerNum, _context, _worldObjects,strSprite)
					-- 调戏
					RaccoonCityFlirt.FlirtGarageKit(_playerNum, _context, _worldObjects,strSprite)
					-- MyGo
					--print('aa_playerNum：',_playerNum)
					RaccoonCityMyGo.MyGoRightMenu(_playerNum, _context, _worldObjects,strSprite,tSquare)
					-- 警局解密
					RaccoonCityPoliceDecryption.OnPutMenu(_playerNum, _context, _worldObjects,strSprite)
					-- 拼图解密
					Re2Jigsaw.LionStatue(_playerNum, _context, _worldObjects,strSprite)
				end
			end
		end
	end
end 



Events.OnFillWorldObjectContextMenu.Add(RaccoonCityRightClickMenu.onClickRight)