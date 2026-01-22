require "VehicleZoneDefinition"
VehicleZoneDistribution.fematruckspawn = VehicleZoneDistribution.fematruckspawn or {}
VehicleZoneDistribution.fematruckspawn.vehicles = VehicleZoneDistribution.fematruckspawn.vehicles or {}
VehicleZoneDistribution.fematruckspawn.vehicles["Base.Vehicles_fematruck01"] = {index = -1, spawnChance = 100}
VehicleZoneDistribution.fematruckspawn.baseVehicleQuality = 1.1;
VehicleZoneDistribution.fematruckspawn.spawnRate = 20000; 

VehicleZoneDistribution.ambulancefemaas = VehicleZoneDistribution.ambulancefemaas or {}
VehicleZoneDistribution.ambulancefemaas.vehicles = VehicleZoneDistribution.ambulancefemaas.vehicles or {}
VehicleZoneDistribution.ambulancefemaas.vehicles["Base.80f350ambulanceFEMAas"] = {index = -1, spawnChance = 100}
VehicleZoneDistribution.ambulancefemaas.baseVehicleQuality = 1.1;
VehicleZoneDistribution.ambulancefemaas.spawnRate = 20000; 

function SPEV_FBSPFEMA_Zones()
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("fematruckspawn", "ParkingStall", 12514, 4226, 0, 4, 4, { Direction = "N" })
        end
    end
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("ambulancefemaas", "ParkingStall", 12476, 3700, 0, 4, 4, { Direction = "N" })
        end
    end
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("fematruckspawn", "ParkingStall", 12966, 1999, 0, 4, 4, { Direction = "N" })
        end
    end
    local dirs = getLotDirectories()
    for i=dirs:size(),1,-1 do
        local map = dirs:get(i-1)
        if map == "Muldraugh, KY" then
            getWorld():registerVehiclesZone("ambulancefemaas", "ParkingStall", 12973, 1999, 0, 4, 4, { Direction = "N" })
        end
    end
end

Events.OnLoadMapZones.Add(SPEV_FBSPFEMA_Zones)


