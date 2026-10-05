local distributionTable = VehicleDistributions[1]

VehicleDistributions.B700GloveBox = {
    rolls = 1,
    items = {
        "Base.87fordBF700Magazine", 60,
        "Base.Pen", 4,
        "Base.Pencil", 4,
        "Base.Cigarettes", 5,
        "Base.Lighter", 5,
        "Base.Matches", 3,
        "Base.Tissue", 2,
    },
    junk = ClutterTables.GloveBoxJunk,
}

VehicleDistributions.F700gunrack = {
    rolls = 1,
    items = {
    	"Base.Shotgun", 130,
    }
}

VehicleDistributions.F700guncab = {
    rolls = 2,
    items = {
    	"Base.Shotgun", 15,
        "Base.Pistol", 20,
        "Base.AssaultRifle", 10,
        "Base.ShotgunShellsBox", 30,
        "Base.Bullets9mmBox", 40,
        "Base.556Box", 20,
    }
}

VehicleDistributions.F700monehz = {
    rolls =100,
    items = {
    	"Base.Money", 100,
        "Base.CreditCard", 90,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
        "Base.Money", 80,
    }
}

VehicleDistributions.B700 = {
	
	GloveBox = VehicleDistributions.B700GloveBox;

    B700Trunk = VehicleDistributions.TrunkHeavy;
	B700TrunkLeft = VehicleDistributions.GloveBox;
    B700TrunkRight = VehicleDistributions.GloveBox;
    B700Roofrack = VehicleDistributions.TrunkHeavy;
}

VehicleDistributions.F700SWAT = {
	
	GloveBox = VehicleDistributions.PoliceGloveBox;

	F700TrunkSW = VehicleDistributions.PoliceTruckBed;
    F700TrunkSWGunrack = VehicleDistributions.F700gunrack;
    F700TrunkSWGuncabinet = VehicleDistributions.F700guncab;
}

VehicleDistributions.F700BANK = {
	
	GloveBox = VehicleDistributions.B700GloveBox;

	F700TrunkBN = VehicleDistributions.F700monehz;
}

VehicleDistributions.F700BOX = {
	
	GloveBox = VehicleDistributions.B700GloveBox;

	F700TrunkBX = VehicleDistributions.TrunkHeavy;
    F700TrunkLeftBX = VehicleDistributions.GloveBox;
}

distributionTable["87fordB700school"] = { Normal = VehicleDistributions.B700; }
distributionTable["87fordB700military"] = { Normal = VehicleDistributions.B700; }
distributionTable["87fordB700prison"] = { Normal = VehicleDistributions.B700; }
distributionTable["87fordF700swat"] = { Normal = VehicleDistributions.F700SWAT; }
distributionTable["87fordF700bank"] = { Normal = VehicleDistributions.F700BANK; }
distributionTable["87fordF700box"] = { Normal = VehicleDistributions.F700BOX; }