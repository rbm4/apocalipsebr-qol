
RaccoonCityServerCommand = RaccoonCityServerCommand or {}


local function RecoveryInfection(player)
	local bodyDamage = player:getBodyDamage()
	if bodyDamage:isInfected() then
		--print('Recovery infection')
		for i = 0, bodyDamage:getBodyParts():size() - 1 do
			local bodyPart = bodyDamage:getBodyParts():get(i)
			bodyPart:SetInfected(false)
		end
		bodyDamage:setInfected(false)
		player:getStats():set(CharacterStat.ZOMBIE_INFECTION, 0)
		--bodyDamage:setInfectionLevel(0)
		bodyDamage:setInfectionTime(-1.0)
		bodyDamage:setInfectionMortalityDuration(-1.0)
	end
end

function RaccoonCityServerCommand.OnClientCommand(_module, _command, _player, _args)
	--print("1_module:",_module)
    if _module ~= 'RaccoonCityCommand' then
        return
    end
    

    if _command == "addZombies" then
		if not _args.count or _args.count == 0 then 
			_args.count = 1
		end 
		addZombiesInOutfit(_args.x, _args.y, _args.z, _args.count, _args.outfit, _args.femaleChance)
        return
	elseif _command == "useVaccines" then 
		RecoveryInfection(_player)
    end
	--print("Command " .. _command)
end


Events.OnClientCommand.Add(RaccoonCityServerCommand.OnClientCommand)
