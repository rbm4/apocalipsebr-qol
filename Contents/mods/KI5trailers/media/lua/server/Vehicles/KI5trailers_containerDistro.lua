local distributionTable = VehicleDistributions[1]

VehicleDistributions.KI5TRTools = {
    rolls = 3,
    items = {
        "Axe", 0.05,
        "BallPeenHammer", 6,
        "ClubHammer", 4,
        "Crowbar", 4,
        "farming.HandShovel", 10,
        "GardenFork", 1,
        "GardenHoe", 2,
        "GardenSaw", 10,
        "Hammer", 8,
        "HandAxe", 1,
        "HandFork", 1,
        "HandScythe", 1,
        "LeafRake", 10,
        "LugWrench", 6,
        "Machete", 0.01,
        "PickAxe", 0.5,
        "PipeWrench", 6,
        "Rake", 10,
        "Rope", 8,
        "Saw", 8,
        "Screwdriver", 10,
        "Shovel", 4,
        "Shovel2", 4,
        "Sledgehammer", 0.01,
        "Sledgehammer2", 0.01,
        "SnowShovel", 2,
        "TirePump", 6,
        "WoodAxe", 0.025,
        "WoodenMallet", 4,
        "Wrench", 6,
    }
}

VehicleDistributions.KI5TRStandard = {

	KI5TRTrunk = VehicleDistributions.TrunkStandard;
    KI5TRToolBox = VehicleDistributions.KI5TRTools;
}

VehicleDistributions.KI5TRHeavy = {

	KI5TRTrunk = VehicleDistributions.TrunkHeavy;
    KI5TRToolBox = VehicleDistributions.KI5TRTools;
}

VehicleDistributions.KI5TRCStandard = {

	KI5TRCLTrunk = VehicleDistributions.TrunkHeavy;
    KI5TRCMTrunk = VehicleDistributions.TrunkStandard;
    KI5TRCSTrunk = VehicleDistributions.TrunkStandard;

}

distributionTable["TrailerKI5utilityLarge"] = { Normal = VehicleDistributions.KI5TRHeavy; }
distributionTable["TrailerKI5utilityMedium"] = { Normal = VehicleDistributions.KI5TRStandard; }
distributionTable["TrailerKI5utilitySmall"] = { Normal = VehicleDistributions.KI5TRStandard; }
distributionTable["TrailerKI5cargoLarge"] = { Normal = VehicleDistributions.KI5TRCStandard; }
distributionTable["TrailerKI5cargoMedium"] = { Normal = VehicleDistributions.KI5TRCStandard; }
distributionTable["TrailerKI5cargoSmall"] = { Normal = VehicleDistributions.KI5TRCStandard; }