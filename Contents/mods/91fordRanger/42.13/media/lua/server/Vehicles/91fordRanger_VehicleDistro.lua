local distributionTable = VehicleDistributions[1]

VehicleDistributions.RNG91GloveBox = {
    rolls = 1,
    items = {
        "Base.91fordRangerMagazine", 50,
        "Base.Pen", 4,
        "Base.Pencil", 4,
        "Base.Cigarettes", 5,
        "Base.Lighter", 5,
        "Base.Matches", 3,
        "Base.Tissue", 2,
    },
    junk = ClutterTables.GloveBoxJunk,
}

VehicleDistributions.RNG91gunrack = {
    rolls = 1,
    items = {
    	"Shotgun", 100,
    }
}

VehicleDistributions.RNG91 = {

	GloveBox = VehicleDistributions.RNG91GloveBox;
	RNG91Trunk = VehicleDistributions.TrunkHeavy;
}

VehicleDistributions.RNG91PD = {

	GloveBox = VehicleDistributions.PoliceGloveBox;
	RNG91Trunk = VehicleDistributions.PoliceTruckBed;
    DAMNGunrack = VehicleDistributions.RNG91gunrack;
}

distributionTable["91fordRangerSC"] = { Normal = VehicleDistributions.RNG91; }
distributionTable["91fordRangerSClong"] = { Normal = VehicleDistributions.RNG91; }
distributionTable["91fordRangerXC"] = { Normal = VehicleDistributions.RNG91; }
distributionTable["91fordRangerXClong"] = { Normal = VehicleDistributions.RNG91; }
distributionTable["91fordRangerPD"] = { Normal = VehicleDistributions.RNG91PD; }
distributionTable["91fordRangerRanger"] = { Normal = VehicleDistributions.RNG91PD; }