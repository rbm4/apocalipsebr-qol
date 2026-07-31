local M = {}

M.getTraitById = function(traitId)
    local definitions = CharacterTraitDefinition.getTraits()
    for i = 0, definitions:size() - 1 do
        local definition = definitions:get(i)
        local trait = definition:getType()
        if trait:toString() == traitId then
            return trait
        end
    end
end

return M
