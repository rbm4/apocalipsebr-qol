require "TimedActions/ISBaseTimedAction"
require "Bicycle/BicycleMenu"

BicycleHopOnAction = ISBaseTimedAction:derive("BicycleHopOnAction")
local bicycleHopOnInstance = nil
local BicycleAttachments = require("Bicycle/SaddleBag/Saddlebag")
local BicycleUtils = require("Bicycle/Utils")
local ThrowRotations = require("Bicycle/ThrowRotations")

local bicycleSprintKeyStates = {}
local bicycleSprintLockStates = {}
local BICYCLE_SPRINT_ENDURANCE_MIN = 0.5
local BICYCLE_SPRINT_ENDURANCE_RESET = 0.55

local function getEnduranceScaling(player)
    if not player then
        return 1, 1
    end

    local stats = player.getStats and player:getStats() or nil
    if not stats then
        return 1, 1
    end

    local endurance = stats:getEndurance()

    if endurance >= 0.5 then
        return 1, endurance
    end

    local scaledEndurance = math.max(0.5, endurance * 0.9 + 0.5)
    return scaledEndurance, endurance
end
local SPORTS_BOTTLE_PART_TYPE = "Sportsbottle"
local THIRST_PER_WATER_UNIT = 0.83333333333333

local function autoDrinkFromBikeSportsbottle(player, bicycleItem)
    if not (player and bicycleItem and bicycleItem.getWeaponPart) then return end

    local part = bicycleItem:getWeaponPart(SPORTS_BOTTLE_PART_TYPE)
    if not part then return end

    local waterAvailable = BicycleAttachments.getSportsbottleWaterAmount(part)
    if waterAvailable <= 0 then return end

    local stats = player:getStats()
    if not stats then return end

    local thirst = stats:getThirst()
    local threshold = (ZomboidGlobals and ZomboidGlobals.ThirstLevelToAutoDrink) or 0.1
    if thirst < threshold then return end

    local thirstReduction = math.min(thirst, waterAvailable * THIRST_PER_WATER_UNIT)
    if thirstReduction <= 0 then return end

    stats:setThirst(math.max(0, thirst - thirstReduction))

    local waterUsed = thirstReduction / THIRST_PER_WATER_UNIT
    BicycleAttachments.setSportsbottleWaterAmount(part, waterAvailable - waterUsed)
end

function BicycleHopOnAction.isValid(args)
	for i,v in ipairs(BicycleMenu.typesTable) do
		if args["character"]:getInventory():contains(tostring(v)) then
			return false
		end
	end
	return true
end

function BicycleHopOnAction:waitToStart()
	return false
end

function BicycleHopOnAction:update()

end

function BicycleHopOnAction.squareHasObject(square)
    local objects = square:getObjects()
    for i = 0, objects:size()-1 do
        local obj = objects:get(i)
        if obj and obj.isHoppable then
            local hoppable = obj:isHoppable()
            if hoppable then
                return true, obj
            end
        end
    end
    return false, nil
end

function BicycleHopOnAction.squareIsRough(square)
    local roughMaterials = {
        Sand = true,
        Grass = true,
        Gravel = true,
        Dirt = true
    }
    local function isRoughMaterial(mat)
        return roughMaterials[mat] or false
    end
    local objects = square:getObjects()
    for i = 0, objects:size()-1 do
        local obj = objects:get(i)
        local mat = obj:getProperties():Val("FootstepMaterial")
        if obj and mat and isRoughMaterial(mat) then
            return true
        end
    end
    return false, nil
end

function BicycleHopOnAction.nearbySquareHasObject(square)
    local squares = {
        square,
        square:getN(),
        square:getS(),
        square:getE(),
        square:getW(),
    }
    for _, s in ipairs(squares) do
        if s then
            local found, obj = BicycleHopOnAction.squareHasObject(s)
            if found then
                return true, obj
            end
        end
    end
    return false, nil
end

function UpdateBicycleAudio(player)
    local bicycleActive = player:getVariableBoolean("BicycleActive")
    local emitter = player:getEmitter()
    local soundVolume = PZAPI.ModOptions:getOptions("BicycleMod"):getOption("BicycleSoundVolume"):getValue()

    if not bicycleActive then
        if emitter:isPlaying('Bicycle_Riding') then
            emitter:stopSoundByName('Bicycle_Riding')
        end
        player:setVariable("Bicycle_Riding", "false")
        player:setVariable("Bicycle_RollingTimestamp", "0")
        return
    end

    if not player:getVariableBoolean("Bicycle_Riding") then
        player:setVariable("Bicycle_RollingTimestamp", "0")
        return
    end

    if emitter:isPlaying('Bicycle_Riding') and player:isPlayerMoving() then
        addSound(nil, player:getX(), player:getY(), player:getZ(), 4, 4)
        BicycleMenu.rotateWheels()
        BicycleMenu.rotatePedals()
        BicycleMenu.drainWearParts(player, player:getPrimaryHandItem())
        return
    elseif not player:isPlayerMoving() then
        emitter:stopSoundByName('Bicycle_Riding')
        return
    end

    if tonumber(player:getVariableString("Bicycle_RollingTimestamp")) < 1 then
        local ts = getTimestampMs()
        player:setVariable("Bicycle_RollingTimestamp", tostring(ts))
    end

    local startTs = tonumber(player:getVariableString("Bicycle_RollingTimestamp"))
    local currentTs = getTimestampMs()

    if currentTs - startTs >= 250 and not emitter:isPlaying('Bicycle_Riding') then
        local sound = emitter:playSound('Bicycle_Riding')
        emitter:setVolume(sound, soundVolume)
        BicycleMenu.rotateWheels()
        BicycleMenu.rotatePedals()
        BicycleMenu.drainWearParts(player, player:getPrimaryHandItem())
        addSound(nil, player:getX(), player:getY(), player:getZ(), 4, 4)
        player:setVariable("Bicycle_RollingTimestamp", "0")
    end
end

function UpdateBicycleSprint(player)
    if not player or not player.getPlayerNum then return end

    local playerNum = player:getPlayerNum()
    local runKey = getCore():getKey("Run")
    local runHeld = runKey and runKey >= 0 and isKeyDown(runKey)
    local wasHeld = bicycleSprintKeyStates[playerNum] or false
    local aimHeld = (player.isAimActive and player:isAimActive()) or (player.isAiming and player:isAiming()) or false
    local sprintRequested = runHeld or (aimHeld and wasHeld)
    local stats = player.getStats and player:getStats() or nil
    local _, enduranceValue = getEnduranceScaling(player)
    local lockState = bicycleSprintLockStates[playerNum] or false
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
    -- Keep draining endurance consistently when sprinting, even in aim state.
    local drainActive = runHeld and not lockState

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
        if aimHeld then
            enduranceDelta = -baseDrain
        end
        stats:setEndurance(stats:getEndurance() + enduranceDelta)
    end

    if wasHeld then
        if enduranceValue <= BICYCLE_SPRINT_ENDURANCE_MIN then
            player:setForceSprint(false)
            bicycleSprintKeyStates[playerNum] = nil
        end
        return
    end

    if not sprintRequested then
        return
    end

    if lockState or enduranceValue < BICYCLE_SPRINT_ENDURANCE_RESET then
        return
    end

    player:setForceSprint(true)
    bicycleSprintKeyStates[playerNum] = true
end


function BicycleFallOff(player)
    if not (player and player:getVariableBoolean("BicycleActive")) then
        return false
    end

    if player:getVariableString("CollideType") == "wall" then
        BicycleUtils.runAfter(0.95, function()
            BicycleMenu.dropBicycle(nil, {player:getPrimaryHandItem()}, 0, false, nil, nil, 0)
        end)
        player:setVariable("dismountAnim", "")
        return true
    end
    if player:getVariableBoolean("BumpFall") then
        BicycleUtils.runAfter(0.35, function()
            BicycleMenu.dropBicycle(nil, {player:getPrimaryHandItem()}, 0, false, nil, nil, 0)
            player:setVariable("dismountAnim", "")
        end)
        return true
    end

    if player:getVariableString("dismountAnim") ~= "" and not player:getVariableBoolean("Dismounting") then
        player:setVariable("dismountAnim", "")
    end
    return false
end


function UpdateBicycleFlag(player)
    local primaryItem = player:getPrimaryHandItem()
    local inventory = player:getInventory()

    if not primaryItem then
        return
    end

    if BicycleFallOff(player) then
        return
    end

    if BicycleUtils.isBicycleItem(primaryItem) then
        local queue = ISTimedActionQueue.getTimedActionQueue(player)
        local action = queue and queue.current
        if action then
            -- your override here
            action:setOverrideHandModels(primaryItem, action.item)
        end
        player:resetEquippedHandsModels()
        local damagedParts = ISHealthPanel.instance:getDamagedParts()
        player:setVariable("BicycleActive", "true")
        player:setIgnoreAutoVault(true)
        player:setBannedAttacking(true)
        BicycleMenu.updateBicycleShoutState(player, primaryItem)
        BicycleAttachments.followPlayer(player, primaryItem)
        autoDrinkFromBikeSportsbottle(player, primaryItem)
        local totalContainerWeight = 0
        for j = 1, inventory:getItems():size() do
            local item = inventory:getItems():get(j - 1)
            local typeName = item:getType()
            if ContainerMap[typeName] then
                totalContainerWeight = totalContainerWeight + item:getInventoryWeight()
            end
        end

        local weightModifier = 1
        if totalContainerWeight > 0 then
            weightModifier = math.max(0.65, 1 - 0.35 * (totalContainerWeight / 20))
        end
        local damageModifier = 1
        for _, part in ipairs(damagedParts) do
            local t = string.lower(tostring(part:getType()))
            if t:find("leg") or t:find("foot") then
                if part:HasInjury() and part:getFractureTime()>0 then
                damageModifier = 0.01
                break
                elseif part:getHealth()<75 then
                damageModifier = (part:getHealth()/100)*0.8
                break
                end
            end
        end
        local options = PZAPI.ModOptions:getOptions("BicycleMod")
        local bicycleImmersive = options:getOption("BicycleImmersive"):getValue()
        local speedMultSlow = options:getOption("SpeedMultSlow"):getValue()
        local speedMultFast = options:getOption("SpeedMultFast"):getValue()
        local sq = player:getSquare()
        local isRough = BicycleHopOnAction.squareIsRough(sq)
        local wheelConfig = BicycleMenu.getWheelConfiguration(primaryItem, player)
        local hasOffroadPair = wheelConfig.offroad >= 2 and wheelConfig.street == 0
        local attachedWheels = BicycleMenu.getAttachedWheels(primaryItem, player)

        if hasOffroadPair then
            speedMultSlow = speedMultSlow * BicycleMenu.OffroadSpeedMultiplier
            speedMultFast = speedMultFast * BicycleMenu.OffroadSpeedMultiplier
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

        if isRough and bicycleImmersive and not hasOffroadPair then
            weightModifier = weightModifier * 0.75
        end
        local enduranceScale = getEnduranceScaling(player)
        -- if enduranceScale <= 0 and player.setForceSprint then
        --     player:setForceSprint(false)
        -- end

        local finalSpeed = damageModifier * weightModifier * speedPenalty
        player:setVariable("BicycleSpeed", finalSpeed * enduranceScale)
        player:setVariable("BicycleWalkSpeed", speedMultSlow * enduranceScale)
        player:setVariable("BicycleRunSpeed", speedMultFast * enduranceScale)
        return
    end
end

local bicycleUpdateHandlersRegistered = false

local function removeBicycleUpdateHandlers()
    Events.OnPlayerUpdate.Remove(UpdateBicycleFlag)
    Events.OnPlayerUpdate.Remove(UpdateBicycleAudio)
    Events.OnPlayerUpdate.Remove(UpdateBicycleSprint)
    bicycleUpdateHandlersRegistered = false
end

function BicycleClearUpdateHandlers()
    removeBicycleUpdateHandlers()
end

function BicycleEnsureUpdateHandlers()
    if bicycleUpdateHandlersRegistered then
        return
    end
    Events.OnPlayerUpdate.Add(UpdateBicycleFlag)
    Events.OnPlayerUpdate.Add(UpdateBicycleAudio)
    Events.OnPlayerUpdate.Add(UpdateBicycleSprint)
    bicycleUpdateHandlersRegistered = true
end

function BicycleHopOnAction:start()
	self.character:setVariable("BicycleActive", "true")
	UpdateBicycleFlag(self.character)
end

function BicycleHopOnAction:stop()

end

function BicycleHopOnAction:perform()
    local inventoryItem = self.item:getItem()
    self.character:setIgnoreAutoVault(true)
    BicycleHopOnAction.equipWeapon(inventoryItem, false, true, self.character:getPlayerNum())
    if not self.saddlebag and not self.basket and not self.crate then
        self.character:setBlockMovement(false)
    end

    ISBaseTimedAction.perform(self)
end

BicycleHopOnAction.onCompleteEquip = function(playerObj, weapon)
    playerObj:setPrimaryHandItem(weapon);
    playerObj:setSecondaryHandItem(weapon);
    BicycleAttachments.onMount(playerObj, weapon)
    playerObj:setVariable("BicycleActive", "true")
    BicycleMenu.updateBicycleShoutState(playerObj, weapon)
    playerObj:setBannedAttacking(true)
    playerObj:setIgnoreAutoVault(true)
    playerObj:setAllowRun(false)
    local equipTime = 1.3
    if playerObj:getVariableString("mountAnim") == "pickUp" then
        equipTime = 1.8
    end
    if bicycleHopOnInstance and bicycleHopOnInstance.mountDirection then
        playerObj:setTurnDelta(100)
        playerObj:setBlockMovement(true)
        playerObj:setIgnoreMovement(true)
        playerObj:setDir(bicycleHopOnInstance.mountDirection)
        BicycleUtils.runAfter(equipTime, function()
            playerObj:setBlockMovement(false)
            playerObj:setIgnoreMovement(false)
            playerObj:setTurnDelta(1)
            playerObj:setVariable("mountAnim", "")
        end)
    end
    BicycleEnsureUpdateHandlers()
end

BicycleHopOnAction.equipWeapon = function(weapon, primary, twoHands, player)
	local playerObj = getSpecificPlayer(0)
    local inv = playerObj:getInventory()
	if isForceDropHeavyItem(playerObj:getPrimaryHandItem()) then
        playerObj:removeFromHands(playerObj:getPrimaryHandItem());
	end
    local action = ISInventoryTransferAction:new(playerObj, weapon, ISInventoryPage.floorContainer[1], inv, 0)
    action.bicycleMount = true
    action:setOnComplete(BicycleHopOnAction.onCompleteEquip, playerObj, weapon)
    ISTimedActionQueue.add(action)
end

SaddleBags = {}

CustomKeyPressed = function(key)
    local V_KEY = Keyboard.KEY_V
    if key == V_KEY then
		SaddleBags = {};
	end
end

function BicycleHopOnAction:new( item, player, saddlebag, basket, crate)

	local o = {}
	setmetatable( o, self)
	self.__index = self
    o.maxTime = 0
    o.character = player
    o.inventory = player:getInventory()
    o.item = item
    o.saddlebag = nil
    o.basket = nil
    o.crate = nil
	o.stopOnWalk = false
	o.stopOnRun = false
    o.stopOnAim = false
    o.options = PZAPI.ModOptions:getOptions("BicycleMod")
    o.speedMultSlow = o.options:getOption("SpeedMultSlow"):getValue()
    o.speedMultFast = o.options:getOption("SpeedMultFast"):getValue()

        o.character:setVariable("BicycleActive", "true")
    o.character:setVariable("BicycleWalkSpeed", o.speedMultSlow)
    o.character:setVariable("BicycleRunSpeed", o.speedMultFast)

    local bikeItem = item and item.getItem and item:getItem() or nil
    local wheelConfig = BicycleMenu.getWheelConfiguration(bikeItem, player)
    local hasOffroadPair = wheelConfig.offroad >= 2 and wheelConfig.street == 0

    if hasOffroadPair then
        o.speedMultSlow = o.speedMultSlow * BicycleMenu.OffroadSpeedMultiplier
        o.speedMultFast = o.speedMultFast * BicycleMenu.OffroadSpeedMultiplier
        o.character:setVariable("BicycleWalkSpeed", o.speedMultSlow)
        o.character:setVariable("BicycleRunSpeed", o.speedMultFast)
    end
    o.bikeXRotation = bikeItem and bikeItem.getWorldXRotation and bikeItem:getWorldXRotation() or nil
    o.bikeYRotation = bikeItem and bikeItem.getWorldYRotation and bikeItem:getWorldYRotation() or nil
    o.bikeZRotation = bikeItem and bikeItem.getWorldZRotation and bikeItem:getWorldZRotation() or nil

    local normalizedZRotation = o.bikeZRotation and BicycleUtils.normalizeZRotation(o.bikeZRotation - 90) or nil
    o.mountDirection = BicycleUtils.zRotationToDirection(normalizedZRotation)

    if player and player.getVariableString and player:getVariableString("mountAnim") == "pickUp" then
        local _, rotation = ThrowRotations.findMatchingRotation(o.bikeXRotation, o.bikeYRotation, o.bikeZRotation)
        if rotation and rotation.faceDir then
            local faceDirRotation = BicycleUtils.normalizeZRotation(rotation.faceDir)
            local faceDirection = BicycleUtils.zRotationToDirection(faceDirRotation)
            if faceDirection then
                o.mountDirection = faceDirection
            end
        end
    end

    if saddlebag then
        o.saddlebag = saddlebag:getItem()
    end
    if basket then
        o.basket = basket:getItem()
    end
    if crate then
        o.crate = crate:getItem()
    end

    bicycleHopOnInstance = o
	return o
end

Events.OnKeyPressed.Add(CustomKeyPressed)

return BicycleHopOnAction
