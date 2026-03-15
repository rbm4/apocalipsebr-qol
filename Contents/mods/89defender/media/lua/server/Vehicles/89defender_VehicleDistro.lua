local distributionTable = VehicleDistributions[1]

VehicleDistributions.DEF89gunrack = {
    rolls = 1,
    items = {
    	"AssaultRifle", 100,
    }
}

VehicleDistributions.DEF89 = {

	GloveBox = VehicleDistributions.GloveBox;
	DEF89Trunk = VehicleDistributions.TrunkHeavy;
    DEF89Trunk130 = VehicleDistributions.TrunkHeavy;
    DEF89TruckBedAddon = VehicleDistributions.TrunkHeavy;
    DEF89Roofrack = VehicleDistributions.GloveBox;
    DEF89CenterConsole = VehicleDistributions.GloveBox;
    DEF89StorageLeft = VehicleDistributions.GloveBox;
    DEF89StorageRight = VehicleDistributions.GloveBox;
    DAMNGunrack = VehicleDistributions.DEF89gunrack;
}

distributionTable["89defender90"] = { Normal = VehicleDistributions.DEF89; }
distributionTable["89defender90utility"] = { Normal = VehicleDistributions.DEF89; }
distributionTable["89defender110"] = { Normal = VehicleDistributions.DEF89; }
distributionTable["89defender110utility"] = { Normal = VehicleDistributions.DEF89; }
distributionTable["89defender130"] = { Normal = VehicleDistributions.DEF89; }
distributionTable["89defenderWolf"] = { Normal = VehicleDistributions.DEF89; }