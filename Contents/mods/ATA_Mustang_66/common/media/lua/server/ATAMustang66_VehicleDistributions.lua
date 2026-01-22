require "CommonTemplates/CommonDistributions"
require "ATA/ATATruckItemDistributions"

local distributionTable = VehicleDistributions[1]

distributionTable["ATAMustang66"] = {
    Normal = VehicleDistributions.NormalSports,
    Specific = { VehicleDistributions.Clothing, VehicleDistributions.Doctor, VehicleDistributions.Golf, VehicleDistributions.Groceries},
}

distributionTable["ATAMustang66Custom"] = distributionTable["ATAMustang66"]

table.insert(VehicleDistributions, 1, distributionTable);
