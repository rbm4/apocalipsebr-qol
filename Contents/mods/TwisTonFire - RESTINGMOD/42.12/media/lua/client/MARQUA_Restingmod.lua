if not MARQUA_RESTINGMOD then MARQUA_RESTINGMOD = {} end
if not MARQUA_RESTINGMOD_GAMESPEED_FLAG then MARQUA_RESTINGMOD_GAMESPEED_FLAG = {} end

local function getCustomOrDefault(opt, defaultKey)
    if not opt or not opt.getValue then return getText(defaultKey) end
    local value = opt:getValue()
    if not value or value == "" then
        return getText(defaultKey)
    end
    return value
end

local function getPlayerKey(player)
    return player and (player:getUsername() or player:getDisplayName() or tostring(player)) or "1"
end

local function setNormalGameSpeedOnce(player)
    local key = getPlayerKey(player)
    if not MARQUA_RESTINGMOD_GAMESPEED_FLAG[key] then
        setGameSpeed(1)
        getGameTime():setMultiplier(1)
        MARQUA_RESTINGMOD_GAMESPEED_FLAG[key] = true
    end
end

local function clearGameSpeedFlag(player)
    local key = getPlayerKey(player)
    if MARQUA_RESTINGMOD_GAMESPEED_FLAG[key] then
        MARQUA_RESTINGMOD_GAMESPEED_FLAG[key] = nil
    end
end
local function resetTextFieldsToDefaults()
    MARQUA_RESTINGMOD.customResting:setValue("...")
    MARQUA_RESTINGMOD.customFinishedRestingF:setValue(getText("UI_Finished_resting_F"))
    MARQUA_RESTINGMOD.customFinishedRestingM:setValue(getText("UI_Finished_resting_M"))
    MARQUA_RESTINGMOD.customStiffnessRightArm:setValue(getText("UI_Stiffness_Right_Arm"))
    MARQUA_RESTINGMOD.customPoisonState:setValue(getText("UI_POISONSTATE"))
end

local options = PZAPI.ModOptions:create("MARQUA_RESTINGMOD", "TwisTonFire - Resting")


local function addTextEntryDefault(key, label, tooltip, defaultKey)
    return options:addTextEntry(key, label, getText(defaultKey), tooltip)
end
MARQUA_RESTINGMOD.modeComboBox = options:addComboBox(
    "modeComboBox",
    getText("UI_RestingMod_Mode"),
    getText("UI_RestingMod_tooltip_when")
)
MARQUA_RESTINGMOD.modeComboBox:addItem(getText("UI_RestingMod_mode_never"), false)
MARQUA_RESTINGMOD.modeComboBox:addItem(getText("UI_RestingMod_mode_pain"), false)
MARQUA_RESTINGMOD.modeComboBox:addItem(getText("UI_RestingMod_mode_nopain"), true)

options:addDescription(getText("UI_RestingMod_txtfielddsc"))
MARQUA_RESTINGMOD.customResting = options:addTextEntry(
    "customResting",
    getText("UI_RestingMod_label_resting") .. " (...)",
    "...", 
    getText("UI_RestingMod_tooltip")
)
MARQUA_RESTINGMOD.customFinishedRestingF = addTextEntryDefault(
    "customFinishedRestingF",
    getText("UI_Finished_resting_F") .. " (" .. getText("UI_RestingMod_female") .. ")",
    getText("UI_RestingMod_tooltip"),
    "UI_Finished_resting_F"
)
MARQUA_RESTINGMOD.customFinishedRestingM = addTextEntryDefault(
    "customFinishedRestingM",
    getText("UI_Finished_resting_M") .. " (" .. getText("UI_RestingMod_male") .. ")",
    getText("UI_RestingMod_tooltip"),
    "UI_Finished_resting_M"
)
MARQUA_RESTINGMOD.customStiffnessRightArm = addTextEntryDefault(
    "customStiffnessRightArm",
    getText("UI_Stiffness_Right_Arm"),
    getText("UI_RestingMod_tooltip"),
    "UI_Stiffness_Right_Arm"
)
MARQUA_RESTINGMOD.customPoisonState = addTextEntryDefault(
    "customPoisonState",
    getText("UI_POISONSTATE"),
    getText("UI_RestingMod_tooltip"),
    "UI_POISONSTATE"
)
options:addButton(
    "resetTextDefaultsBtn",
    getText("UI_RestingMod_ResetDefaults") or "Reset Text Fields",
    getText("UI_RestingMod_ResetDefaults_Tooltip") or "Reset all text fields to their default values.",
    resetTextFieldsToDefaults
)


if MARQUA_RESTINGMOD_FINISHED_LEFT == nil then
    MARQUA_RESTINGMOD_FINISHED_LEFT = 1
end


function MuscleFatiqueRestingPrompt(player)
    if not player or not player:getStats() or not player:getBodyDamage() then return end

    local modeIndex = MARQUA_RESTINGMOD.modeComboBox:getValue()
    local endurance = player:getStats():getEndurance()
    local isSitting = player:isSitOnGround() or player:isSittingOnFurniture()

    local bd = player:getBodyDamage()
    -- Right arm pain (hand, forearm, upper arm)
    local handPain     = bd:getBodyPart(BodyPartType.Hand_R):getPain()
    local forearmPain  = bd:getBodyPart(BodyPartType.ForeArm_R):getPain()
    local upperarmPain = bd:getBodyPart(BodyPartType.UpperArm_R):getPain()
    local maxArmPain   = math.max(handPain, forearmPain, upperarmPain)

    local painThreshold = 0.1  -- keep your current threshold
    local inPain   = maxArmPain > painThreshold
    local hasPoison = (bd:getFoodSicknessLevel() or 0) > 0

    if isSitting then
        -- PHASE 1: recovering -> show RESTING only
        if endurance < 1 then
            HaloTextHelper.addBadText(player, getCustomOrDefault(MARQUA_RESTINGMOD.customResting, "UI_Resting"))
            clearGameSpeedFlag(player)
            return
        end

        -- PHASE 2/3: endurance full -> apply mode gating first (unchanged semantics)
        if modeIndex == 2 then
            setNormalGameSpeedOnce(player)                        -- "when pain"
        elseif modeIndex == 3 then
            if not inPain then setNormalGameSpeedOnce(player)     -- "when no pain"
            else clearGameSpeedFlag(player) end
        else
            clearGameSpeedFlag(player)                            -- "never"
        end

        -- PHASE 2: PAIN (exclusive)
        if inPain then
            HaloTextHelper.addBadText(player, getCustomOrDefault(MARQUA_RESTINGMOD.customStiffnessRightArm, "UI_Stiffness_Right_Arm"))
            return
        end

        -- PHASE 3: RESTED (exclusive)
        if hasPoison then
            HaloTextHelper.addBadText(player, getCustomOrDefault(MARQUA_RESTINGMOD.customPoisonState, "UI_POISONSTATE"))
        end

        if MARQUA_RESTINGMOD_FINISHED_LEFT > 0 then
            local msg = player:isFemale()
                and getCustomOrDefault(MARQUA_RESTINGMOD.customFinishedRestingF, "UI_Finished_resting_F")
                or  getCustomOrDefault(MARQUA_RESTINGMOD.customFinishedRestingM, "UI_Finished_resting_M")
            HaloTextHelper.addGoodText(player, msg)
            MARQUA_RESTINGMOD_FINISHED_LEFT = MARQUA_RESTINGMOD_FINISHED_LEFT - 1
        end
        return
    else
        -- Standing: reset only; standing-specific warn-once bleibt in twistonfire_stiffnesswarning.lua
        clearGameSpeedFlag(player)
        MARQUA_RESTINGMOD_FINISHED_LEFT = 1
    end
end

Events.OnPlayerUpdate.Add(MuscleFatiqueRestingPrompt)