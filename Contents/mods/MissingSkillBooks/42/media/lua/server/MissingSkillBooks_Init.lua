require "MissingSkillBooks_Core"
require "MissingSkillBooks"
require "Items/MissingSkillBooks_Distributions"


function MissingSkillBooks.applySandboxSettings()

    MissingSkillBooks.applyRunningSettings()
    MissingSkillBooks.applyFitnessSettings()
    MissingSkillBooks.applyStrengthSettings()

    MissingSkillBooks.applyLightfootedSettings()
    MissingSkillBooks.applyNimbleSettings()
    MissingSkillBooks.applySneakingSettings()

    MissingSkillBooks.applyAxeSettings()
    MissingSkillBooks.applyLongBluntSettings()
    MissingSkillBooks.applyShortBluntSettings()
    MissingSkillBooks.applyShortBladeSettings()
    MissingSkillBooks.applySpearSettings()




    MissingSkillBooks.addRunningSkillBooks()
    MissingSkillBooks.addFitnessSkillBooks()
    MissingSkillBooks.addStrengthSkillBooks()

    MissingSkillBooks.addLightfootedSkillBooks()
    MissingSkillBooks.addNimbleSkillBooks()
    MissingSkillBooks.addSneakingSkillBooks()

    MissingSkillBooks.addAxeSkillBooks()
    MissingSkillBooks.addLongBluntSkillBooks()
    MissingSkillBooks.addShortBluntSkillBooks()
    MissingSkillBooks.addShortBladeSkillBooks()
    MissingSkillBooks.addSpearSkillBooks()


    ItemPickerJava:Parse()

end


Events.OnInitGlobalModData.Add(
    MissingSkillBooks.applySandboxSettings
)