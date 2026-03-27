-- ERS_DEBUG_PRINT_GUARD
local _ERS_RAW_PRINT = (_G and _G.print) or print
local function ersDebugLogsEnabled()
    if EnergyRouting and EnergyRouting.IsDebugEnabled then
        return EnergyRouting.IsDebugEnabled()
    end
    if EnergyRouting and EnergyRouting.GetConfigValue then
        return EnergyRouting.GetConfigValue("DebugLogs") == true
    end
    local vars = SandboxVars and (SandboxVars.EnergyRoutingSystem or SandboxVars.EnergyRouting) or nil
    return vars and vars.DebugLogs == true
end
local function debugPrint(...)
    if ersDebugLogsEnabled() then
        _ERS_RAW_PRINT(...)
    end
end
local print = debugPrint
require "ISUI/ISWorldObjectContextMenu"
require "ISUI/ISToolTip"
require "EnergyRouting/Init"
require "EnergyRouting/HydroPlacement"
require "EnergyNetwork"
require "EnergyRouting/UI"
require "EnergyRouting/TimedActions"
require "EnergyRouting/RepairTimedActions"
require "EnergyRouting/ContextMenu"
require "EnergyRouting/Controller"
require "EnergyRouting/ERS_RangeOverlay"

EnergyRouting.Client = EnergyRouting.Client or {}
local Client = EnergyRouting.Client

Client.stateById = Client.stateById or {}
Client.uiById = Client.uiById or {}
Client.controllerObjById = Client.controllerObjById or {}
Client.controllerLookupMissAt = Client.controllerLookupMissAt or {}
Client._fallbackStateLogById = Client._fallbackStateLogById or {}
Client._fallbackSnapshotLogById = Client._fallbackSnapshotLogById or {}
Client._fallbackMissLogById = Client._fallbackMissLogById or {}
Client._lastSquaresRequestAtById = Client._lastSquaresRequestAtById or {}
Client.LogEnabled = true

local function logClient(message)
    if not Client.LogEnabled then
        return
    end
    print("[EnergyNetwork][Client] " .. tostring(message))
end

local MENU_STRINGS = {
    open_controller = { en = "Open Energy Controller", es = "Abrir controlador de energia" },
    view_solar_panel = { en = "View solar panel", es = "Ver panel solar" },
    view_solar_battery = { en = "View solar battery", es = "Ver bateria solar" },
    view_aerogenerator = { en = "View aerogenerator", es = "Ver aerogenerador" },
    view_hydro_turbine = { en = "View hydraulic turbine", es = "Ver turbina hidraulica" },
    view_wind_battery = { en = "View wind battery", es = "Ver bateria eolica" },
    connect_panel_controller = { en = "Connect solar panel to Energy Controller", es = "Conectar panel solar al controlador de energia" },
    connect_battery_controller = { en = "Connect solar battery to Energy Controller", es = "Conectar bateria solar al controlador de energia" },
    connect_aero_controller = { en = "Connect to Energy Controller", es = "Conectar al controlador de energia" },
    connect_hydro_controller = { en = "Connect hydraulic turbine to Energy Controller", es = "Conectar turbina hidraulica al controlador de energia" },
    connect_wind_battery_controller = { en = "Connect wind battery to Energy Controller", es = "Conectar bateria eolica al controlador de energia" },
    disconnect_from_controller = { en = "Disconnect from controller", es = "Desconectar del controlador" },
    view_energized_cells = { en = "View energized cells", es = "Ver celdas energizadas" },
    hide_energized_cells = { en = "Hide energized cells", es = "Ocultar celdas energizadas" },
    req_elec_2 = { en = "Requires Electricity level 2.", es = "Requiere Electricidad nivel 2." },
    req_cable = { en = "You need an energy transfer cable.", es = "Necesitas un cable de transferencia de energia." },
    energy_controller_label = { en = "Energy Controller", es = "Controlador de energia" },
}

local function getMenuLang()
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

local function mt(key)
    local entry = MENU_STRINGS[key]
    if not entry then
        return key
    end
    local lang = getMenuLang()
    return entry[lang] or entry.en or key
end

local function getPlayerByIndex(playerNum)
    if type(playerNum) == "userdata" then
        return playerNum
    end
    if type(playerNum) == "table" then
        if playerNum.getInventory then
            return playerNum
        end
        if playerNum.player and playerNum.player.getInventory then
            return playerNum.player
        end
        if playerNum.playerObj and playerNum.playerObj.getInventory then
            return playerNum.playerObj
        end
    end
    if playerNum == nil then
        return getSpecificPlayer(0) or (getPlayer and getPlayer() or nil)
    end
    if type(playerNum) == "number" then
        return getSpecificPlayer(playerNum) or getSpecificPlayer(0) or (getPlayer and getPlayer() or nil)
    end
    return getSpecificPlayer(0) or (getPlayer and getPlayer() or nil)
end

local function getWorldObject(obj)
    if obj and obj.worldobject then
        return obj.worldobject
    end
    return obj
end

local function getContextTarget(obj)
    if obj and obj.worldobject then
        return obj.worldobject
    end
    return obj
end

local function getContextItem(obj)
    if not obj then
        return nil
    end
    if obj.getItem then
        return obj:getItem()
    end
    if obj.getInventoryItem then
        return obj:getInventoryItem()
    end
    if obj.item then
        return obj.item
    end
    if obj.items and obj.items[1] then
        return obj.items[1]
    end
    if obj.getFullType then
        return obj
    end
    return nil
end

local function getSpriteName(obj)
    if not obj or not obj.getSprite then
        return nil
    end
    local sprite = obj:getSprite()
    if sprite and sprite.getName then
        return sprite:getName()
    end
    return nil
end

local function getWorldItem(obj)
    return getContextItem(obj)
end

local function getObjectModData(obj)
    if not obj then
        return nil
    end
    local item = getWorldItem(obj)
    if item and item.getModData then
        return item:getModData()
    end
    if obj.getModData then
        return obj:getModData()
    end
    return nil
end

local function hasWorldItemBacking(obj)
    return getWorldItem(obj) ~= nil
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

local function matchesSprite(obj, token)
    local name = getSpriteName(obj)
    if not name then
        return false
    end
    return string.find(name, token, 1, true) ~= nil
end

local function matchesName(obj, token)
    if not obj or not obj.getName then
        return false
    end
    local name = obj:getName()
    if not name then
        return false
    end
    return string.find(name, token, 1, true) ~= nil
end

local function matchesDisplayName(item, token)
    if not item or not item.getDisplayName then
        return false
    end
    local name = item:getDisplayName()
    if not name then
        return false
    end
    return string.find(name, token, 1, true) ~= nil
end

local function getElectricityLevel(player)
    if not player or not player.getPerkLevel then
        return 0
    end
    return player:getPerkLevel(Perks.Electricity)
end

local function getBatteryRole(obj)
    if not obj then
        return "master"
    end
    local md = getObjectModData(obj)
    if md and md.batteryNet and md.batteryNet.role then
        return md.batteryNet.role
    end
    -- If not explicitly assigned, treat as master per spec.
    return "master"
end

local function hasCableItem(player)
    if not player or not player.getInventory then
        return false
    end
    local inventory = player:getInventory()
    if not inventory then
        return false
    end
    return inventory:contains("EnergyRouting.WireTransferEnergy")
        or inventory:contains("WireTransferEnergy")
        or inventory:contains("EnergyRouting.EnergyTransferCable")
        or inventory:contains("EnergyTransferCable")
end

local function hasRepairItems(player)
    if not player or not player.getInventory then
        return false
    end
    local inventory = player:getInventory()
    if not inventory then
        return false
    end
    return inventory:contains("Base.Screwdriver")
        and inventory:contains("Base.ElectronicsScrap")
        and inventory:contains("Base.ElectricalParts")
end

local function disableOption(option, description)
    if not option then
        return
    end
    option.notAvailable = true
    if description then
        local tooltip = ISToolTip:new()
        tooltip:initialise()
        tooltip:setVisible(false)
        tooltip.description = description
        option.toolTip = tooltip
    end
end

function Client.isBatteryTankObject(obj)
    if not obj then
        return false
    end
    if Client.isWindBatteryObject and Client.isWindBatteryObject(obj) then
        return false
    end
    local md = getObjectModData(obj)
    if md and (md.EnergyNetworkBattery or md.batteryNet or md.batteryId) then
        return true
    end
    local item = getWorldItem(obj)
    local fullType = getItemFullType(item)
    if fullType == "EnergyRouting.BatteryTank" or fullType == "BatteryTank" then
        return true
    end
    if matchesDisplayName(item, "Battery Tank") then
        return true
    end
    if hasWorldItemBacking(obj) and matchesSprite(obj, "BatteryTank") then
        return true
    end
    if matchesName(obj, "Battery Tank") then
        return true
    end
    return false
end

function Client.isSolarPanelObject(obj)
    if not obj then
        return false
    end
    if Client.isWindTurbineObject and Client.isWindTurbineObject(obj) then
        return false
    end
    local md = getObjectModData(obj)
    if md and (md.EnergyNetworkPanel or md.panel) and not md.wind then
        return true
    end
    local item = getWorldItem(obj)
    local fullType = getItemFullType(item)
    if fullType == "EnergyRouting.SolarPanel" or fullType == "SolarPanel"
        or fullType == "EnergyRouting.SolarPanelHorizontal" or fullType == "SolarPanelHorizontal" then
        return true
    end
    if matchesDisplayName(item, "Solar Panel Horizontal") or matchesDisplayName(item, "Solar Panel") then
        return true
    end
    if hasWorldItemBacking(obj) and (matchesSprite(obj, "SolarPanelHorizontal") or matchesSprite(obj, "SolarPanel")) then
        return true
    end
    return false
end

function Client.isWindTurbineObject(obj)
    if not obj then
        return false
    end
    local md = getObjectModData(obj)
    if md and md.wind then
        return true
    end
    local item = getWorldItem(obj)
    local fullType = getItemFullType(item)
    if fullType == "EnergyRouting.Aerogenerador" or fullType == "Aerogenerador" then
        return true
    end
    if matchesDisplayName(item, "Aerogenerador") then
        return true
    end
    if hasWorldItemBacking(obj) and (matchesSprite(obj, "Aerogenerador") or matchesSprite(obj, "WindTurbine")) then
        return true
    end
    return false
end

function Client.isHydroTurbineObject(obj)
    if not obj then
        return false
    end
    local md = getObjectModData(obj)
    if md and md.hydro then
        return true
    end
    local item = getWorldItem(obj)
    local fullType = getItemFullType(item)
    if fullType == "EnergyRouting.TurbinaHidraulica" or fullType == "TurbinaHidraulica" then
        return true
    end
    if matchesDisplayName(item, "Hydraulic Turbine") or matchesDisplayName(item, "Turbina Hidraulica") then
        return true
    end
    if hasWorldItemBacking(obj) and matchesSprite(obj, "TurbinaHidraulica") then
        return true
    end
    return false
end

function Client.isWindBatteryObject(obj)
    if not obj then
        return false
    end
    local md = getObjectModData(obj)
    if md and md.windBattery then
        return true
    end
    local item = getWorldItem(obj)
    local fullType = getItemFullType(item)
    if fullType == "EnergyRouting.WindBattery" or fullType == "WindBattery" then
        return true
    end
    if matchesDisplayName(item, "Wind Battery") then
        return true
    end
    if hasWorldItemBacking(obj) and matchesSprite(obj, "WindBattery") then
        return true
    end
    return false
end

function Client.isEnergyControllerObject(obj)
    if not obj then
        return false
    end
    local md = getObjectModData(obj)
    if md and type(md.energyController) == "table" then
        return true
    end
    local item = getWorldItem(obj)
    local fullType = getItemFullType(item)
    if fullType == "EnergyRouting.EnergyController" or fullType == "EnergyController" then
        return true
    end
    if hasWorldItemBacking(obj) and matchesSprite(obj, "EnergyController") then
        return true
    end
    if matchesDisplayName(item, "Energy Controller") then
        return true
    end
    if matchesName(obj, "Energy Controller") then
        return true
    end
    return false
end

local function getObjectLabel(obj, fallback)
    local item = getWorldItem(obj)
    if item and item.getDisplayName then
        return item:getDisplayName()
    end
    if obj and obj.getName then
        local name = obj:getName()
        if name then
            return name
        end
    end
    local spriteName = getSpriteName(obj)
    if spriteName then
        return spriteName
    end
    return fallback or "BatteryTank"
end

local function findBatteryTankNearSquare(square, radius, excludeObj)
    if not square or not getCell then
        return nil
    end
    local cell = getCell()
    if not cell then
        return nil
    end
    local z = square:getZ()
    local cx = square:getX()
    local cy = square:getY()
    for x = cx - radius, cx + radius do
        for y = cy - radius, cy + radius do
            local sq = cell:getGridSquare(x, y, z)
            if sq then
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    if obj ~= excludeObj and Client.isBatteryTankObject(obj) then
                        return obj
                    end
                end
                local worldObjects = sq:getWorldObjects()
                for i = 0, worldObjects:size() - 1 do
                    local obj = worldObjects:get(i)
                    if obj ~= excludeObj and Client.isBatteryTankObject(obj) then
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

local function collectObjectsNearSquare(square, radius, predicate, excludeObj)
    local results = {}
    if not square or not getCell or not predicate then
        return results
    end
    local cell = getCell()
    if not cell then
        return results
    end
    local seen = {}
    local z = square:getZ()
    local cx = square:getX()
    local cy = square:getY()
    for x = cx - radius, cx + radius do
        for y = cy - radius, cy + radius do
            local sq = cell:getGridSquare(x, y, z)
            if sq then
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    if obj ~= excludeObj and not seen[obj] and predicate(obj) then
                        seen[obj] = true
                        table.insert(results, obj)
                    end
                end
                if sq.getSpecialObjects then
                    local special = sq:getSpecialObjects()
                    for i = 0, special:size() - 1 do
                        local obj = special:get(i)
                        if obj ~= excludeObj and not seen[obj] and predicate(obj) then
                            seen[obj] = true
                            table.insert(results, obj)
                        end
                    end
                end
                if sq.getStaticMovingObjects then
                    local staticObjects = sq:getStaticMovingObjects()
                    for i = 0, staticObjects:size() - 1 do
                        local obj = staticObjects:get(i)
                        if obj ~= excludeObj and not seen[obj] and predicate(obj) then
                            seen[obj] = true
                            table.insert(results, obj)
                        end
                    end
                end
                local worldObjects = sq:getWorldObjects()
                for i = 0, worldObjects:size() - 1 do
                    local obj = worldObjects:get(i)
                    if obj ~= excludeObj and not seen[obj] and predicate(obj) then
                        seen[obj] = true
                        table.insert(results, obj)
                    end
                end
            end
        end
    end
    return results
end

local function collectBatteryTanksNearSquare(square, radius, excludeObj)
    return collectObjectsNearSquare(square, radius, Client.isBatteryTankObject, excludeObj)
end

local function collectSolarPanelsNearSquare(square, radius, excludeObj)
    return collectObjectsNearSquare(square, radius, Client.isSolarPanelObject, excludeObj)
end

local function collectWindTurbinesNearSquare(square, radius, excludeObj)
    return collectObjectsNearSquare(square, radius, Client.isWindTurbineObject, excludeObj)
end

local function collectControllersNearSquare(square, radius, excludeObj)
    return collectObjectsNearSquare(square, radius, Client.isEnergyControllerObject, excludeObj)
end

local function collectWindBatteriesNearSquare(square, radius, excludeObj)
    return collectObjectsNearSquare(square, radius, Client.isWindBatteryObject, excludeObj)
end

local function collectHydroTurbinesNearSquare(square, radius, excludeObj)
    return collectObjectsNearSquare(square, radius, Client.isHydroTurbineObject, excludeObj)
end

local function parseCoordsFromId(id, prefix)
    if not id then
        return nil
    end
    local pattern = "^" .. prefix .. "_(-?%d+)_(-?%d+)_(-?%d+)$"
    local xs, ys, zs = string.match(id, pattern)
    if not xs or not ys or not zs then
        return nil
    end
    return tonumber(xs), tonumber(ys), tonumber(zs)
end

local function findPanelById(panelId)
    local x, y, z = parseCoordsFromId(panelId, "panel")
    if not x then
        return nil
    end
    local cell = getCell()
    if not cell then
        return nil
    end
    local square = cell:getGridSquare(x, y, z)
    if not square then
        return nil
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local obj = worldObjects:get(i)
        if Client.isSolarPanelObject(obj) then
            return obj
        end
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Client.isSolarPanelObject(obj) then
            return obj
        end
    end
    if square.getSpecialObjects then
        local specialObjects = square:getSpecialObjects()
        for i = 0, specialObjects:size() - 1 do
            local obj = specialObjects:get(i)
            if Client.isSolarPanelObject(obj) then
                return obj
            end
        end
    end
    return nil
end

local function findBatteryById(batteryId)
    local x, y, z = parseCoordsFromId(batteryId, "battery")
    if not x then
        return nil
    end
    local cell = getCell()
    if not cell then
        return nil
    end
    local square = cell:getGridSquare(x, y, z)
    if not square then
        return nil
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local obj = worldObjects:get(i)
        if Client.isBatteryTankObject(obj) then
            return obj
        end
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Client.isBatteryTankObject(obj) then
            return obj
        end
    end
    if square.getSpecialObjects then
        local specialObjects = square:getSpecialObjects()
        for i = 0, specialObjects:size() - 1 do
            local obj = specialObjects:get(i)
            if Client.isBatteryTankObject(obj) then
                return obj
            end
        end
    end
    return nil
end

local function findWindById(windId)
    local x, y, z = parseCoordsFromId(windId, "wind")
    if not x then
        return nil
    end
    local cell = getCell()
    if not cell then
        return nil
    end
    local square = cell:getGridSquare(x, y, z)
    if not square then
        return nil
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local obj = worldObjects:get(i)
        if Client.isWindTurbineObject(obj) then
            return obj
        end
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Client.isWindTurbineObject(obj) then
            return obj
        end
    end
    if square.getSpecialObjects then
        local specialObjects = square:getSpecialObjects()
        for i = 0, specialObjects:size() - 1 do
            local obj = specialObjects:get(i)
            if Client.isWindTurbineObject(obj) then
                return obj
            end
        end
    end
    return nil
end

local function findHydroById(hydroId)
    local x, y, z = parseCoordsFromId(hydroId, "hydro")
    if not x then
        return nil
    end
    local cell = getCell()
    if not cell then
        return nil
    end
    local square = cell:getGridSquare(x, y, z)
    if not square then
        return nil
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local obj = worldObjects:get(i)
        if Client.isHydroTurbineObject(obj) then
            return obj
        end
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Client.isHydroTurbineObject(obj) then
            return obj
        end
    end
    if square.getSpecialObjects then
        local specialObjects = square:getSpecialObjects()
        for i = 0, specialObjects:size() - 1 do
            local obj = specialObjects:get(i)
            if Client.isHydroTurbineObject(obj) then
                return obj
            end
        end
    end
    return nil
end

local function findWindBatteryById(windBatteryId)
    local x, y, z = parseCoordsFromId(windBatteryId, "wind_battery")
    if not x then
        return nil
    end
    local cell = getCell()
    if not cell then
        return nil
    end
    local square = cell:getGridSquare(x, y, z)
    if not square then
        return nil
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local obj = worldObjects:get(i)
        if Client.isWindBatteryObject(obj) then
            return obj
        end
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Client.isWindBatteryObject(obj) then
            return obj
        end
    end
    if square.getSpecialObjects then
        local specialObjects = square:getSpecialObjects()
        for i = 0, specialObjects:size() - 1 do
            local obj = specialObjects:get(i)
            if Client.isWindBatteryObject(obj) then
                return obj
            end
        end
    end
    return nil
end

local function resolveLinkTargetObject(kind, objectId)
    if not kind or not objectId then
        return nil
    end
    if kind == "panel" then
        return findPanelById(objectId)
    end
    if kind == "battery" then
        return findBatteryById(objectId)
    end
    if kind == "wind" then
        return findWindById(objectId)
    end
    if kind == "hydro" then
        return findHydroById(objectId)
    end
    if kind == "windBattery" then
        return findWindBatteryById(objectId)
    end
    return nil
end

local function applyLinkSyncToObject(obj, kind, controllerId, connected)
    if not obj or not kind then
        return false
    end
    local md = getObjectModData(obj)
    if not md then
        return false
    end
    local isConnected = connected == true and controllerId ~= nil
    local cid = isConnected and controllerId or nil

    if kind == "panel" then
        md.panel = md.panel or {}
        md.panel.controllerId = cid
        md.energyPanel = md.energyPanel or {}
        md.energyPanel.controllerId = cid
        md.energy = md.energy or {}
        md.energy.type = md.energy.type or "solar"
        md.energy.controllerId = cid
        md.energy.connected = isConnected
        return true
    end
    if kind == "battery" then
        md.energy = md.energy or {}
        md.energy.type = md.energy.type or "battery"
        md.energy.controllerId = cid
        md.energy.connected = isConnected
        return true
    end
    if kind == "wind" then
        md.wind = md.wind or {}
        md.wind.controllerId = cid
        md.wind.connected = isConnected
        md.energy = md.energy or {}
        md.energy.type = md.energy.type or "wind"
        md.energy.controllerId = cid
        md.energy.connected = isConnected
        return true
    end
    if kind == "hydro" then
        md.hydro = md.hydro or {}
        md.hydro.controllerId = cid
        md.hydro.connected = isConnected
        md.energy = md.energy or {}
        md.energy.type = "hydro"
        md.energy.controllerId = cid
        md.energy.connected = isConnected
        return true
    end
    if kind == "windBattery" then
        md.windBattery = md.windBattery or {}
        md.windBattery.controllerId = cid
        md.windBattery.connected = isConnected
        md.energy = md.energy or {}
        md.energy.type = md.energy.type or "windBattery"
        md.energy.controllerId = cid
        md.energy.connected = isConnected
        return true
    end
    return false
end

local function getObjectCoords(obj)
    if not obj or not obj.getSquare then
        return nil
    end
    local square = obj:getSquare()
    if not square then
        return nil
    end
    return square:getX(), square:getY(), square:getZ()
end

local function makeId(prefix, obj)
    local x, y, z = getObjectCoords(obj)
    if not x then
        return nil
    end
    return prefix .. "_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(z)
end

local function getPanelId(obj)
    local md = getObjectModData(obj)
    if md and md.panel and md.panel.panelId then
        return md.panel.panelId
    end
    return makeId("panel", obj)
end

local function getBatteryId(obj)
    local md = getObjectModData(obj)
    if md and md.batteryId then
        return md.batteryId
    end
    return makeId("battery", obj)
end

local function getWindId(obj)
    local liveId = makeId("wind", obj)
    if liveId then
        return liveId
    end
    local md = getObjectModData(obj)
    if md and md.wind and md.wind.id then
        return md.wind.id
    end
    return nil
end

local function getWindBatteryId(obj)
    local liveId = makeId("wind_battery", obj)
    if liveId then
        return liveId
    end
    local md = getObjectModData(obj)
    if md and md.windBattery and md.windBattery.id then
        return md.windBattery.id
    end
    return nil
end

local function getHydroId(obj)
    local liveId = makeId("hydro", obj)
    if liveId then
        return liveId
    end
    local md = getObjectModData(obj)
    if md and md.hydro and md.hydro.id then
        return md.hydro.id
    end
    return nil
end

local function getControllerId(obj)
    local md = getObjectModData(obj)
    if md and type(md.energyController) == "table" and md.energyController.networkId then
        return md.energyController.networkId
    end
    return nil
end

local function getControllerIdFromSquare(obj)
    if not obj or not obj.getSquare then
        return nil
    end
    local square = obj:getSquare()
    if not square then
        return nil
    end
    local md = square:getModData()
    if md and md.EnergyRoutingEDCId then
        return md.EnergyRoutingEDCId
    end
    return nil
end

local function normalizeEdcId(edcId)
    if type(edcId) ~= "string" then
        return edcId
    end
    if string.find(edcId, ",", 1, true) then
        local xs, ys, zs = edcId:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
        if xs and ys and zs then
            return string.format("network_%d_%d_%d", tonumber(xs), tonumber(ys), tonumber(zs))
        end
    end
    local xs, ys, zs = edcId:match("^energy_net_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
    if xs and ys and zs then
        return string.format("network_%d_%d_%d", tonumber(xs), tonumber(ys), tonumber(zs))
    end
    return edcId
end

local function normalizeEnergizedSquares(source)
    local list = {}
    if type(source) ~= "table" then
        return list
    end

    local seen = {}
    local function pushSquare(x, y, z)
        local nx = tonumber(x)
        local ny = tonumber(y)
        local nz = tonumber(z)
        if not nx or not ny or not nz then
            return
        end
        nx = math.floor(nx)
        ny = math.floor(ny)
        nz = math.floor(nz)
        local key = tostring(nx) .. "_" .. tostring(ny) .. "_" .. tostring(nz)
        if seen[key] then
            return
        end
        seen[key] = true
        list[#list + 1] = { x = nx, y = ny, z = nz }
    end

    local hasArrayEntries = false
    for _, entry in ipairs(source) do
        hasArrayEntries = true
        if type(entry) == "table" then
            pushSquare(entry.x, entry.y, entry.z)
        elseif type(entry) == "string" then
            local xs, ys, zs = entry:match("^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            pushSquare(xs, ys, zs)
        end
    end

    if hasArrayEntries then
        return list
    end

    for key, value in pairs(source) do
        if value == true and type(key) == "string" then
            local xs, ys, zs = key:match("^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            pushSquare(xs, ys, zs)
        elseif type(value) == "table" then
            pushSquare(value.x, value.y, value.z)
        elseif type(value) == "string" then
            local xs, ys, zs = value:match("^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            pushSquare(xs, ys, zs)
        end
    end

    return list
end

local function makeId(prefix, obj)
    local x, y, z = getObjectCoords(obj)
    if not x then return nil end
    return prefix .. "_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(z)
end

local function resolveControllerId(obj)
    if obj and EnergyRouting and EnergyRouting.Controller and EnergyRouting.Controller.IsController
        and EnergyRouting.Controller.IsController(obj) then
        local liveId = makeId("network", obj)
        if liveId then
            return liveId
        end
    end
    local id = getControllerId(obj)
    if id then
        return id
    end
    id = getControllerIdFromSquare(obj)
    if id then
        return id
    end

    if EnergyRouting.Controller.IsController(obj) then
        return makeId("network", obj)
    end
    return nil
end

local function parseNetworkId(networkId)
    local x, y, z = parseCoordsFromId(networkId, "network")
    return x, y, z
end

local function findControllerById(controllerId)
    if not controllerId then
        return nil
    end
    if Client.controllerObjById and Client.controllerObjById[controllerId] then
        local cached = Client.controllerObjById[controllerId]
        if cached and Client.isEnergyControllerObject(cached) then
            return cached
        end
        Client.controllerObjById[controllerId] = nil
    end
    local nowMinutes = getWorldMinutes and getWorldMinutes() or 0
    local lastMiss = Client.controllerLookupMissAt and Client.controllerLookupMissAt[controllerId] or nil
    if lastMiss and (nowMinutes - lastMiss) < 1 then
        return nil
    end

    local x, y, z = parseNetworkId(controllerId)
    local cell = getCell()
    if not cell then
        Client.controllerLookupMissAt[controllerId] = nowMinutes
        return nil
    end

    if x and y and z then
        local square = cell:getGridSquare(x, y, z)
        if square then
            local fallbackController = nil
            local worldObjects = square:getWorldObjects()
            for i = 0, worldObjects:size() - 1 do
                local obj = worldObjects:get(i)
                if Client.isEnergyControllerObject(obj) then
                    local md = getObjectModData(obj)
                    if md and md.energyController and md.energyController.networkId == controllerId then
                        Client.controllerObjById[controllerId] = obj
                        Client.controllerLookupMissAt[controllerId] = nil
                        return obj
                    end
                    fallbackController = fallbackController or obj
                end
            end
            local objects = square:getObjects()
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if Client.isEnergyControllerObject(obj) then
                    local md = getObjectModData(obj)
                    if md and md.energyController and md.energyController.networkId == controllerId then
                        Client.controllerObjById[controllerId] = obj
                        Client.controllerLookupMissAt[controllerId] = nil
                        return obj
                    end
                    fallbackController = fallbackController or obj
                end
            end
            if fallbackController then
                Client.controllerObjById[controllerId] = fallbackController
                Client.controllerLookupMissAt[controllerId] = nil
                return fallbackController
            end
        end
        Client.controllerLookupMissAt[controllerId] = nowMinutes
        return nil
    end

    Client.controllerLookupMissAt[controllerId] = nowMinutes
    return nil
end

local function buildObjectLabel(obj, fallback)
    local label = getObjectLabel(obj, fallback)
    local x, y, z = getObjectCoords(obj)
    if x then
        label = label .. " [" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. "]"
    end
    return label
end

local function collectControllerIds(list)
    local ids = {}
    if not list then
        return ids
    end
    local seen = {}
    for k, v in pairs(list) do
        if type(k) == "string" then
            if not seen[k] then
                seen[k] = true
                table.insert(ids, k)
            end
        elseif type(v) == "string" then
            if not seen[v] then
                seen[v] = true
                table.insert(ids, v)
            end
        end
    end
    return ids
end

local function listHasId(list, id)
    if not list or not id then
        return false
    end
    if list[id] then
        return true
    end
    for _, v in ipairs(list) do
        if v == id then
            return true
        end
    end
    return false
end

local function getMaxPanels()
    if EnergyNetwork and EnergyNetwork.GetConfigValue then
        return EnergyNetwork.GetConfigValue("MaxPanels") or 4
    end
    return 4
end

local function getPanelConnectRadius()
    if EnergyNetwork and EnergyNetwork.GetConfigValue then
        return EnergyNetwork.GetConfigValue("PanelConnectRadius") or 8
    end
    return 8
end

local function getBatteryConnectRadius()
    if EnergyNetwork and EnergyNetwork.GetConfigValue then
        return EnergyNetwork.GetConfigValue("BatteryConnectRadius") or 4
    end
    return 4
end

local function getControllerConnectRadius()
    if EnergyNetwork and EnergyNetwork.GetConfigValue then
        return EnergyNetwork.GetConfigValue("ControllerConnectRadius") or 20
    end
    return 20
end

local function sqToTbl(square)
    return { x = square:getX(), y = square:getY(), z = square:getZ() }
end

local function queueCmd(playerObj, walkSq, command, args, time)
    EnergyRouting.TimedActions.Queue(playerObj, walkSq, command, args, time)
end

local function forEachContextObject(worldobjects, fn)
    if not worldobjects or not fn then
        return
    end
    if type(worldobjects) == "table" then
        for _, obj in ipairs(worldobjects) do
            fn(obj)
        end
        return
    end
    if worldobjects.size and worldobjects.get then
        local size = worldobjects:size()
        for i = 0, size - 1 do
            fn(worldobjects:get(i))
        end
    end
end

local function getSquareFromContext(worldobjects)
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.getSquare then
        return ISWorldObjectContextMenu.getSquare(worldobjects)
    end
    if not worldobjects then
        return nil
    end
    local foundSquare = nil
    forEachContextObject(worldobjects, function(obj)
        if foundSquare then
            return
        end
        local targetObj = getContextTarget(obj)
        if targetObj and targetObj.getSquare then
            foundSquare = targetObj:getSquare()
            return
        end
        if obj and obj.getSquare then
            foundSquare = obj:getSquare()
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
    local worldObjects = square:getWorldObjects()
    if worldObjects then
        for i = 0, worldObjects:size() - 1 do
            fn(worldObjects:get(i))
        end
    end
end

local function scanTargetsIn2x2(centerSquare, fn)
    if not centerSquare or not fn then
        return
    end
    local cell = getCell and getCell() or nil
    if not cell then
        return
    end
    local cx = centerSquare:getX()
    local cy = centerSquare:getY()
    local cz = centerSquare:getZ()
    for dx = 0, 1 do
        for dy = 0, 1 do
            local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
            if sq then
                forEachSquareObject(sq, fn)
            end
        end
    end
end

local function sameSquare(a, b)
    if not a or not b then
        return false
    end
    return a:getX() == b:getX() and a:getY() == b:getY() and a:getZ() == b:getZ()
end

local function findTargetsInSquare(square)
    if not square then
        return nil, nil
    end
    local batteryObj = nil
    local panelObj = nil
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if not batteryObj and Client.isBatteryTankObject(obj) then
            batteryObj = obj
        end
        if not panelObj and Client.isSolarPanelObject(obj) then
            panelObj = obj
        end
        if batteryObj and panelObj then
            return batteryObj, panelObj
        end
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local obj = worldObjects:get(i)
        if not batteryObj and Client.isBatteryTankObject(obj) then
            batteryObj = obj
        end
        if not panelObj and Client.isSolarPanelObject(obj) then
            panelObj = obj
        end
        if batteryObj and panelObj then
            return batteryObj, panelObj
        end
    end
    return batteryObj, panelObj
end

function Client.RepairBattery(worldObj, playerObj)
    if not worldObj or not playerObj then
        return
    end
    local square = worldObj.getSquare and worldObj:getSquare() or nil
    if not square then
        return
    end
    sendClientCommand(playerObj, "EnergyRouting", "RepairBattery", {
        batterySquare = { x = square:getX(), y = square:getY(), z = square:getZ() }
    })
end

function Client.ConnectPanel(worldObj, playerObj, batteryObj, walkTargetObj)
    if not worldObj or not playerObj or not batteryObj then
        return
    end
    local panelSquare = worldObj.getSquare and worldObj:getSquare() or nil
    local batterySquare = batteryObj.getSquare and batteryObj:getSquare() or nil
    if not panelSquare or not batterySquare then
        return
    end
    local walkSquare = panelSquare
    if walkTargetObj and walkTargetObj.getSquare then
        walkSquare = walkTargetObj:getSquare() or panelSquare
    end
    queueCmd(playerObj, walkSquare, "ConnectPanelToBattery", {
        panelSquare = sqToTbl(panelSquare),
        batterySquare = sqToTbl(batterySquare)
    }, 80)
end

function Client.ConnectBattery(worldObj, playerObj, otherBatteryObj)
    if not worldObj or not playerObj or not otherBatteryObj then
        return
    end
    local squareA = worldObj.getSquare and worldObj:getSquare() or nil
    local squareB = otherBatteryObj.getSquare and otherBatteryObj:getSquare() or nil
    if not squareA or not squareB then
        return
    end
    queueCmd(playerObj, squareB, "ConnectBatteryToBattery", {
        batteryASquare = sqToTbl(squareA),
        batteryBSquare = sqToTbl(squareB)
    }, 100)
end

function Client.ConnectPanelToController(panelObj, playerObj, controllerObj, controllerIdOverride)
    if not panelObj or not playerObj or not controllerObj then return end

    local panelSquare = panelObj.getSquare and panelObj:getSquare() or nil
    if not panelSquare then 
        print("[EnergyRouting] Error: Panel has no square")
        return 
    end

    local controllerId = controllerIdOverride or resolveControllerId(controllerObj)
    local panelId = getPanelId(panelObj)
    
    -- DEBUG LOG
    if not controllerId then print("[EnergyRouting] Error: controllerId is nil") end
    if not panelId then print("[EnergyRouting] Error: panelId is nil") end

    if not controllerId or not panelId then return end

    queueCmd(playerObj, panelSquare, "ConnectPanelToControllerById", {
        controllerId = controllerId,
        panelId = panelId,
    }, 80)
end

function Client.ConnectBatteryToController(batteryObj, playerObj, controllerObj, controllerIdOverride)
    if not batteryObj or not playerObj or not controllerObj then return end

    local batterySquare = batteryObj.getSquare and batteryObj:getSquare() or nil
    if not batterySquare then
        print("[EnergyRouting] Error: Battery has no square")
        return
    end

    local controllerId = controllerIdOverride or resolveControllerId(controllerObj)
    local batteryId = getBatteryId(batteryObj)

    -- DEBUG LOG
    if not controllerId then print("[EnergyRouting] Error: controllerId is nil") end
    if not batteryId then print("[EnergyRouting] Error: batteryId is nil") end
    
    if not controllerId or not batteryId then return end

    queueCmd(playerObj, batterySquare, "ConnectBatteryToControllerById", {
        controllerId = controllerId,
        batteryId = batteryId,
    }, 100)
end

function Client.ConnectWindToController(windObj, playerObj, controllerObj, controllerIdOverride)
    if not windObj or not playerObj or not controllerObj then return end

    local windSquare = windObj.getSquare and windObj:getSquare() or nil
    if not windSquare then
        print("[EnergyRouting] Error: Wind has no square")
        return
    end

    local controllerId = controllerIdOverride or resolveControllerId(controllerObj)
    local windId = getWindId(windObj)
    if not controllerId then print("[EnergyRouting] Error: controllerId is nil") end
    if not windId then print("[EnergyRouting] Error: windId is nil") end
    if not controllerId or not windId then return end

    queueCmd(playerObj, windSquare, "ConnectWindToControllerById", {
        controllerId = controllerId,
        windId = windId,
    }, 100)
end

function Client.ConnectWindBatteryToController(windBatteryObj, playerObj, controllerObj, controllerIdOverride)
    if not windBatteryObj or not playerObj or not controllerObj then return end

    local batterySquare = windBatteryObj.getSquare and windBatteryObj:getSquare() or nil
    if not batterySquare then
        print("[EnergyRouting] Error: WindBattery has no square")
        return
    end

    local controllerId = controllerIdOverride or resolveControllerId(controllerObj)
    local windBatteryId = getWindBatteryId(windBatteryObj)
    if not controllerId then print("[EnergyRouting] Error: controllerId is nil") end
    if not windBatteryId then print("[EnergyRouting] Error: windBatteryId is nil") end
    if not controllerId or not windBatteryId then return end

    queueCmd(playerObj, batterySquare, "ConnectWindBatteryToControllerById", {
        controllerId = controllerId,
        windBatteryId = windBatteryId,
    }, 100)
end

function Client.ConnectHydroToController(hydroObj, playerObj, controllerObj, controllerIdOverride)
    if not hydroObj or not playerObj or not controllerObj then return end

    local hydroSquare = hydroObj.getSquare and hydroObj:getSquare() or nil
    if not hydroSquare then
        print("[EnergyRouting] Error: Hydro has no square")
        return
    end

    local controllerId = controllerIdOverride or resolveControllerId(controllerObj)
    local hydroId = getHydroId(hydroObj)
    if not controllerId then print("[EnergyRouting] Error: controllerId is nil") end
    if not hydroId then print("[EnergyRouting] Error: hydroId is nil") end
    if not controllerId or not hydroId then return end

    queueCmd(playerObj, hydroSquare, "ConnectHydroToControllerById", {
        controllerId = controllerId,
        hydroId = hydroId,
    }, 100)
end

function Client.DisconnectPanelFromController(panelObj, playerObj, controllerObj)
    if not panelObj or not playerObj or not controllerObj then
        return
    end
    local panelSquare = panelObj.getSquare and panelObj:getSquare() or nil
    local controllerSquare = controllerObj.getSquare and controllerObj:getSquare() or nil
    if not panelSquare or not controllerSquare then
        return
    end
    queueCmd(playerObj, panelSquare, "DisconnectPanelFromController", {
        panelSquare = sqToTbl(panelSquare),
        controllerSquare = sqToTbl(controllerSquare)
    }, 80)
end

function Client.DisconnectBatteryFromController(batteryObj, playerObj, controllerObj)
    if not batteryObj or not playerObj or not controllerObj then
        return
    end
    local batterySquare = batteryObj.getSquare and batteryObj:getSquare() or nil
    local controllerSquare = controllerObj.getSquare and controllerObj:getSquare() or nil
    if not batterySquare or not controllerSquare then
        return
    end
    queueCmd(playerObj, batterySquare, "DisconnectBatteryFromController", {
        batterySquare = sqToTbl(batterySquare),
        controllerSquare = sqToTbl(controllerSquare)
    }, 100)
end

function Client.DisconnectWindFromController(windObj, playerObj, controllerObj)
    if not windObj or not playerObj or not controllerObj then
        return
    end
    local controllerId = resolveControllerId(controllerObj)
    local windId = getWindId(windObj)
    local windSquare = windObj.getSquare and windObj:getSquare() or nil
    if not windSquare or not controllerId or not windId then
        return
    end
    queueCmd(playerObj, windSquare, "DisconnectWindFromController", {
        controllerId = controllerId,
        windId = windId,
    }, 100)
end

function Client.DisconnectWindBatteryFromController(windBatteryObj, playerObj, controllerObj)
    if not windBatteryObj or not playerObj or not controllerObj then
        return
    end
    local controllerId = resolveControllerId(controllerObj)
    local windBatteryId = getWindBatteryId(windBatteryObj)
    local batterySquare = windBatteryObj.getSquare and windBatteryObj:getSquare() or nil
    if not batterySquare or not controllerId or not windBatteryId then
        return
    end
    queueCmd(playerObj, batterySquare, "DisconnectWindBatteryFromController", {
        controllerId = controllerId,
        windBatteryId = windBatteryId,
    }, 100)
end

function Client.DisconnectHydroFromController(hydroObj, playerObj, controllerObj)
    if not hydroObj or not playerObj or not controllerObj then
        return
    end
    local controllerId = resolveControllerId(controllerObj)
    local hydroId = getHydroId(hydroObj)
    local hydroSquare = hydroObj.getSquare and hydroObj:getSquare() or nil
    if not hydroSquare or not controllerId or not hydroId then
        return
    end
    queueCmd(playerObj, hydroSquare, "DisconnectHydroFromController", {
        controllerId = controllerId,
        hydroId = hydroId,
    }, 100)
end

function Client.DisconnectPanel(worldObj, playerObj)
    if not worldObj or not playerObj then
        return
    end
    local square = worldObj.getSquare and worldObj:getSquare() or nil
    if not square then
        return
    end
    queueCmd(playerObj, square, "DisconnectPanel", {
        panelSquare = sqToTbl(square)
    }, 80)
end

function Client.DisconnectBattery(worldObj, playerObj)
    if not worldObj or not playerObj then
        return
    end
    local square = worldObj.getSquare and worldObj:getSquare() or nil
    if not square then
        return
    end
    queueCmd(playerObj, square, "DisconnectBattery", {
        batterySquare = sqToTbl(square)
    }, 100)
end

function Client.DisconnectPanelFromBattery(batteryObj, playerObj)
    if not batteryObj or not playerObj then
        return
    end
    if not EnergyNetwork or not EnergyNetwork.HasInput or not EnergyNetwork.HasInput(batteryObj) then
        return
    end
    local md = getObjectModData(batteryObj)
    local input = md and md.input or nil
    if not input or not input.source then
        return
    end
    local batterySquare = batteryObj.getSquare and batteryObj:getSquare() or nil
    if not batterySquare then
        return
    end
    queueCmd(playerObj, batterySquare, "DisconnectPanel", {
        panelSquare = { x = input.source.x, y = input.source.y, z = input.source.z }
    }, 80)
end

function Client.FindEDCId(square)
    if not square then
        return nil
    end
    local md = square:getModData()
    if md and md.EnergyRoutingEDCId then
        return md.EnergyRoutingEDCId
    end
    return nil
end

function Client.OpenPanel(edcId, readOnly, controllerObj)
    if not edcId then
        return
    end
    edcId = normalizeEdcId(edcId)
    if controllerObj then
        Client.controllerObjById[edcId] = controllerObj
    end

    logClient("[DEBUG] openControllerUI edcId=" .. tostring(edcId) .. " readOnly=" .. tostring(readOnly))

    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, "EnergyRouting", "EnsureController", { controllerId = edcId })
    end

    local panel = Client.uiById[edcId]
    if panel and panel:getIsVisible() then
        if panel.readOnly ~= (readOnly and true or false) then
            panel:removeFromUIManager()
            Client.uiById[edcId] = nil
            panel = nil
        else
            panel:bringToTop()
            return
        end
    end

    if panel then
        panel:bringToTop()
        return
    end

    panel = EnergyRoutingUI:new(edcId, readOnly)
    panel:initialise()
    panel:addToUIManager()
    Client.uiById[edcId] = panel
    if EnergyRouting and EnergyRouting.UI then
        EnergyRouting.UI.instance = panel
    end

    Client.RequestState(edcId)

    local retries = 0
    local function retryRequest()
        retries = retries + 1
        if Client.stateById and Client.stateById[edcId] then
            Events.OnTick.Remove(retryRequest)
            return
        end
        if retries >= 60 then
            Events.OnTick.Remove(retryRequest)
            return
        end
        Client.RequestState(edcId)
    end
    Events.OnTick.Add(retryRequest)
end

function Client.OnPanelClosed(edcId)
    if not edcId then
        return
    end
    if Client.uiById then
        Client.uiById[edcId] = nil
    end
    if EnergyRouting and EnergyRouting.RangeOverlay and EnergyRouting.RangeOverlay.HideIfController then
        EnergyRouting.RangeOverlay.HideIfController(edcId)
    end
end

function Client.UpdateState(edcState)
    if not edcState or not edcState.id then
        return
    end

    local rawId = edcState.id
    local normalizedId = normalizeEdcId(rawId)
    if normalizedId ~= rawId then
        edcState.id = normalizedId
    end
    local previousState = Client.stateById[edcState.id] or Client.stateById[rawId]
    if edcState.batteries then
        local normalized = {}
        for _, entry in ipairs(edcState.batteries) do
            if type(entry) == "string" then
                table.insert(normalized, { id = entry, role = nil })
            elseif type(entry) == "table" and entry.id then
                table.insert(normalized, entry)
            end
        end
        edcState.batteries = normalized
    end
    local hasSquaresPayload = type(edcState.energizedSquares) == "table"
    if hasSquaresPayload then
        edcState.energizedSquares = normalizeEnergizedSquares(edcState.energizedSquares)
    else
        local cachedSquares = previousState and previousState.energizedSquares or nil
        if type(cachedSquares) == "table" and #cachedSquares > 0 then
            edcState.energizedSquares = cachedSquares
        else
            edcState.energizedSquares = {}
        end
        edcState._missingSquaresPayload = true
    end

    logClient("UpdateState id=" .. tostring(edcState.id)
        .. " consumption=" .. tostring(edcState.consumptionTotal or edcState.consumption or 0)
        .. " detected=" .. tostring(edcState.detectedConsumerCount or 0)
        .. " panelCount=" .. tostring(edcState.panelCount)
        .. " batteryCount=" .. tostring(edcState.batteryCount))

    Client.stateById[edcState.id] = edcState
    Client._fallbackStateLogById[edcState.id] = nil
    Client._fallbackSnapshotLogById[edcState.id] = nil
    Client._fallbackMissLogById[tostring(edcState.id) .. "|controller_not_found"] = nil
    Client._fallbackMissLogById[tostring(edcState.id) .. "|controller_moddata_missing"] = nil
    if rawId ~= edcState.id then
        Client.stateById[rawId] = nil
        Client._fallbackStateLogById[rawId] = nil
        Client._fallbackSnapshotLogById[rawId] = nil
        Client._fallbackMissLogById[tostring(rawId) .. "|controller_not_found"] = nil
        Client._fallbackMissLogById[tostring(rawId) .. "|controller_moddata_missing"] = nil
    end

    if EnergyRouting and EnergyRouting.RangeOverlay and EnergyRouting.RangeOverlay.OnStateUpdated then
        EnergyRouting.RangeOverlay.OnStateUpdated(edcState)
    end
    if edcState._missingSquaresPayload
        and EnergyRouting and EnergyRouting.RangeOverlay and EnergyRouting.RangeOverlay.IsVisibleFor
        and EnergyRouting.RangeOverlay.IsVisibleFor(edcState.id) then
        local nowMs = (getTimestampMs and getTimestampMs()) or math.floor((os.clock() or 0) * 1000)
        local lastMs = tonumber(Client._lastSquaresRequestAtById[edcState.id]) or 0
        if (nowMs - lastMs) >= 1000 then
            Client._lastSquaresRequestAtById[edcState.id] = nowMs
            Client.RequestState(edcState.id, true)
        end
    end

    local panel = Client.uiById[edcState.id]
    if not panel and rawId ~= edcState.id then
        panel = Client.uiById[rawId]
        if panel then
            Client.uiById[rawId] = nil
            Client.uiById[edcState.id] = panel
            panel.edcId = edcState.id
        end
    end
    if panel then
        logClient("UpdateState applyState uiById hit id=" .. tostring(edcState.id))
        panel:applyState(edcState)
    else
        logClient("UpdateState uiById miss id=" .. tostring(edcState.id))
    end

    if EnergyRouting and EnergyRouting.UI and EnergyRouting.UI.instance then
        local ui = EnergyRouting.UI.instance
        if ui.edcId == edcState.id then
            logClient("UpdateState applyState UI.instance id=" .. tostring(edcState.id))
            ui:applyState(edcState)
        end
    end
end

function Client.GetState(edcId)
    edcId = normalizeEdcId(edcId)
    if not edcId then
        return nil
    end

    local cachedState = Client.stateById and Client.stateById[edcId] or nil
    if cachedState and cachedState._source ~= "fallback" then
        return cachedState
    end

    -- Fallback: build a minimal state from local controller modData (SP-safe).
    local function logFallbackMissOnce(id, reason, message)
        local key = tostring(id) .. "|" .. tostring(reason)
        if Client._fallbackMissLogById[key] then
            return
        end
        Client._fallbackMissLogById[key] = true
        logClient(message)
    end

    local controllerObj = findControllerById(edcId)
    if not controllerObj then
        logFallbackMissOnce(edcId, "controller_not_found",
            "GetState fallback miss: controllerObj not found for id=" .. tostring(edcId))
        return nil
    end
    local md = getObjectModData(controllerObj)
    local controller = (md and type(md.energyController) == "table") and md.energyController or nil
    if not controller then
        logFallbackMissOnce(edcId, "controller_moddata_missing",
            "GetState fallback miss: controller modData missing for id=" .. tostring(edcId))
        return nil
    end

    if not Client._fallbackStateLogById[edcId] then
        Client._fallbackStateLogById[edcId] = true
        print("[SPESS][UI] fallback-state id=" .. tostring(edcId))
    end

    local function copyTable(source)
        local target = {}
        if type(source) == "table" then
            for k, v in pairs(source) do
                target[k] = v
            end
        end
        return target
    end

    local panels = collectControllerIds(controller.panels or {})
    local batteryIds = collectControllerIds(controller.batteries or {})
    local windIds = collectControllerIds(controller.windTurbines or {})
    local hydroIds = collectControllerIds(controller.hydroTurbines or {})
    local windBatteryIds = collectControllerIds(controller.windBatteries or {})
    local batteries = {}
    for _, batteryId in ipairs(batteryIds) do
        local role = nil
        local batteryObj = findBatteryById(batteryId)
        if batteryObj then
            local bmd = getObjectModData(batteryObj)
            local energy = bmd and bmd.energy or nil
            role = energy and energy.role or nil
        end
        table.insert(batteries, { id = batteryId, role = role })
    end
    local masterId = nil
    for _, entry in ipairs(batteries) do
        if entry.role == "master" then
            masterId = entry.id
            break
        end
    end
    if not masterId and #batteries > 0 then
        batteries[1].role = "master"
        masterId = batteries[1].id
    end
    for _, entry in ipairs(batteries) do
        if entry.id ~= masterId then
            entry.role = "slave"
        end
    end

    local routingData = ModData and ModData.getOrCreate and ModData.getOrCreate("EnergyRouting") or nil
    local routingEdcs = routingData and routingData.edcs or nil
    local edcSnapshot = nil
    if type(routingEdcs) == "table" then
        edcSnapshot = routingEdcs[edcId]
    end
    if type(edcSnapshot) ~= "table" and type(controller.routingState) == "table" then
        edcSnapshot = controller.routingState
    end
    if not Client._fallbackSnapshotLogById[edcId] then
        Client._fallbackSnapshotLogById[edcId] = true
        print("[SPESS][UI] fallback-snapshot id=" .. tostring(edcId)
            .. " hasSnapshot=" .. tostring(edcSnapshot ~= nil)
            .. " consumption=" .. tostring(edcSnapshot and (edcSnapshot.consumptionTotal or edcSnapshot.consumption) or "nil"))
    end

    local toggles = copyTable((edcSnapshot and edcSnapshot.toggles) or controller.toggles) or {}
    local groupStates = copyTable(edcSnapshot and edcSnapshot.groupStates) or {}
    local groupConsumption = copyTable(edcSnapshot and edcSnapshot.groupConsumption) or {}
    local groupDemand = copyTable(edcSnapshot and edcSnapshot.groupDemand) or {}
    local energizedSquares = normalizeEnergizedSquares(edcSnapshot and edcSnapshot.energizedSquares)

    local hasGroupStates = false
    for _ in pairs(groupStates) do
        hasGroupStates = true
        break
    end
    if not hasGroupStates then
        local hasPower = ((controller.totalProduction or 0) > 0) or ((controller.totalStorage or 0) > 0)
        for _, group in ipairs(EnergyRouting.GroupsList) do
            local enabled = toggles[group.id] ~= false
            if enabled then
                groupStates[group.id] = hasPower and "powered" or "limited"
            else
                groupStates[group.id] = "disabled"
            end
        end
    end

    local hasGroupConsumption = false
    for _, watts in pairs(groupConsumption) do
        if (tonumber(watts) or 0) > 0 then
            hasGroupConsumption = true
            break
        end
    end
    if not hasGroupConsumption then
        for _, group in ipairs(EnergyRouting.GroupsList) do
            local demandWatts = tonumber(groupDemand[group.id]) or 0
            if groupStates[group.id] == "powered" then
                groupConsumption[group.id] = demandWatts
            else
                groupConsumption[group.id] = 0
            end
        end
    end

    local production = tonumber((edcSnapshot and edcSnapshot.production) or controller.totalProduction or 0) or 0
    local storage = tonumber((edcSnapshot and edcSnapshot.storage) or controller.totalStorage or 0) or 0
    local totalCapacity = tonumber((edcSnapshot and (edcSnapshot.capacity or edcSnapshot.totalCapacity)) or controller.totalCapacity or 0) or 0
    local windCapacity = tonumber((edcSnapshot and edcSnapshot.windCapacity) or controller.windCapacity or 0) or 0
    local solarCapacity = tonumber((edcSnapshot and edcSnapshot.solarCapacity) or controller.solarCapacity or 0) or 0
    if solarCapacity <= 0 and totalCapacity > 0 then
        solarCapacity = math.max(0, totalCapacity - windCapacity)
    end
    if totalCapacity <= 0 then
        totalCapacity = math.max(0, solarCapacity + windCapacity)
    end
    local consumptionTotal = tonumber((edcSnapshot and (edcSnapshot.consumptionTotal or edcSnapshot.consumption)) or 0) or 0
    local consumption = tonumber((edcSnapshot and edcSnapshot.consumption) or consumptionTotal) or consumptionTotal
    if consumptionTotal <= 0 then
        for _, group in ipairs(EnergyRouting.GroupsList) do
            consumptionTotal = consumptionTotal + (tonumber(groupConsumption[group.id]) or 0)
        end
    end
    if consumption <= 0 then
        consumption = consumptionTotal
    end
    local balance = tonumber(edcSnapshot and edcSnapshot.balance) or (production - consumptionTotal)
    local outputEnabled = (edcSnapshot and edcSnapshot.outputEnabled) ~= false and (controller.outputEnabled ~= false)
    local controllerSq = controllerObj and controllerObj.getSquare and controllerObj:getSquare() or nil
    local fallbackX = controllerSq and controllerSq:getX() or tonumber(edcSnapshot and edcSnapshot.x) or nil
    local fallbackY = controllerSq and controllerSq:getY() or tonumber(edcSnapshot and edcSnapshot.y) or nil
    local fallbackZ = controllerSq and controllerSq:getZ() or tonumber(edcSnapshot and edcSnapshot.z) or nil
    if fallbackX ~= nil then fallbackX = math.floor(fallbackX) end
    if fallbackY ~= nil then fallbackY = math.floor(fallbackY) end
    if fallbackZ ~= nil then fallbackZ = math.floor(fallbackZ) end

    local fallbackState = {
        id = edcId,
        x = fallbackX,
        y = fallbackY,
        z = fallbackZ,
        mode = (edcSnapshot and edcSnapshot.mode) or controller.mode or controller.priorityMode,
        outputEnabled = outputEnabled,
        toggles = toggles,
        groupStates = groupStates,
        groupConsumption = groupConsumption,
        groupDemand = groupDemand,
        role = (edcSnapshot and edcSnapshot.role) or "controller",
        production = production,
        consumptionTotal = consumptionTotal,
        consumption = consumption,
        detectedConsumerCount = tonumber(edcSnapshot and edcSnapshot.detectedConsumerCount) or 0,
        balance = balance,
        usesBattery = (edcSnapshot and edcSnapshot.usesBattery) == true,
        solarProduction = tonumber((edcSnapshot and edcSnapshot.solarProduction) or controller.solarProduction or 0) or 0,
        windProduction = tonumber((edcSnapshot and edcSnapshot.windProduction) or controller.windProduction or 0) or 0,
        hydroProduction = tonumber((edcSnapshot and edcSnapshot.hydroProduction) or controller.hydroProduction or 0) or 0,
        otherProduction = tonumber((edcSnapshot and edcSnapshot.otherProduction) or controller.otherProduction or 0) or 0,
        solarBonusPercent = tonumber((edcSnapshot and edcSnapshot.solarBonusPercent) or controller.solarBonusPercent or 0) or 0,
        windBonusPercent = tonumber((edcSnapshot and edcSnapshot.windBonusPercent) or controller.windBonusPercent or 0) or 0,
        storage = storage,
        capacity = totalCapacity,
        totalCapacity = totalCapacity,
        solarCapacity = solarCapacity,
        windCapacity = windCapacity,
        solarStorage = tonumber((edcSnapshot and edcSnapshot.solarStorage) or controller.solarStorage or 0) or 0,
        windStorage = tonumber((edcSnapshot and edcSnapshot.windStorage) or controller.windStorage or 0) or 0,
        weather = (edcSnapshot and edcSnapshot.weather) or controller.weather or "Unknown",
        panelCount = tonumber((edcSnapshot and edcSnapshot.panelCount) or (type(panels) == "table" and #panels) or 0) or 0,
        batteryCount = tonumber((edcSnapshot and edcSnapshot.batteryCount) or (type(batteryIds) == "table" and #batteryIds) or 0) or 0,
        windCount = tonumber((edcSnapshot and edcSnapshot.windCount) or (type(windIds) == "table" and #windIds) or 0) or 0,
        hydroCount = tonumber((edcSnapshot and edcSnapshot.hydroCount) or (type(hydroIds) == "table" and #hydroIds) or 0) or 0,
        otherCount = tonumber((edcSnapshot and edcSnapshot.otherCount) or controller.otherCount or 0) or 0,
        windBatteryCount = tonumber((edcSnapshot and edcSnapshot.windBatteryCount) or (type(windBatteryIds) == "table" and #windBatteryIds) or 0) or 0,
        batteries = batteries,
        energizedSquares = energizedSquares,
        _source = "fallback",
    }

    Client.stateById[edcId] = fallbackState
    return fallbackState
end

function Client.RequestState(edcId, includeSquares)
    local player = getSpecificPlayer(0)
    if not player then
        return
    end
    edcId = normalizeEdcId(edcId)
    if not edcId then
        return
    end
    sendClientCommand(player, "EnergyRouting", "RequestState", {
        edcId = edcId,
        includeSquares = includeSquares == true,
    })
end

function Client.SendToggle(edcId, groupId, enabled)
    local player = getSpecificPlayer(0)
    if not player then
        return
    end
    edcId = normalizeEdcId(edcId)
    sendClientCommand(player, "EnergyRouting", "ToggleGroup", { edcId = edcId, groupId = groupId, enabled = enabled })
end

function Client.SendMode(edcId, mode)
    local player = getSpecificPlayer(0)
    if not player then
        return
    end
    edcId = normalizeEdcId(edcId)
    sendClientCommand(player, "EnergyRouting", "SetMode", { edcId = edcId, mode = mode })
end

function Client.SendOutputEnabled(edcId, enabled)
    local player = getSpecificPlayer(0)
    if not player then
        return
    end
    edcId = normalizeEdcId(edcId)
    sendClientCommand(player, "EnergyRouting", "SetOutputEnabled", { edcId = edcId, enabled = enabled and true or false })
end

function Client.OnServerCommand(module, command, args)
    if module ~= "EnergyRouting" and module ~= EnergyRouting.MOD_ID then
        return
    end
    logClient("[DBG] OnServerCommand module=" .. tostring(module) .. " command=" .. tostring(command))
    if command == "LinkSync" and args then
        local kind = args.kind
        local objectId = args.objectId
        local controllerId = args.controllerId
        local sourceControllerId = args.sourceControllerId
        local refreshControllerId = controllerId or sourceControllerId
        local connected = args.connected == true
        local targetObj = resolveLinkTargetObject(kind, objectId)
        if targetObj then
            applyLinkSyncToObject(targetObj, kind, controllerId, connected)
        else
            logClient("[DBG] LinkSync target not found kind=" .. tostring(kind) .. " objectId=" .. tostring(objectId))
        end
        if refreshControllerId then
            local hasOpenUi = Client.uiById and Client.uiById[refreshControllerId] ~= nil
            local hasVisibleOverlay = EnergyRouting and EnergyRouting.RangeOverlay
                and EnergyRouting.RangeOverlay.IsVisibleFor
                and EnergyRouting.RangeOverlay.IsVisibleFor(refreshControllerId)
            if hasOpenUi or hasVisibleOverlay then
                Client.RequestState(refreshControllerId, false)
            end
        end
        return
    end
    if command == "UpdateState" and args and args.edc then
        logClient("[DBG] UpdateState recv id="..tostring(args.edc.id)
            .." consumption="..tostring(args.edc.consumptionTotal or args.edc.consumption or 0)
            .." panels="..tostring(args.edc.panelCount)
            .." batteries="..tostring(args.edc.batteryCount)
            .." turbines="..tostring(args.edc.windCount)
            .." hydro="..tostring(args.edc.hydroCount)
            .." windBatteries="..tostring(args.edc.windBatteryCount))
        Client.UpdateState(args.edc)
    end
end

function Client._onContextMenu(playerNum, context, worldobjects, test)
    if test then
        return true
    end

    if not EnergyRouting.GetConfigValue("EnableEnergyRoutingUI") then
        return
    end

    local player = getPlayerByIndex(playerNum) or getSpecificPlayer(0) or (getPlayer and getPlayer() or nil)
    local skill = getElectricityLevel(player)
    local square = getContextCenterSquare(worldobjects, player)
    local squareEdcId = nil
    local batteryObj, panelObj, windObj, hydroObj, windBatteryObj, controllerObj = nil, nil, nil, nil, nil, nil
    local targetKind = nil

    local function pickTarget(probe, strictSquare)
        if not probe then
            return
        end
        if strictSquare and square and probe.getSquare then
            local probeSq = probe:getSquare()
            if probeSq and not sameSquare(probeSq, square) then
                return
            end
        end
        if not windBatteryObj and Client.isWindBatteryObject(probe) then
            windBatteryObj = probe
            targetKind = targetKind or "windBattery"
            return
        end
        if not windObj and Client.isWindTurbineObject(probe) then
            windObj = probe
            targetKind = targetKind or "wind"
            return
        end
        if not hydroObj and Client.isHydroTurbineObject(probe) then
            hydroObj = probe
            targetKind = targetKind or "hydro"
            return
        end
        if not panelObj and Client.isSolarPanelObject(probe) then
            panelObj = probe
            targetKind = targetKind or "panel"
            return
        end
        if not batteryObj and Client.isBatteryTankObject(probe) then
            batteryObj = probe
            targetKind = targetKind or "battery"
            return
        end
        if not controllerObj and Client.isEnergyControllerObject(probe) then
            controllerObj = probe
            targetKind = targetKind or "controller"
            return
        end
    end

    -- Prefer objects exactly on clicked square.
    forEachContextObject(worldobjects, function(obj)
        local target = getContextTarget(obj)
        pickTarget(target or obj, true)
    end)

    if square then
        local sqMd = square:getModData()
        if sqMd and sqMd.EnergyRoutingEDCId then
            squareEdcId = sqMd.EnergyRoutingEDCId
        end
        -- First fallback on exact clicked square objects.
        if not targetKind then
            forEachSquareObject(square, function(probe)
                pickTarget(probe, false)
            end)
        end
        -- Option A: scan a 2x2 footprint around the clicked tile.
        if not targetKind then
            scanTargetsIn2x2(square, function(probe)
                pickTarget(probe, false)
            end)
        end
        if not controllerObj then
            local controllers = collectControllersNearSquare(square, 1)
            controllerObj = controllers and controllers[1] or nil
        end
    end

    if not targetKind then
        if windObj then
            targetKind = "wind"
        elseif hydroObj then
            targetKind = "hydro"
        elseif windBatteryObj then
            targetKind = "windBattery"
        elseif panelObj then
            targetKind = "panel"
        elseif batteryObj then
            targetKind = "battery"
        elseif controllerObj then
            targetKind = "controller"
        end
    end

    local function addConnectToNearby(obj, label, connectFn)
        if not obj then return end

        local objSq = (obj.getSquare and obj:getSquare()) or square
        if not objSq then return end

        local controllers = collectControllersNearSquare(objSq, getControllerConnectRadius())
        if #controllers == 0 then return end

        -- Crear submenu temporal
        local tempOptions = {}

        for _, controller in ipairs(controllers) do
            table.insert(tempOptions, controller)
        end

        -- Si no hay opciones reales, no crear nada
        if #tempOptions == 0 then
            return
        end

        -- Crear root SOLO si realmente hay opciones
        local root = context:addOption(label, obj, function() end)
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(root, sub)

        for _, controller in ipairs(tempOptions) do
            local controllerId = resolveControllerId(controller)
            local row = sub:addOption(
                buildObjectLabel(controller, mt("energy_controller_label")),
                obj,
                connectFn,
                player,
                controller,
                controllerId
            )

            if skill < 2 then
                disableOption(row, mt("req_elec_2"))
            elseif not hasCableItem(player) then
                disableOption(row, mt("req_cable"))
            end
        end
    end

    if targetKind == "controller" and controllerObj then
        local controllerId = normalizeEdcId(resolveControllerId(controllerObj) or squareEdcId)
        if controllerId then
            context:addOption(mt("open_controller"), controllerObj, function()
                if EnergyRouting and EnergyRouting.UI and EnergyRouting.UI.OpenController then
                    EnergyRouting.UI.OpenController(controllerId, false)
                else
                    Client.OpenPanel(controllerId, false, controllerObj)
                end
            end)
            local showingOverlay = EnergyRouting and EnergyRouting.RangeOverlay
                and EnergyRouting.RangeOverlay.IsVisibleFor
                and EnergyRouting.RangeOverlay.IsVisibleFor(controllerId)
            context:addOption(showingOverlay and mt("hide_energized_cells") or mt("view_energized_cells"), controllerObj, function()
                if not (EnergyRouting and EnergyRouting.RangeOverlay) then
                    return
                end
                local isVisibleNow = EnergyRouting.RangeOverlay.IsVisibleFor
                    and EnergyRouting.RangeOverlay.IsVisibleFor(controllerId)
                if isVisibleNow and EnergyRouting.RangeOverlay.Hide then
                    EnergyRouting.RangeOverlay.Hide()
                    return
                end

                local state = Client.GetState(controllerId)
                if not state then
                    local sq = controllerObj and controllerObj.getSquare and controllerObj:getSquare() or nil
                    state = {
                        id = controllerId,
                        x = sq and sq:getX() or nil,
                        y = sq and sq:getY() or nil,
                        z = sq and sq:getZ() or 0,
                        energizedSquares = {},
                    }
                elseif type(state.energizedSquares) ~= "table" then
                    state.energizedSquares = {}
                end

                -- Request full squares before/after show to avoid first-click empty overlay.
                Client.RequestState(controllerId, true)
                if EnergyRouting.RangeOverlay.Show then
                    local shown = EnergyRouting.RangeOverlay.Show(controllerId, state)
                    if shown then
                        Client.RequestState(controllerId, true)
                    end
                end
            end)
        end
    end

    if targetKind == "panel" and panelObj then
        local md = getObjectModData(panelObj)
        local controllerId = (md and md.panel and md.panel.controllerId)
            or (md and md.energyPanel and md.energyPanel.controllerId)
            or (md and md.energy and md.energy.controllerId)
            or nil
        context:addOption(mt("view_solar_panel"), panelObj, function()
            if EnergyRouting and EnergyRouting.UI and EnergyRouting.UI.OpenPanel then
                EnergyRouting.UI.OpenPanel(panelObj)
            end
        end)
        if controllerId then
            local controller = findControllerById(controllerId)
            if controller then
                context:addOption(mt("disconnect_from_controller"), panelObj, Client.DisconnectPanelFromController, player, controller)
            end
        else
            addConnectToNearby(panelObj, mt("connect_panel_controller"), Client.ConnectPanelToController)
        end
    end

    if targetKind == "battery" and batteryObj then
        local md = getObjectModData(batteryObj)
        local controllerId = (md and md.energy and md.energy.controllerId) or nil
        context:addOption(mt("view_solar_battery"), batteryObj, function()
            if EnergyRouting and EnergyRouting.UI and EnergyRouting.UI.OpenBattery then
                EnergyRouting.UI.OpenBattery(batteryObj)
            end
        end)
        if controllerId then
            local controller = findControllerById(controllerId)
            if controller then
                context:addOption(mt("disconnect_from_controller"), batteryObj, Client.DisconnectBatteryFromController, player, controller)
            end
        else
            addConnectToNearby(batteryObj, mt("connect_battery_controller"), Client.ConnectBatteryToController)
        end
    end

    if targetKind == "wind" and windObj then
        local md = getObjectModData(windObj)
        local controllerId = (md and md.wind and md.wind.controllerId)
            or (md and md.energy and md.energy.controllerId)
            or nil
        context:addOption(mt("view_aerogenerator"), windObj, function()
            if EnergyRouting and EnergyRouting.UI and EnergyRouting.UI.OpenPanel then
                EnergyRouting.UI.OpenPanel(windObj)
            end
        end)
        if controllerId then
            local controller = findControllerById(controllerId)
            if controller then
                context:addOption(mt("disconnect_from_controller"), windObj, Client.DisconnectWindFromController, player, controller)
            end
        else
            addConnectToNearby(windObj, mt("connect_aero_controller"), Client.ConnectWindToController)
        end
    end

    if targetKind == "windBattery" and windBatteryObj then
        local md = getObjectModData(windBatteryObj)
        local controllerId = (md and md.windBattery and md.windBattery.controllerId)
            or (md and md.energy and md.energy.controllerId)
            or nil
        context:addOption(mt("view_wind_battery"), windBatteryObj, function()
            if EnergyRouting and EnergyRouting.UI and EnergyRouting.UI.OpenBattery then
                EnergyRouting.UI.OpenBattery(windBatteryObj)
            end
        end)
        if controllerId then
            local controller = findControllerById(controllerId)
            if controller then
                context:addOption(mt("disconnect_from_controller"), windBatteryObj, Client.DisconnectWindBatteryFromController, player, controller)
            end
        else
            addConnectToNearby(windBatteryObj, mt("connect_wind_battery_controller"), Client.ConnectWindBatteryToController)
        end
    end

    if targetKind == "hydro" and hydroObj then
        local md = getObjectModData(hydroObj)
        local controllerId = (md and md.hydro and md.hydro.controllerId)
            or (md and md.energy and md.energy.controllerId)
            or nil
        local ownerMod = md and md.ownerMod or nil

        -- SmallProducersPack owns disconnected mini-hydro context menu.
        if not (ownerMod == "SmallProducersPack" and not controllerId) then
            context:addOption(mt("view_hydro_turbine"), hydroObj, function()
                if EnergyRouting and EnergyRouting.UI and EnergyRouting.UI.OpenPanel then
                    EnergyRouting.UI.OpenPanel(hydroObj)
                end
            end)
            if controllerId then
                local controller = findControllerById(controllerId)
                if controller then
                    context:addOption(mt("disconnect_from_controller"), hydroObj, Client.DisconnectHydroFromController, player, controller)
                end
            else
                addConnectToNearby(hydroObj, mt("connect_hydro_controller"), Client.ConnectHydroToController)
            end
        end
    end
end

function Client.onContextMenu(playerNum, context, worldobjects, test)
    local ok, err = pcall(Client._onContextMenu, playerNum, context, worldobjects, test)
    if not ok then
        print("[EnergyNetwork][Client] onContextMenu error: " .. tostring(err))
    end
end

Events.OnServerCommand.Add(Client.OnServerCommand)
Events.OnFillWorldObjectContextMenu.Add(Client.onContextMenu)
print("[SPESS][Client] Registered OnServerCommand")

