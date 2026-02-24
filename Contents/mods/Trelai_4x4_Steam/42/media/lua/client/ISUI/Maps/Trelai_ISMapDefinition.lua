--require "ISMapDefinitions"
require "Maps/ISMapDefinitions"

MapUtils = {}

 
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

 

local MINZ = 0
local MAXZ = 24

 

local WATER_TEXTURE = false

 --Do i need to use these if im not changing the style?

function MapUtils.initDefaultStyleV1(mapUI)
    local mapAPI = mapUI.javaObject:getAPIv1()
    local styleAPI = mapAPI:getStyleAPI()

 

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
        layer:addFill(13.5, 189, 197, 163, 0)
        layer:addFill(14, 189, 197, 163, 255)
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
--        layer:addScale(MINZ, 4.0)
--        layer:addScale(MAX, 4.0)
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
    layer:setMinZoom(13.0)
    layer:setFilter("building", "yes")
    layer:addFill(13.0, 210, 158, 105, 0)
    layer:addFill(13.5, 210, 158, 105, 255)
    layer:addFill(MAXZ, 210, 158, 105, 255)

 

    layer = styleAPI:newPolygonLayer("building-Residential")
    layer:setMinZoom(13.0)
    layer:setFilter("building", "Residential")
    layer:addFill(13.0, 210, 158, 105, 0)
    layer:addFill(13.5, 210, 158, 105, 255)
    layer:addFill(MAXZ, 210, 158, 105, 255)

 

    layer = styleAPI:newPolygonLayer("building-CommunityServices")
    layer:setMinZoom(13.0)
    layer:setFilter("building", "CommunityServices")
    layer:addFill(13.0, 139, 117, 235, 0)
    layer:addFill(13.5, 139, 117, 235, 255)
    layer:addFill(MAXZ, 139, 117, 235, 255)

 

    layer = styleAPI:newPolygonLayer("building-Hospitality")
    layer:setMinZoom(13.0)
    layer:setFilter("building", "Hospitality")
    layer:addFill(13.0, 127, 206, 225, 0)
    layer:addFill(13.5, 127, 206, 225, 255)
    layer:addFill(MAXZ, 127, 206, 225, 255)

 

    layer = styleAPI:newPolygonLayer("building-Industrial")
    layer:setMinZoom(13.0)
    layer:setFilter("building", "Industrial")
    layer:addFill(13.0, 56, 54, 53, 0)
    layer:addFill(13.5, 56, 54, 53, 255)
    layer:addFill(MAXZ, 56, 54, 53, 255)

 

    layer = styleAPI:newPolygonLayer("building-Medical")
    layer:setMinZoom(13.0)
    layer:setFilter("building", "Medical")
    layer:addFill(13.0, 229, 128, 151, 0)
    layer:addFill(13.5, 229, 128, 151, 255)
    layer:addFill(MAXZ, 229, 128, 151, 255)

 

    layer = styleAPI:newPolygonLayer("building-RestaurantsAndEntertainment")
    layer:setMinZoom(13.0)
    layer:setFilter("building", "RestaurantsAndEntertainment")
    layer:addFill(13.0, 245, 225, 60, 0)
    layer:addFill(13.5, 245, 225, 60, 255)
    layer:addFill(MAXZ, 245, 225, 60, 255)

 

    layer = styleAPI:newPolygonLayer("building-RetailAndCommercial")
    layer:setMinZoom(13.0)
    layer:setFilter("building", "RetailAndCommercial")
    layer:addFill(13.0, 184, 205, 84, 0)
    layer:addFill(13.5, 184, 205, 84, 255)
    layer:addFill(MAXZ, 184, 205, 84, 255)
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
    layer:addFill(14.00, 128, 128, 128, 0)
    layer:addFill(15.00, 128, 128, 128, 32)
    layer:addFill(15.00, 255, 255, 255, 32)
    layer:addTexture(0.00, "media/white.png")
    layer:addTexture(15.00, "media/white.png")
    layer:addTexture(15.00, "media/textures/worldMap/Paper.png")
end

 

function MapUtils.revealKnownArea(mapUI)
    local mapAPI = mapUI.javaObject:getAPIv1()
    local x1 = mapAPI:getMinXInSquares()
    local y1 = mapAPI:getMinYInSquares()
    local x2 = mapAPI:getMaxXInSquares()
    local y2 = mapAPI:getMaxYInSquares()
    WorldMapVisited.getInstance():setKnownInSquares(x1, y1, x2, y2)
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

-- End of Vanilla Funtions


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

--***********************************************************
--**                    Trelai Stash Maps                  **
--***********************************************************
--Trelai.Trelaimap3' South
--Trelai.Trelaimap4' North
--Trelai.Trelaimap'  Annotated Maps
--Trelai.TrelaiStory - Image
--Trelai.TrelaiStory2 - Map and image
--Trelai.Gazette - Tv Mag


LootMaps.Init.trelaimap = function(mapUI)
	-- 1Your custom initialization for Mapitem
	local mapAPI = mapUI.javaObject:getAPIv1()
	mapAPI:addData("media/maps/Trelai_4x4/worldmap.xml")

	-- 2Add XML data from base-game map directories.
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	--MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')

	-- Specify the custom appearance of the map.
	MapUtils.initDefaultStyleV1(mapUI)

	-- Use solid color for water instead of a texture.
	--replaceWaterStyle(mapUI)

	-- 3Show only this area from the full map.
	--mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)
	mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)

	-- Add the town-name PNG.
	--overlayPNG(mapUI, 7540, 6820, 0.666, "badge", "media/textures/worldMap/trelaibadge.png")

	-- Add the legend PNG.
	overlayPNG(mapUI, 6666, 7500, 0.555, "legend", "media/textures/worldMap/TrelaiLegend.png")

	-- Draw a paper-like texture overtop the map.
	MapUtils.overlayPaper(mapUI)

	-- 4The original loot map texture, used to position things correctly.
	--overlayPNG(mapUI, 10524, 9222, 1.0, "lootMapPNG", "media/ui/trelaiitems/trelaimap.png", 1.0)
end


LootMaps.Init.trelaimap4 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	mapAPI:addData("media/maps/Trelai_4x4/worldmap.xml")
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	MapUtils.initDefaultStyleV1(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(6600, 6600, 7799, 7099)
	MapUtils.overlayPaper(mapUI)
	--overlayPNG(mapUI, 7555, 6969, 0.333, "legend", "media/textures/worldMap/TrelaiLegend.png")
end

LootMaps.Init.trelaimap3 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	mapAPI:addData("media/maps/Trelai_4x4/worldmap.xml")
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	MapUtils.initDefaultStyleV1(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(6600, 7100, 7799, 7799)
	MapUtils.overlayPaper(mapUI)
	--overlayPNG(mapUI, 7555, 6969, 0.333, "legend", "media/textures/worldMap/TrelaiLegend.png")
end

local TVMagX1 = 10
local TVMagY1 = 10

local TVMagX2 = 620
local TVMagY2 = 400

LootMaps.Init.TrelaiGazette = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	--mapAPI:addData("media/maps/Trelai_4x4/worldmap.xml")
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
    --MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	MapUtils.initDefaultStyleV1(mapUI)
	replaceWaterStyle(mapUI)
    mapAPI:setBoundsInSquares(TVMagX1, TVMagY1, TVMagX2, TVMagY2)
	--mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)
	MapUtils.overlayPaper(mapUI)
    --overlayPNG(mapUI, 6600, 6600, 1.0, "lootMapPNG", "media/ui/trelaiitems/TVMag.png", 1.0)
    overlayPNG(mapUI, TVMagX1, TVMagY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/TVMag.png", 1.0)
	--overlayPNG(mapUI, 7555, 6969, 0.333, "legend", "media/textures/worldMap/TrelaiLegend.png")
end

LootMaps.Init.TrelaiStory = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	--mapAPI:addData("media/maps/Trelai_4x4/worldmap.xml")
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
    --MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	MapUtils.initDefaultStyleV1(mapUI)
	replaceWaterStyle(mapUI)
    mapAPI:setBoundsInSquares(TVMagX1, TVMagY1, TVMagX2, TVMagY2)
	--mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)
	MapUtils.overlayPaper(mapUI)
    --overlayPNG(mapUI, 6600, 6600, 1.0, "lootMapPNG", "media/ui/trelaiitems/test.png", 1.0)
    overlayPNG(mapUI, TVMagX1, TVMagY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/trelaistory.png", 1.0)
	--overlayPNG(mapUI, 7555, 6969, 0.333, "legend", "media/textures/worldMap/TrelaiLegend.png")
end

LootMaps.Init.TrelaiStory2 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	--mapAPI:addData("media/maps/Trelai_4x4/worldmap.xml")
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
    --MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	MapUtils.initDefaultStyleV1(mapUI)
	replaceWaterStyle(mapUI)
    mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)
	--mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)
	MapUtils.overlayPaper(mapUI)
    --overlayPNG(mapUI, 6600, 6600, 1.0, "lootMapPNG", "media/ui/trelaiitems/test.png", 1.0)
    overlayPNG(mapUI, 6600, 6600, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/trelaistory2.png", 1.0)
	--overlayPNG(mapUI, 7555, 6969, 0.333, "legend", "media/textures/worldMap/TrelaiLegend.png")
end

LootMaps.Init.dragonballmap = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	--mapAPI:addData("media/maps/Trelai_4x4/worldmap.xml")
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
    --MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	MapUtils.initDefaultStyleV1(mapUI)
	replaceWaterStyle(mapUI)
    mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)
	--mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)
	MapUtils.overlayPaper(mapUI)
    --overlayPNG(mapUI, 6600, 6600, 1.0, "lootMapPNG", "media/ui/trelaiitems/test.png", 1.0)
    overlayPNG(mapUI, 6600, 6600, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/dragonball_note.png", 1.0)
	--overlayPNG(mapUI, 7555, 6969, 0.333, "legend", "media/textures/worldMap/TrelaiLegend.png")
end


local bookMAPX1 = 10
local bookMAPY1 = 10

local bookMAPX2 = 1700
local bookMAPY2 = 1200

LootMaps.Init.book0 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book0.png", 1.0)
end

LootMaps.Init.book1 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book1.png", 1.0)
end

LootMaps.Init.book2 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book2.png", 1.0)
end

LootMaps.Init.book3 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book3.png", 1.0)
end

LootMaps.Init.book4 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book4.png", 1.0)
end