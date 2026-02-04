--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};

-- events

Events.OnClientCommand.Add(function(moduleName, command, playerObj, args)
    if moduleName == "that_damn_lib" and DAMN.Commands[command]
    then
        if DAMN["commandsDebug"]
        then
            DAMN:log("OnClientCommand: " .. tostring(moduleName) .. "." .. tostring(command));
        end

        args = args or {};

        if args["_vehicleId"]
        then
            vehicle = getVehicleById(args["_vehicleId"]);

            if vehicle
            then
                DAMN.BackCompat:migrateModData(vehicle);

                args["_vehicle"] = vehicle;
            end
        end

        DAMN.Commands[command](playerObj, args);
    elseif moduleName == "vehicle" and command == "setDoorOpen"
    then
        args["animation"] = args["open"]
            and "Opened"
            or "Closed";

        DAMN.Commands.syncPartAnimation(playerObj, args, command);
    end
end);