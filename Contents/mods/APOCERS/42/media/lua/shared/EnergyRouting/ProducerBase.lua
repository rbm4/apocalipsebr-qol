EnergyRouting = EnergyRouting or {}
EnergyRouting.ProducerBase = EnergyRouting.ProducerBase or {}

local ProducerBase = EnergyRouting.ProducerBase

function ProducerBase.New(definition)
    local def = {}
    if type(definition) == "table" then
        for key, value in pairs(definition) do
            def[key] = value
        end
    end
    return def
end

function ProducerBase.WithDefaults(definition, defaults)
    local def = ProducerBase.New(defaults)
    if type(definition) == "table" then
        for key, value in pairs(definition) do
            def[key] = value
        end
    end
    return def
end
