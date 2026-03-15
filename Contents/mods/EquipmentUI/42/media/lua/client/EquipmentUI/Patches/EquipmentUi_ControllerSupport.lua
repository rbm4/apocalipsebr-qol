local OPT = require("EquipmentUI/Settings")

-- Cleanup when switching inputs
Events.OnGameBoot.Add(function()
    local og_removeInventoryUI = removeInventoryUI
    function removeInventoryUI(id)
        local data = getPlayerData(id);
        if data and data.playerInventory then
            data.playerInventory:destroyEquipmentUi()
        end
        og_removeInventoryUI(id)
    end
end)

-- Toggle the UI when pressing the select button on the controller
local og_ISInventoryPage_onJoypadDown = ISInventoryPage.onJoypadDown
---@diagnostic disable-next-line: duplicate-set-field
function ISInventoryPage:onJoypadDown(button)
    og_ISInventoryPage_onJoypadDown(self, button)

    local inventoryPage = getPlayerInventory(self.player)
    if button == OPT.TOGGLE_UI_CONTROLLER_BIND then
        if OPT.InventoryTetris then
            if inventoryPage.equipmentUi.isClosed then
                self:toggleEquipmentUIForController()
            end 
            setJoypadFocus(self.player, inventoryPage.equipmentUi);
        else
            self:toggleEquipmentUIForController()
        end
    end
end

-- Resize UIs when toggling the equipment UI
local standAloneOpen = false
function ISInventoryPage:toggleEquipmentUIForController()
    local inventoryPage = getPlayerInventory(self.player)
    local lootPage = getPlayerLoot(self.player)
    local equipmentUi = inventoryPage.equipmentUi
    if not equipmentUi then return end

    equipmentUi.isClosed = not equipmentUi.isClosed
    equipmentUi:setVisible(not equipmentUi.isClosed)

    -- Only resize the loot ui for layouts where the loot inventory is to the right of the player inventory and aligned with it without a large gap between them
    local resizeLoot = 
        lootPage:getY() == inventoryPage:getY() and 
        lootPage:getHeight() == inventoryPage:getHeight() and
        lootPage:getX() > inventoryPage:getX() and
        lootPage:getX() - (inventoryPage:getX() + inventoryPage:getWidth()) < 200


    -- Don't resize the UIs if the equipment UI is undocked
    if not equipmentUi.isDocked then
        return
    end

    local x = getPlayerScreenLeft(self.player)
    local w = 0

    -- If we're opening the equipment UI and there's enough space to do so, just open it
    if not equipmentUi.isClosed and inventoryPage:getX() - equipmentUi:getWidth() > x then
        standAloneOpen = true
        return
    end

    if standAloneOpen then
        standAloneOpen = false
        return -- Just close the equipment UI without resizing the other UIs
    end


    if not resizeLoot then
        x = inventoryPage:getX()
        w = inventoryPage:getWidth()
    else
        x = inventoryPage:getX()
        w = lootPage:getX() + lootPage:getWidth() - x
    end

    if not equipmentUi.isClosed then
        x = x + equipmentUi:getWidth()
        w = w - equipmentUi:getWidth()
    else
        x = x - equipmentUi:getWidth()
        w = w + equipmentUi:getWidth()
    end

    if resizeLoot then
        inventoryPage:setWidth(w/2)
        inventoryPage:setX(x)
        lootPage:setWidth(w/2)
        lootPage:setX(x + w/2)
    else
        inventoryPage:setWidth(w)
        inventoryPage:setX(x)
    end
end

--  Handle switching focus between the inventories and equipment UIs
local og_ISInventoryPage_onJoypadDirLeft = ISInventoryPage.onJoypadDirLeft
---@diagnostic disable-next-line: duplicate-set-field
function ISInventoryPage:onJoypadDirLeft(joypadData)
    og_ISInventoryPage_onJoypadDirLeft(self, joypadData)
    if self == getPlayerInventory(self.player) then
        if self.equipmentUi:isVisible() then
            setJoypadFocus(self.player, self.equipmentUi);
        end
    end
end

local og_ISInventoryPage_onJoypadDirRight = ISInventoryPage.onJoypadDirRight
---@diagnostic disable-next-line: duplicate-set-field
function ISInventoryPage:onJoypadDirRight(joypadData)
    og_ISInventoryPage_onJoypadDirRight(self, joypadData)
    if self == getPlayerLoot(self.player) then
        local equipmentUi = getPlayerInventory(self.player).equipmentUi
        if equipmentUi:isVisible() then
            setJoypadFocus(self.player, equipmentUi);
        end
    end
end

