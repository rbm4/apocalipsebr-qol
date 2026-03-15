require "Vehicles/ISUI/ISVehicleMechanics";

local vanillaMechTooltipFn = ISVehicleMechanics["doMenuTooltip"];

ISVehicleMechanics["doMenuTooltip"] = function(self, part, option, lua, name)
	vanillaMechTooltipFn(self, part, option, lua, name);
	
	if lua == "uninstall" and part:getId() == "STP85Roofrack"
	then
		option.toolTip.description = option.toolTip.description .. " <LINE> " .. " <ORANGE> Remove Spare Tires, Gas Can, Tent and Generator to be able to uninstall this part."
	end

end