Events.OnPlayerUpdate.Add(function(player, vehicle, args)
    local vehicle = player.getVehicle and player:getVehicle() or nil
	if (vehicle and string.find( vehicle:getScriptName(), "CadillacRanger" )) then
	
	local part = vehicle:getPartById("GasTank")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	
	local part = vehicle:getPartById("Engine")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end

	local part = vehicle:getPartById("EngineDoor")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("WindowFrontLeft")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("Windshield")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("WindshieldRear")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("WindowFrontRight")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("WindowRearRight")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("WindowRearLeft")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("DoorFrontLeft")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("DoorFrontRight")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("DoorRearLeft")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	local part = vehicle:getPartById("DoorRearRight")
    		if part:getCondition() < 100 then
		part:setCondition(100)
	end
	end
	
end)