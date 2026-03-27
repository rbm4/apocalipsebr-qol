EnergyRouting.Controller = EnergyRouting.Controller or {}

function EnergyRouting.Controller.IsController(obj)
    if not obj then
        return false
    end
    -- Check ModData first
    if obj.getModData then
        local md = obj:getModData()
        if md and type(md.energyController) == "table" then
            return true
        end
    end
    
    -- Check Item Type (IsoWorldInventoryObject handling)
    local item = (obj.getItem and obj:getItem()) or (obj.getInventoryItem and obj:getInventoryItem()) or nil
    if item and item.getFullType and item:getFullType() == "EnergyRouting.EnergyController" then
        return true
    end
    
    -- Check Name
    if obj.getName then
        local name = obj:getName()
        if name == "Energy Controller" then
            return true
        end
    end
    
    -- Check Sprite (SAFE CHECK)
    if obj.getSprite then
        local sprite = obj:getSprite()
        if sprite and sprite.getName then
            local spriteName = sprite:getName()
            if spriteName and string.find(spriteName, "EnergyController", 1, true) then
                return true
            end
        end
    end
    return false
end

function EnergyRouting.Controller.EnsureController(obj)
    if not obj or not obj.getModData then
        return nil
    end
    local md = obj:getModData()
    if type(md.energyController) ~= "table" then
        local square = obj.getSquare and obj:getSquare() or nil
        local x = square and square:getX() or (obj.getX and obj:getX() or 0)
        local y = square and square:getY() or (obj.getY and obj:getY() or 0)
        local z = square and square:getZ() or (obj.getZ and obj:getZ() or 0)
        md.energyController = {
            networkId = "network_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(z),
            panels = {},
            batteries = {},
            priorityMode = "Balanced",
            mode = "Balanced",
            toggles = {},
        }
        if isServer and isServer() and obj.transmitModData then
            obj:transmitModData()
        end
    end
    return md.energyController
end
