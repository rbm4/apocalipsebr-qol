local ProximityInventory = require("ProximityInventory/ProximityInventory")

-- ============================================================
-- FIX: onBackpackRightMouseDown
-- In vanilla B42, this is assigned as button.onRightMouseDown, so
-- 'self' is the button. self.parent.parent is the ISInventoryPage.
-- Crash at vanilla line 1378: container:getParent():getSquare()
-- because our proxInv has no parent. We intercept it first.
-- ============================================================
local old_ISInventoryPage_onBackpackRightMouseDown = ISInventoryPage.onBackpackRightMouseDown
function ISInventoryPage:onBackpackRightMouseDown(x, y)
  local container = self.inventory

  if container and container:getType() == "proxInv" then
    local page = self.parent and self.parent.parent
    local playerNum = (page and page.player) or 0

    local context = ISContextMenu.get(playerNum, getMouseX(), getMouseY())
    if not context then return end

    local inventoryIcon   = ProximityInventory.inventoryIcon
    local forceSelectIcon = ProximityInventory.forceSelectIcon
    local highlightIcon   = getTexture("media/textures/Item_LightBulb.png")

    local isForced = ProximityInventory.isForceSelected[playerNum]
    local forceText = isForced
      and getText("IGUI_ProxInv_Context_ForceSelectOn")
      or  getText("IGUI_ProxInv_Context_ForceSelectOff")
    local optForce = context:addOption(forceText, nil, function()
      ProximityInventory.isForceSelected[playerNum] = not ProximityInventory.isForceSelected[playerNum]
      ISInventoryPage.dirtyUI()
    end)
    optForce.iconTexture = isForced and forceSelectIcon or nil

    local isHighlight = ProximityInventory.isHighlightEnableOption:getValue()
    local highlightText = isHighlight
      and getText("IGUI_ProxInv_Context_HighlightOn")
      or  getText("IGUI_ProxInv_Context_HighlightOff")
    local optHighlight = context:addOption(highlightText, nil, function()
      ProximityInventory.isHighlightEnableOption:setValue(not ProximityInventory.isHighlightEnableOption:getValue())
      PZAPI.ModOptions:save()
      ISInventoryPage.dirtyUI()
    end)
    optHighlight.iconTexture = isHighlight and highlightIcon or nil

    return
  end

  return old_ISInventoryPage_onBackpackRightMouseDown(self, x, y)
end


-- ============================================================
-- Shift + left click on proxInv button toggles force select
-- ============================================================
local old_ISInventoryPage_onBackpackMouseDown = ISInventoryPage.onBackpackMouseDown
function ISInventoryPage:onBackpackMouseDown(button, x, y)
  local container = self.inventory

  if container and container:getType() == "proxInv" and (isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT)) then
    local page = self.parent and self.parent.parent
    local playerNum = (page and page.player) or 0

    ProximityInventory.isForceSelected[playerNum] = not ProximityInventory.isForceSelected[playerNum]

    local player = getSpecificPlayer(playerNum)
    local text = ProximityInventory.isForceSelected[playerNum]
      and getText("IGUI_ProxInv_Text_ForceSelectOn")
      or  getText("IGUI_ProxInv_Text_ForceSelectOff")
    HaloTextHelper.addText(player, text, "", HaloTextHelper.getColorWhite())

    ISInventoryPage.dirtyUI()
    return
  end

  return old_ISInventoryPage_onBackpackMouseDown(self, button, x, y)
end


-- ============================================================
-- "Take all" and "Move To Floor" buttons for proxInv.
--
-- ISInventoryPane:lootAll() and transferAll() both call
-- luautils.walkToContainer(self.inventory) which fails for our
-- virtual proxInv container (no parent/world object).
-- So we implement our own versions that iterate over the real
-- source containers (invSelf.backpacks).
--
-- We hook ISLootWindowContainerControls:arrange() to inject our
-- buttons when the selected container is proxInv.
-- ============================================================

local function proxInvGrabAll(invSelf)
  local playerNum = invSelf.player
  local playerObj = getSpecificPlayer(playerNum)
  if not playerObj then return end
  local playerInv = playerObj:getInventory()

  for i = 1, #invSelf.backpacks do
    local srcContainer = invSelf.backpacks[i].inventory
    if srcContainer:getType() ~= "proxInv" and ProximityInventory.CanBeAdded(srcContainer, playerObj) then
      if luautils.walkToContainer(srcContainer, playerNum) then
        local items = {}
        local it = srcContainer:getItems()
        for j = 0, it:size() - 1 do
          local item = it:get(j)
          if not item:isUnwanted(playerObj) then
            table.insert(items, item)
          end
        end
        invSelf.inventoryPane:transferItemsByWeight(items, playerInv)
      end
    end
  end
  invSelf.inventoryPane.selected = {}
  getPlayerLoot(playerNum).inventoryPane.selected = {}
  getPlayerInventory(playerNum).inventoryPane.selected = {}
end

local function proxInvMoveToFloor(invSelf)
  if isGamePaused() then return end
  local playerNum = invSelf.player
  local floorContainer = ISInventoryPage.GetFloorContainer(playerNum)

  -- Collect all items from all real source containers (not proxInv itself)
  local items = {}
  for i = 1, #invSelf.backpacks do
    local srcContainer = invSelf.backpacks[i].inventory
    if srcContainer:getType() ~= "proxInv" then
      local it = srcContainer:getItems()
      for j = 0, it:size() - 1 do
        table.insert(items, it:get(j))
      end
    end
  end

  ISInventoryPaneContextMenu.onMoveItemsTo(items, floorContainer, playerNum)

  invSelf.inventoryPane.selected = {}
  getPlayerLoot(playerNum).inventoryPane.selected = {}
  getPlayerInventory(playerNum).inventoryPane.selected = {}
end


-- ============================================================
-- Loot All / Move To Floor buttons for proxInv container.
--
-- Two strategies depending on whether CleanUI is loaded:
--
-- 1) CleanUI present: register as proper FloorHandlers via
--    ISLootWindowContainerControls.AddFloorHandler so CleanUI's
--    own arrange() includes them without conflict.
--
-- 2) Vanilla (no CleanUI): hook arrange() and append our buttons
--    after calling the original, so other mods in the chain are
--    not disrupted.
-- ============================================================

local function registerCleanUIHandlers()
  -- "Loot All" handler
  local ProxInvHandler_LootAll = ISLootWindowFloorControlHandler:derive("ProxInvHandler_LootAll")

  function ProxInvHandler_LootAll:shouldBeVisible()
    local container = self.lootWindow and self.lootWindow.inventoryPane and self.lootWindow.inventoryPane.inventory
    if not container or container:getType() ~= "proxInv" then return false end
    for i = 1, #self.lootWindow.backpacks do
      local t = self.lootWindow.backpacks[i].inventory:getType()
      if t ~= "proxInv" and t ~= "floor" then return true end
    end
    return false
  end

  function ProxInvHandler_LootAll:perform()
    proxInvGrabAll(self.lootWindow)
  end

  function ProxInvHandler_LootAll:getControl()
    return self:getButtonControl(getText("IGUI_invpage_Loot_all"))
  end

  function ProxInvHandler_LootAll:new()
    return ISLootWindowFloorControlHandler.new(self)
  end

  -- "Move To Floor" handler
  local ProxInvHandler_MoveToFloor = ISLootWindowFloorControlHandler:derive("ProxInvHandler_MoveToFloor")

  function ProxInvHandler_MoveToFloor:shouldBeVisible()
    local container = self.lootWindow and self.lootWindow.inventoryPane and self.lootWindow.inventoryPane.inventory
    if not container or container:getType() ~= "proxInv" then return false end
    for i = 1, #self.lootWindow.backpacks do
      local t = self.lootWindow.backpacks[i].inventory:getType()
      if t ~= "proxInv" and t ~= "floor" then return true end
    end
    return false
  end

  function ProxInvHandler_MoveToFloor:perform()
    proxInvMoveToFloor(self.lootWindow)
  end

  function ProxInvHandler_MoveToFloor:getControl()
    local text = getTextOrNull("ContextMenu_MoveToFloor") or "Move To Floor"
    return self:getButtonControl(text)
  end

  function ProxInvHandler_MoveToFloor:new()
    return ISLootWindowFloorControlHandler.new(self)
  end

  ISLootWindowContainerControls.AddFloorHandler(ProxInvHandler_LootAll)
  ISLootWindowContainerControls.AddFloorHandler(ProxInvHandler_MoveToFloor)
end

local function registerVanillaHook()
  local old_arrange = ISLootWindowContainerControls.arrange
  function ISLootWindowContainerControls:arrange()
    old_arrange(self)

    local container = self.lootWindow and self.lootWindow.inventoryPane and self.lootWindow.inventoryPane.inventory
    if not container or container:getType() ~= "proxInv" then return end

    local invSelf = self.lootWindow
    local hasNearbyContainers = false
    for i = 1, #invSelf.backpacks do
      local t = invSelf.backpacks[i].inventory:getType()
      if t ~= "proxInv" and t ~= "floor" then
        hasNearbyContainers = true
        break
      end
    end
    if not hasNearbyContainers then return end

    local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
    local buttonH = 2 + FONT_HGT_SMALL + 2
    local y = 1
    local x = 1
    for _, ctrl in ipairs(self.controls) do
      if ctrl:getRight() + 10 > x then x = ctrl:getRight() + 10 end
    end

    if not self.proxGrabAllBtn then
      local btn = ISButton:new(x, y, 80, buttonH, getText("IGUI_invpage_Loot_all"), self, function() proxInvGrabAll(invSelf) end)
      btn:initialise()
      btn.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
      btn:setWidthToTitle()
      self.proxGrabAllBtn = btn
    end
    self.proxGrabAllBtn:setX(x) self.proxGrabAllBtn:setY(y) self.proxGrabAllBtn:setVisible(true)
    self:addChild(self.proxGrabAllBtn)
    table.insert(self.controls, self.proxGrabAllBtn)
    x = self.proxGrabAllBtn:getRight() + 10

    local moveToFloorText = getTextOrNull("ContextMenu_MoveToFloor") or "Move To Floor"
    if not self.proxMoveToFloorBtn then
      local btn = ISButton:new(x, y, 110, buttonH, moveToFloorText, self, function() proxInvMoveToFloor(invSelf) end)
      btn:initialise()
      btn.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
      btn:setWidthToTitle()
      self.proxMoveToFloorBtn = btn
    end
    self.proxMoveToFloorBtn:setX(x) self.proxMoveToFloorBtn:setY(y) self.proxMoveToFloorBtn:setVisible(true)
    self:addChild(self.proxMoveToFloorBtn)
    table.insert(self.controls, self.proxMoveToFloorBtn)

    self:setHeight(math.max(self:getHeight(), y + buttonH + 1))
    self:setVisible(true)
  end
end

-- Defer registration so all mods have loaded before we decide
Events.OnGameStart.Add(function()
  if ISLootWindowFloorControlHandler and ISLootWindowContainerControls and ISLootWindowContainerControls.AddFloorHandler then
    registerCleanUIHandlers()
  else
    registerVanillaHook()
  end
end)


-- ============================================================
local old_ISInventoryPane_update = ISInventoryPane.update
function ISInventoryPane:update()
  if self.inventory and self.inventory:getType() == "proxInv" then
    local saved = {}
    for i, v in pairs(self.selected) do
      saved[i] = v
    end
    old_ISInventoryPane_update(self)
    for i, v in pairs(saved) do
      if instanceof(v, "InventoryItem") and v:getContainer() ~= nil then
        self.selected[i] = v
      end
    end
  else
    old_ISInventoryPane_update(self)
  end
end


-- ============================================================
-- Highlight nearby containers when proxInv is selected
-- ============================================================
local old_ISInventoryPage_update = ISInventoryPage.update
function ISInventoryPage:update()
  if old_ISInventoryPage_update then old_ISInventoryPage_update(self) end

  if not ProximityInventory.isEnabled:getValue() or self.onCharacter then return end

  self.coloredProxInventories = self.coloredProxInventories or {}

  for i=#self.coloredProxInventories, 1, -1 do
    local parent = self.coloredProxInventories[i]:getParent()
    if parent then
      parent:setHighlighted(self.player, false)
      parent:setOutlineHighlight(self.player, false)
      parent:setOutlineHlAttached(self.player, false)
    end
    self.coloredProxInventories[i] = nil
  end

  if not ProximityInventory.isHighlightEnableOption:getValue() or self.isCollapsed or self.inventory:getType() ~= "proxInv" then return end

  for i=1, #self.backpacks do
    local container = self.backpacks[i].inventory
    local parent = container:getParent()
    if parent and (instanceof(parent, "IsoObject") or instanceof(parent, "IsoDeadBody")) then
      parent:setHighlighted(self.player, true, false)
      parent:setHighlightColor(self.player, getCore():getObjectHighlitedColor())
      self.coloredProxInventories[#self.coloredProxInventories+1] = container
    end
  end
end
