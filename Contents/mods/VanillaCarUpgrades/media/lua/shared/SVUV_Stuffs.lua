---Like DoParam but for vehicles
---@param vehicle string Name of the vehicle script
---@param param string The parameter(s) to apply to this script
---@param module string Optional: the module of the vehicle
---@see Item#DoParam
---@see VehicleScript#Load
local DoVehicleParam = function(vehicle, param, module)
	module = module or "Base"
	local vehicleScript = ScriptManager.instance:getVehicle(module .. "." .. vehicle)
	if not vehicleScript then return end
	vehicleScript:Load(vehicle, "{" .. param .. "}")
end

---Utility to change the armor of a vehicle
---@param vehicle string Name of the vehicle script
---@param armor string Name of a armor template
---@see DoVehicleParam
local SetArmor = function(vehicle, armor, module)
	module = module or "Base"
	DoVehicleParam(vehicle, "template! = " .. armor .. ",")
end

---Utility to change the horn sound of a vehicle
---@param vehicle string Name of the vehicle script
---@param sound string Name of a sound
---@see DoVehicleParam
local SetHornSound = function(vehicle, sound)
	DoVehicleParam(vehicle, "sound { horn = " .. sound .. ",}")
end

if not getActivatedMods():contains("VVehicleEnhancer") and not getActivatedMods():contains("SCKCO") and not getActivatedMods():contains("VVSR_Continued") then
	SetArmor("CarLights","SVU_Armor_CarLights");
	SetArmor("CarLightsPolice","SVU_Armor_CarLights");
	SetArmor("CarNormal","SVU_Armor_CarNormal");
	SetArmor("CarTaxi","SVU_Armor_CarLights");
	SetArmor("CarTaxi2","SVU_Armor_CarLights");
	SetArmor("CarStationWagon","SVU_Armor_CarWagon");
	SetArmor("CarStationWagon2","SVU_Armor_CarWagon");
	SetArmor("ModernCar","SVU_Armor_CarModern");
	SetArmor("ModernCar02","SVU_Armor_CarModern2");
	SetArmor("CarLuxury","SVU_Armor_LuxuryCar");
	SetArmor("SmallCar","SVU_Armor_SmallCar");
	SetArmor("SmallCar02","SVU_Armor_SmallCar02");
	SetArmor("SUV","SVU_Armor_SUV");
	SetArmor("OffRoad","SVU_Armor_OffRoad");
	SetArmor("PickUpVanLights","SVU_Armor_PickUpVan");
	SetArmor("PickUpVanLightsPolice","SVU_Armor_PickUpVan");
	SetArmor("PickUpVanLightsFire","SVU_Armor_PickUpVan");
	SetArmor("PickUpVanMccoy","SVU_Armor_PickUpVan");
	SetArmor("PickUpVan","SVU_Armor_PickUpVan");
	SetArmor("PickUpTruckLights","SVU_Armor_PickUpTruck");
	SetArmor("PickUpTruckLightsFire","SVU_Armor_PickUpTruck");
	SetArmor("PickUpTruckMccoy","SVU_Armor_PickUpTruck");
	SetArmor("PickUpTruck","SVU_Armor_PickUpTruck");
	SetArmor("StepVan","SVU_Armor_StepVan");
	SetArmor("StepVan_Heralds","SVU_Armor_StepVan");
	SetArmor("StepVanMail","SVU_Armor_StepVan");
	SetArmor("StepVan_Scarlet","SVU_Armor_StepVan");
	SetArmor("VanSeats","SVU_Armor_VanSeats");
	SetArmor("Van","SVU_Armor_Van");
	SetArmor("Van_KnoxDisti","SVU_Armor_Van");
	SetArmor("Van_Transit","SVU_Armor_Van");
	SetArmor("VanSpiffo","SVU_Armor_Van");
	SetArmor("VanSpecial","SVU_Armor_Van");
	SetArmor("Van_MassGenFac","SVU_Armor_Van");
	SetArmor("Van_LectroMax","SVU_Armor_Van");
	SetArmor("VanRadio","SVU_Armor_VanAmbulance");
	SetArmor("VanRadio_3N","SVU_Armor_VanAmbulance");
	SetArmor("VanAmbulance","SVU_Armor_VanAmbulance");
	SetArmor("SportsCar","SVU_Armor_SportsCar");
end
if getActivatedMods():contains("VVehicleEnhancer") and not getActivatedMods():contains("SCKCO") and not getActivatedMods():contains("VVSR_Continued") then
	SetArmor("CarLights","SVU_Armor_CarLights_VVE");
	SetArmor("CarLightsPolice","SVU_Armor_CarLights_VVE");
	SetArmor("CarNormal","SVU_Armor_CarNormal_VVE");
	SetArmor("CarTaxi","SVU_Armor_CarTaxi_VVE");
	SetArmor("CarTaxi2","SVU_Armor_CarTaxi_VVE");
	SetArmor("CarStationWagon","SVU_Armor_CarWagon_VVE");
	SetArmor("CarStationWagon2","SVU_Armor_CarWagon_VVE");
	SetArmor("ModernCar","SVU_Armor_CarModern_VVE");
	SetArmor("ModernCar02","SVU_Armor_CarModern2_VVE");
	SetArmor("CarLuxury","SVU_Armor_LuxuryCar_VVE");
	SetArmor("SmallCar","SVU_Armor_SmallCar_VVE");
	SetArmor("SmallCar02","SVU_Armor_SmallCar02_VVE");
	SetArmor("SUV","SVU_Armor_SUV_VVE");
	SetArmor("OffRoad","SVU_Armor_OffRoad_VVE");
	SetArmor("PickUpVanLights","SVU_Armor_PickUpVan2_VVE");
	SetArmor("PickUpVanLightsPolice","SVU_Armor_PickUpVan_VVE");
	SetArmor("PickUpVanLightsFire","SVU_Armor_PickUpVan_VVE");
	SetArmor("PickUpVanMccoy","SVU_Armor_PickUpVan2_VVE");
	SetArmor("PickUpVan","SVU_Armor_PickUpVan_VVE");
	SetArmor("PickUpTruckLights","SVU_Armor_PickUpTruck_VVE");
	SetArmor("PickUpTruckLightsFire","SVU_Armor_PickUpTruck_VVE");
	SetArmor("PickUpTruckMccoy","SVU_Armor_PickUpTruck_VVE");
	SetArmor("PickUpTruck","SVU_Armor_PickUpTruck_VVE");
	SetArmor("StepVan","SVU_Armor_StepVan_VVE");
	SetArmor("StepVan_Heralds","SVU_Armor_StepVan_VVE");
	SetArmor("StepVanMail","SVU_Armor_StepVan_VVE");
	SetArmor("StepVan_Scarlet","SVU_Armor_StepVan_VVE");
	SetArmor("VanSeats","SVU_Armor_VanSeats_VVE");
	SetArmor("Van","SVU_Armor_Van_VVE");
	SetArmor("Van_KnoxDisti","SVU_Armor_Van_VVE");
	SetArmor("Van_Transit","SVU_Armor_Van_VVE");
	SetArmor("VanSpiffo","SVU_Armor_Van_VVE");
	SetArmor("VanSpecial","SVU_Armor_Van_VVE");
	SetArmor("Van_MassGenFac","SVU_Armor_Van_VVE");
	SetArmor("Van_LectroMax","SVU_Armor_Van_VVE");
	SetArmor("VanRadio","SVU_Armor_VanAmbulance_VVE");
	SetArmor("VanRadio_3N","SVU_Armor_VanAmbulance_VVE");
	SetArmor("VanAmbulance","SVU_Armor_VanAmbulance_VVE");
	SetArmor("SportsCar","SVU_Armor_SportsCar_VVE");

	SetArmor("CarOldsFull","SVU_Armor_CarNormal_VVE");
	SetArmor("CarNormalPoncho","SVU_Armor_CarNormal_VVE");
	SetArmor("CarLightsStatepolice","SVU_Armor_CarLights_VVE");
	SetArmor("CarLightsSheriff","SVU_Armor_CarLights_VVE");
	SetArmor("CarLightsFireDept","SVU_Armor_CarLights_VVE");
	SetArmor("CarLightsFireDept2","SVU_Armor_CarLights_VVE");
	SetArmor("CarOldWagon","SVU_Armor_CarWagon_VVE");
	SetArmor("CarPonchoWagon","SVU_Armor_CarWagon_VVE");
	SetArmor("PickUpVanf76","SVU_Armor_PickUpVan3_VVE");
	SetArmor("PickUpTruckf76","SVU_Armor_PickUpTruck2_VVE");
	SetArmor("73cayenne","SVU_Armor_PickUpTruck");
	SetArmor("Vanateam","SVU_Armor_VanSeats_VVE");
	SetArmor("Vanboogie","SVU_Armor_VanSeats_VVE");
	SetArmor("Boltrs","SVU_Armor_SmallCar_VVE");
	SetArmor("SmallCarSwiffer","SVU_Armor_SmallCar02_VVE");
	SetArmor("280sport","SVU_Armor_CarModern2_VVE");
end
if getActivatedMods():contains("TallerMecanico") then
	SetArmor("VanSnakeneta","SVU_Armor_Van");
	SetArmor("VanGenova","SVU_Armor_Van");
--		SetArmor("CarTaxiArg","SVU_Armor_CarModern2");
	SetArmor("StepVan_Nubasian","SVU_Armor_StepVan");
end
if getActivatedMods():contains("DashRoamer") then
	SetArmor("DashRoamer","SVU_Armor_DashRoamer");
end
if getActivatedMods():contains("MysteryMachineOGSN") then
	SetArmor("VanMysterymachine","SVU_Armor_Van");
end
if getActivatedMods():contains("STFRCore") then
	SetArmor("VanPrison","SVU_Armor_Van");
	SetArmor("StepVanSwat","SVU_Armor_StepVan");

	SetArmor("CarLightsSecurity","SVU_Armor_CarLights");
	SetArmor("PickUpVanLightsSecurity","SVU_Armor_PickUpVan");

	SetArmor("CarLightsPoliceK9","SVU_Armor_CarLights");
	SetArmor("CarLightsPoliceSupervisor","SVU_Armor_CarLights");
end
if getActivatedMods():contains("PzkVanillaPlusCarPack") and getActivatedMods():contains("STFRCorePZKA") then
	SetArmor("pzkFranklinTriumphSecurity","SVU_Armor_pzkFranklinTriumphLights");
	SetArmor("pzkFranklinTriumphTWDSecurity","SVU_Armor_pzkDashRapierLights");
	SetArmor("pzkDashMayorSecurity","SVU_Armor_pzkDashMayorLights");
	SetArmor("pzkChevalierCeriseSedanSecurity","SVU_Armor_pzkDashRapierLights");
	SetArmor("pzkChevalierCerise93Security","SVU_Armor_pzkFranklinTriumphLights");
	SetArmor("pzkFranklinGalloperSecurity","SVU_Armor_pzkFranklinGalloperLights");
	SetArmor("pzkChevalierLaserSecurity","SVU_Armor_pzkFranklinGalloperLights");

	SetArmor("pzkFranklinTriumphPoliceK9","SVU_Armor_pzkFranklinTriumphLights");
	SetArmor("pzkFranklinTriumphTWDPoliceK9","SVU_Armor_pzkDashRapierLights");
	SetArmor("pzkDashMayorPoliceK9","SVU_Armor_pzkDashMayorLights");
	SetArmor("pzkChevalierCeriseSedanPoliceK9","SVU_Armor_pzkDashRapierLights");
	SetArmor("pzkChevalierCerise93PoliceK9","SVU_Armor_pzkFranklinTriumphLights");

	SetArmor("pzkFranklinTriumphPoliceSupervisor","SVU_Armor_pzkFranklinTriumphLights");
	SetArmor("pzkFranklinTriumphTWDPoliceSupervisor","SVU_Armor_pzkDashRapierLights");
	SetArmor("pzkDashMayorPoliceSupervisor","SVU_Armor_pzkDashMayorLights");
	SetArmor("pzkChevalierCeriseSedanPoliceSupervisor","SVU_Armor_pzkDashRapierLights");
	SetArmor("pzkChevalierCerise93PoliceSupervisor","SVU_Armor_pzkFranklinTriumphLights");
end
