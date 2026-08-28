---@class BicycleMountDismountState
local BicycleMountDismountState = {}

---@param player IsoPlayer|IsoGameCharacter|nil
---@param name string
---@param value any
local function setPlayerVariable(player, name, value)
    if not (player and player.setVariable) then
        return
    end
    player:setVariable(name, value)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param mountAnim string|nil
function BicycleMountDismountState.setMountAnim(player, mountAnim)
    setPlayerVariable(player, "mountAnim", mountAnim or "")
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param dismountAnim string|nil
function BicycleMountDismountState.setDismountAnim(player, dismountAnim)
    setPlayerVariable(player, "dismountAnim", dismountAnim or "")
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param kickstandDown boolean|nil
function BicycleMountDismountState.setDismountKickstand(player, kickstandDown)
    if kickstandDown == nil then
        return
    end
    setPlayerVariable(player, "DismountKickstand", kickstandDown == true)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param isDismounting boolean|nil
function BicycleMountDismountState.setDismounting(player, isDismounting)
    setPlayerVariable(player, "Dismounting", isDismounting == true)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param dismountData table|nil
function BicycleMountDismountState.applyDismountData(player, dismountData)
    if not dismountData then
        return
    end
    BicycleMountDismountState.setDismountKickstand(player, dismountData.kickstandDown)
    if dismountData.dismountAnim then
        BicycleMountDismountState.setDismountAnim(player, dismountData.dismountAnim)
    end
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param mountAnim string|nil
function BicycleMountDismountState.prepareMount(player, mountAnim)
    BicycleMountDismountState.clearDismountState(player)
    BicycleMountDismountState.setMountAnim(player, mountAnim)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param dismountAnim string|nil
function BicycleMountDismountState.prepareDismount(player, dismountAnim)
    BicycleMountDismountState.clearMountState(player)
    BicycleMountDismountState.setDismountAnim(player, dismountAnim)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param dismountData table|nil
function BicycleMountDismountState.beginDismount(player, dismountData)
    BicycleMountDismountState.clearMountState(player)
    BicycleMountDismountState.applyDismountData(player, dismountData)
    BicycleMountDismountState.setDismounting(player, true)
end

---@param player IsoPlayer|IsoGameCharacter|nil
function BicycleMountDismountState.finishMount(player)
    BicycleMountDismountState.clearMountState(player)
end

---@param player IsoPlayer|IsoGameCharacter|nil
function BicycleMountDismountState.finishDismount(player)
    BicycleMountDismountState.clearDismountState(player)
end

---@param player IsoPlayer|IsoGameCharacter|nil
function BicycleMountDismountState.clearMountState(player)
    BicycleMountDismountState.setMountAnim(player, "")
end

---@param player IsoPlayer|IsoGameCharacter|nil
function BicycleMountDismountState.clearDismountState(player)
    BicycleMountDismountState.setDismounting(player, false)
    BicycleMountDismountState.setDismountKickstand(player, false)
    BicycleMountDismountState.setDismountAnim(player, "")
end

---@param player IsoPlayer|IsoGameCharacter|nil
function BicycleMountDismountState.resetAllBikeVariables(player)
    if not (player and player.setVariable) then
        return
    end
    player:setVariable("BicycleActive", "false")
    player:setVariable("Bicycle_Riding", "false")
    player:setVariable("Bicycle_Stopping", false)
    player:setVariable("Bicycle_RollingTimestamp", "0")
    player:setVariable("BicycleSpeed", 0)
    player:setVariable("BicycleWalkSpeed", 0)
    player:setVariable("BicycleRunSpeed", 0)
    player:setVariable("BicycleWalkSpeedRough", 0)
    player:setVariable("BicycleRunSpeedRough", 0)
    player:setVariable("BicycleWalkSpeedTrees", 0)
    player:setVariable("BicycleRunSpeedTrees", 0)
    player:setVariable("BicycleRough", false)
    player:setVariable("droppingBicycle", "false")
    player:setVariable("Bicycle_MountPending", false)
    player:setVariable("mountAnim", "")
    player:setVariable("dismountAnim", "")
    player:setVariable("Dismounting", false)
    player:setVariable("DismountKickstand", false)
    player:setVariable("BumpFall", false)
    player:setVariable("BumpDone", true)
    player:setVariable("TripObstacleType", "")
end

return BicycleMountDismountState
