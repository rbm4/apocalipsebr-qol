-- Very important file, it avoids duping in SP and MP
local ProximityInventory = require("ProximityInventory/ProximityInventory")

local ISCraftingUI_getContainers = ISCraftingUI.getContainers
function ISCraftingUI:getContainers()
  ISCraftingUI_getContainers(self)
  if not self.character or not self.containerList then return end

  local proxInvContainer = ProximityInventory.GetItemContainer(self.playerNum)

  self.containerList:remove(proxInvContainer);
end

-- Used by
-- - media\lua\client\ISUI\ISInventoryPaneContextMenu.lua
-- - media\lua\client\Entity\ISUI\CraftRecipe\ISHandCraftPanel.lua
local ISInventoryPaneContextMenu_getContainers = ISInventoryPaneContextMenu.getContainers
ISInventoryPaneContextMenu.getContainers = function(character)
  local containerList = ISInventoryPaneContextMenu_getContainers(character)
  if not containerList then return end

  local proxInvContainer = ProximityInventory.GetItemContainer(character:getPlayerNum())

  containerList:remove(proxInvContainer)

  return containerList;
end
