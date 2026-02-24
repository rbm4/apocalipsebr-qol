-- VaccineLogic_Server.lua
-- Agora vacinas fazem com que o corpo lute contra a infecção, retardando o tempo de mortalidade
-- quando o jogador está infectado e a taxa de infecção é maior que 40%, o corpo tenta lutar contra a infecção
-- baseado na força da vacina injetada (RECESS). Ao término do período de recess, rola uma tentativa de cura.
-- Se a vacina for de qualidade superior à anterior, seus efeitos substituem os anteriores.

local VaccineLogic = {}

local vaccineEffect = {
    CmpSyringeWithPlainVaccine = {
        Min = 0.15, Max = 0.86, CureChance = 5, InfectChance = 40,
        Time = 0, Strength = 0, AlbuminMin = 3, AlbuminDelta = 4, Recess = 0,
        Quality = 1
    },
    CmpSyringeWithQualityVaccine = {
        Min = 0.10, Max = 0.91, CureChance = 10, InfectChance = 10,
        Time = 168, Strength = 20, AlbuminMin = 5, AlbuminDelta = 5, Recess = 6,
        Quality = 2
    },
    CmpSyringeWithAdvancedVaccine = {
        Min = 0.05, Max = 0.96, CureChance = 15, InfectChance = 1,
        Time = 504, Strength = 65, AlbuminMin = 8, AlbuminDelta = 6, Recess = 12,
        Quality = 3
    },
    CmpSyringeWithCure = {
        Min = -1, Max = 0.99, CureChance = 105, InfectChance = 0,
        Time = 0, Strength = 0, AlbuminMin = 0, AlbuminDelta = 0, Recess = 0,
        Quality = 4
    },
    CmpSyringeReusableWithPlainVaccine = {
        Min = 0.15, Max = 0.86, CureChance = 5, InfectChance = 40,
        Time = 0, Strength = 0, AlbuminMin = 3, AlbuminDelta = 4, Recess = 0,
        Quality = 1
    },
    CmpSyringeReusableWithQualityVaccine = {
        Min = 0.10, Max = 0.91, CureChance = 10, InfectChance = 10,
        Time = 168, Strength = 20, AlbuminMin = 5, AlbuminDelta = 5, Recess = 6,
        Quality = 2
    },
    CmpSyringeReusableWithAdvancedVaccine = {
        Min = 0.05, Max = 0.96, CureChance = 15, InfectChance = 1,
        Time = 504, Strength = 65, AlbuminMin = 8, AlbuminDelta = 6, Recess = 12,
        Quality = 3
    },
    CmpSyringeReusableWithCure = {
        Min = -1, Max = 0.99, CureChance = 105, InfectChance = 0,
        Time = 0, Strength = 0, AlbuminMin = 0, AlbuminDelta = 0, Recess = 0,
        Quality = 4
    },
}

local function SafeCall(obj, funcName, arg)
    if obj then
        pcall(function() 
            if obj[funcName] then obj[funcName](obj, arg) end
        end)
    end
end

local function IsInfectedBool(bd)
    local val = false
    if bd and bd.isInfected then
        local ok, res = pcall(function() return bd:isInfected() end)
        if ok then val = res end
    end
    return val
end

local function InfectionRate(player)
    local body = player:getBodyDamage()
    local deathTime = body:getInfectionMortalityDuration()
    if deathTime <= 0 then return 0 end
    return (player:getHoursSurvived() - body:getInfectionTime()) / deathTime
end

function VaccineLogic.GetInfectionRate(player)
    return InfectionRate(player)
end

-- Normal random distribution (do código original B41)
local function RandNorm(min, max, mean, dev)
    local u1 = ZombRandFloat(0.01, 0.99)
    local u2 = ZombRandFloat(0.01, 0.99)
    local rnd = mean * math.abs(1 + math.sqrt(-2 * (math.log(u1))) * math.cos(2 * math.pi * u2) * dev)
    return min + math.floor(rnd / 2 * (max - min) + 0.5)
end

local function CurePlayer(body, player)
    if not body or not player then return false end
    
    SafeCall(body, "setInfected", false)
    SafeCall(body, "setInfectionTime", -1.0)
    SafeCall(body, "setInfectionMortalityDuration", -1.0)

    pcall(function()
        player:getStats():set(CharacterStat.ZOMBIE_INFECTION, 0)
    end)
    
    SafeCall(body, "setMortalityDuration", -1)
    SafeCall(body, "setIsFakeInfected", false)

    local bodyParts = body:getBodyParts()
    for i = 0, bodyParts:size() - 1 do
        local part = bodyParts:get(i)
        if part then
            SafeCall(part, "SetInfected", false)
            SafeCall(part, "SetFakeInfected", false)
        end
    end
    
    local pMod = player:getModData()
    pMod.Infected = false
    pMod.InfectionTime = nil
    pMod.VaccineRecess = 0
    pMod.VaccineTime = 0
    pMod.VaccineStrength = 0
    pMod.VaccineQuality = 0
    
    player:transmitModData()
    
    return not IsInfectedBool(body)
end

local function InfectPlayerAccidental(body, player)
    SafeCall(body, "setInfected", true)
    SafeCall(body, "setInfectionMortalityDuration", body:pickMortalityDuration())
    SafeCall(body, "setInfectionTime", player:getHoursSurvived())
    
    local bodyParts = body:getBodyParts()
    local torsoUpper = bodyParts:get(BodyPartType.ToIndex(BodyPartType.Torso_Upper))
    
    if torsoUpper then
        SafeCall(torsoUpper, "SetInfected", true)
    else
        for i = 0, bodyParts:size() - 1 do
            local part = bodyParts:get(i)
            if part then
                SafeCall(part, "SetInfected", true)
                break
            end
        end
    end
end

function VaccineLogic.ApplyRecessEffect(player)
    if not player then return end
    
    local body = player:getBodyDamage()
    if not body then return end
    
    local pMod = player:getModData()
    if not pMod then return end
    
    local isInfected = IsInfectedBool(body)
    
    if isInfected and pMod.VaccineRecess and pMod.VaccineRecess > 0 then
        local rate = InfectionRate(player)
        
        if rate >= 0.4 then
            local mortalityDuration = body:getInfectionMortalityDuration()
            local currentInfectionTime = body:getInfectionTime()
            
            local delayPercent = RandNorm(0, 30, 1.1, 0.35) / 100
            local delayAmount = mortalityDuration * delayPercent
            
            SafeCall(body, "setInfectionTime", currentInfectionTime + delayAmount)
        end
    end
end

function VaccineLogic.ProcessInjection(player, itemType)
    if not player or not itemType then return end

    local vaccine = vaccineEffect[itemType]
    if not vaccine then return end

    local body = player:getBodyDamage()
    if not body then return end

    local pMod = player:getModData()
    
    if not pMod.VaccineQuality then
        pMod.VaccineQuality = 0
    end
    
    local currentQuality = pMod.VaccineQuality or 0
    local newQuality = vaccine.Quality or 0
    
    local shouldUpdateProtection = (newQuality >= currentQuality)
    
    local isInfected = IsInfectedBool(body)
    
    if isInfected then
        local roll = ZombRand(100)
        
        if vaccine.CureChance > roll then
            CurePlayer(body, player)
            return
        end

        local rate = InfectionRate(player)
        
        if rate > vaccine.Min and rate <= vaccine.Max then
            SafeCall(body, "setInfectionTime", 
                player:getHoursSurvived() - (vaccine.Min * body:getInfectionMortalityDuration()))
            
            if shouldUpdateProtection and vaccine.AlbuminMin > 0 then
                pMod.AlbuminDoses = vaccine.AlbuminMin + ZombRand(vaccine.AlbuminDelta)
            end
            
            if shouldUpdateProtection then
                pMod.VaccineRecess = vaccine.Recess
                pMod.VaccineQuality = newQuality
            end
        end
        
        player:transmitModData()
        return
    end

    if vaccine.InfectChance > ZombRand(100) then
        InfectPlayerAccidental(body, player)
        return
    end

    if shouldUpdateProtection then
        pMod.VaccineTime = vaccine.Time
        pMod.VaccineStrength = vaccine.Strength
        pMod.VaccineRecess = vaccine.Recess
        pMod.VaccineQuality = newQuality
    end
    
    player:transmitModData()
end

function VaccineLogic.ConsumeSyringe(player, itemType)
    local inv = player:getInventory()
    
    local syringeToRemove = inv:getItemFromType(itemType)
    if syringeToRemove then
        player:removeFromHands(syringeToRemove)
        inv:Remove(syringeToRemove)
        sendRemoveItemFromContainer(inv, syringeToRemove)
    end
    
    local newItemType
    if itemType:find("Reusable") then
        newItemType = "LabItems.LabSyringeReusableUsed"
    else
        newItemType = "LabItems.LabSyringeUsed"
    end
    
    local newItem = inv:AddItem(newItemType)
    if newItem then
        sendAddItemToContainer(inv, newItem)
    end
end

return VaccineLogic