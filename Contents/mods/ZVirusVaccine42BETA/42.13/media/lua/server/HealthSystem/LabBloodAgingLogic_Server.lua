-- LabBloodAgingLogic_Server.lua;
-- Sistema de envelhecimento do sangue;
-- Funcionando corretamente em MP e SP.

local LabBloodAgingLogic = {}

-- Configuração de vida do sangue (em minutos x10)
local bloodLife = {
    MatInfectedBlood = { Target = "MatTaintedBlood", Time = 3 }, -- 30 minutos
    CmpSyringeWithBlood = { Target = "CmpSyringeWithTaintedBlood", Time = 12 }, -- 2 horas
    CmpSyringeReusableWithBlood = { Target = "CmpSyringeReusableWithTaintedBlood", Time = 12 }, -- 2 horas
    --CmpTestTubeWithInfectedBlood = { Target = "CmpTestTubeWithTaintedBlood", Time = 12960 }, -- 90 dias
}

local function UpdateBloodAge(item, container, square)
    if not item then return end
    
    local obj = bloodLife[item:getType()]
    if not obj then return end
    
    local md = item:getModData()
    if md.BloodAge == nil then
        md.BloodAge = obj.Time
        if item.transmitModData then item:transmitModData() end
        return
    end
    
    md.BloodAge = md.BloodAge - 1
    if md.BloodAge > 0 then
        if item.transmitModData then item:transmitModData() end
        return
    end
    
    local targetType = "LabItems." .. obj.Target
    
    -- CASO 1: dentro de um container (funcionando corretamente)
    if type(container) ~= "string" and container then
        if container.DoRemoveItem and container.removeItemOnServer then
            container:DoRemoveItem(item)
            sendRemoveItemFromContainer(container, item)
            
            local newItem = container:AddItem(targetType)
            if newItem then
                sendAddItemToContainer(container, newItem)
            end
        end
        return
    end
    
    -- CASO 2: no chão
    if container == "floor" and square then
        local worldItem = item:getWorldItem()
        if not worldItem then return end

        local actualSquare = worldItem:getSquare()
        if not actualSquare then return end

        -- Cache informações ANTES de remover
        local oldType = item:getType()
        local absX = worldItem:getX()
        local absY = worldItem:getY()
        local absZ = worldItem:getZ()

        local fracX = absX - actualSquare:getX()
        local fracY = absY - actualSquare:getY()
        
        -- Captura os offsets do Extended 3D Placement
        local offX = worldItem.getOffX and worldItem:getOffX() or 0
        local offY = worldItem.getOffY and worldItem:getOffY() or 0
        local offZ = worldItem.getOffZ and worldItem:getOffZ() or 0
        
        -- Captura a rotação do item
        local rotX = item.getWorldXRotation and item:getWorldXRotation() or 0
        local rotY = item.getWorldYRotation and item:getWorldYRotation() or 0
        local rotZ = item.getWorldZRotation and item:getWorldZRotation() or 0

        -- Remove o item antigo
        actualSquare:transmitRemoveItemFromSquare(worldItem)
        worldItem:removeFromSquare()

        -- Cria o novo item com as coordenadas fracionárias corretas
        local newItem = actualSquare:AddWorldInventoryItem(targetType, fracX, fracY, absZ)
        
       -- Aplica os offsets do Extended 3D Placement ao novo item
        if newItem then
            local newWorldItem = newItem:getWorldItem()
            if newWorldItem then
                if newWorldItem.setOffX then
                    newWorldItem:setOffX(offX)
                end
                if newWorldItem.setOffY then
                    newWorldItem:setOffY(offY)
                end
                if newWorldItem.setOffZ then
                    newWorldItem:setOffZ(offZ)
                end

                -- Sincroniza as propriedades do novo item.
                if isServer() then
                    if newWorldItem.sync then
                        newWorldItem:sync()
                    end
                end
            end

            -- Aplica a rotação ao novo item
            if newItem.setWorldXRotation then
                newItem:setWorldXRotation(rotX)
            end
            if newItem.setWorldYRotation then
                newItem:setWorldYRotation(rotY)
            end
            if newItem.setWorldZRotation then
                newItem:setWorldZRotation(rotZ)
            end
        end

        -- Força atualização
        actualSquare:RecalcPropertiesIfNeeded()
        actualSquare:RecalcAllWithNeighboursMineOnly()

        return
    end
end

-- *** PERCORRE UM CONTAINER ***
local function LookForBloodInContainer(container)
    if not container then return end
    
    local items = container:getItems()
    if not items then return end
    
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if item:getCategory() == "Container" then
                local inner = item:getItemContainer()
                if inner then
                    LookForBloodInContainer(inner)
                end
            else
                UpdateBloodAge(item, container, nil)
            end
        end
    end
end

-- *** PERCORRE CONTAINERS DE MUNDO (ARMÁRIOS, GELADEIRAS, ETC.) ***
local function LookForBloodInWorldContainers(player, bloodRadius)
    if not player then return end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = player:getZ()

    local r = bloodRadius
    local cell = getCell()

    for x = px - r, px + r do
        for y = py - r, py + r do
            local square = cell:getGridSquare(x, y, pz)
            if square then
                local objects = square:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj then
                            local container = obj:getContainer()
                            if container then
                                LookForBloodInContainer(container)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- *** PERCORRE ITENS NO CHÃO ***
local function LookForBloodOnGround(player, bloodRadius)
    if not player then return end
    
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = player:getZ()
    
    local r = bloodRadius
    local cell = getCell()
    
    for x = px - r, px + r do
        for y = py - r, py + r do
            local square = cell:getGridSquare(x, y, pz)
            if square then
                local worldItems = square:getWorldObjects()
                if worldItems then
                    for i = 0, worldItems:size() - 1 do
                        local wo = worldItems:get(i)
                        local witem = wo and wo:getItem()
                        if witem then
                            UpdateBloodAge(witem, "floor", square)
                        end
                    end
                end
            end
        end
    end
end

-- *** FUNÇÃO PRINCIPAL (CHAMADA A CADA 10 MINUTOS) ***
function LabBloodAgingLogic.AdjustBloodCondition()

    -- AUTORIDADE
    if isMultiplayer() and not isServer() then
        return
    end

    -- CONFIGURAÇÃO DO SANDBOX
    local sandboxOptions = SandboxVars.ZombieVirusVaccineBETA or {}
    local bloodRadius = sandboxOptions.BloodAgingRadius
    if bloodRadius == nil then bloodRadius = 5 end

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

    for i = 0, playerCount - 1 do
        local player = (type(players) == "table") and players[i + 1] or players:get(i)
        if player then
            LookForBloodInContainer(player:getInventory())
            LookForBloodOnGround(player, bloodRadius)
            LookForBloodInWorldContainers(player, bloodRadius)
        end
    end
end


return LabBloodAgingLogic