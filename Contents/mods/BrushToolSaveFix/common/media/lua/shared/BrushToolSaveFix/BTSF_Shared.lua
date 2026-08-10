BrushToolSaveFix = BrushToolSaveFix or {}

BrushToolSaveFix.MODULE = "BrushToolSaveFix"
BrushToolSaveFix.VERSION = "1.0.0"

function BrushToolSaveFix.log(msg)
    if getDebug and getDebug() then
        print("[BrushToolSaveFix] " .. tostring(msg))
    end
end

function BrushToolSaveFix.canUseBrush(player)
    if not player then
        return false
    end

    if player.isCanUseBrushTool and player:isCanUseBrushTool() then
        return true
    end

    if player.getAccessLevel then
        local level = string.lower(tostring(player:getAccessLevel() or ""))
        if level == "admin" or level == "moderator" or level == "overseer" or level == "gm" then
            return true
        end
    end

    return false
end

function BrushToolSaveFix.getOrCreateSquare(x, y, z)
    local cell = getCell()
    if not cell then
        return nil
    end

    local square = cell:getGridSquare(x, y, z)
    if square == nil then
        square = cell:createNewGridSquare(x, y, z, true)
    end
    return square
end

function BrushToolSaveFix.placeTileOnSquare(square, sprite)
    if not square or not sprite or sprite == "" then
        return false
    end

    local objs = square:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj:getSprite() ~= nil and obj:getSprite():getName() == sprite then
            return false
        end
    end

    local spriteObj = getSprite(sprite)
    if not spriteObj then
        BrushToolSaveFix.log("missing sprite " .. tostring(sprite))
        return false
    end

    local props = ISMoveableSpriteProps.new(IsoObject.new(square, sprite):getSprite())
    props.rawWeight = 10
    props:placeMoveableInternal(square, instanceItem("Base.Plank"), sprite)

    if buildUtil and buildUtil.setHaveConstruction then
        buildUtil.setHaveConstruction(square, true)
    end

    return true
end

function BrushToolSaveFix.destroyTileOnSquare(square, sprite, index)
    if not square then
        return false
    end

    local objs = square:getObjects()
    local target = nil

    if type(index) == "number" and index >= 0 and index < objs:size() then
        local candidate = objs:get(index)
        if candidate and candidate:getSprite() and candidate:getSprite():getName() == sprite then
            target = candidate
        end
    end

    if not target and sprite then
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if obj:getSprite() ~= nil and obj:getSprite():getName() == sprite then
                target = obj
                break
            end
        end
    end

    if not target then
        return false
    end

    square:transmitRemoveItemFromSquare(target)
    return true
end
