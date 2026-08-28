require("Bicycle/BicycleMenu")

---@class BicycleModConfig
local config = {
    bicycleWalkSpeedMultiplier = nil,
    bicycleRunSpeedMultiplier = nil,
    bicycleImmersiveMode = nil,
    bicycleTransferInv = nil,
    bicycleSoundVolume = nil,
    bicycleEditorFix = nil,
    bicycleBetterInvFix = nil,
    bicycleSpawnButton = nil,
    bicycleSaddlebagSpawnButton = nil,
    bicycleBasketSpawnButton = nil,
    bicycleCrateSpawnButton = nil,
    bicycleEquipButton = nil,
    bicycleFixAutoVaultButton = nil,
    bicycleLoadPenaltyEnabled = nil,
    bicycleMaxTurnPenalty = nil,
    bicycleMaxSpeedPenalty = nil,
    bicycleZombieSlowdownEnabled = nil,
    bicycleZombieSlowdownStrength = nil,
    bicycleZombieContactSensitivity = nil,
}

---@param key string
---@return string
---@nodiscard
local function tkey(key)
    return "IGUI_Bicycle_" .. key
end

---@return nil
local function BicycleConfig()
    local options = PZAPI.ModOptions:create("BicycleMod", tkey("ModOptionsTitle"))
    local isSingleplayer = not isClient() and not isServer()

    options:addDescription(tkey("ModOptionsDescriptionVolume"))
    config.bicycleSoundVolume = options:addSlider("BicycleSoundVolume", tkey("SoundVolumeLabel"), 0.01, 1, 0.01, 0.40, tkey("SoundVolumeTooltip"))

    if isSingleplayer then
        options:addDescription(tkey("ModOptionsDescriptionSpeed"))
        config.bicycleWalkSpeedMultiplier = options:addSlider("SpeedMultSlow", tkey("SpeedSlowLabel"), 0.1, 5, 0.1, 2.2, tkey("SpeedSlowTooltip"))
        config.bicycleRunSpeedMultiplier = options:addSlider("SpeedMultFast", tkey("SpeedFastLabel"), 0.1, 5, 0.1, 3.1, tkey("SpeedFastTooltip"))

        options:addDescription(tkey("ModOptionsDescriptionLoadPenalty"))
        config.bicycleLoadPenaltyEnabled = options:addTickBox("BicycleLoadPenaltyEnabled", tkey("LoadPenaltyEnabledLabel"), true, tkey("LoadPenaltyEnabledTooltip"))
        config.bicycleMaxTurnPenalty = options:addSlider("BicycleMaxTurnPenalty", tkey("MaxTurnPenaltyLabel"), 0, 75, 1, 50, tkey("MaxTurnPenaltyTooltip"))
        config.bicycleMaxSpeedPenalty = options:addSlider("BicycleMaxSpeedPenalty", tkey("MaxSpeedPenaltyLabel"), 0, 75, 1, 35, tkey("MaxSpeedPenaltyTooltip"))

        options:addDescription(tkey("ModOptionsDescriptionZombieSlowdown"))
        config.bicycleZombieSlowdownEnabled = options:addTickBox("BicycleZombieSlowdownEnabled", tkey("ZombieSlowdownEnabledLabel"), true, tkey("ZombieSlowdownEnabledTooltip"))
        config.bicycleZombieSlowdownStrength = options:addSlider("BicycleZombieSlowdownStrength", tkey("ZombieSlowdownStrengthLabel"), 0, 150, 5, 100, tkey("ZombieSlowdownStrengthTooltip"))
        config.bicycleZombieContactSensitivity = options:addSlider("BicycleZombieContactSensitivity", tkey("ZombieContactSensitivityLabel"), 0, 100, 5, 30, tkey("ZombieContactSensitivityTooltip"))
    end

    options:addDescription(tkey("GameplayOptionsHeader"))
    config.bicycleEquipButton = options:addKeyBind("BicycleEquipButton", tkey("EquipKeyLabel"), Keyboard.KEY_E, tkey("EquipKeyTooltip"))
    if isSingleplayer then
        config.bicycleImmersiveMode = options:addTickBox("BicycleImmersive", tkey("ImmersiveModeLabel"), true, tkey("ImmersiveModeTooltip"))
        config.bicycleTransferInv = options:addTickBox("BicycleTransferInv", tkey("TransferInventoryLabel"), false, tkey("TransferInventoryTooltip"))
    end

    options:addDescription(tkey("DebugOptionsHeader"))
    config.bicycleSpawnButton = options:addButton("BicycleSpawn", tkey("SpawnBikeButton"), tkey("SpawnBikeTooltip"), SpawnBicycle)
    config.bicycleSaddlebagSpawnButton = options:addButton("BicycleSaddlebagSpawn", tkey("SpawnSaddlebagsButton"), tkey("SpawnSaddlebagsTooltip"), SpawnBicycleSaddlebag)
    config.bicycleBasketSpawnButton = options:addButton("BicycleBasketSpawn", tkey("SpawnBasketButton"), tkey("SpawnBasketTooltip"), SpawnBicycleBasket)
    config.bicycleCrateSpawnButton = options:addButton("BicycleCrateSpawn", tkey("SpawnCrateButton"), tkey("SpawnCrateTooltip"), SpawnBicycleCrate)
    config.bicycleFixAutoVaultButton = options:addButton("BicycleFixAutoVault", tkey("FixAutoVaultButton"), tkey("FixAutoVaultTooltip"), FixAutoVault)

    options:addDescription(tkey("CompatibilityDescription"))
    config.bicycleBetterInvFix = options:addTickBox("BicycleBetterInvFix", tkey("BetterInventoryFixLabel"), false, tkey("BetterInventoryFixTooltip"))

    options:addDescription(tkey("ModderNoticeDescription"))
    config.bicycleEditorFix = options:addTickBox("BicycleEditorFix", tkey("EditorFixLabel"), false, tkey("EditorFixTooltip"))
end

BicycleConfig()
