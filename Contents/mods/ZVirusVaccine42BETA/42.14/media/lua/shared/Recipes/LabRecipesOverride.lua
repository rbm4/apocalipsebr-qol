-- LabRecipesOverride.lua
-- THIS FILE OVERRIDES THE INPUTS OF BONE-RELATED RECIPES TO INCLUDE THE NEW HUMAN BONE ITEMS FROM THE LAB.
-- REPLICATING THE RECIPES AND ADDING THE NEW ITEMS IN THE SCRIPT RATHER THAN USING LUA WOULD BE IDEAL FOR COMPATIBILITY WITH OTHER MODS THAT ALSO ALTER RECIPES, AVOIDING CONFLICTS.
-- HOWEVER, THIS WOULD IMPLY CREATING TOOLTIPS, NAMES, AND TRANSLATIONS FOR EACH RECIPE, IN ADDITION TO HAVING DUPLICATE RECIPES. SO IT'S BETTER TO JUST ALTER THE EXISTING ONES THIS WAY.

-- ============================
-- SHARPENLONGBONE
-- ============================
local newInputs = [[{ inputs { 
            item 1 tags[base:whetstone;base:file] mode:keep flags[MayDegradeLight],
            item 1 tags[base:saw;base:smallsaw;base:crudesaw;base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight],
            item 1 [Base.AnimalBone;Base.LargeAnimalBone;LabItems.LabRegularHumanBone;LabItems.LabHumanBoneLarge;LabItems.LabRegularHumanBoneWP;LabItems.LabHumanBoneLargeWP] flags[Prop2;AllowDestroyedItem],
} }]]
local recipe = getScriptManager():getCraftRecipe("SharpenLongBone")
recipe:getInputs():clear()
recipe:Load("SharpenLongBone", newInputs)

-- ============================
-- SHARPENBONE
-- ============================
local newInputs = [[{ inputs { 
            item 1 tags[base:whetstone;base:file] mode:keep flags[MayDegradeLight],
            item 1 tags[base:saw;base:smallsaw;base:crudesaw;base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight],
            item 1 [Base.BoneBead_Large;Base.HatchetHead_Bone;Base.SharpBone_Long;Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2;AllowDestroyedItem],
} }]]
local recipe = getScriptManager():getCraftRecipe("SharpenBone")
recipe:getInputs():clear()
recipe:Load("SharpenBone", newInputs)

-- ============================
-- MAKEBONEFOREARMARMOR
-- ============================
local newInputs = [[{ inputs {
            item 5 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy, item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine], item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],
} }]]
local recipe = getScriptManager():getCraftRecipe("MakeBoneForearmArmor")
recipe:getInputs():clear()
recipe:Load("MakeBoneForearmArmor", newInputs)

-- ============================
--MAKELARGEBONEBEADS
-- ============================
local newInputs = [[{ inputs {
            item 1 tags[base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight;IsNotDull],
            item 1 tags[base:whetstone;base:file] mode:keep flags[MayDegradeLight],
            item 1 [Base.AnimalBone;Base.LargeAnimalBone;Base.JawboneBovide;LabItems.LabRegularHumanBone;LabItems.LabHumanBoneLarge;LabItems.LabRegularHumanBoneWP;LabItems.LabHumanBoneLargeWP] flags[AllowDestroyedItem],
            item 1 tags[base:drillwood;base:drillmetal;base:drillwoodpoor] mode:keep flags[MayDegradeLight],
} }]]
local recipe = getScriptManager():getCraftRecipe("MakeLargeBoneBeads")
recipe:getInputs():clear()
recipe:Load("MakeLargeBoneBeads", newInputs)

-- ============================
--MAKELARGEBONEBEAD
-- ============================
local newInputs = [[{ inputs {
            item 1 tags[base:drillwood;base:drillmetal;base:drillwoodpoor] mode:keep flags[MayDegradeLight],
            item 1 tags[base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight;IsNotDull],
            item 1 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones;Base.SharpBone_Long] flags[AllowDestroyedItem],
} }]]
local recipe = getScriptManager():getCraftRecipe("MakeLargeBoneBead")
recipe:getInputs():clear()
recipe:Load("MakeLargeBoneBead", newInputs)

-- ============================
-- MAKEBONEMASK
-- ============================
local newInputs = [[{ inputs {
            item 6 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 1 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],
} }]]
local recipe = getScriptManager():getCraftRecipe("MakeBoneMask")
recipe:getInputs():clear()
recipe:Load("MakeBoneMask", newInputs)

-- ============================
-- MAKEBONEPECTORAL
-- ============================
local newInputs = [[{ inputs {
            item 6 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],

} }]]
local recipe = getScriptManager():getCraftRecipe("MakeBonePectoral")
recipe:getInputs():clear()
recipe:Load("MakeBonePectoral", newInputs)

-- ============================
-- MAKEBONESHINARMOR
-- ============================
local newInputs = [[{ inputs {
            item 3 [Base.AnimalBone;LabItems.LabRegularHumanBone;LabItems.LabRegularHumanBoneWP] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight;Prop1],
            item 1 tags[base:saw;base:smallsaw;base:crudesaw] mode:keep flags[MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight],
} }]]
local recipe = getScriptManager():getCraftRecipe("MakeBoneShinArmor")
recipe:getInputs():clear()
recipe:Load("MakeBoneShinArmor", newInputs)

-- ============================
-- MAKEBONESHOULDERARMOR
-- ============================
local newInputs = [[{ inputs {
            item 5 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],
} }]]
local recipe = getScriptManager():getCraftRecipe("MakeBoneShoulderArmor")
recipe:getInputs():clear()
recipe:Load("MakeBoneShoulderArmor", newInputs)

-- ============================
-- MAKEBONETHIGHARMOR
-- ============================
local newInputs = [[{ inputs {
            item 3 [Base.AnimalBone;LabItems.LabRegularHumanBone;LabItems.LabRegularHumanBoneWP] flags[Prop2],
            item 2 [Base.LeatherStrips] mode:destroy,
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight;Prop1],
            item 1 tags[base:saw;base:smallsaw;base:crudesaw] mode:keep flags[MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight],
} }]]
local recipe = getScriptManager():getCraftRecipe("MakeBoneThighArmor")
recipe:getInputs():clear()
recipe:Load("MakeBoneThighArmor", newInputs)

-- ============================
-- MAKEBONEARMOREDGLOVES
-- ============================
local newInputs = [[{ inputs {
            item 4 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2],
            item 1 [Base.Gloves_FingerlessGloves;Base.Gloves_FingerlessLeatherGloves;Base.Gloves_FingerlessLeatherGloves_Black;Base.Gloves_FingerlessLeatherGloves_Brown;Base.Gloves_LeatherGloves;Base.Gloves_LeatherGlovesBlack;Base.Gloves_LeatherGlovesBrown],
            item 1 tags[base:sharpknife] mode:keep flags[IsNotDull;MayDegradeLight],
            item 1 [Base.Twine],
            item 1 tags[base:awl] mode:keep flags[MayDegradeLight;Prop1],
} }]]
local recipe = getScriptManager():getCraftRecipe("MakeBoneArmoredGloves")
recipe:getInputs():clear()
recipe:Load("MakeBoneArmoredGloves", newInputs)

-- ============================
-- MAKEBONEHATCHETHEAD
-- ============================
local newInputs = [[{ inputs {
            item 1 tags[base:saw;base:smallsaw;base:crudesaw;base:sharpknife;base:meatcleaver] mode:keep flags[MayDegradeLight],
            item 1 [Base.JawboneBovide;Base.LargeAnimalBone;LabItems.LabHumanBoneLarge;LabItems.LabHumanBoneLargeWP] flags[Prop2],
            item 1 tags[base:whetstone;base:file] mode:keep flags[MayDegradeLight],
} }]]
local recipe = getScriptManager():getCraftRecipe("MakeBoneHatchetHead")
recipe:getInputs():clear()
recipe:Load("MakeBoneHatchetHead", newInputs)

-- ============================
-- CARVEFLESHINGTOOL
-- ============================
local newInputs = [[{ inputs {
            item 1 tags[base:sharpknife;base:meatcleaver;base:saw;base:smallsaw;base:crudesaw] mode:keep flags[MayDegrade;IsNotDull],
            item 1 [Base.AnimalBone;Base.LargeAnimalBone;LabItems.LabHumanBoneLarge;LabItems.LabHumanBoneLargeWP;LabItems.LabRegularHumanBone;LabItems.LabRegularHumanBoneWP] flags[InheritCondition],
} }]]
local recipe = getScriptManager():getCraftRecipe("CarveFleshingTool")
recipe:getInputs():clear()
recipe:Load("CarveFleshingTool", newInputs)

-- ============================
-- CARVEWHISTLE
-- ============================
local newInputs = [[{ inputs {
            item 1 tags[base:drillwood;base:drillmetal;base:drillwoodpoor] mode:keep flags[MayDegradeLight],
            item 1 tags[base:sharpknife] mode:keep flags[MayDegradeLight],
            item 1 [Base.SmallAnimalBone;LabItems.LabSmallRandomHumanBones] flags[Prop2;AllowDestroyedItem],
} }]]
local recipe = getScriptManager():getCraftRecipe("CarveWhistle")
recipe:getInputs():clear()
recipe:Load("CarveWhistle", newInputs)