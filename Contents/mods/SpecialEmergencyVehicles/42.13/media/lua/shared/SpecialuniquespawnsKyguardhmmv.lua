require "VehicleZoneDefinition"
VehicleZoneDistribution.hmmwvhardtopthsev = VehicleZoneDistribution.hmmwvhardtopthsev or {}
VehicleZoneDistribution.hmmwvhardtopthsev.vehicles = VehicleZoneDistribution.hmmwvhardtopthsev.vehicles or {}
VehicleZoneDistribution.hmmwvhardtopthsev.vehicles["Base.hmmwvHardTopthSEV"] = {index = -1, spawnChance = 100}
VehicleZoneDistribution.hmmwvhardtopthsev.baseVehicleQuality = 1.1;
VehicleZoneDistribution.hmmwvhardtopthsev.spawnRate = 20000; 

function SPEV_hmmwvHardTopthSEV_Zones()
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("hmmwvhardtopthsev", "ParkingStall", 12317, 6771, 0, 3, 3, { Direction = "N" })
        end
    end
	local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("hmmwvhardtopthsev", "ParkingStall", 12317, 6804, 0, 3, 3, { Direction = "N" })
        end
    end
end

Events.OnLoadMapZones.Add(SPEV_hmmwvHardTopthSEV_Zones)
