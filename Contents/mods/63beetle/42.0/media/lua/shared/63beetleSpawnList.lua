if VehicleZoneDistribution then

VehicleZoneDistribution.parkingstall.vehicles["Base.63beetle"] = {index = -1, spawnChance = 1};

VehicleZoneDistribution.trailerpark.vehicles["Base.63beetle"] = {index = -1, spawnChance = 2};
VehicleZoneDistribution.trailerpark.vehicles["Base.63beetleBuggy"] = {index = -1, spawnChance = 1};

VehicleZoneDistribution.bad.vehicles["Base.63beetle"] = {index = -1, spawnChance = 1};

VehicleZoneDistribution.good.vehicles["Base.63beetleHP"] = {index = -1, spawnChance = 3};

VehicleZoneDistribution.junkyard.vehicles["Base.63beetle"] = {index = -1, spawnChance = 1};

VehicleZoneDistribution.trafficjams.vehicles["Base.63beetle"] = {index = -1, spawnChance = 2};
VehicleZoneDistribution.trafficjams.vehicles["Base.63beetleBuggy"] = {index = -1, spawnChance = 2};

VehicleZoneDistribution.ranger.vehicles["Base.63beetleBuggy"] = {index = -1, spawnChance = 3};

VehicleZoneDistribution.farm = VehicleZoneDistribution.farm or {}
VehicleZoneDistribution.farm.vehicles = VehicleZoneDistribution.farm.vehicles or {}
VehicleZoneDistribution.farm.vehicles["Base.63beetleBuggy"] = {index = -1, spawnChance = 5};

end