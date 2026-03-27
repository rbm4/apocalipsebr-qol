require "EnergyRouting/Registry"

EnergyRouting = EnergyRouting or {}
EnergyRouting.API = EnergyRouting.API or {}

local API = EnergyRouting.API

API.VERSION = API.VERSION or "1.0.0"
API.version = API.version or API.VERSION

function API.RegisterProducer(data)
    return EnergyRouting.Registry.RegisterProducer(data)
end

function API.RegisterBattery(data)
    return EnergyRouting.Registry.RegisterBattery(data)
end

function API.UnregisterProducer(id)
    return EnergyRouting.Registry.UnregisterProducer(id)
end

function API.UnregisterBattery(id)
    return EnergyRouting.Registry.UnregisterBattery(id)
end

local function resolveProducerIdFromObject(producerObject)
    if type(producerObject) ~= "table" then
        return nil
    end
    local direct = producerObject.producerID or producerObject.producerId
    if direct then
        return tostring(direct)
    end
    local md = producerObject.getModData and producerObject:getModData() or nil
    if md and type(md) == "table" then
        if md.producerID or md.producerId then
            return tostring(md.producerID or md.producerId)
        end
        local energy = md.energy
        if type(energy) == "table" and (energy.producerID or energy.producerId) then
            return tostring(energy.producerID or energy.producerId)
        end
    end
    return nil
end

function EnergyRouting.ProcessFailure(producerObject, networkContext)
    local producerId = resolveProducerIdFromObject(producerObject)
    if not producerId then
        return false
    end
    local definition = EnergyRouting.Registry.GetProducer(producerId)
    if not definition or type(definition.OnFailure) ~= "function" then
        return false
    end
    definition.OnFailure(producerObject, networkContext)
    return true
end

API.ProcessFailure = EnergyRouting.ProcessFailure
