local M = {}

M.getValue = function(player, key, default)
    local data = player:getModData()
    if not data.AdaptiveTraits then
        data.AdaptiveTraits = {}
    end
    if data.AdaptiveTraits[key] then
        return data.AdaptiveTraits[key]
    end
    return default
end

M.setValue = function(player, key, value)
    local data = player:getModData()
    if not data.AdaptiveTraits then
        data.AdaptiveTraits = {}
    end
    data.AdaptiveTraits[key] = value
end

return M
