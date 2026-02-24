
local OfficialPerform = ISReadABook.perform
local OfficialisValid = ISReadABook.isValid


function CheckIfCanRead()
    return true
end


function ISReadABook:isValid()
	--if self.item:getFullType() == "Base.ApocalypseMagazineWood" then
	--	if not self.hasDisplayedMessage then
	--		self.character:Say(getText("IGUI_PlayerText_Read1"), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
	--		self.hasDisplayedMessage = true
	--	end
	--elseif self.item:getFullType() == "Base.ApocalypseMagazineMetal" then
	--	if not self.hasDisplayedMessage then
	--		self.character:Say(getText("IGUI_PlayerText_Read2"), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
	--		self.hasDisplayedMessage = true
	--	end
	--end

	return OfficialisValid(self)
end



function ISReadABook:perform(...)
	if self.item:getFullType() == "Base.ApocalypseMagazineWood" then
		if not self.hasDisplayedMessage then
			self.character:Say(getText("IGUI_PlayerText_Read1"), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
			self.hasDisplayedMessage = true
		end
	elseif self.item:getFullType() == "Base.ApocalypseMagazineMetal" then
		if not self.hasDisplayedMessage then
			self.character:Say(getText("IGUI_PlayerText_Read2"), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
			self.hasDisplayedMessage = true
		end
	elseif self.item:getFullType() == "Base.RaccoonCityPassWordBook" then
		local gameTime = getGameTime()
		local modData = gameTime:getModData()
		if (modData.strPassWord and modData.strPassWord == '') or not modData.strPassWord then -- 改为全局永久储存
		--if RaccoonCityPasswordData.strPassWord and RaccoonCityPasswordData.strPassWord == '' then 
			--RaccoonCityPasswordData.strPassWord = string.format("%06d", ZombRand(100000, 999999))
			-- 这样更均衡
			local num1 = ZombRand(0, 10)
			local num2 = ZombRand(0, 10)
			local num3 = ZombRand(0, 10)
			local num4 = ZombRand(0, 10)
			local num5 = ZombRand(0, 10)
			local num6 = ZombRand(0, 10)
			--RaccoonCityPasswordData.strPassWord = string.format("%d%d%d%d%d%d", num1,num2,num3,num4,num5,num6)
			modData.strPassWord = string.format("%d%d%d%d%d%d", num1,num2,num3,num4,num5,num6)
		end 
		if not self.hasDisplayedMessage then
			if modData.strPassWord and modData.strPassWord ~= '' then
			--if RaccoonCityPasswordData.strPassWord and RaccoonCityPasswordData.strPassWord ~= '' then 
				--local stySay = getText("IGUI_PlayerText_PassWord") .. RaccoonCityPasswordData.strPassWord
				local stySay = getText("IGUI_PlayerText_PassWord") .. modData.strPassWord
				self.character:Say(stySay , 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
				self.hasDisplayedMessage = true
			end 
		end
	end

	return OfficialPerform(self, ...)
end
