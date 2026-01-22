require "VehicleZoneDefinition"
VehicleZoneDistribution.cdctrucksev = VehicleZoneDistribution.cdctrucksev or {}
VehicleZoneDistribution.cdctrucksev.vehicles = VehicleZoneDistribution.cdctrucksev.vehicles or {}
VehicleZoneDistribution.cdctrucksev.vehicles["Base.f700boxshellCDCSEV"] = {index = -1, spawnChance = 100}
VehicleZoneDistribution.cdctrucksev.baseVehicleQuality = 1.1;
VehicleZoneDistribution.cdctrucksev.spawnRate = 20000; 

function SPEV_cdctrucksev_Zones()
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("cdctrucksev", "ParkingStall", 12317, 6795, 0, 3, 3, { Direction = "N" })
        end
    end
end

Events.OnLoadMapZones.Add(SPEV_cdctrucksev_Zones)
