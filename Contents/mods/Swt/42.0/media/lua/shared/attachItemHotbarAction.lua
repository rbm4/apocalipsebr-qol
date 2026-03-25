require("TimedActions/ISAttachItemHotbar")

local action_new = ISAttachItemHotbar.new
function ISAttachItemHotbar:new(character, item, slot, slotIndex, slotDef)
    local action = action_new(self, character, item, slot, slotIndex, slotDef)
    action.stopOnAim = false
    return action
end