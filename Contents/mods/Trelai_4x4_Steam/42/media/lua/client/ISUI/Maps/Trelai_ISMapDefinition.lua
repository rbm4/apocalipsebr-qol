--require "ISMapDefinitions"
require "Maps/ISMapDefinitions"

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
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)

	-- Add the town-name PNG.
	overlayPNG(mapUI, 7540, 6820, 0.666, "badge", "media/textures/worldMap/trelaibadge.png")

	-- Add the legend PNG.
	overlayPNG(mapUI, 6666, 7500, 0.555, "legend", "media/textures/worldMap/TrelaiLegend.png")

	-- Draw a paper-like texture overtop the map.
	MapUtils.overlayPaper(mapUI)

	-- 4The original loot map texture, used to position things correctly.
	--overlayPNG(mapUI, 10524, 9222, 1.0, "lootMapPNG", "media/ui/trelaiitems/trelaimap.png", 1.0)
end


LootMaps.Init.trelaimap4 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
	mapAPI:setBoundsInSquares(6600, 6600, 7799, 7099)
	MapUtils.overlayPaper(mapUI)
	--overlayPNG(mapUI, 7555, 6969, 0.333, "legend", "media/textures/worldMap/TrelaiLegend.png")
end

LootMaps.Init.trelaimap3 = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	MapUtils.initDefaultStyleV3(mapUI)
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
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	MapUtils.initDefaultStyleV3(mapUI)
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
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	MapUtils.initDefaultStyleV3(mapUI)
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
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	MapUtils.initDefaultStyleV3(mapUI)
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
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Trelai_4x4')
	MapUtils.initDefaultStyleV3(mapUI)
	replaceWaterStyle(mapUI)
    mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)
	--mapAPI:setBoundsInSquares(6600, 6600, 7799, 7799)
	MapUtils.overlayPaper(mapUI)
    --overlayPNG(mapUI, 6600, 6600, 1.0, "lootMapPNG", "media/ui/trelaiitems/test.png", 1.0)
    --overlayPNG(mapUI, 6600, 6600, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/dragonball_note.png", 1.0)
	--overlayPNG(mapUI, 7555, 6969, 0.333, "legend", "media/textures/worldMap/TrelaiLegend.png")
end


local bookMAPX1 = 10
local bookMAPY1 = 10

local bookMAPX2 = 1700
local bookMAPY2 = 1200

-- LootMaps.Init.book0 = function(mapUI)
-- 	local mapAPI = mapUI.javaObject:getAPIv1()
-- 	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
-- 	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
-- 	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book0.png", 1.0)
-- end

-- LootMaps.Init.book1 = function(mapUI)
-- 	local mapAPI = mapUI.javaObject:getAPIv1()
-- 	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
-- 	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
-- 	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book1.png", 1.0)
-- end

-- LootMaps.Init.book2 = function(mapUI)
-- 	local mapAPI = mapUI.javaObject:getAPIv1()
-- 	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
-- 	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
-- 	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book2.png", 1.0)
-- end

-- LootMaps.Init.book3 = function(mapUI)
-- 	local mapAPI = mapUI.javaObject:getAPIv1()
-- 	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
-- 	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
-- 	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book3.png", 1.0)
-- end

-- LootMaps.Init.book4 = function(mapUI)
-- 	local mapAPI = mapUI.javaObject:getAPIv1()
-- 	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
-- 	mapAPI:setBoundsInSquares(bookMAPX1, bookMAPY1, bookMAPX2, bookMAPY2)
-- 	overlayPNG(mapUI, bookMAPX1, bookMAPY1, 1.0, "lootMapPNG", "media/ui/trelaiitems/notes/book4.png", 1.0)
-- end