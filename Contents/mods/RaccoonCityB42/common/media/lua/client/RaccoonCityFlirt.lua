
RaccoonCityFlirt = RaccoonCityFlirt or {}

RaccoonCityFlirt.SpriteList = {}

-- Flirt1
function RaccoonCityFlirt.onClickMolestFlirt1(_playerNum, tSquare)
    --print('onClickMolestFlirt1')
	local player = getSpecificPlayer(_playerNum)
	local num1 = ZombRand(0, 3) + 1
	local strSound = 'molest' .. num1
	player:getEmitter():playSoundImpl(strSound, IsoObject.new())
end

-- Flirt2
--function RaccoonCityFlirt.onClickMolestMenu2(_playerNum, tSquare)
--    --print('onClickMolestFlirt1')
--	local player = getSpecificPlayer(_playerNum)
--	local num1 = ZombRand(0, 2) + 1
--	--print(num1)
--	local strSound = 'molest' .. num1
--	player:getEmitter():playSoundImpl(strSound, IsoObject.new())
--end

-- FlirtKunKun
function RaccoonCityFlirt.onClickFlirtMenuKunKun(_playerNum, tSquare)
    --print('onClickFlirtMenuKunKun')
	local player = getSpecificPlayer(_playerNum)
	local num1 = ZombRand(0, 2) + 1
	--print(num1)
	local strSound = 'molest_kk' .. num1
	player:getEmitter():playSoundImpl(strSound, IsoObject.new())
end


function RaccoonCityFlirt.FlirtGarageKit(_playerNum, _context, _worldObjects,strSprite)
	if strSprite and strSprite ~= '' then
		if RaccoonCityFlirt.SpriteList[strSprite] then 
			_context:addOption(getText('ContextMenu_Flirt'), _playerNum, RaccoonCityFlirt.SpriteList[strSprite])
		end 
	end
end 

-- 
RaccoonCityFlirt.SpriteList['shisan_resident_48'] = RaccoonCityFlirt.onClickMolestFlirt1
RaccoonCityFlirt.SpriteList['shisan_resident_49'] = RaccoonCityFlirt.onClickMolestFlirt1
--RaccoonCityFlirt.SpriteList['shisan_resident_50'] = RaccoonCityFlirt.onClickMolestFlirt1-- 八尺夫人找不到音效。。。
--RaccoonCityFlirt.SpriteList['shisan_resident_51'] = RaccoonCityFlirt.onClickMolestFlirt1
--RaccoonCityFlirt.SpriteList['shisan_resident_52'] = RaccoonCityFlirt.onClickMolestMenu2--男手办暂时滚一边
RaccoonCityFlirt.SpriteList['shisan_resident_53'] = RaccoonCityFlirt.onClickMolestFlirt1
RaccoonCityFlirt.SpriteList['shisan_resident_54'] = RaccoonCityFlirt.onClickMolestFlirt1

RaccoonCityFlirt.SpriteList['shisan_furniture_3_69'] = RaccoonCityFlirt.onClickFlirtMenuKunKun
RaccoonCityFlirt.SpriteList['shisan_furniture_3_70'] = RaccoonCityFlirt.onClickFlirtMenuKunKun
