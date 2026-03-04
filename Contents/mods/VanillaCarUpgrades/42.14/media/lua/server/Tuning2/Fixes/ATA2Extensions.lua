if not ATATuning2 then ATATuning2 = {} end
if not ATATuning2.Create then ATATuning2.Create = {} end
if not ATATuning2.Init then ATATuning2.Init = {} end
if not ATATuning2.UninstallComplete then ATATuning2.UninstallComplete = {} end
if not ATATuning2.InstallComplete then ATATuning2.InstallComplete = {} end

function SetHoodScooped(hood, isScooped)
	if (not hood) then	
--		print("VVA_SVU3: SetHoodScooped - Hood: FALSE.");
		return false;
	end
	hood:setModelVisible("ReAnchor", false);
	if (isScooped) then
--		print("VVA_SVU3: SetHoodScooped - Hood: TRUE. isScooped: TRUE");

		hood:setModelVisible("Default", false);
		hood:setModelVisible("Scooped", true);
	else
--		print("VVA_SVU3: SetHoodScooped - Hood: TRUE. isScooped: FALSE");

		hood:setModelVisible("Scooped", false);
		hood:setModelVisible("Default", true);	
	end
	hood:setModelVisible("ReAnchor", true);
end

function SetModelAnchor(part) 
	local modData = part:getModData();
	if not modData or not modData.tuning2 or not modData.tuning2.model then	
		part:setModelVisible("anchorNormal", false);
		part:setModelVisible("anchorRusted", false);
	else
		print("VVA_SVU3: ATATuning2.InstallComplete.AnchorTuning - Installed:" .. modData.tuning2.model);
		part:setModelVisible(modData.tuning2.model, false);
		if string.find(modData.tuning2.model, "Rusted") then
			part:setModelVisible("anchorNormal", false);
			part:setModelVisible("anchorRusted", true);
		else
			part:setModelVisible("anchorNormal", true);
			part:setModelVisible("anchorRusted", false);
		end
		part:setModelVisible(modData.tuning2.model, true);		
	end
end

function ATATuning2.InstallComplete.AirScoop(vehicle, part)
	ATATuning2.InstallComplete.Tuning(vehicle, part);
	local hood = vehicle:getPartById("EngineDoor");
	if hood and hood:getInventoryItem() then 
		SetHoodScooped(hood,true);
--	else
--		print("VVA_SVU3: ATATuning2.InstallComplete.AirScoop - No hood installed.");
	end
end

function ATATuning2.UninstallComplete.AirScoop(vehicle, part, item)
	ATATuning2.UninstallComplete.Tuning(vehicle, part, item);
	local hood = vehicle:getPartById("EngineDoor");
	if hood and hood:getInventoryItem() then 
		SetHoodScooped(hood, false);
--	else
--		print("VVA_SVU3: ATATuning2.UninstallComplete.AirScoop - No hood installed.");
	end
end

function ATATuning2.Create.ScoopedHood(vehicle, part)
	Vehicles.Create.Default(vehicle, part);
	if not part or not part:getInventoryItem() then 
--		print("VVA_SVU3: ATATuning2.Create.ScoopedHood - No hood installed.");
		return false; 
	end
	local scoop = vehicle:getPartById("ATA2AirScoop");
	SetHoodScooped(part, not(not scoop or not scoop:getInventoryItem()));
end

function ATATuning2.Init.ScoopedHood(vehicle, part,a3,a4)
	Vehicles.Init.Door(vehicle, part,a3,a4);
	if not part or not part:getInventoryItem() then 
--		print("VVA_SVU3: ATATuning2.Init.ScoopedHood - No hood installed.");
		return false; 
	end
	local scoop = vehicle:getPartById("ATA2AirScoop");
	SetHoodScooped(part, not(not scoop or not scoop:getInventoryItem()));
end

function ATATuning2.InstallComplete.ScoopedHood(vehicle, part)
	Vehicles.InstallComplete.Door(vehicle, part);
	local scoop = vehicle:getPartById("ATA2AirScoop");
	SetHoodScooped(part, not(not scoop or not scoop:getInventoryItem()));
end
function ATATuning2.UninstallComplete.ScoopedHood(vehicle, part,item)
	Vehicles.UninstallComplete.Door(vehicle, part,item);
	part:setModelVisible("Default", false);
	part:setModelVisible("Scooped", false);
end

function ATATuning2.Create.AnchorTuning(vehicle, part)
	ATATuning2.Create.Tuning(vehicle, part);
	SetModelAnchor(part);
end

function ATATuning2.Init.AnchorTuning(vehicle, part)
	ATATuning2.Init.Tuning(vehicle, part);
	SetModelAnchor(part);
end

function ATATuning2.InstallComplete.AnchorTuning(vehicle, part)
	ATATuning2.InstallComplete.Tuning(vehicle, part);
	local modData = part:getModData();
	SetModelAnchor(part);
end

function ATATuning2.UninstallComplete.AnchorTuning(vehicle, part,item)
	ATATuning2.UninstallComplete.Tuning(vehicle, part,item);
	part:setModelVisible("anchorNormal", false);
	part:setModelVisible("anchorRusted", false);
end