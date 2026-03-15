local SUPPRESSOR_FULL_TYPE = "SimpleSuppressorB42.Suppressor"
local PROCEDURAL_APPLIED = false

local PROCEDURAL_WEIGHTS = {
    ArmyBunkerLockers = 0.20,
    ArmyBunkerStorage = 0.18,
    ArmyHangarTools = 0.12,
    ArmyStorageGuns = 1.20,
    ArmySurplusCases = 0.30,
    ArmySurplusMisc = 0.16,
    ArmySurplusTools = 0.12,
    PoliceCaptainDesk = 0.18,
    PoliceDesk = 0.15,
    PoliceEvidence = 0.30,
    PoliceLockers = 0.25,
    PoliceStorageGuns = 1.10,
    PrisonArmoryShotguns = 0.60,
    PrisonGuardLockers = 0.24,
    PrisonRiotStorage = 0.14,
    SecurityLockers = 0.18,
    SecurityStorage = 0.16,
    DeskGeneric = 0.003,
    DresserGeneric = 0.006,
    GarageFirearms = 0.015,
    GarageTools = 0.003,
    LivingRoomShelf = 0.002,
    LivingRoomShelfClassy = 0.001,
    LivingRoomShelfNoTapes = 0.001,
    LivingRoomShelfRedneck = 0.003,
    LivingRoomSideTable = 0.002,
    LivingRoomSideTableClassy = 0.001,
    LivingRoomSideTableNoRemote = 0.001,
    LivingRoomSideTableRedneck = 0.003,
    OfficeDeskHome = 0.003,
    OfficeDeskHomeClassy = 0.002,
    WardrobeGeneric = 0.002,
}

local function hasDistributionEntry(list, full_type)
    if not list or not list.items then
        return false
    end

    for i = 1, #list.items, 2 do
        if list.items[i] == full_type then
            return true
        end
    end

    return false
end

local function addDistributionEntry(list_name, full_type, weight)
    local list = ProceduralDistributions and ProceduralDistributions.list and ProceduralDistributions.list[list_name]
    if not list or not list.items or hasDistributionEntry(list, full_type) then
        return
    end

    table.insert(list.items, full_type)
    table.insert(list.items, weight)
end

local function applyProceduralDistributionWeights()
    if PROCEDURAL_APPLIED or not ProceduralDistributions or not ProceduralDistributions.list then
        return
    end

    PROCEDURAL_APPLIED = true

    for list_name, weight in pairs(PROCEDURAL_WEIGHTS) do
        addDistributionEntry(list_name, SUPPRESSOR_FULL_TYPE, weight)
    end
end

Events.OnPreDistributionMerge.Add(applyProceduralDistributionWeights)
