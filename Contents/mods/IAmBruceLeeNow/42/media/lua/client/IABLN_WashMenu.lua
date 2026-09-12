require "ISUI/ISWorldObjectContextMenu"

local STYLE_TYPE = "IAmBruceLeeNow.MartialArtsFightingStyle"

local function isStyleProxy(item)
    if not item or type(item) ~= "userdata" then return false end
    if not instanceof(item, "InventoryItem") then return false end
    return item:getFullType() == STYLE_TYPE
end

-- The proxy must carry blood so the equipped-hand tooltip reflects the real
-- wraps. It is not itself a physical item the player should wash, however.
local originalOnWashClothing = ISWorldObjectContextMenu.onWashClothing
ISWorldObjectContextMenu.onWashClothing = function(
        playerObj, sink, soapList, washList, singleClothing)
    if isStyleProxy(singleClothing) then return end

    if washList then
        local filtered = {}
        for _, item in ipairs(washList) do
            if not isStyleProxy(item) then
                filtered[#filtered + 1] = item
            end
        end
        if #filtered == 0 then return end
        washList = filtered
    end

    return originalOnWashClothing(
        playerObj, sink, soapList, washList, singleClothing)
end

local function optionReferencesProxy(option)
    if isStyleProxy(option.itemForTexture) then return true end
    for index = 1, 10 do
        if isStyleProxy(option["param" .. tostring(index)]) then return true end
    end
    return false
end

local function removeProxyOptions(context, visited)
    if not context or visited[context] then return end
    visited[context] = true

    for index = #(context.options or {}), 1, -1 do
        local option = context.options[index]
        if option.subOption then
            removeProxyOptions(context:getSubMenu(option.subOption), visited)
        end
        if optionReferencesProxy(option) then
            context:removeOptionByName(option.name)
        end
    end
end

local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end
    removeProxyOptions(context, {})
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
