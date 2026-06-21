return function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv3()
	local symbolsAPI = mapAPI:getSymbolsAPIv2()
	local symbol
	symbol = symbolsAPI:addUntranslatedText("Grapeseed", "text-town", 6881, 11212)
	symbol:setRGBA(0.000, 0.000, 0.000, 0.000)
	symbol:setScale(3.500)
	symbol:setAnchor(0.50, 0.50)
	symbol:setRotation(0.0)
	symbol:setMatchPerspective(true)
	symbol:setApplyZoom(true)
	symbol:setMinZoom(0.00)
	symbol:setMaxZoom(13.00)
	symbol:setUserDefined(false)

end