--***********************************************************
--**     KI5 did this / bikinihorst is not to blame        **
--***********************************************************

DAMN = DAMN or {};
B700 = B700 or {};
F700 = F700 or {};

function B700.pvFixCheck()
	local vanillaEnter = ISEnterVehicle["start"];

	ISEnterVehicle["start"] = function(self)

		local vehicle = self.vehicle
			local vehicle = self.vehicle
			if 	vehicle and (
				string.find( vehicle:getScriptName(), "87fordB700" )) then

				self.character:SetVariable("damnVehicle", "True")
			end
		
	vanillaEnter(self);
		
		local seat = self.seat
    		if not seat then return end
				if seat == 0 then		
					self.character:SetVariable("damnPosition", "driver")
				else		
					self.character:SetVariable("damnPosition", "passenger")
			end
	end
end

function B700.pvFixSwitch(player)
	local player = getPlayer()
	local vehicle = player:getVehicle()
		if 	vehicle and (
			string.find( vehicle:getScriptName(), "87fordB700" )) then

			player:SetVariable("damnVehicle", "True")

			local seat = vehicle:getSeat(player)
	    		if not seat then return end
					if seat == 0 then		
						player:SetVariable("damnPosition", "driver")
					else		
						player:SetVariable("damnPosition", "passenger")
				end

	end
end

function B700.pvFixClear(player)

		player:SetVariable("damnVehicle", "False")
end

Events.OnPlayerUpdate.Add(function(player, vehicle, args)
    local player = getPlayer()
    local vehicle = player:getVehicle()
        if (vehicle and string.find( vehicle:getScriptName(), "87fordB700" )) then

		local odfl = (vehicle:getPartById("DoorFrontLeft")):getDoor():isOpen()
        local odrl = (vehicle:getPartById("DoorRL")):getDoor():isOpen()
        local odmr = (vehicle:getPartById("DoorMR")):getDoor():isOpen()
        local odrr = (vehicle:getPartById("DoorRR")):getDoor():isOpen()
        

        local doorFront = vehicle:getPartById("DoorFrontRight")

            if odfl or odrl or odmr or odrr then
                vehicle:playPartAnim(doorFront, "Close")
                doorFront:getDoor():setOpen(false)
            else end
    end

end)

function F700.pvFixCheck()
	local vanillaEnter = ISEnterVehicle["start"];

	ISEnterVehicle["start"] = function(self)

		local vehicle = self.vehicle
			local vehicle = self.vehicle
			if 	vehicle and (
				string.find( vehicle:getScriptName(), "87fordF700" )) then

				self.character:SetVariable("damnVehicle", "True")
			end
		
	vanillaEnter(self);
		
		local seat = self.seat
    		if not seat then return end
				if seat == 0 then		
					self.character:SetVariable("damnPosition", "driver")
                elseif seat == 1 then	
					self.character:SetVariable("damnPosition", "passenger")
                elseif seat == 2 or seat == 4 or seat == 6 then		
                    self.character:SetVariable("damnPosition", "facingRight")
                else
                    self.character:SetVariable("damnPosition", "facingLeft")
			end
	end
end

function F700.pvFixSwitch(player)
	local player = getPlayer()
	local vehicle = player:getVehicle()
		if 	vehicle and (
			string.find( vehicle:getScriptName(), "87fordF700" )) then

			player:SetVariable("damnVehicle", "True")

			local seat = vehicle:getSeat(player)
	    		if not seat then return end
					if seat == 0 then		
						player:SetVariable("damnPosition", "driver")
                    elseif seat == 1 then		
						player:SetVariable("damnPosition", "passenger")
                    elseif seat == 2 or seat == 4 or seat == 6 then		
                        player:SetVariable("damnPosition", "facingRight")
                    else
                        player:SetVariable("damnPosition", "facingLeft")
				end

	end
end

function F700.pvFixClear(player)

		player:SetVariable("damnVehicle", "False")
end

Events.OnGameStart.Add(B700.pvFixCheck);
Events.OnGameStart.Add(B700.pvFixSwitch);
Events.OnExitVehicle.Add(B700.pvFixClear);
Events.OnSwitchVehicleSeat.Add(B700.pvFixSwitch);

Events.OnGameStart.Add(F700.pvFixCheck);
Events.OnGameStart.Add(F700.pvFixSwitch);
Events.OnExitVehicle.Add(F700.pvFixClear);
Events.OnSwitchVehicleSeat.Add(F700.pvFixSwitch);