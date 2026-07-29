Drugzz = Drugzz or {}

Drugzz.VERSION = "2.5.2"

Drugzz.TRAIT_IDS = {
    CANNABIS_CONNOISSEUR = "zdrugzz:cannabisconnoisseur",
    STONER = "zdrugzz:stoner",
    PSYCHONAUT = "zdrugzz:psychonaut",
    COCAINE_DEPENDENT = "zdrugzz:cocainedependent",
    CRACK_DEPENDENT = "zdrugzz:crackdependent",
    METH_DEPENDENT = "zdrugzz:methdependent",
    CLUB_REGULAR = "zdrugzz:clubregular",
    PRESCRIPTION_DEPENDENT = "zdrugzz:prescriptiondependent",
}

Drugzz._traitCache = Drugzz._traitCache or {}
Drugzz.PROFESSION_ID = "zdrugzz:drugdealer"
Drugzz._professionCache = Drugzz._professionCache or {}

local function getOptions()
    if SandboxVars and SandboxVars.ZomboidDrugzz then
        return SandboxVars.ZomboidDrugzz
    end
    return {}
end

function Drugzz.getOption(name, fallback)
    local options = getOptions()
    if options[name] == nil then
        return fallback
    end
    return options[name]
end

function Drugzz.getWorldHours()
    local gameTime = getGameTime and getGameTime()
    if gameTime and gameTime.getWorldAgeHours then
        return gameTime:getWorldAgeHours()
    end
    return 0
end

function Drugzz.clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

function Drugzz.note(character, key, fallback, red, green, blue, duration)
    if not character or not character.setHaloNote then
        return
    end

    local text = fallback
    if getText then
        local translated = getText(key)
        if translated and translated ~= key then
            text = translated
        end
    end

    character:setHaloNote(text, red or 220, green or 220, blue or 220, duration or 250)
end

function Drugzz.hasTrait(character, traitKey)
    if not character then
        return false
    end

    local id = Drugzz.TRAIT_IDS[traitKey]
    if not id or not CharacterTrait or not ResourceLocation then
        return false
    end

    local trait = Drugzz._traitCache[traitKey]
    if not trait then
        trait = CharacterTrait.get(ResourceLocation.of(id))
        Drugzz._traitCache[traitKey] = trait
    end

    return trait and character:hasTrait(trait) or false
end

function Drugzz.hasProfession(character, professionId)
    if not character or not character.getDescriptor or not CharacterProfession or not ResourceLocation then
        return false
    end

    professionId = professionId or Drugzz.PROFESSION_ID
    local profession = Drugzz._professionCache[professionId]
    if not profession then
        profession = CharacterProfession.get(ResourceLocation.of(professionId))
        Drugzz._professionCache[professionId] = profession
    end

    local descriptor = character:getDescriptor()
    return profession and descriptor and descriptor:isCharacterProfession(profession) or false
end

function Drugzz.getState(character)
    if not character then
        return nil
    end

    local modData = character:getModData()
    modData.ZomboidDrugzz = modData.ZomboidDrugzz or {}

    local state = modData.ZomboidDrugzz
    state.load = state.load or 0
    state.cannabisLoad = state.cannabisLoad or 0
    state.hardLoad = state.hardLoad or 0
    state.lastLoadHour = state.lastLoadHour or Drugzz.getWorldHours()
    state.families = state.families or {}
    state.effects = state.effects or {}
    state.symptoms = state.symptoms or {}
    state.withdrawalNoted = state.withdrawalNoted or {}
    return state
end

function Drugzz.syncState(character, state, force)
    if not character or not state or not isClient or not isClient() then
        return
    end

    local now = Drugzz.getWorldHours()
    if force or now - (state.lastTransmitHour or 0) >= 1 then
        if character.transmitModData then
            character:transmitModData()
        end
        state.lastTransmitHour = now
    end
end

function Drugzz.getFamilyState(state, family, now)
    local familyState = state.families[family]
    if not familyState then
        familyState = {
            uses = 0,
            tolerance = 0,
            dependence = 0,
            lastUseHour = now,
            lastToleranceHour = now,
        }
        state.families[family] = familyState
    end
    return familyState
end

function Drugzz.adjustStat(character, stat, amount)
    if not character or not stat or not amount or amount == 0 then
        return
    end

    local stats = character:getStats()
    local current = stats:get(stat)
    local minimum = stat.getMinimumValue and stat:getMinimumValue() or 0
    local maximum = stat.getMaximumValue and stat:getMaximumValue() or 100
    stats:set(stat, Drugzz.clamp(current + amount, minimum, maximum))
end

function Drugzz.setStatAtLeast(character, stat, value)
    if not character or not stat then
        return
    end

    local stats = character:getStats()
    if stats:get(stat) < value then
        stats:set(stat, math.min(value, stat:getMaximumValue()))
    end
end

function Drugzz.damageHealth(character, amount)
    if not character or amount <= 0 then
        return
    end

    local bodyDamage = character:getBodyDamage()
    if bodyDamage and bodyDamage.ReduceGeneralHealth then
        bodyDamage:ReduceGeneralHealth(amount)
    end
end

local statMap = {
    boredom = CharacterStat.BOREDOM,
    endurance = CharacterStat.ENDURANCE,
    fatigue = CharacterStat.FATIGUE,
    foodSickness = CharacterStat.FOOD_SICKNESS,
    hunger = CharacterStat.HUNGER,
    pain = CharacterStat.PAIN,
    panic = CharacterStat.PANIC,
    stress = CharacterStat.STRESS,
    temperature = CharacterStat.TEMPERATURE,
    thirst = CharacterStat.THIRST,
    unhappiness = CharacterStat.UNHAPPINESS,
}

function Drugzz.applyStats(character, changes, scale)
    if not changes then
        return
    end

    scale = scale or 1
    for name, amount in pairs(changes) do
        local stat = statMap[name]
        if stat then
            Drugzz.adjustStat(character, stat, amount * scale)
        end
    end
end

Drugzz.FAMILY_PROFILES = {
    cannabis = {
        active = { stress = -0.010, panic = -0.65, pain = -0.28, fatigue = 0.004, hunger = 0.005, thirst = 0.004 },
        comedown = { fatigue = 0.004, hunger = 0.002 },
        withdrawalStart = 12,
        withdrawalEnd = 120,
        withdrawal = { stress = 0.007, unhappiness = 0.45, fatigue = 0.003, panic = 0.20 },
    },
    psychedelic = {
        active = { boredom = -1.05, unhappiness = -0.45, fatigue = 0.002, thirst = 0.002 },
        comedown = { fatigue = 0.007, unhappiness = 0.25 },
        withdrawalStart = 9999,
        withdrawalEnd = 9999,
        withdrawal = {},
    },
    cocaine = {
        active = { fatigue = -0.010, endurance = 0.012, panic = -0.35, stress = 0.004, thirst = 0.006 },
        comedown = { fatigue = 0.020, unhappiness = 1.05, stress = 0.008, hunger = 0.006 },
        withdrawalStart = 6,
        withdrawalEnd = 120,
        withdrawal = { fatigue = 0.012, unhappiness = 0.85, stress = 0.006, hunger = 0.004 },
    },
    crack = {
        active = { fatigue = -0.016, endurance = 0.017, panic = -0.45, stress = 0.009, thirst = 0.009 },
        comedown = { fatigue = 0.030, unhappiness = 1.55, stress = 0.014, panic = 0.55, hunger = 0.008 },
        withdrawalStart = 3,
        withdrawalEnd = 144,
        withdrawal = { fatigue = 0.017, unhappiness = 1.20, stress = 0.012, panic = 0.55, hunger = 0.006 },
    },
    meth = {
        active = { fatigue = -0.013, endurance = 0.014, boredom = -0.35, stress = 0.008, thirst = 0.010, temperature = 0.010 },
        comedown = { fatigue = 0.028, unhappiness = 1.25, stress = 0.013, panic = 0.40, hunger = 0.010 },
        withdrawalStart = 8,
        withdrawalEnd = 168,
        withdrawal = { fatigue = 0.016, unhappiness = 1.05, stress = 0.010, panic = 0.35, hunger = 0.008 },
    },
    mdma = {
        active = { unhappiness = -0.90, panic = -0.55, stress = -0.006, fatigue = -0.005, thirst = 0.009, temperature = 0.008 },
        comedown = { fatigue = 0.018, unhappiness = 1.05, stress = 0.008, thirst = 0.003 },
        withdrawalStart = 10,
        withdrawalEnd = 96,
        withdrawal = { fatigue = 0.008, unhappiness = 0.65, stress = 0.005 },
    },
    prescription = {
        active = { fatigue = -0.008, endurance = 0.008, boredom = -0.35, stress = 0.003, thirst = 0.004 },
        comedown = { fatigue = 0.011, unhappiness = 0.45, stress = 0.005, hunger = 0.004 },
        withdrawalStart = 10,
        withdrawalEnd = 120,
        withdrawal = { fatigue = 0.009, unhappiness = 0.55, boredom = 0.30, stress = 0.004 },
    },
}

Drugzz.DRUGS = {
    Joint = {
        family = "cannabis", load = 14, hours = 2.2, toleranceGain = 0.65, dependenceGain = 0.025,
        immediate = { stress = -0.14, panic = -8, pain = -4, unhappiness = -10, fatigue = 0.04, hunger = 0.04, thirst = 0.04 },
        side = { dryMouth = 60, cough = 18, panic = 4 },
        messageKey = "IGUI_Drugzz_JointHit", message = "The edge starts to soften.",
    },
    Blunt = {
        family = "cannabis", load = 23, hours = 3.2, toleranceGain = 0.90, dependenceGain = 0.035,
        immediate = { stress = -0.24, panic = -13, pain = -6, unhappiness = -16, fatigue = 0.07, hunger = 0.07, thirst = 0.06 },
        side = { dryMouth = 72, cough = 26, panic = 7 },
        messageKey = "IGUI_Drugzz_BluntHit", message = "A heavy calm settles in.",
    },
    WeedBrownie = {
        family = "cannabis", load = 34, hours = 6.5, toleranceGain = 1.10, dependenceGain = 0.04,
        immediate = { stress = -0.18, panic = -9, pain = -7, unhappiness = -18, fatigue = 0.10, hunger = 0.08, thirst = 0.05 },
        side = { dryMouth = 78, nausea = 12, panic = 12 },
        messageKey = "IGUI_Drugzz_BrownieHit", message = "The brownie keeps getting stronger.",
    },
    MagicMushroomFresh = {
        family = "psychedelic", load = 26, hours = 4.5, toleranceGain = 1.80, dependenceGain = 0,
        immediate = { boredom = -24, unhappiness = -9, panic = 5, foodSickness = 4, thirst = 0.03 },
        side = { nausea = 34, vomit = 6, badTrip = 13 },
        messageKey = "IGUI_Drugzz_ShroomHit", message = "Colors seem a little too alive.",
    },
    MagicMushroomDried = {
        family = "psychedelic", load = 38, hours = 6.0, toleranceGain = 2.20, dependenceGain = 0,
        immediate = { boredom = -34, unhappiness = -14, panic = 8, foodSickness = 6, thirst = 0.04 },
        side = { nausea = 40, vomit = 9, badTrip = 18 },
        messageKey = "IGUI_Drugzz_ShroomStrongHit", message = "The room begins to breathe.",
    },
    LSDTab = {
        family = "psychedelic", load = 48, hours = 9.0, toleranceGain = 2.50, dependenceGain = 0,
        immediate = { boredom = -45, unhappiness = -18, panic = 10, fatigue = -0.03, thirst = 0.04 },
        side = { nausea = 16, vomit = 4, badTrip = 23, dryMouth = 28 },
        messageKey = "IGUI_Drugzz_LSDHit", message = "Reality develops some loose seams.",
    },
    CocaineBaggie = {
        family = "cocaine", load = 36, hours = 1.4, toleranceGain = 1.10, dependenceGain = 0.075,
        immediate = { fatigue = -0.17, endurance = 0.22, panic = -7, stress = 0.08, thirst = 0.08, hunger = -0.03 },
        side = { dryMouth = 48, panic = 13, nosePain = 24, overheating = 8 },
        messageKey = "IGUI_Drugzz_CocaineHit", message = "Everything snaps into sharp focus.",
    },
    CrackPipe = {
        family = "crack", load = 54, hours = 0.75, toleranceGain = 1.45, dependenceGain = 0.12,
        immediate = { fatigue = -0.25, endurance = 0.31, panic = -10, stress = 0.14, thirst = 0.11, hunger = -0.04 },
        side = { dryMouth = 62, cough = 42, panic = 22, overheating = 16, nausea = 12 },
        messageKey = "IGUI_Drugzz_CrackHit", message = "A fierce rush hits all at once.",
    },
    MethBaggie = {
        family = "meth", load = 46, hours = 5.5, toleranceGain = 1.20, dependenceGain = 0.10,
        immediate = { fatigue = -0.23, endurance = 0.26, boredom = -10, stress = 0.12, thirst = 0.12, hunger = -0.05, temperature = 0.12 },
        side = { dryMouth = 76, panic = 18, overheating = 34, tremor = 22, nausea = 16, nosePain = 18 },
        messageKey = "IGUI_Drugzz_MethHit", message = "You feel wired, alert, and unable to sit still.",
    },
    MethPipe = {
        family = "meth", load = 58, hours = 6.5, toleranceGain = 1.50, dependenceGain = 0.13,
        immediate = { fatigue = -0.27, endurance = 0.31, boredom = -13, stress = 0.16, thirst = 0.14, hunger = -0.06, temperature = 0.18 },
        side = { dryMouth = 84, cough = 32, panic = 24, overheating = 44, tremor = 30, nausea = 20 },
        messageKey = "IGUI_Drugzz_MethPipeHit", message = "A hot, restless rush floods your body.",
    },
    MollyCapsule = {
        family = "mdma", load = 38, hours = 4.2, toleranceGain = 1.00, dependenceGain = 0.045,
        immediate = { unhappiness = -26, panic = -15, stress = -0.18, thirst = 0.12, fatigue = -0.07, temperature = 0.10 },
        side = { dryMouth = 68, overheating = 28, nausea = 25, vomit = 6, jawPain = 44 },
        messageKey = "IGUI_Drugzz_MollyHit", message = "Warmth and energy roll through you.",
    },
    EcstasyTablet = {
        family = "mdma", load = 47, hours = 4.8, toleranceGain = 1.20, dependenceGain = 0.055,
        immediate = { unhappiness = -30, panic = -18, stress = -0.22, thirst = 0.15, fatigue = -0.09, temperature = 0.14 },
        side = { dryMouth = 76, overheating = 38, nausea = 31, vomit = 9, jawPain = 52 },
        messageKey = "IGUI_Drugzz_EcstasyHit", message = "The world suddenly feels welcoming.",
    },
    AdderallBottle = {
        family = "prescription", load = 19, hours = 5.0, toleranceGain = 0.65, dependenceGain = 0.035,
        immediate = { fatigue = -0.12, endurance = 0.13, boredom = -8, stress = 0.04, thirst = 0.05, hunger = -0.025 },
        side = { dryMouth = 40, panic = 8, overheating = 5, nausea = 7 },
        messageKey = "IGUI_Drugzz_AdderallHit", message = "Your thoughts line up in neat rows.",
    },
}

Drugzz.CANNABIS_STRAINS = {
    SourDiesel = {
        kind = "sativa",
        immediate = { stress = -0.12, panic = -4, unhappiness = -12, fatigue = -0.05, endurance = 0.06, hunger = 0.02, thirst = 0.05 },
        side = { dryMouth = 66, cough = 18, panic = 12 },
        message = "Sour Diesel comes on bright and energetic.",
    },
    DurbanPoison = {
        kind = "sativa",
        immediate = { boredom = -14, fatigue = -0.08, endurance = 0.08, unhappiness = -8, stress = 0.03, thirst = 0.05 },
        side = { dryMouth = 62, cough = 17, panic = 15 },
        message = "Durban Poison leaves you sharply awake.",
    },
    JackHerer = {
        kind = "sativa",
        immediate = { boredom = -16, stress = -0.10, unhappiness = -12, fatigue = -0.04, endurance = 0.04, hunger = 0.03, thirst = 0.04 },
        side = { dryMouth = 58, cough = 16, panic = 8 },
        message = "Jack Herer settles into a clear, upbeat focus.",
    },
    NorthernLights = {
        kind = "indica",
        immediate = { stress = -0.20, panic = -12, pain = -6, unhappiness = -12, fatigue = 0.10, hunger = 0.07, thirst = 0.05 },
        side = { dryMouth = 66, cough = 16, panic = 4 },
        message = "Northern Lights wraps you in a sleepy calm.",
    },
    GranddaddyPurple = {
        kind = "indica",
        immediate = { stress = -0.24, panic = -14, pain = -8, unhappiness = -15, fatigue = 0.13, hunger = 0.10, endurance = -0.03, thirst = 0.06 },
        side = { dryMouth = 72, cough = 18, nausea = 7, panic = 4 },
        message = "Granddaddy Purple hits heavy, hungry, and slow.",
    },
    BubbaKush = {
        kind = "indica",
        immediate = { stress = -0.22, panic = -16, pain = -7, unhappiness = -13, fatigue = 0.11, hunger = 0.08, thirst = 0.05 },
        side = { dryMouth = 68, cough = 18, panic = 4 },
        message = "Bubba Kush quiets everything down.",
    },
    OGKush = {
        kind = "hybrid",
        immediate = { stress = -0.22, panic = -12, pain = -8, unhappiness = -15, fatigue = 0.07, hunger = 0.08, thirst = 0.06 },
        side = { dryMouth = 70, cough = 18, panic = 7 },
        message = "OG Kush lands with a strong, balanced body calm.",
    },
    WhiteWidow = {
        kind = "hybrid",
        immediate = { stress = -0.15, panic = -8, unhappiness = -16, boredom = -8, endurance = 0.03, hunger = 0.05, thirst = 0.05 },
        side = { dryMouth = 64, cough = 18, panic = 9 },
        message = "White Widow feels balanced, social, and bright.",
    },
    BlueDream = {
        kind = "hybrid",
        immediate = { stress = -0.17, panic = -7, pain = -6, unhappiness = -17, boredom = -8, fatigue = -0.02, hunger = 0.06, thirst = 0.05 },
        side = { dryMouth = 62, cough = 16, panic = 7 },
        message = "Blue Dream brings a mellow lift without much weight.",
    },
    GSC = {
        kind = "hybrid",
        immediate = { stress = -0.20, panic = -10, pain = -5, unhappiness = -20, fatigue = 0.06, hunger = 0.11, thirst = 0.06 },
        side = { dryMouth = 72, cough = 20, nausea = 6, panic = 8 },
        message = "GSC brings a strong mood lift and serious munchies.",
    },
}

for strainId, strain in pairs(Drugzz.CANNABIS_STRAINS) do
    Drugzz.DRUGS[strainId .. "Joint"] = {
        family = "cannabis",
        load = strain.kind == "indica" and 19 or 17,
        hours = strain.kind == "indica" and 2.8 or 2.4,
        toleranceGain = 0.70,
        dependenceGain = 0.026,
        immediate = strain.immediate,
        side = strain.side,
        messageKey = "IGUI_Drugzz_" .. strainId .. "Hit",
        message = strain.message,
    }
end

Drugzz.DRUGS.PackedBongSativa = {
    family = "cannabis", load = 27, hours = 2.7, toleranceGain = 0.90, dependenceGain = 0.032,
    immediate = { boredom = -18, unhappiness = -16, fatigue = -0.09, endurance = 0.11, stress = -0.10, thirst = 0.08 },
    side = { dryMouth = 78, cough = 34, panic = 18, nausea = 7 },
    messageKey = "IGUI_Drugzz_SativaBongHit", message = "The sativa bong hits fast and bright.",
}

Drugzz.DRUGS.PackedBongIndica = {
    family = "cannabis", load = 31, hours = 3.4, toleranceGain = 1.00, dependenceGain = 0.036,
    immediate = { stress = -0.28, panic = -18, pain = -10, unhappiness = -18, fatigue = 0.16, hunger = 0.13, endurance = -0.04, thirst = 0.08 },
    side = { dryMouth = 82, cough = 34, nausea = 9, panic = 6 },
    messageKey = "IGUI_Drugzz_IndicaBongHit", message = "The indica bong settles over you like a weighted blanket.",
}

Drugzz.DRUGS.PackedBongHybrid = {
    family = "cannabis", load = 29, hours = 3.0, toleranceGain = 0.95, dependenceGain = 0.034,
    immediate = { stress = -0.22, panic = -13, pain = -7, unhappiness = -20, boredom = -10, fatigue = 0.05, hunger = 0.10, thirst = 0.08 },
    side = { dryMouth = 80, cough = 34, nausea = 8, panic = 10 },
    messageKey = "IGUI_Drugzz_HybridBongHit", message = "The hybrid bong lands strong and balanced.",
}

Drugzz.DRUGS.KiefJoint = {
    family = "cannabis", load = 25, hours = 2.8, toleranceGain = 0.85, dependenceGain = 0.032,
    immediate = { stress = -0.20, panic = -11, pain = -6, unhappiness = -16, fatigue = 0.06, hunger = 0.08, thirst = 0.07 },
    side = { dryMouth = 78, cough = 28, nausea = 8, panic = 10 },
    messageKey = "IGUI_Drugzz_KiefJointHit", message = "The kief burns rich and noticeably stronger than flower.",
}

Drugzz.DRUGS.HashJoint = {
    family = "cannabis", load = 33, hours = 3.5, toleranceGain = 1.05, dependenceGain = 0.040,
    immediate = { stress = -0.26, panic = -15, pain = -9, unhappiness = -19, fatigue = 0.11, hunger = 0.11, thirst = 0.08 },
    side = { dryMouth = 84, cough = 36, nausea = 12, panic = 10, vomit = 3 },
    messageKey = "IGUI_Drugzz_HashJointHit", message = "The hash settles into a dense, old-school body high.",
}

Drugzz.DRUGS.LoadedDabRigRosin = {
    family = "cannabis", load = 44, hours = 3.5, toleranceGain = 1.20, dependenceGain = 0.045,
    immediate = { stress = -0.28, panic = -15, pain = -11, unhappiness = -22, fatigue = 0.08, hunger = 0.11, thirst = 0.10 },
    side = { dryMouth = 90, cough = 48, nausea = 18, panic = 14, vomit = 4 },
    messageKey = "IGUI_Drugzz_RosinDabHit", message = "The rosin dab blooms into a heavy full-body high.",
}

Drugzz.DRUGS.LoadedDabRigShatter = {
    family = "cannabis", load = 54, hours = 3.2, toleranceGain = 1.45, dependenceGain = 0.055,
    immediate = { stress = -0.25, panic = -12, pain = -10, unhappiness = -25, fatigue = 0.04, hunger = 0.10, thirst = 0.12 },
    side = { dryMouth = 94, cough = 60, nausea = 28, panic = 24, vomit = 8 },
    messageKey = "IGUI_Drugzz_ShatterDabHit", message = "The shatter dab hits with startling force.",
}

Drugzz.DRUGS.LoadedDabRigLiveResin = {
    family = "cannabis", load = 49, hours = 3.8, toleranceGain = 1.35, dependenceGain = 0.050,
    immediate = { stress = -0.30, panic = -14, pain = -9, unhappiness = -26, boredom = -14, fatigue = 0.02, hunger = 0.09, thirst = 0.11 },
    side = { dryMouth = 92, cough = 52, nausea = 22, panic = 18, vomit = 6 },
    messageKey = "IGUI_Drugzz_LiveResinDabHit", message = "The live resin dab feels vivid, aromatic, and intense.",
}

Drugzz.DRUGS.LoadedDabRigDistillate = {
    family = "cannabis", load = 58, hours = 4.0, toleranceGain = 1.60, dependenceGain = 0.060,
    immediate = { stress = -0.24, panic = -10, pain = -12, unhappiness = -27, fatigue = 0.10, hunger = 0.13, thirst = 0.13 },
    side = { dryMouth = 95, cough = 58, nausea = 32, panic = 28, vomit = 10 },
    messageKey = "IGUI_Drugzz_DistillateDabHit", message = "The distillate dab is clean, potent, and almost too much.",
}

Drugzz.DRUGS.ElectronicDabRigRosin = {
    family = "cannabis", load = 43, hours = 3.5, toleranceGain = 1.18, dependenceGain = 0.044,
    immediate = { stress = -0.28, panic = -15, pain = -11, unhappiness = -22, fatigue = 0.08, hunger = 0.11, thirst = 0.09 },
    side = { dryMouth = 88, cough = 24, nausea = 17, panic = 13, vomit = 4 },
    messageKey = "IGUI_Drugzz_ERigRosinHit", message = "The electronic rosin dab lands smooth, warm, and heavy.",
}

Drugzz.DRUGS.ElectronicDabRigShatter = {
    family = "cannabis", load = 52, hours = 3.2, toleranceGain = 1.42, dependenceGain = 0.054,
    immediate = { stress = -0.25, panic = -12, pain = -10, unhappiness = -25, fatigue = 0.04, hunger = 0.10, thirst = 0.11 },
    side = { dryMouth = 92, cough = 32, nausea = 27, panic = 23, vomit = 8 },
    messageKey = "IGUI_Drugzz_ERigShatterHit", message = "The electronic shatter dab ramps up with startling force.",
}

Drugzz.DRUGS.ElectronicDabRigLiveResin = {
    family = "cannabis", load = 48, hours = 3.8, toleranceGain = 1.32, dependenceGain = 0.049,
    immediate = { stress = -0.30, panic = -14, pain = -9, unhappiness = -26, boredom = -14, fatigue = 0.02, hunger = 0.09, thirst = 0.10 },
    side = { dryMouth = 90, cough = 26, nausea = 21, panic = 17, vomit = 6 },
    messageKey = "IGUI_Drugzz_ERigLiveResinHit", message = "The electronic live resin dab feels vivid and intensely aromatic.",
}

Drugzz.DRUGS.ElectronicDabRigDistillate = {
    family = "cannabis", load = 56, hours = 4.0, toleranceGain = 1.56, dependenceGain = 0.059,
    immediate = { stress = -0.24, panic = -10, pain = -12, unhappiness = -27, fatigue = 0.10, hunger = 0.13, thirst = 0.12 },
    side = { dryMouth = 94, cough = 30, nausea = 31, panic = 27, vomit = 10 },
    messageKey = "IGUI_Drugzz_ERigDistillateHit", message = "The electronic distillate dab is smooth, potent, and dangerously easy to underestimate.",
}

Drugzz.DRUGS.THCCartridge = {
    family = "cannabis", load = 11, hours = 1.3, toleranceGain = 0.38, dependenceGain = 0.018,
    immediate = { stress = -0.10, panic = -5, pain = -3, unhappiness = -8, hunger = 0.03, thirst = 0.025 },
    side = { dryMouth = 46, cough = 8, panic = 5, nausea = 3 },
    messageKey = "IGUI_Drugzz_VapeHit", message = "A discreet vapor hit takes the edge off.",
}

Drugzz.DRUGS.SpaceCookie = {
    family = "cannabis", load = 35, hours = 6.5, toleranceGain = 1.10, dependenceGain = 0.040,
    immediate = { stress = -0.23, panic = -12, pain = -8, unhappiness = -20, fatigue = 0.13, hunger = 0.11, thirst = 0.06 },
    side = { dryMouth = 82, nausea = 16, panic = 15, vomit = 4 },
    messageKey = "IGUI_Drugzz_SpaceCookieHit", message = "The cookie comes on slowly, then refuses to leave.",
}

Drugzz.DRUGS.CannabisGummies = {
    family = "cannabis", load = 27, hours = 5.0, toleranceGain = 0.90, dependenceGain = 0.032,
    immediate = { stress = -0.18, panic = -9, pain = -6, unhappiness = -16, fatigue = 0.08, hunger = 0.07, thirst = 0.05 },
    side = { dryMouth = 72, nausea = 12, panic = 10, vomit = 3 },
    messageKey = "IGUI_Drugzz_GummyHit", message = "The gummy builds into a steady body high.",
}

function Drugzz.decayLoad(state, now)
    local previous = state.lastLoadHour or now
    local elapsed = math.max(0, now - previous)
    state.load = math.max(0, (state.load or 0) - (elapsed * 13))
    state.cannabisLoad = math.max(0, (state.cannabisLoad or 0) - (elapsed * 13))
    state.hardLoad = math.max(0, (state.hardLoad or 0) - (elapsed * 13))
    state.lastLoadHour = now
end

local function updateTolerance(familyState, now)
    local previous = familyState.lastToleranceHour or familyState.lastUseHour or now
    local elapsed = math.max(0, now - previous)
    familyState.tolerance = math.max(0, (familyState.tolerance or 0) - (elapsed / 42))
    familyState.lastToleranceHour = now
end

function Drugzz.addSymptom(state, name, now, hours, intensity)
    local symptom = state.symptoms[name] or {}
    symptom.untilHour = math.max(symptom.untilHour or now, now + hours)
    symptom.intensity = math.max(symptom.intensity or 0, intensity or 1)
    state.symptoms[name] = symptom
end

local function sideEffectRisk(character, definition)
    local multiplier = tonumber(Drugzz.getOption("SideEffectSeverity", 1.0)) or 1.0

    if definition.family == "psychedelic" and Drugzz.hasTrait(character, "PSYCHONAUT") then
        multiplier = multiplier * 0.55
    elseif definition.family == "cannabis" and Drugzz.hasTrait(character, "STONER") then
        multiplier = multiplier * 0.78
    elseif definition.family == "cannabis" and Drugzz.hasTrait(character, "CANNABIS_CONNOISSEUR") then
        multiplier = multiplier * 0.62
    end

    return multiplier
end

local function rollSideEffect(chance, multiplier)
    local adjusted = Drugzz.clamp((chance or 0) * multiplier, 0, 95)
    return ZombRand(10000) < math.floor(adjusted * 100)
end

local function applySideEffects(character, state, definition, familyState, now, doseScale)
    local side = definition.side or {}
    local risk = sideEffectRisk(character, definition) * (doseScale or 1)

    if rollSideEffect(side.dryMouth, risk) then
        Drugzz.addSymptom(state, "dryMouth", now, math.min(3.5, definition.hours), 1)
        Drugzz.adjustStat(character, CharacterStat.THIRST, 0.05)
        Drugzz.note(character, "IGUI_Drugzz_Cottonmouth", "Your mouth feels painfully dry.", 220, 190, 120)
    end

    if rollSideEffect(side.nausea, risk) then
        Drugzz.addSymptom(state, "nausea", now, math.min(2.5, definition.hours), 1)
        Drugzz.adjustStat(character, CharacterStat.FOOD_SICKNESS, 8)
        Drugzz.note(character, "IGUI_Drugzz_Nausea", "Your stomach turns.", 190, 220, 120)
    end

    if rollSideEffect(side.vomit, risk) then
        Drugzz.addSymptom(state, "nausea", now, 2.0, 1.4)
        Drugzz.setStatAtLeast(character, CharacterStat.FOOD_SICKNESS, 42)
        Drugzz.adjustStat(character, CharacterStat.THIRST, 0.10)
        Drugzz.adjustStat(character, CharacterStat.HUNGER, 0.06)
        Drugzz.note(character, "IGUI_Drugzz_Retching", "You gag and fight the urge to throw up.", 220, 180, 100)
    end

    if rollSideEffect(side.badTrip, risk) then
        Drugzz.addSymptom(state, "badTrip", now, math.min(3.0, definition.hours * 0.45), 1)
        Drugzz.adjustStat(character, CharacterStat.PANIC, 18)
        Drugzz.adjustStat(character, CharacterStat.STRESS, 0.10)
        Drugzz.note(character, "IGUI_Drugzz_BadTrip", "Something feels terribly wrong.", 255, 100, 120, 320)
    end

    if rollSideEffect(side.panic, risk) then
        Drugzz.addSymptom(state, "stimulantPanic", now, math.min(2.0, definition.hours), 1)
        Drugzz.adjustStat(character, CharacterStat.PANIC, 10)
        Drugzz.adjustStat(character, CharacterStat.STRESS, 0.06)
        Drugzz.note(character, "IGUI_Drugzz_HeartRacing", "Your heart is racing.", 255, 150, 100)
    end

    if rollSideEffect(side.overheating, risk) then
        Drugzz.addSymptom(state, "overheating", now, math.min(3.0, definition.hours), 1)
        Drugzz.adjustStat(character, CharacterStat.TEMPERATURE, 0.18)
        Drugzz.adjustStat(character, CharacterStat.THIRST, 0.05)
        Drugzz.note(character, "IGUI_Drugzz_Overheating", "You feel dangerously hot.", 255, 130, 80)
    end

    if rollSideEffect(side.tremor, risk) then
        Drugzz.addSymptom(state, "tremor", now, math.min(3.0, definition.hours), 1)
        Drugzz.adjustStat(character, CharacterStat.STRESS, 0.05)
        Drugzz.note(character, "IGUI_Drugzz_Tremor", "Your hands will not stop shaking.", 230, 180, 120)
    end

    if rollSideEffect(side.jawPain, risk) then
        Drugzz.addSymptom(state, "jawPain", now, math.min(4.0, definition.hours), 1)
        Drugzz.adjustStat(character, CharacterStat.PAIN, 4)
        Drugzz.note(character, "IGUI_Drugzz_JawClench", "Your jaw aches from clenching.", 220, 180, 160)
    end

    if rollSideEffect(side.nosePain, risk) then
        Drugzz.adjustStat(character, CharacterStat.PAIN, 2)
        Drugzz.adjustStat(character, CharacterStat.UNHAPPINESS, 2)
        Drugzz.note(character, "IGUI_Drugzz_NoseBurn", "Your nose burns.", 220, 180, 160)
    end

    if rollSideEffect(side.cough, risk) then
        Drugzz.adjustStat(character, CharacterStat.PAIN, 1)
        Drugzz.adjustStat(character, CharacterStat.PANIC, 2)
        Drugzz.note(character, "IGUI_Drugzz_Cough", "A rough coughing fit catches you.", 210, 190, 160)
    end

    -- Heavy long-term cannabis use can occasionally cause a severe nausea
    -- episode, representing cannabinoid hyperemesis without making it common.
    if definition.family == "cannabis" and (familyState.uses or 0) >= 18 then
        local chsChance = 2 + ((familyState.dependence or 0) * 5)
        if rollSideEffect(chsChance, risk) then
            Drugzz.addSymptom(state, "nausea", now, 3.0, 1.5)
            Drugzz.setStatAtLeast(character, CharacterStat.FOOD_SICKNESS, 45)
            Drugzz.note(character, "IGUI_Drugzz_CHS", "A violent wave of nausea hits you.", 225, 160, 90, 320)
        end
    end
end

local function applyOverdose(character, state)
    local severity = tonumber(Drugzz.getOption("OverdoseSeverity", 1.0)) or 1.0
    if severity <= 0 then
        return
    end

    local hardLoad = state.hardLoad or 0
    local cannabisLoad = state.cannabisLoad or 0

    if hardLoad < 85 and cannabisLoad >= 85 then
        if cannabisLoad < 120 then
            Drugzz.note(character, "IGUI_Drugzz_GreenOutWarning", "You may have overdone the cannabis.", 210, 190, 100, 300)
            Drugzz.adjustStat(character, CharacterStat.FOOD_SICKNESS, 12 * severity)
            Drugzz.adjustStat(character, CharacterStat.PANIC, 8 * severity)
            Drugzz.adjustStat(character, CharacterStat.FATIGUE, 0.08 * severity)
        elseif cannabisLoad < 165 then
            Drugzz.note(character, "IGUI_Drugzz_GreenOut", "The room spins. You are greening out.", 220, 150, 80, 340)
            Drugzz.setStatAtLeast(character, CharacterStat.FOOD_SICKNESS, 48 * severity)
            Drugzz.adjustStat(character, CharacterStat.PANIC, 22 * severity)
            Drugzz.adjustStat(character, CharacterStat.FATIGUE, 0.16 * severity)
            Drugzz.adjustStat(character, CharacterStat.THIRST, 0.10 * severity)
        else
            Drugzz.note(character, "IGUI_Drugzz_GreenOutSevere", "You are violently sick and can barely stay upright.", 230, 110, 70, 380)
            Drugzz.setStatAtLeast(character, CharacterStat.FOOD_SICKNESS, 72 * severity)
            Drugzz.adjustStat(character, CharacterStat.PANIC, 38 * severity)
            Drugzz.adjustStat(character, CharacterStat.FATIGUE, 0.25 * severity)
            Drugzz.adjustStat(character, CharacterStat.THIRST, 0.18 * severity)
        end
        return
    end

    local load = hardLoad
    if load >= 85 and load < 120 then
        Drugzz.note(character, "IGUI_Drugzz_OverdoseWarning", "Your heart is working too hard.", 255, 180, 80, 300)
        Drugzz.adjustStat(character, CharacterStat.PANIC, 10 * severity)
        Drugzz.adjustStat(character, CharacterStat.STRESS, 0.08 * severity)
    elseif load >= 120 and load < 165 then
        Drugzz.note(character, "IGUI_Drugzz_OverdoseDanger", "You feel dangerously unwell.", 255, 90, 70, 320)
        Drugzz.setStatAtLeast(character, CharacterStat.FOOD_SICKNESS, 35 * severity)
        Drugzz.adjustStat(character, CharacterStat.PANIC, 25 * severity)
        Drugzz.adjustStat(character, CharacterStat.TEMPERATURE, 0.20 * severity)
        Drugzz.damageHealth(character, 7 * severity)
    elseif load >= 165 then
        Drugzz.note(character, "IGUI_Drugzz_Overdose", "Overdose!", 255, 40, 40, 400)
        Drugzz.setStatAtLeast(character, CharacterStat.FOOD_SICKNESS, 55 * severity)
        Drugzz.adjustStat(character, CharacterStat.PANIC, 45 * severity)
        Drugzz.adjustStat(character, CharacterStat.TEMPERATURE, 0.35 * severity)
        Drugzz.damageHealth(character, 24 * severity)
    end
end

function Drugzz.OnConsume(food, character, percent)
    if not food or not character then
        return
    end

    local definition = Drugzz.DRUGS[food:getType()]
    if not definition then
        return
    end

    local doseScale = 1
    if instanceof(food, "Food") then
        doseScale = Drugzz.clamp(tonumber(percent) or 1, 0.01, 1)
    end

    local now = Drugzz.getWorldHours()
    local state = Drugzz.getState(character)
    if not state then
        return
    end

    Drugzz.decayLoad(state, now)

    local familyState = Drugzz.getFamilyState(state, definition.family, now)
    updateTolerance(familyState, now)

    local tolerance = familyState.tolerance or 0
    local potency = math.max(0.48, 1 - (tolerance * 0.055))
    local strength = tonumber(Drugzz.getOption("EffectStrength", 1.0)) or 1.0
    potency = potency * strength * doseScale

    if definition.family == "psychedelic" and Drugzz.hasTrait(character, "PSYCHONAUT") then
        potency = potency * 1.05
    elseif definition.family == "cannabis" and Drugzz.hasTrait(character, "CANNABIS_CONNOISSEUR") then
        potency = potency * 1.04
    end

    Drugzz.applyStats(character, definition.immediate, potency)

    familyState.uses = (familyState.uses or 0) + doseScale
    local toleranceGain = (definition.toleranceGain or 1) * doseScale
    if definition.family == "cannabis" and Drugzz.hasTrait(character, "CANNABIS_CONNOISSEUR") then
        toleranceGain = toleranceGain * 0.80
    end
    familyState.tolerance = math.min(12, tolerance + toleranceGain)
    if Drugzz.getOption("EnableDependence", true) then
        familyState.dependence = math.min(
            1,
            (familyState.dependence or 0) + ((definition.dependenceGain or 0) * doseScale)
        )
    end
    familyState.lastUseHour = now
    familyState.lastToleranceHour = now

    local effect = state.effects[definition.family] or {}
    local duration = definition.hours * potency
    if definition.family == "psychedelic" and Drugzz.hasTrait(character, "PSYCHONAUT") then
        duration = duration * 1.15
    end
    effect.untilHour = math.max(effect.untilHour or now, now) + duration
    effect.intensity = math.min(100, (effect.intensity or 0) + (definition.load * potency))
    effect.comedownUntil = effect.untilHour + math.max(2, definition.hours * 0.80)
    state.effects[definition.family] = effect

    state.load = math.min(240, (state.load or 0) + (definition.load * potency))
    if definition.family == "cannabis" then
        state.cannabisLoad = math.min(240, (state.cannabisLoad or 0) + (definition.load * potency))
    else
        state.hardLoad = math.min(240, (state.hardLoad or 0) + (definition.load * potency))
    end
    state.lastLoadHour = now
    state.withdrawalNoted[definition.family] = nil

    Drugzz.note(character, definition.messageKey, definition.message, 150, 220, 170, 250)
    applySideEffects(character, state, definition, familyState, now, doseScale)
    applyOverdose(character, state)
    Drugzz.syncState(character, state, true)
end

function Drugzz_CanHarvestGrowItem(sourceItem, result)
    if not sourceItem or not sourceItem.getFullType then
        return true
    end

    local fullType = sourceItem:getFullType()
    if fullType == "ZDrugzz.MushroomGrowKit" then
        local days = tonumber(Drugzz.getOption("MushroomGrowDays", 5)) or 5
        return sourceItem:getAge() >= days and not sourceItem:isRotten()
    end

    if fullType == "ZDrugzz.CocaNursery" then
        local days = tonumber(Drugzz.getOption("CocaGrowDays", 8)) or 8
        return sourceItem:getAge() >= days and not sourceItem:isRotten()
    end

    return true
end
