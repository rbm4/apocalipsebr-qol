Drugzz = Drugzz or {}
Drugzz.CharacterTrait = Drugzz.CharacterTrait or {}
Drugzz.CharacterProfession = Drugzz.CharacterProfession or {}

local function registerTrait(key, id)
    if not Drugzz.CharacterTrait[key] then
        Drugzz.CharacterTrait[key] = CharacterTrait.register("zdrugzz:" .. id)
    end
end

registerTrait("STONER", "stoner")
registerTrait("CANNABIS_CONNOISSEUR", "cannabisconnoisseur")
registerTrait("PSYCHONAUT", "psychonaut")
registerTrait("COCAINE_DEPENDENT", "cocainedependent")
registerTrait("CRACK_DEPENDENT", "crackdependent")
registerTrait("METH_DEPENDENT", "methdependent")
registerTrait("CLUB_REGULAR", "clubregular")
registerTrait("PRESCRIPTION_DEPENDENT", "prescriptiondependent")

if not Drugzz.CharacterProfession.DRUG_DEALER then
    Drugzz.CharacterProfession.DRUG_DEALER = CharacterProfession.register("zdrugzz:drugdealer")
end
