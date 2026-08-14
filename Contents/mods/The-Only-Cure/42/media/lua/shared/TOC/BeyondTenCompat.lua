local BeyondTenCompat = {}

local TOC_PERKS = {
    Side_L = true,
    Side_R = true,
    ProstFamiliarity = true,
}

local didTryRequire = false
local didRegister = false

local function GetBeyondTen()
    if BeyondTen then return BeyondTen end
    if didTryRequire then return BeyondTen end

    didTryRequire = true
    pcall(require, "BeyondTen/Shared")
    return BeyondTen
end

function BeyondTenCompat.IsTOCPerk(perkName)
    return TOC_PERKS[perkName] == true
end

function BeyondTenCompat.GetPerk(perkName)
    if not BeyondTenCompat.IsTOCPerk(perkName) then return nil end
    return Perks[perkName]
end

function BeyondTenCompat.RegisterPerks()
    if didRegister then return true end

    local BT = GetBeyondTen()
    if not BT or type(BT.RegisterTrainablePerk) ~= "function" then return false end

    local ok = true
    for perkName, _ in pairs(TOC_PERKS) do
        local perk = Perks[perkName]
        if perk and not BT.RegisterTrainablePerk(perk) then
            ok = false
        end
    end

    didRegister = ok
    return ok
end

function BeyondTenCompat.GetMaxLevel()
    local BT = GetBeyondTen()
    if BT and tonumber(BT.MAX_LEVEL) then return tonumber(BT.MAX_LEVEL) end
    return 10
end

function BeyondTenCompat.GetEffectiveLevel(character, perkName)
    local perk = BeyondTenCompat.GetPerk(perkName)
    if not character or not perk then return 0 end

    local BT = GetBeyondTen()
    if BT then
        BeyondTenCompat.RegisterPerks()
        if type(BT.GetEffectiveLevel) == "function" and type(BT.IsTrainablePerk) == "function" and BT.IsTrainablePerk(perk) then
            return tonumber(BT.GetEffectiveLevel(character, perk)) or 0
        end
    end

    return tonumber(character:getPerkLevel(perk)) or 0
end

function BeyondTenCompat.AddXP(character, perkName, amount)
    local perk = BeyondTenCompat.GetPerk(perkName)
    amount = tonumber(amount)
    if not character or not perk or not amount or amount <= 0 then return 0, 0, 0, 0, 0 end

    local BT = GetBeyondTen()
    if BT then
        BeyondTenCompat.RegisterPerks()
        if type(BT.AddRecoveredXP) == "function" and type(BT.IsTrainablePerk) == "function" and BT.IsTrainablePerk(perk) then
            return BT.AddRecoveredXP(character, perk, amount)
        end
    end

    local oldLevel = tonumber(character:getPerkLevel(perk)) or 0
    if oldLevel >= 10 then return 0, 0, 0, oldLevel, oldLevel end

    addXpNoMultiplier(character, perk, amount)
    local newLevel = tonumber(character:getPerkLevel(perk)) or oldLevel
    return amount, amount, 0, oldLevel, newLevel
end

BeyondTenCompat.RegisterPerks()

return BeyondTenCompat
