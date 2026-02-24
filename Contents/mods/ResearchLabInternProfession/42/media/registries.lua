----------------------
--- RLP REGISTRIES ---
----------------------

print("RLP: Loading registries.lua...")

-- Inicializa namespace
RLP = RLP or {}
RLP.CharacterTrait = RLP.CharacterTrait or {}
RLP.CharacterProfession = RLP.CharacterProfession or {}

-- ====================
-- CHARACTER PROFESSIONS
-- ====================

print("RLP: Registering professions...")

-- Verifica se já foi registrado (evita duplicação)
if not RLP.CharacterProfession.LAB_INTERN then
    
    -- Estagiário de laboratório com conhecimento em biologia e química
    RLP.CharacterProfession.LAB_INTERN = CharacterProfession.register("rlp:labintern")
else
    print("RLP: Lab Intern already registered, skipping...")
end

if RLP.CharacterProfession.LAB_INTERN then
    print("RLP: Profession registered - Lab Intern (rlp:labintern)")
else
    print("RLP: ERROR - Failed to register Lab Intern profession")
end

-- ====================
-- CHARACTER TRAITS
-- ====================

print("RLP: Registering traits...")

-- Verifica se já foi registrado (evita duplicação)
if not RLP.CharacterTrait.AUTOPSY_SPECIALIST then
 
    -- Especialista em autópsias com experiência em dissecação
    RLP.CharacterTrait.AUTOPSY_SPECIALIST = CharacterTrait.register("rlp:autopsyspecialist")
else
    print("RLP: Autopsy Specialist already registered, skipping...")
end

if RLP.CharacterTrait.AUTOPSY_SPECIALIST then
    print("RLP: Trait registered - Autopsy Specialist (rlp:autopsyspecialist)")
else
    print("RLP: ERROR - Failed to register Autopsy Specialist trait")
end

-- ====================
-- VERIFICAÇÕES FINAIS
-- ====================

local function verifyRegistrations()
    local success = true
    
    if not RLP.CharacterProfession.LAB_INTERN then
        print("RLP: CRITICAL - Lab Intern profession not registered")
        success = false
    end
    
    if not RLP.CharacterTrait.AUTOPSY_SPECIALIST then
        print("RLP: CRITICAL - Autopsy Specialist trait not registered")
        success = false
    end
    
    return success
end

if verifyRegistrations() then
    print("RLP: All registries loaded successfully")
else
    print("RLP: Registry verification failed")
end

print("RLP: Registries module complete")