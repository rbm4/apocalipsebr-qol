--***********************************************************************
-- Railroader / RR_ManualPlace  -- the engine adapter that hands the survivor his
-- notebook (see shared/Railroader/RR_Manual.lua for what is written in it and
-- why it is written that way).
--
-- WHO GETS IT: only a character who took the RAILROADER PROFESSION -- i.e. only
-- someone holding the licence trait (RR_Profession.hasLicense), exactly like the
-- photo album. The two go together and do opposite jobs: the album is who he
-- was, the notebook is a crib sheet of what he knows -- eight pages, one fact
-- per line, ordered by what the player needs first. Nobody else has either.
--
-- WHEN: OnNewGame(playerObj, square), vanilla's own new-character hook, with a
-- flag in the save's global "RR_World" ModData so it can never be handed out
-- twice.
--
-- API facts this is built on (verified in the B42 decompile / vanilla Lua):
--   * Literature.addPage(index, text) is public and is exactly what vanilla Lua
--     calls when the player finishes writing in a journal
--     (ISInventoryPaneContextMenu.onWriteSomethingClick -> notebook:addPage(i,v)).
--     Pages land in customPages, which Literature.save/load serializes -- so the
--     notebook survives save/reload with no work from us.
--   * The pages are readable because the ITEM has CanBeWrite = true: that is what
--     puts "Read/Write <name> note" in the context menu and opens the vanilla
--     ISUIWriteJournal. There is no "open a book UI" call to make.
--   * NO InventoryItemFactory IN B42 LUA (it is a B41 memory that throws) --
--     items come from container:AddItem("Base.X").
--   * The journal draws 15 lines of UIFont.Small in a 350px window and no more;
--     RR_Manual.fits() is the authored-text budget and the unit tests enforce it,
--     because an overflowing page is not scrolled to, it is simply unread.
--
-- Debug: RR.ManualPlace.giveToPlayer() from the console puts a fresh notebook in
-- your inventory without starting a new save (gate and flag ignored).
--***********************************************************************

print("[Railroader] RR_ManualPlace.lua: loading...")
require("Railroader/RR_Manual")
require("Railroader/RR_Profession")

local Manual = RR.Manual

local Place = {}

local MD_TAG = "RR_World"          -- same global ModData table as RR_Depot's / RR_Album's

local function worldData()
    local wd = nil
    pcall(function() wd = ModData.getOrCreate(MD_TAG) end)
    return wd
end

--------------------------------------------------------------------------
-- pageText(key): one page, translated, with the "\n" escapes turned into real
-- line breaks. A missing string falls back to the key itself -- ugly in-game,
-- but visible, which is what you want from a missing translation.
--------------------------------------------------------------------------
local function pageText(key)
    local s = key
    pcall(function() s = getText(key) end)
    return Manual.unescape(s)
end

--------------------------------------------------------------------------
-- write(book): put the pages into a notebook item. Returns how many landed.
--------------------------------------------------------------------------
function Place.write(book)
    local n = 0
    for i, p in ipairs(Manual.PAGES) do
        local okWrite = pcall(function() book:addPage(i, pageText(p.key)) end)
        if okWrite then
            n = n + 1
        else
            print("[Railroader] notebook: could not write page " .. tostring(i) .. " (" .. p.id .. ")")
        end
    end
    -- Mark it as ours, so a later feature can tell this notebook from any other
    -- one the survivor picks up and scribbles in.
    pcall(function() book:getModData().rrNotebook = Manual.pageCount() end)
    return n
end

--------------------------------------------------------------------------
-- giveTo(playerObj): put the filled notebook in this character's inventory.
-- Returns true on success. Does NOT check the profession -- callers decide.
--------------------------------------------------------------------------
function Place.giveTo(playerObj)
    if not playerObj then return false end

    local book = nil
    pcall(function() book = playerObj:getInventory():AddItem(Manual.ITEM_TYPE) end)
    if not book then
        print("[Railroader] notebook: could not create " .. Manual.ITEM_TYPE)
        return false
    end

    local n = Place.write(book)
    print(string.format("[Railroader] notebook: the railroader is carrying his own notebook (%d/%d pages).",
                        n, Manual.pageCount()))
    return true
end

--------------------------------------------------------------------------
-- onNewGame(playerObj, square): a Railroader gets his notebook, once ever.
--------------------------------------------------------------------------
function Place.onNewGame(playerObj, square)
    if RR.MP and RR.MP.blocked() then return end     -- the mod stood down: no manual for it (RR_MP)
    if not playerObj then return end

    -- Not a railroader -> he never wrote one.
    if not (RR.Profession and RR.Profession.hasLicense(playerObj)) then return end

    local wd = worldData()
    if wd and wd[Manual.MD_FLAG] then return end

    if not Place.giveTo(playerObj) then return end
    if wd then wd[Manual.MD_FLAG] = true end
end

--------------------------------------------------------------------------
-- Debug: hand one over right now (console), gate and flag ignored.
--------------------------------------------------------------------------
function Place.giveToPlayer()
    Place.giveTo(getPlayer())
end

Events.OnNewGame.Add(Place.onNewGame)

RR = RR or {}
RR.ManualPlace = Place
print("[Railroader] RR_ManualPlace.lua: loaded OK (a Railroader starts with his notebook)")

return Place
