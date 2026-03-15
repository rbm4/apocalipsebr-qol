require "ISUI/ISUIElement"

local BUTTON_TEX = getTexture("media/ui/equipmentui/equipment_min.png");

EquipmentUIToggle = ISUIElement:derive("EquipmentUIToggle");

function EquipmentUIToggle:new(equipmentUi, inventoryPane)
	local o = {};
	o = ISUIElement:new(0, 0, 16, 20);
	setmetatable(o, self);
    self.__index = self;

    o.equipmentUi = equipmentUi
    o.inventoryPane = inventoryPane
    
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}

    equipmentUi.toggleElement = o

    return o;
end

function EquipmentUIToggle:createChildren()
    ISUIElement.createChildren(self);

    self.equipmentButton = ISButton:new(0, 0, self.width, self.height, "", self, self.onToggleEquipmentUiWindow)
    self.equipmentButton:initialise()
    self.equipmentButton.image = BUTTON_TEX
    
    self.equipmentButton:setAnchorLeft(true)
    self.equipmentButton:setAnchorRight(true)
    self.equipmentButton:setAnchorTop(true)
    self.equipmentButton:setAnchorBottom(true)
    self.equipmentButton:setImage(BUTTON_TEX)
    self.equipmentButton.borderColor = {r=0, g=0, b=0, a=0}
    self.equipmentButton.backgroundColor = {r=0, g=0, b=0, a=0}

    self.equipmentButton:forceImageSize(16, 20)

    self:addChild(self.equipmentButton)
    self.equipmentButton:bringToTop()
end

function EquipmentUIToggle:onToggleEquipmentUiWindow()
	local state = not self.equipmentUi:isVisible()
	self.equipmentUi:setVisible(state)
    self.equipmentUi.isClosed = not state

    if not state then
        self.inventoryPane.parent:bringToTop()
    end
end

function EquipmentUIToggle:prerender()
    local invPage = self.inventoryPane.parent
    local titleBarHeight = invPage:titleBarHeight()

    local targetX = invPage:getX()
    local targetY = invPage:getY() + titleBarHeight - 1

    local dockedAndVisible = self.equipmentUi.isDocked and self.equipmentUi:isVisible()
    
    if dockedAndVisible or math.abs(getMouseX() - targetX) + math.abs(getMouseY() - targetY) < 38 then
        self:setWidth(16)
    else
        self:setWidth(6)
    end

    self:setHeight(titleBarHeight);
    self:setX(invPage:getX() - self:getWidth());
    self:setY(invPage:getY() + titleBarHeight - 1);

    local invIsVisible = self.inventoryPane.parent:isVisible() and not self.inventoryPane.parent.isCollapsed
    local undockedAndOpen = not self.equipmentUi.isDocked and self.equipmentUi:isVisible()
    self.equipmentButton:setVisible(invIsVisible and not undockedAndOpen)
end
