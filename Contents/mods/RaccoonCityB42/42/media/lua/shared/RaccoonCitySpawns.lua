if VehicleZoneDistribution then
	-- Biochemical zone - vanilla SUV replacement (modded vehicles sold in store only)
	VehicleZoneDistribution.biochemical = VehicleZoneDistribution.biochemical or {};
	VehicleZoneDistribution.biochemical.vehicles = VehicleZoneDistribution.biochemical.vehicles or {};

	VehicleZoneDistribution.biochemical.vehicles["Base.SUV"] = {index = -1, spawnChance = 50};
	VehicleZoneDistribution.biochemical.vehicles["Base.PickUpTruck"] = {index = -1, spawnChance = 50};

	VehicleZoneDistribution.biochemical.baseVehicleQuality = 2.0;
	VehicleZoneDistribution.biochemical.chanceToSpawnKey = 50;
	VehicleZoneDistribution.biochemical.chanceToSpawnSpecial = 0;
	VehicleZoneDistribution.biochemical.spawnRate = 1000;
	
	-- Vanilla civilian vehicles (modded vehicles removed - sold in store only)
	VehicleZoneDistribution.modplain = VehicleZoneDistribution.modplain or {};
	VehicleZoneDistribution.modplain.vehicles = VehicleZoneDistribution.modplain.vehicles or {};

	VehicleZoneDistribution.modplain.vehicles["Base.CarNormal"] = {index = -1, spawnChance = 15};
	VehicleZoneDistribution.modplain.vehicles["Base.SmallCar"] = {index = -1, spawnChance = 15};
	VehicleZoneDistribution.modplain.vehicles["Base.ModernCar"] = {index = -1, spawnChance = 12};
	VehicleZoneDistribution.modplain.vehicles["Base.PickUpTruck"] = {index = -1, spawnChance = 12};
	VehicleZoneDistribution.modplain.vehicles["Base.SUV"] = {index = -1, spawnChance = 10};
	VehicleZoneDistribution.modplain.vehicles["Base.Van"] = {index = -1, spawnChance = 10};
	VehicleZoneDistribution.modplain.vehicles["Base.CarStationWagon"] = {index = -1, spawnChance = 14};
	VehicleZoneDistribution.modplain.vehicles["Base.SportsCar"] = {index = -1, spawnChance = 8};
	VehicleZoneDistribution.modplain.vehicles["Base.OffRoad"] = {index = -1, spawnChance = 4};

	VehicleZoneDistribution.modplain.baseVehicleQuality = 1.1;
	VehicleZoneDistribution.modplain.chanceToSpawnKey = 5;
	VehicleZoneDistribution.modplain.chanceToSpawnSpecial = 0;
	VehicleZoneDistribution.modplain.spawnRate = 25;
	
	-- Vanilla special vehicles (modded vehicles removed - sold in store only)
	VehicleZoneDistribution.modspecial = VehicleZoneDistribution.modspecial or {};
	VehicleZoneDistribution.modspecial.vehicles = VehicleZoneDistribution.modspecial.vehicles or {};
	
	VehicleZoneDistribution.modspecial.vehicles["Base.CarLightsPolice"] = {index = -1, spawnChance = 40};
	VehicleZoneDistribution.modspecial.vehicles["Base.CarLightsRanger"] = {index = -1, spawnChance = 30};
	VehicleZoneDistribution.modspecial.vehicles["Base.CarLuxury"] = {index = -1, spawnChance = 30};
	
	VehicleZoneDistribution.modspecial.baseVehicleQuality = 1.1;
	VehicleZoneDistribution.modspecial.chanceToSpawnKey = 0;
	VehicleZoneDistribution.modspecial.chanceToSpawnSpecial = 0;
	VehicleZoneDistribution.modspecial.spawnRate = 100;
end