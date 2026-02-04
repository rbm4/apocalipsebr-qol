--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "DAMN_Base_Shared";

DAMN = DAMN or {};
DAMN.BackCompat = DAMN.BackCompat or {};

-- moddata fuckery because storing vehicle moddata was wonky when mp was new

DAMN.BackCompat["muleParts"] = DAMN.BackCompat["muleParts"] or {
	"M101A3Trunk",
	"GloveBox",
	"TruckBed",
	"TrailerTrunk",
	"TruckBedOpen",
	"Engine",
};

function DAMN.BackCompat:getModData(vehicle)
	local part = DAMN.BackCompat:getMulePart(vehicle);

	if part
	then
        local modData = part:getModData();

        if DAMN["backCompatDebug"]
        then
            DAMN:logArray(modData);
        end

		return modData;
	else
        if DAMN["backCompatDebug"]
        then
            DAMN:log("DAMN:getModData() -> data mule part NOT found");
        end

		return {};
	end
end

function DAMN.BackCompat:getMulePart(vehicle)
	if vehicle
	then
		for i, partId in ipairs(DAMN.BackCompat["muleParts"])
		do
			local part = vehicle:getPartById(partId);

			if part
			then
				return part;
			end
		end

        if DAMN["backCompatDebug"]
        then
            DAMN:log("DAMN.BackCompat:getMulePart() -> mule part not found");
        end
	elseif DAMN["backCompatDebug"]
    then
		DAMN:log("DAMN.BackCompat:getMulePart() -> vehicle not found");
	end

	return nil;
end

function DAMN.BackCompat:setMulePartData(vehicle, data)
    local part = DAMN.BackCompat:getMulePart(vehicle);

    if part
    then
        if DAMN["backCompatDebug"]
        then
            DAMN:log("DAMN.BackCompat:setMulePartData() -> Setting mule part mod data");
        end

        local modData = part:getModData();

        for k, v in pairs(data)
        do
            if k ~= "_vehicleId" and k ~= "contentAmount"
            then
                if DAMN["backCompatDebug"]
                then
                    DAMN:log("- setting " .. tostring(k) .. " = " .. tostring(v));
                end

                modData[k] = v;
            end
        end

        vehicle:transmitPartModData(part);
    elseif DAMN["backCompatDebug"]
    then
        DAMN:log("DAMN.BackCompat:setMulePartData() -> Unable to find mule part");
    end
end

function DAMN.BackCompat:migrateModData(vehicle)
    if vehicle
    then
        local modData = vehicle:getModData();

        if not modData["damnlib_migrated"]
        then
            if DAMN["backCompatDebug"]
            then
                DAMN:log("DAMN.BackCompat:migrateModData() -> Moddata migration is necessary");
            end

            modData["damnlib_migrated"] = true;

            DAMN:setVehicleModData(vehicle, DAMN.BackCompat:getModData(vehicle));
        elseif DAMN["backCompatDebug"]
        then
            DAMN:log("DAMN.BackCompat:migrateModData() -> Moddata was already migrated");
        end
    end
end

-- obsolete but can be used later on for different migrations

function DAMN.BackCompat:checkLegacyTires(vehicle)
	for i = 0, vehicle:getPartCount() -1
	do
		local part = vehicle:getPartByIndex(i);

		if not DAMN:partIsMissing(part)
		then
			local inventoryItem = part:getInventoryItem();

			if inventoryItem and inventoryItem:getFullType() == "Base.V100Tire2"
			then
                if DAMN["partDefaultsDebug"]
                then
                    DAMN:log("DAMN.BackCompat:checkLegacyTires() -> replacing " .. inventoryItem:getFullType() .. " on vehicle " .. tostring(vehicle:getSqlId()));
                end

				DAMN:silentPartInstall(part, "Base.V101Tire2");
				DAMN:setContainerAmount(part, 35);
			end
		end
	end
end