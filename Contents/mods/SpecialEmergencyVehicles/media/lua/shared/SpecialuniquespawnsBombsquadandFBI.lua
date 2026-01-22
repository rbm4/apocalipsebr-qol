require "VehicleZoneDefinition"
VehicleZoneDistribution.bombsquadfbsp = VehicleZoneDistribution.bombsquadfbsp or {}
VehicleZoneDistribution.bombsquadfbsp.vehicles = VehicleZoneDistribution.bombsquadfbsp.vehicles or {}
VehicleZoneDistribution.bombsquadfbsp.vehicles["Base.f700boxbombsquadLG"] = {index = -1, spawnChance = 100}
VehicleZoneDistribution.bombsquadfbsp.baseVehicleQuality = 1.1;
VehicleZoneDistribution.bombsquadfbsp.spawnRate = 20000; 


function SPEV_bombsquadfbsp_Zones()
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("bombsquadfbsp", "ParkingStall", 12950, 1396, 0, 4, 4, { Direction = "E" })
        end
    end
end

Events.OnLoadMapZones.Add(SPEV_bombsquadfbsp_Zones)


