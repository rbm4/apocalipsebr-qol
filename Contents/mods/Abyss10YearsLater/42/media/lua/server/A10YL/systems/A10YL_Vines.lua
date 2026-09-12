local Data = require("A10YL/core/A10YL_Data")
local Random = require("A10YL/core/A10YL_Random")
local Mutations = require("A10YL/core/A10YL_Mutations")
local Validation = require("A10YL/core/A10YL_Validation")
local Context = require("A10YL/core/A10YL_Context")
local BuildingProfile = require("A10YL/core/A10YL_BuildingProfile")
local Protection = require("A10YL/core/A10YL_Protection")

local Clearing = require("A10YL/A10YL_Clearing")

local Vines = {}

local function classifyWall(properties, textureName)
    local propertyNames = properties:getPropertyNames()
    local isLowWall = luautils.stringStarts(textureName, "fixtures_railings")
        or propertyNames:contains("FenceTypeLow")

    if propertyNames:contains("WallNW") then
        return "NW", isLowWall
    end

    if propertyNames:contains("WallW")
        or propertyNames:contains("WindowW")
        or propertyNames:contains("doorW")
        or propertyNames:contains("DoorWallW")
        or propertyNames:contains("attachedW")
        or propertyNames:contains("WallWTrans")
    then
        return "W", isLowWall
    end

    if propertyNames:contains("WallN") or propertyNames:contains("WindowN") then
        return "N", isLowWall
    end

    return nil, isLowWall
end

local function getSpritePool(orientation, lowWall, continuation)
    if orientation == "NW" then
        if lowWall then return Data.getOutputPool("vinenwlow") end
        if continuation then return Data.getOutputPool("vinenwtop") end
        return Data.getOutputPool("vinenw")
    elseif orientation == "W" then
        if lowWall then return Data.getOutputPool("vinewlow") end
        if continuation then return Data.getOutputPool("vinewtop") end
        return Data.getOutputPool("vinew")
    elseif orientation == "N" then
        if lowWall then return Data.getOutputPool("vinenlow") end
        if continuation then return Data.getOutputPool("vinentop") end
        return Data.getOutputPool("vinen")
    end
    return nil
end

local function eligibleTexture(square, textureName)
    if square:getZ() == 0 then
        return luautils.stringStarts(textureName, "walls_")
            or luautils.stringStarts(textureName, "fixtures_")
            or luautils.stringStarts(textureName, "fencing_")
            or (luautils.stringStarts(textureName, "location_")
                and not luautils.stringStarts(textureName, "walls_detailling"))
    end

    return luautils.stringStarts(textureName, "walls_")
        and not luautils.stringStarts(textureName, "walls_detailling")
        and not luautils.stringStarts(textureName, "walls_exterior_roofs")
        and not luautils.stringStarts(textureName, "walls_interior")
end

function Vines.planObject(square, obj, cfg, plan, context, profile)
    if not square or not obj or Protection.isProtectedObject(obj, square, context)
        or not cfg.features.vines or square:getRoom() ~= nil
        or not Validation.isCompatibilitySafeTarget("vines", obj, square)
    then
        return false
    end

    local textureName = obj:getTextureName()
    if not textureName then return false end
    textureName = tostring(textureName)
    if not eligibleTexture(square, textureName) then return false end

    local sprite = obj:getSprite()
    local properties = sprite and sprite:getProperties()
    if not properties then return false end

    local orientation, lowWall = classifyWall(properties, textureName)
    if not orientation then return false end

    local surface = context and context.surface or Context.classifySurface(square)
    if surface == Context.SURFACE.RAIL then return false end
    if profile == nil then
        profile = BuildingProfile.get(square) or BuildingProfile.getNearby(square)
    end
    local vineChance = BuildingProfile.weatherChance(cfg.vinePercentage, profile, "vines")
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local continuation = z > 0 and cfg.features.vineNeighbor and not lowWall
    local anchorZ = continuation and (z - 1) or z

    if Random.coordinatePercent(x, y, anchorZ, "vines:presence:" .. orientation) > vineChance then
        return false
    end

    local pool = getSpritePool(orientation, lowWall, continuation)
    local overlay = Random.coordinateElement(
        pool, x, y, anchorZ,
        "vines:sprite:" .. orientation .. (continuation and ":top" or ":base")
    )
    if not overlay then return false end

    local target = Mutations.describeTarget(obj)
    if not target then return false end

    plan.operations[#plan.operations + 1] = {
        system = "vines",
        stage = 4,
        action = "add",
        slot = Mutations.semanticSlot(obj),
        spriteName = overlay,
        target = target,
        expectedTextureName = textureName,
        buildingKey = profile and profile.key or nil,
        buildingSignature = profile and profile.signature or nil,
    }
    return true
end

function Vines.applyOperation(square, operation)
    if not operation then return false end
    if Clearing.isSuppressed(square, operation.id) then
        return true, false
    end
    if Mutations.hasOwnedOperation(square, operation.id, "Vine") then
        return true, false
    end

    if not square or Protection.isProtectedSquare(square) or not operation or operation.action ~= "add"
        or not operation.spriteName or not getSprite(operation.spriteName)
        or square:getRoom() ~= nil
        or Context.classifySurface(square) == Context.SURFACE.RAIL
        or not BuildingProfile.matchesSquareOrNearby(square, operation.buildingKey, operation.buildingSignature)
    then
        return false
    end
    if Mutations.hasSpriteObject(square, operation.spriteName) then
        return false
    end

    local target = Mutations.resolveObject(square, operation.target)
    if not target or Protection.isProtectedObject(target, square)
        or not Validation.isCompatibilitySafeTarget("vines", target, square)
        or tostring(target:getTextureName() or "") ~= tostring(operation.expectedTextureName or "")
    then
        return false
    end

    local obj = IsoObject.new(getCell(), square, operation.spriteName)
    if not obj then return false end

    if not Mutations.tagOwnedObject(obj, "Vine", operation.id) then
        return false, false
    end
    if not Mutations.addTileObject(square, obj) then
        return false, false
    end
    return true, true
end

return Vines
