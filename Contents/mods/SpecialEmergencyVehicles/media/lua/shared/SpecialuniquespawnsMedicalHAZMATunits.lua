require "VehicleZoneDefinition"
VehicleZoneDistribution.hazmatboulderrv = VehicleZoneDistribution.hazmatboulderrv or {}
VehicleZoneDistribution.hazmatboulderrv.vehicles = VehicleZoneDistribution.hazmatboulderrv.vehicles or {}
VehicleZoneDistribution.hazmatboulderrv.vehicles["Base.86bounderHAzardmaterials"] = {index = -1, spawnChance = 100}
VehicleZoneDistribution.hazmatboulderrv.baseVehicleQuality = 1.1;
VehicleZoneDistribution.hazmatboulderrv.spawnRate = 20000; 

function SPEV_HAZMATFBSPRV_Zones()
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("hazmatboulderrv", "ParkingStall", 12357, 3661, 0, 4, 4, { Direction = "N" })
        end
    end
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("hazmatboulderrv", "ParkingStall", 12939, 2098, 0, 4, 4, { Direction = "W" })
        end
    end
end

Events.OnLoadMapZones.Add(SPEV_HAZMATFBSPRV_Zones)


