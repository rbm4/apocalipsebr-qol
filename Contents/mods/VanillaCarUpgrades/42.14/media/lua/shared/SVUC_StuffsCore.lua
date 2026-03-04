---Like DoParam but for vehicles
---@param vehicle string Name of the vehicle script
---@param param string The parameter(s) to apply to this script
---@param module string Optional: the module of the vehicle
---@see Item#DoParam
---@see VehicleScript#Load
local function DoVehicleParam(vehicle, param, module)
	module = module or "Base"
	local vehicleScript = ScriptManager.instance:getVehicle(module .. "." .. vehicle)
	if not vehicleScript then return end
	vehicleScript:Load(vehicle, "{" .. param .. "}")
end

local SVUC = {}

---Utility to change the armor of a vehicle
---@param vehicle string Name of the vehicle script
---@param armor string Name of a armor template
---@see DoVehicleParam
function SVUC.SetArmor(vehicle, armor, module)
	module = module or "Base"
	DoVehicleParam(vehicle, "template! = " .. armor .. ",", module)
end

---Utility to change the horn sound of a vehicle
---@param vehicle string Name of the vehicle script
---@param sound string Name of a sound
---@see DoVehicleParam
function SVUC.SetHornSound(vehicle, sound, module)
	module = module or "Base"
	DoVehicleParam(vehicle, "sound { horn = " .. sound .. ",}", module)
end
return SVUC
