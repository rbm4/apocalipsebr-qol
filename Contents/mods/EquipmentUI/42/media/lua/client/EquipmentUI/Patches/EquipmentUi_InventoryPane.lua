local c = require ("EquipmentUI/Settings")

local og_updateTooltip = ISInventoryPane.updateTooltip
---@diagnostic disable-next-line: duplicate-set-field
function ISInventoryPane:updateTooltip()
	local equipmentUi = self.parent.equipmentUi
	if self.parent:isMouseOverEquipmentUi() or (equipmentUi and equipmentUi.controllerNode.isFocused) then
		return self.parent.equipmentUi:updateTooltip()
	else
		og_updateTooltip(self)
	end
end

function ISInventoryPane:doTooltipForItem(item)
	if not self.parent:isVisible() then return end

    local weightOfStack = 0.0
	if item and not instanceof(item, "InventoryItem") then
		if #item.items > 2 then
			weightOfStack = item.weight
		end
		item = item.items[1]
	end

	local context = getPlayerContextMenu(self.player)
	if not context then return end

	if context:isAnyVisible() then
		item = nil
	end

	if item and self.toolRender and (item == self.toolRender.item) and
			(weightOfStack == self.toolRender.tooltip:getWeightOfStack()) and
			self.toolRender:isVisible() then
		return
	end

	if item and not ISMouseDrag.dragging then
		if self.toolRender then
			self.toolRender:setItem(item)
			self.toolRender:setVisible(true)
			self.toolRender:addToUIManager()
			self.toolRender:bringToTop()
		else
			self.toolRender = ISToolTipInv:new(item)
			self.toolRender:initialise()
			self.toolRender:addToUIManager()
			self.toolRender:setVisible(true)
			self.toolRender:setOwner(self)
			self.toolRender:setCharacter(getSpecificPlayer(self.player))
			self.toolRender.anchorBottomLeft = { x = self:getAbsoluteX() + self.column2, y = self:getParent():getAbsoluteY() }
		end
		self.toolRender.followMouse = not self.doController and not self.parent.equipmentUi.controllerNode.isFocused
		self.toolRender.tooltip:setWeightOfStack(weightOfStack)
	elseif self.toolRender then
		self.toolRender:removeFromUIManager()
		self.toolRender:setVisible(false)
	end

	-- Hack for highlighting doors when a Key tooltip is displayed.
	if self.parent.onCharacter then
		if not self.toolRender or not self.toolRender:getIsVisible() then
			item = nil
		end
		Key.setHighlightDoors(self.player, item)
	end

	local inventoryPage = getPlayerInventory(self.player)
	local inventoryTooltip = inventoryPage and inventoryPage.inventoryPane.toolRender
	local lootPage = getPlayerLoot(self.player)
	local lootTooltip = lootPage and lootPage.inventoryPane.toolRender

	---@diagnostic disable-next-line: param-type-mismatch
	UIManager.setPlayerInventoryTooltip(self.player, inventoryTooltip and inventoryTooltip.javaObject or nil, lootTooltip and lootTooltip.javaObject or nil)
end

-- Delay overriding the functions until the game starts, so we can make sure our changes are not overwritten by other mods
-- i.e. Alternative Inventory Rendering
local events_hooked = false
Events.OnGameStart.Add(function()
	if events_hooked then return end

	local og_renderdetails = ISInventoryPane.renderdetails
	---@diagnostic disable-next-line: duplicate-set-field
	function ISInventoryPane:renderdetails(doDragged)
		if not self.parent.onCharacter then
			og_renderdetails(self, doDragged)
			return
		end

		if self.doHideEquipped ~= c.HIDE_EQUIPPED_ITEMS then -- So the list is updated when the setting is changed
			self:refreshContainer()
		end

		if not c.HIDE_EQUIPPED_ITEMS then 
			self.doHideEquipped = false
			og_renderdetails(self, doDragged)
		else
			self.doHideEquipped = true
			self.itemslist = self.hideEquippedItemsList
			og_renderdetails(self, doDragged)
			self.itemslist = self.cachedItemList
		end
	end

	local og_refreshContainer = ISInventoryPane.refreshContainer
	---@diagnostic disable-next-line: duplicate-set-field
	function ISInventoryPane:refreshContainer()
		og_refreshContainer(self)
		if not self.parent.onCharacter then return end
		if c.InventoryTetris then return end

		self.cachedItemList = self.itemslist

		if not c.HIDE_EQUIPPED_ITEMS or not self.parent.onCharacter then return end

		local newlist = {}
		for k, v in ipairs(self.itemslist) do
			if v and not (v.equipped or v.inHotbar) then
				newlist[#newlist+1] = self.itemslist[k]
			end
		end
		self.hideEquippedItemsList = newlist
	end

	events_hooked = true
end)
