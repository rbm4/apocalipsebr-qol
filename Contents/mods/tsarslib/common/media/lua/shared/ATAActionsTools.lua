ATA = ATA or {}

local function ReduceUses(inventoryItem, consumedUses)
    if not inventoryItem then return end
    
    inventoryItem:setUsedDelta(inventoryItem:getCurrentUsesFloat() - inventoryItem:getUseDelta() * consumedUses)
    
    if inventoryItem:getCurrentUses() < 0 then inventoryItem:setUsedDelta(0.0f) end
    sendItemStats(inventoryItem)
    if inventoryItem:getCurrentUsesFloat() <= 0.0001 then
        inventoryItem:UseAndSync()
    end
end

function ATA.consumeItems(use, character)
    local firstCondition = nil
    if use then
        local inventory = character:getInventory()
        for itemName, num in pairs(use) do
            itemName = itemName:gsub("__", ".")
            if not itemName:find('\.') then
                itemName = 'Base.'..itemName
            end
            local item = inventory:getBestConditionRecurse(itemName)
            if not item then
                print('ERROR ATA.consumeItems item instance is expected but missing for '..itemName..' check item availability failed before doing the action.')
            end
            
            if not firstCondition and item then
                firstCondition = item:getCondition()
            end
            if item:IsDrainable() then
                local array = inventory:getAllTypeRecurse(itemName)
                for i=0,array:size()-1 do
                    item = array:get(i)
                    local availableUses = item:getCurrentUses()
                    if availableUses >= num then
                        ReduceUses(item, num, character)
                        num = 0
                    else
                        ReduceUses(item, availableUses, character)
                        num = num - availableUses
                    end
                    if num == 0 then break end
                end
                if num > 0 then
                    print('ERROR ATA.consumeItems drainable item '..itemName..' is missing '..tostring(num or '0')..' charges at consumption time.')
                end
            else
                local array = inventory:getAllTypeRecurse(itemName)
                local size = array:size()
                if size < num then
                    print('ERROR ATA.consumeItems item '..itemName..' must be consumed (x'..tostring(num or '0')..') but only '..tostring(size or '0')..' are available.')
                end
                for i=0,size-1 do
                    if num == 0 then break end
                    item = array:get(i)
                    character:removeFromHands(item);
                    local container = item and item:getContainer()
                    if container then
                        container:Remove(item)
                        sendRemoveItemFromContainer(container,item)
                    end
                    num = num - 1
                end
            end
        end
    end
    
    return firstCondition
end
