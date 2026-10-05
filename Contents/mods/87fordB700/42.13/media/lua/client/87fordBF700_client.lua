--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

require "Hooks/DAMN_EnterAnimations";

DAMN = DAMN or {};
B700 = B700 or {};
F700 = F700 or {};

DAMN.EnterAnimations:registerVehicleScript("Base.87fordB700military", "basic");
DAMN.EnterAnimations:registerVehicleScript("Base.87fordB700prison", "basic");
DAMN.EnterAnimations:registerVehicleScript("Base.87fordB700school", "basic");
DAMN.EnterAnimations:registerVehicleScript("Base.87fordF700bank", "basic");
DAMN.EnterAnimations:registerVehicleScript("Base.87fordF700box", "basic");

Events.OnPlayerUpdate.Add(function(player, vehicle, args)
    local player = getPlayer()
    local vehicle = player:getVehicle()
        if (vehicle and string.find( vehicle:getScriptName(), "87fordB700" )) then

		--local odfl = (vehicle:getPartById("DoorFrontLeft")):getDoor():isOpen()
        local odrl = (vehicle:getPartById("DoorRL")):getDoor():isOpen()
        local odmr = (vehicle:getPartById("DoorMR")):getDoor():isOpen()
        local odrr = (vehicle:getPartById("DoorRR")):getDoor():isOpen()
        

        local doorFront = vehicle:getPartById("DoorFrontRight")

            if odrl or odmr or odrr then
                vehicle:playPartAnim(doorFront, "Close")
                doorFront:getDoor():setOpen(false)
            else end
    end

end)

DAMN.EnterAnimations:registerVehicleScript("Base.87fordF700swat", function(seatIndex, player)
        if seatIndex == 0
        then
            return {
                ["damnPosition"] = "driver",
                ["damnRole"] = "",
            };
        elseif seatIndex == 1
        then
            return {
                ["damnPosition"] = "passenger",
                ["damnRole"] = "",
            };
        elseif seatIndex == 2 or seatIndex == 4 or seatIndex == 6
        then
            return {
                ["damnPosition"] = "facingRight",
                ["damnRole"] = "",
            };
        else
            return {
                ["damnPosition"] = "facingLeft",
                ["damnRole"] = "",
            };
        end
    end);