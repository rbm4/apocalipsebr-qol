--[[
    [B42.20] Muscle Manager (Build 42 / SP + MP)
    ------------------------------------------------------------------
    Defaults and in-game Mod Options (PZAPI.ModOptions, vanilla B42 API).

    Everything here is client side: the server never sees this file and
    never needs it.
]]

MuscleManager = MuscleManager or {}
local MM = MuscleManager

MM.MOD_ID = "MuscleManager"

if MM.configLoaded then return end
MM.configLoaded = true

MM.defaults = {
    -- pace
    restAt        = 25,     -- % of endurance where the character stops the set and rests
    resumeAt      = 90,     -- % of endurance where it stands up and starts the next set
    setMinutes    = 15,     -- in-game minutes per set (same field as the vanilla panel)
    sitToRest     = true,   -- sit on the ground while resting (used only when no furniture is in reach)
    restOnFurniture = true, -- prefer a nearby bed/couch/mat over the ground
    travelRange   = 6,      -- meters (tiles) the character will walk to a rest spot or gym equipment
    maxSets       = 0,      -- 0 = train until told to stop
    rotate        = false,  -- cycle through the available exercises, one per set

    -- pain
    treatPain     = true,
    painLevel     = 3,      -- pain moodle level that triggers treatment (1-4)
    usePills      = true,   -- swallow Base.Pills (painkillers)
    useBooze      = false,  -- sip an alcoholic drink instead / as a fallback
    boozeSip      = 5,      -- % of the container drunk per sip
    maxDrunk      = 30,     -- never drink above this intoxication (0-100)

    -- food
    autoEat       = false,  -- eat from the inventory while resting
    eatAt         = 2,      -- hunger moodle level that triggers a meal (1-4)

    -- items lying around
    useNearby     = true,   -- also use bags, containers and the floor nearby
    nearbyRange   = 3,      -- how far to look, in tiles
    putItemBack   = true,   -- return the leftovers to where they came from

    -- safety
    stopZombie    = true,
    stopDamage    = true,
    stopLowHealth = true,
    minHealth     = 80,     -- overall body health (0-100) below which auto stops
    stopManual    = true,   -- stop when the player moves/aims
    stopHeavyLoad = true,
    stopOnClose   = false,  -- stop when the fitness panel is closed

    -- misc
    autoDefault   = true,   -- AUTO already ticked when the panel opens
    -- On at the first step by default since 2026-08-29, to match Auto
    -- All. A training session is minutes of watching a character do
    -- press-ups; nobody wants to reach for the speed key every set.
    fastForward   = 2,      -- 1 off / 2 = 2x / 3 = 3x / 4 = Very fast (same tiers as the vanilla Fast Forward keys, single player only)
    holdSpeed     = true,   -- keep that speed while resting too, not only while training
    notify        = 1,      -- 1 halo text / 2 speech bubble / 3 off
    notifyEvery   = 20,     -- seconds before the same "waiting" message repeats
    showSummary   = true,   -- session card (sets, time, XP) when auto training stops
}

--- Reads a setting from Mod Options, falling back to the default above.
function MM.opt(key)
    local options = MM.options
    if options then
        local option = options:getOption(key)
        if option then
            local ok, value = pcall(function() return option:getValue() end)
            if ok and type(value) == "string" then value = tonumber(value) or value end
            if ok and value ~= nil then return value end
        end
    end
    return MM.defaults[key]
end


---------------------------------------------------------------------
-- The host switch
--
-- This file ships in two places: the standalone Muscle Manager, and
-- bundled inside Auto All as its "Auto Exercise" module. Auto All gives
-- every automation a tickbox, a sandbox override and a row in the
-- character tab, and this one has to answer to the same three.
--
-- Asked of Auto All rather than duplicated here, so a server forcing
-- AutoAll.EnableExercise = 0 switches this off for the same reason and
-- through the same code path as every other module.
--
-- Standalone, AutoAll simply does not exist and this always answers true,
-- so the file behaves exactly as it always did.
function MM.enabled()
    if AutoAll and type(AutoAll.enabled) == "function" then
        local ok, on = pcall(AutoAll.enabled, "exercise")
        if ok then return on ~= false end
    end
    return true
end

local function createModOptions()
    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.create) then return end

    local d = MM.defaults
    local options = PZAPI.ModOptions:create(MM.MOD_ID, "UI_MM_ModName")
    MM.options = options

    options:addTitle("UI_MM_opt_titlePace")
    options:addSlider("restAt", "UI_MM_opt_restAt", 5, 60, 5, d.restAt, "UI_MM_opt_restAt_tt")
    options:addSlider("resumeAt", "UI_MM_opt_resumeAt", 40, 100, 5, d.resumeAt, "UI_MM_opt_resumeAt_tt")
    options:addSlider("setMinutes", "UI_MM_opt_setMinutes", 5, 60, 5, d.setMinutes, "UI_MM_opt_setMinutes_tt")
    options:addSlider("maxSets", "UI_MM_opt_maxSets", 0, 50, 1, d.maxSets, "UI_MM_opt_maxSets_tt")
    options:addTickBox("restOnFurniture", "UI_MM_opt_restOnFurniture", d.restOnFurniture, "UI_MM_opt_restOnFurniture_tt")
    options:addSlider("travelRange", "UI_MM_opt_travelRange", 2, 15, 1, d.travelRange, "UI_MM_opt_travelRange_tt")
    options:addTickBox("sitToRest", "UI_MM_opt_sitToRest", d.sitToRest, "UI_MM_opt_sitToRest_tt")
    options:addTickBox("rotate", "UI_MM_opt_rotate", d.rotate, "UI_MM_opt_rotate_tt")

    options:addTitle("UI_MM_opt_titlePain")
    options:addTickBox("treatPain", "UI_MM_opt_treatPain", d.treatPain, "UI_MM_opt_treatPain_tt")
    options:addSlider("painLevel", "UI_MM_opt_painLevel", 1, 4, 1, d.painLevel, "UI_MM_opt_painLevel_tt")
    options:addTickBox("usePills", "UI_MM_opt_usePills", d.usePills, "UI_MM_opt_usePills_tt")
    options:addTickBox("useBooze", "UI_MM_opt_useBooze", d.useBooze, "UI_MM_opt_useBooze_tt")
    options:addSlider("boozeSip", "UI_MM_opt_boozeSip", 1, 25, 1, d.boozeSip, "UI_MM_opt_boozeSip_tt")
    options:addSlider("maxDrunk", "UI_MM_opt_maxDrunk", 5, 100, 5, d.maxDrunk, "UI_MM_opt_maxDrunk_tt")

    options:addTitle("UI_MM_opt_titleFood")
    options:addTickBox("autoEat", "UI_MM_opt_autoEat", d.autoEat, "UI_MM_opt_autoEat_tt")
    options:addSlider("eatAt", "UI_MM_opt_eatAt", 1, 4, 1, d.eatAt, "UI_MM_opt_eatAt_tt")

    options:addTitle("UI_MM_opt_titleItems")
    options:addTickBox("useNearby", "UI_MM_opt_useNearby", d.useNearby, "UI_MM_opt_useNearby_tt")
    options:addSlider("nearbyRange", "UI_MM_opt_nearbyRange", 1, 10, 1, d.nearbyRange, "UI_MM_opt_nearbyRange_tt")
    options:addTickBox("putItemBack", "UI_MM_opt_putItemBack", d.putItemBack, "UI_MM_opt_putItemBack_tt")

    options:addTitle("UI_MM_opt_titleSafety")
    options:addTickBox("stopZombie", "UI_MM_opt_stopZombie", d.stopZombie, "UI_MM_opt_stopZombie_tt")
    options:addTickBox("stopDamage", "UI_MM_opt_stopDamage", d.stopDamage, "UI_MM_opt_stopDamage_tt")
    options:addTickBox("stopLowHealth", "UI_MM_opt_stopLowHealth", d.stopLowHealth, "UI_MM_opt_stopLowHealth_tt")
    options:addSlider("minHealth", "UI_MM_opt_minHealth", 10, 99, 1, d.minHealth, "UI_MM_opt_minHealth_tt")
    options:addTickBox("stopManual", "UI_MM_opt_stopManual", d.stopManual, "UI_MM_opt_stopManual_tt")
    options:addTickBox("stopHeavyLoad", "UI_MM_opt_stopHeavyLoad", d.stopHeavyLoad, "UI_MM_opt_stopHeavyLoad_tt")
    options:addTickBox("stopOnClose", "UI_MM_opt_stopOnClose", d.stopOnClose, "UI_MM_opt_stopOnClose_tt")

    options:addTitle("UI_MM_opt_titleMisc")
    options:addTickBox("autoDefault", "UI_MM_opt_autoDefault", d.autoDefault, "UI_MM_opt_autoDefault_tt")

    local speed = options:addComboBox("fastForward", "UI_MM_opt_fastForward", "UI_MM_opt_fastForward_tt")
    speed:addItem("UI_MM_speed_off")
    speed:addItem("UI_MM_speed_2x", true)
    speed:addItem("UI_MM_speed_3x")
    speed:addItem("UI_MM_speed_vfast")

    options:addTickBox("holdSpeed", "UI_MM_opt_holdSpeed", d.holdSpeed, "UI_MM_opt_holdSpeed_tt")

    local notify = options:addComboBox("notify", "UI_MM_opt_notify", "UI_MM_opt_notify_tt")
    notify:addItem("UI_MM_notify_halo", true)
    notify:addItem("UI_MM_notify_say")
    notify:addItem("UI_MM_notify_off")

    options:addSlider("notifyEvery", "UI_MM_opt_notifyEvery", 5, 120, 5, d.notifyEvery, "UI_MM_opt_notifyEvery_tt")
    options:addTickBox("showSummary", "UI_MM_opt_showSummary", d.showSummary, "UI_MM_opt_showSummary_tt")
end

createModOptions()

-- The options screen only reads ModOptions.ini when it is built, so load the
-- saved values ourselves in case the player never opens the options panel.
local function loadSavedOptions()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.load then
        pcall(function() PZAPI.ModOptions:load() end)
    end
end

Events.OnGameStart.Add(loadSavedOptions)
