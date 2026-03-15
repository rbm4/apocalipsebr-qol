local distributionTable = VehicleDistributions[1]

VehicleDistributions.HLX88gunrack = {
    rolls = 1,
    items = {
    	"Shotgun", 100,
    }
}

VehicleDistributions.HLX88 = {

	GloveBox = VehicleDistributions.GloveBox;
	HLX88Trunk = VehicleDistributions.TrunkHeavy;
    DAMNGunrack = VehicleDistributions.HLX88gunrack;
}

distributionTable["88toyotaHiluxSC"] = { Normal = VehicleDistributions.HLX88; }
distributionTable["88toyotaHiluxXC"] = { Normal = VehicleDistributions.HLX88; }
distributionTable["88toyotaHiluxXCS"] = { Normal = VehicleDistributions.HLX88; }