local M = {}

M.getOption = function(name, default)
    local options = getSandboxOptions()
    local key = table.concat({ "AdaptiveTraits", name }, ".")
    local option = options:getOptionByName(key)
    return option and option:getValue() or default
end

return M
