require "VehicleZoneDefinition"
VehicleZoneDistribution.sogmobilehq = VehicleZoneDistribution.sogmobilehq or {}
VehicleZoneDistribution.sogmobilehq.vehicles = VehicleZoneDistribution.sogmobilehq.vehicles or {}
VehicleZoneDistribution.sogmobilehq.vehicles["Base.Vehicles_sogmobilehq"] = {index = -1, spawnChance = 100}
VehicleZoneDistribution.sogmobilehq.baseVehicleQuality = 1.1;
VehicleZoneDistribution.sogmobilehq.spawnRate = 20000; 

function SPEV_SOGTRUCK_Zones()
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("sogmobilehq", "ParkingStall", 12494, 1614, 0, 4, 4, { Direction = "N" })
        end
    end
end

Events.OnLoadMapZones.Add(SPEV_SOGTRUCK_Zones)


