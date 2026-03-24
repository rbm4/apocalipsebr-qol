-- LabSandboxOptions.lua
-- Helper para ler as opções de sandbox

local LabSandboxOptions = {}

local optionsCache = {}
local cacheInitialized = false

local function InitializeCache()
    if cacheInitialized then return end
    
    local sandbox = SandboxVars.ZombieVirusVaccineBETA
    
    if sandbox then
        -- DEBUG
        optionsCache.DebugMode = sandbox.DebugMode == true
        
        -- AUTÓPSIA
        optionsCache.AllowAutopsyOnGround = sandbox.AllowAutopsyOnGround ~= false
        optionsCache.AutopsySpeed = sandbox.AutopsySpeed or 1200
        optionsCache.TableSpeedBonus = sandbox.TableSpeedBonus or 6
        optionsCache.AutopsyGroundXP = sandbox.AutopsyGroundXP or 15
        optionsCache.AutopsyTableXP = sandbox.AutopsyTableXP or 30
        optionsCache.TicksDecreasedByPerkLv = sandbox.TicksDecreasedByPerkLv or 30
        
        -- COLETA DE PARTES
        optionsCache.CollectPartXP = sandbox.CollectPartXP or 15
        optionsCache.BrainHighOffset = sandbox.BrainHighOffset or 10
        optionsCache.HemophobicDebuff = sandbox.HemophobicDebuff or 10

        -- DEGRADAÇÃO
        optionsCache.AllowScalpelDegrade = sandbox.AllowScalpelDegrade == true
        optionsCache.AllowSawDegrade = sandbox.AllowSawDegrade ~= false

        -- BLOOD AGING
        optionsCache.BloodAgingMode = sandbox.BloodAgingMode ~= false
        optionsCache.BloodAgingRadius = sandbox.BloodAgingRadius or 14
        
        -- RLP
        optionsCache.StartingKit = sandbox.StartingKit ~= false
        
        cacheInitialized = true
    end
end

-- ==============================
-- DEBUG
-- ==============================
function LabSandboxOptions.IsDebugMode()
    InitializeCache()
    return optionsCache.DebugMode
end

-- ==============================
-- AUTÓPSIA
-- ==============================
function LabSandboxOptions.IsAutopsyOnGroundAllowed()
    InitializeCache()
    return optionsCache.AllowAutopsyOnGround
end

function LabSandboxOptions.GetAutopsyBaseSpeed()
    InitializeCache()
    return optionsCache.AutopsySpeed
end

function LabSandboxOptions.GetTableSpeedBonusPercent()
    InitializeCache()
    local value = optionsCache.TableSpeedBonus or 6
    return (value - 1) * 10
end

function LabSandboxOptions.GetAutopsyGroundXP()
    InitializeCache()
    return optionsCache.AutopsyGroundXP
end

function LabSandboxOptions.GetAutopsyTableXP()
    InitializeCache()
    return optionsCache.AutopsyTableXP
end

function LabSandboxOptions.GetTicksDecreasedByPerkLevel()
    InitializeCache()
    return optionsCache.TicksDecreasedByPerkLv
end

-- ==============================
-- COLETA DE PARTES
-- ==============================
function LabSandboxOptions.GetCollectPartXP()
    InitializeCache()
    return optionsCache.CollectPartXP
end

function LabSandboxOptions.GetBrainHighOffset()
    InitializeCache()
    return optionsCache.BrainHighOffset
end

function LabSandboxOptions.GetHemophobicDebuff()
    InitializeCache()
    return optionsCache.HemophobicDebuff
end

-- ==============================
-- DEGRADAÇÃO
-- ==============================
function LabSandboxOptions.IsScalpelDegradeAllowed()
    InitializeCache()
    return optionsCache.AllowScalpelDegrade
end

function LabSandboxOptions.IsSawDegradeAllowed()
    InitializeCache()
    return optionsCache.AllowSawDegrade
end

-- ==============================
-- BLOOD AGING
-- ==============================
function LabSandboxOptions.IsBloodAgingEnabled()
    InitializeCache()
    return optionsCache.BloodAgingMode
end

function LabSandboxOptions.GetBloodAgingRadius()
    InitializeCache()
    return optionsCache.BloodAgingRadius
end

-- ==============================
-- RLP
-- ==============================
function LabSandboxOptions.IsStartingKitEnabled()
    InitializeCache()
    return optionsCache.StartingKit
end

-- ==============================
-- RELOAD
-- ==============================
function LabSandboxOptions.ReloadCache()
    cacheInitialized = false
    optionsCache = {}
    InitializeCache()
    print("========================================")
    print("[ZVirusVaccine] SANDBOX OPTIONS CACHE RELOADED.")
end

Events.OnInitGlobalModData.Add(LabSandboxOptions.ReloadCache)

return LabSandboxOptions