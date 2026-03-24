require "TimedActions/ISBaseTimedAction"

function ISRemoveBrokenGlass:perform()
self.window:removeBrokenGlass()
self.character:getInventory():AddItem("LabItems.MatShatteredGlass")
self.character:playSound("Shatter_B")
-- needed to remove from queue / start next.
ISBaseTimedAction.perform(self)
end

function ISPickupBrokenGlass:perform()
-- add random damage to hands if no gloves (done in pickUpMoveable)
if ISMoveableTools.isObjectMoveable(self.glass) then
local moveable = ISMoveableTools.isObjectMoveable(self.glass)
moveable:pickUpMoveable( self.character, self.square, self.glass, true )
self.character:getInventory():AddItem("LabItems.MatShatteredGlass")
end

-- needed to remove from queue / start next.
ISBaseTimedAction.perform(self)
end