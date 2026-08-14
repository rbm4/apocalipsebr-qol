--***********************************************************************
-- Railroader / RR_Profession  -- the "Railroader" profession + its "Engineer"
-- trait (rr:railroader), and the runtime LICENCE query the drive gate hangs on.
--
-- WHY ALL FROM LUA (not a character_*_definition script): B42 parses the
-- character_profession_definition / character_trait_definition scripts BEFORE mod
-- Lua runs, and those scripts resolve the CharacterProfession/CharacterTrait OBJECT
-- out of the registry at parse time -- an object a mod cannot have registered yet
-- (trait -> NPE on load, profession -> crash on select). Registering the objects AND
-- adding their definitions from Lua works, because the character-creation screen
-- reads the registry / definition maps live. (Proven by windowwasher_pz_mod.)
--
-- RUNTIME TRAIT CHECK -- VERIFIED IN THE B42 DECOMPILE (see docs/ENGINE_NOTES.md):
--   * IsoGameCharacter.hasTrait(CharacterTrait) exists and is exposed to Lua
--     (ILuaGameCharacter:172; vanilla Lua calls playerObj:hasTrait(CharacterTrait.X)).
--   * A profession's granted trait really lands on the character: character creation
--     puts it in listboxTraitSelected -> initWorld() -> getWorld():addLuaTrait(type)
--     -> IsoWorld -> playerObj.applyTraits(...) -> characterTraits.set(trait, true),
--     and that happens BEFORE the OnNewGame event fires.
--   * It survives save/reload: IsoGameCharacter.save/load round-trip the known traits
--     as ResourceLocation strings ("rr:railroader") and re-resolve them from the
--     registry on load (MP packets carry the same strings).
-- So the gate hangs on the TRAIT, not on the profession name (which is what
-- windowwasher had to fall back on). We keep the CharacterTrait OBJECT and pass it
-- to hasTrait -- no string matching, no namespace guessing.
--
-- Registry id shapes (ResourceLocation): id "rr:railroader" -> namespace "rr",
-- path "railroader". trait:getName() returns the PATH ONLY ("railroader");
-- tostring(trait) / the save file use the full "rr:railroader". The trait icon is
-- looked up by the engine as media/ui/Traits/trait_<path>.png -- hence
-- media/ui/Traits/trait_railroader.png. The profession icon is IconPathName ->
-- Texture.trygetTexture("prof_railroader") -> media/textures/prof_railroader.png.
--***********************************************************************

local Prof = {}

Prof.PROF_ID  = "rr:railroader"
Prof.TRAIT_ID = "rr:railroader"   -- separate registry from the profession: no clash

-- Debug: force the licence on for ANY character (so the gate can be exercised
-- without rolling a new save). Leave false in shipping builds.
Prof.DEBUG_GRANT = false

Prof.trait      = nil   -- the CharacterTrait object (nil if registration failed)
Prof.profession = nil   -- the CharacterProfession object

--------------------------------------------------------------------------
-- get-or-register: Registry.register THROWS on a duplicate id, so never blind-
-- register. Registry.get returns nil (no throw) when absent.
--------------------------------------------------------------------------
local function getOrRegister(getFn, registerFn, id, label)
    local obj
    pcall(function() obj = getFn(ResourceLocation.of(id)) end)
    if obj then return obj end
    local ok, res = pcall(function() return registerFn(id) end)
    if ok and res then return res end
    print(("[Railroader] FAILED to register %s '%s': %s"):format(label, id, tostring(res)))
    return nil
end

--------------------------------------------------------------------------
-- Register the objects + their UI definitions. Definitions live in Maps keyed by
-- the object, so re-adding overwrites rather than duplicating a row in the UI.
--
-- Trait: cost 0 + isProfessionTrait = TRUE. That flag is load-bearing: a granted
-- copy of a *selectable* trait (isProfessionTrait false) can be deleted in the
-- creation screen for a points refund it never paid -- the windowwasher exploit.
-- A profession-only trait cannot be exploited that way. So the licence is exactly
-- "you took the Railroader profession"; it is not buyable with free points.
--------------------------------------------------------------------------
local function register()
    if not (CharacterTrait and CharacterProfession and ResourceLocation) then
        print("[Railroader] profession API missing -- skipping registration.")
        return
    end

    Prof.trait = getOrRegister(CharacterTrait.get, CharacterTrait.register, Prof.TRAIT_ID, "trait")
    if Prof.trait then
        pcall(function()
            CharacterTraitDefinition.addCharacterTraitDefinition(
                Prof.trait, "UI_trait_RRRailroader", 0, "UI_trait_RRRailroader_Desc",
                true,    -- isProfessionTrait: granted-only, no points refund exploit
                false)   -- disabledInMultiplayer
        end)
    end

    Prof.profession = getOrRegister(CharacterProfession.get, CharacterProfession.register, Prof.PROF_ID, "profession")
    if not Prof.profession then return end

    local profDef
    pcall(function()
        profDef = CharacterProfessionDefinition.addCharacterProfessionDefinition(
            Prof.profession, "UI_prof_Railroader",
            -4,                       -- cost: 4 points (a unique capability + 4 skill levels)
            "UI_prof_RailroaderDesc",
            "prof_railroader")        -- media/textures/prof_railroader.png
    end)
    if not profDef then
        print("[Railroader] FAILED to add the profession definition.")
        return
    end

    -- The licence trait (free, profession-only).
    if Prof.trait then
        pcall(function() profDef:addGrantedTrait(Prof.trait) end)
    end

    -- XP boosts. A road-switcher hostler lives inside a diesel-electric prime mover:
    -- Mechanics (the machinery), Maintenance (keeping it turning), Electricity (the
    -- traction generator/motors). addXPBoost gives both a starting level and the boost.
    local boosts = {
        { name = "Mechanics",   perk = Perks.Mechanics,   level = 2 },
        { name = "Maintenance", perk = Perks.Maintenance, level = 1 },
        { name = "Electricity", perk = Perks.Electricity, level = 1 },
    }
    for _, b in ipairs(boosts) do
        local ok = pcall(function() return profDef:addXPBoost(PerkFactory.getPerk(b.perk), b.level) end)
        if not ok then print("[Railroader] XP boost failed: " .. b.name) end
    end

    print("[Railroader] profession '" .. Prof.PROF_ID .. "' + trait '" .. Prof.TRAIT_ID .. "' registered.")
end

register()

--------------------------------------------------------------------------
-- hasLicense(chr): does this character hold the Railroader trait -- i.e. may they
-- operate rail equipment? THE one place the gate is read from the engine; the pure
-- modules take it as a plain boolean input (RR_Engine env.licensed).
--
-- Defensive: CharacterTraits snapshots the trait registry in its constructor and
-- get() unboxes a Boolean, so a character built BEFORE our trait was registered
-- would NPE on hasTrait. Our registration is at boot (before any character exists),
-- but pcall it anyway and never pass a nil trait.
--------------------------------------------------------------------------
function Prof.hasLicense(chr)
    if Prof.DEBUG_GRANT then return true end

    -- FAIL OPEN, loudly. If the trait never registered (an API change, a load-order
    -- surprise), the gate is broken -- and a broken gate must not brick the whole
    -- point of the mod for everyone. Say so in the log instead of silently locking
    -- every player out of every locomotive.
    if not Prof.trait then
        if not Prof._warned then
            print("[Railroader] WARNING: trait '" .. Prof.TRAIT_ID .. "' is not registered -- "
                  .. "the profession gate is DISABLED (anyone can drive).")
            Prof._warned = true
        end
        return true
    end

    if not chr then return false end
    local has = false
    local ok = pcall(function() has = chr:hasTrait(Prof.trait) end)
    if not ok then
        if not Prof._warnedQuery then
            print("[Railroader] WARNING: hasTrait() threw -- the profession gate is DISABLED.")
            Prof._warnedQuery = true
        end
        return true
    end
    return has == true
end

RR = RR or {}
RR.Profession = Prof

return Prof
