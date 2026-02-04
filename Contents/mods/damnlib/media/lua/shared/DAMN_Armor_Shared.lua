--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "DAMN_Base_Shared";

DAMN = DAMN or {};
DAMN.Armor = DAMN.Armor or {};

DAMN.Armor["byVehicleScript"] = DAMN.Armor["byVehicleScript"] or {};

-- helpers

-- this registers the car for automatic storage and removal of saved conditions for parts when entering/leaving a vehicle
-- and will execute the handler on player update. the handler function gets a player instance and a vehicle instance to use for the armor code you want to add.
-- adding another armor code with the same vehicle script name will override existing ones - useful for people who want to customize or override it on their servers
function DAMN.Armor:add(fullVehicleScriptName, handler)
    DAMN.Armor["byVehicleScript"][fullVehicleScriptName] = handler;

    DAMN["vehiclesManaged"][fullVehicleScriptName] = DAMN["vehiclesManaged"][fullVehicleScriptName] or {};
    DAMN["vehiclesManaged"][fullVehicleScriptName]["armor"] = true;
end