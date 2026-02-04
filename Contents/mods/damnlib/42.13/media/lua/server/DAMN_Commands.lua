--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};
DAMN.Commands = DAMN.Commands or {};

-- helpers

function DAMN:setVehicleModData(vehicle, data, skipTransmit)
    if DAMN["modDataDebug"]
    then
        DAMN:log("DAMN.BackCompat:setVehicleModData() -> Setting vehicle moddata");
    end

    local modData = vehicle:getModData();

    for k, v in pairs(data)
    do
        if k ~= "_vehicleId" and k ~= "contentAmount"
        then
            if DAMN["modDataDebug"]
            then
                DAMN:log("- saving " .. tostring(k) .. " = " .. tostring(v));
            end

            modData[k] = v;
        end
    end

    if not skipTransmit
    then
        vehicle:transmitModData();
    end

    return modData;
end

function DAMN:spawnAndSendItem(playerObj, config)
    if config["fullType"]
    then
        config["amount"] = config["amount"] or 1;
        config["source"] = config["source"] or "unknown source";
        config["modData"] = config["modData"] or {};

        DAMN:appendLineToFile("that_damn_item_spawn.log", string.format("[%s] [%s] %s x %s (%s)",
            tostring(Calendar.getInstance():getTime()),
            tostring(playerObj),
            tostring(config["amount"]),
            tostring(config["fullType"]),
            tostring(config["source"])
        ));

        local inventory = playerObj:getInventory();

        for i = 1, config["amount"]
        do
            local item = instanceItem(config["fullType"]);

            if item
            then
                local itemData = item:getModData();

                for k, v in pairs(config["modData"])
                do
                    itemData[k] = v;
                end

                if config["condition"] and item["setCondition"]
                then
                    item:setCondition(tonumber(config["condition"]));
                end
                
                if config["name"] and item["setName"]
                then
                    item:setName(tostring(config["name"]));
                end
                
                inventory:AddItem(item);
                sendAddItemToContainer(inventory, item);
            end
        end
    end
end

-- handlers

function DAMN.Commands.addItemsToPlayerInventory(playerObj, args)
    args["items"] = args["items"] or {};

    if args["items"]["itemId"]
    then
        DAMN:spawnAndSendItem(playerObj, {
            fullType = args["items"]["itemId"],
            amount = args["items"]["amount"],
            modData = args["items"]["modData"],
            source = args["source"],
            condition = args["items"]["condition"],
            name = args["items"]["name"],
        });
    elseif args["items"][1] and type(args["items"][1]) == "string"
    then
        for i, itemId in ipairs(args["items"])
        do
            DAMN:spawnAndSendItem(playerObj, {
                fullType = itemId,
                amount = 1,
                modData = args["modData"],
                source = args["source"],
                condition = args["condition"],
                name = args["name"],
            });
        end
    else
        for k, spawnDef in pairs(args["items"])
        do
            DAMN:spawnAndSendItem(playerObj, {
                fullType = spawnDef["itemId"],
                amount = spawnDef["amount"],
                modData = spawnDef["modData"],
                source = args["source"],
                condition = spawnDef["condition"],
                name = args["name"],
            });
        end
    end
end

function DAMN.Commands.syncPartAnimation(playerObj, args)
    local players = getOnlinePlayers();

    if players and args["animation"]
    then
        local vehicle = getVehicleById(args["vehicle"]);

        if vehicle and DAMN:vehicleIsManaged(vehicle:getScript():getFullName())
        then
            --[[
            DAMN:log("DAMN.Commands.syncPartAnimation()");
            DAMN:logArray({
                vehicleId = tostring(args["vehicle"]),
                partId = tostring(args["part"]),
                animation = tostring(args["animation"]),
            });
            ]]--

            --local vehicleSquare = vehicle:getSquare();
            --local triggeredBy = playerObj:getDisplayName();

            for i = 0, players:size() - 1
            do
                local onlinePlayer = players:get(i);

                if onlinePlayer --and onlinePlayer:getDisplayName() ~= triggeredBy
                then
                    --local distance = vehicleSquare:DistToProper(onlinePlayer:getSquare());

                    --if onlinePlayer and distance and distance <= 150
                    --then
                        --DAMN:log(" - sending command to user " .. tostring(onlinePlayer:getDisplayName())
                            --.. " (distance: " .. tostring(distance) .. ")"
                        --);

                        sendServerCommand(onlinePlayer, "that_damn_lib", "playPartAnimation", {
                            vehicleId = args["vehicle"],
                            partId = args["part"],
                            animation = args["animation"],
                        });
                    --else
                        --DAMN:log(" - user " .. tostring(onlinePlayer:getDisplayName()) .. " too far away (distance: " .. tostring(distance) .. ")");
                    --end
                --else
                    --DAMN:log(" - skipping because user [" .. tostring(triggeredBy) .. "] triggered the event or is offline");
                end
            end
        end
    end
end

function DAMN.Commands.setVehicleData(playerObj, args)
	if DAMN["commandsDebug"]
	then
		DAMN:log("DAMN.Commands.setVehicleData(" .. playerObj:getUsername() .. ", " .. args["_vehicleId"] .. ")");
	end

    if args["_vehicle"]
	then
		DAMN:setVehicleModData(args["_vehicle"], args);
	elseif DAMN["commandsDebug"]
	then
		DAMN:log(" -> unable to find vehicle");
	end
end

function DAMN.Commands.setPartModData(playerObj, args)
	local vehicle = args["_vehicle"] or getVehicleById(args["vehicle"]);

	if vehicle and args.data
	then
		local part = vehicle:getPartById(args.part);

		if part
		then
			local modData = part:getModData();

			for key, value in pairs(args.data)
			do
				modData[key] = value;
			end

			vehicle:transmitPartModData(part);
		end
	end
end

function DAMN.Commands.silentPartInstall(playerObj, args)
	local item = args["item"];
	local part = args["part"];

	if args["_vehicle"] and part and item
	then
		if DAMN["commandsDebug"]
		then
			DAMN:log("DAMN.Commands.silentPartInstall(" .. playerObj:getUsername() .. ", " .. part .. ", " .. item .. ")");
		end

		item = instanceItem(item);
		part = args["_vehicle"]:getPartById(part);

		if part and item
		then
			part:setInventoryItem(item);
			args["_vehicle"]:transmitPartItem(part);

			local installTable = part:getTable("install");

			if installTable and installTable["complete"]
			then
				VehicleUtils.callLua(installTable["complete"], args["_vehicle"], part);
			end

			part:setRandomCondition(item);
			part:doInventoryItemStats(part:getInventoryItem(), part:getMechanicSkillInstaller());

			local wheelIndex = part:getWheelIndex();

			if wheelIndex ~= nil and wheelIndex > -1
			then
				part:setContainerContentAmount(ZombRand(25, 35));
			end

			args["_vehicle"]:transmitPartCondition(part);
			args["_vehicle"]:transmitPartModData(part);
		elseif DAMN["commandsDebug"]
		then
			DAMN:log(" -> no item generated");
		end
	elseif DAMN["commandsDebug"]
	then
		DAMN:log(" -> vehicle, part or item missing");
	end
end

function DAMN.Commands.savePartsCondition(playerObj, args)
	if DAMN["commandsDebug"]
	then
		DAMN:log("DAMN.Commands.savePartsCondition(" .. playerObj:getUsername() .. ", " .. args["_vehicleId"] .. ", " .. tostring(args["_vehicle"]) .. ")");
	end

    if args["_vehicle"]
	then
		for i = 0, args["_vehicle"]:getPartCount() -1
		do
			local part = args["_vehicle"]:getPartByIndex(i);

			if part -- DAMN.Parts:partIsInstalled(part)
			then
				local modData = part:getModData();
				local condition = not args["erase"]
					and part:getCondition()
					or nil;

				modData["saveCond"] = condition; -- backwards compatibility with older armor code
				modData["damn:savedCondition"] = condition;

				if DAMN["commandsDebug"]
				then
					DAMN:log(" - " .. tostring(part:getId()) .. " = " .. tostring(condition));
				end

				args["_vehicle"]:transmitPartModData(part);
			end
		end
	elseif DAMN["commandsDebug"]
	then
		DAMN:log(" -> unable to find vehicle");
	end
end

function DAMN.Commands.updatePartConditions(playerObj, args)
	if DAMN["commandsDebug"]
	then
		DAMN:log("DAMN.Commands.updatePartConditions(" .. playerObj:getUsername() .. ", " .. args["_vehicleId"] .. ", " .. tostring(args["_vehicle"]) .. ")");
		DAMN:logArray(args);
	end

	if args["_vehicle"] and args["conditions"]
	then
		for partId, condition in pairs(args["conditions"])
		do
			local part = args["_vehicle"]:getPartById(partId);

			if part
			then
				part:setCondition(tonumber(condition));
				part:doInventoryItemStats(part:getInventoryItem(), part:getMechanicSkillInstaller());

				args["_vehicle"]:transmitPartCondition(part);
			end
		end
	end
end