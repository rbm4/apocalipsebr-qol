local ALL_BODY_PARTS = {
    BodyPartType.Head,
	BodyPartType.Neck,
    BodyPartType.Torso_Upper,
	BodyPartType.Torso_Lower,
	BodyPartType.Groin,
    BodyPartType.UpperArm_L,
	BodyPartType.ForeArm_L,
	BodyPartType.Hand_L,
    BodyPartType.UpperArm_R,
	BodyPartType.ForeArm_R,
	BodyPartType.Hand_R,
    BodyPartType.UpperLeg_L,
	BodyPartType.LowerLeg_L,
	BodyPartType.Foot_L,
    BodyPartType.UpperLeg_R,
	BodyPartType.LowerLeg_R,
	BodyPartType.Foot_R
}

local ARM_PARTS = {
    BodyPartType.UpperArm_L, BodyPartType.UpperArm_R,
	BodyPartType.ForeArm_L, BodyPartType.ForeArm_R
}

local LEG_PARTS = {
    BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R,
	BodyPartType.LowerLeg_L, BodyPartType.LowerLeg_R
}

local HAND_PARTS = {
    BodyPartType.Hand_L,
    BodyPartType.Hand_R
}

local BODY_PART_PAIRS = {
    {primary = BodyPartType.Head, secondary = nil},
    {primary = BodyPartType.Torso_Upper, secondary = nil},
    {primary = BodyPartType.Torso_Lower, secondary = nil},
    {primary = BodyPartType.Groin, secondary = nil},
    {primary = BodyPartType.UpperArm_L, secondary = BodyPartType.UpperArm_R},
    {primary = BodyPartType.ForeArm_L, secondary = BodyPartType.ForeArm_R},
    {primary = BodyPartType.Hand_L, secondary = BodyPartType.Hand_R},
    {primary = BodyPartType.UpperLeg_L, secondary = BodyPartType.UpperLeg_R},
    {primary = BodyPartType.LowerLeg_L, secondary = BodyPartType.LowerLeg_R},
    {primary = BodyPartType.Foot_L, secondary = BodyPartType.Foot_R}
}

local DIRT_BLOOD_PARTS = {
    BloodBodyPartType.Back,
    BloodBodyPartType.Foot_L,
    BloodBodyPartType.Foot_R,
    BloodBodyPartType.ForeArm_L,
    BloodBodyPartType.ForeArm_R,
    BloodBodyPartType.Groin,
    BloodBodyPartType.Hand_L,
    BloodBodyPartType.Hand_R,
    BloodBodyPartType.Head,
    BloodBodyPartType.LowerLeg_L,
    BloodBodyPartType.LowerLeg_R,
    BloodBodyPartType.Neck,
    BloodBodyPartType.Torso_Lower,
    BloodBodyPartType.Torso_Upper,
    BloodBodyPartType.UpperArm_L,
    BloodBodyPartType.UpperArm_R,
    BloodBodyPartType.UpperLeg_L,
    BloodBodyPartType.UpperLeg_R
}



local function getRandomBodyPart(bodyDamage, bodyPartTypes)
    local index = ZombRand(1, #bodyPartTypes + 1)
    return bodyDamage:getBodyPart(bodyPartTypes[index])
end

local function applyBurn(bodyPart, minTime, maxTime)
    bodyPart:setBurned()
    bodyPart:setBurnTime(ZombRandFloat(minTime, maxTime))
    bodyPart:setNeedBurnWash(true)
end

local function applyBite(bodyPart)
    bodyPart:SetBitten(true, false)
    bodyPart:setBiteTime(ZombRandFloat(50, 80))
    bodyPart:setInfectedWound(true)
end



local function applyHeadshot(player)
    local bodyDamage = player:getBodyDamage()
    local injuredHead = bodyDamage:getBodyPart(BodyPartType.Head)
    
    injuredHead:setHaveBullet(true, 0)
    injuredHead:generateDeepWound()
end

local function applyBleedingOut(player)
    local bodyDamage = player:getBodyDamage()
    local injuredNeck = bodyDamage:getBodyPart(BodyPartType.Neck)
    
    injuredNeck:setHaveGlass(true)
    injuredNeck:generateDeepShardWound()
end

local function applySkullFracture(player)
    local bodyDamage = player:getBodyDamage()
    local fracturedHead = bodyDamage:getBodyPart(BodyPartType.Head)
    fracturedHead:generateFractureNew(ZombRandFloat(25, 35))
end

local function applyBrokenArm(player)
    local bodyDamage = player:getBodyDamage()
    local brokenArmPart = getRandomBodyPart(bodyDamage, ARM_PARTS)
    brokenArmPart:generateFracture(ZombRandFloat(65, 80))
end

local function applyBrokenLeg(player)
    local bodyDamage = player:getBodyDamage()
    local brokenLegPart = getRandomBodyPart(bodyDamage, LEG_PARTS)
    brokenLegPart:generateFractureNew(ZombRandFloat(65, 80))
end

local function applyCrushedHands(player)
    local bodyDamage = player:getBodyDamage()
    
    local leftHand = bodyDamage:getBodyPart(BodyPartType.Hand_L)
    local rightHand = bodyDamage:getBodyPart(BodyPartType.Hand_R)
    
    leftHand:generateFracture(ZombRandFloat(65, 80))
    rightHand:generateFracture(ZombRandFloat(65, 80))
end

local function applyAllScratchedUp(player)
    local bodyDamage = player:getBodyDamage()
    
    for _, choice in ipairs(BODY_PART_PAIRS) do
        local bodyPartType
        
        if choice.secondary then
            local rolledSide = (ZombRand(2) == 0) and choice.primary or choice.secondary
            
            if bodyDamage:IsScratched(rolledSide) then
                bodyPartType = ((rolledSide == choice.primary) and choice.secondary) or choice.primary
            else
                bodyPartType = rolledSide
            end
        else
            bodyPartType = choice.primary
        end
        
        bodyDamage:getBodyPart(bodyPartType):setScratched(true, true)
    end
end

local function applySqualor(player, includeDrunk, hungerLevel)
    local bodyDamage = player:getBodyDamage()
    local stats = player:getStats()
    local inventory = player:getInventory()
    
    inventory:clear()
    player:clearWornItems()
    
    player:setClothingItem_Feet(nil)
    player:setClothingItem_Legs(nil)
    player:setClothingItem_Torso(nil)
    
    stats:set(CharacterStat.STRESS, 1.0)
    stats:set(CharacterStat.PANIC, 100)
    stats:set(CharacterStat.ENDURANCE, 0.0)
    stats:set(CharacterStat.FATIGUE, 0.61)
    stats:set(CharacterStat.HUNGER, hungerLevel)
    stats:set(CharacterStat.THIRST, 1.0)
    stats:set(CharacterStat.SICKNESS, 1.0)
    stats:set(CharacterStat.UNHAPPINESS, 100)
    
    if includeDrunk then
        stats:set(CharacterStat.INTOXICATION, 100)
    end
    
    bodyDamage:setCatchACold(0.0)
    bodyDamage:setHasACold(true)
    bodyDamage:setColdStrength(20.0)
    bodyDamage:setTimeToSneezeOrCough(0)
    bodyDamage:setIsFakeInfected(true)
    
    for _, bodyPartType in ipairs(ALL_BODY_PARTS) do
        bodyDamage:getBodyPart(bodyPartType):setWetness(100)
    end
    
    for _, limbType in ipairs(ARM_PARTS) do
        bodyDamage:getBodyPart(limbType):addStiffness(100)
    end
    
    for _, limbType in ipairs(LEG_PARTS) do
        bodyDamage:getBodyPart(limbType):addStiffness(100)
    end
    
    for _, limbType in ipairs(HAND_PARTS) do
        bodyDamage:getBodyPart(limbType):addStiffness(100)
    end
   
    bodyDamage:getBodyPart(BodyPartType.Foot_L):addStiffness(100)
    bodyDamage:getBodyPart(BodyPartType.Foot_R):addStiffness(100)
    
    local visual = player:getHumanVisual()
    if visual then
        for _, dirtPart in ipairs(DIRT_BLOOD_PARTS) do
            visual:setDirt(dirtPart, 0.9)
            visual:setBlood(dirtPart, 0.9)
        end
    end
end

local function createCDDAExplosions(player)
    local square = player:getCurrentSquare()
    if not square then return end
    
    local cell = getCell()
    local room = square:getRoom()
    if not room then return end
    
    local building = room:getBuilding()
    if not building then return end
    
    local i = 0
    while i <= 4 do
        local tile = building:getRandomRoom():getRandomSquare()
        if tile:getRoom() == room then
        else
            i = i + 1
            IsoFireManager.explode(cell, tile, 100000)
        end
    end
    
    local roomSquares = room:getSquares()
    if roomSquares then
        for i = 0, roomSquares:size() - 1 do
            local roomTile = roomSquares:get(i)
            if roomTile then
                roomTile:stopFire()
            end
        end
    end
end

local function delayedExplosions()
    local player = getPlayer()
    if player then
        createCDDAExplosions(player)
        Events.OnTick.Remove(delayedExplosions)
    end
end

local function applyBlackout(player)
    local bodyDamage = player:getBodyDamage()
    local stats = player:getStats()
    local inventory = player:getInventory()
    
    stats:set(CharacterStat.INTOXICATION, 100)
    
    inventory:clear()
    player:clearWornItems()
    
    player:setClothingItem_Feet(nil)
    player:setClothingItem_Legs(nil)
    player:setClothingItem_Torso(nil)
    
    for _, bodyPartType in ipairs(ALL_BODY_PARTS) do
        bodyDamage:getBodyPart(bodyPartType):setWetness(100)
    end
    
    bodyDamage:setCatchACold(0.0)
    bodyDamage:setHasACold(true)
    bodyDamage:setColdStrength(20.0)
    bodyDamage:setTimeToSneezeOrCough(0)
    
    local injuredGroin = bodyDamage:getBodyPart(BodyPartType.Groin)
    injuredGroin:generateDeepShardWound()
    
    if SandboxVars.StartingInjuriesMod.EnableBlackoutExplosions then
		Events.OnTick.Add(delayedExplosions)
    end
end

local function applyHouseFire(player)
    Events.OnTick.Add(delayedExplosions)
end

local function applyMauled(player)
    local bodyDamage = player:getBodyDamage()
    local isLeftSide = ZombRand(2) == 0
    
    local bittenHand, bittenThigh, bittenArm
    local bittenFace = bodyDamage:getBodyPart(BodyPartType.Head)
    local scratchedTorso = bodyDamage:getBodyPart(BodyPartType.Torso_Lower)
    
    if isLeftSide then
        bittenHand = bodyDamage:getBodyPart(BodyPartType.Hand_L)
        bittenThigh = bodyDamage:getBodyPart(BodyPartType.UpperLeg_R)
        
        local rightArm = bodyDamage:getBodyPart(BodyPartType.ForeArm_R)
        if not rightArm:isDeepWounded() then
            bittenArm = rightArm
        else
            bittenArm = bodyDamage:getBodyPart(BodyPartType.ForeArm_L)
        end
    else
        bittenHand = bodyDamage:getBodyPart(BodyPartType.Hand_R)
        bittenThigh = bodyDamage:getBodyPart(BodyPartType.UpperLeg_L)
        
        local leftArm = bodyDamage:getBodyPart(BodyPartType.ForeArm_L)
        if not leftArm:isDeepWounded() then
            bittenArm = leftArm
        else
            bittenArm = bodyDamage:getBodyPart(BodyPartType.ForeArm_R)
        end
    end
    
    applyBite(bittenHand)
    applyBite(bittenThigh)
    applyBite(bittenFace)
    applyBite(bittenArm)
    
    scratchedTorso:setScratched(true, true)
end


local function applyCarCrash(player)
    local bodyDamage = player:getBodyDamage()
    local stats = player:getStats()
    
    local fracturedTorso = bodyDamage:getBodyPart(BodyPartType.Torso_Upper)
    local sprainedNeck = bodyDamage:getBodyPart(BodyPartType.Neck)
    local sprainedWrist = getRandomBodyPart(bodyDamage, HAND_PARTS)
    local injuredArm = getRandomBodyPart(bodyDamage, {BodyPartType.ForeArm_L, BodyPartType.ForeArm_R})
    local injuredShin = getRandomBodyPart(bodyDamage, {BodyPartType.LowerLeg_L, BodyPartType.LowerLeg_R})
    
    fracturedTorso:generateFracture(ZombRandFloat(25, 35))
    injuredArm:setHaveGlass(true)
    injuredArm:generateDeepShardWound()
    injuredShin:setScratched(true, true)
    sprainedWrist:addStiffness(100)
    sprainedNeck:addStiffness(100)
    
    stats:set(CharacterStat.STRESS, 0.5)
    stats:set(CharacterStat.ENDURANCE, 0.5)
end

local function applyFlamingWreckage(player)
    local bodyDamage = player:getBodyDamage()
    local stats = player:getStats()
    local isLeftSide = ZombRand(2) == 0
    
    local burnedHead, injuredArm, burnedTorso, burnedThigh, burnedShin
    
    if isLeftSide then
        burnedHead = bodyDamage:getBodyPart(BodyPartType.Head)
        injuredArm = bodyDamage:getBodyPart(BodyPartType.ForeArm_L)
        burnedTorso = bodyDamage:getBodyPart(BodyPartType.Torso_Upper)
        burnedThigh = bodyDamage:getBodyPart(BodyPartType.UpperLeg_L)
        burnedShin = bodyDamage:getBodyPart(BodyPartType.LowerLeg_L)
    else
        burnedHead = bodyDamage:getBodyPart(BodyPartType.Head)
        injuredArm = bodyDamage:getBodyPart(BodyPartType.ForeArm_R)
        burnedTorso = bodyDamage:getBodyPart(BodyPartType.Torso_Upper)
        burnedThigh = bodyDamage:getBodyPart(BodyPartType.UpperLeg_R)
        burnedShin = bodyDamage:getBodyPart(BodyPartType.LowerLeg_R)
    end
    
    local sprainedNeck = bodyDamage:getBodyPart(BodyPartType.Neck)
    local sprainedWrist = getRandomBodyPart(bodyDamage, HAND_PARTS)
    local fracturedRibs = bodyDamage:getBodyPart(BodyPartType.Torso_Upper)
    
    applyBurn(burnedThigh, 85, 95)
    applyBurn(burnedHead, 30, 50)
    applyBurn(burnedTorso, 50, 70)
    applyBurn(burnedShin, 50, 70)
    
    injuredArm:setHaveGlass(true)
    injuredArm:generateDeepShardWound()
    applyBurn(injuredArm, 30, 50)
    
    burnedShin:setScratched(true, true)
    
    sprainedNeck:addStiffness(100)
    sprainedWrist:addStiffness(100)
    fracturedRibs:generateFracture(ZombRandFloat(25, 35))
	
    stats:set(CharacterStat.STRESS, 0.5)
    stats:set(CharacterStat.ENDURANCE, 0.5)
end

local function applyBurnPatient(player)
    local bodyDamage = player:getBodyDamage()
    
    for _, bodyPartType in ipairs(ALL_BODY_PARTS) do
        local bodyPart = bodyDamage:getBodyPart(bodyPartType)
        bodyPart:setBurned()
        bodyPart:setBurnTime(ZombRand(25, 100))
        
        local needsCleaning = ZombRand(1, 5) == 4
        
        if needsCleaning then
            bodyPart:setNeedBurnWash(true)
            bodyPart:setBandaged(true, 0, false, "Base.Bandage")
        else
            bodyPart:setNeedBurnWash(false)
            bodyPart:setBandaged(true, ZombRandFloat(1.5, 4.0), false, "Base.Bandage")
        end
    end
end

local function applyLeft4Dead(player)
    local bodyDamage = player:getBodyDamage()
    
    local leftHand = bodyDamage:getBodyPart(BodyPartType.Hand_L)
    local rightHand = bodyDamage:getBodyPart(BodyPartType.Hand_R)
    local injuredFoot = getRandomBodyPart(bodyDamage, {BodyPartType.Foot_L, BodyPartType.Foot_R})
    local injuredThigh = getRandomBodyPart(bodyDamage, {BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R})
    local brokenShin = getRandomBodyPart(bodyDamage, {BodyPartType.LowerLeg_L, BodyPartType.LowerLeg_R})
    local shotArm = getRandomBodyPart(bodyDamage, {BodyPartType.UpperArm_L, BodyPartType.UpperArm_R})
    local bittenArm = getRandomBodyPart(bodyDamage, {BodyPartType.ForeArm_L, BodyPartType.ForeArm_R})
    local burnedGroin = bodyDamage:getBodyPart(BodyPartType.Groin)
    local scratchedHead = bodyDamage:getBodyPart(BodyPartType.Head)
    
    injuredThigh:setCut(true, true)
    injuredThigh:setBleedingTime(0)
	injuredThigh:setBandaged(true, 0, false, "Base.Base.Bandaid")
	
    rightHand:generateFracture(ZombRandFloat(55, 65))
	brokenShin:generateFracture(ZombRandFloat(85, 95))
    
    applyBurn(burnedGroin, 85, 95)
	burnedGroin:setBandaged(true, 0, false, "Base.Base.Bandaid")
    
    injuredFoot:generateDeepShardWound()
	injuredFoot:setBandaged(true, 0, false, "Base.Base.Bandaid")
    
    shotArm:setHaveBullet(true, 0)
    shotArm:generateDeepWound()
    shotArm:setBleedingTime(0)
	shotArm:setBandaged(true, 0, false, "Base.Bandaid")
    
    applyBite(bittenArm)
    bittenArm:setBleedingTime(0)
	bittenArm:setBandaged(true, 0, false, "Base.Base.Bandaid")
    
    scratchedHead:setScratched(true, true)
	scratchedHead:setInfectedWound(true)
    
    applySqualor(player, false, 0.65)
end

local function easyModeBandages(player)
    local bandageCount = 0
    
    if player:hasTrait(WoundTraitRegistry.HEADSHOT) then
        bandageCount = bandageCount + 1
    end
	
    if player:hasTrait(WoundTraitRegistry.BLEEDING_OUT) then
        bandageCount = bandageCount + 1
    end
    
    if player:hasTrait(WoundTraitRegistry.CAR_CRASH) then
        bandageCount = bandageCount + 2
    end
    
    if player:hasTrait(WoundTraitRegistry.FLAMING_WRECKAGE) then
        bandageCount = bandageCount + 3
    end
    
    if player:hasTrait(WoundTraitRegistry.MAULED) then
        bandageCount = bandageCount + 4
    end
    
    if player:hasTrait(WoundTraitRegistry.ALL_SCRATCHED_UP) then
        bandageCount = bandageCount + 5
    end
    
    bandageCount = math.min(bandageCount, 6)
    
    if bandageCount > 0 then
        for i = 1, bandageCount do
			player:getInventory():addItem(ItemKey.Normal.BANDAID)
		end
    end
end

local function initWounds(player)
    
    if player:hasTrait(WoundTraitRegistry.BROKEN_ARM) then
        applyBrokenArm(player)
    end
    
    if player:hasTrait(WoundTraitRegistry.BROKEN_LEG) then
        applyBrokenLeg(player)
    end
	
	if player:hasTrait(WoundTraitRegistry.SKULL_FRACTURE) then
		applySkullFracture(player)
	end
    
    -- if player:hasTrait(WoundTraitRegistry.BLACKOUT) then
    --     applyBlackout(player)
    -- end
	
    if player:hasTrait(WoundTraitRegistry.HEADSHOT) then
        applyHeadshot(player)
    end
    
    if player:hasTrait(WoundTraitRegistry.BURN_PATIENT) then
        applyBurnPatient(player)
    end
    
    if player:hasTrait(WoundTraitRegistry.MAULED) then
        applyMauled(player)
    end
    
    if player:hasTrait(WoundTraitRegistry.BLEEDING_OUT) then
        applyBleedingOut(player)
    end
    
    if player:hasTrait(WoundTraitRegistry.CAR_CRASH) then
        applyCarCrash(player)
    end
    
    if player:hasTrait(WoundTraitRegistry.FLAMING_WRECKAGE) then
        applyFlamingWreckage(player)
    end
    
    if player:hasTrait(WoundTraitRegistry.ALL_SCRATCHED_UP) then
        applyAllScratchedUp(player)
    end
	
    if player:hasTrait(WoundTraitRegistry.SQUALOR) then
		applySqualor(player, true, 1.0)
	end
	
	if player:hasTrait(WoundTraitRegistry.LEFT_FOR_DEAD) then
		applyLeft4Dead(player)
	end
	
	if player:hasTrait(WoundTraitRegistry.CRUSHED_HANDS) then
		applyCrushedHands(player)
	end
	
	-- if player:hasTrait(WoundTraitRegistry.HOUSE_FIRE) then
	-- 	applyHouseFire(player)
	-- end
	
	if SandboxVars.StartingInjuriesMod.EnableBandageAssistance then
		easyModeBandages(player)
	end
end

Events.OnNewGame.Add(initWounds)