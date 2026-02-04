--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "Vehicles/ISUI/ISVehicleMechanics";

DAMN = DAMN or {};
DAMN.MechanicsTooltip = DAMN.MechanicsTooltip or {};

-- registration of additional texts

DAMN.MechanicsTooltip["conditionalDescriptions"] = {};

function DAMN.MechanicsTooltip:registerConditionalDescription(fn, identifier)
    --[[
        -- return a string to append it to the tooltip. identifier is optional but good in case you want to debug or override things so adding one is a good idea.
        DAMN.MechanicsTooltip:registerConditionalDescription(function(vehicle, part, partId, tableName, identifier)
            if tableName == "uninstall" and partId == "F3502Roofrack"
            then
                return " <ORANGE> Remove All Gas Cans and Tent from Roofrack to be able to uninstall this part.";
            end
        end, "roofrack warning F350");
    ]]--

    DAMN.MechanicsTooltip["conditionalDescriptions"][identifier or getRandomUUID()] = fn;
end

function DAMN.MechanicsTooltip:registerUninstallSlotWarning(warningPartId, message, identifier)
    --[[
        DAMN.MechanicsTooltip:registerUninstallSlotWarning("F3502Roofrack", "Remove All Gas Cans and Tent from Roofrack to be able to uninstall this part.", "roofrack warning F350");
        DAMN.MechanicsTooltip:registerUninstallSlotWarning("F3502Roofrack", getText("IGUI_ThisWayShouldBeThePreferredWay"), "roofrack warning F350");
    ]]--

    DAMN.MechanicsTooltip:registerConditionalDescription(function(vehicle, part, partId, tableName, identifier)
        if tableName == "uninstall" and partId == warningPartId
        then
            return " <ORANGE> " .. message;
        end
    end, identifier);
end

function DAMN.MechanicsTooltip:processConditionalDescriptions(vehicle, part, partId, tableName, option)
    local additions = {};

    for identifier, fn in pairs(DAMN.MechanicsTooltip["conditionalDescriptions"])
    do
        local addition = fn(vehicle, part, partId, tableName, identifier);

        if addition and type(addition) == "string"
        then
            table.insert(additions, addition);
        end
    end

    return DAMN.MechanicsTooltip:addLinesToDescription(option, additions, " <LINE> ");
end

-- description tooltip helpers

function DAMN.MechanicsTooltip:addLinesToDescription(option, newLines, glue)
    local lineCount = #newLines;

    if lineCount > 0
    then
        option["toolTip"]["description"] = option["toolTip"]["description"] .. table.concat(newLines, glue or " <LINE> ") .. " <LINE> <RGB:1,1,1> ";
    end

    return lineCount;
end

function DAMN.MechanicsTooltip:addEmptyLineToDescription(option)
    option["toolTip"]["description"] = option["toolTip"]["description"] .. " <LINE> <RGB:1,1,1> ";
end

function DAMN.MechanicsTooltip:addLineToDescription(option, line)
    option["toolTip"]["description"] = option["toolTip"]["description"] .. line .. " <LINE> <RGB:1,1,1> ";
end

-- display part dependencies

function DAMN.MechanicsTooltip:displayPartDependencies(vehicle, part, partId, option, tableName, attrName, goodColor, badColor, headerIfLinesAdded)
    local partTable = part:getTable(tableName);

    if partTable and partTable[attrName] and string.find(partTable["test"], "^DAMN%.")
    then
        local newLines = {};

        for i, depPartId in ipairs(partTable[attrName]:split(";"))
        do
            local depPart = vehicle:getPartById(depPartId);

            table.insert(newLines, " <" .. ((depPart and DAMN.Parts:partIsInstalled(depPart))
                and (goodColor or "GREEN")
                or (badColor or "RED")
            ) .. "> " .. (getTextOrNull("IGUI_VehiclePart" .. depPartId) or depPartId));
        end

        local lineCount = #newLines;

        if headerIfLinesAdded and lineCount > 0
        then
            DAMN.MechanicsTooltip:addLineToDescription(option, " <RGB:1,1,1> " .. getText(headerIfLinesAdded, lineCount));
        end

        return DAMN.MechanicsTooltip:addLinesToDescription(option, newLines, " <LINE> ");
    end

    return 0;
end

function DAMN.MechanicsTooltip:displayUninstallDependencies(vehicle, part, partId, option)
    return DAMN.MechanicsTooltip:displayPartDependencies(vehicle, part, partId, option, "uninstall", "requireUninstalled", "GREEN", "RED", "IGUI_DL_UninstallPartsFirst");
end

function DAMN.MechanicsTooltip:displayInstallDependencies(vehicle, part, partId, option)
    return DAMN.MechanicsTooltip:displayPartDependencies(vehicle, part, partId, option, "install", "requireInstalled", "RED", "GREEN", "IGUI_DL_InstallPartsFirst");
end

-- hooks

local vanillaMechTooltipFn = ISVehicleMechanics["doMenuTooltip"];

ISVehicleMechanics["doMenuTooltip"] = function(self, part, option, tableName, name)
	vanillaMechTooltipFn(self, part, option, tableName, name);

    local vehicle = part:getVehicle();

    if vehicle and DAMN:vehicleIsManaged(vehicle:getScript():getFullName())
    then
        local partId = part:getId();

        if DAMN.MechanicsTooltip:processConditionalDescriptions(vehicle, part, partId, tableName, option) > 0
        then
            DAMN.MechanicsTooltip:addEmptyLineToDescription(option);
        end

        if tableName == "uninstall"
        then
            DAMN.MechanicsTooltip:displayUninstallDependencies(vehicle, part, partId, option);
        elseif tableName == "install"
        then
            DAMN.MechanicsTooltip:displayInstallDependencies(vehicle, part, partId, option);
        end
    end
end

Events.OnGameBoot.Add(function()
    DAMN.MechanicsTooltip:registerConditionalDescription(function(vehicle, part, partId, tableName, identifier)
        if tableName == "install"
        then
            if string.find(partId, "DAMNGasCan")
            then
                return getText("IGUI_DL_GasCanInstallHint");
            elseif partId == "DAMNGenerator"
            then
                return getText("IGUI_DL_GeneratorInstallHint");
            end
        end
    end, "damnlib defaults");
end);