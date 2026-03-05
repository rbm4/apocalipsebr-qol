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

-- Serialize a Lua value to a JSON string
-- @param value any Lua value
-- @return string JSON formatted string
local function serializeValue(value)
    local vtype = type(value)
    if vtype == "string" then
        return '"' .. value:gsub('"', '\\"') .. '"'
    elseif vtype == "number" then
        -- Preserve decimals for floats, strip for integers
        if value == math.floor(value) then
            return string.format("%.0f", value)
        else
            return tostring(value)
        end
    elseif vtype == "boolean" then
        return value and "true" or "false"
    elseif vtype == "table" then
        local parts = {}
        for k, v in pairs(value) do
            table.insert(parts, '"' .. tostring(k) .. '":' .. serializeValue(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return '"' .. tostring(value) .. '"'
    end
end

-- Create JSON payload from kill data
-- @param killData table containing kill information
-- @return string JSON formatted string
function ZKC_API.createJsonPayload(killData)
    return serializeValue(killData)
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
