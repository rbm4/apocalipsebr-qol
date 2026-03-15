local distributionTable = VehicleDistributions[1]

VehicleDistributions.STP85gunrack = {
    rolls = 6,
    items = {
    	"Base.Shotgun", 100,
        "Base.Shotgun", 105,
        "Base.Shotgun", 110,
        "Base.Shotgun", 115,
        "Base.Shotgun", 120,
        "Base.Shotgun", 125,
    }
}

VehicleDistributions.STP85 = {

	GloveBox = VehicleDistributions.GloveBox;
	STP85Trunk1 = VehicleDistributions.TrunkHeavy;
	STP85Roofrack = VehicleDistributions.GloveBox;
}

VehicleDistributions.STP85SWAT = {

	GloveBox = VehicleDistributions.PoliceGloveBox;
	STP85Trunk1 = VehicleDistributions.PoliceTruckBed;
    DAMNGunrack = VehicleDistributions.STP85gunrack;
	STP85Roofrack = VehicleDistributions.PoliceGloveBox;
}

distributionTable["85chevyStepVan"] = { Normal = VehicleDistributions.STP85; }
distributionTable["85chevyStepVanSWAT"] = { Normal = VehicleDistributions.STP85SWAT; }