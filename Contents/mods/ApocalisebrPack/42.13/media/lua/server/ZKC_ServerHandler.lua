-- Zombie Kill Counter - Server-Side Handler
-- Receives kill data from clients and writes to server file

require "ZombieKillCounter/ZKC_Config"

ZKC_ServerHandler = ZKC_ServerHandler or {}

-- Logging helper
local function log(message)
    if ZKC_Config.Storage.debug then
        print("[ZKC_Server] " .. tostring(message))
    end
end

-- Write kill data to server file
-- @param jsonPayload string JSON data to write
local function writeToFile(jsonPayload)
    local success, error = pcall(function()
        local filename = ZKC_Config.Storage.filename
        log("Writing kill data to server file: " .. filename)
        
        -- Open file in append mode
        local writer = getFileWriter(filename, true, true)
        if not writer then
            log("ERROR: Failed to open file for writing: " .. filename)
            return false
        end
        
        -- Write JSON line (newline-delimited JSON format)
        writer:write(jsonPayload .. "\n")
        writer:close()
        
        log("Kill data written successfully to server!")
        return true
    end)
    
    if not success then
        log("Error writing kill data to server: " .. tostring(error))
        return false
    end
    
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
        
        -- Write to server file
        writeToFile(jsonPayload)
    end
end

-- Register the command handler
Events.OnClientCommand.Add(OnClientCommand)

log("Server handler initialized and listening for client commands")

return ZKC_ServerHandler
