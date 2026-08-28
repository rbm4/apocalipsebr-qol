require("Bicycle/BicycleCore")

---@class BicycleLoadPenalty
Bicycle = Bicycle or {}
Bicycle.LoadPenalty = Bicycle.LoadPenalty or {}

local M = Bicycle.LoadPenalty

M.MAX_CONTAINERS = 6
M.MAX_WEIGHT_KG = 20
M.WALK_LOCK_WEIGHT_KG = 10

---@param count number container count (0..MAX_CONTAINERS)
---@param weightKg number contents weight (0..MAX_WEIGHT_KG)
---@param maxTurnPct number 0..75 from option
---@param maxSpeedPct number 0..75 from option
---@return number turnDelta, number speedMultiplier, boolean walkLock
function M.compute(count, weightKg, maxTurnPct, maxSpeedPct)
    local containerRatio = math.min(count / M.MAX_CONTAINERS, 1)
    local weightRatio = math.min(weightKg / M.MAX_WEIGHT_KG, 1)

    local turnReductionPct = containerRatio * maxTurnPct
    local speedReductionPct = weightRatio * maxSpeedPct

    local turnDelta = 1 - (turnReductionPct / 100)
    local speedMultiplier = 1 - (speedReductionPct / 100)
    local walkLock = weightKg >= M.WALK_LOCK_WEIGHT_KG

    return turnDelta, speedMultiplier, walkLock
end

return M
