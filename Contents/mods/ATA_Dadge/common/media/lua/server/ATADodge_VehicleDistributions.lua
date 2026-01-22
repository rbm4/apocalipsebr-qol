require "CommonTemplates/CommonDistributions"
require "ATA/ATATruckItemDistributions"

local distributionTable = VehicleDistributions[1]
-- ATA2Dodge ATADodgePpg
distributionTable["ATADodge"] = {
    Normal = VehicleDistributions.NormalSports,
    Specific = { VehicleDistributions.Clothing, VehicleDistributions.Doctor, VehicleDistributions.Golf, VehicleDistributions.Groceries},
}

distributionTable["ATADodgePpg"] = {
    Normal = VehicleDistributions.NormalSports,
    Specific = { VehicleDistributions.Clothing, VehicleDistributions.Doctor, VehicleDistributions.Golf, VehicleDistributions.Groceries},
}

table.insert(VehicleDistributions, 1, distributionTable);


