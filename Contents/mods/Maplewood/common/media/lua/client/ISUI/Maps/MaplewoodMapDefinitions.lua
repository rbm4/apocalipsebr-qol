require 'Maps/ISMapDefinitions'

local MINZ = 0
local MAXZ = 24
local WATER_TEXTURE = false

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

local function worldMapImage(fileName)
	if getCore():getOptionColorblindPatterns() then
		return "media/textures/worldMap/Colorblind Patterns/" .. fileName
	end
	return "media/textures/worldMap/" .. fileName
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

LootMaps.Maplewood_MAP_DIRECTORY = 'media/maps/Maplewood'
LootMaps.Maplewood_OVERLAYS_DIRECTORY = 'media/textures/worldMap/'

LootMaps.Init.MaplewoodMap = function(mapUI)
    local mapAPI = mapUI.javaObject:getAPIv1()
    MapUtils.initDirectoryMapData(mapUI, LootMaps.Maplewood_MAP_DIRECTORY )
    MapUtils.initDefaultStyleV3(mapUI)
    replaceWaterStyle(mapUI)
    mapAPI:setBoundsInSquares(8100, 8400, 8399, 8699)
    MapUtils.overlayPaper(mapUI)
end