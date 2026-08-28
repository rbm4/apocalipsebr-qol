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

SetArmor("ATAPetyarbuilt","SVU_Armor_ATAPetyarbuilt");
SetArmor("ATAPetyarbuiltSleeper","SVU_Armor_ATAPetyarbuilt");
SetArmor("ATAPetyarbuiltSleeperLong","SVU_Armor_ATAPetyarbuilt");
SetArmor("ATAPetyarbuiltJoker","SVU_Armor_ATAPetyarbuilt");
SetArmor("TrailerTSMega","SVU_Armor_TrailerTSMega");
SetArmor("TrailerTSMegaJoker","SVU_Armor_TrailerTSMega");
SetArmor("TrailerTSMegaAnimal","SVU_Armor_TrailerTSMega");
