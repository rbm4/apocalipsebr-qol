local distributionTable = VehicleDistributions[1]

distributionTable["ATAPetyarbuilt"] = {
    Normal = VehicleDistributions.NormalHeavy,
    Specific = { VehicleDistributions.Fisherman, VehicleDistributions.Carpenter, VehicleDistributions.Farmer, VehicleDistributions.Electrician, VehicleDistributions.MetalWelder, VehicleDistributions.Survivalist, VehicleDistributions.ConstructionWorker, VehicleDistributions.Painter },
}
distributionTable["ATAPetyarbuiltSleeper"] = {
    Normal = VehicleDistributions.NormalHeavy,
    Specific = { VehicleDistributions.Fisherman, VehicleDistributions.Carpenter, VehicleDistributions.Farmer, VehicleDistributions.Electrician, VehicleDistributions.MetalWelder, VehicleDistributions.Survivalist, VehicleDistributions.ConstructionWorker, VehicleDistributions.Painter },
}
distributionTable["ATAPetyarbuiltJoker"] = {
    Normal = VehicleDistributions.NormalHeavy,
    Specific = { VehicleDistributions.Fisherman, VehicleDistributions.Carpenter, VehicleDistributions.Farmer, VehicleDistributions.Electrician, VehicleDistributions.MetalWelder, VehicleDistributions.Survivalist, VehicleDistributions.ConstructionWorker, VehicleDistributions.Painter },
}
distributionTable["ATAPetyarbuiltSleeperLong"] = {
    Normal = VehicleDistributions.NormalHeavy,
    Specific = { VehicleDistributions.Fisherman, VehicleDistributions.Carpenter, VehicleDistributions.Farmer, VehicleDistributions.Electrician, VehicleDistributions.MetalWelder, VehicleDistributions.Survivalist, VehicleDistributions.ConstructionWorker, VehicleDistributions.Painter },
}

distributionTable["TrailerTSMega"] = {
    Normal = ATATruckItemDistributions.HeavyMegaTruck,
    Specific = { ATATruckItemDistributions.GroceriesMegaTruck, 
    ATATruckItemDistributions.FarmerMegaTruck,
    ATATruckItemDistributions.FurnitureMegaTruck, 
    ATATruckItemDistributions.ClothingMegaTruck, 
    ATATruckItemDistributions.CarpenterMegaTruck, 
    ATATruckItemDistributions.CorpseMegaTruck, 
    ATATruckItemDistributions.MetalWelderMegaTruck,
    ATATruckItemDistributions.DoctorMegaTruck, 
    ATATruckItemDistributions.PoliceMegaTruck,},
}

distributionTable["TrailerTSMegaJoker"] = {
    Normal = ATATruckItemDistributions.HeavyMegaTruck,
    Specific = { ATATruckItemDistributions.GroceriesMegaTruck,
    ATATruckItemDistributions.FarmerMegaTruck,
    ATATruckItemDistributions.FurnitureMegaTruck,
    ATATruckItemDistributions.ClothingMegaTruck,
    ATATruckItemDistributions.CarpenterMegaTruck,
    ATATruckItemDistributions.CorpseMegaTruck,
    ATATruckItemDistributions.MetalWelderMegaTruck,
    ATATruckItemDistributions.DoctorMegaTruck,
    ATATruckItemDistributions.PoliceMegaTruck,},
}


table.insert(VehicleDistributions, 1, distributionTable);


