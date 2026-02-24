AutoMechanics = AutoMechanics or {}


function AutoMechanics.gameSpeedMultiplierToGameSpeed(multiplier)
    if multiplier == 40 then return 4 end
    if multiplier == 20 then return 3 end
    if multiplier == 5 then return 2 end
    if multiplier ~= 1 then print ("AutoMechanics.gameSpeedMultiplierToGameSpeed set speed 1 for multiplier "..tostring(multiplier or "nil")) end
    return 1
end

function AutoMechanics.getConditionLossPercentage(player, part)--returns 0 when part condition cannot decrease on install/uninstall action.
    local installTable = part:getTable('uninstall')
    if not installTable then
        installTable = part:getTable('install')--some mods break install table but not uninstall one
    end
    if AutoMechanics.getVerbose() then print ("AutoMechanics.getConditionLossPercentage "..tostring(installTable or 'nil')); end
    local success, failure = false, true
    if installTable then
        local perks = installTable.skills;--notice we use only the install table (like VehicleCommands). this may break over time.
        local perksTable = VehicleUtils.getPerksTableForChr(perks, player)
        success, failure = VehicleUtils.calculateInstallationSuccess(perks, player, perksTable);
    end
    if AutoMechanics.getVerbose() then print ("AutoMechanics.getConditionLossPercentage"..tostring(player)..tostring(failure)..tostring(part:getItemType())); end
    return failure
end

function AutoMechanics.getPartValidForTrainingState(player, part)
    if not part then return 0 end
    if AutoMechanics.getVerbose() then
        local itemType = part:getItemType();
        local isEmpty = "true"
        if not itemType then
            itemType = "nil"
        else
            isEmpty = (not part:getItemType():isEmpty()) and "false" or "true"
        end
        local partInventoryItem = part:getInventoryItem() or "nil"
        print ("AutoMechanics.isPartValidForTraining "..tostring(part)
        .." itemType="..tostring(itemType)
        .." isEmpty="..tostring(isEmpty)
        .." invItem="..tostring(partInventoryItem)
        .." hasTable="..(part:getTable('uninstall')~=nil and "true" or "false")
        .." category="..tostring(part:getCategory())
        .." canUninstall="..(part:getVehicle():canUninstallPart(player, part) and "true" or "false")
        );
    end
    
    local isUninstallable = part:getItemType() and not part:getItemType():isEmpty() and part:getInventoryItem() and part:getTable('uninstall') and part:getCategory() ~= "nodisplay";--notice we use only the uninstall table. this may break over time.
    isUninstallable = isUninstallable and AutoMechanics.getConditionLossPercentage(player, part) <= AutoMechanics.getConditionLossPercentageThreshold();--so we filter on perk level at start. we won't do it if we get the required level during that session.
    local isUninstallableNow = isUninstallable and part:getVehicle():canUninstallPart(player, part)

    if isUninstallableNow then return 2; end--ok for main job list
    if isUninstallable then return 1; end--look for job dependency ? or maybe just reparse that table after each uninstall.
    return 0;--do not train on that part
end

function AutoMechanics.getInventoryItem(player, itemId)--returns the item only if it is in player main inventory
    local playerInv = player:getInventory();
    local it = playerInv:getItems()
    local initialInvLastIt = it:size()-1;
    for i = 0, initialInvLastIt do
        local item = it:get(initialInvLastIt-i)--decreasing loop because we were potentially removing the item [OBSOLETE]
        if item:getID() == itemId then
            return item
        end
    end
    return nil
end

function getAnyItemOnPlayerThatMatchesThatPart(player, part)
    local typeToItem = VehicleUtils.getItems(player:getPlayerNum())
    -- among all possible items that can be installed on that part
    for i=0,part:getItemType():size() - 1 do
        local name = part:getItemType():get(i);
        local item = instanceItem(name);
        if item then name = item:getName(); end
        --if any type is owned by the player
        if typeToItem[part:getItemType():get(i)] then
            for j,v in ipairs(typeToItem[part:getItemType():get(i)]) do
                return v;--return first valid item met
            end
        end
    end
    return nil
end

function AutoMechanics.dropBrokenItems(player)
    local playerInv = player:getInventory();
    local it = playerInv:getItems()
    local initialInvLastIt = it:size()-1;
    for i = 0, initialInvLastIt do
        local item = it:get(initialInvLastIt-i)--decreasing loop because we are potentially removing the item we look at
        if item:isBroken() then
            local square = player:getCurrentSquare()
            local dropX,dropY,dropZ = ISTransferAction.GetDropItemOffset(player, square, invItem)--some random position around the player
            square:AddWorldInventoryItem(item, dropX,dropY,dropZ);
            playerInv:Remove(item);
        end
    end
end

function AutoMechanics.dropItem(player, invItem)
    if invItem and player and player:getInventory():contains(invItem) then
        local square = player:getCurrentSquare()
        local playerInv = player:getInventory();
        invItem:getContainer():setDrawDirty(true);
        invItem:setJobDelta(0.0);
        playerInv:Remove(invItem);
        local dropX,dropY,dropZ = ISTransferAction.GetDropItemOffset(player, square, invItem)--some random position around the player
        square:AddWorldInventoryItem(invItem, dropX,dropY,dropZ);
        ISInventoryPage.renderDirty = true
        ISInventoryPage.dirtyUI();--set inventory dirty to force loot window recomputation: FAILED
    end
end
