
FirearmsSuppressor = FirearmsSuppressor or {}




function FirearmsSuppressor.SetSoundEffects(player, weapon)
	if SandboxVars.DisableAdapterSuppressor then 
		return 
	end 
	if not player then return end
	if not weapon then return end
	if not weapon:IsWeapon() then return end 
	if not weapon:isRanged() then return end

	local strWeaponType = weapon:getType()
	if strWeaponType ~= 'SamuraiEdgeAdapter' then return end 
	--print(weapon:getType())
	local Script = weapon:getScriptItem()

	local SoundVolume = Script:getSoundVolume()
	local SoundRadius = Script:getSoundRadius()
	--print('HX_SoundVolume1:',SoundVolume)
	--print('HX_SoundRadius1:',SoundRadius)
	local SwingSound = Script:getSwingSound()

	-- 获取枪口配件
	local Canon = weapon:getWeaponPart("Canon")
	if Canon then 
		local strCanonType = Canon:getType()
		if strCanonType == 'AdapterSuppressor' then 
			-- 消音90%
			SoundVolume = SoundVolume * 0.1
			SoundRadius = SoundRadius * 0.1
			-- 修改音效为消音音效
			SwingSound = 'SamuraiEdgeSuppressed'
		else 
			--print('return')
			return 
		end 
	end 
	--print('HX_SoundVolume2:',SoundVolume)
	--print('HX_SoundRadius2:',SoundRadius)
	weapon:setSoundVolume(SoundVolume)
	weapon:setSoundRadius(SoundRadius)
	weapon:setSwingSound(SwingSound)
end 


function FirearmsSuppressor.OnEquipPrimary(player, weapon)
	--print('FirearmsSuppressor.OnEquipPrimary')
	FirearmsSuppressor.SetSoundEffects(player, weapon)
end 


function FirearmsSuppressor.OnPlayerAttackFinished(player, weapon)
	FirearmsSuppressor.SetSoundEffects(player, weapon)
end 


function FirearmsSuppressor.OnGameStart()
	local player = getPlayer()
	FirearmsSuppressor.SetSoundEffects(player, player:getPrimaryHandItem())
end 

-- 进入游戏
Events.OnGameStart.Add(FirearmsSuppressor.OnGameStart)
-- 每次攻击完成
Events.OnPlayerAttackFinished.Add(FirearmsSuppressor.OnPlayerAttackFinished)
-- 装备武器
Events.OnEquipPrimary.Add(FirearmsSuppressor.OnEquipPrimary)
