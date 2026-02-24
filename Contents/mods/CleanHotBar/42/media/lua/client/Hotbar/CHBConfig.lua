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
    
    local fn, errorMsg = loadstring(content)
    if fn then
        local config = fn()
        CHBConfig.configCache = config
        return config
    else
        print("CleanHotbar: Error loading config - " .. tostring(errorMsg))
        return nil
    end
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