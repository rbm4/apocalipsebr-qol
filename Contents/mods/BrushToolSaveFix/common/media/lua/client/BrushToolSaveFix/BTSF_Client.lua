require "BrushToolSaveFix/BTSF_Shared"

local MODULE = BrushToolSaveFix.MODULE
local hookedCreate = false

local function sendPlace(character, x, y, z, sprite)
    sendClientCommand(character, MODULE, "placeTile", {
        x = x,
        y = y,
        z = z,
        sprite = sprite,
    })
end

local function sendDestroy(character, obj)
    if not obj or not obj:getSquare() or not obj:getSprite() then
        return
    end

    local square = obj:getSquare()
    sendClientCommand(character, MODULE, "destroyTile", {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        index = obj:getObjectIndex(),
        sprite = obj:getSprite():getName(),
    })
end

local function destroyTile(obj, playerObj)
    if isClient() then
        sendDestroy(playerObj, obj)
        return
    end

    if obj and obj:getSquare() then
        obj:getSquare():transmitRemoveItemFromSquare(obj)
    end
end

local function setTileCursor(tilename, playerObj)
    local cursor = ISBrushToolTileCursor:new(tilename, tilename, playerObj)
    getCell():setDrag(cursor, playerObj:getPlayerNum())
end

-- Vanilla defines ISBrushToolTileCursor in lua/server, which is not always
-- available when client mod scripts first load. Hook after it exists.
local function hookCreate()
    if hookedCreate then
        return true
    end
    if not ISBrushToolTileCursor or type(ISBrushToolTileCursor.create) ~= "function" then
        return false
    end

    local _create = ISBrushToolTileCursor.create
    function ISBrushToolTileCursor:create(x, y, z, north, sprite)
        if isClient() then
            sendPlace(self.character, x, y, z, sprite)
            return
        end
        return _create(self, x, y, z, north, sprite)
    end

    hookedCreate = true
    BrushToolSaveFix.log("hooked ISBrushToolTileCursor.create")
    return true
end

local function onTickHook()
    if hookCreate() then
        Events.OnTick.Remove(onTickHook)
    end
end

Events.OnGameStart.Add(hookCreate)
Events.OnCreatePlayer.Add(function()
    hookCreate()
end)
Events.OnTick.Add(onTickHook)
hookCreate()

ISWorldObjectContextMenu.doBrushToolOptions = function(context, worldobjects, player)
    local playerObj = getSpecificPlayer(player)

    local addTooltip = function(option, spriteName)
        local tooltip = ISToolTip:new()
        tooltip:initialise()
        tooltip:setName("")
        tooltip:setTexture(spriteName)
        option.toolTip = tooltip
    end

    context:addOption("Brush Tool Manager", playerObj, BrushToolManager.openPanel)

    local copyOption = context:addOption("Copy tile", worldobjects)
    local copySubMenu = context:getNew(context)
    context:addSubMenu(copyOption, copySubMenu)

    local destroyOption = context:addOption("Destroy tile", worldobjects)
    local destroySubMenu = context:getNew(context)
    context:addSubMenu(destroyOption, destroySubMenu)

    for _, obj in ipairs(worldobjects) do
        if obj:getSprite() ~= nil and obj:getSprite():getName() ~= nil then
            local opt = copySubMenu:addOption("[MAIN] " .. obj:getSprite():getName(), obj:getSprite():getName(), setTileCursor, playerObj)
            addTooltip(opt, obj:getSprite():getName())
            opt = destroySubMenu:addOption(obj:getSprite():getName(), obj, destroyTile, playerObj)
            addTooltip(opt, obj:getSprite():getName())
        end

        if obj:getOverlaySprite() ~= nil and obj:getOverlaySprite():getName() ~= nil then
            local opt = copySubMenu:addOption("[OVERLAY] " .. obj:getOverlaySprite():getName(), obj:getOverlaySprite():getName(), setTileCursor, playerObj)
            addTooltip(opt, obj:getOverlaySprite():getName())
        end

        local attachedSprites = obj:getAttachedAnimSprite()
        if attachedSprites ~= nil then
            for i = 0, attachedSprites:size() - 1 do
                local sprite = attachedSprites:get(i):getParentSprite()
                if sprite and sprite:getName() ~= nil then
                    local opt = copySubMenu:addOption("[ATTACHED] " .. sprite:getName(), sprite:getName(), setTileCursor, playerObj)
                    addTooltip(opt, sprite:getName())
                end
            end
        end
    end
end
