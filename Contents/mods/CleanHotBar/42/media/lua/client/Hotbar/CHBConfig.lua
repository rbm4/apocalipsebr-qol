CHBConfig = {}
CHBConfig.VERSION = "1.0"
CHBConfig.configCache = nil

-- ----------------------------------------- --
-- serializeTable
-- ----------------------------------------- --
function CHBConfig.serializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep("    ", depth)

    if name then 
        tmp = tmp .. name .. " = "
    end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

        for k, v in pairs(val) do
            tmp = tmp .. CHBConfig.serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end

        tmp = tmp .. string.rep("    ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[" .. type(val) .. "]\""
    end

    return tmp
end

function CHBConfig.deserializeTable(content)
    local pos = 1

    local function skipWhitespace()
        while true do
            local char = string.sub(content, pos, pos)
            if char == "" or not string.match(char, "%s") then
                break
            end
            pos = pos + 1
        end
    end

    local function parseIdentifier()
        skipWhitespace()
        local word = string.match(string.sub(content, pos), "^[A-Za-z_][A-Za-z0-9_]*")
        if not word then return nil end
        pos = pos + #word
        return word
    end

    local parseValue

    local function parseString()
        skipWhitespace()
        if string.sub(content, pos, pos) ~= "\"" then return nil end
        pos = pos + 1

        local value = ""
        while pos <= #content do
            local char = string.sub(content, pos, pos)
            if char == "\"" then
                pos = pos + 1
                return value
            end
            if char == "\\" then
                local nextChar = string.sub(content, pos + 1, pos + 1)
                if nextChar == "n" then
                    value = value .. "\n"
                elseif nextChar == "r" then
                    value = value .. "\r"
                elseif nextChar == "t" then
                    value = value .. "\t"
                elseif nextChar ~= "" then
                    value = value .. nextChar
                end
                pos = pos + 2
            else
                value = value .. char
                pos = pos + 1
            end
        end

        return nil
    end

    local function parseTable()
        skipWhitespace()
        if string.sub(content, pos, pos) ~= "{" then return nil end
        pos = pos + 1

        local result = {}
        while true do
            skipWhitespace()
            local char = string.sub(content, pos, pos)
            if char == "}" then
                pos = pos + 1
                return result
            end
            if char == "" then return nil end

            local key = parseIdentifier()
            if not key then return nil end

            skipWhitespace()
            if string.sub(content, pos, pos) ~= "=" then return nil end
            pos = pos + 1

            result[key] = parseValue()
            if result[key] == nil then return nil end

            skipWhitespace()
            char = string.sub(content, pos, pos)
            if char == "," then
                pos = pos + 1
            elseif char ~= "}" then
                return nil
            end
        end
    end

    function parseValue()
        skipWhitespace()

        local char = string.sub(content, pos, pos)
        if char == "{" then
            return parseTable()
        end
        if char == "\"" then
            return parseString()
        end

        local word = parseIdentifier()
        if word == "true" then return true end
        if word == "false" then return false end
        if word ~= nil then return nil end

        local numberText = string.match(string.sub(content, pos), "^[%-]?%d+%.?%d*")
        if numberText then
            pos = pos + #numberText
            return tonumber(numberText)
        end

        return nil
    end

    skipWhitespace()
    local word = parseIdentifier()
    if word ~= "return" then
        return nil
    end

    return parseValue()
end

function CHBConfig.saveConfig(config)
    local file = getFileWriter("CleanHotbarConfig.lua", true, false)
    if file == nil then return nil end

    local contents = "return " .. CHBConfig.serializeTable(config)
    file:write(contents)
    file:close()

    CHBConfig.configCache = config
end

function CHBConfig.loadConfig()
    if CHBConfig.configCache then
        return CHBConfig.configCache
    end
    
    local file = getFileReader("CleanHotbarConfig.lua", true)
    if file == nil then return nil end

    local content = ""
    local line = file:readLine()
    while line do
        content = content .. line .. "\n"
        line = file:readLine()
    end
    file:close()
    
    if content == "" then return nil end
    
    local config = CHBConfig.deserializeTable(content)
    if type(config) == "table" then
        CHBConfig.configCache = config
        return config
    end

    print("CleanHotbar: Error loading config - invalid config format")
    return nil
end

-- ----------------------------------------- --
-- Config Manager
-- ----------------------------------------- --
function CHBConfig.getDefaultConfig()
    return {
        version = CHBConfig.VERSION,
        showItemDurability = { hotbar = true, equipitem = true },
        showWeaponHeadCondition = { hotbar = true, equipitem = true },
        showWeaponSharpness = { hotbar = true, equipitem = true },
        showWeaponAmmo = { hotbar = true, equipitem = true },
        showItemTooltip = { hotbar = false, equipitem = false },
        statusBarHeightScale = 1.0,
        ammoTextScale = 0.8,
        hotbarScale = 1.0,
        showWeaponDurabilityAlert = true,
        showEmptySlots = true,
    }
end

function CHBConfig.getConfig()
    local config = CHBConfig.loadConfig()
    
    if not config then
        config = CHBConfig.getDefaultConfig()
        CHBConfig.saveConfig(config)
        return config
    end

    local defaults = CHBConfig.getDefaultConfig()
    local needsSave = false

    for key, defaultValue in pairs(defaults) do
        if config[key] == nil then
            config[key] = defaultValue
            needsSave = true
        else
            local configType = type(config[key])
            local defaultType = type(defaultValue)
            
            if configType ~= defaultType then
                config[key] = defaultValue
                needsSave = true
            end
        end
    end
    
    if needsSave then
        CHBConfig.saveConfig(config)
    end
    
    return config
end

function CHBConfig.updateConfig(key, value, subKey)
    CHBConfig.configCache = nil
    
    local config = CHBConfig.loadConfig()
    
    if not config then
        config = CHBConfig.getDefaultConfig()
    end
    
    if subKey then
        if not config[key] then
            config[key] = {}
        end
        config[key][subKey] = value
    else
        config[key] = value
    end
    
    CHBConfig.saveConfig(config)
end

Events.OnGameBoot.Add(CHBConfig.getConfig)

return CHBConfig
