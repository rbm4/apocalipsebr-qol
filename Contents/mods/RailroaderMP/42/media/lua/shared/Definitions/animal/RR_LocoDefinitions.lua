--***********************************************************************
-- Railroader / RR_LocoDefinitions  (Task 1.A-art: placeholder skinned model)
--
-- Defines a clean CUSTOM animal type "rr_loco" whose body is our skinned
-- placeholder model "RR_LocoTest" (a box rigged to one Bip01 bone). The whole
-- working entity pipeline (movement / depth-sort / ride) is reused unchanged;
-- only the rendered model differs. The animal AI is suppressed at runtime by
-- RR_TrainEntity, so the cow-derived living-animal fields here are inert.
--
-- WHY clone the cow (verified against decompiled B42, see docs/MODEL_PIPELINE.md):
--   * loadAnimalDefinitions() builds each type purely from the per-animal sub-
--     tables (stages / breeds / genes), read off the global AnimalDefinitions
--     table at first use (AnimalDefinitions.java:loadAnimalDefinitions).
--   * AnimalData.initStage() NPE guard: currentStage is the grow-stage whose
--     `.stage` equals the TYPE NAME (AnimalGrowStage.stage = the table key).
--     Cloning cow keeps keys cowcalf/cow/bull -> none == "rr_loco" ->
--     currentStage stays null -> NPE. FIX: one stage keyed "rr_loco".
--   * Breeds + genes must exist or AnimalBreed/AnimalGene init NPEs. We give a
--     single breed pointing at OUR texture, and reuse the cow gene name list
--     (every name resolves in AnimalGenomeDefinitions).
--
-- Spawned via RR_TrainEntity.spawnDemo("rr_loco") -> addAnimal + addToWorld.
--***********************************************************************

AnimalDefinitions = AnimalDefinitions or {}

local MODEL = "RR_LocoTest"

local function buildLocoType()
    local A = AnimalDefinitions
    if not (A.animals and A.animals["cow"]) then return false end  -- cow not loaded yet
    if A.animals["rr_loco"] then return true end                   -- already built
    if not (A.genome and A.genome["cow"]) then return false end

    -- Shallow-clone the cow animal def so every field the engine may touch
    -- exists, then override the parts that make it OUR rigid placeholder.
    local loco = copyTable(A.animals["cow"])

    -- Our skinned placeholder model on every body-model variant.
    loco.bodyModel           = MODEL
    loco.bodyModelSkel       = MODEL
    loco.bodyModelHeadless   = MODEL
    loco.bodyModelSkelNoHead = MODEL
    loco.modelscript         = MODEL
    loco.bodyModelFleece     = nil
    loco.textureSkinned      = nil      -- force the breed.texture path (our texture)
    loco.animset             = "cow"    -- reuse the cow rig/animset

    -- Single ADULT grow-stage keyed by the TYPE NAME -> initStage finds it,
    -- currentStage != null (the NPE we hit before). No calf, no growth.
    loco.stages   = { ["rr_loco"] = { ageToGrow = 12 * 30 } }
    loco.babyType = nil                 -- no reproduction
    loco.minAge   = 0

    -- Genome: reuse the cow gene-name list (all names exist in the genome def).
    loco.genes = A.genome["cow"].genes

    -- Render scale = 1.5 * size (IsoAnimal.java:2642). This is the REAL size knob
    -- for the loco (the model-script `scale` is ignored on the animal path).
    loco.minSize    = 0.7
    loco.maxSize    = 0.7
    loco.animalSize = 0.5
    loco.female     = true              -- initTexture -> breed.texture (female) list

    -- Ground shadow (Task 1.K, level 1: the vanilla animal blob-shadow, retuned).
    -- IsoAnimal.renderShadow draws ONE oval decal under the entity, sized
    -- shadow{w,fm,bm} * getData().getSize() and aligned to the travel direction
    -- (IsoAnimal.java:1116). The cow values we inherited give a tiny calf-sized
    -- blob under a 15-tile body; blow the oval up to span the corpus instead.
    -- size ~= 0.7, so effective half-width = shadoww*0.7, forward/back reach =
    -- shadow{fm,bm}*0.7. A straight oval: it tracks heading but does NOT chord
    -- the rail kink like the collider (that would be the level-2 shadow chain).
    loco.shadoww    = 2.2               -- ~1.5 tiles half-width
    loco.shadowfm   = 10.0              -- ~7 tiles forward
    loco.shadowbm   = 10.0              -- ~7 tiles back  -> ~14-tile oval along the body

    -- SILENCE the inherited cow sound fields (the rr_collider segment def does
    -- the same). The game's own animal vocal system (IsoAnimal.updateVocalProperties
    -- -> AnimalVocalsManager, runs on every client within 70 tiles) reads
    -- idleSoundVolume/Radius from the def and the breed sound table: a parked,
    -- engine-OFF loco must not contribute game-driven animal sounds (the
    -- "phantom sound near the spawn" bug), and must not attract zombies via
    -- addWorldSoundUnlessInvisible. Our breed already has no `sounds`, so this
    -- is belt-and-braces consistency with rr_collider.
    loco.idleSoundVolume = 0
    loco.idleSoundRadius = 0

    -- One breed pointing at OUR texture. loadBreeds splits `texture` on ',' into
    -- a list; initTexture picks from it. textureMale covers the male branch too.
    loco.breeds = {
        ["rr"] = {
            name        = "rr",
            texture     = MODEL,
            textureMale = MODEL,
        },
    }

    loco.group = "rr_loco"              -- debug-spawn grouping only

    A.animals["rr_loco"] = loco

    -- Parity holders (vanilla defines these; the loader reads the per-animal
    -- sub-tables, but keep them for any lookup-by-type code).
    A.stages = A.stages or {}
    A.stages["rr_loco"] = { stages = loco.stages }
    A.genome = A.genome or {}
    A.genome["rr_loco"] = A.genome["cow"]
    A.breeds = A.breeds or {}
    A.breeds["rr_loco"] = { breeds = loco.breeds }

    print("[Railroader] rr_loco animal type defined (model=" .. MODEL .. ")")
    return true
end

if not buildLocoType() then
    -- cow def not present at our load time; retry once the game has booted.
    print("[Railroader] RR_LocoDefinitions: cow not ready at load; deferring to OnGameBoot")
    if Events and Events.OnGameBoot then
        Events.OnGameBoot.Add(buildLocoType)
    end
end
