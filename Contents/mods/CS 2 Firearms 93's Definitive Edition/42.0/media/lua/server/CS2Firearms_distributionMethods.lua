require "Vehicles/VehicleDistributions"
require "Items/ProceduralDistributions"

CS2FirearmsDistribution = {}

function CS2FirearmsDistribution.cloneSpawn(baseItemName, spawnChanceModifier, newItemName)
    local script = ScriptManager.instance:getItem(baseItemName)
    local shortName = script:getName()
    local fullName  = script:getFullName()

    for _, lootTable in ipairs({ ProceduralDistributions and ProceduralDistributions.list, VehicleDistributions, SuburbsDistributions, BagsAndContainers }) do
        if type(lootTable) == "table" then
            for _, containerData in pairs(lootTable) do
                if type(containerData) == "table" and type(containerData.items) == "table" then
                    local insertions, i = {}, 1
                    while i <= #containerData.items do
                        if containerData.items[i] == shortName or containerData.items[i] == fullName then
                            table.insert(insertions, { pos = i + 2, name = newItemName, weight = (tonumber(containerData.items[i + 1]) or 0) * spawnChanceModifier })
                        end
                        i = i + 2
                    end
                    local offset = 0
                    for _, ins in ipairs(insertions) do
                        table.insert(containerData.items, ins.pos + offset, ins.name)
                        table.insert(containerData.items, ins.pos + offset + 1, ins.weight)
                        offset = offset + 2
                    end
                end
            end
        end
    end
end

function CS2FirearmsDistribution.batchCloneSpawn(baseItem, spawnChance, ...)
    for _, item in ipairs({ ... }) do
        CS2FirearmsDistribution.cloneSpawn(baseItem, spawnChance, item)
    end
end

function CS2FirearmsDistribution.purge(itemName)
    local script = ScriptManager.instance:getItem(itemName)
    local shortName = script and script:getName()
    local fullName  = script and script:getFullName()

    for _, lootTable in ipairs({ ProceduralDistributions and ProceduralDistributions.list, VehicleDistributions, SuburbsDistributions, BagsAndContainers }) do
        if type(lootTable) == "table" then
            for _, containerData in pairs(lootTable) do
                if type(containerData) == "table" and type(containerData.items) == "table" then
                    local i = #containerData.items - 1
                    while i >= 1 do
                        if containerData.items[i] == shortName or containerData.items[i] == fullName or containerData.items[i] == itemName then
                            table.remove(containerData.items, i + 1)
                            table.remove(containerData.items, i)
                        end
                        i = i - 2
                    end
                end
            end
        end
    end
end

function CS2FirearmsDistribution.batchPurge(...)
    for _, item in ipairs({ ... }) do
        CS2FirearmsDistribution.purge(item)
    end
end