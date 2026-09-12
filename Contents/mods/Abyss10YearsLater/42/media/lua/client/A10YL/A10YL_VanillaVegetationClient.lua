-- A10YL v0.8.7 player vegetation cleanup.
-- Keep the interaction in Project Zomboid's normal removal workflow:
-- Remove Bush / Remove Wall Vines / Remove Grass cursors and timed actions.
local Clearing = require("A10YL/A10YL_Clearing")
require("A10YL/A10YL_VanillaVegetationBridge")

local Client = {}

local function installCursorBridge()
    if not ISRemovePlantCursor or ISRemovePlantCursor.A10YL_VANILLA_BRIDGE then
        return false
    end

    local originalGetRemovableObject = ISRemovePlantCursor.getRemovableObject
    if type(originalGetRemovableObject) ~= "function" then
        return false
    end

    function ISRemovePlantCursor:getRemovableObject(square)
        local obj = originalGetRemovableObject(self, square)
        if obj then return obj end

        if self.removeType == "bush" then
            return Clearing.findOwned(square, "Bush")
        elseif self.removeType == "wallVine" then
            return Clearing.findOwned(square, "Vine")
        elseif self.removeType == "grass" then
            return Clearing.findOwnedGrass(square)
        end
        return nil
    end

    ISRemovePlantCursor.A10YL_VANILLA_BRIDGE = true
    return true
end

local function squareHasOwned(square, ownedType)
    return square ~= nil and Clearing.findOwned(square, ownedType) ~= nil
end

local function squareHasOwnedGrass(square)
    return square ~= nil and Clearing.findOwnedGrass(square) ~= nil
end

local function getRelevantSquares(worldobjects)
    local result = {}
    local seen = {}

    for _, object in ipairs(worldobjects or {}) do
        local square = object and object.getSquare and object:getSquare() or nil
        if square then
            local key = tostring(square:getX()) .. ":" .. tostring(square:getY()) .. ":" .. tostring(square:getZ())
            if not seen[key] then
                seen[key] = true
                result[#result + 1] = square
            end
        end
    end
    return result
end

local function addOptionOnce(context, label, target, callback, ...)
    if not context or not label or not callback then return nil end
    if context.getOptionFromName and context:getOptionFromName(label) then
        return nil
    end
    return context:addOption(label, target, callback, ...)
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    -- Vanilla normally creates these options from sprite flags/erosion-attached
    -- vines. A10YL wall vines are standalone owned overlays, so add the same
    -- vanilla entry only when vanilla did not already create it. The option
    -- launches the stock removal cursor/action; it is not an instant-delete
    -- mod command.
    if not ISWorldObjectContextMenu then return end

    local bushSquare, vineSquare, grassSquare = nil, nil, nil
    local squares = getRelevantSquares(worldobjects)
    for i = 1, #squares do
        local square = squares[i]
        if not bushSquare and squareHasOwned(square, "Bush") then bushSquare = square end
        if not vineSquare and squareHasOwned(square, "Vine") then vineSquare = square end
        if not grassSquare and squareHasOwnedGrass(square) then grassSquare = square end
        if bushSquare and vineSquare and grassSquare then break end
    end

    if not bushSquare and not vineSquare and not grassSquare then return end

    if test then
        if ISWorldObjectContextMenu.setTest then
            return ISWorldObjectContextMenu.setTest()
        end
        return true
    end

    if bushSquare and type(ISWorldObjectContextMenu.onRemovePlant) == "function" then
        addOptionOnce(
            context,
            getText("ContextMenu_RemoveBush"),
            worldobjects,
            ISWorldObjectContextMenu.onRemovePlant,
            bushSquare,
            false,
            playerNum
        )
    end

    if vineSquare and type(ISWorldObjectContextMenu.onRemovePlant) == "function" then
        addOptionOnce(
            context,
            getText("ContextMenu_RemoveWallVine"),
            worldobjects,
            ISWorldObjectContextMenu.onRemovePlant,
            vineSquare,
            true,
            playerNum
        )
    end

    if grassSquare and type(ISWorldObjectContextMenu.onRemoveGrass) == "function" then
        addOptionOnce(
            context,
            getText("ContextMenu_RemoveGrass"),
            worldobjects,
            ISWorldObjectContextMenu.onRemoveGrass,
            grassSquare,
            playerNum
        )
    end
end

local function install()
    installCursorBridge()
    if not Client.contextEventInstalled and Events.OnFillWorldObjectContextMenu and Events.OnFillWorldObjectContextMenu.Add then
        Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
        Client.contextEventInstalled = true
    end
end

install()
if Events.OnGameStart and Events.OnGameStart.Add then
    -- One retry covers unusual client load order without replacing vanilla files.
    Events.OnGameStart.Add(installCursorBridge)
end

return Client
