require "Items/ProceduralDistributions"
require "Items/SuburbsDistributions"

DrugzzLoot = DrugzzLoot or {}

local lootRequests = {}
local zombieLootItems = {}

local function optionMultiplier(name, fallback)
    if SandboxVars and SandboxVars.ZomboidDrugzz and SandboxVars.ZomboidDrugzz[name] ~= nil then
        return tonumber(SandboxVars.ZomboidDrugzz[name]) or fallback
    end
    return fallback
end

local function addLoot(items, locations)
    table.insert(lootRequests, {
        items = items,
        locations = locations,
    })
end

local function addZombieLoot(items)
    zombieLootItems = items
end

-- Ordinary personal storage: possible, but never a dependable supply.
addLoot({
    ["ZDrugzz.Joint"] = 0.08,
    ["ZDrugzz.CannabisGummies"] = 0.035,
    ["ZDrugzz.MollyCapsule"] = 0.018,
    ["ZDrugzz.EcstasyTablet"] = 0.018,
    ["ZDrugzz.AdderallBottle"] = 0.045,
}, {
    "BedroomDresser",
    "BedroomSidetable",
    "BathroomCabinet",
    "BathroomCounter",
})

-- Introductory cultivation knowledge.
addLoot({
    ["ZDrugzz.GrowersHandbook"] = 1.20,
}, {
    "BookstoreFarming",
    "BookstoreCrafts",
    "LibraryMagazines",
})

-- Generic seed stock belongs with gardening supplies, not on bookshelves.
addLoot({
    ["ZDrugzz.CannabisSeeds"] = 1.00,
}, {
    "CrateFarming",
    "CrateGardening",
    "GardenStoreMisc",
    "GigamartFarming",
    "ToolStoreFarming",
})

-- Fire-station lockers are a plausible place for an abandoned personal stash,
-- a lighter-duty smoking tool or portable heat equipment. These remain much
-- rarer than dedicated tobacco shops and drug-lab locations.
addLoot({
    ["ZDrugzz.Joint"] = 0.11,
    ["ZDrugzz.Blunt"] = 0.07,
    ["ZDrugzz.GlassPipe"] = 0.035,
    ["ZDrugzz.VapeBattery"] = 0.025,
    ["ZDrugzz.EmptyTHCCartridge"] = 0.020,
    ["ZDrugzz.PortableDabTorch"] = 0.012,
}, {
    "FireDeptLockers",
    "FireStorageTools",
    "FireStorageMechanics",
})

addLoot({
    ["ZDrugzz.MushroomSporePrint"] = 0.45,
}, {
    "LaboratoryLockers",
    "Chemistry",
    "TestingLab",
    "DrugLabSupplies",
    "DrugShackDrugs",
})

addLoot({
    ["ZDrugzz.CocaSeeds"] = 0.28,
}, {
    "CrateGardening",
    "GardenStoreMisc",
    "DrugLabSupplies",
    "DrugShackDrugs",
})

-- The report is literature; chemical components stay in science storage.
addLoot({
    ["ZDrugzz.StreetChemistryReport"] = 0.85,
}, {
    "BookstoreScience",
    "LibraryScience",
    "LaboratoryBooks",
    "PoliceEvidence",
})

addLoot({
    ["ZDrugzz.ChemicalPrecursor"] = 0.90,
    ["ZDrugzz.LabSolvent"] = 1.35,
    ["ZDrugzz.EmptyCapsules"] = 1.00,
}, {
    "LaboratoryLockers",
    "Chemistry",
    "ScienceMisc",
    "TestingLab",
    "UniversityStorageScience",
})

-- Drug labs and hideouts are the best finished-product containers.
addLoot({
    ["ZDrugzz.Joint"] = 0.85,
    ["ZDrugzz.MagicMushroomDried"] = 0.38,
    ["ZDrugzz.LSDTab"] = 0.16,
    ["ZDrugzz.CocaineBaggie"] = 0.42,
    ["ZDrugzz.CrackRock"] = 0.28,
    ["ZDrugzz.MethBaggie"] = 0.27,
    ["ZDrugzz.MollyCapsule"] = 0.34,
    ["ZDrugzz.EcstasyTablet"] = 0.34,
    ["ZDrugzz.AdderallBottle"] = 0.20,
    ["ZDrugzz.THCCartridge"] = 0.24,
    ["ZDrugzz.GlassPipe"] = 0.38,
}, {
    "DerelictHouseDrugs",
    "DrugLabSupplies",
    "DrugShackDrugs",
})

-- Confiscated evidence is worthwhile, but less productive than an active lab.
addLoot({
    ["ZDrugzz.Joint"] = 0.38,
    ["ZDrugzz.MagicMushroomDried"] = 0.18,
    ["ZDrugzz.LSDTab"] = 0.08,
    ["ZDrugzz.CocaineBaggie"] = 0.24,
    ["ZDrugzz.CrackRock"] = 0.16,
    ["ZDrugzz.MethBaggie"] = 0.14,
    ["ZDrugzz.MollyCapsule"] = 0.17,
    ["ZDrugzz.EcstasyTablet"] = 0.17,
    ["ZDrugzz.AdderallBottle"] = 0.12,
    ["ZDrugzz.THCCartridge"] = 0.12,
    ["ZDrugzz.GlassPipe"] = 0.20,
}, {
    "PoliceEvidence",
    "PoliceFileBox",
})

-- Medical storage is the reliable location for prescription stimulants.
addLoot({
    ["ZDrugzz.AdderallBottle"] = 0.48,
    ["ZDrugzz.EmptyCapsules"] = 0.70,
}, {
    "MedicalCabinet",
    "MedicalClinicDrugs",
    "MedicalStorageDrugs",
    "StoreShelfMedical",
})

-- Military medical and checkpoint-style storage can carry prescription
-- stimulants for long shifts and field readiness. These are intentionally
-- below dedicated pharmacy storage, but much better than random houses.
addLoot({
    ["ZDrugzz.AdderallBottle"] = 0.36,
    ["ZDrugzz.EmptyCapsules"] = 0.18,
}, {
    "ArmyStorageMedical",
    "ArmyBunkerMedical",
})

addLoot({
    ["ZDrugzz.AdderallBottle"] = 0.14,
}, {
    "ArmyStorageAmmunition",
    "ArmyStorageElectronics",
    "ArmyStorageGuns",
    "ArmyStorageOutfit",
    "ArmyHangarTools",
    "ArmyHangarOutfit",
    "ArmyBunkerLockers",
    "ArmyBunkerStorage",
})

-- Army surplus stores are mostly gear, not active field supplies, so this is
-- a very rare shelf/case find rather than a dependable pharmacy replacement.
addLoot({
    ["ZDrugzz.AdderallBottle"] = 0.055,
}, {
    "ArmySurplusCases",
    "ArmySurplusMisc",
    "ArmySurplusTools",
    "ArmySurplusSnacks",
    "ArmySurplusBackpacks",
})

addLoot({
    ["ZDrugzz.EmptyBaggie"] = 1.50,
}, {
    "StoreCounterBags",
    "StoreCounterBagsPaper",
    "DrugLabSupplies",
})

addLoot({
    ["ZDrugzz.LabSolvent"] = 0.55,
}, {
    "JanitorChemicals",
    "MorgueChemicals",
    "LaboratoryGasStorage",
    "DrugLabSupplies",
})

-- Advanced cultivation literature remains separate from physical seed stock.
addLoot({
    ["ZDrugzz.CannabisCultureManual"] = 0.70,
    ["ZDrugzz.CultivatorsAlmanac"] = 1.10,
}, {
    "BookstoreFarming",
    "BookstoreCrafts",
    "BookstoreScience",
    "LibraryMagazines",
    "LaboratoryBooks",
    "DrugLabSupplies",
})

-- Named seeds are uncommon enough to encourage trading and collecting.
addLoot({
    ["ZDrugzz.SourDieselSeeds"] = 0.42,
    ["ZDrugzz.DurbanPoisonSeeds"] = 0.34,
    ["ZDrugzz.JackHererSeeds"] = 0.38,
    ["ZDrugzz.NorthernLightsSeeds"] = 0.45,
    ["ZDrugzz.GranddaddyPurpleSeeds"] = 0.30,
    ["ZDrugzz.BubbaKushSeeds"] = 0.34,
    ["ZDrugzz.OGKushSeeds"] = 0.38,
    ["ZDrugzz.WhiteWidowSeeds"] = 0.34,
    ["ZDrugzz.BlueDreamSeeds"] = 0.38,
    ["ZDrugzz.GSCSeeds"] = 0.28,
}, {
    "CrateGardening",
    "GardenStoreMisc",
    "GigamartFarming",
    "DrugLabSupplies",
    "DrugShackDrugs",
})

addLoot({
    ["ZDrugzz.CannabisKitchenCookbook"] = 1.00,
}, {
    "BookstoreCooking",
    "BookstoreCrafts",
    "KitchenBook",
    "LibraryMagazines",
    "MagazineRackMixed",
})

addLoot({
    ["ZDrugzz.ConcentrateExtractionManual"] = 0.70,
}, {
    "BookstoreCrafts",
    "BookstoreScience",
    "LibraryScience",
    "LaboratoryBooks",
    "LaboratoryLockers",
    "DrugLabSupplies",
    "DrugShackDrugs",
})

addLoot({
    ["ZDrugzz.RigServiceManual"] = 0.65,
}, {
    "BookstoreCrafts",
    "ElectronicStoreMagazines",
    "LibraryMagazines",
    "ToolStoreBooks",
    "CrateElectronics",
    "GarageTools",
    "DrugLabSupplies",
})

addLoot({
    ["ZDrugzz.ControlledBotanicalsNotes"] = 0.80,
}, {
    "BookstoreFarming",
    "BookstoreScience",
    "LibraryScience",
    "LaboratoryBooks",
    "CrateFarming",
    "CrateGardening",
    "DrugLabSupplies",
})

-- Tobacco counters carry basic consumption hardware; contraband locations
-- remain the better source for expensive rigs and filled cartridges.
addLoot({
    ["ZDrugzz.GlassBong"] = 0.55,
    ["ZDrugzz.DabRig"] = 0.16,
    ["ZDrugzz.PortableDabTorch"] = 0.24,
    ["ZDrugzz.ElectronicDabRig"] = 0.055,
    ["ZDrugzz.ERigBattery"] = 0.18,
    ["ZDrugzz.DabTool"] = 0.42,
    ["ZDrugzz.VapeBattery"] = 0.48,
    ["ZDrugzz.EmptyTHCCartridge"] = 0.58,
    ["ZDrugzz.THCCartridge"] = 0.14,
}, {
    "StoreCounterTobacco",
})

addLoot({
    ["ZDrugzz.GlassBong"] = 0.70,
    ["ZDrugzz.DabRig"] = 0.38,
    ["ZDrugzz.PortableDabTorch"] = 0.42,
    ["ZDrugzz.ElectronicDabRig"] = 0.11,
    ["ZDrugzz.ERigBattery"] = 0.30,
    ["ZDrugzz.DabTool"] = 0.62,
    ["ZDrugzz.VapeBattery"] = 0.48,
    ["ZDrugzz.EmptyTHCCartridge"] = 0.65,
    ["ZDrugzz.THCCartridge"] = 0.25,
}, {
    "DerelictHouseDrugs",
    "DrugLabSupplies",
    "DrugShackDrugs",
    "PoliceEvidence",
})

-- Mechanical extraction equipment belongs in garages and laboratories.
addLoot({
    ["ZDrugzz.RosinPress"] = 0.18,
    ["ZDrugzz.ExtractionTube"] = 0.34,
    ["ZDrugzz.DistillationKit"] = 0.24,
    ["ZDrugzz.FoodGradeSolvent"] = 0.72,
}, {
    "GarageMetalwork",
    "LaboratoryLockers",
    "Chemistry",
    "TestingLab",
    "DrugLabSupplies",
})

-- Heating hardware and small tools belong in tool storage.
addLoot({
    ["ZDrugzz.PortableDabTorch"] = 0.30,
    ["ZDrugzz.EmptyPortableDabTorch"] = 0.18,
    ["ZDrugzz.DabTool"] = 0.42,
}, {
    "GarageTools",
    "GarageMetalwork",
    "ToolStoreTools",
    "LaboratoryLockers",
    "DrugLabSupplies",
})

-- Electronic rigs and batteries belong with electronics or contraband gear.
addLoot({
    ["ZDrugzz.ElectronicDabRig"] = 0.065,
    ["ZDrugzz.ERigBattery"] = 0.26,
    ["ZDrugzz.EmptyERigBattery"] = 0.16,
}, {
    "CrateElectronics",
    "ElectronicStoreMisc",
    "DrugLabSupplies",
    "DrugShackDrugs",
})

addLoot({
    ["ZDrugzz.Kief"] = 0.25,
    ["ZDrugzz.Hash"] = 0.20,
    ["ZDrugzz.Rosin"] = 0.14,
    ["ZDrugzz.Shatter"] = 0.10,
    ["ZDrugzz.LiveResin"] = 0.085,
    ["ZDrugzz.DistillateSyringe"] = 0.075,
    ["ZDrugzz.SpaceCookie"] = 0.20,
    ["ZDrugzz.CannabisGummies"] = 0.18,
}, {
    "DerelictHouseDrugs",
    "DrugLabSupplies",
    "DrugShackDrugs",
})

addLoot({
    ["ZDrugzz.Kief"] = 0.12,
    ["ZDrugzz.Hash"] = 0.10,
    ["ZDrugzz.Rosin"] = 0.065,
    ["ZDrugzz.Shatter"] = 0.045,
    ["ZDrugzz.LiveResin"] = 0.04,
    ["ZDrugzz.DistillateSyringe"] = 0.035,
    ["ZDrugzz.SpaceCookie"] = 0.10,
    ["ZDrugzz.CannabisGummies"] = 0.09,
}, {
    "PoliceEvidence",
})

-- Fresh and actively growing products only appear around operating grow
-- spaces and their refrigeration. These weights are intentionally tiny.
addLoot({
    ["ZDrugzz.CannabisHarvest"] = 0.10,
    ["ZDrugzz.CannabisBudFresh"] = 0.08,
    ["ZDrugzz.SourDieselHarvest"] = 0.035,
    ["ZDrugzz.DurbanPoisonHarvest"] = 0.030,
    ["ZDrugzz.JackHererHarvest"] = 0.032,
    ["ZDrugzz.NorthernLightsHarvest"] = 0.038,
    ["ZDrugzz.GranddaddyPurpleHarvest"] = 0.026,
    ["ZDrugzz.BubbaKushHarvest"] = 0.030,
    ["ZDrugzz.OGKushHarvest"] = 0.032,
    ["ZDrugzz.WhiteWidowHarvest"] = 0.030,
    ["ZDrugzz.BlueDreamHarvest"] = 0.032,
    ["ZDrugzz.GSCHarvest"] = 0.024,
    ["ZDrugzz.MagicMushroomFresh"] = 0.060,
    ["ZDrugzz.CocaLeaves"] = 0.055,
}, {
    "FridgeDrugLab",
})

addLoot({
    ["ZDrugzz.MushroomGrowKit"] = 0.025,
    ["ZDrugzz.CocaNursery"] = 0.014,
}, {
    "DrugLabSupplies",
    "DrugShackTools",
})

-- Cured flower can be found loose in active contraband locations and, much
-- more rarely, among confiscated evidence.
addLoot({
    ["ZDrugzz.CannabisBudDried"] = 0.22,
    ["ZDrugzz.GroundCannabis"] = 0.12,
    ["ZDrugzz.SourDieselBudDried"] = 0.075,
    ["ZDrugzz.DurbanPoisonBudDried"] = 0.065,
    ["ZDrugzz.JackHererBudDried"] = 0.070,
    ["ZDrugzz.NorthernLightsBudDried"] = 0.080,
    ["ZDrugzz.GranddaddyPurpleBudDried"] = 0.055,
    ["ZDrugzz.BubbaKushBudDried"] = 0.060,
    ["ZDrugzz.OGKushBudDried"] = 0.070,
    ["ZDrugzz.WhiteWidowBudDried"] = 0.065,
    ["ZDrugzz.BlueDreamBudDried"] = 0.070,
    ["ZDrugzz.GSCBudDried"] = 0.050,
}, {
    "DrugLabSupplies",
    "DrugShackDrugs",
})

addLoot({
    ["ZDrugzz.CannabisBudDried"] = 0.10,
    ["ZDrugzz.GroundCannabis"] = 0.050,
    ["ZDrugzz.SourDieselBudDried"] = 0.032,
    ["ZDrugzz.DurbanPoisonBudDried"] = 0.028,
    ["ZDrugzz.JackHererBudDried"] = 0.030,
    ["ZDrugzz.NorthernLightsBudDried"] = 0.034,
    ["ZDrugzz.GranddaddyPurpleBudDried"] = 0.024,
    ["ZDrugzz.BubbaKushBudDried"] = 0.026,
    ["ZDrugzz.OGKushBudDried"] = 0.030,
    ["ZDrugzz.WhiteWidowBudDried"] = 0.028,
    ["ZDrugzz.BlueDreamBudDried"] = 0.030,
    ["ZDrugzz.GSCBudDried"] = 0.022,
}, {
    "PoliceEvidence",
})

-- Finished rolled cannabis and packed bongs remain specialist contraband.
addLoot({
    ["ZDrugzz.Blunt"] = 0.16,
    ["ZDrugzz.SourDieselJoint"] = 0.075,
    ["ZDrugzz.DurbanPoisonJoint"] = 0.065,
    ["ZDrugzz.JackHererJoint"] = 0.070,
    ["ZDrugzz.NorthernLightsJoint"] = 0.080,
    ["ZDrugzz.GranddaddyPurpleJoint"] = 0.055,
    ["ZDrugzz.BubbaKushJoint"] = 0.060,
    ["ZDrugzz.OGKushJoint"] = 0.070,
    ["ZDrugzz.WhiteWidowJoint"] = 0.065,
    ["ZDrugzz.BlueDreamJoint"] = 0.070,
    ["ZDrugzz.GSCJoint"] = 0.050,
    ["ZDrugzz.KiefJoint"] = 0.060,
    ["ZDrugzz.HashJoint"] = 0.050,
    ["ZDrugzz.PackedBongSativa"] = 0.018,
    ["ZDrugzz.PackedBongIndica"] = 0.018,
    ["ZDrugzz.PackedBongHybrid"] = 0.018,
}, {
    "DrugLabSupplies",
    "DrugShackDrugs",
})

addLoot({
    ["ZDrugzz.Blunt"] = 0.070,
    ["ZDrugzz.SourDieselJoint"] = 0.032,
    ["ZDrugzz.DurbanPoisonJoint"] = 0.028,
    ["ZDrugzz.JackHererJoint"] = 0.030,
    ["ZDrugzz.NorthernLightsJoint"] = 0.034,
    ["ZDrugzz.GranddaddyPurpleJoint"] = 0.024,
    ["ZDrugzz.BubbaKushJoint"] = 0.026,
    ["ZDrugzz.OGKushJoint"] = 0.030,
    ["ZDrugzz.WhiteWidowJoint"] = 0.028,
    ["ZDrugzz.BlueDreamJoint"] = 0.030,
    ["ZDrugzz.GSCJoint"] = 0.022,
    ["ZDrugzz.KiefJoint"] = 0.025,
    ["ZDrugzz.HashJoint"] = 0.022,
    ["ZDrugzz.PackedBongSativa"] = 0.008,
    ["ZDrugzz.PackedBongIndica"] = 0.008,
    ["ZDrugzz.PackedBongHybrid"] = 0.008,
}, {
    "PoliceEvidence",
})

-- Infused cooking ingredients and perishable edibles belong in a drug-lab
-- refrigerator, with a smaller chance in an active hideout.
addLoot({
    ["ZDrugzz.Cannabutter"] = 0.10,
    ["ZDrugzz.CannabisOil"] = 0.075,
    ["ZDrugzz.WeedBrownie"] = 0.15,
}, {
    "FridgeDrugLab",
})

addLoot({
    ["ZDrugzz.Cannabutter"] = 0.045,
    ["ZDrugzz.CannabisOil"] = 0.035,
    ["ZDrugzz.WeedBrownie"] = 0.075,
}, {
    "DrugLabSupplies",
    "DrugShackDrugs",
})

-- Processing intermediates are not ordinary consumer loot.
addLoot({
    ["ZDrugzz.CocaPaste"] = 0.055,
    ["ZDrugzz.MDMAPowder"] = 0.040,
}, {
    "DrugLabSupplies",
    "DrugShackDrugs",
})

addLoot({
    ["ZDrugzz.CocaPaste"] = 0.025,
    ["ZDrugzz.MDMAPowder"] = 0.018,
}, {
    "PoliceEvidence",
})

-- Preloaded devices represent abandoned personal setups or confiscated
-- evidence. Electronic rigs are the rarest entries in the entire pool.
addLoot({
    ["ZDrugzz.CrackPipe"] = 0.022,
    ["ZDrugzz.MethPipe"] = 0.020,
    ["ZDrugzz.LoadedDabRigRosin"] = 0.012,
    ["ZDrugzz.LoadedDabRigShatter"] = 0.010,
    ["ZDrugzz.LoadedDabRigLiveResin"] = 0.009,
    ["ZDrugzz.LoadedDabRigDistillate"] = 0.008,
    ["ZDrugzz.ElectronicDabRigRosin"] = 0.005,
    ["ZDrugzz.ElectronicDabRigShatter"] = 0.004,
    ["ZDrugzz.ElectronicDabRigLiveResin"] = 0.004,
    ["ZDrugzz.ElectronicDabRigDistillate"] = 0.003,
}, {
    "DrugLabSupplies",
    "DrugShackDrugs",
})

addLoot({
    ["ZDrugzz.CrackPipe"] = 0.012,
    ["ZDrugzz.MethPipe"] = 0.010,
    ["ZDrugzz.LoadedDabRigRosin"] = 0.006,
    ["ZDrugzz.LoadedDabRigShatter"] = 0.005,
    ["ZDrugzz.LoadedDabRigLiveResin"] = 0.004,
    ["ZDrugzz.LoadedDabRigDistillate"] = 0.004,
    ["ZDrugzz.ElectronicDabRigRosin"] = 0.002,
    ["ZDrugzz.ElectronicDabRigShatter"] = 0.002,
    ["ZDrugzz.ElectronicDabRigLiveResin"] = 0.002,
    ["ZDrugzz.ElectronicDabRigDistillate"] = 0.001,
}, {
    "PoliceEvidence",
})

-- About 0.55% combined at default settings against vanilla's approximately
-- 90 points of corpse-pocket loot: roughly one finished drug per 170-200
-- ordinary zombies, with hard drugs individually much rarer.
addZombieLoot({
    ["ZDrugzz.Joint"] = 0.150,
    ["ZDrugzz.THCCartridge"] = 0.035,
    ["ZDrugzz.CannabisGummies"] = 0.035,
    ["ZDrugzz.SpaceCookie"] = 0.030,
    ["ZDrugzz.MagicMushroomDried"] = 0.040,
    ["ZDrugzz.LSDTab"] = 0.015,
    ["ZDrugzz.CocaineBaggie"] = 0.040,
    ["ZDrugzz.CrackRock"] = 0.020,
    ["ZDrugzz.MethBaggie"] = 0.025,
    ["ZDrugzz.MollyCapsule"] = 0.040,
    ["ZDrugzz.EcstasyTablet"] = 0.040,
    ["ZDrugzz.AdderallBottle"] = 0.060,
})

local function insertPairOnce(items, itemType, weight)
    for index = 1, #items, 2 do
        if items[index] == itemType then
            items[index + 1] = math.max(tonumber(items[index + 1]) or 0, weight)
            return false
        end
    end
    table.insert(items, itemType)
    table.insert(items, weight)
    return true
end

local function applyProceduralLoot()
    if DrugzzLoot.proceduralApplied then
        return
    end

    local multiplier = optionMultiplier("LootMultiplier", 1.0)
    if multiplier <= 0 then
        DrugzzLoot.proceduralApplied = true
        print("[ZomboidDrugzz] World-container loot disabled by sandbox settings.")
        return
    end

    local inserted = 0
    local missing = 0
    for _, request in ipairs(lootRequests) do
        for _, location in ipairs(request.locations) do
            local distribution = ProceduralDistributions
                and ProceduralDistributions.list
                and ProceduralDistributions.list[location]
                or nil
            if distribution and distribution.items then
                for itemType, weight in pairs(request.items) do
                    if insertPairOnce(distribution.items, itemType, weight * multiplier) then
                        inserted = inserted + 1
                    end
                end
            else
                missing = missing + 1
            end
        end
    end

    DrugzzLoot.proceduralApplied = true
    print(string.format(
        "[ZomboidDrugzz] Applied %d world-loot entries at %.2fx (%d unavailable distribution references).",
        inserted,
        multiplier,
        missing
    ))
end

local function applyZombieLoot()
    if DrugzzLoot.zombieApplied then
        return
    end

    local multiplier = optionMultiplier("ZombieLootMultiplier", 1.0)
    if multiplier <= 0 then
        DrugzzLoot.zombieApplied = true
        print("[ZomboidDrugzz] Zombie pocket loot disabled by sandbox settings.")
        return
    end

    if not SuburbsDistributions or not SuburbsDistributions.all then
        return
    end

    local inserted = 0
    for _, inventoryType in ipairs({ "inventoryfemale", "inventorymale" }) do
        local distribution = SuburbsDistributions.all[inventoryType]
        if distribution and distribution.items then
            for itemType, weight in pairs(zombieLootItems) do
                if insertPairOnce(distribution.items, itemType, weight * multiplier) then
                    inserted = inserted + 1
                end
            end
        end
    end

    DrugzzLoot.zombieApplied = true
    print(string.format(
        "[ZomboidDrugzz] Applied %d zombie-loot entries at %.2fx.",
        inserted,
        multiplier
    ))
end

-- Build 42 merges distribution data after server Lua files are loaded.
-- Registering at the supported merge events keeps sandbox multipliers current
-- and ensures the Java item picker sees the final tables in SP, host and
-- dedicated-server games.
if Events and Events.OnPreDistributionMerge then
    Events.OnPreDistributionMerge.Add(applyProceduralLoot)
end
if Events and Events.OnPostDistributionMerge then
    Events.OnPostDistributionMerge.Add(applyZombieLoot)
end

-- Singleplayer and listen-host games do not consistently fire the dedicated
-- server pre-merge path, so apply the procedural table during load as well.
if not (isServer and isServer()) then
    applyProceduralLoot()
end

local fallbackPools = {
    personal = {
        ["ZDrugzz.Joint"] = 55,
        ["ZDrugzz.Blunt"] = 18,
        ["ZDrugzz.CannabisGummies"] = 8,
        ["ZDrugzz.AdderallBottle"] = 8,
        ["ZDrugzz.MagicMushroomDried"] = 4,
        ["ZDrugzz.MollyCapsule"] = 2,
        ["ZDrugzz.EcstasyTablet"] = 2,
        ["ZDrugzz.CocaineBaggie"] = 1.5,
        ["ZDrugzz.MethBaggie"] = 0.8,
        ["ZDrugzz.CrackRock"] = 0.6,
        ["ZDrugzz.LSDTab"] = 0.3,
    },
    books = {
        ["ZDrugzz.GrowersHandbook"] = 16,
        ["ZDrugzz.CannabisCultureManual"] = 15,
        ["ZDrugzz.CultivatorsAlmanac"] = 14,
        ["ZDrugzz.CannabisKitchenCookbook"] = 13,
        ["ZDrugzz.ConcentrateExtractionManual"] = 11,
        ["ZDrugzz.RigServiceManual"] = 10,
        ["ZDrugzz.StreetChemistryReport"] = 7,
        ["ZDrugzz.ControlledBotanicalsNotes"] = 5,
    },
    farming = {
        ["ZDrugzz.CannabisSeeds"] = 70,
        ["ZDrugzz.MushroomSporePrint"] = 20,
        ["ZDrugzz.CocaSeeds"] = 10,
    },
    medical = {
        ["ZDrugzz.AdderallBottle"] = 62,
        ["ZDrugzz.EmptyCapsules"] = 22,
        ["ZDrugzz.MollyCapsule"] = 5,
        ["ZDrugzz.EcstasyTablet"] = 4,
        ["ZDrugzz.DistillateSyringe"] = 4,
        ["ZDrugzz.ChemicalPrecursor"] = 3,
    },
    military_medical = {
        ["ZDrugzz.AdderallBottle"] = 78,
        ["ZDrugzz.EmptyCapsules"] = 16,
        ["ZDrugzz.Joint"] = 3,
        ["ZDrugzz.CannabisGummies"] = 2,
        ["ZDrugzz.MollyCapsule"] = 1,
    },
    military_general = {
        ["ZDrugzz.AdderallBottle"] = 82,
        ["ZDrugzz.Joint"] = 9,
        ["ZDrugzz.CannabisGummies"] = 5,
        ["ZDrugzz.EmptyCapsules"] = 4,
    },
    army_surplus = {
        ["ZDrugzz.AdderallBottle"] = 72,
        ["ZDrugzz.Joint"] = 14,
        ["ZDrugzz.CannabisGummies"] = 8,
        ["ZDrugzz.EmptyCapsules"] = 6,
    },
    police = {
        ["ZDrugzz.Joint"] = 28,
        ["ZDrugzz.CannabisGummies"] = 10,
        ["ZDrugzz.CocaineBaggie"] = 13,
        ["ZDrugzz.MethBaggie"] = 9,
        ["ZDrugzz.CrackRock"] = 7,
        ["ZDrugzz.MollyCapsule"] = 7,
        ["ZDrugzz.EcstasyTablet"] = 7,
        ["ZDrugzz.MagicMushroomDried"] = 6,
        ["ZDrugzz.LSDTab"] = 3,
        ["ZDrugzz.CrackPipe"] = 2,
        ["ZDrugzz.MethPipe"] = 2,
    },
    fire = {
        ["ZDrugzz.Joint"] = 43,
        ["ZDrugzz.Blunt"] = 22,
        ["ZDrugzz.GlassPipe"] = 10,
        ["ZDrugzz.VapeBattery"] = 8,
        ["ZDrugzz.EmptyTHCCartridge"] = 7,
        ["ZDrugzz.PortableDabTorch"] = 4,
        ["ZDrugzz.CannabisGummies"] = 4,
        ["ZDrugzz.AdderallBottle"] = 2,
    },
    tobacco = {
        ["ZDrugzz.Joint"] = 32,
        ["ZDrugzz.Blunt"] = 22,
        ["ZDrugzz.GlassPipe"] = 12,
        ["ZDrugzz.GlassBong"] = 8,
        ["ZDrugzz.VapeBattery"] = 9,
        ["ZDrugzz.EmptyTHCCartridge"] = 8,
        ["ZDrugzz.DabRig"] = 3,
        ["ZDrugzz.PortableDabTorch"] = 3,
        ["ZDrugzz.ElectronicDabRig"] = 1,
        ["ZDrugzz.ERigBattery"] = 2,
    },
    laboratory = {
        ["ZDrugzz.ChemicalPrecursor"] = 18,
        ["ZDrugzz.LabSolvent"] = 18,
        ["ZDrugzz.FoodGradeSolvent"] = 12,
        ["ZDrugzz.EmptyBaggie"] = 9,
        ["ZDrugzz.EmptyCapsules"] = 7,
        ["ZDrugzz.CannabisSeeds"] = 6,
        ["ZDrugzz.MushroomSporePrint"] = 5,
        ["ZDrugzz.CocaSeeds"] = 4,
        ["ZDrugzz.DabTool"] = 4,
        ["ZDrugzz.ExtractionTube"] = 3,
        ["ZDrugzz.DistillationKit"] = 2,
        ["ZDrugzz.RosinPress"] = 1,
        ["ZDrugzz.CocaineBaggie"] = 3,
        ["ZDrugzz.MethBaggie"] = 3,
        ["ZDrugzz.CrackRock"] = 2,
        ["ZDrugzz.MollyCapsule"] = 2,
        ["ZDrugzz.LSDTab"] = 1,
    },
    zombie = zombieLootItems,
}

local fallbackProfiles = {}

local function profile(names, chance, pool, cap)
    for _, name in ipairs(names) do
        fallbackProfiles[name] = {
            chance = chance,
            pool = fallbackPools[pool],
            cap = cap or 70,
        }
    end
end

profile({
    "BedroomDresser", "BedroomDresserClassy", "BedroomSidetable",
    "BedroomSidetableClassy", "BathroomCabinet", "BathroomCounter",
    "Nightstand", "Dresser", "EndTable", "MotelSideTable",
}, 1.0, "personal", 20)

profile({
    "BookstoreBooks", "BookstoreCrafts", "BookstoreFarming",
    "BookstoreScience", "BookstoreCooking", "BookstoreOutdoors",
    "BookstoreHobbies", "BookstoreMisc", "LibraryBooks",
    "LibraryMagazines", "LibraryScience", "LaboratoryBooks",
}, 8.0, "books", 45)

profile({
    "CrateFarming", "CrateGardening", "GardenStoreMisc",
    "GigamartFarming", "ToolStoreFarming",
}, 6.0, "farming", 40)

profile({
    "MedicalCabinet", "MedicalClinicDrugs", "MedicalStorageDrugs",
    "MedicalClinicTools", "MedicalStorageTools", "MedicalOfficeCounter",
}, 5.0, "medical", 35)

profile({
    "ArmyStorageMedical", "ArmyBunkerMedical",
}, 7.5, "military_medical", 45)

profile({
    "ArmyStorageAmmunition", "ArmyStorageElectronics", "ArmyStorageGuns",
    "ArmyStorageOutfit", "ArmyHangarTools", "ArmyHangarOutfit",
    "ArmyBunkerLockers", "ArmyBunkerStorage",
}, 3.0, "military_general", 28)

profile({
    "ArmySurplusCases", "ArmySurplusMisc", "ArmySurplusTools",
    "ArmySurplusSnacks", "ArmySurplusBackpacks",
}, 1.25, "army_surplus", 15)

profile({
    "PoliceEvidence", "PoliceFileBox", "PoliceDesk",
    "PoliceFilingCabinet", "PoliceCaptainCabinet", "PoliceCaptainDesk",
}, 4.0, "police", 30)

profile({
    "FireDeptLockers", "FireStorageTools", "FireStorageMechanics",
    "FiremanTools",
}, 2.0, "fire", 18)

profile({ "StoreCounterTobacco" }, 10.0, "tobacco", 60)

profile({
    "DrugLabSupplies", "DrugShackDrugs", "DrugShackTools",
    "FridgeDrugLab", "FreezerDrugLab", "LaboratoryLockers",
    "Chemistry", "TestingLab",
}, 35.0, "laboratory", 85)

profile({ "inventoryfemale", "inventorymale" }, 0.25, "zombie", 8)

local processedContainers = {}

local function containerKey(container)
    if not container then
        return nil
    end
    local parent = container.getParent and container:getParent() or nil
    local square = parent and parent.getSquare and parent:getSquare() or nil
    if square then
        return string.format(
            "%d:%d:%d:%s",
            square:getX(),
            square:getY(),
            square:getZ(),
            tostring(container.getType and container:getType() or "")
        )
    end
    return tostring(container)
end

local function hasDrugzzItem(container)
    local items = container and container.getItems and container:getItems() or nil
    if not items then
        return false
    end
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        local fullType = item and item.getFullType and item:getFullType() or ""
        if string.sub(fullType, 1, 8) == "ZDrugzz." then
            return true
        end
    end
    return false
end

local function weightedItem(pool)
    local total = 0
    for _, weight in pairs(pool or {}) do
        total = total + math.max(0, tonumber(weight) or 0)
    end
    if total <= 0 then
        return nil
    end

    local roll = ZombRandFloat(0, total)
    for itemType, weight in pairs(pool) do
        roll = roll - math.max(0, tonumber(weight) or 0)
        if roll <= 0 then
            return itemType
        end
    end
    return nil
end

local function onFillContainer(_, containerType, container)
    if isClient and isClient() and not (isServer and isServer()) then
        return
    end

    local profileData = fallbackProfiles[containerType]
    if not profileData or not container then
        return
    end

    local key = containerKey(container)
    if key and processedContainers[key] then
        return
    end
    if key then
        processedContainers[key] = true
    end

    local parent = container.getParent and container:getParent() or nil
    local modData = parent and parent.getModData and parent:getModData() or nil
    local rollKey = "ZomboidDrugzzLootRoll_" .. tostring(containerType)
    if modData and modData[rollKey] then
        return
    end
    if modData then
        modData[rollKey] = true
    end

    -- The normal procedural table gets first refusal. The safety net only
    -- rolls when it produced no mod item, preventing doubled specialist loot.
    if hasDrugzzItem(container) then
        return
    end

    local multiplierName = (containerType == "inventoryfemale" or containerType == "inventorymale")
        and "ZombieLootMultiplier"
        or "LootMultiplier"
    local multiplier = optionMultiplier(multiplierName, 1.0)
    if multiplier <= 0 then
        return
    end

    local chance = math.min(profileData.cap, profileData.chance * multiplier)
    if ZombRandFloat(0, 100) >= chance then
        return
    end

    local itemType = weightedItem(profileData.pool)
    if itemType and container.AddItem then
        container:AddItem(itemType)
    end
end

if Events and Events.OnFillContainer then
    Events.OnFillContainer.Add(onFillContainer)
end

-- If a loader reaches map-zone setup without firing one of the merge hooks,
-- make one last idempotent attempt before gameplay begins.
local function onLoadedMapZones()
    applyProceduralLoot()
    applyZombieLoot()
end

if Events and Events.OnLoadedMapZones then
    Events.OnLoadedMapZones.Add(onLoadedMapZones)
end

DrugzzLoot.applyProceduralLoot = applyProceduralLoot
DrugzzLoot.applyZombieLoot = applyZombieLoot
DrugzzLoot.onFillContainer = onFillContainer
