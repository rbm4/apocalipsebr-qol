local MOD = "RemoveCropFix"

local DEBUG = getCore():getDebug()

local function log(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][C] " .. tostring(msg))
    end
end

local version = require("EuryBugs/_Version")
if not (version and version.isAtMax("42.13.1")) then
    log("skipped patch")
    return
end

require "Farming/ISUI/ISFarmingMenu"
require "Farming/TimedActions/ISShovelAction"
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISWorldObjectContextMenu"
require "Farming/BuildingObjects/ISFarmingCursorMouse"

local function isJoypadCharacter(character)
    if not (character and character.getPlayerNum) then return false end
    if not (JoypadState and JoypadState.players) then return false end
    return JoypadState.players[character:getPlayerNum() + 1] ~= nil
end

local function sqStr(sq)
    if not sq then return "nil" end
    return tostring(sq:getX()) .. "," .. tostring(sq:getY()) .. "," .. tostring(sq:getZ())
end

local function patch()
    if not ISFarmingMenu then return end
    if ISFarmingMenu.__EURY_RemoveCrop_VanillaPatched then return end
    ISFarmingMenu.__EURY_RemoveCrop_VanillaPatched = true

    ISFarmingMenu.onShovel = function(worldobjects, plant, playerObj, sq)
        log("onShovel enter sq " .. sqStr(sq) .. " plant " .. tostring(plant))

        if not ISFarmingMenu.walkToPlant(playerObj, sq) then
            log("onShovel walkToPlant false")
            return
        end

        local handItem = ISWorldObjectContextMenu.equip(
            playerObj,
            playerObj:getPrimaryHandItem(),
            ISFarmingMenu.getShovel(playerObj),
            true
        )

        log("onShovel equipped " .. tostring(handItem and (handItem.getFullType and handItem:getFullType() or handItem) or "nil"))

        if not isJoypadCharacter(playerObj) then
            log("onShovel queue ISShovelAction sq " .. sqStr(sq))
            ISTimedActionQueue.add(ISShovelAction:new(playerObj, handItem, nil, 40, sq:getX(), sq:getY(), sq:getZ()))
        else
            log("onShovel joypad true not queuing immediately")
        end

        ISFarmingMenu.cursor = ISFarmingCursorMouse:new(playerObj, ISFarmingMenu.onShovelSquareSelected, ISFarmingMenu.isShovelValid)
        getCell():setDrag(ISFarmingMenu.cursor, playerObj:getPlayerNum())
    end

    ISFarmingMenu.onShovelSquareSelected = function()
        local cursor = ISFarmingMenu.cursor
        local playerObj = cursor.character
        log("onShovelSquareSelected enter sq " .. sqStr(cursor.sq))

        if not ISFarmingMenu.walkToPlant(playerObj, cursor.sq) then
            log("onShovelSquareSelected walkToPlant false")
            return
        end

        local handItem = ISWorldObjectContextMenu.equip(
            playerObj,
            playerObj:getPrimaryHandItem(),
            ISFarmingMenu.getShovel(playerObj),
            true
        )

        log("onShovelSquareSelected queue ISShovelAction sq " .. sqStr(cursor.sq))
        ISTimedActionQueue.add(ISShovelAction:new(playerObj, handItem, cursor.sq, 40))
    end

    log("patched ISFarmingMenu shovel remove with ISShovelAction logging")
end

Events.OnGameStart.Add(patch)
