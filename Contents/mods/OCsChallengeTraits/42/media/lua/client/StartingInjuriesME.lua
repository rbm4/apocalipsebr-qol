local function setInjuryME()
    local burnPatientExclusive = {
        WoundTraitRegistry.ALL_SCRATCHED_UP,
        WoundTraitRegistry.BLEEDING_OUT,
        WoundTraitRegistry.HEADSHOT,
        -- WoundTraitRegistry.BLACKOUT,
        WoundTraitRegistry.MAULED,
        WoundTraitRegistry.CAR_CRASH,
        WoundTraitRegistry.FLAMING_WRECKAGE
    }
    
    for _, trait in ipairs(burnPatientExclusive) do
        CharacterTraitDefinition.setMutualExclusive(WoundTraitRegistry.BURN_PATIENT, trait)
    end
    
    CharacterTraitDefinition.setMutualExclusive(WoundTraitRegistry.CAR_CRASH, WoundTraitRegistry.FLAMING_WRECKAGE)
    -- CharacterTraitDefinition.setMutualExclusive(WoundTraitRegistry.SQUALOR, WoundTraitRegistry.BLACKOUT)
    -- CharacterTraitDefinition.setMutualExclusive(WoundTraitRegistry.HOUSE_FIRE, WoundTraitRegistry.BLACKOUT)
	
	local left4deadExclusive = {
        WoundTraitRegistry.HEADSHOT,
        WoundTraitRegistry.ALL_SCRATCHED_UP,
        WoundTraitRegistry.BURN_PATIENT,
        WoundTraitRegistry.SQUALOR,
        -- WoundTraitRegistry.BLACKOUT,
        WoundTraitRegistry.SKULL_FRACTURE,
        WoundTraitRegistry.BROKEN_ARM,
        WoundTraitRegistry.BROKEN_LEG,
        WoundTraitRegistry.MAULED,
        WoundTraitRegistry.BLEEDING_OUT,
        WoundTraitRegistry.CAR_CRASH,
        WoundTraitRegistry.FLAMING_WRECKAGE,
		WoundTraitRegistry.CRUSHED_HANDS
    }
    
    for _, trait in ipairs(left4deadExclusive) do
        CharacterTraitDefinition.setMutualExclusive(WoundTraitRegistry.LEFT_FOR_DEAD, trait)
    end
end

Events.OnGameBoot.Add(setInjuryME)