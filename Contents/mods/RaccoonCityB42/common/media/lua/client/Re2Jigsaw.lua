
Re2Jigsaw = Re2Jigsaw or {}


Re2Jigsaw.PicWndList = Re2Jigsaw.PicWndList or {}




function Re2Jigsaw.StartJigsaw(_playerNum, tSquare)
	--local player = getSpecificPlayer(_playerNum)
	local gameTime = getGameTime()
	local modData = gameTime:getModData()
	--if not modData.IsJigsawComplete then 
	if not modData.JigsawCompleteNum then 
		modData.JigsawCompleteNum = 1
	end 
	if modData.JigsawCompleteNum < 3 then 
		JigsawWindow:createWindow(_playerNum)
	end 
end 


function Re2Jigsaw.LionStatue(_playerNum, _context, _worldObjects,strSprite)
	local gameTime = getGameTime()
	local modData = gameTime:getModData()
	if not modData.JigsawCompleteNum or modData.JigsawCompleteNum < 3 then 
		if strSprite and strSprite == 'shisan_rpd7_79' then
			_context:addOption(getText('ContextMenu_StartJigsaw'), _playerNum, Re2Jigsaw.StartJigsaw , tSquare)
		end
	end 
end 