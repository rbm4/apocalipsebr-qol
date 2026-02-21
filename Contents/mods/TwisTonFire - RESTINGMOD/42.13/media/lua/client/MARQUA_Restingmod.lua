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

do
    local label = getText("UI_RestingMod_SitKeybind") or "Sit on Ground (Keybind)"
    local tip   = getText("UI_RestingMod_SitKeybind_Tooltip") or "Choose a key to sit on the ground. Leave unassigned to disable."

    local fn = options.addKeyBind or options.addKeybind or options.addKeyBinding or options.addKeybinding
    if fn then
        -- Try common signatures safely.
        local ok, obj = pcall(fn, options, "sitKeybind", label, 0, tip)
        if not ok then
            ok, obj = pcall(fn, options, "sitKeybind", label, tip)
        end
        MARQUA_RESTINGMOD.sitKeybind = obj
    else
        -- Very rare fallback: store numeric keycode as text (still defaults to 0/unassigned).
        MARQUA_RESTINGMOD.sitKeybind = options:addTextEntry("sitKeybind", label, "0", tip)
    end
end

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
    if not player then return end

    local stats = player:getStats()
    local bd = player:getBodyDamage()
    if not stats or not bd then return end

    -- Safe modeIndex (default to "Never" if options aren't ready yet)
    local modeIndex = 1
    if MARQUA_RESTINGMOD and MARQUA_RESTINGMOD.modeComboBox and MARQUA_RESTINGMOD.modeComboBox.getValue then
        local ok, v = pcall(MARQUA_RESTINGMOD.modeComboBox.getValue, MARQUA_RESTINGMOD.modeComboBox)
        if ok and type(v) == "number" then
            modeIndex = v
        end
    end

    -- Endurance (Build 42.13: getEndurance() may be gone; use Stats:get(CharacterStat.ENDURANCE))
    local enduranceFull = false
    do
        if stats.getEndurance then
            local ok, v = pcall(stats.getEndurance, stats)
            if ok and type(v) == "number" then
                enduranceFull = v >= 0.999
            end
        elseif stats.get and CharacterStat and CharacterStat.ENDURANCE then
            local ok, v = pcall(stats.get, stats, CharacterStat.ENDURANCE)
            if ok and type(v) == "number" then
                enduranceFull = v >= 0.999
            end
        elseif stats.getLastEndurance then
            local ok, v = pcall(stats.getLastEndurance, stats)
            if ok and type(v) == "number" then
                enduranceFull = v >= 0.999
            end
        else
            -- Last resort: moodle level (0..4). Level 0 means "full enough".
            local moodles = player:getMoodles()
            if moodles and moodles.getMoodleLevel and MoodleType and MoodleType.ENDURANCE then
                local ok, lvl = pcall(moodles.getMoodleLevel, moodles, MoodleType.ENDURANCE)
                if ok and type(lvl) == "number" then
                    enduranceFull = lvl <= 0
                end
            end
        end
    end

    -- Sitting state (defensive)
    local isSitting = false
    do
        local function safeBoolCall(fnName)
            local fn = player and player[fnName]
            if not fn then return false end
            local ok, v = pcall(fn, player)
            return ok and v == true
        end

        if safeBoolCall("isSitOnGround") then isSitting = true end
        if not isSitting and safeBoolCall("isSittingOnGround") then isSitting = true end
        if not isSitting and safeBoolCall("isSittingOnFurniture") then isSitting = true end
        if not isSitting and safeBoolCall("isSitting") then isSitting = true end
    end

    -- Right arm pain (hand, forearm, upper arm)
    local handPain     = bd:getBodyPart(BodyPartType.Hand_R):getPain()
    local forearmPain  = bd:getBodyPart(BodyPartType.ForeArm_R):getPain()
    local upperarmPain = bd:getBodyPart(BodyPartType.UpperArm_R):getPain()
    local maxArmPain   = math.max(handPain, forearmPain, upperarmPain)

    local painThreshold = 0.1
    local inPain = maxArmPain > painThreshold

    -- Food sickness ONLY (corpse / bad food). No fallback to generic SICKNESS and no Sick-moodle fallback.
    -- Trigger earlier than the visible "Queasy" moodle: warn as soon as FOOD_SICKNESS > 5.
    local hasPoison = false
    do
        local foodSickness = nil

        -- Preferred (Build 42.13+): this is the same value shown in Debug -> Body -> "Food Sickness"
        if stats and stats.get and CharacterStat and CharacterStat.FOOD_SICKNESS then
            local ok, v = pcall(stats.get, stats, CharacterStat.FOOD_SICKNESS)
            if ok and type(v) == "number" then
                foodSickness = v
            end
        end

        -- Optional fallback: older food-sickness getters (still FOOD-only, not generic sickness)
        if foodSickness == nil then
            local getter = bd and (bd.getFoodSicknessLevel or bd.getFoodSickness)
            if getter then
                local ok, v = pcall(getter, bd)
                if ok and type(v) == "number" then
                    foodSickness = v
                end
            end
        end

        hasPoison = (foodSickness or 0) > 5
    end

    if isSitting then
        -- Phase 1: recovering -> show RESTING only
        if not enduranceFull then
            HaloTextHelper.addBadText(player, getCustomOrDefault(MARQUA_RESTINGMOD.customResting, "UI_Resting"))
            clearGameSpeedFlag(player)
            return
        end

        -- Phase 2/3: endurance full -> apply mode gating first (unchanged semantics)
        if modeIndex == 2 then
            setNormalGameSpeedOnce(player) -- "when pain"
        elseif modeIndex == 3 then
            if not inPain then setNormalGameSpeedOnce(player) else clearGameSpeedFlag(player) end -- "when no pain"
        else
            clearGameSpeedFlag(player) -- "never"
        end

        -- Phase 2: PAIN (exclusive)
        if inPain then
            HaloTextHelper.addBadText(player, getCustomOrDefault(MARQUA_RESTINGMOD.customStiffnessRightArm, "UI_Stiffness_Right_Arm"))
            return
        end

        -- Phase 3: RESTED (exclusive)
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
        -- Standing: reset only; standing-specific warn-once stays in twistonfire_stiffnesswarning.lua
        clearGameSpeedFlag(player)
        MARQUA_RESTINGMOD_FINISHED_LEFT = 1
    end
end

Events.OnPlayerUpdate.Add(MuscleFatiqueRestingPrompt)