-- Deterministic four-layer vegetation planner. Visual density comes primarily
-- from ground cover and shrubs; collision-heavy trees remain sparse.
local Data = require("A10YL/core/A10YL_Data")
local Random = require("A10YL/core/A10YL_Random")
local SquareCheck = require("A10YL/core/A10YL_SquareCheck")
local Mutations = require("A10YL/core/A10YL_Mutations")
local Context = require("A10YL/core/A10YL_Context")
local Validation = require("A10YL/core/A10YL_Validation")
local BuildingProfile = require("A10YL/core/A10YL_BuildingProfile")
local Compatibility = require("A10YL/core/A10YL_Compatibility")
local Protection = require("A10YL/core/A10YL_Protection")
local AreaContext = require("A10YL/core/A10YL_AreaContext")

local Clearing = require("A10YL/A10YL_Clearing")

local Vegetation = {}

-- Percentages within the large-tree share. The locked total share is resolved
-- by Config (0/5/10/16/24%); context only redistributes or clamps its classes.
local LARGE_CLASS_WEIGHTS = {
    forest = { jumbo = 82, xl = 17, xxl = 1 },
    open = { jumbo = 85, xl = 14, xxl = 1 },
    constrained = { jumbo = 96, xl = 4, xxl = 0 },
    road = { jumbo = 100, xl = 0, xxl = 0 },
    interior = { jumbo = 100, xl = 0, xxl = 0 },
}

-- Mature-tree infill always uses full-size tree classes and is stricter than
-- the ordinary woody-succession tree planner. It is only called for natural
-- ground near existing tree seeds.
local MATURE_CLASS_WEIGHTS = {
    forest = { jumbo = 78, xl = 20, xxl = 2 },
    open = { jumbo = 88, xl = 12, xxl = 0 },
    constrained = { jumbo = 100, xl = 0, xxl = 0 },
}

local function isLargeGrowthClass(growthClass)
    return growthClass == "jumbo" or growthClass == "xl" or growthClass == "xxl"
end

local function chance(value)
    value = tonumber(value) or 0
    if value < 0 then
        return 0
    elseif value > 100 then
        return 100
    end
    return value
end

local function shouldPlace(square, percent, salt, patchScale)
    if not square then
        return false
    end

    percent = chance(percent)
    if percent <= 0 then
        return false
    elseif percent >= 100 then
        return true
    end

    local x, y, z = square:getX(), square:getY(), square:getZ()
    local localRoll = Random.coordinatePercent(x, y, z, salt)
    local patchRoll = Random.patchPercent(x, y, z, salt, patchScale or 5)
    local shift = math.floor((patchRoll - 50) * 0.30)
    local shiftedRoll = ((localRoll + shift - 1) % 100) + 1
    return shiftedRoll <= percent
end

local function squareHasTree(square)
    if not square then
        return false
    end

    local objects = square:getObjects()
    if not objects then
        return false
    end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and instanceof(obj, "IsoTree") then
            return true
        end
    end

    return false
end

local function squareHasA10YLBush(square)
    if not square then
        return false
    end

    local objects = square:getObjects()
    if not objects then
        return false
    end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            if Mutations.isOwnedObject(obj, "Bush") then
                return true
            end
        end
    end

    return false
end

local function isWallObject(obj)
    if not obj then
        return false
    end

    local sprite = obj:getSprite()
    local properties = sprite and sprite:getProperties()
    if not properties then
        return false
    end

    return properties:has("WallN")
        or properties:has("WallW")
        or properties:has("WallNW")
        or properties:has("WallNTrans")
        or properties:has("WallWTrans")
        or properties:has("DoorWallN")
        or properties:has("DoorWallW")
        or properties:has("WindowN")
        or properties:has("WindowW")
end

local function isObjectBlockingTree(square)
    if not square then
        return true
    end

    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj then
                if instanceof(obj, "IsoTree")
                    or instanceof(obj, "IsoThumpable")
                    or isWallObject(obj)
                    or Context.isBuiltContextObject(obj)
                    or Validation.hasPersistentStateAtRisk(obj)
                    or Compatibility.isSystemExcluded("vegetation", obj, square)
                then
                    return true
                end
            end
        end
    end

    return square:isVehicleIntersecting()
end

local function isLargeCandidateAt(x, y, z, cfg)
    local largeShare = chance(cfg and cfg.largeTreePercentage)
    return largeShare > 0
        and Random.coordinatePercent(x, y, z, "vegetation:tree-size") <= largeShare
end

local function isCoordinateWinner(square, salt, offsets, cfg)
    if not square or type(offsets) ~= "table" then
        return false
    end

    local x, y, z = square:getX(), square:getY(), square:getZ()
    local score = Random.coordinateHash(x, y, z, salt)

    for i = 1, #offsets do
        local offset = offsets[i]
        local neighbourX = x + offset[1]
        local neighbourY = y + offset[2]
        local neighbourZ = z + (offset[3] or 0)
        if isLargeCandidateAt(neighbourX, neighbourY, neighbourZ, cfg) then
            local neighbourScore = Random.coordinateHash(
                neighbourX, neighbourY, neighbourZ, salt
            )
            if neighbourScore > score
                or (neighbourScore == score and (
                    neighbourZ > z
                    or (neighbourZ == z and neighbourY > y)
                    or (neighbourZ == z and neighbourY == y and neighbourX > x)
                ))
            then
                return false
            end
        end
    end

    return true
end

local function largeTreeAreaBlocked(square, growthClass)
    local offsets = Context.offsets.treeClearance[growthClass] or {}
    return Context.anySquareAtOffsets(square, offsets, isObjectBlockingTree)
end

local function isTreeSpawnSquareValid(square, growthClass, cfg)
    if not square or not square:isSolidFloor() or isObjectBlockingTree(square) then
        return false
    end

    if isLargeGrowthClass(growthClass) then
        local offsets = Context.offsets.treeClearance[growthClass] or Context.offsets.adjacent
        if not isCoordinateWinner(square, "vegetation:large-tree-spacing", offsets, cfg) then
            return false
        end
        if largeTreeAreaBlocked(square, growthClass) then
            return false
        end
    end

    return true
end

local function hasLocalWoodySeed(square)
    return Context.hasTreeAtOffsets(square, Context.offsets.woodySeed)
end

local function scaledChance(value, factor)
    return chance((tonumber(value) or 0) * (tonumber(factor) or 0))
end

local function interiorGrowthChance(square, cfg, knownExposure, profile)
    local exposure = knownExposure or Context.getExposure(square)
    local baseChance = BuildingProfile.weatherChance(
        cfg.overgrowthInteriorPercentage, profile, "interiorIntrusion"
    )

    if exposure == Context.EXPOSURE.SEALED_INTERIOR then
        -- The exact opening damage is planned in the same ageing pass, so a
        -- breached-history building can otherwise look sealed while its room
        -- plan is built. Restrict this predictive intrusion to perimeter rooms.
        if BuildingProfile.isBreachedHistory(profile) and Context.isInteriorPerimeter(square) then
            return scaledChance(baseChance, 0.40), exposure, true
        end
        return 0, exposure, false
    elseif exposure == Context.EXPOSURE.BREACHED_INTERIOR then
        return scaledChance(baseChance, 0.70), exposure, false
    elseif exposure == Context.EXPOSURE.HEAVILY_EXPOSED_INTERIOR then
        return baseChance, exposure, false
    end
    return 0, exposure, false
end

local function append(plan, operation)
    operation.system = "vegetation"
    operation.stage = 1
    plan.operations[#plan.operations + 1] = operation
end

local function planDecoration(plan, square, spriteList, salt, surface)
    local spriteName = Random.coordinateElement(
        spriteList, square:getX(), square:getY(), square:getZ(), salt
    )
    if spriteName then
        local operation = {
            action = "decoration",
            slot = tostring(salt),
            spriteName = spriteName,
            surface = surface or "any",
        }
        append(plan, operation)
        return operation
    end
    return nil
end

local function planBush(plan, square, surface, slot)
    local randomBush = Random.coordinateElement(
        Data.getOutputPool("bush"), square:getX(), square:getY(), square:getZ(), "vegetation:bush-sprite"
    )
    if not randomBush then
        return
    end

    local leafSpriteName
    if Random.coordinatePercent(square:getX(), square:getY(), square:getZ(), "vegetation:bush-leaf-priority") <= 70 then
        leafSpriteName = Random.coordinateElement(
            Data.bushLeafPriority,
            square:getX(), square:getY(), square:getZ(), "vegetation:bush-leaf"
        )
    else
        leafSpriteName = Data.getBushLeafForBase(randomBush)
    end

    local operation = {
        action = "bush",
        slot = slot or ("bush-" .. tostring(surface or "any")),
        spriteName = randomBush,
        leafSpriteName = leafSpriteName,
        surface = surface or "any",
    }
    append(plan, operation)
    return operation
end

function Vegetation.selectTreeGrowthClass(square, cfg, surface)
    if not square or not cfg then return "standard", "constrained" end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local largeShare = tonumber(cfg.largeTreePercentage) or 0
    if largeShare <= 0
        or Random.coordinatePercent(x, y, z, "vegetation:tree-size") > largeShare
    then
        return "standard", Context.treeGrowthContext(square, surface)
    end

    local contextName = Context.treeGrowthContext(square, surface)
    local weights = LARGE_CLASS_WEIGHTS[contextName] or LARGE_CLASS_WEIGHTS.constrained
    local classRoll = Random.coordinatePercent(x, y, z, "vegetation:large-tree-class")
    if classRoll <= weights.jumbo then return "jumbo", contextName end
    if classRoll <= weights.jumbo + weights.xl then return "xl", contextName end
    return "xxl", contextName
end

function Vegetation.getLargeClassWeights(contextName)
    local weights = LARGE_CLASS_WEIGHTS[contextName] or LARGE_CLASS_WEIGHTS.constrained
    return { jumbo = weights.jumbo, xl = weights.xl, xxl = weights.xxl }
end

function Vegetation.selectMatureTreeGrowthClass(square, cfg, surface)
    if not square or not cfg then return nil, "constrained" end
    local contextName = Context.treeGrowthContext(square, surface)
    if contextName == "road" or contextName == "interior" then
        return nil, contextName
    end

    local weights = MATURE_CLASS_WEIGHTS[contextName] or MATURE_CLASS_WEIGHTS.constrained
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local classRoll = Random.coordinatePercent(x, y, z, "vegetation:mature-tree-class")
    if classRoll <= weights.jumbo then return "jumbo", contextName end
    if classRoll <= weights.jumbo + weights.xl then return "xl", contextName end
    return "xxl", contextName
end

local function matureTreeSeedFactor(square)
    if not square or not Context.offsets.matureTreeSeed then return 0 end
    local count = 0
    if Context.countTreeAtOffsets then
        count = Context.countTreeAtOffsets(square, Context.offsets.matureTreeSeed)
    elseif Context.hasTreeAtOffsets(square, Context.offsets.matureTreeSeed) then
        count = 1
    end
    if count <= 0 then return 0 end
    -- Slightly favour established clusters while keeping the extra full-size
    -- trees sparse across the presets. The base percentage remains the main
    -- control; this only makes real tree lines and woodland edges more likely
    -- than an isolated seed tree.
    return math.min(1.60, 1.00 + math.min(count - 1, 6) * 0.10)
end

local function planTree(plan, square, cfg, surface, slot, forcedGrowthClass, forcedContextName)
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local wantedClass, contextName
    if forcedGrowthClass then
        wantedClass = forcedGrowthClass
        contextName = forcedContextName or Context.treeGrowthContext(square, surface)
    else
        wantedClass, contextName = Vegetation.selectTreeGrowthClass(square, cfg, surface)
    end
    if not wantedClass or not isTreeSpawnSquareValid(square, wantedClass, cfg) then return nil end

    local pool = Data.getTreeGrowthPool(wantedClass)
    local randomTree = Random.coordinateElement(
        pool, x, y, z, "vegetation:tree-sprite:" .. wantedClass
    )
    if randomTree then
        local operation = {
            action = "tree",
            slot = slot or ("tree-" .. tostring(surface or "any")),
            spriteName = randomTree,
            growthClass = wantedClass,
            growthContext = contextName,
            largeTree = isLargeGrowthClass(wantedClass),
            matureTree = forcedGrowthClass ~= nil,
            surface = surface or "any",
        }
        append(plan, operation)
        return operation
    end
    return nil
end

local function planMatureTree(plan, square, cfg, surface)
    local growthClass, contextName = Vegetation.selectMatureTreeGrowthClass(square, cfg, surface)
    if not growthClass then return nil end
    return planTree(plan, square, cfg, surface, "natural-mature-tree", growthClass, contextName)
end

function Vegetation.planSquare(square, cfg, plan, context)
    if not square or not cfg or not plan then
        return
    end
    if Protection.isProtectedSquare(square, context) or Compatibility.isSquareExcluded("vegetation", square, context) then
        return
    end

    context = context or Context.describeSquare(square)
    local surface = context.surface
    local areaModifiers = context.areaModifiers or AreaContext.vegetationMultipliers(context.areaType)
    if not square:isSolidFloor() or not SquareCheck.checkWater(square, surface) then
        return
    end

    local z = square:getZ()

    -- Sealed interiors never receive terrestrial overgrowth. Breached interiors
    -- can receive only lightweight intrusion, with sparse shrubs reserved for
    -- heavily exposed ground-floor squares. Trees are never planned indoors.
    if surface == Context.SURFACE.INTERIOR then
        local profile = BuildingProfile.get(square)
        local interiorChance, exposure, historicalBreach = interiorGrowthChance(
            square, cfg, context.exposure, profile
        )
        if interiorChance <= 0 then return end

        if z == 0 and exposure == Context.EXPOSURE.HEAVILY_EXPOSED_INTERIOR
            and shouldPlace(square, scaledChance(interiorChance, 0.35), "vegetation:interior-bush", 5)
        then
            local operation = planBush(plan, square, surface, "interior-bush")
            if operation then
                operation.exposure = exposure
                operation.allowHistoricalBreach = false
                operation.buildingKey = profile and profile.key or nil
                operation.buildingSignature = profile and profile.signature or nil
            end
        end
        if shouldPlace(square, interiorChance, "vegetation:interior-grass", 4) then
            local operation = planDecoration(plan, square, Data.getOutputPool("grass"), "vegetation:interior-grass-sprite", surface)
            if operation then
                operation.exposure = exposure
                operation.allowHistoricalBreach = historicalBreach == true
                operation.buildingKey = profile and profile.key or nil
                operation.buildingSignature = profile and profile.signature or nil
            end
        end
        if shouldPlace(square, scaledChance(interiorChance, 0.70), "vegetation:interior-leaves", 4) then
            local operation = planDecoration(plan, square, Data.getOutputPool("leaf"), "vegetation:interior-leaves-sprite", surface)
            if operation then
                operation.exposure = exposure
                operation.allowHistoricalBreach = historicalBreach == true
                operation.buildingKey = profile and profile.key or nil
                operation.buildingSignature = profile and profile.signature or nil
            end
        end
        return
    end

    if surface == Context.SURFACE.RAIL then
        -- Keep rail corridors readable. Only a restrained edge treatment is
        -- allowed; no shrubs or collision-heavy trees are introduced.
        if context.railClass == "RAIL_EDGE" then
            if shouldPlace(square, scaledChance(cfg.grassPercentageOnRoad, 0.20), "vegetation:rail-grass", 4) then
                planDecoration(plan, square, Data.getOutputPool("grass"), "vegetation:rail-grass-sprite", surface)
            end
            if shouldPlace(square, scaledChance(cfg.floorleavesPercentage, 0.15), "vegetation:rail-leaves", 5) then
                planDecoration(plan, square, Data.getOutputPool("leaf"), "vegetation:rail-leaves-sprite", surface)
            end
        end
        return
    end

    if surface == Context.SURFACE.ROAD then
        if not SquareCheck.checkSquare(square, surface) then return end
        local roadEdge = context.roadClass == "ROAD_EDGE"
        local nearNatural = Context.hasNaturalAtOffsets(square, Context.offsets.adjacent)
        local nearTree = hasLocalWoodySeed(square)

        if roadEdge then
            if nearNatural
                and shouldPlace(square, scaledChance(cfg.treePercentageOnRoad, areaModifiers.road), "vegetation:road-tree", 7)
            then
                planTree(plan, square, cfg, surface, "road-tree")
            end
            if shouldPlace(square, scaledChance(cfg.bushesPercentageOnRoad, 0.50 * areaModifiers.road), "vegetation:road-bush", 5) then
                planBush(plan, square, surface, "road-bush")
            end
            if nearNatural
                and shouldPlace(square, scaledChance(cfg.grassPercentageOnRoad, 0.55 * areaModifiers.road), "vegetation:road-grass", 4)
            then
                planDecoration(plan, square, Data.getOutputPool("grass"), "vegetation:road-grass-sprite", surface)
            end
            if nearTree
                and shouldPlace(square, scaledChance(cfg.floorleavesPercentage, areaModifiers.road), "vegetation:road-leaves", 5)
            then
                planDecoration(plan, square, Data.getOutputPool("leaf"), "vegetation:road-leaves-sprite", surface)
            end
        else
            -- Road cores keep their pavement and usable corridor. Ten years of
            -- neglect still permits sparse non-collision crack weeds/detail,
            -- but never A10YL shrubs or trees in the centre path.
            if shouldPlace(square, scaledChance(cfg.roadCoreGrassPercentage, 0.10 * areaModifiers.road), "vegetation:road-core-grass", 5) then
                planDecoration(plan, square, Data.getOutputPool("grass"), "vegetation:road-core-grass-sprite", surface)
            end
            if nearTree and shouldPlace(square, scaledChance(cfg.roadCoreLeafPercentage, 0.18 * areaModifiers.road), "vegetation:road-core-leaves", 6) then
                planDecoration(plan, square, Data.getOutputPool("leaf"), "vegetation:road-core-leaves-sprite", surface)
            end
        end
        return
    end

    if surface == Context.SURFACE.HARDSCAPE then
        if not SquareCheck.checkSquare(square, surface) then return end
        local hardscapeEdge = context.hardscapeClass == "EXTERIOR_HARDSCAPE_EDGE"
        if hardscapeEdge then
            if shouldPlace(square, scaledChance(cfg.bushesPercentageOnRoad, 0.20 * areaModifiers.hardscape), "vegetation:hardscape-bush", 5) then
                planBush(plan, square, surface, "hardscape-bush")
            end
            if shouldPlace(square, scaledChance(cfg.grassPercentageOnRoad, 0.42 * areaModifiers.hardscape), "vegetation:hardscape-grass", 4) then
                planDecoration(plan, square, Data.getOutputPool("grass"), "vegetation:hardscape-grass-sprite", surface)
            end
            if shouldPlace(square, scaledChance(cfg.floorleavesPercentage, 0.35 * areaModifiers.hardscape), "vegetation:hardscape-leaves", 5) then
                planDecoration(plan, square, Data.getOutputPool("leaf"), "vegetation:hardscape-leaves-sprite", surface)
            end
        else
            -- Parking/service/yard centres weather more slowly than edges but
            -- should not remain visually sterile after a decade. Keep centre
            -- reclamation lightweight so the underlying hardscape stays clear.
            if shouldPlace(square, scaledChance(cfg.grassPercentageOnRoad, 0.07 * areaModifiers.hardscape), "vegetation:hardscape-core-grass", 6) then
                planDecoration(plan, square, Data.getOutputPool("grass"), "vegetation:hardscape-core-grass-sprite", surface)
            end
            if shouldPlace(square, scaledChance(cfg.floorleavesPercentage, 0.15 * areaModifiers.hardscape), "vegetation:hardscape-core-leaves", 6) then
                planDecoration(plan, square, Data.getOutputPool("leaf"), "vegetation:hardscape-core-leaves-sprite", surface)
            end
        end
        return
    end

    if surface == Context.SURFACE.NATURAL then
        if not SquareCheck.checkSquare(square, surface) then return end
        local woodyFactor = Context.getWoodySuccessionFactor(square, surface) * areaModifiers.tree
        local treePlanned = false
        if z == 0 then
            local matureFactor = matureTreeSeedFactor(square) * areaModifiers.mature
            if matureFactor > 0
                and shouldPlace(
                    square,
                    scaledChance(cfg.matureTreePercentage, matureFactor),
                    "vegetation:natural-mature-tree:" .. tostring(context.areaType),
                    10
                )
            then
                treePlanned = planMatureTree(plan, square, cfg, surface) ~= nil
            end

            if not treePlanned
                and shouldPlace(square, scaledChance(cfg.treePercentage, woodyFactor), "vegetation:natural-tree:" .. tostring(context.areaType), 8)
            then
                planTree(plan, square, cfg, surface, "natural-tree")
            end
        end
        if shouldPlace(square, scaledChance(cfg.bushesPercentage, areaModifiers.bush), "vegetation:natural-bush:" .. tostring(context.areaType), 5) then
            planBush(plan, square, surface, "natural-bush")
        end
        if shouldPlace(square, scaledChance(cfg.grassPercentage, areaModifiers.grass), "vegetation:natural-grass:" .. tostring(context.areaType), 4) then
            planDecoration(plan, square, Data.getOutputPool("grass"), "vegetation:natural-grass-sprite", surface)
        end
        if shouldPlace(square, scaledChance(cfg.floorleavesPercentage, areaModifiers.leaf), "vegetation:natural-leaves:" .. tostring(context.areaType), 5) then
            planDecoration(plan, square, Data.getOutputPool("leaf"), "vegetation:natural-leaves-sprite", surface)
        end
        return
    end

    if surface == Context.SURFACE.UPPER_EXPOSED then
        -- Point #5 revision 3: plain exposed upper floors / roof decks are not
        -- treated as terrain. Roof grass/leaves created large visual carpets and
        -- consumed queue capacity without improving the ten-year look. Building
        -- envelope ageing (walls, openings, vines) is handled independently.
        return
    end
    -- Unknown/protected/invalid surfaces fail closed rather than guessing.
end

local function surfaceStillValid(square, surface, exposure, operation)
    if not square or not surface then return false end
    if surface == "any" then return true end
    if Context.classifySurface(square) ~= surface then return false end
    if operation and operation.buildingKey ~= nil
        and not BuildingProfile.matches(square, operation.buildingKey, operation.buildingSignature)
    then
        return false
    end
    if surface == Context.SURFACE.INTERIOR and exposure ~= nil then
        local currentExposure = Context.getExposure(square)
        if currentExposure == exposure then return true end
        if operation and operation.allowHistoricalBreach
            and exposure == Context.EXPOSURE.SEALED_INTERIOR
            and Context.isInteriorPerimeter(square)
            and BuildingProfile.matches(square, operation.buildingKey, operation.buildingSignature)
            and BuildingProfile.isBreachedHistory(BuildingProfile.get(square))
        then
            return true
        end
        return false
    end
    return true
end

local function applyDecoration(square, operation)
    if Clearing.isSuppressed(square, operation.id) then
        return true, false
    end
    if Mutations.hasOwnedOperation(square, operation.id, "GroundCover") then
        return true, false
    end

    if not operation.spriteName or not getSprite(operation.spriteName)
        or not square:isSolidFloor() or not SquareCheck.checkWater(square)
        or not surfaceStillValid(square, operation.surface, operation.exposure, operation)
        or Mutations.hasSpriteObject(square, operation.spriteName)
    then
        return false
    end

    local placed, obj = Mutations.placePersistentDecoration(
        square, operation.spriteName, "GroundCover", operation.id, "special"
    )
    if not placed or not obj then return false, false end
    return true, true
end

local function applyBush(square, operation)
    if Clearing.isSuppressed(square, operation.id) then
        return true, false
    end
    if Mutations.hasOwnedOperation(square, operation.id, "Bush") then
        return true, false
    end

    if not square:isSolidFloor() or not SquareCheck.checkWater(square)
        or not surfaceStillValid(square, operation.surface, operation.exposure, operation)
        or squareHasA10YLBush(square) or isObjectBlockingTree(square)
    then
        return false
    end

    local floor = square:getFloor()
    local floorSprite = floor and floor:getSprite()
    if not floorSprite or not floorSprite:getName() or not getSprite(operation.spriteName) then
        return false
    end

    local placed, obj = Mutations.placePersistentDecoration(
        square, operation.spriteName, "Bush", operation.id, "special"
    )
    if not placed or not obj then return false, false end

    if operation.leafSpriteName and getSprite(operation.leafSpriteName) then
        local leafKey = operation.id .. ":leaf"
        if not Mutations.addAttachedSprite(obj, operation.leafSpriteName, leafKey, "BushLeaf") then
            -- The persistent base bush is still valid; a missing optional leaf
            -- attachment should not duplicate the bush on a later retry.
            return true, true
        end
    end
    return true, true
end

local function applyTree(square, operation, cfg)
    if Mutations.hasOwnedOperation(square, operation.id, "Tree") then
        return true, false
    end

    local growthClass = operation.growthClass
        or (operation.largeTree and "jumbo" or "standard")

    if not surfaceStillValid(square, operation.surface, operation.exposure, operation)
        or squareHasTree(square)
        or not getSprite(operation.spriteName)
        or Data.classifyTreeSprite(operation.spriteName) ~= growthClass
        or not isTreeSpawnSquareValid(square, growthClass, cfg)
    then
        return false
    end

    local newTree = IsoTree.new(square, getSprite(operation.spriteName))
    if not newTree then
        return false
    end

    if not Mutations.tagOwnedObject(newTree, "Tree", operation.id) then
        return false, false
    end

    -- Use the validated tree sprite as a self-contained IsoTree. The legacy
    -- `_4.._16` canopy attachment loop caused large render and replication
    -- bursts and is intentionally not reproduced.
    if not Mutations.addSpecialObject(square, newTree) then
        return false, false
    end
    return true, true
end

function Vegetation.applyOperation(square, operation, cfg)
    if not square or Protection.isProtectedSquare(square) or not operation or Compatibility.isSquareExcluded("vegetation", square) then
        return false
    elseif operation.action == "decoration" then
        return applyDecoration(square, operation)
    elseif operation.action == "bush" then
        return applyBush(square, operation)
    elseif operation.action == "tree" then
        return applyTree(square, operation, cfg)
    end
    return false
end

return Vegetation
