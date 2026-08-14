--***********************************************************************
-- Railroader / RR_AlbumPlace  -- the engine adapter that hands the survivor the
-- photo album (the easter egg; see shared/Railroader/RR_Album.lua for what it is
-- and why it needs no art).
--
-- WHO GETS IT: only a character who took the RAILROADER PROFESSION -- i.e. only
-- someone holding the licence trait (RR_Profession.hasLicense). The album is not
-- a stranger's; it is HIS. Six photographs of the life he had before the outbreak,
-- ending on an old man alone at a crossing. It is the one line of backstory the
-- mod tells, and it only means anything to the man who lived it.
--
-- WHERE: straight into his inventory at character creation -- he is carrying it,
-- the way you carry the one thing you go back for. (The first cut dropped it on
-- the spawn square; on the floor it is one more piece of house clutter, and the
-- point is that it is HIS.)
--
-- WHEN: OnNewGame(playerObj, square) -- vanilla's own new-character hook (see
-- shared/Items/SpawnItems.lua, handed exactly these two arguments), and the
-- profession's granted trait is already on the character by then (verified --
-- docs/ENGINE_NOTES.md, "Professions & custom traits"). Belt and braces: a flag in
-- the save's global ModData ("RR_World", the same table the depot loco's spawn flag
-- lives in) means it can never be handed out twice.
--
-- API facts this is built on (verified in the B42 decompile / vanilla scripts):
--   * THERE IS NO InventoryItemFactory IN B42 LUA. It is a B41 memory; in B42 the
--     global does not exist, and calling it throws "attempted index: CreateItem of
--     non-table: null" -- which is exactly how the first version of this file failed
--     in-game. Vanilla B42 Lua creates items with ItemContainer:AddItem("Base.X")
--     (or the free function instanceItem("Base.X") when it needs a loose item).
--   * Base.PhotoAlbum is an InventoryContainer -> :getItemContainer():AddItem(...)
--     -- the same call vanilla's StarterKit makes on a schoolbag.
--   * A photo's content IS its name -> :setName(...) + a unique literatureTitle in
--     modData is the entire vanilla mechanism (ItemCodeOnCreate.setMediaName does
--     precisely those two things).
--
-- Debug: RR.AlbumPlace.giveToPlayer() from the console puts a fresh album in your
-- inventory without starting a new save (and ignores the profession gate).
--***********************************************************************

print("[Railroader] RR_AlbumPlace.lua: loading...")
require("Railroader/RR_Album")
require("Railroader/RR_Profession")

local Album = RR.Album

local Place = {}

local MD_TAG = "RR_World"          -- same global ModData table as RR_Depot's

local function worldData()
    local wd = nil
    pcall(function() wd = ModData.getOrCreate(MD_TAG) end)
    return wd
end

--------------------------------------------------------------------------
-- caption(key): the photo's full name, from our own translation key. Falls back
-- to the key itself if the string is missing -- ugly in-game, but visible, which
-- is what you want from a missing translation.
--------------------------------------------------------------------------
local function caption(key)
    local s = key
    pcall(function() s = getText(key) end)
    return s
end

--------------------------------------------------------------------------
-- fill(album): put the six photographs into an album item. Returns how many
-- landed (6 = all of them).
--------------------------------------------------------------------------
function Place.fill(album)
    local inv = nil
    pcall(function() inv = album:getItemContainer() end)
    if not inv then
        print("[Railroader] album: " .. Album.ALBUM_TYPE .. " has no container -- no photos added.")
        return 0
    end

    local n = 0
    for _, p in ipairs(Album.PHOTOS) do
        local photo = nil
        pcall(function() photo = inv:AddItem(Album.PHOTO_TYPE) end)
        if photo then
            -- Vanilla's onCreatePhoto has already given this one a random subject.
            -- Overwrite it: the name IS what is depicted; literatureTitle is "have I
            -- read this one". Both are plain fields -- no Java needed.
            pcall(function()
                photo:setName(caption(p.key))
                photo:getModData().literatureTitle = Album.literatureTitle(p.id, ZombRand(1000000))
                photo:getModData().rrAlbumPhoto    = p.id
            end)
            n = n + 1
        else
            print("[Railroader] album: could not create " .. Album.PHOTO_TYPE .. " (" .. p.id .. ")")
        end
    end
    return n
end

--------------------------------------------------------------------------
-- giveTo(playerObj): put a loaded album in this character's inventory.
-- Returns true on success. Does NOT check the profession -- callers decide.
--------------------------------------------------------------------------
function Place.giveTo(playerObj)
    if not playerObj then return false end

    local album = nil
    pcall(function() album = playerObj:getInventory():AddItem(Album.ALBUM_TYPE) end)
    if not album then
        print("[Railroader] album: could not create " .. Album.ALBUM_TYPE)
        return false
    end

    local n = Place.fill(album)
    print(string.format("[Railroader] album: the railroader is carrying his photo album (%d/%d photographs).",
                        n, #Album.PHOTOS))
    return true
end

--------------------------------------------------------------------------
-- onNewGame(playerObj, square): the hook. A Railroader gets his album, once ever.
--------------------------------------------------------------------------
function Place.onNewGame(playerObj, square)
    if RR.MP and RR.MP.blocked() then return end     -- the mod stood down: no props for it (RR_MP)
    if not playerObj then return end

    -- Not a railroader -> not his album, and he never had one.
    if not (RR.Profession and RR.Profession.hasLicense(playerObj)) then return end

    local wd = worldData()
    if wd and wd[Album.MD_FLAG] then return end

    if not Place.giveTo(playerObj) then return end
    if wd then wd[Album.MD_FLAG] = true end
end

--------------------------------------------------------------------------
-- Debug: hand one to the player right now (console), gate and flag ignored.
--------------------------------------------------------------------------
function Place.giveToPlayer()
    Place.giveTo(getPlayer())
end

Events.OnNewGame.Add(Place.onNewGame)

RR = RR or {}
RR.AlbumPlace = Place
print("[Railroader] RR_AlbumPlace.lua: loaded OK (a Railroader starts with his photo album)")

return Place
