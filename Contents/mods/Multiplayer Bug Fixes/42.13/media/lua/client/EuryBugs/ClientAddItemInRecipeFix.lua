require "TimedActions/ISAddItemInRecipe"

if not ISAddItemInRecipe then return end

-- Option-driven toggle (client-only)
-- Assumes your options helper is globally available as OPS and supports OPS.getBool(key, default)
local function fixEnabled()
    return true
end

local _oldNew         = ISAddItemInRecipe.new
local _oldIsValid     = ISAddItemInRecipe.isValid
local _oldWaitToStart = ISAddItemInRecipe.waitToStart
local _oldStart       = ISAddItemInRecipe.start

function ISAddItemInRecipe:new(character, recipe, baseItem, usedItem)
    local o = _oldNew(self, character, recipe, baseItem, usedItem)
    if fixEnabled() and o then
        if baseItem and baseItem.getID then o.baseItemID = baseItem:getID() end
        if usedItem and usedItem.getID then o.usedItemID = usedItem:getID() end
    end
    return o
end

-- Don’t kill the queue just because the transfer/sync hasn't landed yet.
function ISAddItemInRecipe:isValid()
    if not fixEnabled() then
        return _oldIsValid(self)
    end
    return self.character ~= nil and self.recipe ~= nil
end

-- Wait for both items to exist in the player inventory, then bind to the live instances.
function ISAddItemInRecipe:waitToStart()
    if not fixEnabled() then
        return _oldWaitToStart and _oldWaitToStart(self) or false
    end

    local inv = self.character and self.character:getInventory() or nil
    if not inv then return true end

    local base = self.baseItemID and inv:getItemById(self.baseItemID) or self.baseItem
    local used = self.usedItemID and inv:getItemById(self.usedItemID) or self.usedItem

    if not base or not used then
        return true
    end

    self.baseItem = base
    self.usedItem = used
    return false
end

function ISAddItemInRecipe:start()
    if fixEnabled() then
        local inv = self.character and self.character:getInventory() or nil
        if inv then
            if self.baseItemID then self.baseItem = inv:getItemById(self.baseItemID) or self.baseItem end
            if self.usedItemID then self.usedItem = inv:getItemById(self.usedItemID) or self.usedItem end
        end
    end
    return _oldStart(self)
end