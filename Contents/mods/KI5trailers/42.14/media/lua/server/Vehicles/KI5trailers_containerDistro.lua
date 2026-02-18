local distributionTable = VehicleDistributions[1]

VehicleDistributions.KI5TRTools = {
    rolls = 3,
    items = {
        "Base.Axe", 0.05,
        "Base.BallPeenHammer", 6,
        "Base.ClubHammer", 4,
        "Base.Crowbar", 4,
        "Base.farming.HandShovel", 10,
        "Base.GardenFork", 1,
        "Base.GardenHoe", 2,
        "Base.GardenSaw", 10,
        "Base.Hammer", 8,
        "Base.HandAxe", 1,
        "Base.HandFork", 1,
        "Base.HandScythe", 1,
        "Base.LeafRake", 10,
        "Base.LugWrench", 6,
        "Base.Machete", 0.01,
        "Base.PickAxe", 0.5,
        "Base.PipeWrench", 6,
        "Base.Rake", 10,
        "Base.Rope", 8,
        "Base.Saw", 8,
        "Base.Screwdriver", 10,
        "Base.Shovel", 4,
        "Base.Shovel2", 4,
        "Base.Sledgehammer", 0.01,
        "Base.Sledgehammer2", 0.01,
        "Base.SnowShovel", 2,
        "Base.TirePump", 6,
        "Base.WoodAxe", 0.025,
        "Base.WoodenMallet", 4,
        "Base.Wrench", 6,
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