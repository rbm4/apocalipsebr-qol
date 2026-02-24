------------------------------------------
--- INTEGRAÇÃO COM SISTEMA DE FORAGING ---
------------------------------------------

require "Foraging/forageDefinitions"

--- Inicializa as habilidades de foraging para RLP
--- Adiciona bônus de foraging para traits e profissões do mod

local function initRLPForageSkills()
    -- Verifica se o sistema de foraging está disponível
    if not forageSystem or not forageSystem.forageSkillDefinitions then
        return
    end
    
    -- ====================
    -- AUTOPSY SPECIALIST TRAIT
    -- ====================
    -- Expertise em encontrar suprimentos médicos e plantas medicinais
    forageSystem.forageSkillDefinitions.AutopsySpecialist = {
        name = "rlp:autopsyspecialist",
        type = "trait",
        visionBonus = 2,              -- Boa percepção visual (treinamento laboratorial)
        weatherEffect = -1,            -- Afetado pelo clima (trabalha indoor)
        darknessEffect = -1,           -- Afetado pela escuridão (acostumado a laboratório)
        specialisations = {
            ["Medical"] = 45,         -- Consegue encontrar suprimentos médicos com mais facilidade
            ["MedicinalPlants"] = 20, -- Consegue identificar plantas medicinais com mais facilidade
            ["WildPlants"] = 10,      -- Consegue identificar plantas selvagens com mais facilidade
            ["Berries"] = 10,         -- Consegue identificar frutinhas com mais facilidade
            ["Mushrooms"] = 10,       -- Consegue identificar cogumelos com mais facilidade
            ["Insects"] = 5,          -- Consegue identificar insetos com mais facilidade
            ["Junk"] = 5,             -- Consegue encontrar sucata útil com mais facilidade
        },
    }
end

	-- ====================
	-- PROFESSIONS
	-- ====================
	
	-- Lab Intern Profession: MOVIDO PARA A SKILL
	-- Expertise significativa em itens médicos e científicos
	--[[forageSystem.forageSkillDefinitions.LabIntern = {
		name = "rlp:labintern",
		type = "occupation",
		visionBonus = 2,           -- Boa percepção (treinamento científico)
		weatherEffect = 0,            -- Indoor worker, não acostumado a outdoor
		darknessEffect = 0,           -- +5% penalidade na escuridão, mas melhor que average
		specialisations = {
			["Medical"] = 45,         -- +45% chance de encontrar suprimentos médicos
			["MedicinalPlants"] = 20, -- +20% chance de identificar plantas medicinais
			["Trash"] = 15,           -- +15% chance de encontrar materiais úteis no lixo
			["Junk"] = 15,            -- +15% chance de encontrar sucata útil
		},
	}]]


-- Inicializa quando o jogo começa (garante que foraging system já está carregado)
Events.OnGameStart.Add(initRLPForageSkills)

-- Fallback: tenta inicializar imediatamente se o sistema já estiver disponível
if forageSystem and forageSystem.forageSkillDefinitions then
    initRLPForageSkills()
end