--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

local function syncAppliesToPart(part, vehicle)
    local partId = part:getId();

    return partId ~= "TrunkDoor" and partId ~= "EngineDoor" and DAMN:vehicleIsManaged(vehicle:getScript():getFullName());
end

for action, openParam in pairs({
    ISOpenVehicleDoor = true,
    ISCloseVehicleDoor = false,
})
do
    require("Vehicles/TimedActions/" .. action);

    local vanillaStart = _G[action]["start"];
    local vanillaPerform = _G[action]["perform"];
    local vanillaStop = _G[action]["stop"];

    _G[action]["start"] = function(self)
        vanillaStart(self);

        if syncAppliesToPart(self["part"], self["vehicle"])
        then
            if isServer()
            then
                DAMN.Commands.syncPartAnimation(self["character"], {
                    vehicle = self["vehicle"],
                    part = self["part"],
                    open = openParam,
                });
            else
                sendClientCommand(self["character"], "that_damn_library", "syncPartAnimation", {
                    vehicle = self["vehicle"]:getId(),
                    part = self["part"]:getId(),
                    animation = openParam
                        and "Open"
                        or "Close",
                });
            end
        end
    end

    _G[action]["stop"] = function(self)
        if syncAppliesToPart(self["part"], self["vehicle"])
        then
            local vehicleId = self["vehicle"]:getId();
            local partId = self["part"]:getId();

            vanillaStop(self);

            if not isServer()
            then
                sendClientCommand(self["character"], "vehicle", "setDoorOpen", {
                    vehicle = vehicleId,
                    part = partId,
                    open = not openParam,
                });
            end
        else
            vanillaStop(self);
        end
    end

    _G[action]["perform"] = function(self)
        if syncAppliesToPart(self["part"], self["vehicle"])
        then
            local vehicle = self["vehicle"];
            local part = self["part"];

            vanillaPerform(self);

            if isServer()
            then
                part:getDoor():setOpen(openParam);
                vehicle:transmitPartDoor(part);
            else
                sendClientCommand(self["character"], "vehicle", "setDoorOpen", {
                    vehicle = vehicle:getId(),
                    part = part:getId(),
                    open = openParam,
                });
            end
        else
            vanillaPerform(self);
        end
    end
end