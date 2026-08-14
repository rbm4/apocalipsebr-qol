--***********************************************************************
-- Railroader / RR_ColliderDefinitions  -- invisible collision-segment type
--
-- Defines a lightweight custom animal type "rr_collider". The train collider is a
-- chain of these placed along the loco body (RR_Collider.lua): each one is spawned
-- INVISIBLE (setInvisible), AI held by a per-tick position pin, and left COLLIDABLE
-- with NO blockMovement so its separate() actually pushes zombies/the player out of
-- the body. (Our visible loco has blockMovement=true, which makes isPushedBySeparate
-- return false -> it can't push anything; hence these dedicated segments.)
--
-- Verified collision facts (docs/ENGINE_NOTES.md, IsoMovingObject/IsoAnimal):
--   * width = adef.collisionSize * getAnimalSize(), recomputed every update
--     (IsoAnimal.java:431). So the push radius is set via the DEF's collisionSize,
--     not setWidth (which is overwritten each tick).
--   * A zombie is pushed off an animal only if that animal is collidable AND has
--     blockMovement=false (IsoMovingObject.isPushedByForSeparate). Hence collidable
--     here, and the segment is NEVER given blockMovement.
--
-- size is pinned to 1.0 (minSize=maxSize=1.0) so width == collisionSize exactly.
-- collisionSize MUST equal RR.Body.SEG_RADIUS (RR_Body.lua) -> half the loco width.
--
-- Cloned from cow (like rr_loco) so every field the engine may touch exists; the
-- single grow-stage is keyed by the TYPE NAME so AnimalData.initStage finds it
-- (else currentStage==null NPE). The cow body model is kept (light + never drawn).
--***********************************************************************

AnimalDefinitions = AnimalDefinitions or {}

-- Keep in sync with RR.Body.SEG_RADIUS. (RR_Body may not be loaded yet at this
-- point, so this is a literal, not a reference.)
local COLLISION_SIZE = 1.6

local function buildColliderType()
    local A = AnimalDefinitions
    if not (A.animals and A.animals["cow"]) then return false end   -- cow not loaded yet
    if A.animals["rr_collider"] then return true end                -- already built
    if not (A.genome and A.genome["cow"]) then return false end

    local seg = copyTable(A.animals["cow"])

    -- INVISIBLE body: point every body-model variant at a STATIC model, which draws
    -- BLANK on the animal render path (skinningData is null -- proven, see
    -- railroader_models.txt / ENGINE_NOTES). This hides the segment reliably even
    -- for a debug/admin player (setInvisible does not). Collision is unaffected
    -- (separate() uses width = collisionSize*size, not the model).
    local BLANK = "RR_ColliderBlank"
    seg.bodyModel           = BLANK
    seg.bodyModelSkel       = BLANK
    seg.bodyModelHeadless   = BLANK
    seg.bodyModelSkelNoHead = BLANK
    seg.modelscript         = BLANK
    seg.bodyModelFleece     = nil
    seg.textureSkinned      = nil

    -- Single ADULT grow-stage keyed by the TYPE NAME (initStage NPE guard). No calf.
    seg.stages   = { ["rr_collider"] = { ageToGrow = 12 * 30 } }
    seg.babyType = nil
    seg.minAge   = 0

    -- Reuse cow genes (all names resolve in AnimalGenomeDefinitions).
    seg.genes = A.genome["cow"].genes

    -- Fixed render size 1.0 so width == collisionSize. (Invisible, so this only
    -- affects the collision radius, not any visible scale.)
    seg.minSize    = 1.0
    seg.maxSize    = 1.0
    seg.animalSize = 1.0

    -- The whole point: a collidable body with a body-half-width push radius.
    seg.collidable    = true
    seg.collisionSize = COLLISION_SIZE

    -- NO SHADOW: the body model draws blank, but an IsoAnimal still casts its own
    -- ground shadow (IsoAnimal.renderShadow: w = adef.shadoww * size, no per-entity
    -- opt-out flag). Cloned from cow, each segment inherited cow's shadoww=1/fm=3/bm=2
    -- -> a row of cow shadows pooled under the loco. Zeroing the three shadow fields
    -- makes w/fm/bm = 0 -> a degenerate zero-size shadow, i.e. none. Collision is
    -- unaffected (separate() uses collisionSize, not the shadow).
    seg.shadoww  = 0
    seg.shadowfm = 0
    seg.shadowbm = 0

    -- SILENCE at the source (the AI can't be stopped without losing the push, and
    -- the emitter has no Lua mute). idleSoundVolume/Radius are AnimalDefinition
    -- fields read by the vocals system -> 0 = no moo. Clearing each breed's `sounds`
    -- table removes footstep/breed sounds too (playBreedSound finds nothing).
    seg.idleSoundVolume = 0
    seg.idleSoundRadius = 0
    if seg.breeds then
        for _, b in pairs(seg.breeds) do
            if type(b) == "table" then b.sounds = nil end
        end
    end

    seg.group = "rr_collider"   -- debug-spawn grouping only

    A.animals["rr_collider"] = seg

    -- Parity holders (mirror vanilla / rr_loco).
    A.stages = A.stages or {}
    A.stages["rr_collider"] = { stages = seg.stages }
    A.genome = A.genome or {}
    A.genome["rr_collider"] = A.genome["cow"]
    A.breeds = A.breeds or {}
    A.breeds["rr_collider"] = { breeds = seg.breeds }

    print("[Railroader] rr_collider animal type defined (invisible collision segment, collisionSize="
          .. COLLISION_SIZE .. ")")
    return true
end

if not buildColliderType() then
    print("[Railroader] RR_ColliderDefinitions: cow not ready at load; deferring to OnGameBoot")
    if Events and Events.OnGameBoot then
        Events.OnGameBoot.Add(buildColliderType)
    end
end
