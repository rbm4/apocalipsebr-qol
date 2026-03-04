require "ATA2TuningTable"
require "SVUC_TuningTable"

local function copy(obj, seen)
	if type(obj) ~= 'table' then return obj end
	if seen and seen[obj] then return seen[obj] end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
	return res
end

local function SVU_TuningTable()
	if not getActivatedMods():contains("SCKCO") and not getActivatedMods():contains("VVSR_Continued") then
		local TemplateTuningTable = SVUC_TemplateVehicle()
		local NewCarTuningTable = {}

		-- Entries
		NewCarTuningTable["CarNormal"] = {
			addPartsFromVehicleScript = "",
			parts = {}
		}
		NewCarTuningTable["CarLights"] = {
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

		if getActivatedMods():contains("DashRoamer") then
			NewCarTuningTable["DashRoamer"] = {
				addPartsFromVehicleScript = "",
				parts = {}
			}
		end
		if getActivatedMods():contains("PzkVanillaPlusCarPack") and getActivatedMods():contains("STFRCorePZKA") then
			NewCarTuningTable["pzkChevalierLaserSecurity"] = {
				addPartsFromVehicleScript = "",
				parts = {}
			}
		end

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
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionWindowRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionWindowRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
		NewCarTuningTable["CarLights"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionTrunk"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionDoorRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionDoorRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"])
		NewCarTuningTable["CarLights"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
		NewCarTuningTable["CarLights"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
		NewCarTuningTable["CarLights"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
		NewCarTuningTable["CarLights"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])


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
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].Light.protection = {"TruckBed", "GasTank"}
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].Heavy.protection = {"TruckBed", "GasTank"}
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].LightRusted.protection = {"TruckBed", "GasTank"}
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].HeavyRusted.protection = {"TruckBed", "GasTank"}
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].LightSpiked.protection = {"TruckBed", "GasTank"}
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].HeavySpiked.protection = {"TruckBed", "GasTank"}
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].LightSpikedRusted.protection = {"TruckBed", "GasTank"}
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].HeavySpikedRusted.protection = {"TruckBed", "GasTank"}
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].Reinforced.protection = {"TruckBed", "GasTank"}
		NewCarTuningTable["PickUpTruck"].parts["ATA2ProtectionTrunk"].ReinforcedRusted.protection = {"TruckBed", "GasTank"}
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

		NewCarTuningTable["CarLightsPolice"] = copy(NewCarTuningTable["CarLights"])
		NewCarTuningTable["CarLightsPolice"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarPolice"])

		NewCarTuningTable["PickUpVanLightsPolice"] = copy(NewCarTuningTable["PickUpVan"])
		NewCarTuningTable["PickUpVanLightsPolice"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarPoliceSUV"])

		NewCarTuningTable["ModernCar"] = NewCarTuningTable["CarNormal"]
		NewCarTuningTable["ModernCar02"] = NewCarTuningTable["CarNormal"]
		NewCarTuningTable["CarStationWagon2"] = NewCarTuningTable["CarStationWagon"]
		NewCarTuningTable["SUV"] = NewCarTuningTable["CarStationWagon"]
--		NewCarTuningTable["CarLightsPolice"] = NewCarTuningTable["CarLights"]
		NewCarTuningTable["CarTaxi"] = NewCarTuningTable["CarLights"]
		NewCarTuningTable["CarTaxi2"] = NewCarTuningTable["CarLights"]
		NewCarTuningTable["CarLuxury"] = NewCarTuningTable["SmallCar02"]
		NewCarTuningTable["SportsCar"] = NewCarTuningTable["SmallCar02"]
		NewCarTuningTable["OffRoad"] = NewCarTuningTable["SmallCar"]
		NewCarTuningTable["PickUpTruckMccoy"] = NewCarTuningTable["PickUpTruck"]
		NewCarTuningTable["PickUpTruckLightsFire"] = NewCarTuningTable["PickUpTruck"]
		NewCarTuningTable["PickUpTruckLights"] = NewCarTuningTable["PickUpTruck"]
		NewCarTuningTable["PickUpVanMccoy"] = NewCarTuningTable["PickUpVan"]
		NewCarTuningTable["PickUpVanLightsFire"] = NewCarTuningTable["PickUpVan"]
		NewCarTuningTable["PickUpVanLights"] = NewCarTuningTable["PickUpVan"]
		NewCarTuningTable["StepVan"] = NewCarTuningTable["Van"]
		NewCarTuningTable["StepVan_Heralds"] = NewCarTuningTable["Van"]
		NewCarTuningTable["StepVanMail"] = NewCarTuningTable["Van"]
		NewCarTuningTable["StepVan_Scarlet"] = NewCarTuningTable["Van"]
		NewCarTuningTable["Van_KnoxDisti"] = NewCarTuningTable["Van"]
		NewCarTuningTable["Van_Transit"] = NewCarTuningTable["Van"]
		NewCarTuningTable["VanSpiffo"] = NewCarTuningTable["Van"]
		NewCarTuningTable["VanSpecial"] = NewCarTuningTable["Van"]
		NewCarTuningTable["Van_MassGenFac"] = NewCarTuningTable["Van"]
		NewCarTuningTable["Van_LectroMax"] = NewCarTuningTable["Van"]
		NewCarTuningTable["VanRadio_3N"] = NewCarTuningTable["VanRadio"]
		NewCarTuningTable["VanAmbulance"] = NewCarTuningTable["VanRadio"]

		if getActivatedMods():contains("VVehicleEnhancer") then
			NewCarTuningTable["CarOldsFull"] = NewCarTuningTable["CarNormal"]
			NewCarTuningTable["CarNormalPoncho"] = NewCarTuningTable["CarNormal"]
			NewCarTuningTable["CarLightsStatepolice"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["CarLightsSheriff"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["CarLightsFireDept"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["CarLightsFireDept2"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["CarOldWagon"] = NewCarTuningTable["CarStationWagon"]
			NewCarTuningTable["CarPonchoWagon"] = NewCarTuningTable["CarStationWagon"]
			NewCarTuningTable["PickUpVanf76"] = NewCarTuningTable["PickUpVan"]
			NewCarTuningTable["PickUpTruckf76"] = NewCarTuningTable["PickUpTruck"]
			NewCarTuningTable["73cayenne"] = NewCarTuningTable["PickUpTruck"]
			NewCarTuningTable["Vanateam"] = NewCarTuningTable["VanSeats"]
			NewCarTuningTable["Vanboogie"] = NewCarTuningTable["VanSeats"]
			NewCarTuningTable["Boltrs"] = NewCarTuningTable["SmallCar"]
			NewCarTuningTable["SmallCarSwiffer"] = NewCarTuningTable["SmallCar02"]
			NewCarTuningTable["280sport"] = NewCarTuningTable["CarNormal"]
		end
		if getActivatedMods():contains("TallerMecanico") then
			NewCarTuningTable["VanSnakeneta"] = NewCarTuningTable["Van"]
			NewCarTuningTable["VanGenova"] = NewCarTuningTable["Van"]
	--		NewCarTuningTable["CarTaxiArg"] = NewCarTuningTable["CarNormal"]
			NewCarTuningTable["StepVan_Nubasian"] = NewCarTuningTable["StepVan"]
		end
		if getActivatedMods():contains("MysteryMachineOGSN") then
			NewCarTuningTable["VanMysterymachine"] = NewCarTuningTable["Van"]
		end

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

		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionWindowFrontLeft")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionWindowFrontRight")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionWindowRearLeft")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionWindowRearRight")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionWindshield")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionWindshieldRear")
		SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "CarLights", "ATA2Bullbar")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionTrunk")
		SVUC_setVehicleRecipesArmorHood(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionHood")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionDoorFrontLeft")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionDoorFrontRight")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionDoorRearLeft")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionDoorRearRight")
		SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "CarLights", "ATA2ProtectionWheels")
		SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "CarLights", "ATA2RoofLightFront")
		SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "CarLights", "ATA2AirScoop")
		SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "CarLights", "ATA2Snorkel")

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

		SVUC_setVehiclePickup(NewCarTuningTable, "PickUpTruck")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionWindowFrontLeft")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionWindowFrontRight")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionWindshield")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionWindshieldRear")
		SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2Bullbar")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionTrunk")
		SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpTruck", "ATA2ProtectionTrunk", {"TruckBedOpen", "GasTank"})
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

		if getActivatedMods():contains("DashRoamer") then
			-- DashRoamer
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionWindowRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
			NewCarTuningTable["DashRoamer"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionDoorsRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionDoorRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"])
			NewCarTuningTable["DashRoamer"].parts["ATA2InteractiveTrunkRoofRack"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"])
			NewCarTuningTable["DashRoamer"].parts["ATA2InteractiveTrunkRoofRack"].Default.containerCapacity = 100
			NewCarTuningTable["DashRoamer"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
			NewCarTuningTable["DashRoamer"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
			NewCarTuningTable["DashRoamer"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
			NewCarTuningTable["DashRoamer"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])

			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionWindowFrontLeft")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionWindowFrontRight")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionWindowRearRight")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionWindshield")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionWindshieldRear")
			SVUC_setVehicleRecipesBullbars(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2Bullbar")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionDoorsRear")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionHood")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionDoorFrontLeft")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionDoorFrontRight")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionDoorRearRight")
			SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2InteractiveTrunkRoofRack")
			SVUC_setVehicleRecipesWheels(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2ProtectionWheels")
			SVUC_setVehicleRecipesMods(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2RoofLightFront")
			SVUC_setVehicleRecipesScoops(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2AirScoop")
			SVUC_setVehicleRecipesSnorkels(NewCarTuningTable, carRecipe, "DashRoamer", "ATA2Snorkel")
		end
		if getActivatedMods():contains("VVehicleEnhancer") then
			-- VVE PickUpVan
			NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionWindowRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"])
			NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionWindowRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"])
			NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionDoorRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"])
			NewCarTuningTable["PickUpVan"].parts["ATA2ProtectionDoorRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"])

			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionWindowRearLeft")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionWindowRearRight")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionDoorRearLeft")
			SVUC_setVehicleRecipesArmor(NewCarTuningTable, carRecipe, "PickUpVan", "ATA2ProtectionDoorRearRight")
		end
		if getActivatedMods():contains("STFRCore") then
			NewCarTuningTable["VanPrison"] = NewCarTuningTable["Van"]
			NewCarTuningTable["StepVanSwat"] = NewCarTuningTable["Van"]

			NewCarTuningTable["CarLightsSecurity"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["PickUpVanLightsSecurity"] = NewCarTuningTable["PickUpVan"]

			NewCarTuningTable["CarLightsPoliceK9"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["CarLightsPoliceSupervisor"] = NewCarTuningTable["CarLights"]
		end
		if getActivatedMods():contains("PzkVanillaPlusCarPack") and getActivatedMods():contains("STFRCorePZKA") then
			-- pzkChevalierLaserSecurity
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionWindowFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionWindowRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionWindowRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionWindshield"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2Bullbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionTrunk"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionDoorFrontLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2RoofLightFront"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2ProtectionWheels"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2AirScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"])
			NewCarTuningTable["pzkChevalierLaserSecurity"].parts["ATA2Snorkel"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"])

			NewCarTuningTable["pzkFranklinTriumphSecurity"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkFranklinTriumphTWDSecurity"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkDashMayorSecurity"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkChevalierCeriseSedanSecurity"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkChevalierCerise93Security"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkFranklinGalloperSecurity"] = NewCarTuningTable["pzkChevalierLaserSecurity"]

			NewCarTuningTable["pzkFranklinTriumphPoliceK9"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkFranklinTriumphTWDPoliceK9"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkDashMayorPoliceK9"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkChevalierCeriseSedanPoliceK9"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkChevalierCerise93PoliceK9"] = NewCarTuningTable["CarLights"]

			NewCarTuningTable["pzkFranklinTriumphPoliceSupervisor"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkFranklinTriumphTWDPoliceSupervisor"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkDashMayorPoliceSupervisor"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkChevalierCeriseSedanPoliceSupervisor"] = NewCarTuningTable["CarLights"]
			NewCarTuningTable["pzkChevalierCerise93PoliceSupervisor"] = NewCarTuningTable["CarLights"]
		end
		ATA2Tuning_AddNewCars(NewCarTuningTable)
	end
end
Events.OnInitGlobalModData.Add(SVU_TuningTable)
