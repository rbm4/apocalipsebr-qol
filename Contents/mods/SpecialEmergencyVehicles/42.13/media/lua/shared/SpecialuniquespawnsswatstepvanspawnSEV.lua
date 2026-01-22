require "VehicleZoneDefinition"
VehicleZoneDistribution.stepvanchevySWATSEVs = VehicleZoneDistribution.stepvanchevySWATSEVs or {}
VehicleZoneDistribution.stepvanchevySWATSEVs.vehicles = VehicleZoneDistribution.stepvanchevySWATSEVs.vehicles or {}
VehicleZoneDistribution.stepvanchevySWATSEVs.vehicles["base.stepvanchevySWATSEV"] = {index = -1, spawnChance = 1000}
VehicleZoneDistribution.stepvanchevySWATSEVs.baseVehicleQuality = 1.1;
VehicleZoneDistribution.stepvanchevySWATSEVs.spawnRate = 20000; 


function SPEV_stepvanchevySWATSEVs_Zones()
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("stepvanchevySWATSEVs", "ParkingStall", 12973, 1408, 0, 4, 4, { Direction = "E" })
        end
    end
end

Events.OnLoadMapZones.Add(SPEV_stepvanchevySWATSEVs_Zones)


