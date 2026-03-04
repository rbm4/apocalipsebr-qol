-- Server-side command handler for Pumps Have Propane MP Fix
-- Also handles ISConsolidateDrainable sync

local function OnClientCommand(module, command, player, args)
    if module ~= "PumpsHavePropaneMP" then
        return
    end

    -- Command: refillItem - Refill a drainable item to full (gas pump refill)
    if command == "refillItem" then
        if not player or not args or not args.itemId then
            return
        end

        local item = player:getInventory():getItemById(args.itemId)
        if not item then
            return
        end

        -- Set to full on the server side
        if item.setUsedDelta then item:setUsedDelta(1.0) end
        local maxUses = 1
        if item.getMaxUses then maxUses = item:getMaxUses() end
        if maxUses < 1 then maxUses = 1 end
        if item.setCurrentUses then item:setCurrentUses(maxUses) end

        -- Sync to all clients
        sendItemStats(item)

    -- Command: syncItem - Broadcast current item state to all clients
    elseif command == "syncItem" then
        if not player or not args or not args.itemId then
            return
        end

        local item = player:getInventory():getItemById(args.itemId)
        if not item then
            return
        end

        sendItemStats(item)
    end
end

Events.OnClientCommand.Add(OnClientCommand)
