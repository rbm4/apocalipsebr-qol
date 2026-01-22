-- Zombie Kill Counter - Data Storage Module
-- Handles writing kill data to file for external API consumption

require "ZombieKillCounter/ZKC_Config"

ZKC_API = ZKC_API or {}

-- Logging helper
local function log(message)
    if ZKC_Config.Storage.debug then
        print("[ZKC_API] " .. tostring(message))
    end
end

-- Send kill data to file (append mode)
-- @param killData table containing kill information
-- @return boolean success
function ZKC_API.sendKillData(killData)
    if not ZKC_Config.enabled then
        return false
    end
    
    -- Write directly to file
    return ZKC_API.writeKillDataToFile(killData)
end

-- Send kill data to server (via client command)
-- @param killData table containing kill information
function ZKC_API.writeKillDataToFile(killData)
    local success, error = pcall(function()
        log("Sending kill data to server...")
        
        -- Create JSON payload
        local jsonPayload = ZKC_API.createJsonPayload(killData)
        log("Payload: " .. jsonPayload)
        
        -- Send command to server to write the data
        sendClientCommand("ZKC", "StoreKillData", {
            jsonPayload = jsonPayload
        })
        
        log("Kill data sent to server successfully!")
        return true
    end)
    
    if not success then
        log("Error sending kill data to server: " .. tostring(error))
        return false
    end
    
    return true
end

-- Create JSON payload from kill data
-- @param killData table containing kill information
-- @return string JSON formatted string
function ZKC_API.createJsonPayload(killData)
    -- Simple JSON serialization (you might want to use a proper JSON library for complex data)
    local parts = {}
    
    for key, value in pairs(killData) do
        local valueStr
        if type(value) == "string" then
            valueStr = '"' .. value:gsub('"', '\\"') .. '"'
        elseif type(value) == "number" then
            valueStr = string.format("%.0f", value)
        elseif type(value) == "boolean" then
            valueStr = value and "true" or "false"
        else
            valueStr = '"' .. tostring(value) .. '"'
        end
        table.insert(parts, '"' .. key .. '":' .. valueStr)
    end
    
    return "{" .. table.concat(parts, ",") .. "}"
end

-- Test sending data to server
function ZKC_API.testConnection()
    log("Testing server communication...")
    
    local testData = {
        playerName = "TestPlayer",
        kills = 1,
        timestamp = os.time(),
        test = true
    }
    
    ZKC_API.sendKillData(testData)
end

return ZKC_API
