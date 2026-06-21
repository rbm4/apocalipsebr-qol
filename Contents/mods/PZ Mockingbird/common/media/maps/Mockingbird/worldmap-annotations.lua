return function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv3()
	local symbolsAPI = mapAPI:getSymbolsAPIv2()
	local symbol
	symbol = symbolsAPI:addUntranslatedText("Mockingbird", "text-town", 10329, 13044)
	symbol:setRGBA(0.000, 0.000, 0.000, 0.000)
	symbol:setScale(3.000)
	symbol:setAnchor(0.50, 0.50)
	symbol:setRotation(0.0)
	symbol:setMatchPerspective(true)
	symbol:setApplyZoom(true)
	symbol:setMinZoom(0.00)
	symbol:setMaxZoom(13.00)
	symbol:setUserDefined(false)

end