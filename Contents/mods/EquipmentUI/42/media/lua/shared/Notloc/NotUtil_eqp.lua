if not NotUtil then
    NotUtil = {}
end

-- Assumes all items are the same type
NotUtil.createVanillaStacksFromItems = function(items, inventoryPane)
    local vanillaStack = {}
    vanillaStack.items = {}
    vanillaStack.invPanel = inventoryPane

    if items[1] then
        vanillaStack.name = items[1]:getName()
        vanillaStack.cat = items[1]:getDisplayCategory() or items[1]:getCategory();
    end

    local weight = 0
    table.insert(vanillaStack.items, items[1])
    for _, item in ipairs(items) do
        table.insert(vanillaStack.items, item)
        weight = weight + item:getUnequippedWeight()
    end
    vanillaStack.weight = weight
    vanillaStack.count = #items + 1

    return {vanillaStack}
end