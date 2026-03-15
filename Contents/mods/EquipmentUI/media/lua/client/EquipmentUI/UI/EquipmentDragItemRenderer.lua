require "ISUI/ISUIElement"
local c = require "EquipmentUI/Settings"

local BG_TEXTURE = getTexture("media/ui/equipmentui/ItemSlot.png")

EquipmentDragItemRenderer = ISUIElement:derive("DragItemRenderer")

function EquipmentDragItemRenderer:new(equipmentUi, inventoryPane, playerNum)
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self

    o.equipmentUi = equipmentUi
    o.inventoryPane = inventoryPane
    o.playerNum = playerNum

    return o
end

function EquipmentDragItemRenderer:prerender()
    self:bringToTop()
end

function EquipmentDragItemRenderer:render()
    if self.inventoryPane.dragging then
        return
    end

    local item = DragAndDrop.getDraggedItem()
    if not item then
        return
    end
    
    local lootPage = getPlayerLoot(self.playerNum)
    if self.inventoryPane.dragging or lootPage.inventoryPane.dragging then
        return
    end

    local x = self:getMouseX()
    local y = self:getMouseY()

    self:suspendStencil()
    self:renderItem(item, x, y)
    self:resumeStencil()
end

function EquipmentDragItemRenderer:renderItem(item, x, y)
    self:drawTextureCenteredAndSquare(item:getTex(), x, y, 32 * c.SCALE, 1, EquipmentSlot.getItemColor(item))
end