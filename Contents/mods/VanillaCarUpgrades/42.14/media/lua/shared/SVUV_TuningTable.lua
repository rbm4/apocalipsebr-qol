require "ATA2TuningTable"
require "SVUC_TuningTableCore"

local function copy(obj, seen)
	if type(obj) ~= 'table' then return obj end
	if seen and seen[obj] then return seen[obj] end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
	return res
end

local function SVUV_DoubleMaterialCosts(vehicleTable)
	for partName, partData in pairs(vehicleTable.parts) do
		for variantName, variant in pairs(partData) do
			if type(variant) == "table" and variant.install and variant.install.use then
				-- Replace ATAProtectionWheelsChain with module-prefixed ID
				if variant.install.use["ATAProtectionWheelsChain"] then
					variant.install.use["ATAProtectionWheelsChain"] = nil
					variant.install.use["ATA2.ATAProtectionWheelsChain"] = 1
				end
				-- Double all materials except BlowTorch and wheel chains
				for material, amount in pairs(variant.install.use) do
					if material ~= "BlowTorch" and material ~= "ATA2.ATAProtectionWheelsChain" then
						variant.install.use[material] = amount * 2
					end
				end
			end
		end
	end
end

function SVUV_TuningTable()
	local TemplateTuningTable = SVUC_TemplateVehicle()
	local NewCarTuningTable = {}

	-- Entries
	NewCarTuningTable["CarNormal"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["CarLightsRanger"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["CarStationWagon"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["PickUpTruck"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["PickUpVan"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["SmallCar"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["SmallCar02"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["VanSeats"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["Van"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["VanRadio"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["CarLightsPolice"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}
	NewCarTuningTable["PickUpVanLightsPolice"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}

	local carRecipe = "ATAVanillaRecipes"

	-- CarNormal
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionWindowRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionWindowRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["CarNormal"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionTrunk"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionDoorRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionDoorRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"])
	NewCarTuningTable["CarNormal"].parts["ATA2InteractiveTrunkRoofRack"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"])
	NewCarTuningTable["CarNormal"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["CarNormal"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["CarNormal"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["CarNormal"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


	-- CarLights
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionWindowRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionWindowRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionTrunk"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionDoorRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionDoorRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["CarLightsRanger"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


	-- CarWagon
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionWindowRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionWindowRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionTrunk"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionDoorRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionDoorRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2InteractiveTrunkRoofRack"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2InteractiveTrunkRoofRack"].Default.containerCapacity = 100
	NewCarTuningTable["CarStationWagon"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["CarStationWagon"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


	-- SmallCar
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionWindowRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionWindowRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["SmallCar"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionTrunk"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["SmallCar"].parts["ATA2InteractiveTrunkRoofRack"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"])
	NewCarTuningTable["SmallCar"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["SmallCar"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["SmallCar"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["SmallCar"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


	-- SmallCar2
	NewCarTuningTable["SmallCar02"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["SmallCar02"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["SmallCar02"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["SmallCar02"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["SmallCar02"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["SmallCar02"].parts["ATA2ProtectionTrunk"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	NewCarTuningTable["SmallCar02"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["SmallCar02"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["SmallCar02"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["SmallCar02"].parts["ATA2InteractiveTrunkRoofRack"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"])
	NewCarTuningTable["SmallCar02"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["SmallCar02"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["SmallCar02"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["SmallCar02"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


	-- PickUpTruck
	NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["PickUpTruck"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


	-- PickUpVan
	NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["PickUpVan"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionTrunk"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["PickUpVan"].parts["ATA2InteractiveTrunkRoofRack"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"])
	NewCarTuningTable["PickUpVan"].parts["ATA2InteractiveTrunkRoofRack"].Default.containerCapacity = 100
	NewCarTuningTable["PickUpVan"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["PickUpVan"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["PickUpVan"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


	-- Van
	NewCarTuningTable["Van"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["Van"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["Van"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["Van"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["Van"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["Van"].parts["ATA2ProtectionDoorsRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"])
	NewCarTuningTable["Van"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["Van"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["Van"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["Van"].parts["ATA2InteractiveTrunkRoofRack"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"])
	NewCarTuningTable["Van"].parts["ATA2InteractiveTrunkRoofRack"].Default.containerCapacity = 100
	NewCarTuningTable["Van"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["Van"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["Van"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["Van"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


	-- VanRadio
	NewCarTuningTable["VanRadio"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["VanRadio"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["VanRadio"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["VanRadio"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["VanRadio"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["VanRadio"].parts["ATA2ProtectionDoorsRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"])
	NewCarTuningTable["VanRadio"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["VanRadio"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["VanRadio"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["VanRadio"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["VanRadio"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["VanRadio"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["VanRadio"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


	-- VanSeats
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionWindowMiddleLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionWindowMiddleRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
	NewCarTuningTable["VanSeats"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionDoorsRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionDoorMiddleLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionDoorMiddleRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"])
	NewCarTuningTable["VanSeats"].parts["ATA2InteractiveTrunkRoofRack"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"])
	NewCarTuningTable["VanSeats"].parts["ATA2InteractiveTrunkRoofRack"].Default.containerCapacity = 100
	NewCarTuningTable["VanSeats"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
	NewCarTuningTable["VanSeats"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	NewCarTuningTable["VanSeats"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
	NewCarTuningTable["VanSeats"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])

	NewCarTuningTable["CarLightsPolice"] = copy(NewCarTuningTable["CarLightsRanger"])
	NewCarTuningTable["CarLightsPolice"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarPolice"])

	NewCarTuningTable["PickUpVanLightsPolice"] = copy(NewCarTuningTable["PickUpVan"])
	NewCarTuningTable["PickUpVanLightsPolice"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarPoliceSUV"])

	-- Double material costs for all vanilla vehicles (excluding BlowTorch)
	SVUV_DoubleMaterialCosts(NewCarTuningTable["CarNormal"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["CarLightsRanger"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["CarStationWagon"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["SmallCar"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["SmallCar02"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["PickUpTruck"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["PickUpVan"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["Van"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["VanRadio"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["VanSeats"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["CarLightsPolice"])
	SVUV_DoubleMaterialCosts(NewCarTuningTable["PickUpVanLightsPolice"])

	NewCarTuningTable["CarLightsBulletinSheriff"] = NewCarTuningTable["CarLightsPolice"]
	NewCarTuningTable["CarLightsKST"] = NewCarTuningTable["CarLightsPolice"]
	NewCarTuningTable["CarLightsLouisvilleCounty"] = NewCarTuningTable["CarLightsPolice"]
	NewCarTuningTable["CarLightsMuldraughPolice"] = NewCarTuningTable["CarLightsPolice"]
	NewCarTuningTable["ModernCarLightsCityLouisvillePD"] = NewCarTuningTable["CarLightsPolice"]
	NewCarTuningTable["ModernCarLightsMeadeSheriff"] = NewCarTuningTable["CarLightsPolice"]
	NewCarTuningTable["ModernCarLightsWestPoint"] = NewCarTuningTable["CarLightsPolice"]
	NewCarTuningTable["PickUpVanLightsLouisvilleCounty"] = NewCarTuningTable["PickUpVanLightsPolice"]
	NewCarTuningTable["PickUpVanLightsStatePolice"] = NewCarTuningTable["PickUpVanLightsPolice"]

	NewCarTuningTable["ModernCar"] = NewCarTuningTable["CarNormal"]
	NewCarTuningTable["ModernCar02"] = NewCarTuningTable["CarNormal"]

	NewCarTuningTable["CarStationWagon2"] = NewCarTuningTable["CarStationWagon"]
	NewCarTuningTable["SUV"] = NewCarTuningTable["CarStationWagon"]

	NewCarTuningTable["CarTaxi"] = NewCarTuningTable["CarLightsRanger"]
	NewCarTuningTable["CarTaxi2"] = NewCarTuningTable["CarLightsRanger"]

	NewCarTuningTable["CarLuxury"] = NewCarTuningTable["SmallCar02"]
	NewCarTuningTable["SportsCar"] = NewCarTuningTable["SmallCar02"]

	NewCarTuningTable["OffRoad"] = NewCarTuningTable["SmallCar"]

	NewCarTuningTable["PickUpTruckMccoy"] = NewCarTuningTable["PickUpTruck"]
	NewCarTuningTable["PickUpTruckLightsFire"] = NewCarTuningTable["PickUpTruck"]
	NewCarTuningTable["PickUpTruckLightsRanger"] = NewCarTuningTable["PickUpTruck"]
	NewCarTuningTable["PickUpTruckJPLandscaping"] = NewCarTuningTable["PickUpTruck"]
	NewCarTuningTable["PickUpTruck_Camo"] = NewCarTuningTable["PickUpTruck"]
	NewCarTuningTable["PickUpTruckLightsAirport"] = NewCarTuningTable["PickUpTruck"]
	NewCarTuningTable["PickUpTruckLightsAirportSecurity"] = NewCarTuningTable["PickUpTruck"]
	NewCarTuningTable["PickUpTruckLightsFossoil"] = NewCarTuningTable["PickUpTruck"]

	NewCarTuningTable["PickUpVanMccoy"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanLightsFire"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanLightsRanger"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanLightsFossoil"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanLightsKentuckyLumber"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanLightsCarpenter"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanBrickingIt"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanCallowayLandscaping"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanHeltonMetalWorking"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanKimbleKonstruction"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanMarchRidgeConstruction"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanWeldingbyCamille"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanYingsWood"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanMetalworker"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVanBuilder"] = NewCarTuningTable["PickUpVan"]
	NewCarTuningTable["PickUpVan_Camo"] = NewCarTuningTable["PickUpVan"]

	NewCarTuningTable["StepVan_LouisvilleSWAT"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Heralds"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVanMail"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Scarlet"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVanAirportCatering"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Cereal"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Citr8"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_CompleteRepairShop"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Genuine_Beer"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_HuangsLaundry"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Jorgensen"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_LouisvilleMotorShop"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_MarineBites"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Plonkies"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_RandisPlants"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_SouthEasternHosp"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_SouthEasternPaint"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_USL"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Zippee"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Mechanic"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Florist"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Glass"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Butchers"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Blacksmith"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_Masonry"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_MobileLibrary"] = NewCarTuningTable["Van"]
	NewCarTuningTable["StepVan_SmartKut"] = NewCarTuningTable["Van"]

	NewCarTuningTable["Van_Blacksmith"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_CraftSupplies"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_Glass"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_HeritageTailors"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_Leather"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_Locksmith"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_Masonry"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_KnoxDisti"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_Transit"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanSpiffo"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_MassGenFac"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_LectroMax"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanRosewoodworking"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanSchwabSheetMetal"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanTreyBaines"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanUncloggers"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_VoltMojo"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanWPCarpentry"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanBeckmans"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanBrewsterHarbin"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_BugWipers"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_Charlemange_Beer"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanCoastToCoast"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanDeerValley"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanFossoil"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanGardenGods"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanGreenes"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanJohnMcCoy"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanJonesFabrication"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanKerrHomes"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanKnobCreekGas"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanKnoxCom"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanKorshunovs"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanLouisvilleLandscaping"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanMccoy"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanMeltingPointMetal"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanMetalheads"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanMicheles"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanMobileMechanics"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanMooreMechanics"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanOldMill"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanOvoFarm"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanPennSHam"] = NewCarTuningTable["Van"]
	NewCarTuningTable["Van_Perfick_Potato"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanPlattAuto"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanPluggedInElectrics"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanRiversideFabrication"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanBuilder"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanGardener"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanCarpenter"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanMechanic"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanMetalworker"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanUtility"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanMail"] = NewCarTuningTable["Van"]

	NewCarTuningTable["VanSeats_Creature"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanSeats_LadyDelighter"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanSeats_Mural"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanSeats_Space"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanSeats_Trippy"] = NewCarTuningTable["Van"]
	NewCarTuningTable["VanSeats_Valkyrie"] = NewCarTuningTable["Van"]

	NewCarTuningTable["VanSeatsAirportShuttle"] = NewCarTuningTable["VanSeats"]
	NewCarTuningTable["VanSeats_Prison"] = NewCarTuningTable["VanSeats"]

	NewCarTuningTable["VanRadio_3N"] = NewCarTuningTable["VanRadio"]
	NewCarTuningTable["VanAmbulance"] = NewCarTuningTable["VanRadio"]


	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionWindowRearLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionWindowRearRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "CarNormal", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionTrunk")
	SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionDoorRearLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionDoorRearRight")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "CarNormal", "ATA2InteractiveTrunkRoofRack")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "CarNormal", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "CarNormal", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "CarNormal", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "CarNormal", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionWindowRearLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionWindowRearRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionTrunk")
	SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionDoorRearLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionDoorRearRight")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "CarLightsRanger", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionWindowRearLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionWindowRearRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionTrunk")
	SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionDoorRearLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionDoorRearRight")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2InteractiveTrunkRoofRack")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "CarStationWagon", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionWindowRearLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionWindowRearRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "SmallCar", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionTrunk")
	SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "SmallCar", "ATA2InteractiveTrunkRoofRack")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "SmallCar", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "SmallCar", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "SmallCar", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "SmallCar", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2ProtectionTrunk")
	SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2InteractiveTrunkRoofRack")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "SmallCar02", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionTrunk")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionTrunk")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2InteractiveTrunkRoofRack")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "Van", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "Van", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "Van", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "Van", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "Van", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "Van", "ATA2ProtectionDoorsRear")
	SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "Van", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "Van", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "Van", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "Van", "ATA2InteractiveTrunkRoofRack")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "Van", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "Van", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "Van", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "Van", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanRadio", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanRadio", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanRadio", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanRadio", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "VanRadio", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanRadio", "ATA2ProtectionDoorsRear")
	SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "VanRadio", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanRadio", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanRadio", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "VanRadio", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "VanRadio", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "VanRadio", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "VanRadio", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionWindowMiddleLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionWindowMiddleRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "VanSeats", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionDoorsRear")
	SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionDoorMiddleLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionDoorMiddleRight")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "VanSeats", "ATA2InteractiveTrunkRoofRack")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "VanSeats", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "VanSeats", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "VanSeats", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "VanSeats", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionWindowRearLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionWindowRearRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionTrunk")
	SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionDoorRearLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionDoorRearRight")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "CarLightsPolice", "ATA2Snorkel")

	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2ProtectionWindowFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2ProtectionWindowFrontRight")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2ProtectionWindshield")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2ProtectionWindshieldRear")
	SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2Bullbar")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2ProtectionTrunk")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2ProtectionHood")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2ProtectionDoorFrontLeft")
	SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2ProtectionDoorFrontRight")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2InteractiveTrunkRoofRack")
	SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2ProtectionWheels")
	SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2RoofLightFront")
	SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2AirScoop")
	SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "PickUpVanLightsPolice", "ATA2Snorkel")

	SVUC_setVehiclePickup(NewCarTuningTable, "PickUpTruck")

	ATA2Tuning_AddNewCars(NewCarTuningTable)

	return NewCarTuningTable
end
Events.OnInitGlobalModData.Add(SVUV_TuningTable)
