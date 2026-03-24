--[[local LabSandboxOptions = require "Util/LabSandboxOptions"

local function DebugPrintSandboxOptions()

    print("========== ZVirusVaccine Sandbox ==========")
    print("Debug Mode:", LabSandboxOptions.IsDebugMode())
    print("Allow Autopsy On Ground:", LabSandboxOptions.IsAutopsyOnGroundAllowed())
    print("Autopsy Base Speed:", LabSandboxOptions.GetAutopsyBaseSpeed())
    print("Table Speed Bonus Percent:", LabSandboxOptions.GetTableSpeedBonusPercent())
    print("Autopsy Ground XP:", LabSandboxOptions.GetAutopsyGroundXP())
    print("Autopsy Table XP:", LabSandboxOptions.GetAutopsyTableXP())
    print("Ticks Decreased By Perk Level:", LabSandboxOptions.GetTicksDecreasedByPerkLevel())
    print("Allow Scalpel Degrade:", LabSandboxOptions.IsScalpelDegradeAllowed())
    print("Allow Saw Degrade:", LabSandboxOptions.IsSawDegradeAllowed())
    print("Blood Aging Enabled:", LabSandboxOptions.IsBloodAgingEnabled())
    print("Blood Aging Radius:", LabSandboxOptions.GetBloodAgingRadius())
    print("===========================================")
end

Events.OnGameStart.Add(DebugPrintSandboxOptions)]]