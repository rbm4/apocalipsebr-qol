if VehicleZoneDistribution then

VehicleZoneDistribution.parkingstall.vehicles["Base.92amgeneralM998"] = {index = -1, spawnChance = 0};
VehicleZoneDistribution.parkingstall.vehicles["Base.TrailerM101A3cargo"] = {index = -1, spawnChance = 1};

VehicleZoneDistribution.trailerpark.vehicles["Base.92amgeneralM998"] = {index = -1, spawnChance = 0};
VehicleZoneDistribution.trailerpark.vehicles["Base.92amgeneralM998Burnt"] = {index = -1, spawnChance = 1};
VehicleZoneDistribution.trailerpark.vehicles["Base.TrailerM101A3cargo"] = {index = -1, spawnChance = 2};

VehicleZoneDistribution.bad.vehicles["Base.92amgeneralM998"] = {index = -1, spawnChance = 0};
VehicleZoneDistribution.bad.vehicles["Base.92amgeneralM998Burnt"] = {index = -1, spawnChance = 1};

VehicleZoneDistribution.junkyard.vehicles["Base.92amgeneralM998"] = {index = -1, spawnChance = 0};
VehicleZoneDistribution.junkyard.vehicles["Base.92amgeneralM998Burnt"] = {index = -1, spawnChance = 2};

VehicleZoneDistribution.ranger.vehicles["Base.92amgeneralM998"] = {index = -1, spawnChance = 0};
VehicleZoneDistribution.ranger.vehicles["Base.TrailerM101A3cargo"] = {index = -1, spawnChance = 1};

-- Trafficjam spawns --

VehicleZoneDistribution.trafficjams.vehicles["Base.92amgeneralM998"] = {index = -1, spawnChance = 0};
VehicleZoneDistribution.trafficjams.vehicles["Base.92amgeneralM998Burnt"] = {index = -1, spawnChance = 2};
VehicleZoneDistribution.trafficjams.vehicles["Base.TrailerM101A3cargo"] = {index = -1, spawnChance = 1};

-- Military spawn --

VehicleZoneDistribution.military = VehicleZoneDistribution.military or {}
VehicleZoneDistribution.military.vehicles = VehicleZoneDistribution.military.vehicles or {}

VehicleZoneDistribution.military.vehicles["Base.92amgeneralM998"] = {index = -1, spawnChance = 0};

VehicleZoneDistribution.military.vehicles["Base.92amgeneralM998Burnt"] = {index = -1, spawnChance = 0};

VehicleZoneDistribution.military.vehicles["Base.TrailerM101A3cargo"] = {index = -1, spawnChance = 0};

end