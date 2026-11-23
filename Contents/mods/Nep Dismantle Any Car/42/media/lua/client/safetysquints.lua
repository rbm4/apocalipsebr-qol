require "Vehicles/ISUI/ISVehicleMenu"
require "NepWrecks_DismantleAction"


--copies of some local functions from ISVehicleMenu.lua

local function predicateWeldingMask(item)
	return item:hasTag(ItemTag.WELDING_MASK) or item:getType() == "WeldingMask"
end

local function comparatorDrainableUsesInt(item1, item2)
	return item1:getCurrentUses() - item2:getCurrentUses()
end



-- remove Putting on the mask
NepOGISVehicleMenuonRemoveBurntVehicle=ISVehicleMenu.onRemoveBurntVehicle
function ISVehicleMenu.onRemoveBurntVehicle(player, vehicle)
	-- Client-side UX only.  The authoritative check is performed by the
	-- server immediately before ISRemoveBurntVehicle completes.
	if VehicleClaim and VehicleClaim.isClaimed and VehicleClaim.isClaimed(vehicle) then
		return
	end

	if luautils.walkAdj(player, vehicle:getSquare()) then
		ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), NepWrecks.isUsableTorch, true);
		if SandboxVars.NepWrecks.NeedMask then
			local mask = player:getInventory():getFirstEvalRecurse(predicateWeldingMask);
			if mask then
				ISInventoryPaneContextMenu.wearItem(mask, player:getPlayerNum());
			end
		end
		ISTimedActionQueue.add(ISRemoveBurntVehicle:new(player, vehicle));
	end
end

--Postfix patch to replace the disassemble wreck function
NepOGISVehicleMenuFillMenuOutsideVehicle=ISVehicleMenu.FillMenuOutsideVehicle
function ISVehicleMenu.FillMenuOutsideVehicle(player, context, vehicle, test)
	NepOGISVehicleMenuFillMenuOutsideVehicle(player, context, vehicle, test)  
	
	local playerObj = getSpecificPlayer(player)
	-- Remove the existing context menu entry for removing burnt vehicles, if it is present,.
		if context:getOptionFromName(getText("ContextMenu_RemoveBurntVehicle")) then context:removeOptionByName(getText("ContextMenu_RemoveBurntVehicle")) end
	-- add a remove burnt vehicle entry even if it is not burt/wrecked
	-- if  string.match(vehicle:getScript():getName(), "Burnt") or string.match(vehicle:getScript():getName(), "Smashed") then
	
	local isWreck = string.match(vehicle:getScript():getName(), "Burnt") or string.match(vehicle:getScript():getName(), "Smashed")
	local contextMenuText=getText("ContextMenu_NepRemoveIntactVehicle") -- "Dismantle Car"
	if isWreck then
		contextMenuText=getText("ContextMenu_RemoveBurntVehicle") -- "Dismantle Car Wreck", Vanill text
	end

	local option = context:addOption(contextMenuText, playerObj, ISVehicleMenu.onRemoveBurntVehicle, vehicle);
	local toolTip = ISToolTip:new();
	toolTip:initialise();
	toolTip:setVisible(false);
	option.toolTip = toolTip;
	toolTip:setName(contextMenuText);
	local toolTipText=getText("Tooltip_NepRemoveIntactVehicle") -- removes references to wrecks
	if isWreck then
		contextMenuText=getText("Tooltip_removeBurntVehicle") -- vanilla text 
	end	
	
	toolTip.description = toolTipText .. " <LINE> <LINE> ";

	-- ApocalipseClaimSystem integration: block dismantling any claimed vehicle
	if VehicleClaim and VehicleClaim.isClaimed and VehicleClaim.isClaimed(vehicle) then
		local ownerName = VehicleClaim.getOwnerName and VehicleClaim.getOwnerName(vehicle) or getText("Tooltip_NepVehicleClaimUnknownOwner")
		toolTip.description = toolTip.description .. " <LINE> <RGB:1,0,0> " .. getText("Tooltip_NepVehicleClaimedBy", ownerName)
		option.notAvailable = true
	end
	
	if SandboxVars.NepWrecks.NeedMask then
		if playerObj:getInventory():containsEvalRecurse(predicateWeldingMask) then
			toolTip.description = toolTip.description .. " <LINE> <RGB:1,1,1> " .. getItemNameFromFullType("Base.WeldingMask") .. " 1/1";
		else
			toolTip.description = toolTip.description .. " <LINE> <RGB:1,0,0> " .. getItemNameFromFullType("Base.WeldingMask") .. " 0/1";
			option.notAvailable = true;
		end
	else
		toolTip.description = toolTip.description .. " <LINE> <RGB:1,1,1> " .. getText("IGUI_NepSafetySquints") .. " 1/1";
	end				

	local blowTorch = playerObj:getInventory():getBestTypeEvalRecurse("Base.BlowTorch", comparatorDrainableUsesInt)
	if blowTorch then
		local blowTorchUseLeft = blowTorch:getCurrentUses();
		if blowTorchUseLeft >= SandboxVars.NepWrecks.FuelUsed then
			toolTip.description = toolTip.description .. " <LINE> <RGB:1,1,1> " .. getItemNameFromFullType("Base.BlowTorch") .. " " .. getText("ContextMenu_Uses") .. " " .. blowTorchUseLeft .. "/" .. SandboxVars.NepWrecks.FuelUsed;
		else
			toolTip.description = toolTip.description .. " <LINE> <RGB:1,0,0> " .. getItemNameFromFullType("Base.BlowTorch") .. " " .. getText("ContextMenu_Uses") .. " " .. blowTorchUseLeft .. "/" .. SandboxVars.NepWrecks.FuelUsed;
			option.notAvailable = true;
		end
	else
		toolTip.description = toolTip.description .. " <LINE> <RGB:1,0,0> " .. getItemNameFromFullType("Base.BlowTorch") .. " " .. getText("ContextMenu_Uses") .. " 0/" .. SandboxVars.NepWrecks.FuelUsed;
		option.notAvailable = true;
	end
	
	
end
