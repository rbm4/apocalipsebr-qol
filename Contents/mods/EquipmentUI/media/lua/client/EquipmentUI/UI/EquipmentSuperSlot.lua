require "IS/UI/ISPanel"
local c = require "EquipmentUI/Settings"
local BG_TEXTURE = getTexture("media/ui/equipmentui/ItemSlot.png")

local MAX_COLUMN = 3
local MINI_ICON_SCALE = 0.375
local MINI_ICON_SIZE = 32 * MINI_ICON_SCALE
local BG_COLOR = { r = 0.4, g = 0.4, b = 0.4 }

EquipmentSuperSlot = ISPanel:derive("EquipmentSuperSlot");

function EquipmentSuperSlot:new(slotDefinition, equipmentUi, inventoryPane, playerNum)
    local o = ISPanel:new(0, 0, (c.SUPER_SLOT_SIZE + c.SUPER_SLOT_SUB_ITEM_WIDTH), c.SUPER_SLOT_SIZE);
	setmetatable(o, self)
    self.__index = self

    if slotDefinition.position then
        o:setX(c.SCALE * slotDefinition.position.x + c.EQUIPMENT_UI_X_OFFSET);
        o:setY(c.SCALE * slotDefinition.position.y + c.EQUIPMENT_UI_Y_OFFSET);
    end

    o.slotDefinition = slotDefinition;
    o.equipmentUi = equipmentUi;
    o.inventoryPane = inventoryPane;
    o.playerNum = playerNum;
	o.moveWithMouse = true;

    o.slots = {}
    o.mouseDownX = 0;
    o.mouseDownY = 0;

    o.bodyLocationGroup = getSpecificPlayer(playerNum):getWornItems():getBodyLocationGroup();

	return o;
end

function EquipmentSuperSlot:initialise()
    ISPanel.initialise(self);

    table.insert(c.OnScaleChanged, function(scale)
        self:setX(scale * self.slotDefinition.position.x + c.EQUIPMENT_UI_X_OFFSET);
        self:setY(scale * self.slotDefinition.position.y + c.EQUIPMENT_UI_Y_OFFSET);
        self:setWidth(c.SUPER_SLOT_SIZE + c.SUPER_SLOT_SUB_ITEM_WIDTH);
        self:setHeight(c.SUPER_SLOT_SIZE);
    end)

    NotlocControllerNode
        :injectControllerNode(self)
        :setJoypadDownHandler(self.controllerNodeOnJoypadDown)
        :setLoseJoypadFocusHandler(function()
            self:setExpanded(false)
        end)
        :setChildrenNodeProvider(self.getVisibleControllerNodes, self)
end

function EquipmentSuperSlot:createChildren()
    for _, bodyLocation in ipairs(self.slotDefinition.bodyLocations) do
        local slot = EquipmentSlot:new(0, 0, bodyLocation, self.equipmentUi, self.inventoryPane, self.playerNum);
        slot:initialise();
        slot:setVisible(false);
        self:addChild(slot);
        self.slots[bodyLocation] = slot;
    end
end

function EquipmentSuperSlot:setItem(item, bodyLocation)
    if self.slots[bodyLocation] then
        self.slots[bodyLocation]:setItem(item);
    end
end

function EquipmentSuperSlot:clearItem()
    for _, slot in pairs(self.slots) do
        slot:clearItem();
    end
end

function EquipmentSuperSlot:hasItem()
    return self:getTopItem() ~= nil
end

function EquipmentSuperSlot:getTopItem()
    local slot = self:getTopSlot();
    return slot and slot.item or nil;
end

function EquipmentSuperSlot:getTopSlot()
    for _, slot in pairs(self.slots) do
        if slot.item then
            return slot;
        end
    end
    return nil;
end

function EquipmentSuperSlot:getVisibleControllerNodes()
    local slots = {}
    for _, slot in pairs(self.slots) do
        if slot:isVisible() then
            table.insert(slots, slot.controllerNode)
        end
    end
    return slots
end

function EquipmentSuperSlot:getNthItem(index)
    local count = 0;
    for _, slot in pairs(self.slots) do
        if slot.item then
            count = count + 1;
            if count == index then
                return slot.item;
            end
        end
    end
    return nil;
end

function EquipmentSuperSlot:getItemCount()
    local count = 0
    for _, slot in pairs(self.slots) do
        if slot.item then
            count = count + 1;
        end
    end
    return count
end

function EquipmentSuperSlot:doesItemConflict(item)
    local bodyLocation = EquipmentSlot.getBodyLocationForItem(item);
    if not bodyLocation then
        return false
    end

    for _, slot in pairs(self.slots) do
        if slot.item and slot.item ~= item and (bodyLocation == slot.bodyLocation or self.bodyLocationGroup:isExclusive(bodyLocation, slot.bodyLocation)) then
            return true
        end
    end
    return false
end

function EquipmentSuperSlot:isDraggingMyItem()
    local dragItem = DragAndDrop.getDraggedItem();
    if dragItem then
        for _, slot in pairs(self.slots) do
            if slot.item == dragItem then
                return true;
            end
        end
    end
    return false;
end

function EquipmentSuperSlot:prerender()
    local itemCount = self:getItemCount();

    local hasControllerFocus = self.controllerNode and self.controllerNode.isFocused
    local bgColor = hasControllerFocus and NotlocControllerNode.FOCUS_COLOR or BG_COLOR

    if itemCount > 0 then
        local slotWidth = (itemCount > 1 and c.SUPER_SLOT_SIZE + c.SUPER_SLOT_SUB_ITEM_WIDTH or c.SUPER_SLOT_SIZE);

        self:drawRect(0, 0, slotWidth, c.SUPER_SLOT_SIZE, 0.85, 0, 0, 0);
        self:drawTextureScaled(BG_TEXTURE, 0, 0, slotWidth, c.SUPER_SLOT_SIZE, 1, bgColor.r, bgColor.g, bgColor.b);
        self:drawRectBorder(0, 0, slotWidth, c.SUPER_SLOT_SIZE, 1, 1, 1, 1);
    else
        self:drawRect(0, 0, c.SUPER_SLOT_SIZE, c.SUPER_SLOT_SIZE, 0.65, 0, 0, 0);
        self:drawTextureScaled(BG_TEXTURE, 0, 0, c.SUPER_SLOT_SIZE, c.SUPER_SLOT_SIZE, 1, bgColor.r, bgColor.g, bgColor.b);
        self:drawRectBorder(0, 0, c.SUPER_SLOT_SIZE, c.SUPER_SLOT_SIZE, 1, 1, 1, 1);
    end

    local dragItem = DragAndDrop.getDraggedItem();
    if dragItem then
        local bodyLocation = EquipmentSlot.getBodyLocationForItem(dragItem);
        if bodyLocation then
            local canAcceptItem = self.slots[bodyLocation] and self.slots[bodyLocation].item ~= dragItem
            local hasConflictingItems = self:doesItemConflict(dragItem)

            local r = hasConflictingItems and 1 or 0
            local g = canAcceptItem and 1 or 0
            if canAcceptItem or hasConflictingItems then
                self:drawRect(1, 1, c.SUPER_SLOT_SIZE - 2, c.SUPER_SLOT_SIZE - 2, 0.5, r, g, 0);
            end
        end
    end

    if self.expanded and itemCount < 2 then
        self:toggleExpanded();
    end

    if self.expanded then
        self:layoutSlots();

        local slotCount = self.visibleSlots
        local xCount = math.min(slotCount, 3);
        local yCount = math.ceil(slotCount / 3);
        if self.expanded then
            local yOffset = c.SUPER_SLOT_SIZE + c.SUPER_SLOT_VERTICAL_OFFSET;
            local width = c.SLOT_SIZE * xCount + c.SUB_SLOT_THING - xCount;
            local height = c.SLOT_SIZE * yCount + c.SUB_SLOT_THING - yCount;
            self:drawRect(0, yOffset, width, height, 0.9, 0, 0, 0);
            self:drawRectBorder(0, yOffset, width, height, 0.8, 1, 1, 1);
        end
    end
end

function EquipmentSuperSlot:layoutSlots()
    self.visibleSlots = 0;
    local column = 0;
    local row = 0;

    if not self.expanded then
        for _, slot in pairs(self.slots) do
            slot:setVisible(self.expanded);
        end
        return
    end

    for _, slot in pairs(self.slots) do
        if slot.item then
            slot:setVisible(true);
            slot:setX((column * c.SLOT_SIZE) + 2 - column);
            slot:setY((c.SUPER_SLOT_SIZE + c.SUPER_SLOT_VERTICAL_OFFSET + row * c.SLOT_SIZE) + 2 - row);

            self.visibleSlots = self.visibleSlots + 1;
            column = column + 1;

            if column >= 3 then
                column = 0;
                row = row + 1;
            end
        else
            slot:setVisible(false);
        end
    end
end

function EquipmentSuperSlot:render()
    --if the mouse is over the super slot, draw the name of the slot
    if self:isMouseOver() or self.controllerNode.isFocused then
        local name = getText(self.slotDefinition.name);
        local width = getTextManager():MeasureStringX(UIFont.Small, name);
        local height = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight();

        local center = c.SUPER_SLOT_SIZE / 2
        local x = center - width / 2 - 3
        local y = -height - 2

        self:drawRect(x, y, width + 8, height+4, 0.9, 0, 0, 0);

        self:drawRectBorder(x, y, width + 8, height+4, 1, 1, 1, 1);
        self:drawTextCentre(name, center, y, 1, 1, 1, 1, UIFont.Small);
    end

    local itemsToDraw = {};

    local index = 1;
    for _, bodyLocation in ipairs(self.slotDefinition.bodyLocations) do
        local slot = self.slots[bodyLocation];
        if slot.item and index <= 4 then
            itemsToDraw[index] = slot.item;
            index = index + 1;
        end
    end

    local count = index - 1

    if count == 0 then
        return
    end

    local xOff = (c.SUPER_SLOT_SIZE - c.SLOT_SIZE) / 2;
    local yOff = (c.SUPER_SLOT_SIZE - c.SLOT_SIZE) / 2;
    local mainAlpha = 1;
    if itemsToDraw[1] == DragAndDrop.getDraggedItem() then
        mainAlpha = 0.5;
    end
    self:drawTextureScaledUniform(itemsToDraw[1]:getTex(), xOff + c.SCALE, yOff + c.SCALE, c.SCALE, mainAlpha, EquipmentSlot.getItemColor(itemsToDraw[1]));

    if count > 1 then
        local slotSize = c.SUPER_SLOT_SIZE + c.SUPER_SLOT_SUB_ITEM_WIDTH
        local scaledSize = MINI_ICON_SIZE * c.SCALE
        for i = 2, count do
            self:drawRect(slotSize - scaledSize - 1, (scaledSize * (i - 2)), scaledSize+1, scaledSize+1, 0.7, 0, 0, 0);
            self:drawRectBorder(slotSize - scaledSize - 1, (scaledSize * (i - 2)), scaledSize+1, scaledSize+1, 0.4, 1, 1, 1);
            self:drawTextureScaledUniform(itemsToDraw[i]:getTex(), slotSize - scaledSize, yOff + (scaledSize * (i - 2)) - c.SCALE, MINI_ICON_SCALE * c.SCALE, 1, EquipmentSlot.getItemColor(itemsToDraw[i]));
        end

        self:drawRectBorder(c.SUPER_SLOT_SIZE - 1, 0, c.SUPER_SLOT_SUB_ITEM_WIDTH + 1, c.SUPER_SLOT_SIZE, 1, 1, 1, 1);
    end

    local isController = self.controllerNode.isFocused

    if not isController and not DragAndDrop.isDragging() and self:isMouseOver() then
        local x = self:getMouseX();
        local y = self:getMouseY();

        if y > c.SUPER_SLOT_SIZE then
            return
        end

        local index = self:mousePositionToSlotIndex(x, y);
        if index ~= -1 and index <= count then
            self.equipmentUi:doTooltipForItem(self, itemsToDraw[index]);
        else
            self.equipmentUi:closeTooltip();
        end
    end

    if isController and not self.controllerNode.selectedChild then
        self.equipmentUi:doTooltipForItem(self, itemsToDraw[1]);
    end
end

function EquipmentSuperSlot:mousePositionToSlotIndex(x, y)
    if x > 0 and y > 0 and x < c.SUPER_SLOT_SIZE and y < c.SUPER_SLOT_SIZE then
        return 1;
    end

    if x > c.SUPER_SLOT_SIZE and y > 0 and x < (c.SUPER_SLOT_SIZE + c.SUPER_SLOT_SUB_ITEM_WIDTH) and y < c.SUPER_SLOT_SIZE then
        return math.floor(y / MINI_ICON_SIZE / c.SCALE) + 2;
    end

    return -1;
end

function EquipmentSuperSlot:onRightMouseUp(x, y)
    local index = self:mousePositionToSlotIndex(x, y);
    if index == -1 then
        return;
    end

    local item = self:getNthItem(index);
    if item then
        EquipmentSlot.openItemContextMenu(self, x, y, item, self.inventoryPane, self.playerNum)
        return true
    end
end

function EquipmentSuperSlot:onMouseDown(x, y)
    self.mouseDownX = x;
    self.mouseDownY = y;
    
    local item = self:getTopItem();
    if item then
        local stack = DragAndDrop.convertItemToStack(item);
        DragAndDrop.prepareDrag(self, stack, x, y);
        return true;
    end

    ISPanel.onMouseDown(self, x, y);
end

function EquipmentSuperSlot:onMouseMove(dx, dy)
    if DragAndDrop.isDragging() and self:doesItemConflict(DragAndDrop.getDraggedItem()) then
        self:setExpanded(true);
    else 
        DragAndDrop.startDrag(self);
    end
end

function EquipmentSuperSlot:onMouseMoveOutside(x, y)
    if not DragAndDrop.isDragging() then  
        DragAndDrop.startDrag(self);
    end

    -- if the mouse is more than 10 pixels away from the edge of the super slot, close it
    local limit = 10 * c.SCALE
    if self.expanded and not self:isDraggingMyItem() and (math.abs(x - self.mouseDownX) > limit or math.abs(y - self.mouseDownY) > limit) then
        self:setExpanded(false);
    end
end

function EquipmentSuperSlot:onMouseUp(x, y)
    if DragAndDrop.isDragging() then
        self:handleDragDrop(x, y);
    else
        self:handleSlotClick(x, y);
    end
    DragAndDrop.endDrag();
end

function EquipmentSuperSlot:onMouseUpOutside(x, y)
    DragAndDrop.cancelDrag(self, EquipmentSuperSlot.dropOrUnequip);
end

function EquipmentSuperSlot:handleDragDrop(x, y)
    local item = DragAndDrop.getDraggedItem();
    local bodyLocation = EquipmentSlot.getBodyLocationForItem(item)
    if bodyLocation then
        self:handleClothingDrop(item, bodyLocation);
    end

    DragAndDrop.endDrag();
end

function EquipmentSuperSlot:handleClothingDrop(item, bodyLocation)
    local slot = self.slots[bodyLocation];
    if slot then
        ISInventoryPaneContextMenu.onWearItems({item}, self.playerNum);
    end
end

function EquipmentSuperSlot:handleSlotClick(x, y)
    local dx = math.abs(x - self.mouseDownX);
    local dy = math.abs(y - self.mouseDownY);
    if dx < 5 and dy < 5 then
        self:toggleExpanded();
    end
    ISPanel.onMouseUp(self, x, y);

    if self.parentX then
        print(self:getAbsoluteX() - self.parentX:getAbsoluteX(), ", ", self:getAbsoluteY() - self.parentX:getAbsoluteY());
    end
end

function EquipmentSuperSlot:toggleExpanded()
    self:setExpanded(not self.expanded);
end

function EquipmentSuperSlot:setExpanded(expanded)
    self.expanded = expanded and self:getItemCount() > 1;
    self:layoutSlots()

    local count = self.visibleSlots;
    local countX = count > MAX_COLUMN and MAX_COLUMN or count;
    local countY = count > MAX_COLUMN and math.ceil(count / MAX_COLUMN) or 1;

    local closedWidth = (c.SUPER_SLOT_SIZE + c.SUPER_SLOT_SUB_ITEM_WIDTH)

    self:setWidth(self.expanded and (countX * c.SLOT_SIZE + 4 - countX) or closedWidth);
    if self.width < closedWidth then
        self:setWidth(closedWidth);
    end

    self:setHeight(self.expanded and (c.SUPER_SLOT_SIZE + c.SUPER_SLOT_VERTICAL_OFFSET + c.SLOT_SIZE * countY) + 4 - countY or c.SUPER_SLOT_SIZE);

    if self.expanded then
        self:bringToTop();
        local firstSlot = self:getTopSlot()
        if firstSlot then
            self.controllerNode:setSelectedChild(firstSlot.controllerNode);
        end
    else
        self.controllerNode:setSelectedChild(nil);
    end
end

function EquipmentSuperSlot:dropOrUnequip()
    local item = self:getTopItem()
    if item then
        if not InventoryTetris then
            if self.inventoryPane:isMouseOver() then
                ISInventoryPaneContextMenu.unequipItem(item, self.playerNum)
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

function EquipmentSuperSlot:unequip()
    local item = self:getTopItem()
    if item then
        ISInventoryPaneContextMenu.unequipItem(item, self.playerNum)
    end
end

function EquipmentSuperSlot:controllerNodeOnJoypadDown(button)
    if button == Joypad.BButton then
        self:toggleExpanded()
        return true
    end
    if button == Joypad.XButton then
        self:unequip()
        return true
    end
    if button == Joypad.AButton then
        local item = self:getTopItem()
        if item then
            local x = self.width
            local y = self.height/2
            EquipmentSlot.openItemContextMenu(self, x, y, item, self.inventoryPane, self.playerNum)
        end
        return true
    end
    return false
end