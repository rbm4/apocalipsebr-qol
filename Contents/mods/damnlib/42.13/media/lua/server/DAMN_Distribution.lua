--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};
DAMN.Distribution = DAMN.Distribution or {};

function DAMN.Distribution:addItemsToLocations(itemsAndChances, locations)
    if ProceduralDistributions and ProceduralDistributions["list"]
    then
        for item, chance in pairs(itemsAndChances)
        do
            for i, location in ipairs(locations)
            do
                if ProceduralDistributions["list"][location] and ProceduralDistributions["list"][location]["items"]
                then
                    table.insert(ProceduralDistributions["list"][location]["items"], item);
                    table.insert(ProceduralDistributions["list"][location]["items"], chance);
                else
                    DAMN:log("Skipping item distro location [" .. tostring(location) .. "] because it is invalid");
                end
            end
        end
    end
end

function DAMN.Distribution:addVehicleToZones(fullVehicleId, zonesAndChances)
    if VehicleZoneDistribution
    then
        for zone, chance in pairs(zonesAndChances)
        do
            if VehicleZoneDistribution[zone] and VehicleZoneDistribution[zone]["vehicles"]
            then
                VehicleZoneDistribution[zone]["vehicles"][fullVehicleId] = {
                    index = -1,
                    spawnChance = chance,
                };
            else
                DAMN:log("Skipping vehicle distro zone [" .. tostring(zone) .. "] because it is invalid");
            end
        end
    end
end