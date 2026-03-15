require "IS/UI/ISPanel"
local c = require "EquipmentUI/Settings"
local BG_TEXTURE = getTexture("media/ui/equipmentui/ItemSlot.png")
local BG_COLOR = {r=0.4, g=0.4, b=0.4}

HotbarSlot = ISPanel:derive("HotbarSlot");

function HotbarSlot:new(hotbar, equipmentUi, inventoryPane, playerNum)
    local o = ISPanel:new(50, 50, c.SUPER_SLOT_SIZE, c.SUPER_SLOT_SIZE);
	setmetatable(o, self)
    self.__index = self

    o.hotbar = hotbar;
    o.equipmentUi = equipmentUi;
    o.inventoryPane = inventoryPane;
    o.playerNum = playerNum;

	o.moveWithMouse = true;

    o.mouseDownX = 0;
    o.mouseDownY = 0;

	return o;
end

function HotbarSlot:initialise()
    ISPanel.initialise(self);
    NotlocControllerNode
        :injectControllerNode(self)
        :setJoypadDownHandler(self.controllerNodeOnJoypadDown)
end

function HotbarSlot:getItem()
   return self.hotbar.attachedItems[self.index] 
end

function HotbarSlot:prerender()
    if not self.index then
        return
    end

    local itemCount = 0;

    local color = self.controllerNode.isFocused and NotlocControllerNode.FOCUS_COLOR or BG_COLOR;

    self:drawRect(0, 0, c.SUPER_SLOT_SIZE, c.SUPER_SLOT_SIZE, 0.65, 0, 0, 0);
    self:drawTextureScaled(BG_TEXTURE, 0, 0, c.SUPER_SLOT_SIZE, c.SUPER_SLOT_SIZE, 1, color.r, color.g, color.b);
    self:drawRectBorder(0, 0, c.SUPER_SLOT_SIZE, c.SUPER_SLOT_SIZE, 1, 1, 1, 1);

    local dragItem = DragAndDrop.getDraggedItem();
    if dragItem and dragItem ~= self:getItem() then
        if self:canAttachItem(dragItem) then
           local col = c.GOOD_COLOR
           if self:getItem() then
               col = c.MIDDLE_COLOR
           end
            self:drawRect(1, 1, c.SUPER_SLOT_SIZE - 2, c.SUPER_SLOT_SIZE - 2, 0.5, col.r, col.g, col.b);
        end
    end
end

function HotbarSlot:render()
    if not self.index then
        return
    end
    local item = self:getItem()

    --if the mouse is over the super slot, draw the name of the slot
    if self:isMouseOver() or self.controllerNode.isFocused then
        local slot = self.hotbar.availableSlot[self.index]
        if slot then
            local name = getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType) or slot.name;

            local width = getTextManager():MeasureStringX(UIFont.Small, name);
            local height = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight();

            local center = c.SUPER_SLOT_SIZE / 2


            if center - width / 2 + self.x < 0 then
                center = width / 2 + 3
            elseif center + width / 2 + self.x > self.parent:getWidth() then
                center = c.SUPER_SLOT_SIZE - width / 2 - 3
            end

            local x = center - width / 2 - 3
            local y = -height - 2

            self:drawRect(x, y, width + 8, height+4, 0.9, 0, 0, 0);
            self:drawRectBorder(x, y, width + 8, height+4, 1, 1, 1, 1);
            self:drawTextCentre(name, center, y, 1, 1, 1, 1, UIFont.Small);

            self:bringToTop();

            if item then
                self.equipmentUi:doTooltipForItem(self, item);
            end
        end
    end

    if not item then 
        return
    end

    local xOff = (c.SUPER_SLOT_SIZE - c.SLOT_SIZE) / 2;
    local yOff = (c.SUPER_SLOT_SIZE - c.SLOT_SIZE) / 2;
    local mainAlpha = 1;
    if item == DragAndDrop.getDraggedItem() then
        mainAlpha = 0.5;
    end
    self:drawTextureScaledUniform(item:getTex(), xOff, yOff, c.SCALE, mainAlpha, EquipmentSlot.getItemColor(item));
end


function HotbarSlot:onRightMouseUp(x, y)
    local item = self:getItem()
    if item then
        EquipmentSlot.openItemContextMenu(self, x, y, item, self.inventoryPane, self.playerNum)
    end
end

function HotbarSlot:onMouseDown(x, y)
    local item = self:getItem()
    if item then
        DragAndDrop.prepareDrag(self, DragAndDrop.convertItemToStack(item), x, y);
    end
end

function HotbarSlot:onMouseMove(dx, dy)
    DragAndDrop.startDrag(self);
end

function HotbarSlot:onMouseMoveOutside(dx, dy)
    DragAndDrop.startDrag(self);
end

function HotbarSlot:onMouseUp(x, y)
    local draggedItem = DragAndDrop.getDraggedItem();
    if draggedItem and draggedItem ~= self:getItem() then
        self:attachItemIfPossible(draggedItem);
    end
    DragAndDrop.endDrag();
end

function HotbarSlot:onMouseUpOutside(x, y)
    DragAndDrop.cancelDrag(self, HotbarSlot.dropOrUnequip);
end


function HotbarSlot:attachItemIfPossible(item)
    local slot = self.hotbar.availableSlot[self.index]
    local slotDef = slot.def;

    for i, v in pairs(slotDef.attachments) do
        if item:getAttachmentType() == i then
            local doIt = true;
            if self.hotbar.replacements and self.hotbar.replacements[item:getAttachmentType()] then
                slot = self.hotbar.replacements[item:getAttachmentType()];
                if slot == "null" then
                    doIt = false;
                end
            end
            if doIt then
                self.hotbar:attachItem(item, v, self.index, slotDef, true);
                return
            end
        end
    end
end

function HotbarSlot:canAttachItem(item)
    local slot = self.hotbar.availableSlot[self.index]
    if not slot then return false end

    local slotDef = slot.def;
    for i, v in pairs(slotDef.attachments) do
        if item:getAttachmentType() == i then
            local doIt = true;
            if self.hotbar.replacements and self.hotbar.replacements[item:getAttachmentType()] then
                slot = self.hotbar.replacements[item:getAttachmentType()];
                if slot == "null" then
                    doIt = false;
                end
            end
            if doIt then
                return true
            end
        end
    end
    return false
end

function HotbarSlot:dropOrUnequip()
    local item = self:getItem()
    if item then
        if not InventoryTetris then
            if self.inventoryPane:isMouseOver() then
                self.hotbar:removeItem(item, true)
                return
            end
        end

        local playerObj = getSpecificPlayer(self.playerNum)
        local vehicle = playerObj:getVehicle()
        if vehicle then
            return
        end

        if not ISUIElement.isMouseOverAnyUI() then
            ISInventoryPaneContextMenu.dropItem(item, self.playerNum)
        end
    end
end

function HotbarSlot:controllerNodeOnJoypadDown(button)
    local item = self:getItem()
    if button == Joypad.XButton then
        if item then
            self.hotbar:removeItem(item, true)
        end
        return true
    end
    if button == Joypad.AButton then
        if item then
            local x = self.width
            local y = self.height/2
            EquipmentSlot.openItemContextMenu(self, x, y, item, self.inventoryPane, self.playerNum)
        end
        return true
    end
    return false
end