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

VehicleDistributions.STP85GloveBox = {
    rolls = 1,
    items = {
        "Base.85chevyStepVanMagazine", 50,
        "Base.Pen", 4,
        "Base.Pencil", 4,
        "Base.Cigarettes", 5,
        "Base.Lighter", 5,
        "Base.Matches", 3,
        "Base.Tissue", 2,
    },
    junk = ClutterTables.GloveBoxJunk,
}

VehicleDistributions.STP85 = {

	GloveBox = VehicleDistributions.STP85GloveBox;
	STP85Trunk1 = VehicleDistributions.TrunkHeavy;
	STP85Roofrack = VehicleDistributions.GloveBox;
}

VehicleDistributions.STP85SWAT = {

	GloveBox = VehicleDistributions.STP85GloveBox;
	STP85Trunk1 = VehicleDistributions.PoliceSWATTruckBed;
    SeatFrontLeft = VehicleDistributions.DriverSeat;
	SeatFrontRight = VehicleDistributions.PoliceSWATSeatFront;
    DAMNGunrack = VehicleDistributions.STP85gunrack;
	STP85Roofrack = VehicleDistributions.PoliceSWATGloveBox;
}

distributionTable["85chevyStepVan"] = { Normal = VehicleDistributions.STP85; }
distributionTable["85chevyStepVanSWAT"] = { Normal = VehicleDistributions.STP85SWAT; }