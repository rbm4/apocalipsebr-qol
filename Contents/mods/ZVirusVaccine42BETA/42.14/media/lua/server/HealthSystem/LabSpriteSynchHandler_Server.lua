-- LabSpriteSynchHandler.lua
-- Funcoes para sincronizacao de sprites de mesas

local LabSpriteSynchHandler = {}

function LabSpriteSynchHandler.MorgueTableSwap(top, bottom, targetStatus)
    if not top or not bottom or not targetStatus then return end
    if not morgueTable then return end

    local topSprite = top:getSprite()
    if not topSprite then return end
    local sprite = topSprite:getName()
    local entry = morgueTable[sprite]
    if not entry then return end

    local newSpriteName = nil
    for spr, data in pairs(morgueTable) do
        if data.Status == targetStatus and data.Top == entry.Top and data.East == entry.East then
            newSpriteName = spr
            break
        end
    end

    if not newSpriteName or sprite == newSpriteName then return end

    local md = top:getModData()
    md.MorgueStatus = targetStatus
    
    top:setSpriteFromName(newSpriteName)
    
    local adj = morgueTable[newSpriteName] and morgueTable[newSpriteName].Adj
    if adj then
        bottom:setSpriteFromName(adj)
    end
    
    top:transmitModData()
    top:transmitUpdatedSpriteToClients()
    bottom:transmitUpdatedSpriteToClients()
    
    local topSquare = top:getSquare()
    local bottomSquare = bottom:getSquare()
    
    if topSquare then
        topSquare:RecalcAllWithNeighbours(true)
    end
    if bottomSquare then
        bottomSquare:RecalcAllWithNeighbours(true)
    end
end

return LabSpriteSynchHandler