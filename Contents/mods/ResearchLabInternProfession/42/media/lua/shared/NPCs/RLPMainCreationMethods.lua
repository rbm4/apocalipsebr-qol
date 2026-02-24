----------------------------------------------
---- RLP CHARACTER INITIALIZATIONS        ----
----------------------------------------------

RLPCharacterDetails = RLPCharacterDetails or {}

--- Inicializa o personagem Lab Intern com itens iniciais
RLPCharacterDetails.DoNewCharacterInitializations = function(arg1, arg2)
    -- Detecta o player corretamente para ambos eventos
    local player = arg2
    if not player or not player.getDescriptor then
        player = arg1
    end
    
    if not player then
        return
    end
    
    -- Evita execução em client (multiplayer)
    if isClient() then
        return
    end
    
    local modData = player:getModData()
    
    -- Evita inicialização duplicada
    if modData.RLPInitialized then
        return
    end
    
    -- Verifica se o personagem tem profissão válida
    if not player:getDescriptor():getCharacterProfession() then
        return
    end
    
    local survivorDescription = player:getDescriptor()
    
    -- ====================
    -- LAB INTERN PROFESSION
    -- ====================
    if survivorDescription:isCharacterProfession(RLP.CharacterProfession.LAB_INTERN) then
        local inventory = player:getInventory()
        
        -- Procura ou cria a mochila
        local bag = inventory:FindAndReturn("Base.Bag_Satchel")
        if not bag then
            bag = inventory:AddItem("Base.Bag_Satchel")
            player:setClothingItem_Back(bag)
        end
        
        -- Adiciona livros de laboratório dentro da mochila
        bag:getItemContainer():AddItem("LabBooks.BkLaboratoryEquipment1")
        bag:getItemContainer():AddItem("LabBooks.BkLaboratoryEquipment2")
        bag:getItemContainer():AddItem("LabBooks.BkLaboratoryEquipment3")
        bag:getItemContainer():AddItem("LabBooks.BkVirologyCourses1")
        bag:getItemContainer():AddItem("LabBooks.BkVirologyCourses2")
        bag:getItemContainer():AddItem("LabBooks.BkChemistryCourse")
        
        -- Adiciona páginas do diário dentro da mochila
        bag:getItemContainer():AddItem("ProfessionItems.DiaryPage1")
        bag:getItemContainer():AddItem("ProfessionItems.DiaryPage2")
        bag:getItemContainer():AddItem("ProfessionItems.DiaryPage3")
        bag:getItemContainer():AddItem("ProfessionItems.DiaryPage4")
        bag:getItemContainer():AddItem("ProfessionItems.DiaryPage5")
        bag:getItemContainer():AddItem("ProfessionItems.DiaryPage6")
        bag:getItemContainer():AddItem("Base.Pencil")
        bag:getItemContainer():AddItem("LabItems.LabFlask")
        bag:getItemContainer():AddItem("LabItems.LabFlask")
        bag:getItemContainer():AddItem("LabItems.LabTestTube")
        bag:getItemContainer():AddItem("LabItems.LabTestTube")
        bag:getItemContainer():AddItem("LabItems.LabTestTube")
        bag:getItemContainer():AddItem("LabItems.LabTestTube")

        -- Adiciona kit de primeiros socorros preenchido
        local firstAidKit = inventory:AddItem("FirstAidKit_NewPro")
        if firstAidKit then
            firstAidKit:getItemContainer():AddItem("Base.Tweezers")
            firstAidKit:getItemContainer():AddItem("Base.Scalpel")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholBandage")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholBandage")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholBandage")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholBandage")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholBandage")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholedCottonBalls")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholedCottonBalls")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholedCottonBalls")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholedCottonBalls")
            firstAidKit:getItemContainer():AddItem("Base.AlcoholedCottonBalls")
            firstAidKit:getItemContainer():AddItem("LabItems.LabSyringeReusable")
        end
    end
    
    -- ====================
    -- AUTOPSY SPECIALIST TRAIT
    -- ====================
    if player:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST) then
        if modData.RLPAutopsySpecialist == nil then
            modData.RLPAutopsySpecialist = true
        end
    end
    
    -- Marca como inicializado
    modData.RLPInitialized = true
end

-- Registra nos eventos de criação de personagem
Events.OnNewGame.Add(RLPCharacterDetails.DoNewCharacterInitializations)
Events.OnGameStart.Add(RLPCharacterDetails.DoNewCharacterInitializations)