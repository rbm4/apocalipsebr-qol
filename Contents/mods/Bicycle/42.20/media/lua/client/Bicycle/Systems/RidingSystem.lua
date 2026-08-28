local BicycleAttachments = require("Bicycle/SaddleBag/Saddlebag")
local BicycleMountDismountState = require("Bicycle/MountDismountState")
local BicycleLoadPenalty = require("Bicycle/LoadPenalty")
local BicycleOptions = require("Bicycle/BicycleOptions")
local BicycleUtils = require("Bicycle/Utils")
local BicycleWorldUtils = require("Bicycle/WorldUtils")
local BicycleZombieProximity = require("Bicycle/Systems/ZombieProximity")

---@type table|nil
local bicycleMenu = nil

---@class BicycleRidingSystem
local BicycleRidingSystem = {}

---@type table<number, boolean>
local bicycleSprintKeyStates = {}
---@type table<number, boolean>
local bicycleSprintLockStates = {}
---@type table<number, boolean>
local bicycleFallDropScheduled = {}
---@type table<number, boolean>
local bicycleTurnDeltaApplied = {}

local BICYCLE_SPRINT_ENDURANCE_MIN = 0.5
local BICYCLE_SPRINT_ENDURANCE_RESET = 0.55
local SPORTS_BOTTLE_PART_TYPE = "Sportsbottle"
local THIRST_PER_WATER_UNIT = 0.83333333333333

local BICYCLE_TURN_SPEED_BASE = 0.80
local BICYCLE_TURN_WALK_SPEED_BASE = 1.04

---@param menu table
---@return nil
function BicycleRidingSystem.setMenu(menu)
    bicycleMenu = menu
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return number
---@return number
---@nodiscard
local function getEnduranceScaling(player)
    if not player then
        return 1, 1
    end

    local stats = player:getStats()
    if not stats then
        return 1, 1
    end

    local endurance = stats:get(CharacterStat.ENDURANCE)

    if endurance >= 0.5 then
        return 1, endurance
    end

    local scaledEndurance = math.max(0.5, endurance * 0.9 + 0.5)
    return scaledEndurance, endurance
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
local function autoDrinkFromBikeSportsbottle(player, bicycleItem)
    if not (player and bicycleItem and bicycleItem.getWeaponPart) then
        return
    end

    local part = bicycleItem:getWeaponPart(SPORTS_BOTTLE_PART_TYPE)
    if not part then
        return
    end

    local waterAvailable = BicycleAttachments.getSportsbottleWaterAmount(part)
    if waterAvailable <= 0 then
        return
    end

    local stats = player:getStats()
    if not stats then
        return
    end

    local thirst = stats:get(CharacterStat.THIRST)
    local threshold = (ZomboidGlobals and ZomboidGlobals.ThirstLevelToAutoDrink) or 0.1
    if thirst < threshold then
        return
    end

    local thirstReduction = math.min(thirst, waterAvailable * THIRST_PER_WATER_UNIT)
    if thirstReduction <= 0 then
        return
    end

    stats:set(CharacterStat.THIRST, math.max(0, thirst - thirstReduction))

    local waterUsed = thirstReduction / THIRST_PER_WATER_UNIT
    BicycleAttachments.setSportsbottleWaterAmount(part, waterAvailable - waterUsed)
end

---@return boolean
---@nodiscard
local function isBicycleRunKeyHeld()
    local core = getCore()
    local runKey = core:getKey("Run")
    if runKey and runKey >= 0 and isKeyDown(runKey) then
        return true
    end

    local altRunKey = core:getAltKey("Run")
    if altRunKey and altRunKey >= 0 and isKeyDown(altRunKey) then
        return true
    end

    return false
end

-- Drop the bike the player is falling off, after a delay for the stumble animation. The bike is captured now,
-- not read inside the timer -- by then the hands may hold a different bike that was auto-equipped.
---@param player IsoPlayer|IsoGameCharacter
---@param delay number
local function scheduleFallOffDrop(player, delay)
    local scheduledBike = player:getPrimaryHandItem()
    if not BicycleUtils.isBicycleItem(scheduledBike) then
        return
    end

    BicycleUtils.runAfter(delay, function()
        if not bicycleMenu then
            return
        end
        -- Only the bike we were holding when the fall started.
        if player:getPrimaryHandItem() ~= scheduledBike then
            return
        end
        local square = player:getSquare()
        if not square then
            return
        end
        local zRot = BicycleUtils.directionToZRotation(player:getDir())
        bicycleMenu.dropBicycleAtSquare(player, scheduledBike, square, {
            kickstandDown = false,
            shiftHeld = true,
            direction = player:getDir(),
            zRotation = zRot,
        })
    end)
end

---@param player IsoPlayer|IsoGameCharacter
---@return boolean
local function bicycleFallOff(player)
    if not (player and player:getVariableBoolean("BicycleActive")) then
        return false
    end

    -- A throw keeps the bike equipped and BicycleActive set for its animation. A fence is a wall, so without this
    -- the wall-collision branch below schedules a fall-off drop in the middle of the throw.
    if player:getVariableBoolean("ThrowBicycleFence") then
        return false
    end

    if player:getVariableString("CollideType") == "wall" then
        local playerNum = player:getPlayerNum()
        if not bicycleFallDropScheduled[playerNum] then
            bicycleFallDropScheduled[playerNum] = true
            scheduleFallOffDrop(player, 0.95)
            BicycleMountDismountState.setDismountAnim(player, "")
        end
        return true
    end

    local inTrees = player:getVariableBoolean("intrees")
    local aimHeld = (player.isAimActive and player:isAimActive()) or (player.isAiming and player:isAiming()) or false
    if inTrees and aimHeld and player:getVariableBoolean("pressedRunButton") then
        local playerNum = player:getPlayerNum()
        if not bicycleFallDropScheduled[playerNum] then
            bicycleFallDropScheduled[playerNum] = true
            player:setForceSprint(false)
            player:setVariable("BumpFall", true)
            player:setVariable("BumpDone", false)
            player:setVariable("TripObstacleType", "tree")
            player:setBumpType("left")
            scheduleFallOffDrop(player, 0.35)
            BicycleUtils.runAfter(0.35, function()
                BicycleMountDismountState.setDismountAnim(player, "")
            end)
        end
        return true
    end

    if player:getVariableBoolean("BumpFall") then
        local playerNum = player:getPlayerNum()
        if not bicycleFallDropScheduled[playerNum] then
            bicycleFallDropScheduled[playerNum] = true
            scheduleFallOffDrop(player, 0.35)
            BicycleUtils.runAfter(0.35, function()
                BicycleMountDismountState.setDismountAnim(player, "")
            end)
        end
        return true
    end

    if player:getVariableString("dismountAnim") ~= "" and not player:getVariableBoolean("Dismounting") then
        BicycleMountDismountState.setDismountAnim(player, "")
    end

    return false
end

---@param player IsoPlayer|IsoGameCharacter
function BicycleRidingSystem.updateBicycleAudio(player)
    local bicycleActive = player:getVariableBoolean("BicycleActive")
    local emitter = player:getEmitter()
    local soundVolume = 0.40
    if PZAPI and PZAPI.ModOptions then
        local options = PZAPI.ModOptions:getOptions("BicycleMod")
        if options then
            local option = options:getOption("BicycleSoundVolume")
            if option then
                soundVolume = option:getValue()
            end
        end
    end

    if player.isLocalPlayer and not player:isLocalPlayer() then
        if emitter:isPlaying("Bicycle_Riding") then
            emitter:stopSoundByName("Bicycle_Riding")
        end
        return
    end

    if not bicycleActive then
        if emitter:isPlaying("Bicycle_Riding") then
            emitter:stopSoundByName("Bicycle_Riding")
        end
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.syncSoundState then
            Bicycle.ClientSync.syncSoundState(player, "Bicycle_Riding", false)
        end
        player:setVariable("Bicycle_Riding", "false")
        player:setVariable("Bicycle_RollingTimestamp", "0")
        return
    end

    if not player:getVariableBoolean("Bicycle_Riding") then
        if emitter:isPlaying("Bicycle_Riding") then
            emitter:stopSoundByName("Bicycle_Riding")
        end
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.syncSoundState then
            Bicycle.ClientSync.syncSoundState(player, "Bicycle_Riding", false)
        end
        player:setVariable("Bicycle_RollingTimestamp", "0")
        return
    end

    if emitter:isPlaying("Bicycle_Riding") and player:isPlayerMoving() then
        addSound(nil, player:getX(), player:getY(), player:getZ(), 4, 4)
        if bicycleMenu then
            bicycleMenu.rotateWheels()
            bicycleMenu.drainWearParts(player, player:getPrimaryHandItem())
        end
        return
    end

    if not player:isPlayerMoving() then
        emitter:stopSoundByName("Bicycle_Riding")
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.syncSoundState then
            Bicycle.ClientSync.syncSoundState(player, "Bicycle_Riding", false)
        end
        player:setVariable("Bicycle_RollingTimestamp", "0")
        return
    end

    if tonumber(player:getVariableString("Bicycle_RollingTimestamp")) < 1 then
        local ts = getTimestampMs()
        player:setVariable("Bicycle_RollingTimestamp", tostring(ts))
    end

    local startTs = tonumber(player:getVariableString("Bicycle_RollingTimestamp"))
    local currentTs = getTimestampMs()

    if currentTs - startTs >= 250 and not emitter:isPlaying("Bicycle_Riding") then
        local sound = emitter:playSoundImpl("Bicycle_Riding", nil)
        emitter:setVolume(sound, soundVolume)
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.syncSoundState then
            Bicycle.ClientSync.syncSoundState(player, "Bicycle_Riding", true)
        end
        if bicycleMenu then
            bicycleMenu.rotateWheels()
            bicycleMenu.drainWearParts(player, player:getPrimaryHandItem())
        end
        addSound(nil, player:getX(), player:getY(), player:getZ(), 4, 4)
        player:setVariable("Bicycle_RollingTimestamp", "0")
    end
end

---@param player IsoPlayer|IsoGameCharacter
function BicycleRidingSystem.updateBicycleSprint(player)
    local bicycleActive = player:getVariableBoolean("BicycleActive")
    if not bicycleActive then
        player:setVariable("BicycleSprintHeld", false)
        return
    end

    local playerNum = player:getPlayerNum()
    local runHeld = isBicycleRunKeyHeld()
    local wasHeld = bicycleSprintKeyStates[playerNum] == true
    local stats = player.getStats and player:getStats() or nil
    local _, enduranceValue = getEnduranceScaling(player)
    local lockState = bicycleSprintLockStates[playerNum] == true

    if enduranceValue <= BICYCLE_SPRINT_ENDURANCE_MIN then
        lockState = true
    elseif lockState and enduranceValue >= BICYCLE_SPRINT_ENDURANCE_RESET then
        lockState = false
    end

    if lockState then
        bicycleSprintLockStates[playerNum] = true
        player:setVariable("runLocked", true)
    else
        bicycleSprintLockStates[playerNum] = nil
        player:setVariable("runLocked", false)
    end

    local drainActive = runHeld and not lockState
    player:setVariable("BicycleSprintHeld", drainActive)

    if not player:getVariableBoolean("BicycleActive") then
        if wasHeld then
            player:setForceSprint(false)
            bicycleSprintKeyStates[playerNum] = nil
        end
        bicycleSprintLockStates[playerNum] = nil
        return
    end

    if lockState then
        local walkSpeed = player.getVariableFloat and player:getVariableFloat("BicycleWalkSpeed", 0) or 0
        if walkSpeed > 0 then
            player:setVariable("BicycleRunSpeed", walkSpeed)
        end
    end

    if not drainActive then
        if wasHeld then
            player:setForceSprint(false)
            bicycleSprintKeyStates[playerNum] = nil
        end
        return
    end

    if stats and drainActive then
        local fitnessLevel = player.getPerkLevel and player:getPerkLevel(Perks.Fitness) or 0
        local baseDrain = 0.00007
        if fitnessLevel >= 9 then
            baseDrain = 0.00003
        end
        local enduranceDelta = baseDrain
        local aimHeld = (player.isAimActive and player:isAimActive()) or (player.isAiming and player:isAiming()) or false
        if aimHeld then
            enduranceDelta = -baseDrain
        end
        stats:set(CharacterStat.ENDURANCE, stats:get(CharacterStat.ENDURANCE) + enduranceDelta)
    end

    if not wasHeld and enduranceValue < BICYCLE_SPRINT_ENDURANCE_RESET then
        return
    end

    player:setAllowSprint(true)
    player:setForceSprint(true)
    bicycleSprintKeyStates[playerNum] = true
end

---@param player IsoPlayer|IsoGameCharacter
function BicycleRidingSystem.updateBicycleFlag(player)
    local primaryItem = player:getPrimaryHandItem()
    local playerNum = player:getPlayerNum()

    local isRidingNow = primaryItem and BicycleUtils.isBicycleItem(primaryItem)
    if bicycleTurnDeltaApplied[playerNum] and not isRidingNow then
        player:setTurnDelta(1.0)
        bicycleTurnDeltaApplied[playerNum] = nil
    end

    if not primaryItem then
        BicycleZombieProximity.reset(player)
        return
    end

    if bicycleFallOff(player) then
        BicycleZombieProximity.reset(player)
        return
    end

    if BicycleUtils.isBicycleItem(primaryItem) then
        local queue = ISTimedActionQueue.getTimedActionQueue(player)
        local action = queue and queue.current
        if action then
            action:setOverrideHandModels(primaryItem, action.item)
        end
        player:resetEquippedHandsModels()

        if bicycleMenu and player.isLocalPlayer and player:isLocalPlayer() then
            bicycleMenu.updatePedalCrank(player)
        end

        local bodyDamage = player:getBodyDamage()
        if isClient() and not player:isLocalPlayer() then
            bodyDamage = player:getBodyDamageRemote()
        end
        player:setVariable("BicycleActive", "true")
        player:setIgnoreAutoVault(true)
        player:setBannedAttacking(true)
        if bicycleMenu then
            bicycleMenu.updateBicycleShoutState(player, primaryItem)
        end
        BicycleAttachments.followPlayer(player, primaryItem)
        autoDrinkFromBikeSportsbottle(player, primaryItem)

        local penaltyEnabled = BicycleOptions.isLoadPenaltyEnabled()
        local maxTurnPct = BicycleOptions.getMaxTurnPenalty()
        local maxSpeedPct = BicycleOptions.getMaxSpeedPenalty()
        local containerCount, contentsWeight = BicycleAttachments.measureContainerLoad(primaryItem)

        local weightModifier = 1
        local turnDelta = 1
        if penaltyEnabled then
            turnDelta, weightModifier =
                BicycleLoadPenalty.compute(containerCount, contentsWeight, maxTurnPct, maxSpeedPct)
            player:setTurnDelta(turnDelta)
            bicycleTurnDeltaApplied[playerNum] = true
        elseif bicycleTurnDeltaApplied[playerNum] then
            player:setTurnDelta(1.0)
            bicycleTurnDeltaApplied[playerNum] = nil
        end

        local fastRegime = player:isSprinting() or player:isRunning()
        local animTurnDelta = fastRegime and turnDelta or 1
        player:setVariable("BicycleTurnSpeed", BICYCLE_TURN_SPEED_BASE * animTurnDelta)
        player:setVariable("BicycleTurnWalkSpeed", BICYCLE_TURN_WALK_SPEED_BASE * animTurnDelta)
        local damageModifier = 1
        local bodyParts = bodyDamage and bodyDamage:getBodyParts()
        if bodyParts then
            for i = 1, bodyParts:size() do
                local part = bodyParts:get(i - 1)
                local partName = string.lower(tostring(part:getType()))
                if partName:find("leg") or partName:find("foot") then
                    if part:HasInjury() and part:getFractureTime() > 0 then
                        damageModifier = 0.01
                        break
                    elseif part:getHealth() < 75 then
                        damageModifier = (part:getHealth() / 100) * 0.8
                        break
                    end
                end
            end
        end
        local bicycleImmersive = BicycleOptions.isImmersiveModeEnabled()
        local speedMultSlow, speedMultFast = BicycleOptions.getSpeedMultipliers()
        local square = player:getSquare()
        local isRough = BicycleWorldUtils.isRoughSurface(square)
        local wheelConfig = bicycleMenu and bicycleMenu.getWheelConfiguration(primaryItem, player) or { offroad = 0, street = 0 }
        local hasOffroadPair = wheelConfig.offroad >= 2 and wheelConfig.street == 0
        local attachedWheels = bicycleMenu and bicycleMenu.getAttachedWheels(primaryItem, player) or {}

        if bicycleMenu and hasOffroadPair then
            speedMultSlow = speedMultSlow * bicycleMenu.OffroadSpeedMultiplier
            speedMultFast = speedMultFast * bicycleMenu.OffroadSpeedMultiplier
        end

        local flatCount = 0
        for _, wheel in ipairs(attachedWheels) do
            if wheel.isFlat then
                flatCount = flatCount + 1
            end
        end

        local speedPenalty = 1
        if flatCount == 1 then
            speedPenalty = 0.7
        elseif flatCount >= 2 then
            speedPenalty = 0.3
        end

        speedMultSlow = speedMultSlow * speedPenalty
        speedMultFast = speedMultFast * speedPenalty

        local isRoughActive = (isRough and bicycleImmersive and not hasOffroadPair) and true or false
        if isRoughActive then
            weightModifier = weightModifier * 0.75
        end

        local enduranceScale = getEnduranceScaling(player)
        local finalSpeed = damageModifier * weightModifier * speedPenalty

        local zombieMult = 1
        local evaluateZombies = (not isClient()) or player:isLocalPlayer()
        if evaluateZombies and BicycleOptions.isZombieSlowdownEnabled() then
            local contactCount = BicycleZombieProximity.countTouchingZombies(player)
            zombieMult = BicycleZombieProximity.computeMultiplier(player, contactCount)
            BicycleZombieProximity.maybeKnockOff(player, contactCount)
        elseif evaluateZombies then
            BicycleZombieProximity.reset(player)
        end

        player:setVariable("BicycleSpeed", 1)
        player:setVariable("BicycleWalkSpeed", speedMultSlow * enduranceScale * zombieMult * finalSpeed)
        player:setVariable("BicycleRunSpeed", speedMultFast * enduranceScale * zombieMult * finalSpeed)
        player:setVariable("BicycleWalkSpeedRough", speedMultSlow * enduranceScale * finalSpeed * zombieMult)
        player:setVariable("BicycleRunSpeedRough", speedMultFast * enduranceScale * finalSpeed * zombieMult)
        player:setVariable("BicycleRough", isRoughActive)

        local treeSpeedMult = 0.5
        player:setVariable("BicycleWalkSpeedTrees", speedMultSlow * enduranceScale * treeSpeedMult * zombieMult * finalSpeed)
        player:setVariable("BicycleRunSpeedTrees", speedMultFast * enduranceScale * treeSpeedMult * zombieMult * finalSpeed)
        return
    end
end

---@return nil
local function removeBicycleUpdateHandlers()
    Events.OnPlayerUpdate.Remove(BicycleRidingSystem.updateBicycleFlag)
    Events.OnPlayerUpdate.Remove(BicycleRidingSystem.updateBicycleAudio)
    Events.OnPlayerUpdate.Remove(BicycleRidingSystem.updateBicycleSprint)

    for playerNum, _ in pairs(bicycleTurnDeltaApplied) do
        local p = getSpecificPlayer(playerNum)
        if p then
            p:setTurnDelta(1.0)
        end
    end
    bicycleTurnDeltaApplied = {}
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return nil
function BicycleRidingSystem.clearFallDropScheduled(player)
    if not player then
        return
    end
    local playerNum = player:getPlayerNum()
    bicycleFallDropScheduled[playerNum] = nil
end

---@return nil
function BicycleRidingSystem.clearUpdateHandlers()
    for k in pairs(bicycleFallDropScheduled) do
        bicycleFallDropScheduled[k] = nil
    end
    removeBicycleUpdateHandlers()
end

---@return nil
function BicycleRidingSystem.ensureUpdateHandlers()
    Events.OnPlayerUpdate.Remove(BicycleRidingSystem.updateBicycleFlag)
    Events.OnPlayerUpdate.Remove(BicycleRidingSystem.updateBicycleAudio)
    Events.OnPlayerUpdate.Remove(BicycleRidingSystem.updateBicycleSprint)
    Events.OnPlayerUpdate.Add(BicycleRidingSystem.updateBicycleFlag)
    Events.OnPlayerUpdate.Add(BicycleRidingSystem.updateBicycleAudio)
    Events.OnPlayerUpdate.Add(BicycleRidingSystem.updateBicycleSprint)
end

return BicycleRidingSystem
