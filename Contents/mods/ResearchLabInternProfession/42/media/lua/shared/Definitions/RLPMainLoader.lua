---=================================---
---  RESEARCH LAB PROFESSION MOD    ---
---    Main Loader & Orchestrator   ---
---=================================---

print("========================================")
print("RLP: Starting Research Lab Profession Mod")
print("========================================")

-- FASE 1: Inicialização do Namespace
print("RLP: Phase 1 - Initializing namespace...")
RLP = RLP or {}
RLP.CharacterTrait = RLP.CharacterTrait or {}  -- NÃO apagar se já existe
RLP.CharacterProfession = RLP.CharacterProfession or {}  -- NÃO apagar se já existe
RLP.Version = "1.0.0"

-- Verifica se já foi inicializado (evita recarregamento)
if RLP.Initialized then
    print("RLP: Already initialized, skipping...")
    return
end

print("RLP: Namespace initialized - Version " .. RLP.Version)

-- FASE 2: Verificação de Traits e Profissões
print("RLP: Phase 2 - Verifying traits and professions...")

-- Os registros são feitos no registries.lua (raiz do media/)
-- Aqui apenas verificamos se foram carregados corretamente
local function verifyRegistries()
    if not CharacterTrait or not CharacterProfession then
        print("RLP: ERROR - Base game CharacterTrait/CharacterProfession not available")
        return false
    end
    
    -- Verifica se RLP já foi inicializado pelo registries.lua
    if not RLP or not RLP.CharacterProfession or not RLP.CharacterTrait then
        print("RLP: ERROR - RLP namespace not initialized by registries.lua")
        return false
    end
    
    -- Verifica se os registros foram bem sucedidos
    if RLP.CharacterProfession.LAB_INTERN and RLP.CharacterTrait.AUTOPSY_SPECIALIST then
        print("RLP: - Traits and professions verified successfully")
        print("RLP: - Profession: Lab Intern (rlp:labintern)")
        print("RLP: - Trait: Autopsy Specialist (rlp:autopsyspecialist)")
        return true
    else
        print("RLP: ERROR - Traits/professions not found in registry")
        return false
    end
end

if not verifyRegistries() then
    print("RLP: CRITICAL ERROR - Cannot continue without registries")
    print("RLP: Make sure media/registries.lua is present and loaded")
    return
end

-- FASE 3: Carregamento de Definições
print("RLP: Phase 3 - Loading definitions...")

-- Clothing Definitions já estão carregadas automaticamente pelo jogo
-- Verificação simples para garantir que estão disponíveis
local function verifyClothingDefinitions()
    if ClothingSelectionDefinitions and ClothingSelectionDefinitions.labintern then
        print("RLP: Clothing definitions verified")
        return true
    else
        print("RLP: WARNING - Clothing definitions not found")
        return false
    end
end

verifyClothingDefinitions()

-- FASE 4: Verificação Final
print("RLP: Phase 4 - Final verification...")

local function performFinalChecks()
    local warnings = {}
    local errors = {}
    
    -- Verifica profissões
    if not RLP.CharacterProfession.LAB_INTERN then
        table.insert(errors, "Lab Intern profession not registered")
    end
    
    -- Verifica traits
    if not RLP.CharacterTrait.AUTOPSY_SPECIALIST then
        table.insert(errors, "Autopsy Specialist trait not registered")
    end
    
    -- Verifica clothing (não crítico)
    if not ClothingSelectionDefinitions or not ClothingSelectionDefinitions.labintern then
        table.insert(warnings, "Clothing definitions not loaded")
    end
    
    -- Verifica foraging system (será carregado depois)
    if not forageSystem then
        table.insert(warnings, "Foraging system not loaded yet (will be loaded on game start)")
    end
    
    return errors, warnings
end

local errors, warnings = performFinalChecks()

-- Exibe erros críticos
if #errors > 0 then
    print("RLP: CRITICAL ERRORS DETECTED:")
    for i, error in ipairs(errors) do
        print("RLP:   - " .. error)
    end
    print("========================================")
    return
end

-- Exibe warnings
if #warnings > 0 then
    print("RLP: WARNINGS:")
    for i, warning in ipairs(warnings) do
        print("RLP:   - " .. warning)
    end
end

-- Marca como inicializado
RLP.Initialized = true

print("RLP: All critical systems operational")
print("========================================")
print("RLP: Research Lab Profession Mod loaded successfully!")
print("========================================")

-- Função de utilidade para debug
RLP.Debug = function(message)
    if getDebug() then
        print("[RLP DEBUG] " .. tostring(message))
    end
end

-- Evento de confirmação
Events.OnGameBoot.Add(function()
    print("RLP: Game booted - Mod is active and ready")
end)