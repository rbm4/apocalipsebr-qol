local function UpdateEnginePartsRecipes()
	local settings = SandboxVars.SpareEnginePartsCrafting
	if not settings then return end

	local recipeSettings = {
		["MakeEnginePartsWeld"] = settings.EnginePartsOutputWeld or 20,
		["MakeEnginePartsMech"] = settings.EnginePartsOutputMech or 20,
		["MakeEnginePartsElec"] = settings.EnginePartsOutputElec or 20,
		["MakeEnginePartsSmit"] = settings.EnginePartsOutputSmit or 20
	}

	local sm = getScriptManager()

	for recipeName, countToSet in pairs(recipeSettings) do
		if countToSet ~= 20 then
			local recipe = sm:getCraftRecipe(recipeName)
		
			if recipe then
				local outputs = recipe:getOutputs()
				
				if outputs then
					outputs:clear()
				end

				local script = string.format("{ outputs { item %d Base.EngineParts, } }", countToSet)
				recipe:Load(recipeName, script)
			end
		end
	end
end

Events.OnInitGlobalModData.Add(UpdateEnginePartsRecipes)