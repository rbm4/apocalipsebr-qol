-- LabRecipesOverride.lua
-- THIS FILE OVERRIDES THE INPUTS OF BONE-RELATED RECIPES TO INCLUDE THE NEW HUMAN BONE ITEMS FROM THE LAB.
-- REPLICATING THE RECIPES AND ADDING THE NEW ITEMS IN THE SCRIPT RATHER THAN USING LUA WOULD BE IDEAL FOR COMPATIBILITY WITH OTHER MODS THAT ALSO ALTER RECIPES, AVOIDING CONFLICTS.
-- HOWEVER, THIS WOULD IMPLY CREATING TOOLTIPS, NAMES, AND TRANSLATIONS FOR EACH RECIPE, IN ADDITION TO HAVING DUPLICATE RECIPES. SO IT'S BETTER TO JUST ALTER THE EXISTING ONES THIS WAY.

-- ============================
-- HELPER
-- ============================
local function patchRecipe(recipeName, newInputs)
    local recipe = getScriptManager():getCraftRecipe(recipeName)
    if not recipe then
        print("[ZVirusVaccine] WARNING: Recipe '" .. recipeName .. "' not found. It may have been renamed or removed by a game update. Skipping patch.")
        return
    end
    recipe:getInputs():clear()
    recipe:Load(recipeName, newInputs)
end

-- ============================
-- SHARPENLONGBONE
-- ============================
patchRecipe("SharpenLongBone", [[{ inputs { 
            item 1 tags[base:whetstone;base:file] mode:keep flags[MayDegradeLight],
            item 1 tags[base:saw;base:smallsaw;base:crudesaw;base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight],
            item 1 [Base.AnimalBone;Base.LargeAnimalBone;LabItems.LabRegularHumanBoneWP;LabItems.LabHumanBoneLargeWP] flags[Prop2;AllowDestroyedItem],
} }]])

-- ============================
-- SHARPENBONE
-- ============================
patchRecipe("SharpenBone", [[{ inputs { 
            item 1 tags[base:whetstone;base:file] mode:keep flags[MayDegradeLight],
            item 1 tags[base:saw;base:smallsaw;base:crudesaw;base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight],
            item 1 [Base.BoneBead_Large;Base.HatchetHead_Bone;Base.SharpBone_Long;Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2;AllowDestroyedItem],
} }]])

-- ============================
-- MAKEBONEFOREARMARMOR
-- ============================
patchRecipe("MakeBoneForearmArmor", [[{ inputs {
            item 5 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy, item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine], item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],
} }]])

-- ============================
-- MAKELARGEBONEBEADS
-- ============================
patchRecipe("MakeLargeBoneBeads", [[{ inputs {
            item 1 tags[base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight;IsNotDull],
            item 1 tags[base:whetstone;base:file] mode:keep flags[MayDegradeLight],
            item 1 [Base.AnimalBone;Base.LargeAnimalBone;Base.JawboneBovide;LabItems.LabRegularHumanBoneWP;LabItems.LabHumanBoneLargeWP] flags[AllowDestroyedItem],
            item 1 tags[base:drillwood;base:drillmetal;base:drillwoodpoor] mode:keep flags[MayDegradeLight],
} }]])

-- ============================
-- MAKELARGEBONEBEAD
-- ============================
patchRecipe("MakeLargeBoneBead", [[{ inputs {
            item 1 tags[base:drillwood;base:drillmetal;base:drillwoodpoor] mode:keep flags[MayDegradeLight],
            item 1 tags[base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight;IsNotDull],
            item 1 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones;Base.SharpBone_Long] flags[AllowDestroyedItem],
} }]])

-- ============================
-- MAKEBONEMASK
-- ============================
patchRecipe("MakeBoneMask", [[{ inputs {
            item 6 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 1 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],
} }]])

-- ============================
-- MAKEBONEPECTORAL
-- ============================
patchRecipe("MakeBonePectoral", [[{ inputs {
            item 6 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],
} }]])

-- ============================
-- MAKEBONESHINARMOR
-- ============================
patchRecipe("MakeBoneShinArmor", [[{ inputs {
            item 3 [Base.AnimalBone;LabItems.LabRegularHumanBoneWP] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight;Prop1],
            item 1 tags[base:saw;base:smallsaw;base:crudesaw] mode:keep flags[MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight],
} }]])

-- ============================
-- MAKEBONESHOULDERARMOR
-- ============================
patchRecipe("MakeBoneShoulderArmor", [[{ inputs {
            item 5 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],
} }]])

-- ============================
-- MAKEBONETHIGHARMOR
-- ============================
patchRecipe("MakeBoneThighArmor", [[{ inputs {
            item 3 [Base.AnimalBone;LabItems.LabRegularHumanBoneWP] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight;Prop1],
            item 1 tags[base:saw;base:smallsaw;base:crudesaw] mode:keep flags[MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight],
} }]])

-- ============================
-- MAKEBONEARMOREDGLOVES
-- ============================
patchRecipe("MakeBoneArmoredGloves", [[{ inputs {
            item 4 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 1 [Base.Gloves_FingerlessGloves;Base.Gloves_FingerlessLeatherGloves;Base.Gloves_FingerlessLeatherGloves_Black;Base.Gloves_FingerlessLeatherGloves_Brown;Base.Gloves_LeatherGloves;Base.Gloves_LeatherGlovesBlack;Base.Gloves_LeatherGlovesBrown],
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],
} }]])

-- ============================
-- MAKEBONEHATCHETHEAD
-- ============================
patchRecipe("MakeBoneHatchetHead", [[{ inputs {
            item 1 tags[base:saw;base:smallsaw;base:crudesaw;base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight],
            item 1 [Base.JawboneBovide;Base.LargeAnimalBone;LabItems.LabHumanBoneLargeWP] flags[Prop2],
            item 1 tags[base:whetstone;base:file] mode:keep flags[MayDegradeLight],
} }]])

-- ============================
-- CARVEFLESHINGTOOL
-- ============================
patchRecipe("CarveFleshingTool", [[{ inputs {
            item 1 tags[base:sharpknife;base:meatcleaver;base:saw;base:smallsaw;base:crudesaw] mode:keep flags[MayDegrade;IsNotDull],
            item 1 [Base.AnimalBone;Base.LargeAnimalBone;LabItems.LabHumanBoneLargeWP;LabItems.LabRegularHumanBoneWP] flags[InheritCondition],
} }]])

-- ============================
-- CARVEWHISTLE
-- ============================
patchRecipe("CarveWhistle", [[{ inputs {
            item 1 tags[base:drillwood;base:drillmetal;base:drillwoodpoor] mode:keep flags[MayDegradeLight],
            item 1 tags[base:sharpknife] mode:keep flags[MayDegradeLight],
            item 1 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2;AllowDestroyedItem],
} }]])