--***********************************************************************
-- Railroader / RR_Album  -- the photo album a railroader carries out of his old life.
--
-- The mod's one piece of pure flavour: a character who took the RAILROADER
-- PROFESSION starts the game carrying his own photo album -- six photographs of
-- the working life that ended with everything else, ending on an old man alone at
-- a crossing. Nobody else gets one; it is his. Nothing is unlocked by it, no XP,
-- no quest. It is only there to say who you were before, and why the cold GP10 in
-- the Muldraugh shed (RR_Spawn/RR_Depot) is going to feel like YOUR locomotive.
--
-- PURE LUA, NO ENGINE DEPENDENCIES -- unit-tested in a bare interpreter
-- (tests/run_tests.lua). The client adapter (RR_AlbumPlace) does the engine work:
-- create the items, name them, drop them on a square.
--
-- WHY THERE IS NO ART HERE (verified in the B42 scripts + decompile; see
-- docs/ENGINE_NOTES.md "Photos are TEXT, not pictures"): a vanilla photograph has
-- no image of its own. Every Base.Photo shares the same handful of sprites and
-- gets its CONTENT from its NAME -- ItemCodeOnCreate.onCreatePhoto formats
-- "Photograph of a Baby With a Teddy Bear" out of a translation key drawn at
-- random. What is depicted is a string. So the six photographs below are six
-- strings, and Base.PhotoAlbum is a real container item that holds them.
--
-- We name the photos from ONE key each (the whole name, not vanilla's
-- "%1 of %2" composite) so that the RU translation can be a proper Russian
-- sentence instead of "Photograph of <russian>" -- vanilla itself ships no RU
-- strings for photos at all.
--***********************************************************************

local Album = {}

-- Vanilla item types (media/scripts/generated/items/{literature,container}.txt).
Album.ALBUM_TYPE = "Base.PhotoAlbum"
Album.PHOTO_TYPE = "Base.Photo"

-- Vanilla numbers, mirrored here ONLY so the unit test can prove six photos fit.
Album.ALBUM_CAPACITY = 5      -- PhotoAlbum: Capacity = 5
Album.PHOTO_WEIGHT   = 0.1    -- Photo: Weight = 0.1  => 6 photos = 0.6, easily in.
Album.MAX_ITEM_SIZE  = 0.2    -- PhotoAlbum: MaxItemSize -- a photo (0.1) passes.

-- The album is placed exactly once per save; the flag lives in the same global
-- ModData table as the depot loco's (RR_Depot.MD_TAG = "RR_World").
Album.MD_FLAG = "rrAlbumPlaced"

--------------------------------------------------------------------------
-- The six photographs, IN ALBUM ORDER. Order is the whole storytelling device:
-- it walks from the crew at their best to the man who outlived them, so the last
-- one lands. Each entry is an id (stable, used in the literatureTitle) and the
-- translation key holding the item's full name.
--------------------------------------------------------------------------
Album.PHOTOS = {
    { id = "nose",     key = "IGUI_RR_Photo_Nose"     },  -- two men on the nose, sunset
    { id = "shift",    key = "IGUI_RR_Photo_Shift"    },  -- old hand + young hand after a shift
    { id = "crew",     key = "IGUI_RR_Photo_Crew"     },  -- four of them, bags and a cooler
    { id = "flagger",  key = "IGUI_RR_Photo_Flagger"  },  -- the woman with the stop sign
    { id = "bar",      key = "IGUI_RR_Photo_Bar"      },  -- beer at a wooden bar table
    { id = "crossing", key = "IGUI_RR_Photo_Crossing" },  -- one old man, alone, gray sky
}

--------------------------------------------------------------------------
-- literatureTitle(id, roll): the per-item media key PZ uses to remember "have I
-- read this". Vanilla builds it as "<type>_<key>_<random int>"
-- (ItemCodeOnCreate.onCreatePhoto) -- the random part is what stops two photos of
-- the same subject counting as one read. Same shape here; the roll comes from
-- ZombRand in-game and a fixed number in the tests.
--------------------------------------------------------------------------
function Album.literatureTitle(id, roll)
    local n = math.floor(tonumber(roll) or 0)
    if n < 0 then n = 0 end
    return string.format("RRPhoto_%s_%d", tostring(id), n)
end

--------------------------------------------------------------------------
-- fits(): would the album actually hold the set? (Pure sanity -- a silent
-- overflow would drop photos on the floor one by one with no error.)
--------------------------------------------------------------------------
function Album.fits()
    return (#Album.PHOTOS * Album.PHOTO_WEIGHT) <= Album.ALBUM_CAPACITY
       and Album.PHOTO_WEIGHT <= Album.MAX_ITEM_SIZE
end

RR = RR or {}
RR.Album = Album

return Album
