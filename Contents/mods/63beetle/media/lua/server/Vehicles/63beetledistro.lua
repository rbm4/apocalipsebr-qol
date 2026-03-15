local distributionTable = VehicleDistributions[1]

VehicleDistributions.BTL63 = {

	GloveBox = VehicleDistributions.GloveBox;
	BTL63Trunk = VehicleDistributions.TrunkHeavy;
	BTL63InnerTrunk = VehicleDistributions.GloveBox;
}

distributionTable["63beetle"] = { Normal = VehicleDistributions.BTL63; }
distributionTable["63beetleHP"] = { Normal = VehicleDistributions.BTL63; }
distributionTable["63beetleBuggy"] = { Normal = VehicleDistributions.BTL63; }