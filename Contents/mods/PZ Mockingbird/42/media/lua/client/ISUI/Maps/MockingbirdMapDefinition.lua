require "ISUI/Maps/ISMapDefinitions"

MapUtils = MapUtils or {}

function MapUtils.initDirectoryMapData(mapUI, directory)
	local mapAPI = mapUI.javaObject:getAPIv1()
	local file = directory..'/worldmap-forest.xml'
	if fileExists(file) then
		mapAPI:addData(file)
	end
	file = directory..'/worldmap.xml'
	if fileExists(file) then
		mapAPI:addData(file)
	end

	-- This call indicates the end of XML data files for the directory.
	-- If map features exist for a particular cell in this directory,
	-- then no data added afterwards will be used for that same cell.
	mapAPI:endDirectoryData()

	mapAPI:addImages(directory)
end

function MapUtils.initDefaultMapData(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	mapAPI:clearData()
	-- Add data from highest priority (mods) to lowest priority (vanilla)
	local dirs = getLotDirectories()
	for i=1,dirs:size() do
		MapUtils.initDirectoryMapData(mapUI, 'media/maps/'..dirs:get(i-1))
	end
end

function MapUtils.initDirectoryStreetData(mapUI, directory)
	local mapAPI = mapUI.javaObject:getAPIv3()
	local streetsAPI = mapAPI:getStreetsAPI()
	local file = directory..'/streets.xml'
	if fileExists(file) then
		streetsAPI:addStreetData(file)
	end
end

function MapUtils.initDefaultStreetData(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv3()
	local streetsAPI = mapAPI:getStreetsAPI()
	streetsAPI:clearStreetData()
	-- Add data from highest priority (mods) to lowest priority (vanilla)
	local dirs = getLotDirectories()
	for i=1,dirs:size() do
		MapUtils.initDirectoryStreetData(mapUI, 'media/maps/'..dirs:get(i-1))
	end
end

function MapUtils.initDirectoryAnnotations(mapUI, directory)
	local file = directory..'/worldmap-annotations.lua'
	if fileExists(file) then
		local annotationFunction = reloadLuaFile(file)
		if type(annotationFunction) == "function" then
            annotationFunction(mapUI)
        end
	end
end

function MapUtils.initDefaultAnnotations(mapUI)
	-- Add data from highest priority (mods) to lowest priority (vanilla)
	local dirs = getLotDirectories()
	for i=1,dirs:size() do
		MapUtils.initDirectoryAnnotations(mapUI, 'media/maps/'..dirs:get(i-1))
	end
end

function MapUtils.initDefaultTextLayersV3(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv3()
	local styleAPI = mapAPI:getStyleAPI()

    local layer = styleAPI:newTextLayer("text-note")
    layer:setFont(UIFont.Handwritten)
    layer:setLineHeight(40)
    layer:addFill(0.0, 0.0, 0.0, 0.0, 255.0)

    layer = styleAPI:newTextLayer("text-street")
    layer:setFont(UIFont.SdfBold)
    layer:setLineHeight(48)
    layer:addFill(13.0, 255.0, 255.0, 255.0, 0.0)
    layer:addFill(13.5, 255.0, 255.0, 255.0, 255.0)

    layer = styleAPI:newTextLayer("text-building")
    layer:setFont(UIFont.SdfBoldItalic)
    layer:setLineHeight(48)
    layer:addFill(13.0, 255.0, 255.0, 255.0, 0.0)
    layer:addFill(13.5, 255.0, 255.0, 255.0, 255.0)
    layer:addFill(16.5, 255.0, 255.0, 255.0, 255.0)
    layer:addFill(17.0, 255.0, 255.0, 255.0, 0.0)

    layer = styleAPI:newTextLayer("text-place")
    layer:setFont(UIFont.SdfBoldItalic)
    layer:setLineHeight(48)
    layer:addFill(13.0, 255.0, 255.0, 255.0, 0.0)
    layer:addFill(13.5, 255.0, 255.0, 255.0, 255.0)
    layer:addFill(16.5, 255.0, 255.0, 255.0, 255.0)
    layer:addFill(17.0, 255.0, 255.0, 255.0, 0.0)

    layer = styleAPI:newTextLayer("text-town")
    layer:setFont(UIFont.SdfBold)
    layer:setLineHeight(48)
    layer:addFill(0.0, 0.0, 0.0, 0.0, 255.0)
    layer:addFill(13.0, 0.0, 0.0, 0.0, 255.0)
    layer:addFill(13.5, 0.0, 0.0, 0.0, 0.0)

    layer = styleAPI:newTextLayer("text-forest")
    layer:setFont(UIFont.SdfBold)
    layer:setLineHeight(32)
    layer:addFill(0.0, 15.0, 99.0, 43.0, 255.0)
    layer:addFill(13.0, 15.0, 99.0, 43.0, 255.0)
    layer:addFill(13.5, 15.0, 99.0, 43.0, 0.0)

    layer = styleAPI:newTextLayer("text-water-small")
    layer:setFont(UIFont.SdfBold)
    layer:setLineHeight(32)
    layer:addFill(0.0, 4.0, 48.0, 125.0, 255.0)
    layer:addFill(16.0, 4.0, 48.0, 125.0, 255.0)
    layer:addFill(16.5, 4.0, 48.0, 125.0, 0.0)

    layer = styleAPI:newTextLayer("text-water-medium")
    layer:setFont(UIFont.SdfBold)
    layer:setLineHeight(32)
    layer:addFill(0.0, 4.0, 48.0, 125.0, 255.0)
    layer:addFill(14.5, 4.0, 48.0, 125.0, 255.0)
    layer:addFill(15.0, 4.0, 48.0, 125.0, 0.0)

    layer = styleAPI:newTextLayer("text-water-nofade")
    layer:setFont(UIFont.SdfBold)
    layer:setLineHeight(32)
    layer:addFill(0.0, 4.0, 48.0, 125.0, 255.0)

    -- CH / CN / JP / KO / PL / RU / TH languages don't use the SDF fonts that EN does.
    if getTextManager():isUsingNonEnglishFonts() then
        styleAPI:getLayerByName("text-street"):setFont(UIFont.Medium)
        styleAPI:getLayerByName("text-building"):setFont(UIFont.Medium)
        styleAPI:getLayerByName("text-place"):setFont(UIFont.Medium)
        styleAPI:getLayerByName("text-town"):setFont(UIFont.Medium)
        styleAPI:getLayerByName("text-forest"):setFont(UIFont.Medium)
        styleAPI:getLayerByName("text-water-small"):setFont(UIFont.Medium)
        styleAPI:getLayerByName("text-water-medium"):setFont(UIFont.Medium)
        styleAPI:getLayerByName("text-water-nofade"):setFont(UIFont.Medium)
    end
end

local MINZ = 0
local MAXZ = 24
local MINZ_BUILDINGS = 13

local WATER_TEXTURE = false

function MapUtils.initDefaultStyleV1(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	local styleAPI = mapAPI:getStyleAPI()

	local ColorblindPatterns = getCore():getOptionColorblindPatterns()
	mapAPI:setBoolean("ColorblindPatterns", ColorblindPatterns)

    -- The default changed from false to true when street names were added.
	mapAPI:setBoolean("ImagePyramid", false)

	local r,g,b = 219/255, 215/255, 192/255
	mapAPI:setBackgroundRGBA(r, g, b, 1.0)
	mapAPI:setUnvisitedRGBA(r * 0.915, g * 0.915, b * 0.915, 1.0)
	mapAPI:setUnvisitedGridRGBA(r * 0.777, g * 0.777, b * 0.777, 1.0)

	styleAPI:clear()

	local layer = styleAPI:newPolygonLayer("forest")
	layer:setMinZoom(13.5)
	layer:setFilter("natural", "forest")
	if true then
		layer:addFill(MINZ, 189, 197, 163, 0)
		layer:addFill(14.5, 189, 197, 163, 0)
		layer:addFill(15, 189, 197, 163, 255)
		layer:addFill(MAXZ, 189, 197, 163, 255)
	else
		layer:addFill(MINZ, 255, 255, 255, 255)
		layer:addFill(MAXZ, 255, 255, 255, 255)
		layer:addTexture(MINZ, "media/textures/worldMap/Grass.png")
		layer:addTexture(MAXZ, "media/textures/worldMap/Grass.png")
		layer:addScale(13.5, 4.0)
		layer:addScale(MAXZ, 4.0)
	end
	
	layer = styleAPI:newPolygonLayer("water")
	layer:setMinZoom(MINZ)
	layer:setFilter("water", "river")
	if not WATER_TEXTURE then
		layer:addFill(MINZ, 59, 141, 149, 255)
		layer:addFill(MAXZ, 59, 141, 149, 255)
	else
		layer:addFill(MINZ, 59, 141, 149, 255)
		layer:addFill(14.5, 59, 141, 149, 255)
		layer:addFill(14.5, 255, 255, 255, 255)
		layer:addTexture(MINZ, nil)
		layer:addTexture(14.5, nil)
		layer:addTexture(14.5, "media/textures/worldMap/Water.png")
		layer:addTexture(MAXZ, "media/textures/worldMap/Water.png")
--		layer:addScale(MINZ, 4.0)
--		layer:addScale(MAX, 4.0)
	end

	layer = styleAPI:newPolygonLayer("road-trail")
	layer:setMinZoom(12.0)
	layer:setFilter("highway", "trail")
	layer:addFill(12.25, 185, 122, 87, 0)
	layer:addFill(13, 185, 122, 87, 255)
	layer:addFill(MAXZ, 185, 122, 87, 255)

	layer = styleAPI:newPolygonLayer("road-tertiary")
	layer:setMinZoom(11.0)
	layer:setFilter("highway", "tertiary")
	layer:addFill(11.5, 171, 158, 143, 0)
	layer:addFill(13, 171, 158, 143, 255)
	layer:addFill(MAXZ, 171, 158, 143, 255)

	layer = styleAPI:newPolygonLayer("road-secondary")
	layer:setMinZoom(11.0)
	layer:setFilter("highway", "secondary")
	layer:addFill(MINZ, 134, 125, 113, 255)
	layer:addFill(MAXZ, 134, 125, 113, 255)

	layer = styleAPI:newPolygonLayer("road-primary")
	layer:setMinZoom(11.0)
	layer:setFilter("highway", "primary")
	layer:addFill(MINZ, 134, 125, 113, 255)
	layer:addFill(MAXZ, 134, 125, 113, 255)

	layer = styleAPI:newPolygonLayer("railway")
	layer:setMinZoom(14.0)
	layer:setFilter("railway", "*")
	layer:addFill(MINZ, 200, 191, 231, 255)
	layer:addFill(MAXZ, 200, 191, 231, 255)

	-- Default, same as building-Residential
	layer = styleAPI:newPolygonLayer("building")
	layer:setMinZoom(MINZ_BUILDINGS)
	layer:setFilter("building", "yes")
	if ColorblindPatterns then
		layer:addTexture(MINZ, "media/textures/worldMap/Colorblind Patterns/Pattern_Residential.png", "ScreenPixel")
		layer:addScale(MINZ, 4)
	end
	layer:addFill(MINZ_BUILDINGS, 210, 158, 105, 0)
	layer:addFill(MINZ_BUILDINGS + 0.5, 210, 158, 105, 255)
	layer:addFill(MAXZ, 210, 158, 105, 255)

	layer = styleAPI:newPolygonLayer("building-Residential")
	layer:setMinZoom(MINZ_BUILDINGS)
	layer:setFilter("building", "Residential")
	if ColorblindPatterns then
		layer:addTexture(MINZ, "media/textures/worldMap/Colorblind Patterns/Pattern_Residential.png", "ScreenPixel")
		layer:addScale(MINZ, 4)
	end
	layer:addFill(MINZ_BUILDINGS, 210, 158, 105, 0)
	layer:addFill(MINZ_BUILDINGS + 0.5, 210, 158, 105, 255)
	layer:addFill(MAXZ, 210, 158, 105, 255)

	layer = styleAPI:newPolygonLayer("building-CommunityServices")
	layer:setMinZoom(MINZ_BUILDINGS)
	layer:setFilter("building", "CommunityServices")
	if ColorblindPatterns then
		layer:addTexture(MINZ, "media/textures/worldMap/Colorblind Patterns/Pattern_Community.png", "ScreenPixel")
		layer:addScale(MINZ, 4)
	end
	layer:addFill(MINZ_BUILDINGS, 139, 117, 235, 0)
	layer:addFill(MINZ_BUILDINGS + 0.5, 139, 117, 235, 255)
	layer:addFill(MAXZ, 139, 117, 235, 255)

	layer = styleAPI:newPolygonLayer("building-Hospitality")
	layer:setMinZoom(MINZ_BUILDINGS)
	layer:setFilter("building", "Hospitality")
	if ColorblindPatterns then
		layer:addTexture(MINZ, "media/textures/worldMap/Colorblind Patterns/Pattern_Hospitality.png", "ScreenPixel")
		layer:addScale(MINZ, 4)
	end
	layer:addFill(MINZ_BUILDINGS, 127, 206, 225, 0)
	layer:addFill(MINZ_BUILDINGS + 0.5, 127, 206, 225, 255)
	layer:addFill(MAXZ, 127, 206, 225, 255)

	layer = styleAPI:newPolygonLayer("building-Industrial")
	layer:setMinZoom(MINZ_BUILDINGS)
	layer:setFilter("building", "Industrial")
	if ColorblindPatterns then
		layer:addTexture(MINZ, "media/textures/worldMap/Colorblind Patterns/Pattern_Industrial.png", "ScreenPixel")
		layer:addScale(MINZ, 4)
	end
	layer:addFill(MINZ_BUILDINGS, 56, 54, 53, 0)
	layer:addFill(MINZ_BUILDINGS + 0.5, 56, 54, 53, 255)
	layer:addFill(MAXZ, 56, 54, 53, 255)

	layer = styleAPI:newPolygonLayer("building-Medical")
	layer:setMinZoom(MINZ_BUILDINGS)
	layer:setFilter("building", "Medical")
	if ColorblindPatterns then
		layer:addTexture(MINZ, "media/textures/worldMap/Colorblind Patterns/Pattern_Medical.png", "ScreenPixel")
		layer:addScale(MINZ, 4)
	end
	layer:addFill(MINZ_BUILDINGS, 229, 128, 151, 0)
	layer:addFill(MINZ_BUILDINGS + 0.5, 229, 128, 151, 255)
	layer:addFill(MAXZ, 229, 128, 151, 255)

	layer = styleAPI:newPolygonLayer("building-RestaurantsAndEntertainment")
	layer:setMinZoom(MINZ_BUILDINGS)
	layer:setFilter("building", "RestaurantsAndEntertainment")
	if ColorblindPatterns then
		layer:addTexture(MINZ, "media/textures/worldMap/Colorblind Patterns/Pattern_RestaurantsEntertainment.png", "ScreenPixel")
		layer:addScale(MINZ, 4)
	end
	layer:addFill(MINZ_BUILDINGS, 245, 225, 60, 0)
	layer:addFill(MINZ_BUILDINGS + 0.5, 245, 225, 60, 255)
	layer:addFill(MAXZ, 245, 225, 60, 255)

	layer = styleAPI:newPolygonLayer("building-RetailAndCommercial")
	layer:setMinZoom(MINZ_BUILDINGS)
	layer:setFilter("building", "RetailAndCommercial")
	if ColorblindPatterns then
		layer:addTexture(MINZ, "media/textures/worldMap/Colorblind Patterns/Pattern_RetailCommercial.png", "ScreenPixel")
		layer:addScale(MINZ, 4)
	end
	layer:addFill(MINZ_BUILDINGS, 184, 205, 84, 0)
	layer:addFill(MINZ_BUILDINGS + 0.5, 184, 205, 84, 255)
	layer:addFill(MAXZ, 184, 205, 84, 255)
end

function MapUtils.initDefaultStyleV3(mapUI)
    MapUtils.initDefaultStyleV1(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv3()
	local styleAPI = mapAPI:getStyleAPI()

	mapAPI:setBoolean("ImagePyramid", true)

	local ignoreForestFeatures = false
	if ignoreForestFeatures then
    	styleAPI:removeLayerById("forest")
    end

    local pyramidLayer = mapAPI:getStyleAPI():newPyramidLayer("pyramid-forest")
    pyramidLayer:setPyramidFileName("forest.pyramid.zip")
    pyramidLayer:addFill(0.0, 189, 197, 163, 255.0)
    if not ignoreForestFeatures then
        pyramidLayer:addFill(14.999, 189, 197, 163, 255.0)
        pyramidLayer:addFill(15.0, 0.0, 0.0, 0.0, 0.0)
    end

    local index1 = styleAPI:indexOfLayer("pyramid-forest")
    local index2 = styleAPI:indexOfLayer("forest")
    styleAPI:moveLayer(index1, index2 + 1)

    MapUtils.initDefaultTextLayersV3(mapUI)
end

function MapUtils.overlayPaper(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	local styleAPI = mapAPI:getStyleAPI()
	local layer = styleAPI:newTextureLayer("paper")
	layer:setMinZoom(0.00)
	local x1 = mapAPI:getMinXInSquares()
	local y1 = mapAPI:getMinYInSquares()
	local x2 = mapAPI:getMaxXInSquares() + 1
	local y2 = mapAPI:getMaxYInSquares() + 1
	layer:setBoundsInSquares(x1, y1, x2, y2)
	layer:setTile(true)
	layer:setUseWorldBounds(true)
	if false then
        layer:addFill(0.00, 255, 255, 255, 32)
        layer:addTexture(0.00, "media/textures/worldMap/Paper.png")
    else
        layer:addFill(14.00, 128, 128, 128, 0)
        layer:addFill(15.00, 128, 128, 128, 32)
        layer:addFill(15.00, 255, 255, 255, 32)
        layer:addTexture(0.00, "media/white.png")
        layer:addTexture(15.00, "media/white.png")
        layer:addTexture(15.00, "media/textures/worldMap/Paper.png")
    end
end

function MapUtils.revealKnownArea(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	local x1 = mapAPI:getMinXInSquares()
	local y1 = mapAPI:getMinYInSquares()
	local x2 = mapAPI:getMaxXInSquares()
	local y2 = mapAPI:getMaxYInSquares()
	WorldMapVisited.getInstance():setKnownInSquares(x1, y1, x2, y2)
end

function MapUtils.renderDarkModeOverlay(mapUI)
	local alpha = getCore():getOptionWorldMapBrightness()
	alpha = 1 - PZMath.lerp(0.2, 1.0, alpha)
	mapUI:drawTextureScaled(Texture.getWhite(), 0, 0, mapUI.width, mapUI.height, alpha, 0.0, 0.0, 0.0)
end

-----

local function replaceWaterStyle(mapUI)
	if not WATER_TEXTURE then return end
	local mapAPI = mapUI.javaObject:getAPIv1()
	local styleAPI = mapAPI:getStyleAPI()
	local layer = styleAPI:getLayerByName("water")
	if not layer then return end
	layer:setMinZoom(MINZ)
	layer:setFilter("water", "river")
	layer:removeAllFill()
	layer:removeAllTexture()
	layer:addFill(MINZ, 59, 141, 149, 255)
	layer:addFill(MAXZ, 59, 141, 149, 255)
end

local function overlayPNG(mapUI, x, y, scale, layerName, tex, alpha)
	local texture = getTexture(tex)
	if not texture then return end
	local mapAPI = mapUI.javaObject:getAPIv1()
	local styleAPI = mapAPI:getStyleAPI()
	local layer = styleAPI:newTextureLayer(layerName)
	layer:setMinZoom(MINZ)
	layer:addFill(MINZ, 255, 255, 255, (alpha or 1.0) * 255)
	layer:addTexture(MINZ, tex)
	layer:setBoundsInSquares(x, y, x + texture:getWidth() * scale, y + texture:getHeight() * scale)
end

local function overlayPNG2(mapUI, x, y, scaleX, scaleY, tex)
	local mapAPI = mapUI.javaObject:getAPIv1()
	local styleAPI = mapAPI:getStyleAPI()
	local layer = styleAPI:newTextureLayer("lootMapPNG")
	layer:setMinZoom(MINZ)
	local texture = getTexture(tex)
	layer:addFill(MINZ, 255, 255, 255, 128)
	layer:addTexture(MINZ, tex)
	layer:setBoundsInSquares(x, y, x + texture:getWidth() * scaleX, y + texture:getHeight() * scaleY)
end

local function worldMapImage(fileName)
	if getCore():getOptionColorblindPatterns() then
		return "media/textures/worldMap/Colorblind Patterns/" .. fileName
	end
	return "media/textures/worldMap/" .. fileName
end

-- -- -- -- --

LootMaps = LootMaps or {}
LootMaps.Init = LootMaps.Init or {}

function LootMaps.callLua(functionName, mapUI, arg1, arg2, arg3, arg4)
	local t = LootMaps[functionName]
	if not t then
		print("LootMaps.callLua(): no hay funciones en LootMaps." .. functionName)
		return
	end
	local mapItem = mapUI.mapItem or mapUI.mapObj
	local f = t[mapItem:getStashMap()] or t[mapItem:getMapID()]
	if not f then
		print("LootMaps.callLua(): no hay funciones en LootMaps." .. functionName .. "." .. mapItem:getMapID())
		return
	end
	return f(mapUI, arg1, arg2, arg3, arg4)
end

-- Init functions for each MapItem.getMapID().

LootMaps.DEFAULT_MAP_DIRECTORY = 'media/maps/Muldraugh, KY'

LootMaps.Init.MockingbirdMap = function(mapUI)
    local mapAPI = mapUI.javaObject:getAPIv1()
    MapUtils.initDirectoryMapData(mapUI, 'media/maps/Mockingbird')
    -- 'media/maps/Mockingbird' - ruta donde se encuentra el archivo worldmap.xml del mapa

	MapUtils.initDefaultStyleV3(mapUI)
    -- especifica la apariencia del mapa.

    replaceWaterStyle(mapUI)
    -- reemplaza la textura del agua por un color solido. 

    mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
    -- (eje x inicial, eje y inicial, eje x final, eje y final) el área que abarca y a descubrir, en coordenadas del mundo.

    overlayPNG(mapUI, 10200, 12900, 0.2, "badge", "media/textures/worldMap/MockingbirdBadge.png")
    --[[ agrega tu encabezado del mapa lootable PNG. (en coordenadas del mundo, eje x inicial, eje y inicial, y múltiplo de las dimensiones)
	dimensiones del dibujo 1500x150 x 0.2 = dimensiones finales 300x30 (big square in world = 300x300) ]]
    overlayPNG(mapUI, 10209, 13100, 0.2, "legend", "media/textures/worldMap/Legend.png")
    --[[ agreaga el dibujo de las leyendas PNG. (en coordenadas del mundo, eje x inicial, eje y inicial, y múltiplo de las dimensiones)
	dimensiones del dibujo 565x468 x 0.1 = dimensiones finales 56.5  x 46.8
	dimensiones del dibujo 565x468 x 0.2 = dimensiones finales 113   x 93.6
	dimensiones del dibujo 565x468 x 0.3 = dimensiones finales 169.5 x 140.4
	dimensiones del dibujo 565x468 x 0.4 = dimensiones finales 226   x 187.2
	dimensiones del dibujo 565x468 x 0.5 = dimensiones finales 282.5 x 234
	dimensiones del dibujo 565x468 x 0.6 = dimensiones finales 339   x 280.8
	dimensiones del dibujo 565x468 x 0.7 = dimensiones finales 395.5 x 327.6
	dimensiones del dibujo 565x468 x 0.8 = dimensiones finales 452   x 374.4
	dimensiones del dibujo 565x468 x 0.9 = dimensiones finales 508.5 x 421.2 ]]
	
    overlayPNG(mapUI, 10350, 13018, 0.1, "logo", "media/textures/worldMap/GhostbustersLogo.png")
    -- agrega el dibujo PNG del logo de los cazafantazmas. (en coordenadas del mundo, eje x inicial, eje y inicial, y múltiplo de las dimensiones)
	
    MapUtils.overlayPaper(mapUI)
    -- dibuja una textura tipo papel sobre el mapa.
end

local LVx = 11700
local LVy = 900
local LVw = 300 * 4
local LVh = 300 * 4
local LVdx = 300 * 3
local LVdy = 300 * 3
local LVbadgeHgt = 150
local function lvGridX1(col)
	return LVx + LVdx * col
end
local function lvGridY1(row)
	return LVy + LVdy * row - LVbadgeHgt
end
local function lvGridX2(col)
	return lvGridX1(col) + LVw - 1
end
local function lvGridY2(row)
	return lvGridY1(row) + LVh - 1 + LVbadgeHgt
end

LootMaps.Init.MockingbirdStashMap1 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
end
LootMaps.Init.MockingbirdStashMap2 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
end
LootMaps.Init.MockingbirdStashMap3 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
end
LootMaps.Init.MockingbirdStashMap4 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
end
LootMaps.Init.MockingbirdStashMap5 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
end
LootMaps.Init.MockingbirdStashMap6 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
end
LootMaps.Init.MockingbirdStashMap7 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
end
LootMaps.Init.MockingbirdStashMap8 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
end
LootMaps.Init.MockingbirdStashMap9 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(10200, 12900, 10499, 13199)
end
--[[
PrintMediaMaps = {}
PrintMediaMaps.Init = {}

function PrintMediaMaps.callLua(functionName, mapUI, arg1, arg2, arg3, arg4)
	local t = PrintMediaMaps[functionName]
	if not t then
		print("PrintMediaMaps.callLua(): no such function PrintMediaMaps." .. functionName)
		return
	end
	local f = t[mapUI.mapID]
	if f then
		return f(mapUI, arg1, arg2, arg3, arg4)
	end
	if functionName == "Init" and tonumber(arg1) ~= nil then
		local details = PrintMediaDefinitions.MiscDetails[mapUI.mapID]
		if details and details.locations and (#details.locations >= 1) and (#details.locations >= arg1) then
			local location = details.locations[arg1]
			if location.x1 and location.y1 and location.x2 and location.y2 then
				local mapAPI = mapUI.javaObject:getAPIv1()
				MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
				MapUtils.initDefaultStyleV3(mapUI)
				replaceWaterStyle(mapUI)
				mapAPI:setBoundsInSquares(location.x1, location.y1, location.x2, location.y2)
				mapUI.centerX = location.x
				mapUI.centerY = location.y
				return
			end
		end
	end
	print("PrintMediaMaps.callLua(): no such function PrintMediaMaps." .. functionName .. "." .. tostring(mapUI.mapID))
end
]]--