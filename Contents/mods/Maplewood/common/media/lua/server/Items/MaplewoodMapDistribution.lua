require 'Items/ProceduralDistributions'
require 'Items/Distributions'
require 'Vehicles/Distributions'


local function preDistributionMerge()
    table.insert(ProceduralDistributions.list.MagazineRackMaps.items, "MaplewoodMap");
    table.insert(ProceduralDistributions.list.MagazineRackMaps.items, 50);
	
	table.insert(VehicleDistributions.GloveBox.items, "MaplewoodMap");
    table.insert(VehicleDistributions.GloveBox.items, 50);
end
Events.OnPreDistributionMerge.Add(preDistributionMerge); 