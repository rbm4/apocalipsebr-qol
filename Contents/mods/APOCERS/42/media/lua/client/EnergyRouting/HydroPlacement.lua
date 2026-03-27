require "EnergyRouting/Init"
require "BuildingObjects/ISPlace3DItemCursor"
require "TimedActions/ISDropWorldItemAction"

if isServer() then
    return
end

if not ISPlace3DItemCursor then
    return
end

EnergyRouting = EnergyRouting or {}
EnergyRouting.HydroPlacement = EnergyRouting.HydroPlacement or {}
local HydroPlacement = EnergyRouting.HydroPlacement

local function isHydroItem(item)
    if not item then
        return false
    end
    local fullType = nil
    if item.getFullType then
        fullType = item:getFullType()
    elseif item.getType then
        fullType = item:getType()
    end
    if fullType == "EnergyRouting.TurbinaHidraulica" or fullType == "TurbinaHidraulica" then
        return true
    end
    if item.getDisplayName then
        local name = item:getDisplayName()
        if name == "Hydraulic Turbine" or name == "Turbina Hidraulica" then
            return true
        end
    end
    return false
end

HydroPlacement.IsHydroItem = isHydroItem

local function getHydroFloorSprite(square)
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

local function squareHasFlag(square, flag)
    if not square or not flag then
        return false
    end
    local props = square.getProperties and square:getProperties() or nil
    return props and props.has and props:has(flag) or false
end

local function isNaturalWaterSquare(square)
    if not square then
        return false
    end
    if square.isWater and square:isWater() then
        return true
    end
    local waterAmount = square.getWaterAmount and (tonumber(square:getWaterAmount()) or 0) or 0
    if waterAmount > 0 then
        return true
    end
    return squareHasFlag(square, IsoFlagType.water)
end

local function isValidHydroWaterSquare(square)
    if not square then
        return false
    end
    local spriteName = getHydroFloorSprite(square)
    if EnergyRouting and EnergyRouting.IsValidHydroSpriteName then
        if EnergyRouting.IsValidHydroSpriteName(spriteName) then
            return true
        end
    end
    if isNaturalWaterSquare(square) then
        return true
    end
    return false
end

HydroPlacement.IsValidWaterSquare = isValidHydroWaterSquare

local ADJACENT_OFFSETS = {
    { x = 0, y = -1 },
    { x = 1, y = 0 },
    { x = 0, y = 1 },
    { x = -1, y = 0 },
    { x = 1, y = -1 },
    { x = 1, y = 1 },
    { x = -1, y = 1 },
    { x = -1, y = -1 },
}

local function isValidLandAnchorSquare(square)
    if not square then
        return false
    end
    if isValidHydroWaterSquare(square) then
        return false
    end
    if not square.TreatAsSolidFloor or not square:TreatAsSolidFloor() then
        return false
    end
    if square.isSolid and square:isSolid() then
        return false
    end
    if square.isSolidTrans and square:isSolidTrans() then
        return false
    end
    return true
end

local function getSquareCoords(square)
    if not square then
        return nil
    end
    return {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    }
end

local function getAdjacentLandSquare(square, chr)
    if not square then
        return nil
    end
    local cell = getCell and getCell() or nil
    if not cell then
        return nil
    end
    local z = square:getZ()
    local x = square:getX()
    local y = square:getY()
    local best = nil
    local bestDist = nil
    local playerSquare = chr and chr.getCurrentSquare and chr:getCurrentSquare() or nil

    for _, offset in ipairs(ADJACENT_OFFSETS) do
        local candidate = cell:getGridSquare(x + offset.x, y + offset.y, z)
        if isValidLandAnchorSquare(candidate) then
            if not playerSquare then
                return candidate
            end
            local dist = candidate:DistToProper(playerSquare)
            if not bestDist or dist < bestDist then
                best = candidate
                bestDist = dist
            end
        end
    end
    return best
end

HydroPlacement.GetAdjacentLandSquare = getAdjacentLandSquare

local function markItemAsPlacedOverWater(item, waterSquare, anchorSquare)
    if not item or not item.getModData then
        return
    end
    local md = item:getModData()
    md.hydro = md.hydro or {}
    md.hydroPlacement = md.hydroPlacement or {}

    local waterCoords = getSquareCoords(waterSquare)
    local anchorCoords = getSquareCoords(anchorSquare)

    md.hydro.isOverWater = true
    md.hydro.placedOnWater = true
    md.hydro.waterSquare = waterCoords
    md.hydro.anchorSquare = anchorCoords

    md.hydroPlacement.isOverWater = true
    md.hydroPlacement.placedOnWater = true
    md.hydroPlacement.waterSquare = waterCoords
    md.hydroPlacement.anchorSquare = anchorCoords
end

local function hydroCursorIsValid(self, square)
    if not square then
        return false
    end
    if not self or not self.items or #self.items == 0 then
        return false
    end
    local item = self.items[1]
    if not isHydroItem(item) then
        return false
    end
    local chr = self.chr or self.character
    if not chr then
        return false
    end
    local currentSquare = chr:getCurrentSquare()
    if not currentSquare then
        return false
    end
    if chr:getVehicle() then
        return false
    end
    local maxPlacementDistance = 4
    if square:DistToProper(currentSquare) > maxPlacementDistance then
        return false
    end
    if not square:isCouldSee(chr:getPlayerNum()) then
        return false
    end
    if not isValidHydroWaterSquare(square) then
        return false
    end
    local adj = getAdjacentLandSquare(square, chr)
    if not adj then
        return false
    end
    if adj:DistToProper(currentSquare) > maxPlacementDistance then
        return false
    end
    if (adj:getTotalWeightOfItemsOnFloor() + item:getUnequippedWeight()) > 50 then
        return false
    end
    return true
end

local function hydroCursorCreate(self, x, y, z, north, sprite)
    local waterSquare = getCell() and getCell():getGridSquare(x, y, z) or nil
    if not waterSquare or not hydroCursorIsValid(self, waterSquare) then
        return
    end

    local item = self.items and self.items[1] or nil
    if not item then
        return
    end
    local chr = self.chr or self.character
    if not chr then
        return
    end

    local adj = getAdjacentLandSquare(waterSquare, chr)
    if not adj then
        return
    end
    if (adj:getTotalWeightOfItemsOnFloor() + item:getUnequippedWeight()) > 50 then
        return
    end

    markItemAsPlacedOverWater(item, waterSquare, adj)
    ISWorldObjectContextMenu.transferIfNeeded(chr, item)

    table.remove(self.items, 1)
    if chr:isEquipped(item) then
        ISTimedActionQueue.add(ISUnequipAction:new(chr, item, 1))
    end
    ISTimedActionQueue.add(ISDropWorldItemAction:new(
        chr,
        item,
        adj,
        0.5,
        0.5,
        0.0,
        self.render3DItemRot,
        false
    ))

    if #self.items > 0 then
        getCell():setDrag(self, chr:getPlayerNum())
    else
        self.keepOnSquare = false
    end
end

function HydroPlacement.NewCursor(playerObj, item)
    if not playerObj or not item or not isHydroItem(item) then
        return nil
    end
    local cursor = ISPlace3DItemCursor:new(playerObj, { item })
    cursor._energyRoutingHydro = true
    cursor.isValid = hydroCursorIsValid
    cursor.create = hydroCursorCreate
    return cursor
end
