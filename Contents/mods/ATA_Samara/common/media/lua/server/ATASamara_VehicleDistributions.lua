require "CommonTemplates/CommonDistributions"
require "ATA/ATATruckItemDistributions"

local distributionTable = VehicleDistributions[1]
distributionTable["ATASamaraClassic"] = {
    Normal = VehicleDistributions.NormalSports,
    Specific = { VehicleDistributions.Clothing, VehicleDistributions.Doctor, VehicleDistributions.Golf, VehicleDistributions.Groceries},
}

distributionTable["ATASamaraPolice"] = { Normal = VehicleDistributions.Police }

table.insert(VehicleDistributions, 1, distributionTable);


