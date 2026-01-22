require "VehicleZoneDefinition"
VehicleZoneDistribution.cadillacrangerswatfbsp = VehicleZoneDistribution.cadillacrangerswatfbsp or {}
VehicleZoneDistribution.cadillacrangerswatfbsp.vehicles = VehicleZoneDistribution.cadillacrangerswatfbsp.vehicles or {}
VehicleZoneDistribution.cadillacrangerswatfbsp.vehicles["Base.CadillacRangerSWATFBSP"] = {index = -1, spawnChance = 100}
VehicleZoneDistribution.cadillacrangerswatfbsp.baseVehicleQuality = 1.1;
VehicleZoneDistribution.cadillacrangerswatfbsp.spawnRate = 20000; 

function SPEV_CadillacRangerSWAT_Zones()
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("cadillacrangerswatfbsp", "ParkingStall", 12453, 1590, 0, 4, 4, { Direction = "N" })
        end
    end
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("cadillacrangerswatfbsp", "ParkingStall", 12523, 4185, 0, 4, 4, { Direction = "N" })
        end
    end
end

Events.OnLoadMapZones.Add(SPEV_CadillacRangerSWAT_Zones)


