--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

require "Hooks/DAMN_EnterAnimations";

DAMN = DAMN or {};
STP85 = STP85 or {};

DAMN.EnterAnimations:registerVehicleScript("Base.85chevyStepVan", "basic");
DAMN.EnterAnimations:registerVehicleScript("Base.85chevyStepVanSWAT", function(seatIndex, player)
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
                ["damnPosition"] = "facingRight",
                ["damnRole"] = "",
            };
        elseif seatIndex == 6
        then
            return {
                ["damnPosition"] = "facingRight",
                ["damnRole"] = "",
            };
        elseif seatIndex == 8
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