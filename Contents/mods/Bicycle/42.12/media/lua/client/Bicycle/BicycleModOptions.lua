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
}

local function t(key)
    return getText("IGUI_Bicycle_" .. key)
end

local function BicycleConfig()
    local options = PZAPI.ModOptions:create("BicycleMod", getText("IGUI_Bicycle_ModOptionsTitle"))

    options:addDescription(t("ModOptionsDescriptionVolume"))
    config.bicycleSoundVolume = options:addSlider("BicycleSoundVolume", t("SoundVolumeLabel"), 0.01, 1, 0.01, 0.40, t("SoundVolumeTooltip"))

    options:addDescription(t("ModOptionsDescriptionSpeed"))
    config.bicycleWalkSpeedMultiplier = options:addSlider("SpeedMultSlow", t("SpeedSlowLabel"), 0.1, 5, 0.1, 2.2, t("SpeedSlowTooltip"))
    config.bicycleRunSpeedMultiplier = options:addSlider("SpeedMultFast", t("SpeedFastLabel"), 0.1, 5, 0.1, 3.1, t("SpeedFastTooltip"))

    options:addDescription(t("GameplayOptionsHeader"))
    config.bicycleEquipButton = options:addKeyBind("BicycleEquipButton", t("EquipKeyLabel"), Keyboard.KEY_E, t("EquipKeyTooltip"))
    config.bicycleImmersiveMode = options:addTickBox("BicycleImmersive", t("ImmersiveModeLabel"), true, t("ImmersiveModeTooltip"))
    config.bicycleTransferInv = options:addTickBox("BicycleTransferInv", t("TransferInventoryLabel"), false, t("TransferInventoryTooltip"))

    options:addDescription(t("DebugOptionsHeader"))
    config.bicycleSpawnButton = options:addButton("BicycleSpawn", t("SpawnBikeButton"), t("SpawnBikeTooltip"), SpawnBicycle)
    config.bicycleSaddlebagSpawnButton = options:addButton("BicycleSaddlebagSpawn", t("SpawnSaddlebagsButton"), t("SpawnSaddlebagsTooltip"), SpawnBicycleSaddlebag)
    config.bicycleBasketSpawnButton = options:addButton("BicycleBasketSpawn", t("SpawnBasketButton"), t("SpawnBasketTooltip"), SpawnBicycleBasket)
    config.bicycleCrateSpawnButton = options:addButton("BicycleCrateSpawn", t("SpawnCrateButton"), t("SpawnCrateTooltip"), SpawnBicycleCrate)
    config.bicycleFixAutoVaultButton = options:addButton("BicycleFixAutoVault", t("FixAutoVaultButton"), t("FixAutoVaultTooltip"), FixAutoVault)

    options:addDescription(t("CompatibilityDescription"))
    config.bicycleBetterInvFix = options:addTickBox("BicycleBetterInvFix", t("BetterInventoryFixLabel"), false, t("BetterInventoryFixTooltip"))

    options:addDescription(t("ModderNoticeDescription"))
    config.bicycleEditorFix = options:addTickBox("BicycleEditorFix", t("EditorFixLabel"), false, t("EditorFixTooltip"))
end

BicycleConfig()
