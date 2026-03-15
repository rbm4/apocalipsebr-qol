local distributionTable = VehicleDistributions[1]

VehicleDistributions.HLX88GloveBox = {
    rolls = 1,
    items = {
        "Base.88toyotaHiluxMagazine", 50,
        "Base.Pen", 4,
        "Base.Pencil", 4,
        "Base.Cigarettes", 5,
        "Base.Lighter", 5,
        "Base.Matches", 3,
        "Base.Tissue", 2,
    },
    junk = ClutterTables.GloveBoxJunk,
}

VehicleDistributions.HLX88gunrack = {
    rolls = 1,
    items = {
    	"Shotgun", 100,
    }
}

VehicleDistributions.HLX88 = {

	GloveBox = VehicleDistributions.HLX88GloveBox;
	HLX88Trunk = VehicleDistributions.TrunkHeavy;
    DAMNGunrack = VehicleDistributions.HLX88gunrack;
}

distributionTable["88toyotaHiluxSC"] = { Normal = VehicleDistributions.HLX88; }
distributionTable["88toyotaHiluxXC"] = { Normal = VehicleDistributions.HLX88; }
distributionTable["88toyotaHiluxXCS"] = { Normal = VehicleDistributions.HLX88; }