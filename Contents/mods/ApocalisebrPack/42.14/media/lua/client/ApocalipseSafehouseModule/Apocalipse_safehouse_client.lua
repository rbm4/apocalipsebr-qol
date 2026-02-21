-- -- =============================================================================
-- -- ApocalipseSafehouse Client Module
-- --
-- -- Hooks into OnSafehousesChanged (fires client-side whenever a safehouse
-- -- is claimed, released, or synced) and sends a command to the server so it
-- -- can run DesignationZone-based boundary scanning while chunks are loaded.
-- -- =============================================================================

-- local MODULE_NAME = "ApocalipseSafehouse"

-- local function log(msg)
--     print("[" .. MODULE_NAME .. ":Client] " .. tostring(msg))
-- end

-- -- Debounce: the event may fire multiple times in quick succession
-- local lastSentTime = 0
-- local DEBOUNCE_MS  = 2000  -- 2 seconds

-- local function onSafehousesChanged()
--     local player = getPlayer()
--     if not player then return end

--     local now = getTimestampMs()
--     if now - lastSentTime < DEBOUNCE_MS then return end
--     lastSentTime = now

--     local username = player:getUsername()
--     log("OnSafehousesChanged fired – notifying server for " .. username)
--     sendClientCommand(player, MODULE_NAME, "safehouseChanged", {})
-- end

-- Events.OnSafehousesChanged.Add(onSafehousesChanged)
-- log("Client module loaded. Listening for safehouse changes.")