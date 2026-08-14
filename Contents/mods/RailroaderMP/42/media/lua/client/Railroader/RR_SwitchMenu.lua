--***********************************************************************
-- Railroader / RR_SwitchMenu  (Stage 2: throw a switch from the world menu)
--
-- Right-click a switch tile (an industry_railroad_05_* turnout piece) that sits
-- near a registered switch -> a "Railroad switch" submenu with two radio options:
--   * Main line (straight)  = NORMAL
--   * Diverging track        = REVERSE
-- the current one checked. Anchoring is by PROXIMITY to the switch's fork coord
-- (RR_TrackGraph data), gated on the clicked square carrying a turnout sprite, so
-- plain running rail (industry_railroad_01_*) never shows the menu.
--
-- Picking an option does NOT flip the switch on the spot: the survivor walks to
-- the stand and works the lever through a timed action with a progress bar
-- (RR_SwitchAction / ISRRThrowSwitch), which is where the state actually changes.
--
-- State lives in RR_TrackGraph (in memory) and is mirrored to the save's RR_World
-- ModData by RR_SwitchPersist, so a thrown switch survives reload. A loco approaching
-- the fork picks up the state via RR_TrainEntity.reanchor. Placing switch tiles on
-- bare forks is the remaining step.
--***********************************************************************

print("[Railroader] RR_SwitchMenu.lua: loading...")
require("Railroader/RR_TrackGraph")
require("Railroader/RR_SwitchAction")

local SwitchMenu = {}
local SWITCH_SPRITE_PREFIX = "industry_railroad_05_"   -- turnout pieces (T-dump: _52.._55)
-- A turnout-sprite tile is tied to a registered switch only if that switch's fork
-- `at` is within this many tiles (a real turnout sprite sits a few tiles off the fork
-- point). This is NOT a "click near the switch" radius: the clicked tile must itself
-- be a turnout tile (or the switch's exact `place` tile) -- see switchAtSquare.
local ASSOC_RADIUS = 5

--------------------------------------------------------------------------
-- findSwitchObject(sq): the turnout IsoObject on the square, or nil. The action
-- needs the OBJECT (faceThisObject), not just the square.
--------------------------------------------------------------------------
local function findSwitchObject(sq)
    if not sq then return nil end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local o    = objs:get(i)
        local spr  = o:getSprite()
        local name = spr and spr:getName()
        if name and string.sub(name, 1, #SWITCH_SPRITE_PREFIX) == SWITCH_SPRITE_PREFIX then
            return o
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- switchAtSquare(sq): the registered switch whose tile this square IS, or nil.
-- STRICT -- the menu appears only on the switch's own tile:
--   * a placed switch matches its exact `place` tile, and
--   * any switch matches a tile that carries a turnout sprite whose nearest fork
--     `at` is within ASSOC_RADIUS (so a stray vanilla turnout elsewhere is ignored).
-- Returns baseId, sw, how ("place" | "sprite").
--------------------------------------------------------------------------
local function switchAtSquare(sq)
    if not (sq and RR.TrackGraph and RR.TrackGraph.defs) then return nil end
    local x, y, z = math.floor(sq:getX()), math.floor(sq:getY()), math.floor(sq:getZ())
    local hasTurnout = findSwitchObject(sq) ~= nil
    local bBase, bSw, bD
    for baseId, def in pairs(RR.TrackGraph.defs) do
        for _, sw in ipairs(def.switches) do
            local p = sw.place
            if p and math.floor(p.x) == x and math.floor(p.y) == y and math.floor(p.z or 0) == z then
                return baseId, sw, "place"
            end
            if hasTurnout then
                local dx, dy = sw.at.x - x, sw.at.y - y
                local d = dx * dx + dy * dy
                if (not bD) or d < bD then bBase, bSw, bD = baseId, sw, d end
            end
        end
    end
    if hasTurnout and bSw and bD <= (ASSOC_RADIUS * ASSOC_RADIUS) then
        return bBase, bSw, "sprite"
    end
    return nil
end

--------------------------------------------------------------------------
-- onSet: walk to the stand, then throw it (timed action + progress bar). The
-- state is NOT changed here -- ISRRThrowSwitch:perform does it once the work is
-- actually finished, so an interrupted walk/throw leaves the switch as it was.
--------------------------------------------------------------------------
function SwitchMenu.onSet(worldobjects, playerNum, object, baseId, switchId, state)
    if not RR.TrackGraph then return end
    if RR.TrackGraph.getState(baseId, switchId) == state then return end   -- already there
    local playerObj = getSpecificPlayer(playerNum)
    if not (playerObj and object) then return end
    if luautils.walkAdj(playerObj, object:getSquare()) then
        ISTimedActionQueue.add(ISRRThrowSwitch:new(playerObj, object, baseId, switchId, state))
    end
end

--------------------------------------------------------------------------
-- OnFillWorldObjectContextMenu: add the switch submenu ONLY when the clicked square
-- IS a switch's tile (switchAtSquare -- a turnout tile, or a placed switch's exact
-- stand tile). The turnout tile, if present, is what the survivor walks to / faces;
-- otherwise the first clicked object.
-- Signature: (playerNum, context, worldobjects, test).
--------------------------------------------------------------------------
function SwitchMenu.OnFill(playerNum, context, worldobjects, test)
    if RR.MP and RR.MP.blocked() and not RR.MPClient then return end
    if not (RR.TrackGraph and RR.TrackGraph.defs) then return end

    -- The clicked square + a fallback object to face (all objects share the square).
    local sq, firstObj
    for _, o in ipairs(worldobjects) do
        firstObj = firstObj or o
        local s = o:getSquare()
        if s then sq = s; break end
    end
    if not sq then return end

    local baseId, sw = switchAtSquare(sq)
    if not sw then return end

    local object = findSwitchObject(sq) or firstObj
    if not object then return end

    local cur   = RR.TrackGraph.getState(baseId, sw.id)
    local top   = context:addOption(getText("IGUI_RR_Switch"), worldobjects, nil)
    local sub   = ISContextMenu:getNew(context)
    context:addSubMenu(top, sub)

    local oMain = sub:addOption(getText("IGUI_RR_SwitchMain"),    worldobjects, SwitchMenu.onSet, playerNum, object, baseId, sw.id, "normal")
    local oDiv  = sub:addOption(getText("IGUI_RR_SwitchDiverge"), worldobjects, SwitchMenu.onSet, playerNum, object, baseId, sw.id, "reverse")
    sub:setOptionChecked(oMain, cur == "normal")
    sub:setOptionChecked(oDiv,  cur == "reverse")
end

Events.OnFillWorldObjectContextMenu.Add(SwitchMenu.OnFill)

RR = RR or {}
RR.SwitchMenu = SwitchMenu
print("[Railroader] RR_SwitchMenu.lua: loaded OK")
return SwitchMenu
