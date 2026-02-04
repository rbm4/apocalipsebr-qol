--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "DAMN_Armor_Shared";

DAMN = DAMN or {};
DAMN.Armor = DAMN.Armor or {};

DAMN.Armor["tireRFSCondition"] = 25;
DAMN.Armor["tireCTISPressure"] = 35;

DAMN.Armor["partUpdateBuffer"] = {};
DAMN.Armor["lastPartUpdate"] = 0;
DAMN.Armor["partUpdateInterval"] = 1000;

-- helpers

function DAMN.Armor:updateEventRequired()
    return DAMN.Armor:hasMagicTires() or DAMN["vehicleHasAirBrake"] or DAMN.Armor["byVehicleScript"][DAMN["currentVehicleScript"]];
end

function DAMN.Armor:hasMagicTires()
    return DAMN["vehicleHasRFS"] or DAMN["vehicleHasCTIS"];
end

function DAMN.Armor:updateMagicTires(vehicle)
    for i, tirePart in ipairs ({
        "TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight"
    })
    do
        local part = vehicle:getPartById(tirePart);

        if part and DAMN["vehicleHasRFS"]
        then
            if part:getCondition() < DAMN.Armor["tireRFSCondition"]
            then
                DAMN.Armor:setPartCondition(part, DAMN.Armor["tireRFSCondition"]);
            end

            if DAMN["vehicleHasCTIS"] and part:getContainerContentAmount() < DAMN.Armor["tireCTISPressure"]
            then
                DAMN.Parts:setContainerAmount(part, DAMN.Armor["tireCTISPressure"]);
            end
        end
    end
end

function DAMN.Armor:runArmorCode(player, vehicle)
    if DAMN["armorEventDebug"] and not DAMN["onPlayerUpdateReported"]
    then
        DAMN:log("OnPlayerUpdate: armor code found, executing");

        DAMN["onPlayerUpdateReported"] = true;
    end

    DAMN.Armor["byVehicleScript"][DAMN["currentVehicleScript"]](player, vehicle);
end

function DAMN.Armor:setPartCondition(part, condition)
    if DAMN["armorEventDebug"]
    then
        DAMN:log("DAMN.Armor:setPartCondition(" .. tostring(part:getId()) .. ", " .. tostring(condition) .. ")");
    end

    part:setCondition(condition);

    DAMN.Armor["partUpdateBuffer"][part:getId()] = condition;
end

function DAMN.Armor:flushPartsBuffer(vehicle, currentTime, forceUpdate)
    DAMN.Armor["lastPartUpdate"] = currentTime or Calendar.getInstance():getTimeInMillis();

    if DAMN:arrayIsEmpty(DAMN.Armor["partUpdateBuffer"]) and not forceUpdate
    then
        return false;
    end

    if DAMN["armorEventDebug"]
    then
        DAMN:log("DAMN.Armor:flushPartsBuffer(" .. tostring(vehicle:getScript():getFullName()) .. ", " .. tostring(currentTime) .. ", " .. tostring(forceUpdate) .. ")");
        DAMN:logArray(DAMN.Armor["partUpdateBuffer"]);
    end

    DAMN:sendLibCommand("updatePartConditions", {
        conditions = DAMN.Armor["partUpdateBuffer"],
    }, vehicle);

    DAMN.Armor["partUpdateBuffer"] = {};
end