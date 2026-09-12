-- Core square safety checks backed by the checkpoint-41 contextual surface
-- classifier. The old blends_natural road fallback is intentionally gone.
local Context = require("A10YL/core/A10YL_Context")
local Compatibility = require("A10YL/core/A10YL_Compatibility")
local Protection = require("A10YL/core/A10YL_Protection")

local SquareCheck = {}

function SquareCheck.checkSquare(square, knownSurface)
    if not square or Protection.isProtectedSquare(square) then return false end
    local surface = knownSurface or Context.classifySurface(square)
    if surface == Context.SURFACE.WATER or surface == Context.SURFACE.PROTECTED
        or surface == Context.SURFACE.INVALID or surface == Context.SURFACE.INTERIOR
    then
        return false
    end
    if Compatibility.isSquareExcluded("vegetation", square) then return false end
    if square:HasStairs() or not square:hasFloor(true) then return false end
    if square:getDoor(true) or square:getDoor(false) or square:haveDoor() then return false end

    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            local sprite = obj and obj:getSprite()
            local properties = sprite and sprite:getProperties()
            if properties and properties:isTable() and properties:isTableTop() then
                return false
            end
        end
    end

    if square:isSolid() or square:isSolidTrans() then return false end

    for i = 1, #Context.offsets.cardinal do
        local offset = Context.offsets.cardinal[i]
        local nearby = Context.getOffsetSquare(square, offset[1], offset[2], 0)
        if nearby and square:getDoorFrameTo(nearby) then return false end
    end

    return true
end

function SquareCheck.checkWater(square, knownSurface)
    if Protection.isProtectedSquare(square) then return false end
    local surface = knownSurface or Context.classifySurface(square)
    return surface ~= Context.SURFACE.WATER
        and surface ~= Context.SURFACE.PROTECTED
        and surface ~= Context.SURFACE.INVALID
end

return SquareCheck
