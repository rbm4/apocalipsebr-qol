--[[
    MM_FileHandler.lua
    File I/O and JSON parsing for the Vehicle Migration Module

    Reads a JSONL file (one JSON object per line) written by an external backend,
    parses each line into a Lua table, and provides a function to clear the file
    after processing.

    Uses getFileReader / getFileWriter (Project Zomboid file API).
]]

MigrationFileHandler = MigrationFileHandler or {}

-----------------------------------------------------------
-- Logging
-----------------------------------------------------------

--- Log a message with the module prefix
--- @param msg string
function MigrationFileHandler.log(msg)
    print("[MigrationModule] " .. tostring(msg))
end

-----------------------------------------------------------
-- JSON Parser (minimal recursive descent)
-----------------------------------------------------------

local parseValue -- forward declaration

--- Skip whitespace in the JSON string starting from position pos
--- @param str string
--- @param pos number
--- @return number newPos
local function skipWhitespace(str, pos)
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
            pos = pos + 1
        else
            break
        end
    end
    return pos
end

--- Parse a JSON string value starting from position pos (at opening quote)
--- @param str string
--- @param pos number
--- @return string value, number newPos
local function parseString(str, pos)
    pos = pos + 1 -- skip opening "
    local result = {}
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == '"' then
            return table.concat(result), pos + 1
        elseif c == '\\' then
            pos = pos + 1
            local escaped = str:sub(pos, pos)
            if escaped == '"' then
                table.insert(result, '"')
            elseif escaped == '\\' then
                table.insert(result, '\\')
            elseif escaped == '/' then
                table.insert(result, '/')
            elseif escaped == 'n' then
                table.insert(result, '\n')
            elseif escaped == 'r' then
                table.insert(result, '\r')
            elseif escaped == 't' then
                table.insert(result, '\t')
            elseif escaped == 'b' then
                table.insert(result, '\b')
            elseif escaped == 'f' then
                table.insert(result, '\f')
            elseif escaped == 'u' then
                local hex = str:sub(pos + 1, pos + 4)
                pos = pos + 4
                local codepoint = tonumber(hex, 16)
                if codepoint and codepoint < 128 then
                    table.insert(result, string.char(codepoint))
                else
                    table.insert(result, "?")
                end
            else
                table.insert(result, escaped)
            end
            pos = pos + 1
        else
            table.insert(result, c)
            pos = pos + 1
        end
    end
    return table.concat(result), pos
end

--- Parse a JSON number starting from position pos
--- @param str string
--- @param pos number
--- @return number value, number newPos
local function parseNumber(str, pos)
    local startPos = pos
    if str:sub(pos, pos) == '-' then
        pos = pos + 1
    end
    while pos <= #str and str:sub(pos, pos):match('[0-9]') do
        pos = pos + 1
    end
    if pos <= #str and str:sub(pos, pos) == '.' then
        pos = pos + 1
        while pos <= #str and str:sub(pos, pos):match('[0-9]') do
            pos = pos + 1
        end
    end
    if pos <= #str and (str:sub(pos, pos) == 'e' or str:sub(pos, pos) == 'E') then
        pos = pos + 1
        if pos <= #str and (str:sub(pos, pos) == '+' or str:sub(pos, pos) == '-') then
            pos = pos + 1
        end
        while pos <= #str and str:sub(pos, pos):match('[0-9]') do
            pos = pos + 1
        end
    end
    local numStr = str:sub(startPos, pos - 1)
    return tonumber(numStr), pos
end

--- Parse a JSON array starting from position pos (at '[')
--- @param str string
--- @param pos number
--- @return table value, number newPos
local function parseArray(str, pos)
    local arr = {}
    pos = pos + 1 -- skip '['
    pos = skipWhitespace(str, pos)

    if pos <= #str and str:sub(pos, pos) == ']' then
        return arr, pos + 1
    end

    while pos <= #str do
        local value
        value, pos = parseValue(str, pos)
        table.insert(arr, value)

        pos = skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == ']' then
            return arr, pos + 1
        elseif c == ',' then
            pos = pos + 1
            pos = skipWhitespace(str, pos)
        else
            break
        end
    end
    return arr, pos
end

--- Parse a JSON object starting from position pos (at '{')
--- @param str string
--- @param pos number
--- @return table value, number newPos
local function parseObject(str, pos)
    local obj = {}
    pos = pos + 1 -- skip '{'
    pos = skipWhitespace(str, pos)

    if pos <= #str and str:sub(pos, pos) == '}' then
        return obj, pos + 1
    end

    while pos <= #str do
        pos = skipWhitespace(str, pos)
        local key
        key, pos = parseString(str, pos)

        pos = skipWhitespace(str, pos)
        if str:sub(pos, pos) == ':' then
            pos = pos + 1
        end
        pos = skipWhitespace(str, pos)

        local value
        value, pos = parseValue(str, pos)
        obj[key] = value

        pos = skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == '}' then
            return obj, pos + 1
        elseif c == ',' then
            pos = pos + 1
            pos = skipWhitespace(str, pos)
        else
            break
        end
    end
    return obj, pos
end

--- Parse any JSON value starting from position pos
--- @param str string
--- @param pos number
--- @return any value, number newPos
parseValue = function(str, pos)
    pos = skipWhitespace(str, pos)
    if pos > #str then
        return nil, pos
    end

    local c = str:sub(pos, pos)

    if c == '"' then
        return parseString(str, pos)
    elseif c == '{' then
        return parseObject(str, pos)
    elseif c == '[' then
        return parseArray(str, pos)
    elseif c == 't' then
        pos = pos + 4
        return true, pos
    elseif c == 'f' then
        pos = pos + 5
        return false, pos
    elseif c == 'n' then
        pos = pos + 4
        return nil, pos
    elseif c == '-' or c:match('[0-9]') then
        return parseNumber(str, pos)
    end

    return nil, pos + 1
end

--- Parse a complete JSON string into a Lua table
--- @param jsonStr string
--- @return table|nil
local function parseJson(jsonStr)
    if not jsonStr or jsonStr == "" then
        return nil
    end
    local ok, result = pcall(function()
        local value, _ = parseValue(jsonStr, 1)
        return value
    end)
    if ok then
        return result
    else
        MigrationFileHandler.log("ERROR: Failed to parse JSON line: " .. tostring(result))
        return nil
    end
end

-----------------------------------------------------------
-- File I/O
-----------------------------------------------------------

--- Read all entries from a JSONL file (one JSON object per line)
--- Returns parallel arrays: parsed entries and their raw line strings.
--- Raw lines are preserved so retryable entries can be written back as-is.
--- @param filename string The filename to read (relative to PZ Lua save directory)
--- @return table entries Array of parsed Lua tables (one per valid line)
--- @return table rawLines Array of raw line strings (parallel to entries)
function MigrationFileHandler.readEntries(filename)
    local entries = {}
    local rawLines = {}

    local reader = getFileReader(filename, false)
    if not reader then
        -- File does not exist — normal, nothing to process
        return entries, rawLines
    end

    local lineNum = 0
    local line = reader:readLine()
    while line ~= nil do
        lineNum = lineNum + 1
        -- Trim whitespace
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            local entry = parseJson(trimmed)
            if entry and type(entry) == "table" then
                table.insert(entries, entry)
                table.insert(rawLines, trimmed)
            else
                MigrationFileHandler.log("WARNING: Skipping malformed line " .. lineNum .. " in " .. filename)
            end
        end
        line = reader:readLine()
    end
    reader:close()

    return entries, rawLines
end

--- Clear the contents of a file (overwrite with empty string)
--- The file is kept on disk but emptied so the backend can write to it again.
--- @param filename string The filename to clear
function MigrationFileHandler.clearFile(filename)
    local writer = getFileWriter(filename, true, false) -- createIfNull=true, append=false (overwrite)
    if writer then
        writer:write("")
        writer:close()
    end
end

--- Write raw JSONL lines back to a file (overwrite mode).
--- Used to preserve retryable entries that couldn't be processed yet.
--- @param filename string The filename to write
--- @param lines table Array of raw JSONL line strings
function MigrationFileHandler.writeLines(filename, lines)
    local writer = getFileWriter(filename, true, false) -- createIfNull=true, append=false (overwrite)
    if not writer then
        MigrationFileHandler.log("ERROR: Could not open file for writing: " .. filename)
        return
    end
    for _, line in ipairs(lines) do
        writer:writeln(line)
    end
    writer:close()
end

MigrationFileHandler.log("MM_FileHandler module loaded")
