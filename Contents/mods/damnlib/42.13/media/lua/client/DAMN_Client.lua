--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};

-- helpers

function DAMN:sendClientCommand(moduleName, methodName, args, vehicle)
	if vehicle
	then
		args["_vehicleId"] = vehicle:getId();
	end

	sendClientCommand(getPlayer(), moduleName, methodName, args or {});
end

function DAMN:sendLibCommand(methodName, args, vehicle)
	DAMN:sendClientCommand("that_damn_lib", methodName, args or {}, vehicle);
end

-- handlers

function DAMN.inVehicleUpdateTask(player)
    if DAMN["currentVehicleScript"] and DAMN.Armor["byVehicleScript"][DAMN["currentVehicleScript"]]
    then
        DAMN.Armor:runArmorCode(player, DAMN["currentVehicle"]);

        local currentTime = Calendar.getInstance():getTimeInMillis();

        if currentTime > DAMN.Armor["lastPartUpdate"] + DAMN.Armor["partUpdateInterval"]
        then
            DAMN.Armor:flushPartsBuffer(DAMN["currentVehicle"], currentTime);
        end
    end

    if DAMN["currentVehicle"]:isEngineRunning()
    then
        if DAMN.Armor:hasMagicTires()
        then
            DAMN.Armor:updateMagicTires(DAMN["currentVehicle"]);
        end

        if DAMN["vehicleHasAirBrake"]
        then
            local speed = DAMN["currentVehicle"]:getCurrentSpeedKmHour();

			if speed == 0 and not DAMN["airBrakePlayed"]
            then
                local emitter = getPlayer():getEmitter();

                if not emitter:isPlaying("damnBrake")
                then
                    emitter:setVolume(emitter:playSound("damnBrake"), 0.2);
                end

                DAMN["airBrakePlayed"] = true;
            end

            if speed ~= 0 and DAMN["airBrakePlayed"]
            then
                DAMN["airBrakePlayed"] = false;
            end
        end
    end
end

-- events

Events.OnEnterVehicle.Add(function(player)
    local vehicle = player:getVehicle();

    if vehicle
    then
        DAMN["currentVehicle"] = vehicle;
        DAMN["currentVehicleScript"] = vehicle:getScript():getFullName();

        if DAMN["armorEventDebug"]
        then
            DAMN:log("OnEnterVehicle: caching vehicle and vehicle script " .. tostring(DAMN["currentVehicleScript"]));
        end

        DAMN["vehicleHasRFS"] = vehicle:getPartById("RFsystem") ~= nil;
        DAMN["vehicleHasCTIS"] = vehicle:getPartById("CTIsystem") ~= nil;
        DAMN["vehicleHasAirBrake"] = vehicle:getPartById("airBrake") ~= nil;

        if DAMN.Armor:updateEventRequired()
        then
            if DAMN.Armor["byVehicleScript"][DAMN["currentVehicleScript"]]
            then
                if DAMN["armorEventDebug"]
                then
                    DAMN:log(" -> armor code exists, saving condition");
                end

                DAMN:sendLibCommand("savePartsCondition", {}, DAMN["currentVehicle"]);
            end

            if DAMN["armorEventDebug"] and DAMN.Armor:hasMagicTires()
            then
                DAMN:log(" -> rfs/ctis exists");
            end

            if DAMN["armorEventDebug"] and DAMN["vehicleHasAirBrake"]
            then
                DAMN:log(" -> air brake exists");
            end

            Events.OnPlayerUpdate.Remove(DAMN.inVehicleUpdateTask);
            Events.OnPlayerUpdate.Add(DAMN.inVehicleUpdateTask);
        end
    end
end);

Events.OnExitVehicle.Add(function(player)
    Events.OnPlayerUpdate.Remove(DAMN.inVehicleUpdateTask);

    if DAMN["armorEventDebug"]
    then
        DAMN:log("OnExitVehicle: clearing vehicle and vehicle script cache");
    end

    if DAMN.Armor["byVehicleScript"][DAMN["currentVehicleScript"]]
    then
        if DAMN["armorEventDebug"]
        then
            DAMN:log(" -> armor code exists, cleanup follows");
        end

        DAMN["onPlayerUpdateReported"] = nil;

        --DAMN:sendLibCommand("savePartsCondition", {
            --erase = true,
        --}, DAMN["currentVehicle"]);

        DAMN.Armor:flushPartsBuffer(DAMN["currentVehicle"], nil, true);
    end

    DAMN["currentVehicle"] = nil;
    DAMN["currentVehicleScript"] = nil;
    DAMN["vehicleHasRFS"] = false;
    DAMN["vehicleHasCTIS"] = false;
    DAMN["vehicleHasAirBrake"] = false;
end);

Events.OnServerCommand.Add(function(moduleName, command, args)
    if moduleName == "that_damn_lib"
    then
        if command == "playPartAnimation" and args["vehicleId"] and args["animation"]
        then
            local vehicle = getVehicleById(args["vehicleId"]);

            if vehicle
            then
                local part = vehicle:getPartById(args["partId"]);

                if part
                then
                    vehicle:playPartAnim(part, args["animation"]);

                    if args["animation"] == "Close" or args["animation"] == "Open"
                    then
                        local player = getPlayer();
                        local seat = vehicle:getSeat(player);

                        vehicle:playPartSound(part, player, args["animation"]);

                        if seat
                        then
                            vehicle:playPassengerAnim(seat, args["animation"] == "Open"
                                and "openDoor"
                                or "closeDoor", player);
                        else
                            vehicle:playActorAnim(part, args["animation"], player);
                        end
                    end
                end
            end
        end
    end
end);