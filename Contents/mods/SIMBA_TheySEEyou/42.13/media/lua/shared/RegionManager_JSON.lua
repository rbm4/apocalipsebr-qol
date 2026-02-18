-- ============================================================================
-- File: media/lua/shared/RegionManager_JSON.lua
-- JSON parsing and serialization utilities
-- ============================================================================

local JSON = {}

function JSON.parseString(str, pos)
    -- pos should be right after the opening quote
    local result = ""
    local i = pos
    while i <= #str do
        local c = str:sub(i, i)
        if c == '\\' then
            local next_c = str:sub(i + 1, i + 1)
            if next_c == '"' then result = result .. '"'
            elseif next_c == '\\' then result = result .. '\\'
            elseif next_c == '/' then result = result .. '/'
            elseif next_c == 'n' then result = result .. '\n'
            elseif next_c == 't' then result = result .. '\t'
            elseif next_c == 'r' then result = result .. '\r'
            else result = result .. next_c end
            i = i + 2
        elseif c == '"' then
            return result, i + 1
        else
            result = result .. c
            i = i + 1
        end
    end
    return result, i
end

function JSON.parseNumber(str, pos)
    local numStr = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
    if numStr then
        return tonumber(numStr), pos + #numStr
    end
    return nil, pos
end

function JSON.skipWhitespace(str, pos)
    return str:match("^%s*()", pos) or pos
end

function JSON.parseValue(str, pos)
    pos = JSON.skipWhitespace(str, pos)
    local c = str:sub(pos, pos)
    
    if c == '"' then
        return JSON.parseString(str, pos + 1)
    elseif c == '{' then
        return JSON.parseObject(str, pos)
    elseif c == '[' then
        return JSON.parseArray(str, pos)
    elseif str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    else
        return JSON.parseNumber(str, pos)
    end
end

function JSON.parseArray(str, pos)
    local arr = {}
    pos = pos + 1 -- skip '['
    pos = JSON.skipWhitespace(str, pos)
    if str:sub(pos, pos) == ']' then return arr, pos + 1 end
    
    while pos <= #str do
        local val
        val, pos = JSON.parseValue(str, pos)
        table.insert(arr, val)
        pos = JSON.skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == ']' then return arr, pos + 1 end
        if c == ',' then pos = pos + 1 end
    end
    return arr, pos
end

function JSON.parseObject(str, pos)
    local obj = {}
    pos = pos + 1 -- skip '{'
    pos = JSON.skipWhitespace(str, pos)
    if str:sub(pos, pos) == '}' then return obj, pos + 1 end
    
    while pos <= #str do
        pos = JSON.skipWhitespace(str, pos)
        if str:sub(pos, pos) ~= '"' then break end
        local key
        key, pos = JSON.parseString(str, pos + 1)
        pos = JSON.skipWhitespace(str, pos)
        pos = pos + 1 -- skip ':'
        local val
        val, pos = JSON.parseValue(str, pos)
        obj[key] = val
        pos = JSON.skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == '}' then return obj, pos + 1 end
        if c == ',' then pos = pos + 1 end
    end
    return obj, pos
end

function JSON.parse(str)
    local val, _ = JSON.parseValue(str, 1)
    return val
end

-- Encode a Lua value to JSON string
function JSON.encode(val, indent, currentIndent)
    indent = indent or "  "
    currentIndent = currentIndent or ""
    local nextIndent = currentIndent .. indent
    
    if val == nil then
        return "null"
    elseif type(val) == "boolean" then
        return tostring(val)
    elseif type(val) == "number" then
        -- Use integer format when there are no decimals
        if val == math.floor(val) then
            return string.format("%d", val)
        end
        return tostring(val)
    elseif type(val) == "string" then
        local escaped = val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    elseif type(val) == "table" then
        -- Detect array vs object: array if sequential integer keys starting at 1
        local isArray = true
        local maxN = 0
        for k, _ in pairs(val) do
            if type(k) == "number" and k == math.floor(k) and k > 0 then
                if k > maxN then maxN = k end
            else
                isArray = false
                break
            end
        end
        if maxN ~= #val then isArray = false end
        if maxN == 0 then
            -- Empty table: check if it was meant to be an array or object
            -- Default to object {}
            local hasKeys = false
            for _ in pairs(val) do hasKeys = true; break end
            if not hasKeys then return "{}" end
        end
        
        if isArray then
            local parts = {}
            for i = 1, #val do
                table.insert(parts, nextIndent .. JSON.encode(val[i], indent, nextIndent))
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. currentIndent .. "]"
        else
            -- Sort keys for consistent output
            local keys = {}
            for k, _ in pairs(val) do table.insert(keys, k) end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            local parts = {}
            for _, k in ipairs(keys) do
                local encodedKey = JSON.encode(tostring(k), indent, nextIndent)
                local encodedVal = JSON.encode(val[k], indent, nextIndent)
                table.insert(parts, nextIndent .. encodedKey .. ": " .. encodedVal)
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. currentIndent .. "}"
        end
    end
    return "null"
end

return JSON
