--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};
DAMN.ScriptTools = DAMN.ScriptTools or {};

DAMN.ScriptTools["loadedFiles"] = {};

-- DAMN.ScriptTools:loadScriptInModFolder("BTSE_RestorePod", "dynamic_scripts/pod_card_scrapping.txt");
function DAMN.ScriptTools:loadScriptInModFolder(modId, fileName)
    if DAMN["scriptLoadDebug"]
    then
        DAMN:log(string.format('DAMN.ScriptTools:loadScriptInModFolder("%s", "%s")', modId, fileName));
    end

    DAMN.ScriptTools["loadedFiles"][modId] = DAMN.ScriptTools["loadedFiles"][modId] or {};

    if not string.find(fileName, "media/")
    then
        fileName = "media/" .. fileName;

        if DAMN["scriptLoadDebug"]
        then
            DAMN:log(" - prepended media folder to relative path: " .. fileName);
        end
    end

    if not DAMN.ScriptTools["loadedFiles"][modId][fileName]
    then
        local modInfo = getModInfoByID(modId);

        if modInfo
        then
            DAMN.ScriptTools["loadedFiles"][modId][fileName] = true;

            fileName = modInfo:getDir() .. "/" .. fileName;
            fileName = string.gsub(fileName, "[%/%\\]", getFileSeparator());

            if DAMN["scriptLoadDebug"]
            then
                DAMN:log(" - mod directory: " .. modInfo:getDir());
                DAMN:log(" - loading file: " .. fileName);
            end

            getScriptManager():LoadFile(fileName, true);

            return true;
        end
    elseif DAMN["scriptLoadDebug"]
    then
        DAMN:log(" - mod id [" .. tostring(modId) .. "] / file [" .. tostring(fileName) .. "] already loaded");
    end

    return false;
end

--[[
    -- works with table...
    DAMN.ScriptTools:loadScriptIfModEnabled("damnlib", "dynamic_scripts/appliance_oven.txt", {
        "69VWBangBus",
        "80MANKAT1BoxTruck",
    });
    -- ...or with string.
    DAMN.ScriptTools:loadScriptIfModEnabled("damnlib", "dynamic_scripts/appliance_oven.txt", "69VWBangBus");
]]--
function DAMN.ScriptTools:loadScriptIfModEnabled(scriptModId, fileName, mod)
    local enabledMods = getActivatedMods();

    for i, modId in ipairs(DAMN:tableIfNotTable(mod))
    do
        if enabledMods:contains(modId)
        then
            DAMN.ScriptTools:loadScriptInModFolder(scriptModId, fileName);

            return true;
        end
    end

    return false;
end

-- file name eats file extensions and prepends "Vehicles/" automatically so the pure file name of the thing is enough
-- DAMN.ScriptTools:addSkinToVehicleScript("Base.92amgeneralM998", "Vehicles_92amgeneralM998_Shell_USMCgreen_Burnt.png");
-- DAMN.ScriptTools:addSkinToVehicleScript("Base.92amgeneralM998", "Vehicles_92amgeneralM998_Shell_USMCgreen_Burnt");
function DAMN.ScriptTools:addSkinToVehicleScript(fullVehicleScript, textureFile)
    local vehicleScript = fullVehicleScript and getScriptManager():getVehicle(fullVehicleScript);

    if textureFile
    then
        if DAMN["tweakerDebug"]
        then
            DAMN:log(string.format("DAMN.ScriptTools:addSkinToVehicleScript(%s, %s)", fullVehicleScript, textureFile));
        end

        if vehicleScript
        then
            textureFile = string.gsub(textureFile, "%.%a+$", "");

            if not string.find(textureFile, "Vehicles/")
            then
                textureFile = "Vehicles/" .. textureFile;

                if DAMN["tweakerDebug"]
                then
                    DAMN:log(" - prepended Vehicles folder to relative path: " .. textureFile);
                end
            end

            local scriptName = string.gsub(fullVehicleScript, "^%a+%.", "");

            if DAMN["tweakerDebug"]
            then
                DAMN:log(" - adding skin for script name: " .. tostring(scriptName));
            end

            vehicleScript:Load(scriptName, table.concat({
                "{",
                    "skin {",
                        "texture = ", textureFile, ",",
                    "}",
                "}",
            }, " "));
        elseif DAMN["tweakerDebug"]
        then
            DAMN:log(" - script parameter not given or invalid vehicle script");
        end
    elseif DAMN["tweakerDebug"]
    then
        DAMN:log(" - textureFile parameter is empty");
    end
end