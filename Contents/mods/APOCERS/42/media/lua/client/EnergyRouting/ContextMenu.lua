require "ISUI/ISToolTip"
require "ISUI/ISWorldObjectContextMenu"
require "ISUI/ISInventoryPane"
require "BuildingObjects/ISPlace3DItemCursor"
require "Entity/ISEntityUI"
require "EnergyRouting/Init"
require "EnergyRouting/RepairTimedActions"

EnergyRouting = EnergyRouting or {}

local STRINGS = {
    repair_option = { en = "Repair energy producer", es = "Reparar productor de energia" },
    place_hydro_water = { en = "Place hydraulic turbine", es = "Colocar turbina hidraulica" },
    open_craft_recipe = { en = "Open crafting recipe", es = "Abrir receta de fabricacion" },
    req_skill = { en = "Requires Electricity level 6.", es = "Requiere Electricidad nivel 6." },
    req_screwdriver = { en = "Missing: Screwdriver", es = "Falta: Destornillador" },
    req_pliers = { en = "Missing: Pliers", es = "Falta: Alicates" },
    req_wire = { en = "Missing: Electric Wire x2", es = "Falta: Cable electrico x2" },
    req_wire_wind = { en = "Missing: Electric Wire x4", es = "Falta: Cable electrico x4" },
    req_electronics = { en = "Missing: Electronics Scrap x6", es = "Falta: Chatarra electronica x6" },
    req_wind_motor = { en = "Missing: Wind Turbine Motor x2", es = "Falta: Motor de aerogenerador x2" },
    req_spares = { en = "Missing: Solar Panel Individual x4", es = "Falta: Panel Solar individual x4" },
    need_screwdriver = { en = "Needs: Screwdriver", es = "Necesita: Destornillador" },
    need_pipe_wrench = { en = "Needs: Pipe Wrench", es = "Necesita: Llave para tubos" },
    need_hydro_helice = { en = "Needs: Turbine Helice x1", es = "Necesita: Turbine Helice x1" },
    need_wire_hydro = { en = "Needs: Electric Wire x2", es = "Necesita: Cable electrico x2" },
    need_electronics_hydro = { en = "Needs: Electronics Scrap x4", es = "Necesita: Chatarra electronica x4" },
}

local REPAIR_WIRE_TYPES = { "Base.ElectricWire", "ElectricWire" }
local REPAIR_SPARE_TYPES = { "EnergyRouting.SolarPanel_Individual", "SolarPanel_Individual" }
local REPAIR_ELECTRONICS_TYPES = { "Base.ElectronicsScrap", "ElectronicsScrap" }
local REPAIR_WIND_MOTOR_TYPES = { "EnergyRouting.WindTurbineMotor", "WindTurbineMotor" }
local REPAIR_HYDRO_HELICE_TYPES = { "EnergyRouting.TurbineHelice", "TurbineHelice" }
local HYDRO_TURBINE_ITEM_TYPES = { "EnergyRouting.TurbinaHidraulica", "TurbinaHidraulica" }
local TOOL_SCREWDRIVER_TYPES = { "Base.Screwdriver", "Screwdriver" }
local TOOL_PLIERS_TYPES = { "Base.Pliers", "Pliers" }
local TOOL_PIPE_WRENCH_TYPES = { "Base.PipeWrench", "PipeWrench" }
local ITEM_CRAFT_RECIPE_TYPES = {
    ["EnergyRouting.EnergyController"] = "CraftEnergyController",
    ["EnergyRouting.BatteryTank"] = "CraftBatteryTank",
    ["EnergyRouting.WindBattery"] = "CraftWindBattery",
    ["EnergyRouting.SolarPanel"] = "CraftSolarPanel",
    ["EnergyRouting.SolarPanelHorizontal"] = "CraftSolarPanelHorizontal",
    ["EnergyRouting.Aerogenerador"] = "CraftAerogenerador",
    ["EnergyRouting.TurbinaHidraulica"] = "CraftTurbinaHidraulica",
    ["EnergyController"] = "CraftEnergyController",
    ["BatteryTank"] = "CraftBatteryTank",
    ["WindBattery"] = "CraftWindBattery",
    ["SolarPanel"] = "CraftSolarPanel",
    ["SolarPanelHorizontal"] = "CraftSolarPanelHorizontal",
    ["Aerogenerador"] = "CraftAerogenerador",
    ["TurbinaHidraulica"] = "CraftTurbinaHidraulica",
}
local getProducerDegradation

local function getLang()
    local core = getCore and getCore() or nil
    local lang = core and core.getOptionLanguage and core:getOptionLanguage() or nil
    if (not lang or tostring(lang) == "") and core and core.getOptionLanguageName then
        lang = core:getOptionLanguageName()
    end
    if not lang or tostring(lang) == "" then
        local tm = getTextManager and getTextManager() or nil
        local cl = tm and tm.getCurrentLanguage and tm:getCurrentLanguage() or nil
        if cl and cl.name then
            local ok, value = pcall(cl.name, cl)
            if ok and value then
                lang = value
            end
        end
        if (not lang or tostring(lang) == "") and cl and cl.toString then
            local ok, value = pcall(cl.toString, cl)
            if ok and value then
                lang = value
            end
        end
    end
    lang = type(lang) == "string" and string.lower(lang) or "en"
    if string.find(lang, "es", 1, true)
        or string.find(lang, "spa", 1, true)
        or string.find(lang, "span", 1, true) then
        return "es"
    end
    return "en"
end

local function rt(key)
    local entry = STRINGS[key]
    if not entry then
        return key
    end
    local lang = getLang()
    return entry[lang] or entry.en or key
end

local function getObjectModData(obj)
    if not obj then
        return nil
    end
    local item = (obj.getItem and obj:getItem()) or (obj.getInventoryItem and obj:getInventoryItem()) or nil
    if item and item.getModData then
        return item:getModData()
    end
    return obj.getModData and obj:getModData() or nil
end

local function getWorldItem(obj)
    if not obj then
        return nil
    end
    return (obj.getItem and obj:getItem()) or (obj.getInventoryItem and obj:getInventoryItem()) or nil
end

local function getItemFullType(item)
    if not item then
        return nil
    end
    if item.getFullType then
        return item:getFullType()
    end
    if item.getType then
        return item:getType()
    end
    return nil
end

local function getActualInventoryItems(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then
        local actualItems = ISInventoryPane.getActualItems(items)
        if actualItems and #actualItems > 0 then
            return actualItems
        end
    end

    local resolved = {}
    if type(items) ~= "table" then
        return resolved
    end

    for _, entry in ipairs(items) do
        if instanceof(entry, "InventoryItem") then
            table.insert(resolved, entry)
        elseif entry and type(entry.items) == "table" then
            for _, item in ipairs(entry.items) do
                if instanceof(item, "InventoryItem") then
                    table.insert(resolved, item)
                end
            end
        end
    end

    return resolved
end

local function getERSCraftRecipeForItem(item)
    if not item or not getScriptManager then
        return nil
    end

    local fullType = getItemFullType(item)
    local shortType = item.getType and item:getType() or nil
    local recipeId = ITEM_CRAFT_RECIPE_TYPES[fullType] or ITEM_CRAFT_RECIPE_TYPES[shortType]
    if not recipeId then
        return nil
    end

    return getScriptManager():getCraftRecipe(recipeId)
end

local function getCraftRecipeDisplayName(recipe)
    if not recipe then
        return nil
    end

    local recipeName = recipe.getName and recipe:getName() or nil
    if recipeName and getRecipeDisplayName then
        local ok, displayName = pcall(getRecipeDisplayName, recipeName)
        if ok and type(displayName) == "string" and displayName ~= "" then
            return displayName
        end
    end

    local translationName = recipe.getTranslationName and recipe:getTranslationName() or nil
    if translationName then
        local displayName = getText(translationName)
        if displayName and displayName ~= "" then
            return displayName
        end
    end

    return recipeName
end

local function isSolarPanelLocal(obj)
    if not obj then
        return false
    end
    if EnergyRouting.Client and EnergyRouting.Client.isSolarPanelObject then
        return EnergyRouting.Client.isSolarPanelObject(obj)
    end
    local item = getWorldItem(obj)
    local fullType = getItemFullType(item)
    return fullType == "EnergyRouting.SolarPanel"
        or fullType == "SolarPanel"
        or fullType == "EnergyRouting.SolarPanelHorizontal"
        or fullType == "SolarPanelHorizontal"
end

local function isWindTurbineLocal(obj)
    if not obj then
        return false
    end
    if EnergyRouting.Client and EnergyRouting.Client.isWindTurbineObject then
        return EnergyRouting.Client.isWindTurbineObject(obj)
    end
    local item = getWorldItem(obj)
    local fullType = getItemFullType(item)
    return fullType == "EnergyRouting.Aerogenerador" or fullType == "Aerogenerador"
end

local function isHydroTurbineLocal(obj)
    if not obj then
        return false
    end
    if EnergyRouting.Client and EnergyRouting.Client.isHydroTurbineObject then
        return EnergyRouting.Client.isHydroTurbineObject(obj)
    end
    local md = getObjectModData(obj)
    if md and md.hydro then
        return true
    end
    local item = getWorldItem(obj)
    local fullType = getItemFullType(item)
    return fullType == "EnergyRouting.TurbinaHidraulica" or fullType == "TurbinaHidraulica"
end

EnergyRouting.isSolarPanel = isSolarPanelLocal
EnergyRouting.isWindTurbine = isWindTurbineLocal
EnergyRouting.isHydroTurbine = isHydroTurbineLocal

local function getTypeCount(inventory, itemType)
    if not inventory or not itemType then
        return 0
    end
    if inventory.getCountTypeRecurse then
        return tonumber(inventory:getCountTypeRecurse(itemType)) or 0
    end
    if inventory.getCountType then
        return tonumber(inventory:getCountType(itemType)) or 0
    end
    if inventory.getNumberOfItem then
        return tonumber(inventory:getNumberOfItem(itemType, true)) or 0
    end
    return 0
end

local function containsAny(inventory, itemTypes)
    if not inventory or not itemTypes then
        return false
    end
    local lookup = {}
    for _, itemType in ipairs(itemTypes) do
        lookup[itemType] = true
    end

    local function scanContainer(container)
        if not container or not container.getItems then
            return false
        end
        local items = container:getItems()
        if not items then
            return false
        end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item then
                local fullType = item.getFullType and item:getFullType() or nil
                if fullType and lookup[fullType] then
                    return true
                end
                local shortType = item.getType and item:getType() or nil
                if shortType and lookup[shortType] then
                    return true
                end
                local sub = item.getInventory and item:getInventory() or nil
                if sub and scanContainer(sub) then
                    return true
                end
            end
        end
        return false
    end

    if scanContainer(inventory) then
        return true
    end

    for _, itemType in ipairs(itemTypes) do
        if getTypeCount(inventory, itemType) > 0 then
            return true
        end
    end
    return false
end

local function countAny(inventory, itemTypes)
    if not inventory or not itemTypes then
        return 0
    end
    local lookup = {}
    for _, itemType in ipairs(itemTypes) do
        lookup[itemType] = true
    end
    local recursiveCount = 0
    local function scanContainer(container)
        if not container or not container.getItems then
            return
        end
        local items = container:getItems()
        if not items then
            return
        end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item then
                local fullType = item.getFullType and item:getFullType() or nil
                local shortType = item.getType and item:getType() or nil
                if (fullType and lookup[fullType]) or (shortType and lookup[shortType]) then
                    recursiveCount = recursiveCount + 1
                end
                local sub = item.getInventory and item:getInventory() or nil
                if sub then
                    scanContainer(sub)
                end
            end
        end
    end
    scanContainer(inventory)

    local count = 0
    for _, itemType in ipairs(itemTypes) do
        local value = getTypeCount(inventory, itemType)
        if value > count then
            count = value
        end
    end
    if recursiveCount > count then
        return recursiveCount
    end
    return count
end

local function collectItemsByTypes(inventory, itemTypes)
    local list = {}
    if not inventory or not itemTypes then
        return list
    end

    local seen = {}
    for _, itemType in ipairs(itemTypes) do
        local items = inventory.getAllTypeRecurse and inventory:getAllTypeRecurse(itemType) or nil
        if items then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item and not seen[item] then
                    seen[item] = true
                    table.insert(list, item)
                end
            end
        end
    end
    return list
end

local function getRepairValidation(playerObj, obj)
    if not playerObj or not playerObj.getInventory then
        return false, { rt("req_skill") }
    end

    local missing = {}
    local inventory = playerObj:getInventory()

    local isWind = obj and isWindTurbineLocal(obj)
    local isHydro = obj and isHydroTurbineLocal(obj)
    if isHydro then
        if not containsAny(inventory, TOOL_SCREWDRIVER_TYPES) then
            table.insert(missing, rt("req_screwdriver"))
        end
        if not containsAny(inventory, TOOL_PIPE_WRENCH_TYPES) then
            table.insert(missing, rt("req_pipe_wrench"))
        end
        if countAny(inventory, REPAIR_HYDRO_HELICE_TYPES) < 1 then
            table.insert(missing, rt("req_hydro_helice"))
        end
    elseif isWind then
        if playerObj.getPerkLevel and playerObj:getPerkLevel(Perks.Electricity) < 6 then
            table.insert(missing, rt("req_skill"))
        end
        if not containsAny(inventory, TOOL_SCREWDRIVER_TYPES) then
            table.insert(missing, rt("req_screwdriver"))
        end
        if not containsAny(inventory, TOOL_PLIERS_TYPES) then
            table.insert(missing, rt("req_pliers"))
        end
        if countAny(inventory, REPAIR_WIRE_TYPES) < 4 then
            table.insert(missing, rt("req_wire_wind"))
        end
        if countAny(inventory, REPAIR_ELECTRONICS_TYPES) < 6 then
            table.insert(missing, rt("req_electronics"))
        end
        if countAny(inventory, REPAIR_WIND_MOTOR_TYPES) < 2 then
            table.insert(missing, rt("req_wind_motor"))
        end
    else
        if playerObj.getPerkLevel and playerObj:getPerkLevel(Perks.Electricity) < 6 then
            table.insert(missing, rt("req_skill"))
        end
        if not containsAny(inventory, TOOL_SCREWDRIVER_TYPES) then
            table.insert(missing, rt("req_screwdriver"))
        end
        if not containsAny(inventory, TOOL_PLIERS_TYPES) then
            table.insert(missing, rt("req_pliers"))
        end
        if countAny(inventory, REPAIR_WIRE_TYPES) < 2 then
            table.insert(missing, rt("req_wire"))
        end
        if countAny(inventory, REPAIR_SPARE_TYPES) < 4 then
            table.insert(missing, rt("req_spares"))
        end
    end

    return #missing == 0, missing
end

function EnergyRouting.canRepairProducer(playerObj, obj)
    if not playerObj then
        return false
    end
    if obj and not (isSolarPanelLocal(obj) or isWindTurbineLocal(obj) or isHydroTurbineLocal(obj)) then
        return false
    end
    if obj and getProducerDegradation(obj) >= 0.9999 then
        return false
    end
    local valid = getRepairValidation(playerObj, obj)
    return valid == true
end

getProducerDegradation = function(obj)
    local md = getObjectModData(obj)
    if not md then
        return 1.0
    end
    if isHydroTurbineLocal(obj) and md.hydro and md.hydro.condition ~= nil then
        local value = tonumber(md.hydro.condition) or 100
        if value < 0 then value = 0 end
        if value > 100 then value = 100 end
        return value / 100
    end
    local production = md.production
    if production and production.degradation ~= nil then
        local value = tonumber(production.degradation) or 1.0
        if value < 0 then value = 0 end
        if value > 1 then value = 1 end
        return value
    end
    if md.solar and md.solar.degradation ~= nil then
        local value = tonumber(md.solar.degradation) or 1.0
        if value < 0 then value = 0 end
        if value > 1 then value = 1 end
        return value
    end
    if md.wind and md.wind.condition ~= nil then
        local value = tonumber(md.wind.condition) or 1.0
        if value < 0 then value = 0 end
        if value > 1 then value = 1 end
        return value
    end
    return 1.0
end

local function addTooltip(option, missing)
    if not option or not missing or #missing == 0 then
        return
    end
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip.description = "<RGB:1,0.25,0.25>" .. table.concat(missing, " <LINE> ")
    option.notAvailable = true
    option.toolTip = tooltip
end

local function eachWorldObject(worldobjects, fn)
    if not worldobjects or not fn then
        return
    end
    if type(worldobjects) == "table" then
        for _, entry in ipairs(worldobjects) do
            fn(entry)
        end
        return
    end
    if worldobjects.size and worldobjects.get then
        for i = 0, worldobjects:size() - 1 do
            fn(worldobjects:get(i))
        end
    end
end

local function unwrapObject(entry)
    if entry and entry.worldobject then
        return entry.worldobject
    end
    return entry
end

local function addObjectIfValid(seen, list, obj)
    if not obj or seen[obj] then
        return
    end
    seen[obj] = true
    table.insert(list, obj)
end

local function getSquareFromContext(worldobjects)
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.getSquare then
        return ISWorldObjectContextMenu.getSquare(worldobjects)
    end
    if not worldobjects then
        return nil
    end

    local foundSquare = nil
    eachWorldObject(worldobjects, function(entry)
        if foundSquare then
            return
        end
        local obj = unwrapObject(entry)
        if obj and obj.getSquare then
            foundSquare = obj:getSquare()
            return
        end
        if entry and entry.getSquare then
            foundSquare = entry:getSquare()
        end
    end)
    return foundSquare
end

local function getContextCenterSquare(worldobjects, playerObj)
    local square = getSquareFromContext(worldobjects)
    if square then
        return square
    end
    if playerObj and playerObj.getSquare then
        return playerObj:getSquare()
    end
    return nil
end

local function forEachSquareObject(square, fn)
    if not square or not fn then
        return
    end
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            fn(objects:get(i))
        end
    end
    if square.getSpecialObjects then
        local special = square:getSpecialObjects()
        if special then
            for i = 0, special:size() - 1 do
                fn(special:get(i))
            end
        end
    end
    local world = square:getWorldObjects()
    if world then
        for i = 0, world:size() - 1 do
            fn(world:get(i))
        end
    end
end

local function forEachSquareIn2x2(centerSq, fn)
    if not centerSq or not fn then
        return
    end
    local cell = getCell and getCell() or nil
    if not cell then
        return
    end
    local cx = centerSq:getX()
    local cy = centerSq:getY()
    local cz = centerSq:getZ()
    for dx = 0, 1 do
        for dy = 0, 1 do
            local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
            if sq then
                fn(sq)
            end
        end
    end
end

local function getFloorSpriteName(square)
    if not square or not square.getFloor then
        return nil
    end
    local floor = square:getFloor()
    if not floor or not floor.getSprite then
        return nil
    end
    local sprite = floor:getSprite()
    if sprite and sprite.getName then
        return sprite:getName()
    end
    return nil
end

local function isValidHydroWaterSquare(square)
    if EnergyRouting and EnergyRouting.HydroPlacement and EnergyRouting.HydroPlacement.IsValidWaterSquare then
        return EnergyRouting.HydroPlacement.IsValidWaterSquare(square)
    end
    local spriteName = getFloorSpriteName(square)
    if EnergyRouting and EnergyRouting.IsValidHydroSpriteName then
        return EnergyRouting.IsValidHydroSpriteName(spriteName)
    end
    return false
end

local function contextHasValidHydroWater(worldobjects, playerObj)
    local found = false
    eachWorldObject(worldobjects, function(entry)
        if found then
            return
        end
        local obj = unwrapObject(entry)
        local square = obj and obj.getSquare and obj:getSquare() or nil
        if square and isValidHydroWaterSquare(square) then
            found = true
        end
    end)
    if found then
        return true
    end
    local centerSq = getContextCenterSquare(worldobjects, playerObj)
    if not centerSq then
        return false
    end
    if isValidHydroWaterSquare(centerSq) then
        return true
    end
    forEachSquareIn2x2(centerSq, function(sq)
        if not found and isValidHydroWaterSquare(sq) then
            found = true
        end
    end)
    return found
end

local function onPlaceHydroFromWater(hydroItem, playerObj)
    if not hydroItem or not playerObj then
        return
    end
    if playerObj:getVehicle() then
        return
    end
    local cursor = nil
    if EnergyRouting and EnergyRouting.HydroPlacement and EnergyRouting.HydroPlacement.NewCursor then
        cursor = EnergyRouting.HydroPlacement.NewCursor(playerObj, hydroItem)
    end
    if not cursor then
        cursor = ISPlace3DItemCursor:new(playerObj, { hydroItem })
        cursor._energyRoutingHydro = true
    end
    getCell():setDrag(cursor, playerObj:getPlayerNum())
end

local function addHydroPlacementFromWater(playerNum, context, worldobjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then
        return
    end
    if playerObj:getVehicle() then
        return
    end

    if not contextHasValidHydroWater(worldobjects, playerObj) then
        return
    end

    local hydroItems = collectItemsByTypes(playerObj:getInventory(), HYDRO_TURBINE_ITEM_TYPES)
    if #hydroItems == 0 then
        return
    end

    if test then
        return true
    end

    local option = context:addOption(rt("place_hydro_water"), worldobjects, nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    for _, hydroItem in ipairs(hydroItems) do
        local label = hydroItem:getDisplayName() or hydroItem:getName() or "Hydraulic Turbine"
        subMenu:addOption(label, hydroItem, onPlaceHydroFromWater, playerObj)
    end
end

local function collectCandidateObjects(worldobjects, playerObj)
    local list = {}
    local seen = {}
    eachWorldObject(worldobjects, function(entry)
        local obj = unwrapObject(entry)
        addObjectIfValid(seen, list, obj)
    end)

    local centerSq = getContextCenterSquare(worldobjects, playerObj)
    if centerSq then
        forEachSquareObject(centerSq, function(obj)
            addObjectIfValid(seen, list, obj)
        end)
        forEachSquareIn2x2(centerSq, function(sq)
            forEachSquareObject(sq, function(obj)
                addObjectIfValid(seen, list, obj)
            end)
        end)
    end
    return list
end

local function findRepairTarget(worldobjects, playerObj)
    local candidates = collectCandidateObjects(worldobjects, playerObj)
    local hydroFallback = nil
    for _, obj in ipairs(candidates) do
        if isSolarPanelLocal(obj) or isWindTurbineLocal(obj) or isHydroTurbineLocal(obj) then
            local degradation = getProducerDegradation(obj)
            if degradation < 0.9999 then
                return obj, false
            end
            if not hydroFallback and isHydroTurbineLocal(obj) then
                hydroFallback = obj
            end
        end
    end
    if hydroFallback then
        return hydroFallback, true
    end
    return nil, false
end

function EnergyRouting.onRepairProducer(obj, playerObj)
    local player = playerObj
    if type(playerObj) == "number" then
        player = getSpecificPlayer(playerObj)
    end
    if not player or not obj then
        return
    end
    if not EnergyRouting.canRepairProducer(player, obj) then
        return
    end
    if EnergyRouting.RepairTimedActions and EnergyRouting.RepairTimedActions.Queue then
        EnergyRouting.RepairTimedActions.Queue(player, obj, 200)
    end
end

local function onOpenCraftRecipe(playerObj, recipe)
    if not playerObj or not recipe or not ISEntityUI or not ISEntityUI.OpenHandcraftWindow then
        return
    end
    ISEntityUI.OpenHandcraftWindow(playerObj, nil, "*", false, recipe)
end

local function addInventoryCraftRecipeOption(playerNum, context, items)
    if not context then
        return
    end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then
        return
    end

    local actualItems = getActualInventoryItems(items)
    if not actualItems or #actualItems == 0 then
        return
    end

    local firstItem = actualItems[1]
    local firstType = getItemFullType(firstItem)
    if not firstType then
        return
    end

    for i = 2, #actualItems do
        if getItemFullType(actualItems[i]) ~= firstType then
            return
        end
    end

    local recipe = getERSCraftRecipeForItem(firstItem)
    if not recipe then
        return
    end

    local optionText = rt("open_craft_recipe")
    local recipeName = getCraftRecipeDisplayName(recipe)
    if recipeName and recipeName ~= "" then
        optionText = optionText .. ": " .. recipeName
    end

    local option = context:addOption(optionText, playerObj, onOpenCraftRecipe, recipe)
    if option and firstItem.getTexture then
        local texture = firstItem:getTexture()
        if texture then
            option.iconTexture = texture
        end
    end
end

local function addRepairOption(playerNum, context, worldobjects, test)
    if test then
        return true
    end
    if not context then
        return
    end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then
        return
    end

    local target, hydroAtMaxCondition = findRepairTarget(worldobjects, playerObj)
    if not target then
        return
    end

    local option = context:addOption(rt("repair_option"), target, EnergyRouting.onRepairProducer, playerObj)
    local valid, missing = getRepairValidation(playerObj, target)
    local blockedReasons = {}
    local function addUniqueReason(text)
        if not text then
            return
        end
        for _, existing in ipairs(blockedReasons) do
            if existing == text then
                return
            end
        end
        table.insert(blockedReasons, text)
    end
    if hydroAtMaxCondition then
        option.notAvailable = true
    end
    if not valid and missing then
        for _, message in ipairs(missing) do
            addUniqueReason(message)
        end
    end
    if hydroAtMaxCondition and isHydroTurbineLocal(target) then
        addUniqueReason(rt("need_screwdriver"))
        addUniqueReason(rt("need_pipe_wrench"))
        addUniqueReason(rt("need_hydro_helice"))
        addUniqueReason(rt("need_wire_hydro"))
        addUniqueReason(rt("need_electronics_hydro"))
    end
    if #blockedReasons > 0 then
        addTooltip(option, blockedReasons)
    end
end

Events.OnFillWorldObjectContextMenu.Add(addRepairOption)
Events.OnFillWorldObjectContextMenu.Add(addHydroPlacementFromWater)
Events.OnFillInventoryObjectContextMenu.Add(addInventoryCraftRecipeOption)
