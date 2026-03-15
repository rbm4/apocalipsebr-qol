ProceduralDistributions = ProceduralDistributions or {}
ProceduralDistributions.list = ProceduralDistributions.list or {}

local function preDistributionMerge()

	ProceduralDistributions.list.MockingbirdZoneRoom = {
        rolls = 6,
        items = {
			"Base.LouisvilleMap1", 2,
			"Base.LouisvilleMap2", 2,
			"Base.LouisvilleMap3", 2,
			"Base.LouisvilleMap4", 2,
			"Base.LouisvilleMap5", 2,
			"Base.LouisvilleMap6", 2,
			"Base.LouisvilleMap7", 2,
			"Base.LouisvilleMap8", 2,
			"Base.LouisvilleMap9", 2,
			"Base.MuldraughMap", 10,
			"Base.WestpointMap", 10,
			"Base.MarchRidgeMap", 10,
			"Base.RosewoodMap", 10,
			"Base.RiversideMap", 10,
            "Base.MockingbirdMap", 10,
			"ElectronicsMag4", 10,
			"Katana", 20,
			"Katana", 20,
			"Katana", 20,
			"Katana", 20,
			"Katana", 10,
			"Katana", 10,
			"Katana", 10,
			"Katana", 10,
        },
		junk = {
			rolls = 1,
			items = {

			}
		}
    }

end

Events.OnPreDistributionMerge.Add(preDistributionMerge);
