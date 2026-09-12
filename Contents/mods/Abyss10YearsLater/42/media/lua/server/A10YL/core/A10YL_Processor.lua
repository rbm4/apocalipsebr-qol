local Vegetation = require("A10YL/systems/A10YL_Vegetation")
local Debris = require("A10YL/systems/A10YL_Debris")
local Roads = require("A10YL/systems/A10YL_Roads")
local Vines = require("A10YL/systems/A10YL_Vines")
local Fences = require("A10YL/systems/A10YL_Fences")
local Structures = require("A10YL/systems/A10YL_Structures")
local Openings = require("A10YL/systems/A10YL_Openings")
local Identity = require("A10YL/A10YL_Identity")
local Config = require("A10YL/core/A10YL_Config")
if type(Config) ~= "table" then
    Config = A10YL_Config
end
local Persistence = require("A10YL/core/A10YL_Persistence")
local Context = require("A10YL/core/A10YL_Context")
local BuildingProfile = require("A10YL/core/A10YL_BuildingProfile")
local Validation = require("A10YL/core/A10YL_Validation")
local Protection = require("A10YL/core/A10YL_Protection")

local Processor = {}

local SYSTEMS = {
    vegetation = Vegetation,
    debris = Debris,
    roads = Roads,
    vines = Vines,
    fences = Fences,
    structures = Structures,
    openings = Openings,
}


-- Point #5 revision 3 vertical-work classifier. Ground squares retain the full
-- terrain ageing pass. Above/below ground, only genuine interior floors or
-- map-authored building-envelope objects are worth turning into full planner /
-- persistence jobs. Plain exposed roof/floor squares are intentionally skipped
-- so large buildings do not fill the ageing queue with roof grass/debris work.
function Processor.classifySquareWork(square)
    if not square then return "skip" end
    local context = Context.create(square)
    if Protection.isProtectedSquare(square, context) then return "skip" end
    local z = tonumber(square:getZ()) or 0
    if z == 0 then return "ground" end

    local surface = Context.classifySurface(square, context)
    if surface == Context.SURFACE.WATER
        or surface == Context.SURFACE.PROTECTED
        or surface == Context.SURFACE.INVALID
    then
        return "skip"
    end
    if surface == Context.SURFACE.INTERIOR then
        return "interior"
    end

    local objects = square:getObjects()
    if not objects then return "skip" end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            if instanceof(obj, "IsoDoor") or instanceof(obj, "IsoWindow")
                or Validation.isSupportedOriginalWall(obj)
                or Validation.isSupportedOriginalFence(obj)
            then
                return "envelope"
            end
        end
    end

    return "skip"
end

local function stableStageSort(plan)
    local operations = plan.operations
    local duplicateIds = {}
    local seenIds = {}

    for i = 1, #operations do
        local op = operations[i]
        op._sequence = i

        local slot = op.slot
        if not slot and op.target then
            slot = Identity.operationSlotForTarget(op.target)
        end
        slot = slot or "primary"
        op.slot = slot
        op.id = Identity.operationKey(
            plan.x, plan.y, plan.z,
            op.system, op.action, slot
        )

        if seenIds[op.id] then
            duplicateIds[op.id] = true
        else
            seenIds[op.id] = true
        end
    end

    table.sort(operations, function(a, b)
        local stageA = tonumber(a.stage) or 99
        local stageB = tonumber(b.stage) or 99
        if stageA == stageB then
            return (a._sequence or 0) < (b._sequence or 0)
        end
        return stageA < stageB
    end)

    -- Stable target signatures deliberately contain no object-list index. If
    -- two operations collapse to the same identity, neither can safely target a
    -- unique original object, so remove both rather than guess.
    local filtered = {}
    for i = 1, #operations do
        local op = operations[i]
        op._sequence = nil
        if not duplicateIds[op.id] then
            filtered[#filtered + 1] = op
        end
    end
    plan.operations = filtered
end

local function planObjects(square, cfg, plan, context, profile)
    local objects = square:getObjects()
    if not objects then
        return
    end

    -- Snapshot/classify the live square once. Systems append primitive
    -- descriptors only; no Java object references survive beyond this call.
    -- Preserve the legacy short-circuit order while stage numbers determine
    -- application order later.
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if obj and obj:getSprite() and not Protection.isPlayerBuiltOrMovedObject(obj) then
            local handled = Structures.planRoof(square, obj, cfg, plan, context, profile)
            if not handled then
                handled = Roads.planObject(square, obj, cfg, plan, context)
            end

            if not handled then
                Structures.planWall(square, obj, cfg, plan, context, profile)
                local fenceAction = Fences.planObject(square, obj, cfg, plan, context, profile)
                if not fenceAction then
                    Vines.planObject(square, obj, cfg, plan, context, profile)
                end
                Openings.planObject(square, obj, cfg, plan, context, profile)
            end
        end
    end
end

function Processor.buildPlan(square, cfg)
    if not square or not cfg then
        return nil, "invalid"
    end
    local context = Context.create(square)
    if Protection.isProtectedSquare(square, context) then
        return nil, "protected"
    end

    local configHash = cfg.generationHash or Config.generationHash(cfg)
    if not configHash then
        return nil, "invalid-config"
    end

    local persistenceState, persistenceInfo = Persistence.inspectSquare(square, configHash)
    if persistenceState == "processed" then
        return nil, "processed"
    elseif persistenceState == "disabled" then
        return nil, "persistence-disabled"
    end

    local plan = {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        operations = {},
        cursor = 1,
        cfg = cfg,
        configHash = configHash,
    }

    if persistenceState == "seal" then
        plan.operations[1] = {
            system = "processor",
            stage = 0,
            action = "seal-partial",
            slot = "square",
            sealReason = persistenceInfo.reason,
            sealVersion = persistenceInfo.sealVersion,
        }
        stableStageSort(plan)
        return plan, nil
    end

    if persistenceState == "fresh" then
        plan.operations[#plan.operations + 1] = {
            system = "processor",
            stage = 0,
            action = "begin-processing",
            slot = "square",
        }
    end

    -- Plan-time square context and building history are read-only. Resolve each
    -- once and share the primitive/profile result across feature planners rather
    -- than repeating rail/object/building scans for every object on the square.
    -- Apply-time operations still re-fetch and revalidate the live world.
    if square.getFloor and square.getObjects then
        context = Context.describeSquare(square, context)
    end
    local profile = BuildingProfile.get(square) or false

    Vegetation.planSquare(square, cfg, plan, context)
    Debris.planSquare(square, cfg, plan, context, profile)
    planObjects(square, cfg, plan, context, profile)

    -- v0.8.0 optimisation: only write persistent stage checkpoints for stages
    -- that actually have feature work, plus the final stage required before PV is
    -- set. Older builds wrote all seven stage checkpoints on every square even if
    -- most of those stages had no operations, creating avoidable CPU/save churn.
    local featureStages = {}
    for i = 1, #plan.operations do
        local operation = plan.operations[i]
        if operation.system ~= "processor" then
            local stage = tonumber(operation.stage) or Persistence.FINAL_STAGE
            if stage >= 1 and stage <= Persistence.FINAL_STAGE then
                featureStages[stage] = true
            end
        end
    end
    featureStages[Persistence.FINAL_STAGE] = true

    for stage = 1, Persistence.FINAL_STAGE do
        if featureStages[stage] then
            plan.operations[#plan.operations + 1] = {
                system = "processor",
                stage = stage,
                action = "checkpoint-stage",
                slot = "stage-" .. tostring(stage),
                checkpointStage = stage,
            }
        end
    end

    plan.operations[#plan.operations + 1] = {
        system = "processor",
        stage = Persistence.FINAL_STAGE,
        action = "finalize-square",
        slot = "square",
    }

    stableStageSort(plan)

    if persistenceState == "resume" then
        local savedStage = tonumber(persistenceInfo.savedStage) or 0
        local remaining = {}
        for i = 1, #plan.operations do
            local operation = plan.operations[i]
            if (tonumber(operation.stage) or 99) > savedStage then
                remaining[#remaining + 1] = operation
            end
        end
        plan.operations = remaining
    end

    return plan, nil
end

local function dispatch(square, operation, cfg, configHash)
    if operation.system == "processor" then
        local satisfied, didMutate
        if operation.action == "begin-processing" then
            satisfied, didMutate = Persistence.beginSquare(square, configHash)
        elseif operation.action == "checkpoint-stage" then
            satisfied, didMutate = Persistence.checkpointStage(
                square, operation.checkpointStage, configHash
            )
        elseif operation.action == "finalize-square" then
            satisfied, didMutate = Persistence.completeSquare(square)
        elseif operation.action == "seal-partial" then
            satisfied, didMutate = Persistence.sealPartial(
                square, operation.sealReason, operation.sealVersion
            )
        else
            error("unknown processor operation: " .. tostring(operation.action))
        end
        if not satisfied then
            error("persistence operation was not safely satisfied: " .. tostring(operation.action))
        end
        return true, didMutate == true
    end

    local system = SYSTEMS[operation.system]
    if not system or type(system.applyOperation) ~= "function" then
        error("unknown mutation system: " .. tostring(operation.system))
    end

    local satisfied, didMutate = system.applyOperation(square, operation, cfg)
    -- The feature-system contract is explicit: satisfaction and mutation are
    -- independent booleans. A missing second result is never promoted into a
    -- mutation credit merely because the first result was true.
    return satisfied == true, didMutate == true
end

function Processor.applyNext(plan, square)
    if not plan or not square then
        return "unloaded", false, false
    end

    if square:getX() ~= plan.x or square:getY() ~= plan.y or square:getZ() ~= plan.z then
        error("square coordinate mismatch while applying plan")
    end

    local operation = plan.operations[plan.cursor]
    if not operation then
        return "done", false, false
    end

    local satisfied = false
    local didMutate = false
    local isFeatureOperation = operation.system ~= "processor"

    -- No shipped operation currently declares dependencies. Avoid allocating and
    -- updating a per-plan results table in the hot apply path.
    satisfied, didMutate = dispatch(square, operation, plan.cfg, plan.configHash)

    plan.cursor = plan.cursor + 1

    if plan.cursor > #plan.operations then
        return "done", didMutate, isFeatureOperation
    end

    return didMutate and "applied" or "skipped", didMutate, isFeatureOperation
end

return Processor
