-- NoSafehouse.lua
-- Prevents buildings inside blocked zones from being claimed as safehouses.

-- Each entry: { x1, y1, x2, y2 } defining a rectangle
local BLOCKED_ZONES = {
    { 11258, 14779, 11432, 15064 },
    { 11436, 14885, 11558, 15039 },
    { 11023, 14866, 11248, 14924 },
    { 11099, 14931, 11271, 15024 },
    { 14545, 5750, 14551, 5828 },
    { 4631, 9302, 4631 + 125, 9302 + 112 }, -- SerenityBunker
    { 11786, 6540, 11967, 6626 },
}

local function isInBlockedZone(x, y)
    for i = 1, #BLOCKED_ZONES do
        local z = BLOCKED_ZONES[i]
        if x >= z[1] and x <= z[3] and y >= z[2] and y <= z[4] then
            return true
        end
    end
    return false
end

local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local sq = player:getCurrentSquare()
    if not sq then return end

    if not isInBlockedZone(sq:getX(), sq:getY()) then return end

    local claimText = getText("ContextMenu_SafehouseClaim")
    local option = context:getOptionFromName(claimText)
    if option then
        option.notAvailable = true
        option.toolTip = ISWorldObjectContextMenu.addToolTip()
        option.toolTip.description = "This building cannot be claimed as a safehouse."
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
