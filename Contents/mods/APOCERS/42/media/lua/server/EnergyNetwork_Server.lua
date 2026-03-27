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
require "EnergyNetwork"
require "EnergyRouting/Init"
require "EnergyRouting/Weather"
require "EnergyRouting/Energy_Server"

print("[SPESS][Server] EnergyNetwork_Server.lua loaded")

EnergyNetwork.Server = EnergyNetwork.Server or {}
local EN = EnergyNetwork.Server
EnergyNetwork_Server = EnergyNetwork_Server or EN
local DEFAULT_CONTROLLER_VERTICAL_RANGE = 2

EN.networks = EN.networks or {}
EN.modData = EN.modData or nil
EN.LogEnabled = true

local function safeCall(obj, method, ...)
    if obj and obj[method] then
        local ok, result = pcall(obj[method], obj, ...)
        if ok then
            return result
        end
    end
    return nil
end

local function logInfo(message)
    if not EN.LogEnabled then
        return
    end
    print("[EnergyNetwork] " .. tostring(message))
end

local function updateBatteryPanelsMap(batteryMd, panelList)
    if not batteryMd then
        return
    end
    batteryMd.batteryNet = batteryMd.batteryNet or {}
    local panelsMap = batteryMd.batteryNet.panels or {}
    -- Clear map
    for k in pairs(panelsMap) do
        panelsMap[k] = nil
    end
    if panelList then
        for _, panelId in ipairs(panelList) do
            panelsMap[panelId] = true
        end
    end
    batteryMd.batteryNet.panels = panelsMap
    batteryMd.batteryNet.hasInput = panelList and #panelList > 0 or false
end

local function getWorldMinutes()
    local gt = getGameTime()
    if not gt or not gt.getWorldAgeHours then
        return 0
    end
    return math.floor(gt:getWorldAgeHours() * 60)
end

local function getSquare(x, y, z)
    local cell = getCell()
    if not cell then
        return nil
    end
    return cell:getGridSquare(x, y, z)
end

function EN.SetSquaresElectricity(edc, hasPower)
    if not edc then
        return 0
    end

    local cx = tonumber(edc.x)
    local cy = tonumber(edc.y)
    local cz = tonumber(edc.z)
    if not cx or not cy or not cz then
        return 0
    end
    cx = math.floor(cx)
    cy = math.floor(cy)
    cz = math.floor(cz)

    local radius = tonumber(EnergyRouting and EnergyRouting.CONTROLLER_RADIUS or nil) or 20
    local verticalRange = tonumber(EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("ControllerVerticalRange") or nil)
    if not verticalRange or verticalRange < 0 then
        verticalRange = DEFAULT_CONTROLLER_VERTICAL_RANGE
    end
    verticalRange = math.floor(math.max(0, verticalRange))

    local cell = getCell and getCell() or nil
    if not cell then
        return 0
    end
    local minZ = cz - verticalRange
    if minZ < 0 then
        minZ = 0
    end
    local maxZ = cz + verticalRange
    if cell.getMaxZ then
        local ok, worldMaxZ = pcall(cell.getMaxZ, cell)
        if ok and type(worldMaxZ) == "number" and worldMaxZ >= 0 then
            worldMaxZ = math.floor(worldMaxZ)
            if maxZ > worldMaxZ then
                maxZ = worldMaxZ
            end
        end
    end
    if maxZ < minZ then
        maxZ = minZ
    end

    local count = 0
    for x = cx - radius, cx + radius do
        for y = cy - radius, cy + radius do
            for z = minZ, maxZ do
                local sq = cell:getGridSquare(x, y, z)
                if sq then
                    if sq.setHaveElectricity then
                        pcall(sq.setHaveElectricity, sq, hasPower and true or false)
                    end
                    if sq.setHasElectricity then
                        pcall(sq.setHasElectricity, sq, hasPower and true or false)
                    end
                    if sq.setElectricity then
                        pcall(sq.setElectricity, sq, hasPower and true or false)
                    end
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function getSquareFromObj(obj)
    if not obj or not obj.getSquare then
        return nil
    end
    return obj:getSquare()
end

local function resolvePlayer(player)
    if player then
        return player
    end
    if getSpecificPlayer then
        return getSpecificPlayer(0)
    end
    return nil
end

local function hasItemByFullType(container, fullType)
    if not container then
        return false
    end
    local items = container:getItems()
    if not items then
        return false
    end
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and item.getFullType and item:getFullType() == fullType then
            return true
        end
        if item and item.getInventory then
            local sub = item:getInventory()
            if sub and hasItemByFullType(sub, fullType) then
                return true
            end
        end
    end
    return false
end

local function removeItemByFullType(container, fullType)
    if not container then
        return false
    end
    local items = container:getItems()
    if not items then
        return false
    end
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and item.getFullType and item:getFullType() == fullType then
            if container.DoRemoveItem then
                container:DoRemoveItem(item)
            else
                container:Remove(item)
            end
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(container, item)
            end
            if container.setDrawDirty then
                container:setDrawDirty(true)
            end
            return true
        end
        if item and item.getInventory then
            local sub = item:getInventory()
            if sub and removeItemByFullType(sub, fullType) then
                return true
            end
        end
    end
    return false
end

local function randFloat()
    if ZombRandFloat then
        return ZombRandFloat(0.0, 1.0)
    end
    if ZombRand then
        return ZombRand(10000) / 10000
    end
    return math.random()
end

local function getItemFullType(obj)
    if not obj then
        return nil
    end
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item and item.getFullType then
        return item:getFullType()
    end
    if obj.getFullType then
        return obj:getFullType()
    end
    return nil
end

local function getSpriteName(obj)
    local sprite = safeCall(obj, "getSprite")
    if sprite and sprite.getName then
        return sprite:getName()
    end
    return nil
end

function EN.IsBatteryTankObject(obj)
    if not obj then
        return false
    end
    local md = safeCall(obj, "getModData")
    if md and md.EnergyNetworkBattery then
        return true
    end
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.BatteryTank" or fullType == "BatteryTank" then
        return true
    end
    local spriteName = getSpriteName(obj)
    if spriteName and string.find(spriteName, "BatteryTank", 1, true) then
        return true
    end
    return false
end

function EN.IsSolarPanelObject(obj)
    if not obj then
        return false
    end
    local md = safeCall(obj, "getModData")
    if md and md.EnergyNetworkPanel then
        return true
    end
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.SolarPanel" or fullType == "SolarPanel"
        or fullType == "EnergyRouting.SolarPanelHorizontal" or fullType == "SolarPanelHorizontal" then
        return true
    end
    local spriteName = getSpriteName(obj)
    if spriteName and (string.find(spriteName, "SolarPanel", 1, true) ~= nil) then
        return true
    end
    return false
end

function EN.GetPanelBonus(obj)
    local fullType = getItemFullType(obj)
    if fullType == "EnergyRouting.SolarPanelHorizontal" or fullType == "SolarPanelHorizontal" then
        return EnergyNetwork.GetConfigValue("PanelBonusH")
    end
    return EnergyNetwork.GetConfigValue("PanelBonusV")
end

function EN.FindObjectOnSquare(square, predicate)
    if not square or not predicate then
        return nil
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if predicate(obj) then
            return obj
        end
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local obj = worldObjects:get(i)
        if predicate(obj) then
            return obj
        end
    end
    return nil
end

function EN.GetBatteryById(batteryId)
    local x, y, z = EnergyNetwork.ParseCoordsFromId(batteryId, "battery")
    if not x then
        return nil
    end
    local square = getSquare(x, y, z)
    return EN.FindObjectOnSquare(square, EN.IsBatteryTankObject)
end

function EN.GetPanelById(panelId)
    local x, y, z = EnergyNetwork.ParseCoordsFromId(panelId, "panel")
    if not x then
        return nil
    end
    local square = getSquare(x, y, z)
    return EN.FindObjectOnSquare(square, EN.IsSolarPanelObject)
end

local function withinRadius(squareA, squareB, radius)
    if not squareA or not squareB then
        return false
    end
    if squareA:getZ() ~= squareB:getZ() then
        return false
    end
    local dx = squareA:getX() - squareB:getX()
    local dy = squareA:getY() - squareB:getY()
    return (dx * dx + dy * dy) <= (radius * radius)
end

local function listHasId(list, id)
    if not list or not id then
        return false
    end
    for _, v in ipairs(list) do
        if v == id then
            return true
        end
    end
    return false
end

function EN.EnsureBatteryMeta(obj)
    if not obj then
        return nil
    end
    local square = getSquareFromObj(obj)
    if not square then
        return nil
    end
    local md = obj:getModData()
    md.EnergyNetworkBattery = true
    md.batteryId = md.batteryId or EnergyNetwork.MakeBatteryId(square:getX(), square:getY(), square:getZ())
    md.batteryNet = md.batteryNet or {}
    md.batteryNet.condition = md.batteryNet.condition or 1.0
    md.batteryNet.capacity = md.batteryNet.capacity or EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
    -- Migration: older builds stored masterId as netId ("energy_net_x_y_z")
    if md.batteryNet and md.batteryNet.masterId and type(md.batteryNet.masterId) == "string" then
        if string.sub(md.batteryNet.masterId, 1, 11) == "energy_net_" then
            if md.batteryNet.role == "master" or md.batteryNet.role == nil then
                md.batteryNet.masterId = md.batteryId
            else
                local net = md.batteryNet.netId and EN.networks and EN.networks[md.batteryNet.netId]
                if net and net.masterId then
                    md.batteryNet.masterId = net.masterId
                end
            end
        end
    end
    return md
end

function EN.EnsurePanelMeta(obj)
    if not obj then
        return nil
    end
    local square = getSquareFromObj(obj)
    if not square then
        return nil
    end
    local md = obj:getModData()
    md.EnergyNetworkPanel = true
    md.panel = md.panel or {}
    md.panel.panelId = md.panel.panelId or EnergyNetwork.MakePanelId(square:getX(), square:getY(), square:getZ())
    md.panel.type = md.panel.type or (EN.GetPanelBonus(obj) == EnergyNetwork.GetConfigValue("PanelBonusH") and "H" or "V")
    md.panel.bonus = md.panel.bonus or EN.GetPanelBonus(obj)
    return md
end

function EN.PlayerHasCable(player)
    local actor = resolvePlayer(player)
    if not actor or not actor.getInventory then
        return false
    end
    local inventory = actor:getInventory()
    if not inventory then
        return false
    end
    if inventory:contains("EnergyRouting.WireTransferEnergy") or inventory:contains("WireTransferEnergy") then
        return true
    end
    return hasItemByFullType(inventory, "EnergyRouting.WireTransferEnergy")
        or hasItemByFullType(inventory, "WireTransferEnergy")
end

function EN.ConsumeCable(player)
    local actor = resolvePlayer(player)
    if not actor or not actor.getInventory then
        return false
    end
    local inventory = actor:getInventory()
    if not inventory then
        return false
    end
    if removeItemByFullType(inventory, "EnergyRouting.WireTransferEnergy") then
        return true
    end
    if removeItemByFullType(inventory, "WireTransferEnergy") then
        return true
    end
    return false
end

function EN.ReturnCable(player)
    local actor = resolvePlayer(player)
    if not actor or not actor.getInventory then
        return false
    end
    local inventory = actor:getInventory()
    if not inventory then
        return false
    end
    local item = inventory:AddItem("EnergyRouting.WireTransferEnergy")
    if item and sendAddItemToContainer then
        sendAddItemToContainer(inventory, item)
    end
    if inventory.setDrawDirty then
        inventory:setDrawDirty(true)
    end
    return item ~= nil
end

function EN.LoadModData()
    local data = ModData.getOrCreate("EnergyNetwork")
    EN.modData = data
    EN.networks = data.networks or {}
    data.networks = EN.networks
end

function EN.SaveModData()
    if not EN.modData then
        return
    end
    EN.modData.networks = EN.networks
    ModData.transmit("EnergyNetwork")
end

function EN.CreateNetwork(masterObj)
    local square = getSquareFromObj(masterObj)
    if not square then
        return nil
    end

    local md = EN.EnsureBatteryMeta(masterObj)
    local netId = EnergyNetwork.MakeNetId(square:getX(), square:getY(), square:getZ())
    local batteryId = md.batteryId

    local net = {
        netId = netId,
        masterId = batteryId,
        slaveId = nil,
        panels = {},
    }
    EN.networks[netId] = net

    md.batteryNet.netId = netId
    md.batteryNet.role = "master"
    md.batteryNet.masterId = batteryId
    md.batteryNet.panels = md.batteryNet.panels or {}
    md.batteryNet.hasInput = md.batteryNet.hasInput or false
    if md.batteryNet.hasInput == nil then
        md.batteryNet.hasInput = false
    end
    md.batteryNet.slaveBatteryId = nil
    md.batteryNet.storage = md.batteryNet.storage or 0
    md.batteryNet.capacity = md.batteryNet.capacity or EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
    masterObj:transmitModData()

    EN.SaveModData()
    EN.EnsureEDC(masterObj, netId)

    return net
end

function EN.EnsureEDC(masterObj, netId)
    if not EnergyRouting or not EnergyRouting.Server or not EnergyRouting.Server.RegisterEDC then
        return
    end
    local square = getSquareFromObj(masterObj)
    if not square then
        return
    end
    EnergyRouting.Server.RegisterEDC(square, nil, netId)
end

function EN.GetNetworkByNetId(netId)
    return netId and EN.networks[netId] or nil
end

function EN.GetNetworkForBattery(obj)
    if not obj then
        return nil
    end
    local md = safeCall(obj, "getModData")
    local netId = md and md.batteryNet and md.batteryNet.netId or nil
    return EN.GetNetworkByNetId(netId)
end

function EN.GetMasterObj(net)
    if not net then
        return nil
    end
    return EN.GetBatteryById(net.masterId)
end

function EN.GetSlaveObj(net)
    if not net or not net.slaveId then
        return nil
    end
    return EN.GetBatteryById(net.slaveId)
end

function EN.ApplyConditionLoss(net, rate)
    if not net or not rate or rate <= 0 then
        return
    end
    local loss = rate * EnergyNetwork.GetConfigValue("ConditionLossRate")
    if loss <= 0 then
        return
    end
    local masterObj = EN.GetMasterObj(net)
    if not masterObj then
        return
    end
    local masterMd = masterObj:getModData()
    local masterNet = masterMd.batteryNet or {}

    local slaveObj = EN.GetSlaveObj(net)
    local splitLoss = loss
    if slaveObj then
        splitLoss = loss * 0.5
    end

    masterNet.condition = EnergyNetwork.Clamp((masterNet.condition or 1.0) - splitLoss, 0, 1)
    masterObj:transmitModData()

    if slaveObj then
        local slaveMd = slaveObj:getModData()
        local slaveNet = slaveMd.batteryNet or {}
        slaveNet.condition = EnergyNetwork.Clamp((slaveNet.condition or 1.0) - splitLoss, 0, 1)
        slaveMd.batteryNet = slaveNet
        slaveObj:transmitModData()
    end
end

function EN.ApplyFailureRisk(net, storage)
    local masterObj = EN.GetMasterObj(net)
    if not masterObj then
        return storage
    end
    local md = masterObj:getModData()
    local cond = md and md.batteryNet and md.batteryNet.condition or 1.0
    if cond >= 0.25 then
        return storage
    end
    if ZombRand(100) < 5 then
        local capacity = EN.GetTotalCapacity(net)
        return math.max(0, storage - (capacity * 0.10))
    end
    return storage
end

function EN.GetTotalCapacity(net)
    if not net then
        return 0
    end
    local masterObj = EN.GetMasterObj(net)
    if not masterObj then
        return 0
    end
    local masterMd = masterObj:getModData()
    local masterNet = masterMd.batteryNet or {}
    local baseCapacity = masterNet.capacity or EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
    local total = baseCapacity * EnergyNetwork.GetConditionMultiplier(masterNet.condition or 1.0)

    local slaveObj = EN.GetSlaveObj(net)
    if slaveObj then
        local slaveMd = slaveObj:getModData()
        local slaveNet = slaveMd.batteryNet or {}
        local slaveCapacity = slaveNet.capacity or baseCapacity
        total = total + (slaveCapacity * EnergyNetwork.GetConditionMultiplier(slaveNet.condition or 1.0))
    end
    return total
end

function EN.UpdateNetwork(net)
    local masterObj = EN.GetMasterObj(net)
    if not masterObj then
        return nil
    end

    local masterMd = masterObj:getModData()
    local masterNet = masterMd.batteryNet or {}
    masterNet.storage = masterNet.storage or 0

    local baseRate = EnergyNetwork.GetConfigValue("BaseChargeRate")
    local panelBonus = 0
    local panelCount = 0
    for _, panelId in ipairs(net.panels or {}) do
        local panelObj = EN.GetPanelById(panelId)
        if panelObj then
            panelCount = panelCount + 1
            panelBonus = panelBonus + EN.GetPanelBonus(panelObj)
        end
    end

    local roleInfo = "master=" .. tostring(net.masterId) .. ", slave=" .. tostring(net.slaveId or "none")
    logInfo("Net " .. tostring(net.netId) .. " panels=" .. tostring(panelCount) .. " (" .. roleInfo .. ")")

    local finalRate = 0
    if panelCount > 0 then
        finalRate = baseRate * (1 + panelBonus)
    end
    local weatherSnapshot = EnergyRouting.Weather.GetWeatherSnapshot()
    local weatherMultiplier = weatherSnapshot.multiplier or 1.0
    local production = finalRate * weatherMultiplier

    local totalCapacity = EN.GetTotalCapacity(net)
    local storage = masterNet.storage + production
    storage = EnergyNetwork.Clamp(storage, 0, totalCapacity)
    storage = EN.ApplyFailureRisk(net, storage)
    masterNet.storage = storage
    masterNet.totalCapacity = totalCapacity
    masterNet.lastProduction = production
    masterNet.lastWeather = weatherSnapshot.label or "Unknown"
    masterNet.capacity = masterNet.capacity or EnergyNetwork.GetConfigValue("BaseBatteryCapacity")
    masterMd.batteryNet = masterNet
    masterObj:transmitModData()

    EN.ApplyConditionLoss(net, production)

    if net.slaveId then
        logInfo("Battery roles: master=" .. tostring(net.masterId) .. " slave=" .. tostring(net.slaveId))
    else
        logInfo("Battery roles: master=" .. tostring(net.masterId) .. " slave=none")
    end

    return {
        storage = storage,
        production = production,
        weather = weatherSnapshot.label or "Unknown",
        panelCount = panelCount,
    }
end

function EN.GetSnapshotForEDC(edc)
    if not edc or not edc.id then
        return { available = 0, production = 0, storage = 0, weather = "Offline", weatherApplied = true }
    end
    local net = EN.networks[edc.id]
    if not net then
        return { available = 0, production = 0, storage = 0, weather = "No Network", weatherApplied = true }
    end
    local masterObj = EN.GetMasterObj(net)
    if not masterObj then
        return { available = 0, production = 0, storage = 0, weather = "Offline", weatherApplied = true }
    end
    local masterNet = masterObj:getModData().batteryNet or {}
    local storage = masterNet.storage or 0
    local production = masterNet.lastProduction or 0
    local weather = masterNet.lastWeather or "Unknown"

    return { available = storage, production = production, storage = storage, weather = weather, weatherApplied = true }
end

function EN.ApplyConsumption(edc, consumption)
    if not edc or not edc.id then
        return nil
    end
    local net = EN.networks[edc.id]
    if not net then
        return nil
    end
    if not consumption or consumption <= 0 then
        return nil
    end
    local masterObj = EN.GetMasterObj(net)
    if not masterObj then
        return nil
    end
    local masterMd = masterObj:getModData()
    local masterNet = masterMd.batteryNet or {}
    masterNet.storage = masterNet.storage or 0
    masterNet.storage = math.max(0, masterNet.storage - consumption)
    masterMd.batteryNet = masterNet
    masterObj:transmitModData()

    EN.ApplyConditionLoss(net, consumption)

    return masterNet.storage
end

function EN.DisconnectPanel(net, panelId, player)
    if not net or not panelId then
        return
    end
    local returnCable = false
    local panelObj = EN.GetPanelById(panelId)
    if panelObj then
        local md = panelObj:getModData()
        if md.panel then
            md.panel.connectedNet = nil
            md.panel.connectedBatteryId = nil
            if md.panel.cableAttached then
                returnCable = true
            end
            md.panel.cableAttached = nil
        end
        panelObj:transmitModData()
    end

    local newPanels = {}
    for _, id in ipairs(net.panels or {}) do
        if id ~= panelId then
            table.insert(newPanels, id)
        end
    end
    net.panels = newPanels

    local masterObj = EN.GetMasterObj(net)
    if masterObj then
        local masterMd = masterObj:getModData()
        local masterNet = masterMd.batteryNet or {}
        masterMd.batteryNet = masterNet
        updateBatteryPanelsMap(masterMd, newPanels)
        masterObj:transmitCompleteItemToClients()
        if panelObj then
            EnergyNetwork.Disconnect(panelObj, masterObj)
        end
    end

    if returnCable then
        EN.ReturnCable(player)
    end
    logInfo("Panel disconnected: panel=" .. tostring(panelId) .. " from net=" .. tostring(net.netId))
end

function EN.ClearPanelConnection(panelId, player)
    if not panelId then
        return
    end
    local panelObj = EN.GetPanelById(panelId)
    if panelObj then
        local md = panelObj:getModData()
        if md.panel then
            if md.panel.cableAttached then
                EN.ReturnCable(player)
            end
            md.panel.connectedNet = nil
            md.panel.cableAttached = nil
        end
        panelObj:transmitModData()
    end
end

function EN.DisconnectSlave(net, player)
    if not net or not net.slaveId then
        return
    end
    local returnCable = false
    local slaveObj = EN.GetSlaveObj(net)
    if slaveObj then
        local md = slaveObj:getModData()
        if md.batteryNet then
            if md.batteryNet.masterCable then
                returnCable = true
            end
            md.batteryNet.masterCable = nil
            md.batteryNet.netId = nil
            md.batteryNet.role = nil
            md.batteryNet.masterId = nil
        end
        slaveObj:transmitModData()
    end
    net.slaveId = nil

    local masterObj = EN.GetMasterObj(net)
    if masterObj then
        local masterMd = masterObj:getModData()
        local masterNet = masterMd.batteryNet or {}
        if masterNet.slaveCable then
            returnCable = true
        end
        masterNet.slaveCable = nil
        masterNet.slaveBatteryId = nil
        masterMd.batteryNet = masterNet
        masterObj:transmitModData()
    end

    if returnCable then
        EN.ReturnCable(player)
    end
    logInfo("Battery disconnect: master=" .. tostring(net.masterId) .. " slave=none")
end

function EN.RemoveNetwork(netId)
    local net = EN.networks[netId]
    if not net then
        return
    end
    for _, panelId in ipairs(net.panels or {}) do
        EN.DisconnectPanel(net, panelId)
    end
    EN.DisconnectSlave(net)
    local masterObj = EN.GetMasterObj(net)
    if masterObj then
        local md = masterObj:getModData()
        if md.batteryNet then
            md.batteryNet.netId = nil
            md.batteryNet.role = nil
            md.batteryNet.masterId = nil
            md.batteryNet.panels = nil
            md.batteryNet.hasInput = false
            md.batteryNet.slaveBatteryId = nil
        end
        masterObj:transmitModData()
    end
    EN.networks[netId] = nil
    if EnergyRouting and EnergyRouting.Server and EnergyRouting.Server.RemoveEDC then
        EnergyRouting.Server.RemoveEDC(netId)
    end
    EN.SaveModData()
end

function EN.ValidateNetwork(net)
    local mx, my, mz = EnergyNetwork.ParseCoordsFromId(net.masterId, "battery")
    local masterSquare = (mx and getSquare(mx, my, mz)) or nil
    if not masterSquare then
        return true
    end

    local masterObj = EN.GetMasterObj(net)
    if not masterObj then
        return false
    end

    local panelRadius = EnergyNetwork.GetConfigValue("PanelConnectRadius")
    local panels = {}
    for _, panelId in ipairs(net.panels or {}) do
        local px, py, pz = EnergyNetwork.ParseCoordsFromId(panelId, "panel")
        local panelSquare = (px and getSquare(px, py, pz)) or nil
        if not panelSquare then
            table.insert(panels, panelId)
        else
            local panelObj = EN.GetPanelById(panelId)
            if panelObj then
                if withinRadius(panelSquare, masterSquare, panelRadius) then
                    local panelMd = panelObj:getModData()
                    if panelMd.panel and panelMd.panel.connectedNet == net.netId then
                        table.insert(panels, panelId)
                    else
                        EN.ClearPanelConnection(panelId)
                    end
                else
                    EN.ClearPanelConnection(panelId)
                end
            else
                -- Panel object not loaded yet: keep the link until the object appears.
                table.insert(panels, panelId)
            end
        end
    end
    net.panels = panels

    local masterMd = masterObj:getModData()
    if masterMd and masterMd.batteryNet then
        updateBatteryPanelsMap(masterMd, panels)
        masterObj:transmitCompleteItemToClients()
    end

    if net.slaveId then
        local sx, sy, sz = EnergyNetwork.ParseCoordsFromId(net.slaveId, "battery")
        local slaveSquare = (sx and getSquare(sx, sy, sz)) or nil
        if slaveSquare then
            local slaveObj = EN.GetSlaveObj(net)
            local batteryRadius = EnergyNetwork.GetConfigValue("BatteryConnectRadius")
            if slaveObj then
                if not withinRadius(slaveSquare, masterSquare, batteryRadius) then
                    EN.DisconnectSlave(net)
                end
            else
                -- Slave object not loaded yet: keep the link until the object appears.
            end
        end
    end

    return true
end

function EN.TickNetworks()
    for _, net in pairs(EN.networks) do
        if EN.ValidateNetwork(net) then
            EN.EnsureEDC(EN.GetMasterObj(net), net.netId)
            EN.UpdateNetwork(net)
        else
            EN.RemoveNetwork(net.netId)
        end
    end
end

function EN.ConnectPanelToBattery(player, panelObj, batteryObj)
    if not panelObj or not batteryObj then
        return false
    end
    local panelSquare = getSquareFromObj(panelObj)
    local batterySquare = getSquareFromObj(batteryObj)
    if not panelSquare or not batterySquare then
        return false
    end
    if not withinRadius(panelSquare, batterySquare, EnergyNetwork.GetConfigValue("PanelConnectRadius")) then
        return false
    end
    if player and not EN.PlayerHasCable(player) then
        return false
    end

    local panelMd = EN.EnsurePanelMeta(panelObj)
    local batteryMd = EN.EnsureBatteryMeta(batteryObj)
    if not panelMd or not batteryMd then
        return false
    end

    panelMd.panel = panelMd.panel or {}
    panelMd.panel.panelId = panelMd.panel.panelId
        or EnergyNetwork.MakePanelId(panelSquare:getX(), panelSquare:getY(), panelSquare:getZ())

    if panelMd.panel.connectedNet then
        return false
    end

    local net = nil
    if batteryMd.batteryNet and batteryMd.batteryNet.netId then
        net = EN.networks[batteryMd.batteryNet.netId]
    end
    if not net then
        net = EN.CreateNetwork(batteryObj)
        batteryMd = batteryObj:getModData()
    end
    if not net then
        return false
    end

    net.panels = net.panels or {}
    if listHasId(net.panels, panelMd.panel.panelId) then
        return false
    end

    local maxPanels = EnergyNetwork.GetConfigValue("MaxPanels")
    if #net.panels >= maxPanels then
        return false
    end

    table.insert(net.panels, panelMd.panel.panelId)
    panelMd.panel.connectedNet = net.netId
    panelMd.panel.connectedBatteryId = batteryMd.batteryId
    panelMd.panel.cableAttached = true

    updateBatteryPanelsMap(batteryMd, net.panels)

    EnergyNetwork.Connect(panelObj, batteryObj)
    if batteryObj.transmitModData then
        batteryObj:transmitModData()
    end
    if panelObj.transmitModData then
        panelObj:transmitModData()
    end

    EN.SaveModData()
    if player then
        EN.ConsumeCable(player)
    end
    logInfo("Panel connected: panel=" .. tostring(panelMd.panel.panelId) .. " net=" .. tostring(net.netId))
    return true
end

function EN.ConnectBatteryToBattery(player, batteryA, batteryB)
    if not batteryA or not batteryB then
        return false
    end
    local squareA = getSquareFromObj(batteryA)
    local squareB = getSquareFromObj(batteryB)
    if not squareA or not squareB then
        return false
    end
    if not withinRadius(squareA, squareB, EnergyNetwork.GetConfigValue("BatteryConnectRadius")) then
        return false
    end
    if player and not EN.PlayerHasCable(player) then
        return false
    end

    local mdA = EN.EnsureBatteryMeta(batteryA)
    local mdB = EN.EnsureBatteryMeta(batteryB)
    if not mdA or not mdB then
        return false
    end
    if mdB.batteryNet and mdB.batteryNet.netId then
        return false
    end
    if mdA.batteryNet and mdA.batteryNet.role == "slave" then
        return false
    end

    local net = nil
    if mdA.batteryNet and mdA.batteryNet.netId then
        net = EN.networks[mdA.batteryNet.netId]
    end
    if not net then
        net = EN.CreateNetwork(batteryA)
        mdA = batteryA:getModData()
    end
    if not net then
        return false
    end
    if net.slaveId then
        return false
    end

    local maxBatteries = EnergyNetwork.GetConfigValue("MaxBatteries")
    if maxBatteries and maxBatteries < 2 then
        return false
    end

    net.slaveId = mdB.batteryId
    mdA.batteryNet = mdA.batteryNet or {}
    mdA.batteryNet.slaveBatteryId = mdB.batteryId
    mdA.batteryNet.slaveCable = true

    mdB.batteryNet = mdB.batteryNet or {}
    mdB.batteryNet.netId = net.netId
    mdB.batteryNet.role = "slave"
    mdB.batteryNet.masterId = net.masterId or mdA.batteryId
    mdB.batteryNet.masterCable = true

    if batteryA.transmitModData then
        batteryA:transmitModData()
    end
    if batteryB.transmitModData then
        batteryB:transmitModData()
    end

    EN.SaveModData()
    if player then
        EN.ConsumeCable(player)
    end
    logInfo("Battery connected: master=" .. tostring(net.masterId) .. " slave=" .. tostring(mdB.batteryId))
    return true
end

function EN.ConnectPanel(player, panelObj, batteryObj)
    return EN.ConnectPanelToBattery(player, panelObj, batteryObj)
end

function EN.ConnectBattery(player, batteryA, batteryB)
    return EN.ConnectBatteryToBattery(player, batteryA, batteryB)
end

function EN.RepairBattery(player, batteryObj)
    if not player or not batteryObj then
        return false
    end
    local md = EN.EnsureBatteryMeta(batteryObj)
    if not md or not md.batteryNet then
        return false
    end

    local skill = player:getPerkLevel(Perks.Electricity)
    if skill < 4 then
        return false
    end

    local inventory = player:getInventory()
    if not inventory then
        return false
    end
    if not inventory:contains("Base.Screwdriver") then
        return false
    end
    if not inventory:contains("Base.ElectronicsScrap") then
        return false
    end
    if not inventory:contains("Base.ElectricalParts") then
        return false
    end

    inventory:RemoveOneOf("Base.ElectronicsScrap")
    inventory:RemoveOneOf("Base.ElectricalParts")

    local minRepair = EnergyNetwork.GetConfigValue("RepairMin")
    local maxRepair = EnergyNetwork.GetConfigValue("RepairMax")
    local delta = minRepair + ((maxRepair - minRepair) * randFloat())
    md.batteryNet.condition = EnergyNetwork.Clamp((md.batteryNet.condition or 1.0) + delta, 0, EnergyNetwork.GetConfigValue("MaxRepairCondition"))
    batteryObj:transmitModData()
    return true
end

function EN.OnObjectAdded(obj)
    if EN.IsBatteryTankObject(obj) then
        EN.EnsureBatteryMeta(obj)
        obj:transmitModData()
    elseif EN.IsSolarPanelObject(obj) then
        EN.EnsurePanelMeta(obj)
        obj:transmitModData()
    end
end

function EN.OnObjectRemoved(obj)
    if EN.IsSolarPanelObject(obj) then
        local md = safeCall(obj, "getModData")
        if md and md.panel and md.panel.connectedNet then
            local net = EN.networks[md.panel.connectedNet]
            if net then
                EN.DisconnectPanel(net, md.panel.panelId)
                EN.SaveModData()
            end
        end
    elseif EN.IsBatteryTankObject(obj) then
        local md = safeCall(obj, "getModData")
        if md and md.batteryNet and md.batteryNet.netId then
            local net = EN.networks[md.batteryNet.netId]
            if net then
                if md.batteryNet.role == "master" then
                    EN.RemoveNetwork(net.netId)
                else
                    EN.DisconnectSlave(net)
                    EN.SaveModData()
                end
            end
        end
    end
end

function EN.OnClientCommand(module, command, player, args)
    local modId = (EnergyRouting and EnergyRouting.MOD_ID) or "EnergyRouting"
    if module ~= modId then
        return
    end
    if command == "ConnectPanelToBattery" and args then
        local panelSquare = args.panelSquare and getSquare(args.panelSquare.x, args.panelSquare.y, args.panelSquare.z)
        local batterySquare = args.batterySquare and getSquare(args.batterySquare.x, args.batterySquare.y, args.batterySquare.z)
        local panelObj = EN.FindObjectOnSquare(panelSquare, EN.IsSolarPanelObject)
        local batteryObj = EN.FindObjectOnSquare(batterySquare, EN.IsBatteryTankObject)
        if panelObj and batteryObj then
            EN.ConnectPanelToBattery(player, panelObj, batteryObj)
        end
    elseif command == "ConnectBatteryToBattery" and args then
        local squareA = args.batteryASquare and getSquare(args.batteryASquare.x, args.batteryASquare.y, args.batteryASquare.z)
        local squareB = args.batteryBSquare and getSquare(args.batteryBSquare.x, args.batteryBSquare.y, args.batteryBSquare.z)
        local batteryA = EN.FindObjectOnSquare(squareA, EN.IsBatteryTankObject)
        local batteryB = EN.FindObjectOnSquare(squareB, EN.IsBatteryTankObject)
        if batteryA and batteryB then
            EN.ConnectBatteryToBattery(player, batteryA, batteryB)
        end
    elseif command == "DisconnectPanel" and args then
        local panelSquare = args.panelSquare and getSquare(args.panelSquare.x, args.panelSquare.y, args.panelSquare.z)
        local panelObj = EN.FindObjectOnSquare(panelSquare, EN.IsSolarPanelObject)
        if panelObj then
            local md = panelObj:getModData()
            if md and md.panel and md.panel.connectedNet then
                local net = EN.networks[md.panel.connectedNet]
                if net then
                    local panelId = md.panel.panelId
                    if not panelId and panelSquare then
                        panelId = EnergyNetwork.MakePanelId(panelSquare:getX(), panelSquare:getY(), panelSquare:getZ())
                        md.panel.panelId = panelId
                    end
                    EN.DisconnectPanel(net, panelId, player)
                    EN.SaveModData()
                end
            end
        end
    elseif command == "DisconnectBattery" and args then
        local square = args.batterySquare and getSquare(args.batterySquare.x, args.batterySquare.y, args.batterySquare.z)
        local batteryObj = EN.FindObjectOnSquare(square, EN.IsBatteryTankObject)
        if batteryObj then
            local md = batteryObj:getModData()
            if md and md.batteryNet and md.batteryNet.netId then
                local net = EN.networks[md.batteryNet.netId]
                if net and net.slaveId then
                    EN.DisconnectSlave(net, player)
                    EN.SaveModData()
                end
            end
        end
    elseif command == "RepairBattery" and args then
        local square = args.batterySquare and getSquare(args.batterySquare.x, args.batterySquare.y, args.batterySquare.z)
        local batteryObj = EN.FindObjectOnSquare(square, EN.IsBatteryTankObject)
        if batteryObj then
            EN.RepairBattery(player, batteryObj)
        end
    end
end

function EN.BindRouting()
    if EnergyRouting and EnergyRouting.RegisterEnergyProvider then
        EnergyRouting.RegisterEnergyProvider(function(edc)
            return EN.GetSnapshotForEDC(edc)
        end)
    end
    if EnergyRouting and EnergyRouting.RegisterEnergyConsumer then
        EnergyRouting.RegisterEnergyConsumer(function(edc, consumption)
            return EN.ApplyConsumption(edc, consumption)
        end)
    end
end

Events.OnInitGlobalModData.Add(EN.LoadModData)
Events.OnObjectAdded.Add(EN.OnObjectAdded)
if Events.OnObjectAboutToBeRemoved then
    Events.OnObjectAboutToBeRemoved.Add(EN.OnObjectRemoved)
elseif Events.OnObjectRemoved then
    Events.OnObjectRemoved.Add(EN.OnObjectRemoved)
end
Events.OnClientCommand.Add(EN.OnClientCommand)

EN.BindRouting()

