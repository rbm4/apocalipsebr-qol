require "PasswordDoorUI"

PasswordDoorCore = PasswordDoorCore or {}

PasswordDoorCore.SpriteList = {}



function PasswordDoorCore.onClickPasswordDoorMenu(_playerNum, tSquare)
    --print('onClickPasswordDoorMenu')
	local ui = PasswordDoorUI:new(250, 270, getSpecificPlayer(_playerNum))
	ui:initialise()
	ui:addToUIManager()
end


function PasswordDoorCore.PasswordDoorMenu(_playerNum, _context, _worldObjects,strSprite)
	if strSprite and strSprite ~= '' then
		if PasswordDoorCore.SpriteList[strSprite] then 
			_context:addOption(getText('ContextMenu_PasswordDoor'), _playerNum, PasswordDoorCore.onClickPasswordDoorMenu)
		end 
	end
end 



PasswordDoorCore.SpriteList['d_shisan_cannotdamaged_8'] = PasswordDoorCore.onClickPasswordDoorMenu
PasswordDoorCore.SpriteList['d_shisan_cannotdamaged_9'] = PasswordDoorCore.onClickPasswordDoorMenu
PasswordDoorCore.SpriteList['d_shisan_cannotdamaged_10'] = PasswordDoorCore.onClickPasswordDoorMenu
PasswordDoorCore.SpriteList['d_shisan_cannotdamaged_11'] = PasswordDoorCore.onClickPasswordDoorMenu
PasswordDoorCore.SpriteList['d_shisan_cannotdamaged_12'] = PasswordDoorCore.onClickPasswordDoorMenu
