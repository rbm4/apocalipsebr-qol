----------------------------------------------
---- RLP TRAIT EFFECTS                    ----
----------------------------------------------

local RLPTraitEffects = {}

--- Modifica o tempo de autópsia para quem tem o trait Autopsy Specialist
function RLPTraitEffects.ModifyAutopsyDuration(character, originalTime)
    if character:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST) then
        -- Reduz o tempo em 40% para Autopsy Specialist
        return math.floor(originalTime * 0.60)
    end
    
    return originalTime
end

--- Modifica o multiplicador de XP da autópsia
function RLPTraitEffects.ModifyAutopsyXPMultiplier(character, baseMultiplier)
    if character:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST) then
        return 1.30
    end
    
    return baseMultiplier
end


--- Modifica a quantidade de amostras obtidas na autópsia em mesa
function RLPTraitEffects.ModifyAutopsySampleCount(character, baseSampleCount)
    if character:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST) then
        return 6
    end
    
    return baseSampleCount
end


--- Modifica a chance de obter sangue infectado (bom) vs sangue contaminado (ruim)
function RLPTraitEffects.ModifyAutopsyInfectedBloodChance(character, baseChance)
    if character:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST) then
        return 75
    end
    
    return baseChance
end

-- Registra a função globalmente para o mod de laboratório usar
_G.RLPTraitEffects = RLPTraitEffects