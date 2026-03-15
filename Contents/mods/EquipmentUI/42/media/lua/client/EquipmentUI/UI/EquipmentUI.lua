require ("ISUI/ISPanelJoypad")
local c = require "EquipmentUI/Settings"

local SUPER_SLOT_DEFS = require "EquipmentUI/EquipmentSlotDefinitions"
local WEAPON_SLOT_DEFS = require "EquipmentUI/WeaponSlotDefinitions"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

EquipmentUI = ISPanelJoypad:derive("EquipmentUI");

EquipmentUI.version = {
    major = 2,
    minor = 1,
    revision = 5,
}

function EquipmentUI:new(x, y, width, height, inventoryPane, playerNum)
	local o = {};
	o = ISPanelJoypad:new(x, y, width, height);
	setmetatable(o, self);
    self.__index = self;

    o.inventoryPane = inventoryPane
    o.playerNum = playerNum

	o.char = getSpecificPlayer(playerNum);
	o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.backgroundColor = {r=0, g=0, b=0, a=0.8};
	o.bodyOutline = getTexture("media/ui/defense/" .. (o.char:isFemale() and "female" or "male") .. "_base.png")

    o.hotbarSlots = {}
    o.hotbarSlotPool = {}

    o.dynamicEquipmentY = c.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET

    o.bottomY = 200
   return o;
end

function EquipmentUI:createChildren()
    ISPanelJoypad.createChildren(self);
    self:createEquipmentSlots();
    self:createWeaponSlots();

    table.insert(c.OnScaleChanged, function()
        local hotbar = getPlayerHotbar(self.playerNum)
        self:updateDynamicEquipmentSlots()
        self:updateHotbarSlots(hotbar)
        self:setWidth(c.EQUIPMENT_WIDTH)
        self:setHeight(self.bottomY)
    end)

    Events.OnClothingUpdated.Add(function(character)
        if instanceof(character, "IsoPlayer") then
            ---@cast character IsoPlayer
            if character:isLocalPlayer() and character:getPlayerNum() == self.playerNum then
                self:updateSlots()
                self:updateDynamicEquipmentSlots()
            end
        end
    end)

    self:updateSlots()
    self:updateDynamicEquipmentSlots()
end

function EquipmentUI:createEquipmentSlots()
    self.dynamicSlotPool = {}
    self.dynamicSlots = {};
    self.superSlots = {};

    for _, superSlotDef in pairs(SUPER_SLOT_DEFS) do
        local superslot = EquipmentSuperSlot:new(superSlotDef, self, self.inventoryPane, self.playerNum);
        superslot:initialise();

        if superSlotDef.position then
            superslot.moveWithMouse = false
            self:addChild(superslot);
        else
            superslot.parentX = self;
            superslot:addToUIManager();
        end

        for _, bodyLocation in pairs(superslot.slotDefinition.bodyLocations) do
            self.superSlots[bodyLocation] = superslot;
        end
    end
end

function EquipmentUI:updateDynamicEquipmentSlots()
    for key, slot in pairs(self.dynamicSlots) do
        slot:setVisible(false)
        table.insert(self.dynamicSlotPool, slot)
        self.dynamicSlots[key] = nil
    end

    local player = getSpecificPlayer(self.playerNum)
    local wornItems = player:getWornItems()

    local MAX_COLUMN = 5

    local column = 0
    local row = 0
    for i = 1, wornItems:size() do
        local wornItem = wornItems:get(i-1)
        if not wornItem:getItem():isHidden() then
            local bodyLocation = wornItem:getLocation()
            if not self.superSlots[bodyLocation] then
                if column >= MAX_COLUMN then
                    column = 0
                    row = row + 1
                end

                local slot = self:createDynamicEquipmentSlot(bodyLocation)
                slot:setX(c.EQUIPMENT_DYNAMIC_SLOT_X_OFFSET + (column * (c.SLOT_SIZE + c.EQUIPMENT_DYNAMIC_SLOT_MARGIN)));
                slot:setY(c.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET + (row * (c.SLOT_SIZE + c.EQUIPMENT_DYNAMIC_SLOT_MARGIN)));
                slot:setItem(wornItem:getItem())
                self.dynamicSlots[bodyLocation] = slot

                column = column + 1
            end
        end
    end

    if column > 0 then
        row = row + 1
    end

    self.dynamicEquipmentY = c.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET + ((row) * (c.SLOT_SIZE + 4)) + 8
end

function EquipmentUI:createDynamicEquipmentSlot(bodyLocation)
    if #self.dynamicSlotPool > 0 then
        local slot = self.dynamicSlotPool[#self.dynamicSlotPool]
        table.remove(self.dynamicSlotPool, #self.dynamicSlotPool)

        slot.bodyLocation = bodyLocation
        slot:setVisible(true)
        slot:setItem(nil)
        return slot
    end

    local slot = EquipmentSlot:new(50, 50, bodyLocation, self, self.inventoryPane, self.playerNum);
    slot.borderColor = {r=1, g=1, b=1, a=1};
    slot:initialise();
    self:addChild(slot);
    return slot
end

function EquipmentUI:createWeaponSlots()
    self.primarySlot = WeaponSlot:new(WEAPON_SLOT_DEFS[1], self, self.inventoryPane, self.playerNum);
    self.primarySlot:initialise();
    self:addChild(self.primarySlot);

    self.secondarySlot = WeaponSlot:new(WEAPON_SLOT_DEFS[2], self, self.inventoryPane, self.playerNum, true);
    self.secondarySlot:initialise();
    self:addChild(self.secondarySlot);
end

function EquipmentUI:updateSlots()
    for _, slot in pairs(self.dynamicSlots) do
        slot:clearItem();
    end

    for _, slot in pairs(self.superSlots) do
        slot:clearItem();
    end

    local wornItems = self.char:getWornItems()
    for i=1,wornItems:size() do
        local wornItem = wornItems:get(i-1)
        local bodyLocation = wornItem:getLocation()
        if self.superSlots[bodyLocation] then
            self.superSlots[bodyLocation]:setItem(wornItem:getItem(), bodyLocation)
        end

        if self.dynamicSlots[bodyLocation] then
            self.dynamicSlots[bodyLocation]:setItem(wornItem:getItem())
        end
    end
end

function EquipmentUI:updateHotbarSlots(hotbar)
    if not hotbar then
        return
    end

    self:disableHotbarSlots()

    local y = self.dynamicEquipmentY + c.HOTBAR_SLOT_Y_OFFSET

    local row = 0
    local column = 0
    local slots = hotbar.availableSlot
    for i, slot in ipairs(slots) do
        if column >= 5 then
            column = 0
            row = row + 1
        end

        local newSlot = self:createHotbarSlot(hotbar)
        newSlot:setX(c.HOTBAR_SLOT_X_OFFSET + (column * (c.SUPER_SLOT_SIZE + c.HOTBAR_SLOT_MARGIN)));
        newSlot:setY(y + (row * (c.SUPER_SLOT_SIZE + c.HOTBAR_SLOT_MARGIN)));

        newSlot.index = i

        column = column + 1
    end

    self.bottomY = y + ((row + 1) * (c.SUPER_SLOT_SIZE + c.HOTBAR_SLOT_MARGIN)) + c.EQUIPMENT_UI_BOTTOM_PADDING
end

function EquipmentUI:createHotbarSlot(hotbar)
    local newSlot = nil
    if #self.hotbarSlotPool > 0 then -- Used to remove from the end, but we do the front now for controller support
        newSlot = self.hotbarSlotPool[1] -- Kind of a lazy fix, but we refresh these every frame so they can't be changing order
        table.remove(self.hotbarSlotPool, 1) -- Eventually need to rewrite this to only update the slots that changed
        newSlot:setVisible(true)
        
    else
        newSlot = HotbarSlot:new(hotbar, self, self.inventoryPane, self.playerNum);
        newSlot:initialise();
        self:addChild(newSlot);
    end

    table.insert(self.hotbarSlots, newSlot)
    return newSlot
end

function EquipmentUI:disableHotbarSlots()
    for _, slot in pairs(self.hotbarSlots) do
        slot:setVisible(false)
        slot.index = nil
        table.insert(self.hotbarSlotPool, slot) 
    end
    table.wipe(self.hotbarSlots)
end

function EquipmentUI:prerender()
    self:renderHeaderCentered(getText("UI_equipment_equipment"), 12)
    self:renderHeaderCentered(getText("UI_equipment_hotbar"), self.dynamicEquipmentY + 12)
    self:drawTextureScaledUniform(self.bodyOutline, c.EQUIPMENT_UI_X_OFFSET, c.EQUIPMENT_UI_Y_OFFSET, c.SCALE, 1, 1, 1, 1);

    local hotbar = getPlayerHotbar(self.playerNum)
    if hotbar and not hotbar.notloc_onRefresh then
        hotbar.notloc_onRefresh = function(hotbar)
            self:updateHotbarSlots(hotbar)
        end
        self:updateHotbarSlots(hotbar)
    end
end

function EquipmentUI:renderHeader(text, height)
    local hotbarTextW = getTextManager():MeasureStringX(UIFont.Small, text);
    local hotbarTextH = getTextManager():getFontHeight(UIFont.Small);
    self:drawText(text, 8, height - hotbarTextH/2, 1, 1, 1, 1, UIFont.Small);
    self:drawRectBorder(12 + hotbarTextW, height, self.width - 24 - hotbarTextW, 1, 1, 1, 1, 1);
end

function EquipmentUI:renderHeaderCentered(text, height)
    local hotbarTextW = getTextManager():MeasureStringX(UIFont.Small, text);
    local hotbarTextH = getTextManager():getFontHeight(UIFont.Small);
    self:drawText(text, self.width/2 - hotbarTextW/2, height - hotbarTextH/2, 1, 1, 1, 1, UIFont.Small);
    -- two borders, one on each side
    self:drawRectBorder(12, height, self.width/2 - hotbarTextW/2 - 18, 1, 1, 1, 1, 1);
    self:drawRectBorder(self.width/2 + hotbarTextW/2 + 6, height, self.width/2 - hotbarTextW/2 - 18, 1, 1, 1, 1, 1);
end

function EquipmentUI:getHeightForScroll()
    return self.bottomY
end

function EquipmentUI:onMouseDown(x, y)
    return false
end

function EquipmentUI:doTooltipForItem(owner, item)
    self.tooltipOwner = owner
    self.inventoryPane:doTooltipForItem(item)
end

local function tContains(haystack, needle)
    for _, v in pairs(haystack) do
        if v == needle then
            return true
        end
    end
    return false
end

function EquipmentUI:updateTooltip()
    if not self.inventoryPane.toolRender then
        return
    end

    local owner = nil
    for _, child in pairs(self.children) do
        if child:isMouseOver() or child.controllerNode.isFocused then
            owner = child
        end
    end

    if not owner or (self.tooltipOwner ~= owner and (not owner.children or not tContains(owner.children, self.tooltipOwner))) then
        self:closeTooltip()
    end
end

function EquipmentUI:closeTooltip()
    if self.inventoryPane.toolRender then
        self.inventoryPane.toolRender:removeFromUIManager()
        self.inventoryPane.toolRender:setVisible(false)
        self.tooltipOwner = nil
    end
end

function EquipmentUI:getControllerNodes()
    local nodes = {}
    for _, slot in pairs(self.dynamicSlots) do
        table.insert(nodes, slot.controllerNode)
    end
    for _, slot in pairs(self.superSlots) do
        table.insert(nodes, slot.controllerNode)
    end
    for _, slot in pairs(self.hotbarSlots) do
        table.insert(nodes, slot.controllerNode)
    end
    table.insert(nodes, self.primarySlot.controllerNode)
    table.insert(nodes, self.secondarySlot.controllerNode)
    return nodes
end