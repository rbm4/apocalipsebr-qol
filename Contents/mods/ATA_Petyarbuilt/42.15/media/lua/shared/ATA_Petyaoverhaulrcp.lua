-- Mod does not need to be dependent on Realistic Car Physics being installed:
local REALISTICCARPHYSICS_ENABLED = getActivatedMods():contains("RealisticCarPhysics")
print("W900 Overhaul: Realistic Car Physics detected: " .. tostring(REALISTICCARPHYSICS_ENABLED))
if REALISTICCARPHYSICS_ENABLED then
	print("W900 Overhaul: Adding Realistic Car Physics values for W900 and trailers.")
	local carData = require "Realistic_Car_Overhaul_Data"

	-- Engines sounds can be specified this way. 
	-- Engine Volume = engineSoundBias + Throttle * engineSoundMultipler. Same for exhaust. Allows engine sound to change with throttle. 
	-- the values here relate to Sound script names in Realistic Car Physics. You can add your own sound files for your vehicles. 
	-- Its mainly just here to show you how to do it. Engine1 through Engine4 are also predefined for you to use. 
	carData.engineValues["EnginePetya_new"] = 
	{
		engineSound = "W900_Engine",
		engineSoundRPM = 2500,
		engineSoundBias = 1.4,
		engineSoundMultipler = 0.5,

		exhaustSound = "W900_Exhaust",
		exhaustSoundBias = 0.2, 
		exhaustSoundMultipler = 0.8,

		crankSound = "W900_EngineStart",
		startSound = "W900_EngineCrank",
		
		engineTurnOff = "W900_EngineTurnOff"
	}

	--Use real life values here for horsepower and weight (kg). Note that 1 horsePower is equal 4 vanilla pz horsepower.
	--Most vanilla vehicles have 70~250hp in this overhaul, and 800~3000kg weight.
	--engineSound relates to the key used in carData.EngineValues[]

	--Petyarbuilt
	carData.vehicleValues["Base.ATAPetyarbuilt"] = {horsePower = 235, weight = 6152, cargo = 25, engineSound = "EnginePetya_new"}
	carData.vehicleValues["Base.ATAPetyarbuiltSleeper"] = {horsePower = 250, weight = 8631, cargo = 30, engineSound = "EnginePetya_new"}
	carData.vehicleValues["Base.ATAPetyarbuiltJoker"] = {horsePower = 420, weight = 8631, cargo = 75, engineSound = "EnginePetya_new"}
	carData.vehicleValues["Base.ATAPetyarbuiltSleeperLong"] = {horsePower = 270, weight = 9215, cargo = 35, engineSound = "EnginePetya_new"}


	-- Trailers
	carData.vehicleValues["Base.TrailerTSMega"] = {weight = 3140, cargo = 1500}
	carData.vehicleValues["Base.TrailerTSMegaJoker"] = {weight = 3140, cargo = 1500}
	carData.vehicleValues["Base.TrailerTSMegaAnimal"] = {weight = 3140, cargo = 900}
end
