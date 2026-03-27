
DaisyDogSound = DaisyDogSound or {}

DaisyDogSound.SpriteList = {}

-- Dog
function DaisyDogSound.onClickDogSound1(_playerNum, tSquare)
    --print('onClickDogSound1')
	local player = getSpecificPlayer(_playerNum)
	local num1 = ZombRand(0, 6) + 1
	--print(num1)
	local strSound = 'DogSound' .. num1
	player:getEmitter():playSoundImpl(strSound, IsoObject.new())
end

-- Flirt2
--function DaisyDogSound.onClickMolestMenu2(_playerNum, tSquare)
--    --print('onClickDogSound1')
--	local player = getSpecificPlayer(_playerNum)
--	local num1 = ZombRand(0, 2) + 1
--	--print(num1)
--	local strSound = 'molest' .. num1
--	player:getEmitter():playSoundImpl(strSound, IsoObject.new())
--end

-- Cat
function DaisyDogSound.onClickCatSound1(_playerNum, tSquare)
    --print('onClickCatSound1')
	local player = getSpecificPlayer(_playerNum)
	local num1 = ZombRand(0, 5) + 1
	--print(num1)
	local strSound = 'CatSound' .. num1
	player:getEmitter():playSoundImpl(strSound, IsoObject.new())
end


function DaisyDogSound.DogBark(_playerNum, _context, _worldObjects,strSprite)
	if strSprite and strSprite ~= '' then
		if DaisyDogSound.SpriteList[strSprite] then 
			_context:addOption(getText('ContextMenu_DogBark'), _playerNum, DaisyDogSound.SpriteList[strSprite])
		end 
	end
end 

-- 
DaisyDogSound.SpriteList['daisy_furniture_02_8'] = DaisyDogSound.onClickDogSound1
DaisyDogSound.SpriteList['daisy_furniture_02_9'] = DaisyDogSound.onClickDogSound1
DaisyDogSound.SpriteList['daisy_furniture_02_10'] = DaisyDogSound.onClickDogSound1
DaisyDogSound.SpriteList['daisy_furniture_02_11'] = DaisyDogSound.onClickDogSound1
DaisyDogSound.SpriteList['daisy_furniture_02_12'] = DaisyDogSound.onClickDogSound1
DaisyDogSound.SpriteList['daisy_furniture_02_15'] = DaisyDogSound.onClickDogSound1
DaisyDogSound.SpriteList['daisy_furniture_02_13'] = DaisyDogSound.onClickCatSound1
DaisyDogSound.SpriteList['daisy_furniture_02_14'] = DaisyDogSound.onClickCatSound1
