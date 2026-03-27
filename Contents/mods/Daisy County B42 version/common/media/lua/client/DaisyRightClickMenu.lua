require "DaisyDogSound"



DaisyRightClickMenu = DaisyRightClickMenu or {}




function DaisyRightClickMenu.onClickRight(_playerNum, _context, _worldObjects)
	
	local player = getSpecificPlayer(_playerNum)
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
				
					
					-- 和猫猫狗狗玩
					DaisyDogSound.DogBark(_playerNum, _context, _worldObjects,strSprite)
				end
			end
		end
	end
end 



Events.OnFillWorldObjectContextMenu.Add(DaisyRightClickMenu.onClickRight)