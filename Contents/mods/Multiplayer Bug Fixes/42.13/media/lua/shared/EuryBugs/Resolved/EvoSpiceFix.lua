local MOD = "EvoSpiceFix"

local DEBUG = getCore():getDebug()

local function log(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][SH] " .. tostring(msg))
    end
end

local version = require("EuryBugs/_Version")
if not (version and version.isAtMax("42.13.1")) then
    log("skipped patch")
    return
end

local CMD = "SyncEvoSpices"

local function dirtyUI()
    if ISInventoryPage and ISInventoryPage.dirtyUI then
        ISInventoryPage.dirtyUI()
    end
end

local function isSpiceItem(item)
    -- Vanilla truth: EvolvedRecipe.addItem branches on usedItemFood.isSpice()
    -- and also uses InventoryItem.isSpice() in item checks.
    return item and item.isSpice and item:isSpice() == true
end

local function spicesToLua(food)
    local out = {}
    if not (food and instanceof(food, "Food") and food.getSpices) then return out end
    local s = food:getSpices()
    if not s then return out end
    for i = 0, s:size() - 1 do
        out[#out + 1] = s:get(i)
    end
    return out
end

-- --------------------
-- Client side: apply spices to the correct item + refresh UI
-- --------------------
local function tryInvGetById(inv, id)
    if not (inv and id) then return nil end
    if inv.getItemById then
        local it = inv:getItemById(id)
        if it then return it end
    end
    return nil
end

local function findItemByIdClient(playerNum, id)
    if not id then return nil end

    local player = getSpecificPlayer(playerNum)
    if player then
        local it = tryInvGetById(player:getInventory(), id)
        if it then return it end

        local ph = player:getPrimaryHandItem()
        if ph and ph.getID and ph:getID() == id then return ph end

        local sh = player:getSecondaryHandItem()
        if sh and sh.getID and sh:getID() == id then return sh end
    end

    -- Inventory UI pane container (if open)
    local invPage = getPlayerInventory and getPlayerInventory(playerNum)
    if invPage and invPage.inventoryPane and invPage.inventoryPane.inventory then
        local it = tryInvGetById(invPage.inventoryPane.inventory, id)
        if it then return it end
    end

    -- Loot UI pane container (common: EVO base food sits in nearby container)
    local lootPage = getPlayerLoot and getPlayerLoot(playerNum)
    if lootPage and lootPage.inventoryPane and lootPage.inventoryPane.inventory then
        local it = tryInvGetById(lootPage.inventoryPane.inventory, id)
        if it then return it end
    end

    return nil
end

if isClient() then
    local function onServerCommand(module, command, args)
        if module ~= MOD or command ~= CMD then return end
        if not (args and args.id and args.spices) then return end

        local playerNum = args.playerNum or 0
        local item = findItemByIdClient(playerNum, args.id)
        if not (item and instanceof(item, "Food") and item.setSpices) then
            return
        end

        local ArrayList = (ArrayList or java.util.ArrayList)
        local list = ArrayList.new()
        for i = 1, #args.spices do
            list:add(args.spices[i])
        end

        item:setSpices(list)
        dirtyUI()
        -- log("Applied spices for itemID " .. tostring(args.id))
    end

    Events.OnServerCommand.Add(onServerCommand)
end

-- --------------------
-- Hook: ISAddItemInRecipe.complete
-- Only sync when the consumed item is a spice (vanilla’s own classification)
-- --------------------
do
    if not (ISAddItemInRecipe and ISAddItemInRecipe.complete) then return end

    local _origComplete = ISAddItemInRecipe.complete

    ISAddItemInRecipe.complete = function(self, ...)
        local usedItem = self and self.usedItem
        local shouldSync = isSpiceItem(usedItem)

        local ret = _origComplete(self, ...)

        if shouldSync then
            local chr = self and self.character
            local baseItem = self and self.baseItem

            if isServer() then
                if chr and baseItem and baseItem.getID then
                    sendServerCommand(chr, MOD, CMD, {
                        playerNum = chr.getPlayerNum and chr:getPlayerNum() or 0,
                        id = baseItem:getID(),
                        spices = spicesToLua(baseItem),
                    })
                    -- log("Synced spices for itemID " .. tostring(baseItem:getID()))
                end
            else
                -- SP / local host: force refresh so you see the spice immediately
                dirtyUI()
            end
        end

        return ret
    end
end
