local pb = getModInfoByID("hf_point_blank")
if not pb or not isModActive(pb) then
    return
end
local ok = pcall(require, "hf_point_blank")
if not ok or not HF_PointBlank then
	return
end
HF_PointBlank.isCrossbow = function(weapon)
	if not weapon then
		return false
	end
	local ammoType = weapon:getAmmoType()
	if ammoType == nil then
		return false
	end
	ammoType = ammoType:toString()
	return ammoType == "PZCrossbows.WoodBolt" or
		ammoType == "PZCrossbows.ShortWoodBolt" or
		ammoType == "pzcrossbows:wood_bolt" or
		ammoType == "pzcrossbows:short_wood_bolt"
end
