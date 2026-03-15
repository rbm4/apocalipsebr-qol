--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

require "Hooks/DAMN_EnterAnimations";

DAMN = DAMN or {};
F350 = F350 or {};

DAMN.EnterAnimations:registerVehicleScript("Base.90fordF350", function(seatIndex, player)
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
        elseif seatIndex == 2
        then
            return {
                ["damnPosition"] = "facingRight",
                ["damnRole"] = "",
            };
        elseif seatIndex == 4
        then
            return {
                ["damnPosition"] = "lying",
                ["damnRole"] = "",
            };
        else
            return {
                ["damnPosition"] = "facingLeft",
                ["damnRole"] = "",
            };
        end
    end);

DAMN.EnterAnimations:registerVehicleScript("Base.90fordF350SWAT", function(seatIndex, player)
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
        elseif seatIndex == 2
        then
            return {
                ["damnPosition"] = "facingRight",
                ["damnRole"] = "",
            };
        elseif seatIndex == 4
        then
            return {
                ["damnPosition"] = "lying",
                ["damnRole"] = "",
            };
        else
            return {
                ["damnPosition"] = "facingLeft",
                ["damnRole"] = "",
            };
        end
    end);
