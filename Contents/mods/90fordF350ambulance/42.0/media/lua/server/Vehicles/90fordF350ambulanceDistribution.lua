local distributionTable = VehicleDistributions[1]

VehicleDistributions.F350AmbGloveBox = {
    rolls = 1,
    items = {
        "Base.90fordF350Magazine", 60,
        "Base.Pen", 4,
        "Base.Pencil", 4,
        "Base.Cigarettes", 5,
        "Base.Lighter", 5,
        "Base.Matches", 3,
        "Base.Tissue", 2,
    },
    junk = ClutterTables.GloveBoxJunk,
}

VehicleDistributions.F350Amb = {
	
	GloveBox = VehicleDistributions.F350AmbGloveBox;

    F350TallStorage = VehicleDistributions.DoctorTruckBed;
    F350LowStorage = VehicleDistributions.DoctorTruckBed;
	F350LowCornerStorage = VehicleDistributions.DoctorTruckBed;
    F350RearStorage = VehicleDistributions.DoctorTruckBed;
    F350RightStorage = VehicleDistributions.DoctorTruckBed;
}

VehicleDistributions.F350SWAT = {
	
	GloveBox = VehicleDistributions.F350AmbGloveBox;

    F350TallStorage = VehicleDistributions.PoliceTruckBed;
    F350LowStorage = VehicleDistributions.PoliceTruckBed;
	F350LowCornerStorage = VehicleDistributions.PoliceTruckBed;
    F350RearStorage = VehicleDistributions.DoctorTruckBed;
    F350RightStorage = VehicleDistributions.DoctorTruckBed;
}

distributionTable["90fordF350ambulance"] = { Normal = VehicleDistributions.F350Amb; }
distributionTable["90fordF350SWAT"] = { Normal = VehicleDistributions.F350SWAT; }