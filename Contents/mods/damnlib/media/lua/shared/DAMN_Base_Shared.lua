--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};

require "DAMN_Helpers";

DAMN["partDefaultsDebug"] = false;
DAMN["modDataDebug"] = false;
DAMN["commandsDebug"] = false;
DAMN["backCompatDebug"] = false;
DAMN["spawnerDebug"] = false;
DAMN["armorEventDebug"] = false;
DAMN["weightDebug"] = false;
DAMN["scriptLoadDebug"] = false;
DAMN["tweakerDebug"] = false;

DAMN["vehiclesManaged"] = {};

-- moddata helpers

function DAMN:getModData(vehicle)
    local modData = vehicle:getModData();

    if not modData["damnlib_migrated"]
    then
        if DAMN["modDataDebug"]
        then
            DAMN:log("DAMN:getModData() -> current data on vehicle (before migration):");
            DAMN:logArray(modData);
        end

        if not isClient()
        then
            DAMN.BackCompat:migrateModData(vehicle);
        end

        modData = vehicle:getModData();

        if DAMN["modDataDebug"]
        then
            DAMN:log("DAMN:getModData() -> data on vehicle (after migration):");
            DAMN:logArray(modData);
        end
    end

    return modData;
end

function DAMN:saveModData(vehicle, data)
    if isClient()
    then
	    DAMN:sendLibCommand("setVehicleData", data, vehicle);
    else
        DAMN:setVehicleModData(vehicle, data);
    end
end

-- checks

function DAMN:vehicleIsManaged(vehicleScript)
    return DAMN["vehiclesManaged"][vehicleScript] ~= nil;
end

-- events

Events.OnGameBoot.Add(function()
    if getDebug()
    then
        DAMN:pruneLog();
    end
end);

Events.OnGameStart.Add(function()
    if getDebug()
    then
        DAMN:log("Vehicle scripts managed by that DAMN lib:");
        DAMN:logArray(DAMN["vehiclesManaged"]);
    end
end);