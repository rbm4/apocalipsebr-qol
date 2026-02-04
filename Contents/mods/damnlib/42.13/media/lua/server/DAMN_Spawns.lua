--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};
DAMN.Spawns = DAMN.Spawns or {};

function DAMN.Spawns:add(fullScriptName, x, y, options)
    if DAMN["spawnerDebug"]
    then
        DAMN:log("DAMN.Spawns:add(...)");
    end

    if not isClient()
    then
        return DAMN.Spawns:addInternal(fullScriptName, x, y, options);
    end

    if DAMN["spawnerDebug"]
    then
        DAMN:log(" -> skipping because it was called on the client side.");
    end

    return false;
end

if isClient()
then
    return;
end

DAMN.Spawns["byLocation"] = DAMN.Spawns["byLocation"] or {};
DAMN.Spawns["modDataKey"] = "forced_vehicle_spawns";
--DAMN.Spawns["bufferSize"] = DAMN.Spawns["modDataKey"] or 5;

-- EXAMPLES:
--
-- DAMN.Spawns:add("Base.82oshkoshM911", 8145, 11644, {
--     direction = IsoDirections.E,
--     chance = 80,
--     skinIndex = 3
-- });
-- DAMN.Spawns:add("Base.82oshkoshM911", 8145, 11644, {
--     skinIndex = 3
-- });
-- DAMN.Spawns:add("Base.82oshkoshM911", 8145, 11644, {
--     direction = IsoDirections.E,
-- });
-- DAMN.Spawns:add("Base.82oshkoshM911", 8145, 11644, {
--     direction = IsoDirections.E,
--     sandboxVar = "AllowBushmasterSpawns",
-- });
-- DAMN.Spawns:add("Base.82oshkoshM911", 8145, 11644, {
--     direction = IsoDirections.E,
--     modBlacklist = {
--         "clearcove", "CoyoteCountyAraxas",
--     },
-- });
-- DAMN.Spawns:add("Base.78amgeneralM49A2C", 8145, 11644, {
--     sandboxVar = "AllowM49A2CSpawns",
--     modWhitelist = {
--         "tsarslib",
--     },
-- });
-- DAMN.Spawns:add("Base.78amgeneralM49A2C", 8145, 11644, {
--     mapBlacklist = {
--         "Blackwood",
--     },
--     modWhitelist = {
--         "tsarslib",
--     },
--     skinIndex = 1,
-- });
-- DAMN.Spawns:add("Base.82oshkoshM911", 8145, 11644);

-- adds a spawn at a precise location. the x and y are used as unique identifiers. make sure you used the right coords so you do not have to adjust later on. #
-- all options besides vehicle script name, x and y can be mixed and mashed as you like.
-- required arguments:
--     fullScriptName is the namespaced vehicle script name
--     x and y are the location of the center of the vehicle in its correct alignment
-- optional arguments in table "options":
--     direction should be N,S,W,E and the permutations of them to align it better with the world. if none given, south is assumed. see also: https://zomboid-javadoc.com/41.78/zombie/iso/IsoDirections.html
--     chance is optional and expects an integer. if you do not want a chance roll, 100(%) is assumed
--     skinIndex is optional and will randomize if omitted. if you choose one, remember they start at 0, not 1
--     sandboxVar is optional and will search for a sandbox var of that name in the DAMN namespace
--     modBlacklist allows to add an array / a table of mod ids which will, when ANY of them are loaded, prevent the spawn
--     modWhitelist allows to add an array / a table of mod ids which are treated as dependencies. if any of the named mods is NOT loaded the spawn is prevented.
--     needsVanillaMap allows you to check for vanilla map presence. it is assumed to be true by default. change this if you are spawning for standalone maps!
--     mapBlacklist allows to add an array / a table of map ids which will, when ANY of them are loaded, prevent the spawn
--     mapWhitelist allows to add an array / a table of map ids which are treated as dependencies. if any of the named maps is NOT loaded the spawn is prevented.
-- if multiple calls of this method at the same xy coords are done, the latest one wins

function DAMN.Spawns:addInternal(fullScriptName, x, y, options)
    if getScriptManager():getVehicle(fullScriptName)
    then
        if x and y and x > 0 and y > 0
        then
            local xy = tostring(x) .. "_" .. tostring(y);

            options = options or {};

            DAMN.Spawns["byLocation"][xy] = {
                mdKey = xy,
                script = fullScriptName,
                direction = options["direction"] or IsoDirections.S,
                chance = options["chance"] or 100,
                skinIndex = options["skinIndex"] or nil,
                sandboxVar = options["sandboxVar"] or nil,
                modBlacklist = options["modBlacklist"] or {},
                modWhitelist = options["modWhitelist"] or {},
                mapBlacklist = options["mapBlacklist"] or {},
                mapWhitelist = options["mapWhitelist"] or {},
            };

            if options["needsVanillaMap"] ~= false
            then
                table.insert(DAMN.Spawns["byLocation"][xy]["mapWhitelist"], "Muldraugh, KY");
            end

            if DAMN["spawnerDebug"]
            then
                DAMN:log(" -> adding [" .. tostring(fullScriptName) .. "] at [" .. tostring(x) .. "," .. tostring(y) .. "]");
                DAMN:logArray(DAMN.Spawns["byLocation"][xy]);
            end
        elseif DAMN["spawnerDebug"]
        then
            DAMN:log(" - invalid location [" .. tostring(x) .. "," .. tostring(y) .. "]: skipping");
        end
    elseif DAMN["spawnerDebug"]
    then
        DAMN:log(" - vehicle script [" .. tostring(fullScriptName) .. "] unavailable: skipping");
    end
end

function DAMN.Spawns:checkSquare(square)
    local squareConfig = DAMN.Spawns["byLocation"][tostring(square:getX()) .. "_" .. tostring(square:getY())];

    if squareConfig
    then
        if DAMN.Spawns:checkIfDone(squareConfig)
        then
            if DAMN["spawnerDebug"]
            then
                DAMN:log("DAMN.Spawns:checkIfDone(...) -> vehicle spawn was already processed");
            end

            return false;
        end

        if DAMN.Spawns:checkIfAllowed(squareConfig)
        then
            local roll = ZombRandBetween(1, 100);

            if DAMN["spawnerDebug"]
            then
                DAMN:log("DAMN.Spawns:checkIfAllowed(...) -> rolling for force spawn: [" .. tostring(roll) .. "] vs. [" .. tostring(squareConfig["chance"]) .. "] on square [" .. tostring(squareConfig["mdKey"] .. "]"));
            end

            if roll <= squareConfig["chance"]
            then
                if not DAMN.Spawns:checkIfBlocked(square)
                then
                    if DAMN["spawnerDebug"]
                    then
                        DAMN:log(" -> force spawned vehicle [" .. squareConfig["script"] .. "] at [" .. squareConfig["mdKey"] .."]");
                    end

                    addVehicleDebug(squareConfig["script"], squareConfig["direction"], squareConfig["skinIndex"], square);
                elseif DAMN["spawnerDebug"]
                then
                    DAMN:log(" -> square at [" .. squareConfig["mdKey"] .. "] is blocked. will retry later");

                    return false;
                end
            elseif DAMN["spawnerDebug"]
            then
                DAMN:log(" -> not force spawning vehicle [" .. squareConfig["script"] .. "] at [" .. squareConfig["mdKey"] .. "] because of bad rng");
            end

            DAMN.Spawns:remember(squareConfig);
        elseif DAMN["spawnerDebug"]
        then
            DAMN:log(" -> vehicle is not allowed to spawn");
        end
    end

    return true;
end

function DAMN.Spawns:remember(squareConfig)
    ModData.getOrCreate(DAMN.Spawns["modDataKey"])[squareConfig["mdKey"]] = Calendar.getInstance():getTimeInMillis();
    ModData.transmit(DAMN.Spawns["modDataKey"]);
end

-- checks

function DAMN.Spawns:checkIfDone(squareConfig)
    if DAMN["spawnerDebug"]
    then
        DAMN:log("DAMN.Spawns:checkIfDone(...): checking if spawn was already done");
    end

    return ModData.getOrCreate(DAMN.Spawns["modDataKey"])[squareConfig["mdKey"]];
end

function DAMN.Spawns:checkIfAllowed(squareConfig)
    DAMN:log("DAMN.Spawns:checkIfAllowed(...)");

    if squareConfig["sandboxVar"] and not SandboxVars["DAMN"][squareConfig["sandboxVar"]]
    then
        if DAMN["spawnerDebug"]
        then
            DAMN:log(" -> spawning this vehicle is disabled in sandbox options: " .. tostring(squareConfig["sandboxVar"]));
        end

        return false;
    end

    if #squareConfig["modBlacklist"] > 0 or #squareConfig["modWhitelist"] > 0
    then
        local modList = getActivatedMods();

        if #squareConfig["modBlacklist"]
        then
            if DAMN["spawnerDebug"]
            then
                DAMN:log(" - checking mod blacklist");
            end

            local failed = {};

            for i, modId in ipairs(squareConfig["modBlacklist"])
            do
                if DAMN["spawnerDebug"]
                then
                    DAMN:log("    - looking for [" .. tostring(modId) .."]");
                end

                if modList:contains(modId)
                then
                    table.insert(failed, modId);
                end
            end

            if #failed > 0
            then
                if DAMN["spawnerDebug"]
                then
                    DAMN:log(" -> mod blacklist checks failed:");
                    DAMN:printList(failed, "    - mod [%s] prevents this spawn");
                end

                return false;
            elseif DAMN["spawnerDebug"]
            then
                DAMN:log(" -> mod blacklist checks passed");
            end
        end

        if #squareConfig["modWhitelist"] > 0
        then
            if DAMN["spawnerDebug"]
            then
                DAMN:log(" - checking mod whitelist");
            end

            local failed = {};

            for i, modId in ipairs(squareConfig["modWhitelist"])
            do
                if DAMN["spawnerDebug"]
                then
                    DAMN:log("    - looking for [" .. tostring(modId) .."]");
                end

                if not modList:contains(modId)
                then
                    table.insert(failed, modId);
                end
            end

            if #failed > 0
            then
                if DAMN["spawnerDebug"]
                then
                    DAMN:log(" -> mod whitelist checks failed:");
                    DAMN:printList(failed, "    - mod [%s] not found");
                end

                return false;
            elseif DAMN["spawnerDebug"]
            then
                DAMN:log(" -> mod whitelist checks passed");
            end
        end
    end

    if #squareConfig["mapBlacklist"] > 0 or #squareConfig["mapWhitelist"] > 0
    then
        local maps = string.split(getServerOptions():getOptionByName("Map"):getValue(), ";") or {};

        if DAMN["spawnerDebug"]
        then
            DAMN:log(" - loaded maps:");
        end

        if #squareConfig["mapBlacklist"] > 0
        then
            if DAMN["spawnerDebug"]
            then
                DAMN:log(" - checking map blacklist");
            end

            local failed = {};

            for i, map in ipairs(maps)
            do
                if DAMN["spawnerDebug"]
                then
                    DAMN:log("    - checking if loaded map [" .. tostring(map) .."] is blacklisted");
                end

                if DAMN:itemIsInArray(squareConfig["mapBlacklist"], map)
                then
                    table.insert(failed, map);
                end
            end

            if #failed > 0
            then
                if DAMN["spawnerDebug"]
                then
                    DAMN:log(" -> map blacklist checks failed:");
                    DAMN:printList(failed, "    - map [%s] prevents this spawn");
                end

                return false;
            elseif DAMN["spawnerDebug"]
            then
                DAMN:log(" -> map blacklist checks passed");
            end
        end

        if #squareConfig["mapWhitelist"] > 0
        then
            if DAMN["spawnerDebug"]
            then
                DAMN:log(" - checking map whitelist");
            end

            local failed = {};

            for i, map in ipairs(squareConfig["mapWhitelist"])
            do
                if DAMN["spawnerDebug"]
                then
                    DAMN:log("    - checking if map [" .. tostring(map) .."] is loaded");
                end

                if not DAMN:itemIsInArray(maps, map)
                then
                    table.insert(failed, map);
                end
            end

            if #failed > 0
            then
                if DAMN["spawnerDebug"]
                then
                    DAMN:log(" -> map whitelist checks failed:");
                    DAMN:printList(failed, "    - required map [%s] not found");
                end

                return false;
            elseif DAMN["spawnerDebug"]
            then
                DAMN:log(" -> map whitelist checks passed");
            end
        end
    end

    if DAMN["spawnerDebug"]
    then
        DAMN:log(" -> vehicle [" .. tostring(squareConfig["script"]) .. "] is allowed to spawn!");
    end

    return true;
end

function DAMN.Spawns:checkIfBlocked(square)
    if square:isVehicleIntersecting()
    then
        if DAMN["spawnerDebug"]
        then
            DAMN:log("DAMN.Spawns:checkIfBlocked(...) -> vehicle intersecting");
        end

        return true;
    end

    --local vehicles = square:getCell():getVehicles();

    --DAMN:log("[DAMN_SPAWN] " .. tostring(vehicles:size()) .. " VEHICLES IN THE CELL");

    --for i = 0, vehicles:size() - 1
    --do
        --local vehicle = vehicles:get(i);

        --DAMN:log("[DAMN_SPAWN]  - CHECKING IF VEHICLE " .. tostring(vehicle) .. " IS TOO CLOSE (" .. tostring(vehicle:getSquare():DistToProper(square)) .. ")");

        --if vehicle and vehicle:getSquare():DistToProper(square) < DAMN.Spawns["bufferSize"]
        --then
            --return true;
        --end
    --end

    return false;
end

-- events

Events.OnInitGlobalModData.Add(function() -- need global moddata to remember spawns
    Events.LoadGridsquare.Add(function(square)
        DAMN.Spawns:checkSquare(square);
    end);
end)