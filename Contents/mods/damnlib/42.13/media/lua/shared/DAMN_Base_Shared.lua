--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};

require "DAMN_Helpers";

DAMN["partFnDebug"] = false;
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

-- item spawning with b42

function DAMN:addItemsToPlayerInventory(itemArray, source, playerObj)
    --[[
        usage:

        DAMN:addItemsToPlayerInventory({
            "Full.ItemType", "Full.ItemType2", "Full.ItemType3",
        }, "crafting something special");

        DAMN:addItemsToPlayerInventory({
            itemId = "damnCraft.DoorSchematics",
        }, "some text maybe");

        DAMN:addItemsToPlayerInventory({
            itemId = "Full.ItemType",
            amount = 5,
        }, "recipe");

        DAMN:addItemsToPlayerInventory({
            {
                itemId = "Full.ItemType",
            },
            {
                itemId = "Full.ItemType2",
                amount = 2,
            },
        }, "refunding some parts or so");
    ]]--

    local args = {
        items = itemArray or {},
        source = source or "unknown",
    };

    if not isServer()
    then
        DAMN:sendLibCommand("addItemsToPlayerInventory", args);
    else
        DAMN.Commands.addItemsToPlayerInventory(playerObj, args);
    end
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