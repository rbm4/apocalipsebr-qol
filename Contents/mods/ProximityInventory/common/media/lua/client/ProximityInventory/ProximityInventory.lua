local ProximityInventory = {}

-- Options
ProximityInventory.options = PZAPI.ModOptions:create("ProximityInventory", "Proximity Inventory")

ProximityInventory.isEnabled = ProximityInventory.options:addTickBox(
  "ProximityInventory_isEnabled",
  getText("UI_optionscreen_binding_ProximityInventory_isEnabled"),
  true
)

ProximityInventory.toggleEnabledOption = ProximityInventory.options:addKeyBind(
  "ProximityInventory_toggleEnabled",
  getText("UI_optionscreen_binding_ProximityInventory_toggleEnabled"),
  Keyboard.KEY_NUMPAD1
)

ProximityInventory.toggleForceSelectedOption = ProximityInventory.options:addKeyBind(
  "ProximityInventory_ToggleForceSelected",
  getText("UI_optionscreen_binding_ProximityInventory_ToggleForceSelected"),
  Keyboard.KEY_NUMPAD0
)

ProximityInventory.isHighlightEnableOption = ProximityInventory.options:addTickBox(
  "ProximityInventory_isHighlightEnableOption",
  getText("UI_optionscreen_binding_ProximityInventory_isHighlightEnableOption"),
  true
)

-- Consts
ProximityInventory.inventoryIcon = getTexture("media/ui/ProximityInventory.png")
ProximityInventory.forceSelectIcon = getTexture("media/ui/Panel_Icon_Pin.png")

---@type { [number]: ItemContainer? }
ProximityInventory.itemContainer = {}
---@type { [number]: ISButton? } -- Reference of the button in the UI for each player
ProximityInventory.inventoryButtonRef = {}
---@type { [number]: boolean? } -- Reference of the button in the UI for each player
ProximityInventory.isForceSelected = {}

---@param container ItemContainer
---@param playerObj IsoPlayer
function ProximityInventory.CanBeAdded(container, playerObj)
  local object = container:getParent()

  if SandboxVars.ProximityInventory.ZombieOnly then
    return container:getType() == "inventoryfemale" or container:getType() == "inventorymale"
  end

  -- Don't allow to see inside containers locked to you, for MP
  if object and instanceof(object, "IsoThumpable") and object:isLockedToCharacter(playerObj) then
    return false
  end

  return true
end

---@param playerNum number
function ProximityInventory.GetItemContainer(playerNum)
  if ProximityInventory.itemContainer[playerNum] then
    return ProximityInventory.itemContainer[playerNum]
  end

  ProximityInventory.itemContainer[playerNum] = ItemContainer.new("proxInv", nil, nil)
  ProximityInventory.itemContainer[playerNum]:setExplored(true)
  ProximityInventory.itemContainer[playerNum]:setOnlyAcceptCategory("none") -- Ensures you can't put stuff in it
  ProximityInventory.itemContainer[playerNum]:setCapacity(0)                -- Makes the UI Render the weight as XXX/0 instead of the default XXX/50

  return ProximityInventory.itemContainer[playerNum]
end

---@param invSelf ISInventoryPage
---@return ISButton
function ProximityInventory.AddProximityInventoryButton(invSelf)
  local itemContainer = ProximityInventory.GetItemContainer(invSelf.player)
  itemContainer:clear() -- We want to reset the proxinv between refreshes

  local title = getText("IGUI_ProxInv_InventoryName")

  if getSpecificPlayer(invSelf.player):getVehicle() then
    title = title .. " - " .. getText("GameSound_Category_Vehicle")
  end

  local proxInvButton = invSelf:addContainerButton(
    itemContainer,
    ProximityInventory.inventoryIcon,
    title
  )

  proxInvButton.textureOverride = ProximityInventory.isForceSelected[invSelf.player]
      and ProximityInventory.forceSelectIcon
      or nil

  return proxInvButton
end

---Adds the button at the top of the list of the containers, so that it always appears as first
---@param invSelf ISInventoryPage
function ProximityInventory.OnBeginRefresh(invSelf)
  local proxInvButton = ProximityInventory.AddProximityInventoryButton(invSelf)

  -- We will need this ref for after the button are added
  ProximityInventory.inventoryButtonRef[invSelf.player] = proxInvButton
end

---TODO Maybe Re-work this? We I could hook into ISInventoryPage:addContainerButton and insert the items from there, it could save us some performance
---@param invSelf ISInventoryPage
function ProximityInventory.OnButtonsAdded(invSelf)
  local proximityButtonRef = ProximityInventory.inventoryButtonRef[invSelf.player]
  if not proximityButtonRef then return end -- something must have gone wrong if this returns here

  local playerNum = invSelf.player --[[@as number]]
  local playerObj = getSpecificPlayer(invSelf.player)

  -- Handle force selected
  if ProximityInventory.isForceSelected[playerNum] then
    invSelf:setForceSelectedContainer(ProximityInventory.GetItemContainer(playerNum))
  end

  -- Add All backpacks content except proxInv (TODO: Ensure the 'except proxInv' part)
  for i = 1, #invSelf.backpacks do
    local invToAdd = invSelf.backpacks[i].inventory
    if ProximityInventory.CanBeAdded(invToAdd, playerObj) then
      local items = invToAdd:getItems()
      proximityButtonRef.inventory:getItems():addAll(items)
    end
  end
end

function ProximityInventory.OnToggle()
  ProximityInventory.isEnabled:setValue(not ProximityInventory.isEnabled:getValue())
  PZAPI.ModOptions:save()

  ISInventoryPage.dirtyUI() -- Let's force a reset of the UI
end

function ProximityInventory.OnToggleForceSelected()
  local playerNum = 0
  local player = getSpecificPlayer(playerNum)

  ProximityInventory.isForceSelected[playerNum] = not ProximityInventory.isForceSelected[playerNum]

  local text = ProximityInventory.isForceSelected[playerNum]
      and getText("IGUI_ProxInv_Text_ForceSelectOn")
      or getText("IGUI_ProxInv_Text_ForceSelectOff")
      HaloTextHelper.addText(player, text, "", HaloTextHelper.getColorWhite())

  ISInventoryPage.dirtyUI() -- Let's force a reset of the UI
end

Events.OnKeyPressed.Add(function(key)
  if not getPlayer() then return end
  if key == ProximityInventory.toggleForceSelectedOption:getValue() then
    return ProximityInventory.OnToggleForceSelected()
  end
  if key == ProximityInventory.toggleEnabledOption:getValue() then
    return ProximityInventory.OnToggle()
  end
end);


Events.OnRefreshInventoryWindowContainers.Add(function(invSelf, state)
  if not ProximityInventory.isEnabled:getValue() or invSelf.onCharacter then
    -- Ignore character containers, as usual, but I Wonder if instead it would be nice to have
    -- I did just enable proxinv for vehicles, so I'll need to wait for feedback
    return
  end

  if state == "begin" then
    return ProximityInventory.OnBeginRefresh(invSelf)
  end

  if state == "buttonsAdded" then
    return ProximityInventory.OnButtonsAdded(invSelf)
  end
end)

return ProximityInventory