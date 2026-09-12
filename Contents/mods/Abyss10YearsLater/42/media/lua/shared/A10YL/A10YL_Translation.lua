-- Small shared translation helper for client prompts and administrator-facing
-- diagnostics. English fallbacks keep safety messages useful if a translation
-- file is missing or the translation API is unavailable during early startup.
local Translation = {}

local function lookup(key)
    if type(getText) ~= "function" then return nil end

    local ok, value = pcall(getText, key)
    if not ok or type(value) ~= "string" or value == "" or value == key then
        return nil
    end
    return value
end

function Translation.get(key, fallback)
    return lookup(key) or tostring(fallback or key or "")
end

function Translation.format(key, fallback, values)
    local message = Translation.get(key, fallback)
    if type(values) ~= "table" then return message end

    for name, value in pairs(values) do
        local token = "{" .. tostring(name) .. "}"
        message = message:gsub(token, function() return tostring(value) end)
    end
    return message
end

return Translation
