require "CommonTemplates/CommonDistributions"
require "ATA/ATATruckItemDistributions"

local distributionTable = VehicleDistributions[1]
distributionTable["ATAMustangClassic"] = {
    Normal = VehicleDistributions.NormalSports,
    Specific = { VehicleDistributions.Clothing, VehicleDistributions.Doctor, VehicleDistributions.Golf, VehicleDistributions.Groceries},
}

distributionTable["ATAMustangPolice"] = { Normal = VehicleDistributions.Police }

table.insert(VehicleDistributions, 1, distributionTable);


