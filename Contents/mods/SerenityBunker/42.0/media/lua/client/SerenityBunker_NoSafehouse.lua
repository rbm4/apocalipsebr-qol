-- SerenityBunker_NoSafehouse.lua
-- Prevents buildings inside the SerenityBunker map from being claimed as safehouses.

-- SerenityBunker TownZone bounds from objects.lua:
-- x=4631, y=9302, width=125, height=112
-- local ZONE_X1 = 4631
-- local ZONE_Y1 = 9302
-- local ZONE_X2 = 4631 + 125
-- local ZONE_Y2 = 9302 + 112

-- local function isInSerenityBunker(x, y)
--     return x >= ZONE_X1 and x <= ZONE_X2 and y >= ZONE_Y1 and y <= ZONE_Y2
-- end

-- local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
--     if test then return end

--     local player = getSpecificPlayer(playerNum)
--     if not player then return end

--     local sq = player:getCurrentSquare()
--     if not sq then return end

--     if not isInSerenityBunker(sq:getX(), sq:getY()) then return end

--     local claimText = getText("ContextMenu_SafehouseClaim")
--     local option = context:getOptionFromName(claimText)
--     if option then
--         option.notAvailable = true
--         option.toolTip = ISWorldObjectContextMenu.addToolTip()
--         option.toolTip.description = "This building cannot be claimed as a safehouse."
--     end
-- end

-- Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
