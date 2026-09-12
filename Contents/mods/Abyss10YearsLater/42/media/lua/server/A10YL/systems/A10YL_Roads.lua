-- Additive road/hardscape deterioration. Underlying floor semantics are never
-- deleted or replaced; rail corridors are deliberately left conservative.
local Random = require("A10YL/core/A10YL_Random")
local Mutations = require("A10YL/core/A10YL_Mutations")
local Validation = require("A10YL/core/A10YL_Validation")
local Context = require("A10YL/core/A10YL_Context")
local Protection = require("A10YL/core/A10YL_Protection")

local Roads = {}

local function targetSalt(prefix, square, target)
    return prefix .. ":" .. Mutations.targetKey(target) .. ":"
        .. tostring(square:getX()) .. ":" .. tostring(square:getY()) .. ":" .. tostring(square:getZ())
end

local function append(plan, operation)
    operation.system = "roads"
    operation.stage = 3
    plan.operations[#plan.operations + 1] = operation
end

function Roads.planObject(square, obj, cfg, plan, context)
    if not square or Protection.isProtectedSquare(square, context) or not obj or not cfg or not plan or not cfg.features.cracks
        or obj ~= square:getFloor()
        or not Validation.isCompatibilitySafeTarget("roads", obj, square)
    then
        return false
    end

    local surface = context and context.surface or Context.classifySurface(square)
    if surface == Context.SURFACE.RAIL then
        -- Track tiles are not ordinary pavement; do not cover them with road
        -- crack overlays until a dedicated rail visual path is validated.
        return false
    end
    if surface ~= Context.SURFACE.ROAD and surface ~= Context.SURFACE.HARDSCAPE then
        return false
    end

    local target = Mutations.describeTarget(obj)
    if not target then return false end

    local x, y, z = square:getX(), square:getY(), square:getZ()
    local chance = surface == Context.SURFACE.ROAD
        and (tonumber(cfg.roadCrackOverlayPercentage) or 0)
        or (tonumber(cfg.dirtCrackOverlayPercentage) or 0)

    local contextClass
    if surface == Context.SURFACE.ROAD then
        contextClass = context and context.roadClass or Context.getRoadClass(square, surface)
    else
        contextClass = context and context.hardscapeClass or Context.getHardscapeClass(square, surface)
    end

    -- Edge surfaces take slightly more ecological/weather pressure while the centre of
    -- broad hardscape remains more legible and traversable. Point #5 keeps this
    -- amplification deliberately mild so crack overlays do not form a continuous rim.
    if contextClass == "ROAD_EDGE" or contextClass == "EXTERIOR_HARDSCAPE_EDGE" then
        chance = math.min(100, chance * 1.05)
    end

    if Random.coordinatePercent(x, y, z, targetSalt("roads:presence", square, target)) > chance then
        return false
    end

    local overlayIndex = Random.coordinateIndex(
        x, y, z, targetSalt("roads:index", square, target), 32
    )
    if not overlayIndex then return false end

    local overlayName
    if surface == Context.SURFACE.ROAD then
        local dirt = Random.coordinatePercent(
            x, y, z, targetSalt("roads:type", square, target)
        ) <= (contextClass == "ROAD_EDGE" and 20 or 8)
        overlayName = "blends_" .. (dirt and "dirt" or "street")
            .. "overlays_01_" .. tostring(overlayIndex - 1)
    else
        overlayName = "blends_dirtoverlays_01_" .. tostring(overlayIndex - 1)
    end

    append(plan, {
        action = "overlay",
        slot = "floor",
        target = target,
        overlayName = overlayName,
        expectedSurface = surface,
        contextClass = contextClass,
    })
    return true
end

function Roads.applyOperation(square, operation)
    if not square or Protection.isProtectedSquare(square) or not operation or operation.action ~= "overlay" then return false end
    if Context.classifySurface(square) ~= operation.expectedSurface then return false, false end

    local floor = Mutations.resolveObject(square, operation.target)
    if not floor or floor ~= square:getFloor()
        or not Validation.isCompatibilitySafeTarget("roads", floor, square)
        or not operation.overlayName or not getSprite(operation.overlayName)
    then
        return false, false
    end

    -- Migration from generator 25's standalone RoadOverlay object. If it
    -- survived, remove only that A10YL-owned object before attaching the same
    -- deterministic sprite to the persistent vanilla floor.
    local legacy = Mutations.findOwnedByOperationKey(square, operation.id, "RoadOverlay")
    if legacy == false then return false, false end
    if legacy then Mutations.removeOwnedObject(square, legacy) end

    if Mutations.hasAttachedSprite(floor, operation.overlayName) then
        return true, false
    end
    if not Mutations.addAttachedSprite(floor, operation.overlayName, operation.id, "RoadOverlay") then
        return false, false
    end
    return true, true
end

return Roads
