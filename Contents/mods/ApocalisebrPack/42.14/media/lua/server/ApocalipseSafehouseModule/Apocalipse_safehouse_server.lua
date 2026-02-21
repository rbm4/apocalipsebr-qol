-- -- =============================================================================
-- -- ApocalipseSafehouse Server Module
-- --
-- -- Three responsibilities:
-- --   1) EXPANSION  – reads a CSV queue file written by an external Spring app.
-- --                   Each row is: username,tiles
-- --                   The Spring app decides how many tiles to grant.
-- --   2) TRACKING   – polls SafeHouse.getSafehouseList() every hour and writes
-- --                   a JSON file with all claimed safehouses + maxExpand limits,
-- --                   so the Spring app can read who owns what and how far they
-- --                   can expand.
-- --   3) BOUNDARY SCAN – when a player claims a safehouse the client sends
-- --                   a command; the server scans outward using DesignationZone
-- --                   to calculate how far the safehouse can expand per direction
-- --                   without entering another claimable building zone. Also
-- --                   detects unclaims and logs them so the Spring app can reset.
-- --
-- -- Works even if the target player is offline (SafeHouse is server-side data).
-- -- Boundary scan requires chunks loaded (triggered by client on claim).
-- -- =============================================================================

-- local MODULE_NAME = "ApocalipseSafehouse"
-- local BASE_DIR = "ApocalipseSafehouse/"

-- -- Files read/written by this module (all under Zomboid/Lua/)
-- local QUEUE_FILE       = BASE_DIR .. "queue.csv"
-- local PROCESSED_FILE   = BASE_DIR .. "processed.csv"
-- local SAFEHOUSES_FILE  = BASE_DIR .. "safehouses.json"
-- local UNCLAIMED_FILE   = BASE_DIR .. "unclaimed.csv"

-- local CSV_QUEUE_HEADER     = "username,tiles"
-- local CSV_PROCESSED_HEADER = "timestamp,username,tiles_requested,tiles_applied,status,message"
-- local CSV_UNCLAIMED_HEADER = "timestamp,username,x,y,w,h"

-- -- =============================================================================
-- -- Configuration
-- -- =============================================================================
-- local CONFIG = {
--     MODDATA_KEY          = "ApocalipseSafehouse",
--     MAX_SCAN_DISTANCE    = 30,  -- max tiles to scan outward per direction
--     MAX_EXPANSION_PER_DIR = 15, -- absolute cap per direction
--     SAFEHOUSE_BUFFER     = 2,   -- gap to leave before neighbor zone
-- }

-- local function log(msg)
--     print("[" .. MODULE_NAME .. "] " .. tostring(msg))
-- end

-- -- =============================================================================
-- -- Minimal JSON encoder
-- -- =============================================================================

-- local jsonEncode

-- local function jsonEncodeString(s)
--     s = s:gsub('\\', '\\\\'):gsub('"', '\\"')
--        :gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
--     return '"' .. s .. '"'
-- end

-- local function isArray(t)
--     local i = 0
--     for _ in pairs(t) do
--         i = i + 1
--         if t[i] == nil then return false end
--     end
--     return true
-- end

-- jsonEncode = function(value)
--     local vtype = type(value)
--     if value == nil then return "null"
--     elseif vtype == "boolean" then return value and "true" or "false"
--     elseif vtype == "number"  then return tostring(value)
--     elseif vtype == "string"  then return jsonEncodeString(value)
--     elseif vtype == "table" then
--         if isArray(value) then
--             local parts = {}
--             for _, v in ipairs(value) do parts[#parts+1] = jsonEncode(v) end
--             return "[" .. table.concat(parts, ",") .. "]"
--         else
--             local parts = {}
--             for k, v in pairs(value) do
--                 parts[#parts+1] = jsonEncodeString(tostring(k)) .. ":" .. jsonEncode(v)
--             end
--             return "{" .. table.concat(parts, ",") .. "}"
--         end
--     end
--     return "null"
-- end

-- -- =============================================================================
-- -- File I/O helpers
-- -- =============================================================================

-- local function ensureFile(filePath, header)
--     local reader = getFileReader(filePath, true)
--     if reader then reader:close(); return end
--     local writer = getFileWriter(filePath, true, false)
--     if writer then
--         writer:write(header .. "\n")
--         writer:close()
--         log("Created file: " .. filePath)
--     end
-- end

-- local function readLines(filePath)
--     local lines = {}
--     local reader = getFileReader(filePath, true)
--     if not reader then return lines end
--     local line = reader:readLine()
--     while line ~= nil do
--         line = line:match("^%s*(.-)%s*$") or ""
--         if line ~= "" and line:sub(1,1) ~= "#" then
--             lines[#lines+1] = line
--         end
--         line = reader:readLine()
--     end
--     reader:close()
--     return lines
-- end

-- local function writeFileRaw(filePath, content)
--     local writer = getFileWriter(filePath, true, false)
--     if writer then writer:write(content); writer:close() end
-- end

-- local function writeFileWithHeader(filePath, header, lines)
--     local writer = getFileWriter(filePath, true, false)
--     if not writer then log("ERROR: Could not write " .. filePath); return end
--     writer:write(header .. "\n")
--     if lines then
--         for _, l in ipairs(lines) do writer:write(l .. "\n") end
--     end
--     writer:close()
-- end

-- local function appendLine(filePath, line)
--     local writer = getFileWriter(filePath, true, true)
--     if writer then writer:write(line .. "\n"); writer:close() end
-- end

-- local function getTimestamp()
--     local gt = getGameTime()
--     if gt then
--         return "Day" .. gt:getNightsSurvived() .. "_H" .. gt:getHour()
--     end
--     return "unknown"
-- end

-- -- =============================================================================
-- -- Queue CSV: username,tiles
-- -- =============================================================================

-- local function readQueue()
--     local entries = {}
--     for _, line in ipairs(readLines(QUEUE_FILE)) do
--         if line ~= CSV_QUEUE_HEADER then
--             local username, tilesStr = line:match("^([^,]+),(%d+)$")
--             if username and tilesStr then
--                 username = username:match("^%s*(.-)%s*$")
--                 local tiles = tonumber(tilesStr)
--                 if username ~= "" and tiles and tiles > 0 then
--                     entries[#entries+1] = { username = username, tiles = tiles }
--                 end
--             else
--                 log("WARN: Ignoring malformed queue line: " .. line)
--             end
--         end
--     end
--     return entries
-- end

-- local function clearQueue()
--     writeFileWithHeader(QUEUE_FILE, CSV_QUEUE_HEADER, nil)
-- end

-- local function logProcessed(username, tilesRequested, tilesApplied, status, message)
--     message = message:gsub(",", ";")
--     appendLine(PROCESSED_FILE,
--         getTimestamp() .. "," .. username .. "," .. tilesRequested .. ","
--         .. tilesApplied .. "," .. status .. "," .. message)
-- end

-- -- =============================================================================
-- -- Expansion History (ModData – persists across restarts)
-- -- =============================================================================

-- local function getModData()
--     local md = ModData.getOrCreate(CONFIG.MODDATA_KEY)
--     if not md.safehouses then md.safehouses = {} end
--     return md
-- end

-- local function getExpansionHistory(owner)
--     local entry = getModData().safehouses[owner]
--     if entry then
--         return entry.totalTilesExpanded or 0, entry.originalBounds, entry.maxExpand
--     end
--     return 0, nil, nil
-- end

-- local function saveExpansionHistory(owner, originalBounds, totalTilesExpanded, maxExpand)
--     getModData().safehouses[owner] = {
--         originalBounds     = originalBounds,
--         totalTilesExpanded = totalTilesExpanded,
--         maxExpand          = maxExpand,
--     }
-- end

-- local function clearExpansionHistory(owner)
--     getModData().safehouses[owner] = nil
--     log("Cleared expansion history for: " .. owner)
-- end

-- -- =============================================================================
-- -- DesignationZone boundary scanning
-- -- Scans outward from safehouse edge tile-by-tile per direction.
-- -- Stops when hitting:
-- --   1) A DesignationZone that doesn't overlap our safehouse (neighbor zone)
-- --   2) A different claimed SafeHouse
-- --   3) CONFIG.MAX_SCAN_DISTANCE
-- -- Returns safe tiles before obstacle, minus buffer.
-- -- =============================================================================

-- --- Identify DesignationZone(s) that our safehouse sits on
-- ---@param safehouse any
-- ---@return table<string,boolean> set of zone keys
-- local function getOwnZones(safehouse)
--     local ownZones = {}
--     local sx, sy = safehouse:getX(), safehouse:getY()
--     local sw, sh = safehouse:getW(), safehouse:getH()

--     -- Sample several interior points
--     local points = {
--         { sx + math.floor(sw/2), sy + math.floor(sh/2) },
--         { sx + 2, sy + 2 },
--         { sx + sw - 3, sy + 2 },
--         { sx + 2, sy + sh - 3 },
--         { sx + sw - 3, sy + sh - 3 },
--         { sx + math.floor(sw/2), sy + 2 },
--         { sx + math.floor(sw/2), sy + sh - 3 },
--     }

--     for _, pt in ipairs(points) do
--         local zone = DesignationZone.getZone(pt[1], pt[2], 0)
--         if zone then
--             local key = zone:getX() .. "," .. zone:getY() .. "," .. zone:getW() .. "," .. zone:getH()
--             ownZones[key] = true
--         end
--     end

--     return ownZones
-- end

-- --- Check if tile (tx,ty) is inside a DesignationZone that is NOT one of ours
-- ---@param tx number
-- ---@param ty number
-- ---@param ownZones table<string,boolean>
-- ---@return boolean
-- local function isForeignZone(tx, ty, ownZones)
--     local zone = DesignationZone.getZone(tx, ty, 0)
--     if not zone then return false end -- open ground
--     local key = zone:getX() .. "," .. zone:getY() .. "," .. zone:getW() .. "," .. zone:getH()
--     return not ownZones[key]
-- end

-- --- Check if tile (tx,ty) is inside another claimed safehouse
-- ---@param tx number
-- ---@param ty number
-- ---@param safehouse any ours to exclude
-- ---@return boolean
-- local function isOtherSafehouse(tx, ty, safehouse)
--     local list = SafeHouse.getSafehouseList()
--     if not list then return false end
--     for i = 0, list:size() - 1 do
--         local other = list:get(i)
--         if other ~= safehouse then
--             if tx >= other:getX() and tx < other:getX() + other:getW()
--                and ty >= other:getY() and ty < other:getY() + other:getH() then
--                 return true
--             end
--         end
--     end
--     return false
-- end

-- --- Scan outward from safehouse edge in one direction
-- ---@param safehouse any
-- ---@param direction string
-- ---@param ownZones table
-- ---@return number safe tiles
-- local function scanDirection(safehouse, direction, ownZones)
--     local sx, sy = safehouse:getX(), safehouse:getY()
--     local sw, sh = safehouse:getW(), safehouse:getH()
--     local maxDist = math.min(CONFIG.MAX_SCAN_DISTANCE, CONFIG.MAX_EXPANSION_PER_DIR)

--     for dist = 1, maxDist do
--         local blocked = false

--         if direction == "left" then
--             local tx = sx - dist
--             for ty = sy, sy + sh - 1 do
--                 if isForeignZone(tx, ty, ownZones) or isOtherSafehouse(tx, ty, safehouse) then
--                     blocked = true; break
--                 end
--             end
--         elseif direction == "right" then
--             local tx = sx + sw + dist - 1
--             for ty = sy, sy + sh - 1 do
--                 if isForeignZone(tx, ty, ownZones) or isOtherSafehouse(tx, ty, safehouse) then
--                     blocked = true; break
--                 end
--             end
--         elseif direction == "up" then
--             local ty = sy - dist
--             for tx = sx, sx + sw - 1 do
--                 if isForeignZone(tx, ty, ownZones) or isOtherSafehouse(tx, ty, safehouse) then
--                     blocked = true; break
--                 end
--             end
--         elseif direction == "down" then
--             local ty = sy + sh + dist - 1
--             for tx = sx, sx + sw - 1 do
--                 if isForeignZone(tx, ty, ownZones) or isOtherSafehouse(tx, ty, safehouse) then
--                     blocked = true; break
--                 end
--             end
--         end

--         if blocked then
--             return math.max(0, dist - 1 - CONFIG.SAFEHOUSE_BUFFER)
--         end
--     end

--     return maxDist
-- end

-- --- Calculate expansion limits in all 4 directions.
-- --- MUST be called with chunks loaded (player nearby).
-- ---@param safehouse any
-- ---@return table {left=n, right=n, up=n, down=n}
-- local function calculateExpansionLimits(safehouse)
--     local ownZones = getOwnZones(safehouse)

--     local count = 0
--     for _ in pairs(ownZones) do count = count + 1 end
--     log("Own DesignationZones found: " .. count)

--     local limits = {
--         left  = scanDirection(safehouse, "left",  ownZones),
--         right = scanDirection(safehouse, "right", ownZones),
--         up    = scanDirection(safehouse, "up",    ownZones),
--         down  = scanDirection(safehouse, "down",  ownZones),
--     }

--     log(string.format("Expansion limits: L=%d R=%d U=%d D=%d",
--         limits.left, limits.right, limits.up, limits.down))

--     return limits
-- end

-- -- =============================================================================
-- -- Remove-and-Recreate (network sync)
-- -- =============================================================================

-- local function recreateSafehouse(safehouse, newX, newY, newW, newH)
--     local owner = safehouse:getOwner()
--     local title = safehouse:getTitle()
--     local oldX, oldY = safehouse:getX(), safehouse:getY()
--     local oldW, oldH = safehouse:getW(), safehouse:getH()

--     local membersList = {}
--     for i = 0, safehouse:getPlayers():size() - 1 do
--         membersList[#membersList+1] = safehouse:getPlayers():get(i)
--     end
--     local respawnList = {}
--     for i = 0, safehouse:getPlayersRespawn():size() - 1 do
--         respawnList[#respawnList+1] = safehouse:getPlayersRespawn():get(i)
--     end

--     SafeHouse.removeSafeHouse(safehouse)

--     local newSafe = SafeHouse.addSafeHouse(newX, newY, newW, newH, owner)
--     if not newSafe then
--         log("ERROR: Engine rejected safehouse for " .. owner .. ", rolling back")
--         local rb = SafeHouse.addSafeHouse(oldX, oldY, oldW, oldH, owner)
--         if rb then
--             rb:setTitle(title)
--             for _, p in ipairs(membersList) do
--                 if p ~= owner then rb:addPlayer(p) end
--             end
--             for _, p in ipairs(respawnList) do
--                 rb:setRespawnInSafehouse(true, p)
--             end
--         end
--         return nil
--     end

--     newSafe:setTitle(title)
--     for _, p in ipairs(membersList) do
--         if p ~= owner then newSafe:addPlayer(p) end
--     end
--     for _, p in ipairs(respawnList) do
--         newSafe:setRespawnInSafehouse(true, p)
--     end
--     return newSafe
-- end

-- -- =============================================================================
-- -- Core Resize
-- -- =============================================================================

-- local function resizeSafehouse(username, tilesPerDirection)
--     local safehouse = SafeHouse.getSafehouseByOwner(username)
--     if not safehouse then
--         local memberOf = SafeHouse.hasSafehouse(username)
--         if memberOf then
--             return false, "Not the owner (owned by " .. memberOf:getOwner() .. ")", 0
--         end
--         return false, "No safehouse found for " .. username, 0
--     end

--     local totalExpanded, originalBounds, maxExpand = getExpansionHistory(username)

--     if not originalBounds then
--         originalBounds = {
--             x = safehouse:getX(), y = safehouse:getY(),
--             w = safehouse:getW(), h = safehouse:getH(),
--         }
--     end

--     -- Clamp to pre-calculated DesignationZone limits if available
--     local left  = tilesPerDirection
--     local right = tilesPerDirection
--     local up    = tilesPerDirection
--     local down  = tilesPerDirection

--     if maxExpand then
--         left  = math.min(left,  maxExpand.left  or 0)
--         right = math.min(right, maxExpand.right or 0)
--         up    = math.min(up,    maxExpand.up    or 0)
--         down  = math.min(down,  maxExpand.down  or 0)
--     end

--     -- Also clamp against claimed safehouses (may have appeared since scan)
--     local function clampVsSafehouses(dir, amount)
--         local sx, sy = safehouse:getX(), safehouse:getY()
--         local sw, sh = safehouse:getW(), safehouse:getH()
--         for try = amount, 0, -1 do
--             local nx, ny, nx2, ny2
--             if     dir == "left"  then nx=sx-try;  ny=sy;     nx2=sx+sw;       ny2=sy+sh
--             elseif dir == "right" then nx=sx;      ny=sy;     nx2=sx+sw+try;   ny2=sy+sh
--             elseif dir == "up"    then nx=sx;      ny=sy-try; nx2=sx+sw;       ny2=sy+sh
--             elseif dir == "down"  then nx=sx;      ny=sy;     nx2=sx+sw;       ny2=sy+sh+try
--             end
--             if not SafeHouse.getSafehouseOverlapping(nx, ny, nx2, ny2, safehouse) then
--                 return try
--             end
--         end
--         return 0
--     end

--     left  = clampVsSafehouses("left",  left)
--     right = clampVsSafehouses("right", right)
--     up    = clampVsSafehouses("up",    up)
--     down  = clampVsSafehouses("down",  down)

--     local totalApplied = left + right + up + down
--     if totalApplied == 0 then
--         return false, "Blocked in all directions by zones or safehouses", 0
--     end

--     local oldX, oldY = safehouse:getX(), safehouse:getY()
--     local oldW, oldH = safehouse:getW(), safehouse:getH()

--     local newSafe = recreateSafehouse(safehouse,
--         oldX - left, oldY - up,
--         oldW + left + right, oldH + up + down)
--     if not newSafe then
--         return false, "Engine rejected expansion; rolled back", 0
--     end

--     -- Update expansion history
--     local newTotal = totalExpanded + tilesPerDirection
--     if maxExpand then
--         maxExpand.left  = (maxExpand.left  or 0) - left
--         maxExpand.right = (maxExpand.right or 0) - right
--         maxExpand.up    = (maxExpand.up    or 0) - up
--         maxExpand.down  = (maxExpand.down  or 0) - down
--     end
--     saveExpansionHistory(username, originalBounds, newTotal, maxExpand)

--     local msg = string.format(
--         "%dx%d -> %dx%d (L=%d R=%d U=%d D=%d)",
--         oldW, oldH, oldW + left + right, oldH + up + down,
--         left, right, up, down)
--     return true, msg, totalApplied
-- end

-- -- =============================================================================
-- -- Safehouse tracking (JSON + unclaim detection)
-- -- =============================================================================

-- local previousOwners = {}  -- owner -> {x,y,w,h}

-- local function buildSafehouseEntry(sh)
--     local owner = sh:getOwner()
--     local members = {}
--     for i = 0, sh:getPlayers():size() - 1 do
--         members[#members+1] = sh:getPlayers():get(i)
--     end

--     local _, _, maxExpand = getExpansionHistory(owner)

--     return {
--         owner    = owner,
--         title    = sh:getTitle(),
--         x        = sh:getX(),
--         y        = sh:getY(),
--         w        = sh:getW(),
--         h        = sh:getH(),
--         members  = members,
--         maxExpand = maxExpand,
--     }
-- end

-- local function writeSafehousesJson()
--     local list = SafeHouse.getSafehouseList()
--     if not list then return end

--     local arr = {}
--     for i = 0, list:size() - 1 do
--         arr[#arr+1] = buildSafehouseEntry(list:get(i))
--     end

--     writeFileRaw(SAFEHOUSES_FILE, jsonEncode(arr) .. "\n")
-- end

-- local function detectUnclaims(currentOwners)
--     for owner, prevData in pairs(previousOwners) do
--         if not currentOwners[owner] then
--             log("Unclaim detected: " .. owner)
--             appendLine(UNCLAIMED_FILE,
--                 getTimestamp() .. "," .. owner .. ","
--                 .. prevData.x .. "," .. prevData.y .. ","
--                 .. prevData.w .. "," .. prevData.h)
--             clearExpansionHistory(owner)
--         end
--     end
-- end

-- local function updateSafehouseTracking()
--     local list = SafeHouse.getSafehouseList()
--     local currentOwners = {}
--     if list then
--         for i = 0, list:size() - 1 do
--             local sh = list:get(i)
--             currentOwners[sh:getOwner()] = {
--                 x = sh:getX(), y = sh:getY(),
--                 w = sh:getW(), h = sh:getH(),
--             }
--         end
--     end

--     detectUnclaims(currentOwners)
--     writeSafehousesJson()
--     previousOwners = currentOwners
-- end

-- -- =============================================================================
-- -- Client command handler:
-- -- Client sends "ApocalipseSafehouse" / "safehouseChanged" when
-- -- OnSafehousesChanged fires. We scan boundaries for that player.
-- -- =============================================================================

-- local function onClientCommand(module, command, player, args)
--     if module ~= MODULE_NAME then return end

--     if command == "safehouseChanged" then
--         local username = player:getUsername()
--         log("Received safehouseChanged from: " .. username)

--         local safehouse = SafeHouse.getSafehouseByOwner(username)
--         if safehouse then
--             log(string.format("Safehouse found for %s: (%d,%d) %dx%d",
--                 username, safehouse:getX(), safehouse:getY(),
--                 safehouse:getW(), safehouse:getH()))

--             -- Chunks are loaded because the player is RIGHT HERE
--             local limits = calculateExpansionLimits(safehouse)

--             -- Save limits into ModData
--             local totalExpanded, originalBounds, _ = getExpansionHistory(username)
--             if not originalBounds then
--                 originalBounds = {
--                     x = safehouse:getX(), y = safehouse:getY(),
--                     w = safehouse:getW(), h = safehouse:getH(),
--                 }
--             end
--             saveExpansionHistory(username, originalBounds, totalExpanded, limits)

--             log(string.format("Stored limits for %s: L=%d R=%d U=%d D=%d",
--                 username, limits.left, limits.right, limits.up, limits.down))
--         else
--             log("No safehouse owned by " .. username .. " (might be unclaim)")
--         end

--         -- Always update tracking when safehouses change
--         updateSafehouseTracking()
--     end
-- end

-- -- =============================================================================
-- -- Queue Processor (runs on EveryHours)
-- -- =============================================================================

-- local function processQueue()
--     local entries = readQueue()
--     if #entries > 0 then
--         log("Processing " .. #entries .. " queued expansion(s)...")
--         for _, entry in ipairs(entries) do
--             local success, message, applied = resizeSafehouse(entry.username, entry.tiles)
--             local status = success and "SUCCESS" or "FAILED"
--             logProcessed(entry.username, entry.tiles, applied or 0, status, message)
--             log(status .. ": " .. entry.username .. " (" .. entry.tiles .. " tiles) -> " .. message)
--         end
--         clearQueue()
--         log("Queue cleared")
--     end

--     updateSafehouseTracking()
-- end

-- -- =============================================================================
-- -- Initialization
-- -- =============================================================================

-- local function onServerStarted()
--     ensureFile(QUEUE_FILE, CSV_QUEUE_HEADER)
--     ensureFile(PROCESSED_FILE, CSV_PROCESSED_HEADER)
--     ensureFile(UNCLAIMED_FILE, CSV_UNCLAIMED_HEADER)

--     log("Initialized")
--     log("  Queue:      " .. QUEUE_FILE)
--     log("  Processed:  " .. PROCESSED_FILE)
--     log("  Safehouses: " .. SAFEHOUSES_FILE)
--     log("  Unclaimed:  " .. UNCLAIMED_FILE)
--     log("  MaxScan:    " .. CONFIG.MAX_SCAN_DISTANCE)
--     log("  MaxExpand:  " .. CONFIG.MAX_EXPANSION_PER_DIR)
--     log("  Buffer:     " .. CONFIG.SAFEHOUSE_BUFFER)

--     -- Initial snapshot
--     local list = SafeHouse.getSafehouseList()
--     local count = list and list:size() or 0
--     previousOwners = {}
--     if list then
--         for i = 0, list:size() - 1 do
--             local sh = list:get(i)
--             previousOwners[sh:getOwner()] = {
--                 x = sh:getX(), y = sh:getY(),
--                 w = sh:getW(), h = sh:getH(),
--             }
--         end
--     end
--     writeSafehousesJson()
--     log("Initial snapshot: " .. count .. " safehouse(s)")

--     -- Process anything queued while offline
--     local entries = readQueue()
--     if #entries > 0 then
--         log("Found " .. #entries .. " queued entry(ies)")
--         processQueue()
--     end
-- end

-- Events.OnServerStarted.Add(onServerStarted)
-- Events.EveryHours.Add(processQueue)
-- Events.OnClientCommand.Add(onClientCommand)

-- -- =============================================================================
-- -- Public API
-- -- =============================================================================
-- ApocalipseSafehouse = ApocalipseSafehouse or {}
-- ApocalipseSafehouse.resizeSafehouse = resizeSafehouse
-- ApocalipseSafehouse.processQueue = processQueue
-- ApocalipseSafehouse.updateTracking = updateSafehouseTracking
-- ApocalipseSafehouse.calculateLimits = calculateExpansionLimits
-- ApocalipseSafehouse.clearExpansionHistory = clearExpansionHistory
-- ApocalipseSafehouse.CONFIG = CONFIG