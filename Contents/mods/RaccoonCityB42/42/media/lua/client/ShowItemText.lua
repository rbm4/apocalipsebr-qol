



-- 保存原始函数
BackpackCapacity_Render = BackpackCapacity_Render or ISToolTipInv.render

function ISToolTipInv:render()
	if not self.item then
		return BackpackCapacity_Render(self)
	end
	--print('item:',self.item)
	if instanceof(self.item, "FluidContainer") then
		return BackpackCapacity_Render(self)
	end 
	-- 检查是否是容器物品
	if self.item and self.item:getContainer() then
		local itemtype = self.item:getType()
		if itemtype == 'ResidentEvilBackPack' or itemtype == 'ResidentEvilSuspenders' then
			--print(itemtype)
			local nCapacity = 49
			local tips = ''
			if itemtype == 'ResidentEvilBackPack' then 
				nCapacity = SandboxVars.ResidentEvilBackpackCapacity
				tips = 'Tooltip_BackpackCapacity'
			elseif itemtype == 'ResidentEvilSuspenders' then 
				nCapacity = SandboxVars.ResidentEvilSuspendersCapacity
				tips = 'Tooltip_SuspendersCapacity'
			end 
			local capacityText = string.format("%s%d", getText(tips), nCapacity)
			
			
			-- 获取字体和行高
			local font = UIFont[getCore():getOptionTooltipFont()]
			local lineSpacing = self.tooltip:getLineSpacing()
			local height = self.tooltip:getHeight()
			
			local newHeight = height + lineSpacing
			
			-- 保存原始函数
			local old_setHeight = ISToolTipInv.setHeight
			self.setHeight  = function (self, h, ...)
				h = newHeight
				self.keepOnScreen = false
				return old_setHeight(self, h, ...)
			end
			
			-- 保存原始函数
			local old_drawRectBorder = ISToolTipInv.drawRectBorder
			self.drawRectBorder = function (self, ...)
				self.tooltip:DrawText(font, capacityText, 5, height, 1, 0, 0, 1)
				old_drawRectBorder(self, ...)
			end
			BackpackCapacity_Render(self)
			
			-- 还原
			self.setHeight = old_setHeight
			self.drawRectBorder = old_drawRectBorder
			return 
		end 
	end
	BackpackCapacity_Render(self)
end