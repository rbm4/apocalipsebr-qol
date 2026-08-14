--***********************************************************************
-- Railroader / RR_AnimalMenuFilter  -- hide the vanilla animal context menu on our animals
--
-- The loco (rr_loco) and its collider segments (rr_collider) are REAL IsoAnimals,
-- so right-clicking the locomotive pops the vanilla livestock menu -- Feed, Water,
-- Kill, Pet, Info, Attach, and every debug entry -- built per-animal by
-- AnimalContextMenu.doMenu (see ISUI/Animal/ISAnimalContextMenu.lua), fed from the
-- OnClickedAnimalForContext event. That menu is meaningless (and immersion-breaking)
-- on a diesel engine.
--
-- doMenu is the ONE funnel every world-object animal submenu passes through, so we
-- wrap it and bail out for any animal whose type carries our "rr_" prefix (rr_loco,
-- rr_collider). No header, no submenu, nothing gets added -- the loco simply has no
-- animal section in its right-click menu. Everything NOT ours falls through to the
-- original untouched.
--***********************************************************************

print("[Railroader] RR_AnimalMenuFilter.lua: loading...")

local OWN_PREFIX = "rr_"   -- our animal types: rr_loco (visual), rr_collider (segments)

local function isOurs(animal)
    if not animal then return false end
    local t
    pcall(function() t = animal:getAnimalType() end)
    return t ~= nil and string.sub(t, 1, #OWN_PREFIX) == OWN_PREFIX
end

local function install()
    if not AnimalContextMenu or AnimalContextMenu.rrAnimalMenuFiltered then return end
    if not AnimalContextMenu.doMenu or not AnimalContextMenu.onAnimalInfo then return end
    local origDoMenu = AnimalContextMenu.doMenu
    local origInfo = AnimalContextMenu.onAnimalInfo
    local origClicked = AnimalContextMenu.clickedAnimals
    AnimalContextMenu.doMenu = function(player, context, animal, test)
        if isOurs(animal) then
            -- Add NOTHING as a rule -- except the single admin-gated entry that
            -- belongs on the locomotive itself: "put it back on the rails"
            -- (RR_RerailMenu, silent unless the player is a server admin AND the
            -- animal is part of a derailed loco). This is the hook with the best
            -- reach we have on the body: the engine collects clicked animals from
            -- the 3x3 around the clicked square, and the hull is lined with
            -- rr_collider segments, so a click anywhere along the wreck lands on
            -- one of ours (SP v1.0.2 hook, v1.0.8 admin-gated in MP).
            if RR and RR.RerailMenu and RR.RerailMenu.addForAnimal then
                pcall(function() RR.RerailMenu.addForAnimal(player, context, animal, test) end)
            end
            return
        end
        return origDoMenu(player, context, animal, test)
    end
    AnimalContextMenu.onAnimalInfo = function(animal, chr)
        if isOurs(animal) then return end
        return origInfo(animal, chr)
    end
    if origClicked then
        AnimalContextMenu.clickedAnimals = function(player, context, animals, test)
            local filtered = {}
            for _, animal in ipairs(animals or {}) do
                if not isOurs(animal) then filtered[#filtered + 1] = animal end
            end
            return origClicked(player, context, filtered, test)
        end
    end
    AnimalContextMenu.rrAnimalMenuFiltered = true
end

install()
Events.OnGameStart.Add(install)
