--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "Vehicles/TimedActions/ISEnterVehicle";

DAMN = DAMN or {};
DAMN.EnterAnimations = DAMN.EnterAnimations or {};

-- registration

DAMN.EnterAnimations["variablesUsed"] = {
    "damnVehicle", "damnPosition", "damnRole",
};
DAMN.EnterAnimations["byScriptName"] = {};
DAMN.EnterAnimations["presets"] = DAMN.EnterAnimations["presets"] or {
    ["basic"] = function(seatIndex, player)
        return seatIndex == 0
            and {
                ["damnPosition"] = "driver",
            }
            or {
                ["damnPosition"] = "passenger",
            };
    end,
    ["low"] = function(seatIndex, player)
        return seatIndex == 0
            and {
                ["damnPosition"] = "driver_low",
            }
            or {
                ["damnPosition"] = "passenger_low",
            };
    end,
    ["sport"] = function(seatIndex, player)
        return seatIndex == 0
            and {
                ["damnPosition"] = "driver_sport",
            }
            or {
                ["damnPosition"] = "passenger_sport",
            };
    end,
};

function DAMN.EnterAnimations:registerVehicleScript(vehicleScriptName, presetOrCustomFn)
    DAMN.EnterAnimations["byScriptName"][vehicleScriptName] = presetOrCustomFn;
end

-- helpers

function DAMN.EnterAnimations:checkSeatPositionVar(player, vehicle, seatIndex)
    player = player or getPlayer();

    local vehicle = vehicle or (player and player:getVehicle());

    if vehicle
    then
        seatIndex = seatIndex or vehicle:getSeat(player);

        if seatIndex
        then
            local vehicleScript = vehicle:getScript():getFullName();
            local getAnimationFn = DAMN.EnterAnimations["byScriptName"][vehicleScript]
                and (type(DAMN.EnterAnimations["byScriptName"][vehicleScript]) == "string"
                    and DAMN.EnterAnimations["presets"][DAMN.EnterAnimations["byScriptName"][vehicleScript]]
                    or DAMN.EnterAnimations["byScriptName"][vehicleScript]
                )
                or DAMN.EnterAnimations["presets"]["basic"];

            if getAnimationFn
            then
                for variable, value in pairs(getAnimationFn(seatIndex, player))
                do
                    if value and value ~= ""
                    then
                        player:setVariable(variable, value);

                        if not DAMN:itemIsInArray(DAMN.EnterAnimations["variablesUsed"], variable)
                        then
                            table.insert(DAMN.EnterAnimations["variablesUsed"], variable);
                        end
                    else
                        player:ClearVariable(variable);
                    end
                end
            end
        end
    end
end

function DAMN.EnterAnimations:clearPlayerVars(player)
    player = player or getPlayer();

    player:ClearVariable("damnVehicle");

    for i, variable in ipairs(DAMN.EnterAnimations["variablesUsed"] or {})
    do
        player:ClearVariable(variable);
    end
end

-- handlers

function DAMN.EnterAnimations:onEnterVehicleStart(self, vanillaEnterStart)
    DAMN.EnterAnimations:clearPlayerVars(self["character"]);

    local isValid = self["character"] and self["vehicle"] and DAMN:vehicleIsManaged(self["vehicle"]:getScript():getFullName());

    if isValid
    then
        self["character"]:setVariable("damnVehicle", "True");
    end

    vanillaEnterStart(self);

    if isValid
    then
        DAMN.EnterAnimations:checkSeatPositionVar(self["character"], self["vehicle"], self["seat"]);
    end
end

function DAMN.EnterAnimations:onEnterVehiclePerform(self, vanillaEnterPerform)
    DAMN.EnterAnimations:checkSeatPositionVar(self["character"], self["vehicle"], self["seat"]);
    vanillaEnterPerform(self);
end

function DAMN.EnterAnimations:onEnterVehicleStop(self, vanillaEnterStop)
    DAMN.EnterAnimations:clearPlayerVars(self["character"]);
    vanillaEnterStop(self);
end

function DAMN.EnterAnimations:onExitVehicle(player)
    DAMN.EnterAnimations:clearPlayerVars(player);
end

function DAMN.EnterAnimations:onEnterVehicle(player)
    DAMN.EnterAnimations:checkSeatPositionVar(player);
end

function DAMN.EnterAnimations:onSwitchVehicleSeat(player)
    DAMN.EnterAnimations:checkSeatPositionVar(player);
end

-- events and hooks

Events.OnGameStart.Add(function()
    local vanillaEnterStart = ISEnterVehicle["start"];
    local vanillaEnterStop = ISEnterVehicle["stop"];
    local vanillaEnterPerform = ISEnterVehicle["perform"];

    ISEnterVehicle["start"] = function(self)
        DAMN.EnterAnimations:onEnterVehicleStart(self, vanillaEnterStart);
    end

    ISEnterVehicle["stop"] = function(self)
        DAMN.EnterAnimations:onEnterVehicleStop(self, vanillaEnterStop);
    end

    ISEnterVehicle["perform"] = function(self)
        DAMN.EnterAnimations:onEnterVehiclePerform(self, vanillaEnterPerform);
    end

    Events.OnExitVehicle.Add(function(player)
        DAMN.EnterAnimations:onExitVehicle(player);
    end);

    Events.OnEnterVehicle.Add(function(player)
        DAMN.EnterAnimations:onEnterVehicle(player);
    end);

    Events.OnSwitchVehicleSeat.Add(function(player)
        DAMN.EnterAnimations:onSwitchVehicleSeat(player);
    end);
end);