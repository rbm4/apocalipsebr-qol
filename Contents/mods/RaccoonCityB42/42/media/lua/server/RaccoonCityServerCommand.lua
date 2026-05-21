
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
    elseif _command == "closeBiochemicalDoor" then
        -- Force-close all open doors on the Biochemical PickupTruck.
        -- Handles the case where ISCloseVehicleDoor's NetTimedAction fails silently
        -- on the server (getDuration()=0 with nil part deserialization or stalled
        -- ISEnterVehicle blocking the action queue from reaching ISCloseVehicleDoor).
        local vehicle = _player:getVehicle()
        if not vehicle then return end
        if vehicle:getScriptName() ~= "Base.Biochemical_PickupTruck" then return end
        local doorPartIds = { "DoorFrontLeft", "DoorFrontRight", "DoorRearLeft", "DoorRearRight" }
        for _, partId in ipairs(doorPartIds) do
            local part = vehicle:getPartById(partId)
            if part and part:getDoor() and part:getDoor():isOpen() then
                part:getDoor():setOpen(false)
                vehicle:transmitPartDoor(part)
            end
        end
    end
end


Events.OnClientCommand.Add(RaccoonCityServerCommand.OnClientCommand)
