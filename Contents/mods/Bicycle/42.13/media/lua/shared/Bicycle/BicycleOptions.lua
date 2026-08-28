require("Bicycle/BicycleCore")

---@class BicycleOptions
Bicycle = Bicycle or {}
Bicycle.Options = Bicycle.Options or {}

local Options = Bicycle.Options

Options.Key = {
    WalkSpeedMultiplier = "SpeedMultSlow",
    RunSpeedMultiplier = "SpeedMultFast",
    ImmersiveMode = "BicycleImmersive",
    TransferToInventory = "BicycleTransferInv",
    LoadPenaltyEnabled = "BicycleLoadPenaltyEnabled",
    MaxTurnPenalty = "BicycleMaxTurnPenalty",
    MaxSpeedPenalty = "BicycleMaxSpeedPenalty",
    ZombieSlowdownEnabled = "BicycleZombieSlowdownEnabled",
    ZombieSlowdownStrength = "BicycleZombieSlowdownStrength",
    ZombieContactSensitivity = "BicycleZombieContactSensitivity"
}

Options.Default = {
    WalkSpeedMultiplier = 2.2,
    RunSpeedMultiplier = 3.1,
    ImmersiveMode = true,
    TransferToInventory = false,
    LoadPenaltyEnabled = true,
    MaxTurnPenalty = 50,
    MaxSpeedPenalty = 35,
    ZombieSlowdownEnabled = true,
    ZombieSlowdownStrength = 100,
    ZombieContactSensitivity = 30
}

---@return ModOptions|nil
---@nodiscard
local function getSingleplayerOptions()
    if not (PZAPI and PZAPI.ModOptions) then
        return nil
    end

    return PZAPI.ModOptions:getOptions("BicycleMod")
end

---@param fallback number|nil
---@return number
---@nodiscard
function Options.getWalkSpeedMultiplier(fallback)
    local value = fallback or Options.Default.WalkSpeedMultiplier

    if isClient() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.WalkSpeedMultiplier then
            value = SandboxVars.Bicycle.WalkSpeedMultiplier
        end
    elseif isServer() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.WalkSpeedMultiplier then
            value = SandboxVars.Bicycle.WalkSpeedMultiplier
        end
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.WalkSpeedMultiplier)
            if option then
                value = option:getValue()
            end
        end
    end

    return value
end

---@param fallback number|nil
---@return number
---@nodiscard
function Options.getRunSpeedMultiplier(fallback)
    local value = fallback or Options.Default.RunSpeedMultiplier

    if isClient() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.RunSpeedMultiplier then
            value = SandboxVars.Bicycle.RunSpeedMultiplier
        end
    elseif isServer() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.RunSpeedMultiplier then
            value = SandboxVars.Bicycle.RunSpeedMultiplier
        end
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.RunSpeedMultiplier)
            if option then
                value = option:getValue()
            end
        end
    end

    return value
end

---@return number, number
---@nodiscard
function Options.getSpeedMultipliers()
    return Options.getWalkSpeedMultiplier(), Options.getRunSpeedMultiplier()
end

---@param fallback boolean|nil
---@return boolean
---@nodiscard
function Options.isImmersiveModeEnabled(fallback)
    local value = fallback
    if value == nil then
        value = Options.Default.ImmersiveMode
    end

    if isClient() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.ImmersiveMode ~= nil then
            value = SandboxVars.Bicycle.ImmersiveMode
        end
    elseif isServer() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.ImmersiveMode ~= nil then
            value = SandboxVars.Bicycle.ImmersiveMode
        end
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.ImmersiveMode)
            if option then
                value = option:getValue()
            end
        end
    end

    return value == true
end

---@param fallback boolean|nil
---@return boolean
---@nodiscard
function Options.isLoadPenaltyEnabled(fallback)
    local value = fallback
    if value == nil then
        value = Options.Default.LoadPenaltyEnabled
    end

    if isClient() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.LoadPenaltyEnabled ~= nil then
            value = SandboxVars.Bicycle.LoadPenaltyEnabled
        end
    elseif isServer() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.LoadPenaltyEnabled ~= nil then
            value = SandboxVars.Bicycle.LoadPenaltyEnabled
        end
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.LoadPenaltyEnabled)
            if option then
                value = option:getValue()
            end
        end
    end

    return value == true
end

---@param fallback number|nil
---@return number
---@nodiscard
function Options.getMaxTurnPenalty(fallback)
    local value = fallback or Options.Default.MaxTurnPenalty

    if isClient() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.MaxTurnPenalty then
            value = SandboxVars.Bicycle.MaxTurnPenalty
        end
    elseif isServer() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.MaxTurnPenalty then
            value = SandboxVars.Bicycle.MaxTurnPenalty
        end
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.MaxTurnPenalty)
            if option then
                value = option:getValue()
            end
        end
    end

    return value
end

---@param fallback number|nil
---@return number
---@nodiscard
function Options.getMaxSpeedPenalty(fallback)
    local value = fallback or Options.Default.MaxSpeedPenalty

    if isClient() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.MaxSpeedPenalty then
            value = SandboxVars.Bicycle.MaxSpeedPenalty
        end
    elseif isServer() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.MaxSpeedPenalty then
            value = SandboxVars.Bicycle.MaxSpeedPenalty
        end
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.MaxSpeedPenalty)
            if option then
                value = option:getValue()
            end
        end
    end

    return value
end

---@param fallback boolean|nil
---@return boolean
---@nodiscard
function Options.canTransferToPlayerInventory(fallback)
    local value = fallback
    if value == nil then
        value = Options.Default.TransferToInventory
    end

    if isClient() then
        return true
    elseif isServer() then
        return true
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.TransferToInventory)
            if option then
                value = option:getValue()
            end
        end
    end

    return value == true
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
function Options.canUseSpawnButtons(player)
    if isClient() then
        return player and player:isAccessLevel("admin") == true
    elseif isServer() then
        return player and player:isAccessLevel("admin") == true
    end

    return true
end

---@param fallback boolean|nil
---@return boolean
---@nodiscard
function Options.isZombieSlowdownEnabled(fallback)
    local value = fallback
    if value == nil then
        value = Options.Default.ZombieSlowdownEnabled
    end

    if isClient() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.ZombieSlowdownEnabled ~= nil then
            value = SandboxVars.Bicycle.ZombieSlowdownEnabled
        end
    elseif isServer() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.ZombieSlowdownEnabled ~= nil then
            value = SandboxVars.Bicycle.ZombieSlowdownEnabled
        end
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.ZombieSlowdownEnabled)
            if option then
                value = option:getValue()
            end
        end
    end

    return value == true
end

---@param fallback number|nil
---@return number
---@nodiscard
function Options.getZombieSlowdownStrength(fallback)
    local value = fallback or Options.Default.ZombieSlowdownStrength

    if isClient() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.ZombieSlowdownStrength then
            value = SandboxVars.Bicycle.ZombieSlowdownStrength
        end
    elseif isServer() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.ZombieSlowdownStrength then
            value = SandboxVars.Bicycle.ZombieSlowdownStrength
        end
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.ZombieSlowdownStrength)
            if option then
                value = option:getValue()
            end
        end
    end

    return value
end

---@param fallback number|nil
---@return number
---@nodiscard
function Options.getZombieContactSensitivity(fallback)
    local value = fallback or Options.Default.ZombieContactSensitivity

    if isClient() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.ZombieContactSensitivity then
            value = SandboxVars.Bicycle.ZombieContactSensitivity
        end
    elseif isServer() then
        if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.ZombieContactSensitivity then
            value = SandboxVars.Bicycle.ZombieContactSensitivity
        end
    else
        local options = getSingleplayerOptions()
        if options then
            local option = options:getOption(Options.Key.ZombieContactSensitivity)
            if option then
                value = option:getValue()
            end
        end
    end

    return value
end

return Options
