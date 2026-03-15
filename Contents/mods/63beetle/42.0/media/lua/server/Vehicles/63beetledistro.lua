local distributionTable = VehicleDistributions[1]

VehicleDistributions.BTL63loveBox = {
    rolls = 1,
    items = {
        "Base.63beetleMagazine", 50,
        "Base.Pen", 4,
        "Base.Pencil", 4,
        "Base.Cigarettes", 5,
        "Base.Lighter", 5,
        "Base.Matches", 3,
        "Base.Tissue", 2,
    },
    junk = ClutterTables.GloveBoxJunk,
}

VehicleDistributions.BTL63 = {

	GloveBox = VehicleDistributions.BTL63loveBox;
	BTL63Trunk = VehicleDistributions.TrunkHeavy;
	BTL63InnerTrunk = VehicleDistributions.GloveBox;
}

distributionTable["63beetle"] = { Normal = VehicleDistributions.BTL63; }
distributionTable["63beetleHP"] = { Normal = VehicleDistributions.BTL63; }
distributionTable["63beetleBuggy"] = { Normal = VehicleDistributions.BTL63; }