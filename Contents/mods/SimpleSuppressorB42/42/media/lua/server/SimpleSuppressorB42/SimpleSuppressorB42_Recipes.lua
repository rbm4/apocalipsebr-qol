require "recipecode"
require "SimpleSuppressorB42/SimpleSuppressorB42_Improvised"

RecipeCodeOnCreate = RecipeCodeOnCreate or {}

function RecipeCodeOnCreate.makeImprovisedSuppressor(craftRecipeData, character)
    local created_items = craftRecipeData and craftRecipeData:getAllCreatedItems() or nil
    if not created_items or created_items:isEmpty() then
        return
    end

    local item = created_items:get(0)
    local metalworking_level = 0

    if character then
        metalworking_level = character:getPerkLevel(Perks.MetalWelding)
    end

    SimpleSuppressorB42_Improvised.applyCraftQuality(item, character, metalworking_level)
end
