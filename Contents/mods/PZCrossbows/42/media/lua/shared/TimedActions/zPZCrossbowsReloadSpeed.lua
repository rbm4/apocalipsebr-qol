require "TimedActions/ISReloadWeaponAction"

local PZC_CrossbowTypes = {
	["PZCrossbows.Crossbow"] = true,
	["PZCrossbows.ImprovedCrossBow"] = true,
	["PZCrossbows.CompoundCrossBow"] = true,
	["PZCrossbows.HandCrossBow"] = true,
}

local PZC_originalSetReloadSpeed = ISReloadWeaponAction.setReloadSpeed

function ISReloadWeaponAction.setReloadSpeed(character, rack)
	PZC_originalSetReloadSpeed(character, rack)

	local gun = character:getPrimaryHandItem()
	if not gun or not PZC_CrossbowTypes[gun:getFullType()] then
		return
	end

	local quiver = character:getWornItem(ItemBodyLocation.AMMO_STRAP)
	if quiver and quiver:getFullType() == "PZCrossbows.BoltQuiver" then
		local speed = character:getVariableFloat("ReloadSpeed", 1.0)
		character:setVariable("ReloadSpeed", speed * 1.15)
	end
end
