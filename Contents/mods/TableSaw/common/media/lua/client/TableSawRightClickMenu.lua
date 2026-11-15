

TableSawRightClickMenu = TableSawRightClickMenu or {}


TableSawRightClickMenu.CanSawLogList = 
{
	['Log'] = true,
	['LargeBranch'] = true,
	['Sapling'] = true,
}


function TableSawRightClickMenu.StartSawWood(_playerNum, Square, Sprite, tablesaw)
	local player = getSpecificPlayer(_playerNum)
	
	TableSawUI.openWindow(player, tablesaw)
end

function TableSawRightClickMenu.onClickRight(_playerNum, _context, _worldObjects)
	
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
			local tablesaw = obj:getSprite()
			if tablesaw ~= nil then
				local strSprite = tablesaw:getName()
				
				--print(strSprite)
				-- 比对瓷砖名
				if strSprite and TableSawSpriteList[strSprite] then
					--local objectIndex = obj:getObjectIndex()
					--print('objectIndex:',objectIndex)
					--_context:addOption(getText('ContextMenu_PutTheBadgeIn'), _playerNum, RaccoonCityPoliceDecryption.onClickPut , tSquare)
					local option = _context:insertOptionBefore(getText("ContextMenu_Walk_to"), getText("ContextMenu_TableSawInfor"), _playerNum, TableSawRightClickMenu.StartSawWood, tSquare, strSprite, obj)
					
					local iconTexture = getTexture("media/textures/TableSaw.png")
					if iconTexture and option then
						option.iconTexture = iconTexture
						option.icon = nil 
					end
				end
			end
		end
	end
end 



Events.OnFillWorldObjectContextMenu.Add(TableSawRightClickMenu.onClickRight)