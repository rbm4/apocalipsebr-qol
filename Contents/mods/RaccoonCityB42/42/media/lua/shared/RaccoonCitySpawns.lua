if VehicleZoneDistribution then
	-- 生化皮卡
	VehicleZoneDistribution.biochemical = VehicleZoneDistribution.biochemical or {};
	VehicleZoneDistribution.biochemical.vehicles = VehicleZoneDistribution.biochemical.vehicles or {};

	VehicleZoneDistribution.biochemical.vehicles["Base.Biochemical_PickupTruck"] = {index = -1, spawnChance = 1000};

	VehicleZoneDistribution.biochemical.baseVehicleQuality = 2.0;
	VehicleZoneDistribution.biochemical.chanceToSpawnKey = 50;
	VehicleZoneDistribution.biochemical.chanceToSpawnSpecial = 0;
	VehicleZoneDistribution.biochemical.spawnRate = 1000;
	
	-- MOD普通车
	VehicleZoneDistribution.modplain = VehicleZoneDistribution.modplain or {};
	VehicleZoneDistribution.modplain.vehicles = VehicleZoneDistribution.modplain.vehicles or {};

	VehicleZoneDistribution.modplain.vehicles["Base.U1550L"] = {index = -1, spawnChance = 12};
	VehicleZoneDistribution.modplain.vehicles["Base.UnimogTrailer"] = {index = -1, spawnChance = 12};
	VehicleZoneDistribution.modplain.vehicles["Base.en21_Bronco"] = {index = -1, spawnChance = 14};
	--VehicleZoneDistribution.modplain.vehicles["Base.86econolinerv"] = {index = -1, spawnChance = 10};
	--VehicleZoneDistribution.modplain.vehicles["Base.86bounder"] = {index = -1, spawnChance = 10};
	VehicleZoneDistribution.modplain.vehicles["Base.ATA_VanDeRumba"] = {index = -1, spawnChance = 12};
	VehicleZoneDistribution.modplain.vehicles["Base.ATAJeepClassic"] = {index = -1, spawnChance = 12};
	VehicleZoneDistribution.modplain.vehicles["Base.ATAJeepRubicon"] = {index = -1, spawnChance = 12};
	VehicleZoneDistribution.modplain.vehicles["Base.ATAMustangClassic"] = {index = -1, spawnChance = 12};
	VehicleZoneDistribution.modplain.vehicles["Base.ATADodge"] = {index = -1, spawnChance = 14};

	VehicleZoneDistribution.modplain.baseVehicleQuality = 1.1;
	VehicleZoneDistribution.modplain.chanceToSpawnKey = 5;
	VehicleZoneDistribution.modplain.chanceToSpawnSpecial = 0;
	VehicleZoneDistribution.modplain.spawnRate = 25;
	
	-- MOD军车
	--VehicleZoneDistribution.modmilitary = VehicleZoneDistribution.modmilitary or {};
	--VehicleZoneDistribution.modmilitary.vehicles = VehicleZoneDistribution.modmilitary.vehicles or {};
	--
	--VehicleZoneDistribution.modmilitary.vehicles["Base.SC_M35A1"] = {index = -1, spawnChance = 10};
	--VehicleZoneDistribution.modmilitary.vehicles["Base.80manKat1"] = {index = -1, spawnChance = 10};
	--VehicleZoneDistribution.modmilitary.vehicles["Base.83amgeneralM923"] = {index = -1, spawnChance = 10};
	--VehicleZoneDistribution.modmilitary.vehicles["Base.78amgeneralM35A2"] = {index = -1, spawnChance = 15};
	--VehicleZoneDistribution.modmilitary.vehicles["Base.78amgeneralM49A2C"] = {index = -1, spawnChance = 10};
	--VehicleZoneDistribution.modmilitary.vehicles["Base.78amgeneralM50A3"] = {index = -1, spawnChance = 10};
	--VehicleZoneDistribution.modmilitary.vehicles["Base.92amgeneralM998"] = {index = -1, spawnChance = 15};
	--VehicleZoneDistribution.modmilitary.vehicles["Base.86oshkoshKYFD"] = {index = -1, spawnChance = 10};
	--VehicleZoneDistribution.modmilitary.vehicles["Base.HEMTTLoadHandling"] = {index = -1, spawnChance = 10};
	--
	--VehicleZoneDistribution.modmilitary.baseVehicleQuality = 1.1;
	--VehicleZoneDistribution.modmilitary.chanceToSpawnKey = 5;
	--VehicleZoneDistribution.modmilitary.chanceToSpawnSpecial = 0;
	--VehicleZoneDistribution.modmilitary.spawnRate = 40;
	
	-- 特殊车
	VehicleZoneDistribution.modspecial = VehicleZoneDistribution.modspecial or {};
	VehicleZoneDistribution.modspecial.vehicles = VehicleZoneDistribution.modspecial.vehicles or {};
	
	VehicleZoneDistribution.modspecial.vehicles["Base.ATAJeepArcher"] = {index = -1, spawnChance = 30};
	VehicleZoneDistribution.modspecial.vehicles["Base.ATADodgePpg"] = {index = -1, spawnChance = 70};
	
	VehicleZoneDistribution.modspecial.baseVehicleQuality = 1.1;
	VehicleZoneDistribution.modspecial.chanceToSpawnKey = 0;
	VehicleZoneDistribution.modspecial.chanceToSpawnSpecial = 0;
	VehicleZoneDistribution.modspecial.spawnRate = 100;
end