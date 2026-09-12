--[[
    Auto All - Cook, Tailoring and Reload (Build 42 / SP + MP)
    ------------------------------------------------------------------
    Defaults and in-game Mod Options (PZAPI.ModOptions, vanilla B42 API).

    Everything here is client side: the server never sees this file and
    never needs it.
]]

AutoAll = AutoAll or {}
local AA = AutoAll

AA.MOD_ID = "AutoAll"

if AA.configLoaded then return end
AA.configLoaded = true

---------------------------------------------------------------------
-- the ten automations
--
-- This lives here rather than in AutoAll_Core because AutoAll_Core's
-- first line is `require "AutoAll/AutoAll_Config"`: this file is fully
-- executed, options panel and all, before a single line of Core runs. The
-- panel is built from this table, so the table has to exist by then.
--
-- Core builds its lookups from it afterwards and owns AA.enabled,
-- AA.icon and AA.registerMenu.
--
-- `icon` is a texture name. The game builds those from an item script's
-- `Icon =` field as `Item_<Icon>`, so `Item_Wrench` is the wrench item's
-- own art. All ten were read out of media/scripts rather than guessed.
---------------------------------------------------------------------

-- `label` is spelled out rather than glued together from `option` at run
-- time, for the same reason the tickboxes below are: validate-autoall.js
-- matches literal strings, and a key built with `..` is invisible to it.
AA.MODULES = {
    { key = "cook",      option = "enableCook",      sandbox = "EnableCook",      icon = "Item_Spoon",       label = "UI_AA_opt_enableCook"      },
    { key = "read",      option = "enableRead",      sandbox = "EnableRead",      icon = "Item_Book",        label = "UI_AA_opt_enableRead"      },
    { key = "clean",     option = "enableClean",     sandbox = "EnableClean",     icon = "Item_Soap",        label = "UI_AA_opt_enableClean"     },
    { key = "sterilize", option = "enableSterilize", sandbox = "EnableSterilize", icon = "Item_Alcohol",     label = "UI_AA_opt_enableSterilize" },
    { key = "rip",       option = "enableRip",       sandbox = "EnableRip",       icon = "Item_Scissors",    label = "UI_AA_opt_enableRip"       },
    { key = "repair",    option = "enableRepair",    sandbox = "EnableRepair",    icon = "Item_Needle",      label = "UI_AA_opt_enableRepair"    },
    { key = "tailoring", option = "enableTailoring", sandbox = "EnableTailoring", icon = "Item_Thread",      label = "UI_AA_opt_enableTailoring" },
    { key = "mechanics", option = "enableMechanics", sandbox = "EnableMechanics", icon = "Item_Wrench",      label = "UI_AA_opt_enableMechanics" },
    { key = "reload",    option = "enableReload",    sandbox = "EnableReload",    icon = "Item_PistolAmmo",  label = "UI_AA_opt_enableReload"    },
    { key = "dismantle", option = "enableDismantle", sandbox = "EnableDismantle", icon = "Item_Screwdriver", label = "UI_AA_opt_enableDismantle" },
    { key = "vhs",       option = "enableVHS",       sandbox = "EnableVHS",       icon = "Item_Cassette3",   label = "UI_AA_opt_enableVHS"       },
    { key = "medicine",  option = "enableMedicine",  sandbox = "EnableMedicine",  icon = "Item_Bandage",     label = "UI_AA_opt_enableMedicine"  },
    { key = "exercise",  option = "enableExercise",  sandbox = "EnableExercise",  icon = "Item_Dumbbell",    label = "UI_AA_opt_enableExercise"  },
    { key = "open",      option = "enableOpen",      sandbox = "EnableOpen",      icon = "Item_CanOpener",   label = "UI_AA_opt_enableOpen"      },
}

AA.defaults = {
    -- cooking
    cookMaxIngredients = 0,     -- 0 = whatever the recipe allows (MaxItems)
    cookSameTypeMax    = 2,     -- how many copies of the same ingredient may go in
    cookSpices         = true,  -- season the dish with every spice available
    cookSpiceMax       = 3,     -- how many different spices at most
    cookSkipUnhappy    = true,  -- skip ingredients that make the meal depressing
    cookSkipRotten     = true,
    cookSkipPoison     = true,
    cookSkipFavorite   = true,  -- never cook items flagged as favourite
    cookReturnItems    = true,  -- put borrowed items back where they came from
    cookPriority       = 1,     -- 1 calories / 2 hunger / 3 balanced
    cookBadFromLevel   = 7,     -- Cooking level that unlocks bad ingredients (0 = never)
    -- Off by default, because it changes which ingredients go in the pot
    -- and nobody should have that change under them on an update.
    -- Requested by Tourette: "maybe also an option to use ingredients
    -- sorted by freshest (so a tomato that has only 2 hours freshness
    -- will be prioritized)".
    cookSpoilFirst     = false, -- prefer the ingredients closest to going off

    -- cleaning
    cleanSelf          = true,  -- wash the character as well as the gear
    -- Off by default: wringing is its own entry now ("Wring Out Wet
    -- Clothing"), so the wash no longer decides for you. Turn this back on
    -- to have it follow the wash automatically.
    cleanWring         = false, -- wring the clothes out afterwards and put them back on

    -- sterilizing
    sterilReturnItems  = true,  -- put the leftover alcohol back when finished

    -- dismantling electronics
    dismantleReturnItems   = true,  -- put the screwdriver back when finished
    dismantleResultsToSource = true, -- send the scrap back to the container it came from
    dismantleMax           = 0,     -- 0 = as many as the batch allows

    -- ripping clothing
    ripSkipFavorite    = true,  -- never rip items flagged as favourite
    ripReturnItems     = true,  -- put the scissors back when finished
    -- Off by default: rags, denim strips and leather strips are the single
    -- most used material in the game, and walking back to the wardrobe for
    -- them is exactly the clicking this mod exists to remove. Turn it on to
    -- have the results go back where the clothing came from.
    ripResultsToSource = false, -- send the strips back to the container they came from
    ripMax             = 0,     -- 0 = as many as the batch allows

    -- tailoring
    tailorFabric       = 1,     -- 1 any / 2 ripped sheets / 3 denim strips / 4 leather strips
    tailorMaxCycles    = 0,     -- 0 = until stopped
    tailorHolesFirst   = true,  -- patch actual holes before padding intact parts

    -- reading
    readSkillBooks     = true,  -- skill books whose level band fits the character
    readMagazines      = true,  -- recipe magazines that still teach something new
    readNearby         = true,  -- also take books from the containers in reach
    readReturnItems    = true,  -- put each book back where it came from
    readMaxBooks       = 0,     -- 0 = until there is nothing left to read

    -- opening tins and jars
    openReturnItems     = true,  -- put the can opener back when finished
    openResultsToSource = true,  -- send the opened food back to the container it came from
    openMax             = 0,     -- 0 = as many as there are

    -- watching tapes
    vhsNearby          = true,  -- also take tapes from the containers in reach
    vhsReturnItems     = true,  -- put each watched tape back where it came from
    vhsMaxTapes        = 0,     -- 0 = until there is nothing left worth watching

    -- which automations exist at all (all on, so nothing changes for
    -- anyone who never opens this panel)
    enableCook         = true,
    enableRead         = true,
    enableClean        = true,
    enableSterilize    = true,
    enableRip          = true,
    enableRepair       = true,
    enableTailoring    = true,
    enableMechanics    = true,
    enableReload       = true,
    enableDismantle    = true,
    enableVHS          = true,
    enableMedicine     = true,
    enableExercise     = true,
    enableOpen         = true,

    -- Auto Medicine
    -- Disinfecting is on by default: it is what stops an ordinary cut
    -- becoming an infected one, and it is the step people forget. Anyone
    -- rationing alcohol turns it off.
    medDisinfect       = true,

    -- mechanics
    -- The game's own success chance, as a percentage. Parts below this are
    -- left alone rather than gambled with. 30 is roughly "will not wreck
    -- the car"; 100 is "never risk a part at all".
    mechMinSuccess     = 30,
    mechMax            = 0,     -- 0 = every part it can do
    -- Single player only, and it restores something rather than adding it.
    -- Vanilla's failure sound goes through playServerSound, which is
    -- GameServer.PlayWorldSound, which opens with "if (!GameServer.server)
    -- return" - so on a dedicated server everyone hears the metal snap and
    -- in single player nobody ever does. Ours is a local emitter sound, not
    -- a world sound, so it stays audio and does not call zombies over.
    mechFailSound      = true,

    -- reload
    reloadMaxCycles    = 0,     -- 0 = until stopped

    -- safety, shared by the three automations
    stopOnMove         = true,
    stopOnAim          = true,
    stopOnEsc          = true,
    stopZombie         = true,
    stopDamage         = true,

    -- The Auto All tab in the character window. On by default; a
    -- controller player asked to be able to take it out of the tab
    -- rotation, and everything it holds is also in Mod Options.
    showTab            = true,

    -- misc
    -- 1 off, 2/3/4 = the game's own three fast forward steps (multiplier
    -- 5, 20, 40 - see the SPEEDS table in AutoAll_Core). Single player
    -- only; the server owns game speed in multiplayer.
    --
    -- On by default at the game's first step since 2026-08-29. It shipped
    -- off, and the report was "is there a reason it don't auto speed up, I
    -- have seen other Mods do that, as I need to speed my speed up key
    -- always" (Barbiehunter) - which is exactly the clicking this mod
    -- exists to remove, sitting behind a setting nobody found. The first
    -- step rather than 20x or 40x because it is only ever taken from a
    -- standing start, handed straight back when the job ends, and dropped
    -- for the rest of the job the moment the player touches the speed
    -- themselves. See AA.applySpeed.
    fastForward        = 2,
    notify             = 1,     -- 1 halo text / 2 speech bubble / 3 off
    notifyEvery        = 20,    -- seconds before the same "waiting" message repeats
}

--- Reads a setting from Mod Options, falling back to the default above.
function AA.opt(key)
    local options = AA.options
    if options then
        local option = options:getOption(key)
        if option then
            local ok, value = pcall(function() return option:getValue() end)
            if ok and type(value) == "string" then value = tonumber(value) or value end
            if ok and value ~= nil then return value end
        end
    end
    return AA.defaults[key]
end

---------------------------------------------------------------------
-- the community button
---------------------------------------------------------------------

AA.DISCORD_URL = "https://discord.gg/ugRKt2apwu"

--- Shows the invite in a field the player can select and copy.
---
--- **The game cannot open this link, and no mod can make it.** Read out of
--- the jar rather than guessed at:
---
---   * the global is declared `openURl` - capital U, capital R, lowercase
---     L - so vanilla's own `openUrl(url)` at MainScreen.lua:1538 is
---     already nil, Kahlua's dispatch being case sensitive;
---   * and the real method opens with
---
---         if (!LuaManager.isIndieStoneUrl(url)) return;
---
---     where isIndieStoneUrl is a hardcoded whitelist of exactly four
---     domains: steamcommunity.com, projectzomboid.com, theindiestone.com
---     and pzwiki.net. Anything else is dropped in silence.
---
--- So a browser was never going to open. That leaves two options:
--- activateSteamOverlayToWebPage, which has no whitelist but forces
--- Steam's built-in browser and was turned down; or handing over the text.
--- This hands over the text.
--- ISTextBox with a Copy button added beside Ok and Cancel.
---
--- Clipboard.setClipboard is what the base game's own "copy to clipboard"
--- uses (ISSpawnPointsEditor.lua:270), so a click really does put the
--- invite on the system clipboard - no selecting, no Ctrl+C.
--- Puts the invite on the system clipboard and says so on the button.
---
--- Clipboard.setClipboard is what the base game's own copy-to-clipboard
--- uses (ISSpawnPointsEditor.lua:270). A dialog confirming a copy would be
--- one dialog too many, so the button re-titles itself instead.
local function onCopyDiscord(box, button)
    local ok = pcall(function() Clipboard.setClipboard(AA.DISCORD_URL) end)

    if button and button.setTitle then
        button:setTitle(getText(ok and "UI_AA_discord_copied" or "UI_AA_discord_copybtn"))
    end
    if not ok then
        print("[AutoAll] clipboard unavailable; Discord invite is " .. AA.DISCORD_URL)
    end
end

--- Adds a Copy button beside Ok and Cancel and re-lays the row for three.
---
--- Done here, after initialise(), and **not** by overriding createChildren
--- on a subclass - which is what the first attempt did, and why no button
--- appeared. ISTextBox builds Ok and Cancel inside `initialise`, and its
--- first `addChild` (the text entry, line 27) instantiates the box, which
--- calls createChildren from inside initialise - well before `self.yes`
--- and `self.no` exist twenty lines further down. The override ran, found
--- no buttons and returned.
local function addCopyButton(box)
    if not box.yes or not box.no then return end

    local gap    = 10
    local width  = box.yes:getWidth()
    local height = box.yes:getHeight()
    local row    = box.yes:getY()

    local copy = ISButton:new(0, row, width, height,
            getText("UI_AA_discord_copybtn"), box, onCopyDiscord)
    copy:initialise()
    copy:instantiate()
    box:addChild(copy)

    local total = width * 3 + gap * 2
    local left  = (box:getWidth() - total) / 2
    copy:setX(left)
    box.yes:setX(left + width + gap)
    box.no:setX(left + (width + gap) * 2)
end

function AA.openDiscord()
    local url = AA.DISCORD_URL

    local ok, err = pcall(function()
        local w, h = 420, 150
        local box = ISTextBox:new(
                getCore():getScreenWidth() / 2 - w / 2,
                getCore():getScreenHeight() / 2 - h / 2,
                w, h,
                getText("UI_AA_discord_copy"), url, nil, nil)
        box:initialise()
        addCopyButton(box)
        box:addToUIManager()
    end)

    if not ok then
        print("[AutoAll] could not show the Discord link box: " .. tostring(err))
        print("[AutoAll] Discord invite is " .. url)
        return false
    end
    return true
end

--- A clickable button in the mod options panel.
---
--- PZAPI.ModOptions has no addButton, but the screen that draws the panel
--- does handle `type = "button"` (MainOptions.lua:2974) - so the entry is
--- appended to options.data by hand, in the shape that renderer reads:
--- it wants name, id, target, onclick, args and tooltip.
---
--- Guarded, because this reaches past the documented API. If a future
--- build drops that branch the button is simply absent and the rest of
--- the panel is unaffected.
function AA.addButton(options, id, name, onclick, tooltip)
    if not options or type(options.data) ~= "table" then return nil end

    local entry = {
        type = "button", id = id, name = name,
        target = nil, onclick = onclick, args = {},
        tooltip = tooltip, isEnabled = true,
    }
    table.insert(options.data, entry)
    return entry
end

local function createModOptions()
    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.create) then return end

    local d = AA.defaults
    local options = PZAPI.ModOptions:create(AA.MOD_ID, "UI_AA_ModName")
    AA.options = options

    -- Which automations exist at all, first, because it is the setting
    -- most people will come here for: ten modules is a lot of context menu
    -- for someone who only wanted Auto Read. Everything is on by default,
    -- so an existing save behaves exactly as it did.
    --
    -- Written out one per line rather than looped over AA.MODULES, and
    -- deliberately. validate-autoall.js checks that every default has a
    -- panel entry and a translated label by matching literal strings in
    -- this file; a loop that glues the key name together at runtime is
    -- invisible to it, and would quietly switch that check off for
    -- exactly the ten options a player is most likely to touch. Ten lines
    -- is a cheap price for keeping the pre-flight check honest.
    options:addTitle("UI_AA_opt_titleModules")
    options:addDescription("UI_AA_opt_modules_desc")
    options:addTickBox("enableCook", "UI_AA_opt_enableCook", d.enableCook, "UI_AA_opt_modules_tt")
    options:addTickBox("enableRead", "UI_AA_opt_enableRead", d.enableRead, "UI_AA_opt_modules_tt")
    options:addTickBox("enableClean", "UI_AA_opt_enableClean", d.enableClean, "UI_AA_opt_modules_tt")
    options:addTickBox("enableSterilize", "UI_AA_opt_enableSterilize", d.enableSterilize, "UI_AA_opt_modules_tt")
    options:addTickBox("enableRip", "UI_AA_opt_enableRip", d.enableRip, "UI_AA_opt_modules_tt")
    options:addTickBox("enableRepair", "UI_AA_opt_enableRepair", d.enableRepair, "UI_AA_opt_modules_tt")
    options:addTickBox("enableTailoring", "UI_AA_opt_enableTailoring", d.enableTailoring, "UI_AA_opt_modules_tt")
    options:addTickBox("enableMechanics", "UI_AA_opt_enableMechanics", d.enableMechanics, "UI_AA_opt_modules_tt")
    options:addTickBox("enableReload", "UI_AA_opt_enableReload", d.enableReload, "UI_AA_opt_modules_tt")
    options:addTickBox("enableDismantle", "UI_AA_opt_enableDismantle", d.enableDismantle, "UI_AA_opt_modules_tt")
    options:addTickBox("enableOpen", "UI_AA_opt_enableOpen", d.enableOpen, "UI_AA_opt_modules_tt")
    options:addTickBox("enableVHS", "UI_AA_opt_enableVHS", d.enableVHS, "UI_AA_opt_modules_tt")
    options:addTickBox("enableMedicine", "UI_AA_opt_enableMedicine", d.enableMedicine, "UI_AA_opt_modules_tt")
    options:addTickBox("enableExercise", "UI_AA_opt_enableExercise", d.enableExercise, "UI_AA_opt_modules_tt")

    options:addTitle("UI_AA_opt_titleCook")
    options:addSlider("cookMaxIngredients", "UI_AA_opt_cookMaxIngredients", 0, 12, 1, d.cookMaxIngredients, "UI_AA_opt_cookMaxIngredients_tt")
    options:addSlider("cookSameTypeMax", "UI_AA_opt_cookSameTypeMax", 1, 6, 1, d.cookSameTypeMax, "UI_AA_opt_cookSameTypeMax_tt")
    options:addTickBox("cookSpices", "UI_AA_opt_cookSpices", d.cookSpices, "UI_AA_opt_cookSpices_tt")
    options:addSlider("cookSpiceMax", "UI_AA_opt_cookSpiceMax", 1, 6, 1, d.cookSpiceMax, "UI_AA_opt_cookSpiceMax_tt")

    local priority = options:addComboBox("cookPriority", "UI_AA_opt_cookPriority", "UI_AA_opt_cookPriority_tt")
    priority:addItem("UI_AA_prio_calories", true)
    priority:addItem("UI_AA_prio_hunger")
    priority:addItem("UI_AA_prio_balanced")

    options:addTickBox("cookSkipUnhappy", "UI_AA_opt_cookSkipUnhappy", d.cookSkipUnhappy, "UI_AA_opt_cookSkipUnhappy_tt")
    options:addTickBox("cookSkipRotten", "UI_AA_opt_cookSkipRotten", d.cookSkipRotten, "UI_AA_opt_cookSkipRotten_tt")
    options:addTickBox("cookSkipPoison", "UI_AA_opt_cookSkipPoison", d.cookSkipPoison, "UI_AA_opt_cookSkipPoison_tt")
    options:addTickBox("cookSkipFavorite", "UI_AA_opt_cookSkipFavorite", d.cookSkipFavorite, "UI_AA_opt_cookSkipFavorite_tt")
    options:addTickBox("cookSpoilFirst", "UI_AA_opt_cookSpoilFirst", d.cookSpoilFirst, "UI_AA_opt_cookSpoilFirst_tt")
    options:addTickBox("cookReturnItems", "UI_AA_opt_cookReturnItems", d.cookReturnItems, "UI_AA_opt_cookReturnItems_tt")
    options:addSlider("cookBadFromLevel", "UI_AA_opt_cookBadFromLevel", 0, 10, 1, d.cookBadFromLevel, "UI_AA_opt_cookBadFromLevel_tt")

    options:addTitle("UI_AA_opt_titleClean")
    options:addTickBox("cleanSelf", "UI_AA_opt_cleanSelf", d.cleanSelf, "UI_AA_opt_cleanSelf_tt")
    options:addTickBox("cleanWring", "UI_AA_opt_cleanWring", d.cleanWring, "UI_AA_opt_cleanWring_tt")

    options:addTitle("UI_AA_opt_titleSteril")
    options:addTickBox("sterilReturnItems", "UI_AA_opt_sterilReturnItems", d.sterilReturnItems, "UI_AA_opt_sterilReturnItems_tt")

    options:addTitle("UI_AA_opt_titleDismantle")
    options:addTickBox("dismantleReturnItems", "UI_AA_opt_dismantleReturnItems", d.dismantleReturnItems, "UI_AA_opt_dismantleReturnItems_tt")
    options:addTickBox("dismantleResultsToSource", "UI_AA_opt_dismantleResultsToSource", d.dismantleResultsToSource, "UI_AA_opt_dismantleResultsToSource_tt")
    options:addSlider("dismantleMax", "UI_AA_opt_dismantleMax", 0, 100, 1, d.dismantleMax, "UI_AA_opt_dismantleMax_tt")

    options:addTitle("UI_AA_opt_titleOpen")
    options:addTickBox("openReturnItems", "UI_AA_opt_openReturnItems", d.openReturnItems, "UI_AA_opt_openReturnItems_tt")
    options:addTickBox("openResultsToSource", "UI_AA_opt_openResultsToSource", d.openResultsToSource, "UI_AA_opt_openResultsToSource_tt")
    options:addSlider("openMax", "UI_AA_opt_openMax", 0, 100, 1, d.openMax, "UI_AA_opt_openMax_tt")

    options:addTitle("UI_AA_opt_titleRip")
    options:addTickBox("ripSkipFavorite", "UI_AA_opt_ripSkipFavorite", d.ripSkipFavorite, "UI_AA_opt_ripSkipFavorite_tt")
    options:addTickBox("ripReturnItems", "UI_AA_opt_ripReturnItems", d.ripReturnItems, "UI_AA_opt_ripReturnItems_tt")
    options:addTickBox("ripResultsToSource", "UI_AA_opt_ripResultsToSource", d.ripResultsToSource, "UI_AA_opt_ripResultsToSource_tt")
    options:addSlider("ripMax", "UI_AA_opt_ripMax", 0, 100, 1, d.ripMax, "UI_AA_opt_ripMax_tt")

    options:addTitle("UI_AA_opt_titleTailor")
    local fabric = options:addComboBox("tailorFabric", "UI_AA_opt_tailorFabric", "UI_AA_opt_tailorFabric_tt")
    fabric:addItem("UI_AA_fabric_any", true)
    fabric:addItem("UI_AA_fabric_sheets")
    fabric:addItem("UI_AA_fabric_denim")
    fabric:addItem("UI_AA_fabric_leather")
    options:addSlider("tailorMaxCycles", "UI_AA_opt_tailorMaxCycles", 0, 100, 1, d.tailorMaxCycles, "UI_AA_opt_tailorMaxCycles_tt")
    options:addTickBox("tailorHolesFirst", "UI_AA_opt_tailorHolesFirst", d.tailorHolesFirst, "UI_AA_opt_tailorHolesFirst_tt")

    options:addTitle("UI_AA_opt_titleRead")
    options:addTickBox("readSkillBooks", "UI_AA_opt_readSkillBooks", d.readSkillBooks, "UI_AA_opt_readSkillBooks_tt")
    options:addTickBox("readMagazines", "UI_AA_opt_readMagazines", d.readMagazines, "UI_AA_opt_readMagazines_tt")
    options:addTickBox("readNearby", "UI_AA_opt_readNearby", d.readNearby, "UI_AA_opt_readNearby_tt")
    options:addTickBox("readReturnItems", "UI_AA_opt_readReturnItems", d.readReturnItems, "UI_AA_opt_readReturnItems_tt")
    options:addSlider("readMaxBooks", "UI_AA_opt_readMaxBooks", 0, 50, 1, d.readMaxBooks, "UI_AA_opt_readMaxBooks_tt")

    options:addTitle("UI_AA_opt_titleVHS")
    options:addTickBox("vhsNearby", "UI_AA_opt_vhsNearby", d.vhsNearby, "UI_AA_opt_vhsNearby_tt")
    options:addTickBox("vhsReturnItems", "UI_AA_opt_vhsReturnItems", d.vhsReturnItems, "UI_AA_opt_vhsReturnItems_tt")
    options:addSlider("vhsMaxTapes", "UI_AA_opt_vhsMaxTapes", 0, 50, 1, d.vhsMaxTapes, "UI_AA_opt_vhsMaxTapes_tt")

    options:addTitle("UI_AA_opt_titleMech")
    options:addSlider("mechMinSuccess", "UI_AA_opt_mechMinSuccess", 0, 100, 5, d.mechMinSuccess, "UI_AA_opt_mechMinSuccess_tt")
    options:addSlider("mechMax", "UI_AA_opt_mechMax", 0, 60, 1, d.mechMax, "UI_AA_opt_mechMax_tt")
    options:addTickBox("mechFailSound", "UI_AA_opt_mechFailSound", d.mechFailSound, "UI_AA_opt_mechFailSound_tt")

    options:addTitle("UI_AA_opt_titleReload")
    options:addSlider("reloadMaxCycles", "UI_AA_opt_reloadMaxCycles", 0, 100, 1, d.reloadMaxCycles, "UI_AA_opt_reloadMaxCycles_tt")

    options:addTitle("UI_AA_opt_titleMed")
    options:addTickBox("medDisinfect", "UI_AA_opt_medDisinfect", d.medDisinfect, "UI_AA_opt_medDisinfect_tt")

    options:addTitle("UI_AA_opt_titleSafety")
    options:addTickBox("stopOnMove", "UI_AA_opt_stopOnMove", d.stopOnMove, "UI_AA_opt_stopOnMove_tt")
    options:addTickBox("stopOnAim", "UI_AA_opt_stopOnAim", d.stopOnAim, "UI_AA_opt_stopOnAim_tt")
    options:addTickBox("stopOnEsc", "UI_AA_opt_stopOnEsc", d.stopOnEsc, "UI_AA_opt_stopOnEsc_tt")
    options:addTickBox("stopZombie", "UI_AA_opt_stopZombie", d.stopZombie, "UI_AA_opt_stopZombie_tt")
    options:addTickBox("stopDamage", "UI_AA_opt_stopDamage", d.stopDamage, "UI_AA_opt_stopDamage_tt")

    options:addTitle("UI_AA_opt_titleMisc")
    options:addTickBox("showTab", "UI_AA_opt_showTab", d.showTab, "UI_AA_opt_showTab_tt")
    local speed = options:addComboBox("fastForward", "UI_AA_opt_fastForward", "UI_AA_opt_fastForward_tt")
    speed:addItem("UI_AA_speed_off")
    speed:addItem("UI_AA_speed_2x", true)
    speed:addItem("UI_AA_speed_3x")
    speed:addItem("UI_AA_speed_5x")

    local notify = options:addComboBox("notify", "UI_AA_opt_notify", "UI_AA_opt_notify_tt")
    notify:addItem("UI_AA_notify_halo", true)
    notify:addItem("UI_AA_notify_say")
    notify:addItem("UI_AA_notify_off")

    options:addSlider("notifyEvery", "UI_AA_opt_notifyEvery", 5, 120, 5, d.notifyEvery, "UI_AA_opt_notifyEvery_tt")

    options:addTitle("UI_AA_opt_titleCommunity")
    options:addDescription("UI_AA_opt_discord_desc")
    AA.addButton(options, "discord", "UI_AA_opt_discord_btn",
            AA.openDiscord, "UI_AA_opt_discord_tt")
end

createModOptions()

-- The options screen only reads ModOptions.ini when it is built, so load the
-- saved values ourselves in case the player never opens the options panel.
local function loadSavedOptions()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.load then
        pcall(function() PZAPI.ModOptions:load() end)
    end
end

Events.OnGameStart.Add(loadSavedOptions)
