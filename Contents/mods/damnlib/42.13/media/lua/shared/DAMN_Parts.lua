--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "DAMN_Base_Shared";

DAMN = DAMN or {};
DAMN.Parts = DAMN.Parts or {};

KI5 = KI5 or {};
KI5["loadedParts"] = KI5["loadedParts"] or {};

-- debugging

function DAMN.Parts:checkPartsConfig(fullVehicleScript, rootNS)
	if rootNS["parts"]
	then
		for partNS, partConfig in pairs(rootNS["parts"])
		do
			for partName, partVariants in pairs(partConfig)
			do
				if type(partVariants) == "table"
				then
					if not getScriptManager():getVehicle(fullVehicleScript):getPartById(partName)
					then
						DAMN:log(fullVehicleScript .. ": Part slot " .. tostring(partName) .. " not found!");
					end
				end
			end
		end
	end
end

-- create vehicle parts functions from config

DAMN.Parts["loadedByVehicleScript"] = DAMN.Parts["loadedByVehicleScript"] or {};

function DAMN.Parts:processConfigV2(rootNsName, config)
	if not rootNsName or type(rootNsName) ~= "string"
	then
		DAMN:log("ERROR: invalid root namespace name given: (" .. type(rootNsName) .. ")[" .. tostring(rootNsName) .. "]");

		return false;
	end

	_G[rootNsName] = _G[rootNsName] or {};

	for i, node in ipairs({
		"Init", "Create", "InstallComplete", "UninstallComplete", "CheckEngine", "CheckOperate", "ContainerAccess", "InstallTest", "UninstallTest", "Update", "Use"
	})
	do
		if not _G[rootNsName][node]
		then
			if DAMN["partDefaultsDebug"]
			then
				DAMN:log("Creating main namespace node [" .. tostring(rootNsName) .. "." .. tostring(node) .. "]");
			end

			_G[rootNsName][node] = {};
		end
	end

	for partNS, partConfig in pairs(config or {})
	do
		if DAMN["partDefaultsDebug"]
		then
			DAMN:log("Processing part namespace [" .. tostring(partNS) .. "]");
		end

		if not _G[rootNsName][partNS]
		then
			if DAMN["partDefaultsDebug"]
			then
				DAMN:log(" - Populating main part function node [" .. tostring(rootNsName) .. "." .. tostring(partNS) .. "]");
			end

			_G[rootNsName][partNS] = function(vehicle, part)
				DAMN.Parts:mainPartFn(vehicle, part, partConfig, rootNsName, partNS);
			end;
		end

		if not _G[rootNsName].Create[partNS]
		then
			if DAMN["partDefaultsDebug"]
			then
				DAMN:log(" - Populating part function [" .. tostring(rootNsName) .. ".Create." .. tostring(partNS) .. "]");
			end

			_G[rootNsName].Create[partNS] = function(vehicle, part)
				DAMN.Parts:createPartFn(vehicle, part, partConfig, rootNsName, partNS);
			end
		end

		for i, node in ipairs({
			"Init", "InstallComplete", "UninstallComplete"
		})
		do
			if not _G[rootNsName][node][partNS]
			then
				if DAMN["partDefaultsDebug"]
				then
					DAMN:log(" - Populating part function [" .. tostring(rootNsName) .. "." .. tostring(node) .. "." .. tostring(partNS) .. "]");
				end

				_G[rootNsName][node][partNS] = function(vehicle, part)
                    if DAMN["partFnDebug"]
                    then
                        DAMN:log("Executing [" .. tostring(rootNsName) .. "." .. tostring(node) .. "." .. tostring(partNS) .. "]");
                    end

					if node == "Init"
					then
						DAMN.Parts.initPartFn(vehicle, part, partConfig, rootNsName, partNS);
					end

					DAMN.Parts:installPartFn(vehicle, part, partConfig, rootNsName, partNS);
				end
			end
		end
	end
end

function DAMN.Parts:processConfig(rootNS)
	for i, node in ipairs({"Init", "Create", "InstallComplete", "UninstallComplete", "CheckEngine", "CheckOperate", "ContainerAccess", "InstallTest", "UninstallTest", "Update", "Use"})
	do
		if not rootNS[node]
		then
			rootNS[node] = {};
		end
	end

	if rootNS["parts"]
	then
		for partNS, partConfig in pairs(rootNS["parts"])
		do
			for partName, partVariants in pairs(partConfig)
			do
				if type(rootNS["parts"][partNS]) == "table"
				then
					if not rootNS[partNS]
					then
						rootNS[partNS] = function(vehicle, part)
							part = vehicle:getPartById(partName);

							local item = part:getInventoryItem();

							if item
							then
								for varModelName, varItem in pairs(partVariants)
								do
									part:setModelVisible(varModelName, item:getType() == varItem);
								end
							end
						end;
					end

					if not rootNS.Create[partNS]
					then
						rootNS.Create[partNS] = function(vehicle, part)
							part:setInventoryItem(nil);
							rootNS[partNS](vehicle, part, nil);
							vehicle:doDamageOverlay();
						end
					end

					for i, partFn in ipairs({"Init", "InstallComplete", "UninstallComplete"})
					do
						if not rootNS[partFn][partNS]
						then
							rootNS[partFn][partNS] = function(vehicle, part)
								if partFn == "Init"
								then
									if not vehicle:getPartById(partName)
									then
										DAMN:log(vehicle:getFullType() .. " -> Part slot " .. tostring(partName) .. " not found!");
									end

									if isServer() == false
									then
										DAMN.Parts:processDefaults(vehicle, part, rootNS["parts"][partNS]);
										--DAMN.BackCompat:checkLegacyTires(vehicle);
									end

									local vName = vehicle:getScript():getName();

									if not DAMN.Parts["loadedByVehicleScript"][vName]
									then
										DAMN.Parts["loadedByVehicleScript"][vName] = {
											rootNS = rootNS,
											parts = {}
										}
									end

									if not DAMN.Parts["loadedByVehicleScript"][vName]["parts"][partNS]
									then
										DAMN.Parts["loadedByVehicleScript"][vName]["parts"][partNS] = true;
									end
								end

								rootNS[partNS](vehicle, part);
								vehicle:doDamageOverlay();
							end
						end
					end
				end
			end
		end
	end
end

-- main functions to save a bit of memory

function DAMN.Parts:rememberPart(vehicle, part, partConfig, rootNsName, partNS)
	local vehicleScript = vehicle:getScript():getFullName();

	DAMN["vehiclesManaged"][vehicleScript] = DAMN["vehiclesManaged"][vehicleScript] or {};
    DAMN["vehiclesManaged"][vehicleScript]["parts"] = true;

	if not DAMN.Parts["loadedByVehicleScript"][vehicleScript]
	then
		DAMN.Parts["loadedByVehicleScript"][vehicleScript] = {
			rootNS = _G[rootNsName],
			parts = {},
		};
		KI5["loadedParts"][vehicleScript] = DAMN.Parts["loadedByVehicleScript"][vehicleScript];
	end

	DAMN.Parts["loadedByVehicleScript"][vehicleScript]["parts"][partNS] = true;
	KI5["loadedParts"][vehicleScript]["parts"][partNS] = true;

	DAMN["vehiclesManaged"][vehicleScript] = DAMN["vehiclesManaged"][vehicleScript] or {};
	DAMN["vehiclesManaged"][vehicleScript]["parts"] = true;
end

function DAMN.Parts:mainPartFn(vehicle, part, partConfig, rootNsName, partNS)
    if DAMN["partFnDebug"]
    then
        DAMN:log("Executing [" .. tostring(rootNsName) .. "." .. tostring(partNS) .. "]");
    end

	part = vehicle:getPartById(partConfig["partId"]);

	local item = part:getInventoryItem();

    if DAMN["partFnDebug"]
    then
        DAMN:log(" - installed item: " .. tostring(item and item:getFullType() or "none"));
    end

	if item and partConfig["itemToModel"]
	then
		for itemName, models in pairs(partConfig["itemToModel"])
		do
			models = DAMN:tableIfNotTable(models);

			local isInstalled = item:getFullType() == itemName or item:getType() == itemName;

            if DAMN["partFnDebug"]
            then
                DAMN:log(" - checking if item [" .. tostring(itemName) .. "] is installed: " .. tostring(isInstalled));
            end

			for i, modelName in ipairs(models)
			do
                if DAMN["partFnDebug"]
                then
                    DAMN:log("    -> setting model [" .. tostring(modelName) .. "] to visibility: " .. tostring(isInstalled));
                end

				part:setModelVisible(modelName, isInstalled);
			end
		end
	end

	vehicle:doDamageOverlay();
end

function DAMN.Parts.initPartFn(vehicle, part, partConfig, rootNsName, partNS)
	if not vehicle:getPartById(partConfig["partId"])
	then
		DAMN:log(rootNsName .. " -> Part slot " .. tostring(partConfig["partId"]) .. " not found!");
	end

	if isServer() == false
	then
		DAMN.Parts:processDefaults(vehicle, part, partConfig);
		--DAMN.BackCompat:checkLegacyTires(vehicle);

        if partConfig["legacyPartsReplacements"]
        then
            DAMN.BackCompat:replaceLegacyItemsInSlot(vehicle, part, partConfig["legacyPartsReplacements"]);
        end

        if partConfig["piggybackPartsReplacements"]
        then
            DAMN.BackCompat:replaceLegacyItems(vehicle, partConfig["piggybackPartsReplacements"]);
        end
	end

	DAMN.Parts:rememberPart(vehicle, part, partConfig, rootNsName, partNS);
end

function DAMN.Parts:createPartFn(vehicle, part, partConfig, rootNsName, partNS)
    if DAMN["partFnDebug"]
    then
        DAMN:log("Executing [" .. tostring(rootNsName) .. ".Create." .. tostring(partNS) .. "]");
    end

	part:setInventoryItem(nil);
	_G[rootNsName][partNS](vehicle, part, nil);
end

function DAMN.Parts:installPartFn(vehicle, part, partConfig, rootNsName, partNS)
	local wheelIndex = part:getWheelIndex();

	if wheelIndex ~= nil and wheelIndex > -1
	then
        if DAMN["partFnDebug"]
        then
            DAMN:log(" - part has wheel index [" .. tostring(wheelIndex) .. "]: treating it as a tire");
        end

		vehicle:setTireRemoved(wheelIndex, DAMN.Parts:partIsMissing(part));
	end

	_G[rootNsName][partNS](vehicle, part);
end

-- process default parts config

function DAMN.Parts:processDefaults(vehicle, part, partConfig)
	local partId = part:getId();
	local modData = DAMN:getModData(vehicle);

	if not modData["defaultPartSet_" .. partId] and DAMN.Parts:partIsMissing(part)
	then
		if DAMN["partDefaultsDebug"] and item
		then
			DAMN:log(" - MP client or SP: Processing parts defaults for part id " .. partId);
		end

		if partConfig["default"]
		then
			local possibilities = {};

			if partConfig["allowedForRandom"]
			then
				possibilities = partConfig["allowedForRandom"];
			elseif part:getTable("install")
			then
				local items = part:getItemType();

				for i = 0, items:size() - 1
				do
					table.insert(possibilities, items:get(i));
				end
			end

			if #possibilities > 0
			then
                if DAMN["partDefaultsDebug"]
				then
                    DAMN:log(" - available items:");
                    DAMN:logArray(possibilities);
                end

				local item = nil;

				if partConfig["default"] == "first"
				then
					item = possibilities[1];
				elseif partConfig["default"] == "trve_random" or partConfig["default"] == "random"
				then
                    if partConfig["default"] == "trve_random"
                    then
                        if ZombRand(101) >= (tonumber(partConfig["noPartChance"]) or 50)
                        then
                            item = DAMN:pickRandomItemFromArray(possibilities);
                        end
                    else
                        item = DAMN:pickRandomItemFromArray(possibilities);
                    end
				else
					item = partConfig["default"];
				end

				if item
				then
					DAMN.Parts:silentInstall(part, item);
				end

				DAMN:saveModData(vehicle, {
					["defaultPartSet_" .. partId] = "true"
				});
			elseif DAMN["partDefaultsDebug"]
			then
				DAMN:log(" -> no item choices available for " .. tostring(partId));
			end
		end

		--[[
		if part:getTable("install")
		then
			local default = partConfig["default"];
			local item = nil;

			if default
			then
				local possibilities = part:getItemType();

				if default == "first"
				then
					item = possibilities:get(0);
				elseif default == "random"
				then
					item = possibilities:get(ZombRandBetween(0, possibilities:size()));
				elseif default == "trve_random"
				then
					if ZombRandBetween(1, 100) >= tonumber(partConfig["noPartChance"] or 50)
					then
						item = possibilities:get(ZombRandBetween(0, possibilities:size()));
					end
				else
					item = default;
				end

                if DAMN["partDefaultsDebug"] and item
                then
                    DAMN:log("DAMN.Parts:processDefaults() -> installing item " .. tostring(item) .. " in slot " .. partId);
                end

				if item
				then
					DAMN.Parts:silentInstall(part, item);
				end
			end

			DAMN:saveModData(vehicle, {
				["defaultPartSet_" .. partId] = "true"
			});
		end
		]]--
	end
end

-- helpers

function DAMN:eachPart(vehicle, fn)
    for i = 0, vehicle:getPartCount() -1
    do
        local part = vehicle:getPartByIndex(i);

        if part and DAMN.Parts:partIsInstalled(part)
        then
            if fn(part) == true
            then
                return part;
            end
        end
    end
end

function DAMN.Parts:partIsMissing(part)
    return part:getItemType() and tostring(part:getItemType():isEmpty()) == "false" and tostring(part:getInventoryItem()) == "nil";
end

function DAMN.Parts:partIsInstalled(part)
    return not DAMN.Parts:partIsMissing(part);
end

function DAMN.Parts:silentInstall(part, itemId)
    if DAMN["partDefaultsDebug"]
	then
        DAMN:log("DAMN.Parts:silentInstall() -> silently installing " .. itemId .. " for " .. part:getId());
    end

	DAMN:sendLibCommand("silentPartInstall", {
		part = part:getId(),
		item = itemId,
	}, part:getVehicle());
end

function DAMN.Parts:setContainerAmount(part, amount)
	DAMN:sendClientCommand("vehicle", "setContainerContentAmount", {
		vehicle = part:getVehicle():getId(),
		part = part:getId(),
		amount = amount
	});
end