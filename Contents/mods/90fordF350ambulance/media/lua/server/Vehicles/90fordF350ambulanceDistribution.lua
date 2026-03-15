local distributionTable = VehicleDistributions[1]

VehicleDistributions.F350Amb = {
	
	GloveBox = VehicleDistributions.DoctorGloveBox;

    F350TallStorage = VehicleDistributions.DoctorTruckBed;
    F350LowStorage = VehicleDistributions.DoctorTruckBed;
	F350LowCornerStorage = VehicleDistributions.DoctorTruckBed;
    F350RearStorage = VehicleDistributions.DoctorTruckBed;
    F350RightStorage = VehicleDistributions.DoctorTruckBed;
}

VehicleDistributions.F350SWAT = {
	
	GloveBox = VehicleDistributions.PoliceGloveBox;

    F350TallStorage = VehicleDistributions.PoliceTruckBed;
    F350LowStorage = VehicleDistributions.PoliceTruckBed;
	F350LowCornerStorage = VehicleDistributions.PoliceTruckBed;
    F350RearStorage = VehicleDistributions.DoctorTruckBed;
    F350RightStorage = VehicleDistributions.DoctorTruckBed;
}

distributionTable["90fordF350ambulance"] = { Normal = VehicleDistributions.F350Amb; }
distributionTable["90fordF350SWAT"] = { Normal = VehicleDistributions.F350SWAT; }