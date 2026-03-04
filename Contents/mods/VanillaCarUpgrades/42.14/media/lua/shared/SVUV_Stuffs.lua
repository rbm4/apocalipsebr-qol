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

SetArmor("CarLightsRanger","SVU_Armor_CarLights");
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
SetArmor("PickUpVanLightsRanger","SVU_Armor_PickUpVan");
SetArmor("PickUpVanLightsFire","SVU_Armor_PickUpVan");
SetArmor("PickUpVanMccoy","SVU_Armor_PickUpVan");
SetArmor("PickUpVan","SVU_Armor_PickUpVan");
SetArmor("PickUpTruckLightsRanger","SVU_Armor_PickUpTruck");
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
SetArmor("Van_MassGenFac","SVU_Armor_Van");
SetArmor("Van_LectroMax","SVU_Armor_Van");
SetArmor("VanMail","SVU_Armor_Van");
SetArmor("VanRadio","SVU_Armor_VanAmbulance");
SetArmor("VanRadio_3N","SVU_Armor_VanAmbulance");
SetArmor("VanAmbulance","SVU_Armor_VanAmbulance");
SetArmor("SportsCar","SVU_Armor_SportsCar");


SetArmor("CarLightsPolice","SVU_Armor_CarLights");
SetArmor("CarLightsBulletinSheriff","SVU_Armor_CarLights");
SetArmor("CarLightsKST","SVU_Armor_CarLights");
SetArmor("CarLightsLouisvilleCounty","SVU_Armor_CarLights");
SetArmor("CarLightsMuldraughPolice","SVU_Armor_CarLights");

SetArmor("ModernCarLightsCityLouisvillePD","SVU_Armor_CarModernLights");
SetArmor("ModernCarLightsMeadeSheriff","SVU_Armor_CarModernLights");
SetArmor("ModernCarLightsWestPoint","SVU_Armor_CarModernLights");

SetArmor("PickUpVanLightsPolice","SVU_Armor_PickUpVan");
SetArmor("PickUpVanLightsLouisvilleCounty","SVU_Armor_PickUpVan");
SetArmor("PickUpVanLightsStatePolice","SVU_Armor_PickUpVan");

SetArmor("StepVan_LouisvilleSWAT","SVU_Armor_StepVan");

SetArmor("PickUpTruckLightsAirport","SVU_Armor_PickUpTruck");
SetArmor("PickUpTruckLightsAirportSecurity","SVU_Armor_PickUpTruck");
SetArmor("PickUpTruckLightsFossoil","SVU_Armor_PickUpTruck");

SetArmor("PickUpVanLightsFossoil","SVU_Armor_PickUpVan");
SetArmor("PickUpVanLightsKentuckyLumber","SVU_Armor_PickUpVan");
SetArmor("PickUpVanLightsCarpenter","SVU_Armor_PickUpVan");


SetArmor("VanRosewoodworking","SVU_Armor_Van");
SetArmor("VanSchwabSheetMetal","SVU_Armor_Van");
SetArmor("VanTreyBaines","SVU_Armor_Van");
SetArmor("VanUncloggers","SVU_Armor_Van");
SetArmor("Van_VoltMojo","SVU_Armor_Van");
SetArmor("VanWPCarpentry","SVU_Armor_Van");
SetArmor("VanBeckmans","SVU_Armor_Van");
SetArmor("VanBrewsterHarbin","SVU_Armor_Van");
SetArmor("Van_BugWipers","SVU_Armor_Van");
SetArmor("Van_Charlemange_Beer","SVU_Armor_Van");
SetArmor("VanCoastToCoast","SVU_Armor_Van");
SetArmor("VanDeerValley","SVU_Armor_Van");
SetArmor("VanFossoil","SVU_Armor_Van");
SetArmor("VanGardenGods","SVU_Armor_Van");
SetArmor("VanGreenes","SVU_Armor_Van");
SetArmor("VanJohnMcCoy","SVU_Armor_Van");
SetArmor("VanJonesFabrication","SVU_Armor_Van");
SetArmor("VanKerrHomes","SVU_Armor_Van");
SetArmor("VanKnobCreekGas","SVU_Armor_Van");
SetArmor("VanKnoxCom","SVU_Armor_Van");
SetArmor("VanKorshunovs","SVU_Armor_Van");
SetArmor("VanLouisvilleLandscaping","SVU_Armor_Van");
SetArmor("VanMccoy","SVU_Armor_Van");
SetArmor("VanMeltingPointMetal","SVU_Armor_Van");
SetArmor("VanMetalheads","SVU_Armor_Van");
SetArmor("VanMicheles","SVU_Armor_Van");
SetArmor("VanMobileMechanics","SVU_Armor_Van");
SetArmor("VanMooreMechanics","SVU_Armor_Van");
SetArmor("VanOldMill","SVU_Armor_Van");
SetArmor("VanOvoFarm","SVU_Armor_Van");
SetArmor("VanPennSHam","SVU_Armor_Van");
SetArmor("Van_Perfick_Potato","SVU_Armor_Van");
SetArmor("VanPlattAuto","SVU_Armor_Van");
SetArmor("VanPluggedInElectrics","SVU_Armor_Van");
SetArmor("VanRiversideFabrication","SVU_Armor_Van");
SetArmor("VanBuilder","SVU_Armor_Van");
SetArmor("VanGardener","SVU_Armor_Van");
SetArmor("VanCarpenter","SVU_Armor_Van");
SetArmor("VanMechanic","SVU_Armor_Van");
SetArmor("VanMetalworker","SVU_Armor_Van");
SetArmor("VanUtility","SVU_Armor_Van");
SetArmor("VanSeats_Creature","SVU_Armor_Van");
SetArmor("VanSeats_LadyDelighter","SVU_Armor_Van");
SetArmor("VanSeats_Mural","SVU_Armor_Van");
SetArmor("VanSeats_Space","SVU_Armor_Van");
SetArmor("VanSeats_Trippy","SVU_Armor_Van");
SetArmor("VanSeats_Valkyrie","SVU_Armor_Van");
SetArmor("Van_Blacksmith","SVU_Armor_Van");
SetArmor("Van_CraftSupplies","SVU_Armor_Van");
SetArmor("Van_Glass","SVU_Armor_Van");
SetArmor("Van_HeritageTailors","SVU_Armor_Van");
SetArmor("Van_Leather","SVU_Armor_Van");
SetArmor("Van_Locksmith","SVU_Armor_Van");
SetArmor("Van_Masonry","SVU_Armor_Van");

SetArmor("VanSeatsAirportShuttle","SVU_Armor_VanSeats");
SetArmor("VanSeats_Prison","SVU_Armor_VanSeats");

SetArmor("PickUpTruckJPLandscaping","SVU_Armor_PickUpTruck");
SetArmor("PickUpTruck_Camo","SVU_Armor_PickUpTruck");

SetArmor("PickUpVanBrickingIt","SVU_Armor_PickUpVan");
SetArmor("PickUpVanCallowayLandscaping","SVU_Armor_PickUpVan");
SetArmor("PickUpVanHeltonMetalWorking","SVU_Armor_PickUpVan");
SetArmor("PickUpVanKimbleKonstruction","SVU_Armor_PickUpVan");
SetArmor("PickUpVanMarchRidgeConstruction","SVU_Armor_PickUpVan");
SetArmor("PickUpVanWeldingbyCamille","SVU_Armor_PickUpVan");
SetArmor("PickUpVanYingsWood","SVU_Armor_PickUpVan");
SetArmor("PickUpVanMetalworker","SVU_Armor_PickUpVan");
SetArmor("PickUpVanBuilder","SVU_Armor_PickUpVan");
SetArmor("PickUpVan_Camo","SVU_Armor_PickUpVan");

SetArmor("StepVanAirportCatering","SVU_Armor_StepVan");
SetArmor("StepVan_Cereal","SVU_Armor_StepVan");
SetArmor("StepVan_Citr8","SVU_Armor_StepVan");
SetArmor("StepVan_CompleteRepairShop","SVU_Armor_StepVan");
SetArmor("StepVan_Genuine_Beer","SVU_Armor_StepVan");
SetArmor("StepVan_HuangsLaundry","SVU_Armor_StepVan");
SetArmor("StepVan_Jorgensen","SVU_Armor_StepVan");
SetArmor("StepVan_LouisvilleMotorShop","SVU_Armor_StepVan");
SetArmor("StepVan_MarineBites","SVU_Armor_StepVan");
SetArmor("StepVan_Plonkies","SVU_Armor_StepVan");
SetArmor("StepVan_RandisPlants","SVU_Armor_StepVan");
SetArmor("StepVan_SouthEasternHosp","SVU_Armor_StepVan");
SetArmor("StepVan_SouthEasternPaint","SVU_Armor_StepVan");
SetArmor("StepVan_USL","SVU_Armor_StepVan");
SetArmor("StepVan_Zippee","SVU_Armor_StepVan");
SetArmor("StepVan_Mechanic","SVU_Armor_StepVan");
SetArmor("StepVan_Florist","SVU_Armor_StepVan");
SetArmor("StepVan_Glass","SVU_Armor_StepVan");
SetArmor("StepVan_Butchers","SVU_Armor_StepVan");
SetArmor("StepVan_Blacksmith","SVU_Armor_StepVan");
SetArmor("StepVan_Masonry","SVU_Armor_StepVan");
SetArmor("StepVan_MobileLibrary","SVU_Armor_StepVan");
SetArmor("StepVan_SmartKut","SVU_Armor_StepVan");
