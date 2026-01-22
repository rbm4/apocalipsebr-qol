require "VehicleZoneDefinition"
VehicleZoneDistribution.cdcjeepcherokeesev = VehicleZoneDistribution.cdcjeepcherokeesev or {}
VehicleZoneDistribution.cdcjeepcherokeesev.vehicles = VehicleZoneDistribution.cdcjeepcherokeesev.vehicles or {}
VehicleZoneDistribution.cdcjeepcherokeesev.vehicles["Base.93jeepcherokeeCDCSEV"] = {index = -1, spawnChance = 100}
VehicleZoneDistribution.cdcjeepcherokeesev.baseVehicleQuality = 1.1;
VehicleZoneDistribution.cdcjeepcherokeesev.spawnRate = 20000; 

function SPEV_cdcjeepcherokeesev_Zones()
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("cdcjeepcherokeesev", "ParkingStall", 12317, 6786, 0, 3, 3, { Direction = "N" })
        end
    end
end

Events.OnLoadMapZones.Add(SPEV_cdcjeepcherokeesev_Zones)
