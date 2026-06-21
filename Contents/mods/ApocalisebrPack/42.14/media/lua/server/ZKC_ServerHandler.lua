-- Zombie Kill Counter - Server-Side Handler
-- Receives kill data from clients and writes to server file

require "ZombieKillCounter/ZKC_Config"

ZKC_ServerHandler = ZKC_ServerHandler or {}
ZKC_ServerHandler.pendingPayloads = ZKC_ServerHandler.pendingPayloads or {}

-- Logging helper
local function log(message)
    if ZKC_Config.Storage.debug then
        print("[ZKC_Server] " .. tostring(message))
    end
end

-- Flush all queued JSONL entries with one open/write/close cycle.
-- Entries stay queued when opening, writing, or closing the file fails.
function ZKC_ServerHandler.flushPendingPayloads()
    local pendingPayloads = ZKC_ServerHandler.pendingPayloads
    local payloadCount = #pendingPayloads
    if payloadCount == 0 then
        return true
    end

    local filename = ZKC_Config.Storage.filename
    local success, written, errorMessage = pcall(function()
        local writer = getFileWriter(filename, true, true)
        if not writer then
            return false, "Failed to open file for writing: " .. filename
        end

        for i = 1, payloadCount do
            writer:write(pendingPayloads[i])
            writer:write("\n")
        end
        writer:close()
        return true
    end)

    if not success then
        log("Error flushing " .. payloadCount .. " queued entries: " .. tostring(written))
        return false
    end
    if not written then
        log("ERROR: " .. tostring(errorMessage))
        return false
    end

    ZKC_ServerHandler.pendingPayloads = {}
    log("Flushed " .. payloadCount .. " queued entries to " .. filename)
    return true
end

-- Handle client command to store kill data
-- @param module string module name
-- @param command string command name
-- @param player IsoPlayer who sent the command
-- @param args table command arguments
local function OnClientCommand(module, command, player, args)
    -- Only handle our module's commands
    if module ~= "ZKC" then
        return
    end
    
    if command == "StoreKillData" then
        local jsonPayload = args.jsonPayload
        
        if not jsonPayload then
            log("ERROR: Received StoreKillData command without jsonPayload")
            return
        end
        
        log("Received kill data from player: " .. (player and player:getUsername() or "Unknown"))
        
        table.insert(ZKC_ServerHandler.pendingPayloads, jsonPayload)
    end
end

-- Client commands only queue data. The server performs a single disk append
-- for the whole batch at the next in-game minute.
Events.OnClientCommand.Add(OnClientCommand)
Events.EveryOneMinute.Add(ZKC_ServerHandler.flushPendingPayloads)

log("Server handler initialized and listening for client commands")

return ZKC_ServerHandler
