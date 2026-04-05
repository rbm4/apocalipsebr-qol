-- LabModOptions.lua
-- Opções do mod ZVirusVaccine42 (client-only)

require "PZAPI/ModOptions"

local MOD_ID   = "ZVirusVaccine42BETA"
local MOD_NAME = "Zombie Virus Vaccine"

LabModOptions = {}

local function initOptions()
    local options = PZAPI.ModOptions:create(MOD_ID, MOD_NAME)

    options:addTickBox(
        "enableSpeech",
        getText("Sandbox_ZombieVirusVaccineBETA_EnablePlayerSpeech"),
        true,
        getText("Sandbox_ZombieVirusVaccineBETA_EnablePlayerSpeech_tooltip")
    )

    -- BloodTest
    options:addSlider(
        "speechChanceBloodTestNegative",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceBloodTestNegative"),
        0, 100, 1, 100,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceBloodTestNegative_tooltip")
    )
    options:addSlider(
        "speechChanceBloodTestPositive",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceBloodTestPositive"),
        0, 100, 1, 100,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceBloodTestPositive_tooltip")
    )
    options:addSlider(
        "speechChanceBloodTestInvalid",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceBloodTestInvalid"),
        0, 100, 1, 100,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceBloodTestInvalid_tooltip")
    )

    -- CollectBlood
    options:addSlider(
        "speechChanceCollectBlood",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceCollectBlood"),
        0, 100, 1, 100,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceCollectBlood_tooltip")
    )

    -- Autopsy
    options:addSlider(
        "speechChanceAutopsyInfected",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceAutopsyInfected"),
        0, 100, 1, 30,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceAutopsyInfected_tooltip")
    )
    options:addSlider(
        "speechChanceAutopsyTainted",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceAutopsyTainted"),
        0, 100, 1, 30,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceAutopsyTainted_tooltip")
    )
    options:addSlider(
        "speechChanceAutopsyNothing",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceAutopsyNothing"),
        0, 100, 1, 30,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceAutopsyNothing_tooltip")
    )
    options:addSlider(
        "speechChanceAutopsyAlready",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceAutopsyAlready"),
        0, 100, 1, 100,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceAutopsyAlready_tooltip")
    )

    -- Morgue
    options:addSlider(
        "speechChanceMorgueCorpsePlaced",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueCorpsePlaced"),
        0, 100, 1, 50,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueCorpsePlaced_tooltip")
    )
    options:addSlider(
        "speechChanceMorgueSuccess",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueSuccess"),
        0, 100, 1, 50,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueSuccess_tooltip")
    )
    options:addSlider(
        "speechChanceMorgueNoContainer",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueNoContainer"),
        0, 100, 1, 50,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueNoContainer_tooltip")
    )
    options:addSlider(
        "speechChanceMorgueTableCleaned",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueTableCleaned"),
        0, 100, 1, 50,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueTableCleaned_tooltip")
    )
    options:addSlider(
        "speechChanceMorgueCorpseRemoved",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueCorpseRemoved"),
        0, 100, 1, 50,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueCorpseRemoved_tooltip")
    )
    options:addSlider(
        "speechChanceMorgueBodyPartCollected",
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueBodyPartCollected"),
        0, 100, 1, 50,
        getText("Sandbox_ZombieVirusVaccineBETA_SpeechChanceMorgueBodyPartCollected_tooltip")
    )

    LabModOptions.options = options
end

function LabModOptions.isSpeechEnabled()
    if not LabModOptions.options then return true end
    local opt = LabModOptions.options:getOption("enableSpeech")
    return opt and opt:getValue()
end

function LabModOptions.getSpeechChance(key)
    if not LabModOptions.options then return 100 end
    local opt = LabModOptions.options:getOption(key)
    return opt and opt:getValue() or 100
end

-- Rola a chance de fala para uma chave específica.
-- Retorna true se deve falar, false caso contrário.
function LabModOptions.rollSpeech(key, defaultChance)
    if not LabModOptions.isSpeechEnabled() then return false end
    local chance = LabModOptions.getSpeechChance(key)
    if chance == nil then chance = defaultChance or 100 end
    return ZombRand(100) < chance
end

Events.OnGameBoot.Add(initOptions)