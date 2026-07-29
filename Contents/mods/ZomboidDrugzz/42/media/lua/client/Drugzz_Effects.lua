require "Drugzz_Core"

local function activeEffect(character, family, effect)
    local profile = Drugzz.FAMILY_PROFILES[family]
    if not profile then
        return
    end

    local intensity = Drugzz.clamp((effect.intensity or 0) / 100, 0.10, 1.0)
    Drugzz.applyStats(character, profile.active, intensity)

    if family == "psychedelic" and ZombRand(100) < 7 then
        Drugzz.adjustStat(character, CharacterStat.PANIC, ZombRand(3, 11) * intensity)
    end

    effect.intensity = math.max(0, (effect.intensity or 0) - 1.35)
end

local function comedown(character, family, effect)
    local profile = Drugzz.FAMILY_PROFILES[family]
    if not profile then
        return
    end

    local intensity = Drugzz.clamp((effect.intensity or 0) / 100, 0.15, 1.0)
    Drugzz.applyStats(character, profile.comedown, intensity)
    effect.intensity = math.max(0, (effect.intensity or 0) - 2.5)
end

local symptomProfiles = {
    dryMouth = { thirst = 0.012, unhappiness = 0.10 },
    nausea = { foodSickness = 0.80, unhappiness = 0.25 },
    badTrip = { panic = 1.35, stress = 0.012, unhappiness = 0.35 },
    stimulantPanic = { panic = 0.70, stress = 0.008 },
    overheating = { temperature = 0.018, thirst = 0.012, fatigue = 0.003 },
    tremor = { panic = 0.30, stress = 0.006, endurance = -0.003 },
    jawPain = { pain = 0.18, unhappiness = 0.12 },
}

local function severeNauseaMoment(character, symptom)
    if ZombRand(1000) >= (4 * (symptom.intensity or 1)) then
        return
    end

    Drugzz.setStatAtLeast(character, CharacterStat.FOOD_SICKNESS, 42)
    Drugzz.adjustStat(character, CharacterStat.THIRST, 0.08)
    Drugzz.adjustStat(character, CharacterStat.HUNGER, 0.05)
    Drugzz.adjustStat(character, CharacterStat.FATIGUE, 0.025)
    Drugzz.note(character, "IGUI_Drugzz_Retching", "You gag and fight the urge to throw up.", 220, 180, 100)

    if character.Say and ZombRand(100) < 35 then
        character:Say("*retches*")
    end
end

local function symptomTick(character, state, now)
    for symptomName, symptom in pairs(state.symptoms or {}) do
        if now <= (symptom.untilHour or 0) then
            local changes = symptomProfiles[symptomName]
            if changes then
                Drugzz.applyStats(character, changes, symptom.intensity or 1)
            end

            if symptomName == "nausea" then
                severeNauseaMoment(character, symptom)
            end
        else
            state.symptoms[symptomName] = nil
        end
    end
end

local function dependenceTick(character, state, now)
    if not Drugzz.getOption("EnableDependence", true) then
        return
    end

    for family, familyState in pairs(state.families or {}) do
        local profile = Drugzz.FAMILY_PROFILES[family]
        local dependence = familyState.dependence or 0
        local lastUse = familyState.lastUseHour or now
        local abstinentHours = math.max(0, now - lastUse)

        if profile and dependence > 0.12
            and abstinentHours >= profile.withdrawalStart
            and abstinentHours <= profile.withdrawalEnd then

            local scale = Drugzz.clamp(dependence, 0.15, 1.0)
            Drugzz.applyStats(character, profile.withdrawal, scale)

            if not state.withdrawalNoted[family] then
                Drugzz.note(
                    character,
                    "IGUI_Drugzz_Withdrawal_" .. family,
                    "Withdrawal is setting in.",
                    225,
                    160,
                    120,
                    300
                )
                state.withdrawalNoted[family] = true
            end
        elseif abstinentHours > (profile and profile.withdrawalEnd or 96) and dependence > 0 then
            familyState.dependence = math.max(0, dependence - 0.006)
            familyState.uses = math.max(0, (familyState.uses or 0) - 0.05)
            familyState.tolerance = math.max(0, (familyState.tolerance or 0) - 0.03)
            state.withdrawalNoted[family] = nil
        elseif abstinentHours < (profile and profile.withdrawalStart or 24) then
            state.withdrawalNoted[family] = nil
        end
    end
end

local function updateCharacter(character)
    if not character or character:isDead() then
        return
    end

    local state = Drugzz.getState(character)
    local now = Drugzz.getWorldHours()
    Drugzz.decayLoad(state, now)

    for family, effect in pairs(state.effects or {}) do
        if now <= (effect.untilHour or 0) then
            activeEffect(character, family, effect)
        elseif now <= (effect.comedownUntil or 0) then
            comedown(character, family, effect)
        else
            state.effects[family] = nil
        end
    end

    symptomTick(character, state, now)
    dependenceTick(character, state, now)
    Drugzz.syncState(character, state, false)
end

local function everyTenMinutes()
    for playerIndex = 0, getNumActivePlayers() - 1 do
        updateCharacter(getSpecificPlayer(playerIndex))
    end
end

Events.EveryTenMinutes.Add(everyTenMinutes)
