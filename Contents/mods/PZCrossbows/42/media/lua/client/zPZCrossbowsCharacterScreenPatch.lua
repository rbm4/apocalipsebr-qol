require "XpSystem/ISUI/ISCharacterScreen"

if ISCharacterScreen and ISCharacterScreen.loadFavouriteWeapon and not ISCharacterScreen.PZCrossbowsFavouriteWeaponPatched then
	local PZCrossbowsOriginalLoadFavouriteWeapon = ISCharacterScreen.loadFavouriteWeapon

	local function PZCrossbowsGetItemDisplayName(fullType)
		if not fullType or not string.find(fullType, "^PZCrossbows%.") then
			return fullType
		end
		local item = getItem(fullType)
		if item then
			return item:getDisplayName()
		end
		return fullType
	end

	ISCharacterScreen.loadFavouriteWeapon = function(self)
		PZCrossbowsOriginalLoadFavouriteWeapon(self)
		self.favouriteWeapon = PZCrossbowsGetItemDisplayName(self.favouriteWeapon)
	end

	ISCharacterScreen.PZCrossbowsFavouriteWeaponPatched = true
end
