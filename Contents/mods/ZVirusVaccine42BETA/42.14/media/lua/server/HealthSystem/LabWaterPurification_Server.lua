-- LabWaterPurification_Server.lua
-- Sistema de purificação de água por calor.
-- Só testei no microondas, não usei o fogão, mas deve funcionar também.

local LabWaterPurification = {}

-- CONFIGURAÇÃO
local MIN_GAME_TEMPERATURE = 1.6  -- Temperatura mínima para purificação
local PURIFICATION_TIME = 15      -- Minutos de jogo necessários
local SCAN_RADIUS = 5             -- Raio de busca ao redor do jogador


-- FUNÇÕES AUXILIARES
local function isFlaskWithWater(item)
    if not item or item:getType() ~= "LabFlask" then 
        return false 
    end

    if not item.getFluidContainer then 
        return false 
    end
    
    local fc = item:getFluidContainer()
    if not fc or not fc.getPrimaryFluid then 
        return false 
    end
    
    local primaryFluid = fc:getPrimaryFluid()
    if not primaryFluid or not primaryFluid.getFluidTypeString then
        return false
    end
	
    -- isso garante que não vamos transformar qualquer coisa em água purificada
    return primaryFluid:getFluidTypeString() == "Water" 
end

local function purifyFlask(item)
    if not item then return end
    
    local fc = item:getFluidContainer()
    if not fc then return end
    
    local capacity = fc:getCapacity()
    
    -- Esvazia o container
    if fc.empty then
        fc:empty()
    elseif fc.Empty then
        fc:Empty()
    end
    
    -- Adiciona água purificada
    if fc.addFluid then
        fc:addFluid("PurifiedWater", capacity)
    end
    
    -- Sincronização
    if item.syncItemFields then
        item:syncItemFields()
    end
    
    if item.syncItemModData then
        item:syncItemModData()
    end
end

-- Verifica se o container é uma fonte de calor válida
local function isHeatContainer(container)
    if not container or not container.getType then return false end

    local ctype = container:getType()
    if not ctype then return false end

    ctype = string.lower(ctype)

    return
        string.find(ctype, "stove") or
        string.find(ctype, "microwave") or
        string.find(ctype, "oven")
end


-- LÓGICA DE PURIFICAÇÃO
local function processFlask(item, containerObj)
    if not isFlaskWithWater(item) then
        -- Limpa estado se não é mais água
        local md = item:getModData()
        if md and md.PurificationEndTime then
            md.PurificationEndTime = nil
            if item.syncItemModData then 
                item:syncItemModData() 
            end
        end
        return
    end
    
    -- Obtém o ItemContainer do objeto
    local container = containerObj and containerObj.getContainer and containerObj:getContainer()
    if not container then return end
    
    -- Verifica temperatura
    local temperature = nil
    if container.getTemprature then
        temperature = container:getTemprature()
    elseif container.getTemperature then
        temperature = container:getTemperature()
    end
    
    if not temperature or temperature < MIN_GAME_TEMPERATURE then
        return
    end
    
    -- Gerencia tempo de purificação
    local md = item:getModData()
    if not md then return end
    
    local gameTime = getGameTime()
    if not gameTime then return end
    
    local nowMinutes = gameTime:getWorldAgeHours() * 60
    
    -- Inicia contagem
    if not md.PurificationEndTime then
        md.PurificationEndTime = nowMinutes + PURIFICATION_TIME
        if item.syncItemModData then 
            item:syncItemModData() 
        end
        return
    end
    
    -- Verifica se terminou
    if nowMinutes < md.PurificationEndTime then
        return
    end
    
    -- Purifica
    purifyFlask(item)
    md.PurificationEndTime = nil
    if item.syncItemModData then 
        item:syncItemModData() 
    end
end

-- SCAN DE CONTAINERS
local function scanContainers()
    local players = getOnlinePlayers()
    
    if not players or players:size() == 0 then
        local localPlayer = getSpecificPlayer(0)
        if localPlayer then
            players = { localPlayer }
        else
            return
        end
    end
    
    local playerCount = (type(players) == "table") and #players or players:size()
    local cell = getCell()
    local processed = {}

    for p = 0, playerCount - 1 do
        local player = (type(players) == "table") and players[p + 1] or players:get(p)
        
        if player then
            local px = math.floor(player:getX())
            local py = math.floor(player:getY())
            local pz = player:getZ()

            for x = px - SCAN_RADIUS, px + SCAN_RADIUS do
                for y = py - SCAN_RADIUS, py + SCAN_RADIUS do
                    local square = cell:getGridSquare(x, y, pz)
                    if square then
                        local objects = square:getObjects()
                        if objects then
                            for i = 0, objects:size() - 1 do
                                local obj = objects:get(i)
                                
                                if obj and not processed[obj] then
                                    processed[obj] = true
                                    
                                    -- Conta containers
                                    local containerCount = 0
                                    if obj.getContainerCount then
                                        containerCount = obj:getContainerCount()
                                    elseif obj.getContainer then
                                        if obj:getContainer() then
                                            containerCount = 1
                                        end
                                    end
                                    
                                    -- Processa cada container
                                    for idx = 0, containerCount - 1 do
                                        local container
                                        if containerCount == 1 and obj.getContainer then
                                            container = obj:getContainer()
                                        elseif obj.getContainerByIndex then
                                            container = obj:getContainerByIndex(idx)
                                        end
                                        
                                        -- Só processa containers que realmente geram calor
                                        if container and container.getItems and isHeatContainer(container) then
                                            local items = container:getItems()
                                            if items then
                                                for j = 0, items:size() - 1 do
                                                    local item = items:get(j)
                                                    if item and item:getType() == "LabFlask" then
                                                        processFlask(item, obj)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function LabWaterPurification.ProcessWaterPurification()
    if isMultiplayer() and not isServer() then 
        return 
    end
    
    scanContainers()
end

Events.EveryTenMinutes.Add(LabWaterPurification.ProcessWaterPurification)

return LabWaterPurification