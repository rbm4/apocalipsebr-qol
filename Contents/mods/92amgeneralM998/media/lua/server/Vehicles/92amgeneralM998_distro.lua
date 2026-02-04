local distributionTable = VehicleDistributions[1]

VehicleDistributions.M998gunrack = {
    rolls = 1,
    items = {
    	"Shotgun", 130,
    }
}

VehicleDistributions.M998 = {

	GloveBox = VehicleDistributions.GloveBox;
	M998Trunk = VehicleDistributions.TrunkHeavy;
    DAMNGunrack = VehicleDistributions.M998gunrack;
}

VehicleDistributions.M101A3 = {

	M101A3Trunk = VehicleDistributions.TrunkHeavy;
}

distributionTable["92amgeneralM998"] = { Normal = VehicleDistributions.M998; }
distributionTable["92amgeneralM998Burnt"] = { Normal = VehicleDistributions.M998; }
distributionTable["TrailerM101A3cargo"] = { Normal = VehicleDistributions.M101A3; }