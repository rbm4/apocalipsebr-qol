local distributionTable = VehicleDistributions[1]

VehicleDistributions.M998GloveBox = {
    rolls = 1,
    items = {
        "Base.92amgeneralM998Magazine", 60,
        "Base.Pen", 4,
        "Base.Pencil", 4,
        "Base.Cigarettes", 5,
        "Base.Lighter", 5,
        "Base.Matches", 3,
        "Base.Tissue", 2,
    },
    junk = ClutterTables.GloveBoxJunk,
}

VehicleDistributions.M998gunrack = {
    rolls = 1,
    items = {
    	"Base.Shotgun", 130,
    }
}

VehicleDistributions.M998 = {

	GloveBox = VehicleDistributions.M998GloveBox;
	M998Trunk = VehicleDistributions.PoliceTruckBed;
    DAMNGunrack = VehicleDistributions.M998gunrack;
}

VehicleDistributions.M101A3 = {

	M101A3Trunk = VehicleDistributions.PoliceTruckBed;
}

distributionTable["92amgeneralM998"] = { Normal = VehicleDistributions.M998; }
distributionTable["92amgeneralM998Burnt"] = { Normal = VehicleDistributions.M998; }
distributionTable["TrailerM101A3cargo"] = { Normal = VehicleDistributions.M101A3; }