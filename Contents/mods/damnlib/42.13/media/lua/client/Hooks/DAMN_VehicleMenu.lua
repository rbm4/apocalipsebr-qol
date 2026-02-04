--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "Vehicles/ISUI/ISVehicleMenu";

DAMN = DAMN or {};
DAMN.VehicleMenu = DAMN.VehicleMenu or {};

-- add "open / close window" function where no door is present

function DAMN.VehicleMenu:addWindowOpenCloseSlice(radialMenu, playerObj, vehicle)
    local seat = vehicle:getSeat(playerObj);

    if seat
    then
        seat = tostring(seat); -- easier to compare because the game fetches the index as string

        DAMN:eachPart(vehicle, function(part)
            local customVars = part:getTable("CustomVariables");

            if customVars and customVars["seatIndex"] and customVars["seatIndex"] == seat
            then
                local window = part:getWindow();

                if window
                then
                    if window:isOpenable() and not window:isDestroyed()
                    then
                        if window:isOpen()
                        then
                            radialMenu:addSlice(getText("ContextMenu_Close_window"), getTexture("media/ui/vehicles/vehicle_windowCLOSED.png"), ISVehiclePartMenu.onOpenCloseWindow, playerObj, part, false);
                        else
                            radialMenu:addSlice(getText("ContextMenu_Open_window"), getTexture("media/ui/vehicles/vehicle_windowOPEN.png"), ISVehiclePartMenu.onOpenCloseWindow, playerObj, part, true);
                        end
                    end

                    return true;
                end
            end
        end);
    end
end

-- conditional slice registration

DAMN.VehicleMenu["conditionalSlices"] = {};

function DAMN.VehicleMenu:registerConditionalSlice(handler, identifier)
    --[[
        DAMN.VehicleMenu:registerConditionalSlice(function(radialMenu, playerObj, vehicle, vehicleScriptName)
            radialMenu:addSlice("Slice title", getTexture("media/some.png"), function()
                -- something to do when slice is activated
            end);
        end, "custom id or empty");
    ]]--
    DAMN.VehicleMenu["conditionalSlices"][identifier or getRandomUUID()] = handler;
end

function DAMN.VehicleMenu:processConditionalSlices(radialMenu, playerObj, vehicle, vehicleScriptName)
    for id, handler in pairs(DAMN.VehicleMenu["conditionalSlices"])
    do
        handler(radialMenu, playerObj, vehicle, vehicleScriptName);
    end
end

-- handlers

function DAMN.VehicleMenu:onShowRadialMenu(radialMenu, playerObj, vehicle)
    if radialMenu
    then
        local vehicleScriptName = vehicle:getScript():getFullName();

        DAMN.VehicleMenu:addWindowOpenCloseSlice(radialMenu, playerObj, vehicle);
        DAMN.VehicleMenu:processConditionalSlices(radialMenu, playerObj, vehicle, vehicleScriptName);
    end
end

-- hooks

local orgShowRadialMenu = ISVehicleMenu["showRadialMenu"];

ISVehicleMenu["showRadialMenu"] = function(playerObj)
    orgShowRadialMenu(playerObj);

    local vehicle = playerObj and playerObj:getVehicle();

    if vehicle
    then
        DAMN.VehicleMenu:onShowRadialMenu(getPlayerRadialMenu(playerObj:getPlayerNum()), playerObj, vehicle);
    end
end