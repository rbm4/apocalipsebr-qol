-- LabDistributions.lua
-- Lógica de distribuição de itens (SERVER/CLIENT)
-- As tabelas de dados estão em LabDistributions_Tables.lua

require "Items/ProceduralDistributions"
require "Items/Distribution_BagsAndContainers"
require "Vehicles/VehicleDistributions"

local T = require "Items/LabDistributions_Tables"

--==============================
-- SANDBOXVARS
--==============================

local _sb = SandboxVars.ZombieVirusVaccineBETA or {}

local function getLootMultiplier(option)
    local multipliers = {
        [1] = 0,
        [2] = 0.5,
        [3] = 1,
        [4] = 1.5
    }
    return multipliers[option] or 1
end

local enableWorldLoot     = _sb.EnableWorldLoot;     if enableWorldLoot     == nil then enableWorldLoot     = true  end
local enableLightPaints   = _sb.EnableLightPaints;   if enableLightPaints   == nil then enableLightPaints   = true  end
local expandChemicalsLoot = _sb.ExpandChemicalsLoot; if expandChemicalsLoot == nil then expandChemicalsLoot = false end 
local enableVehicleLoot   = _sb.EnableVehicleLoot;   if enableVehicleLoot   == nil then enableVehicleLoot   = true  end
local enableBagsLoot      = _sb.EnableBagsLoot;      if enableBagsLoot      == nil then enableBagsLoot      = true  end
local debugMode           = _sb.DebugMode;           if debugMode           == nil then debugMode           = false end

local chemicalsMultiplier      = getLootMultiplier(_sb.LootChemicals      or 3)
local syringesMultiplier       = getLootMultiplier(_sb.LootSyringes       or 3)
local equipmentBooksMultiplier = getLootMultiplier(_sb.LootEquipmentBooks or 3)
local virologyBooksMultiplier  = getLootMultiplier(_sb.LootVirologyBooks  or 3)
local virologyBooksSpawnMode   = _sb.VirologyBooksSpawnMode or 2

local function debugPrint(...)
    if debugMode == true then print("[ZVirusVaccine]", ...) end
end

--[[
print("========================================")
print("[ZVirusVaccine] READING RAW SANDBOX SETTINGS...")
print("========================================")
print("World Loot:", SandboxVars.ZombieVirusVaccineBETA.EnableWorldLoot)
print("Light Paints:", SandboxVars.ZombieVirusVaccineBETA.EnableLightPaints)
print("Expand Chemicals Loot:", SandboxVars.ZombieVirusVaccineBETA.ExpandChemicalsLoot)
print("Vehicle Loot:", SandboxVars.ZombieVirusVaccineBETA.EnableVehicleLoot)
print("Bags Loot:", SandboxVars.ZombieVirusVaccineBETA.EnableBagsLoot)
print("Debug Mode:", SandboxVars.ZombieVirusVaccineBETA.DebugMode)
print("Chemicals Multiplier:", SandboxVars.ZombieVirusVaccineBETA.LootChemicals)
print("Syringes Multiplier:", SandboxVars.ZombieVirusVaccineBETA.LootSyringes)
print("Equipment Books Multiplier:", SandboxVars.ZombieVirusVaccineBETA.LootEquipmentBooks)
print("Virology Books Multiplier:", SandboxVars.ZombieVirusVaccineBETA.LootVirologyBooks)
print("Virology Books Spawn Mode:", SandboxVars.ZombieVirusVaccineBETA.VirologyBooksSpawnMode)
print("========================================")
print("[ZVirusVaccine] READING LOCAL SANDBOX SETTINGS:")
print("========================================")
print("World Loot:", enableWorldLoot)
print("Light Paints:", enableLightPaints)
print("Expand Chemicals Loot:", expandChemicalsLoot)
print("Vehicle Loot:", enableVehicleLoot)
print("Bags Loot:", enableBagsLoot)
print("Debug Mode:", debugMode)
print("Chemicals Multiplier:", chemicalsMultiplier)
print("Syringes Multiplier:", syringesMultiplier)
print("Equipment Books Multiplier:", equipmentBooksMultiplier)
print("Virology Books Multiplier:", virologyBooksMultiplier)
print("Virology Books Spawn Mode:", virologyBooksSpawnMode)
print("========================================")
]]
--==============================
-- FUNÇÕES AUXILIARES
--==============================

local function addCategoryToTables(tables, items, multiplier)
    if not enableWorldLoot or multiplier <= 0 then return end

    for tableName, baseChance in pairs(tables) do
        local dist = ProceduralDistributions.list[tableName]
        if dist and dist.items then
            local finalChance = baseChance * multiplier
            for _, item in ipairs(items) do
                table.insert(dist.items, item)
                table.insert(dist.items, finalChance)
            end
        end
    end
end

local function addBagItemWithMultiplier(bagType, itemName, baseChance, multiplier)
    if not (enableWorldLoot and enableBagsLoot and multiplier > 0) then return end

    local itemList = BagsAndContainers[bagType]
    if not itemList then
        print("[ZVirusVaccine][ERROR] Bag item list not found:", bagType)
        return
    end

    local adjustedChance = baseChance * multiplier
    table.insert(itemList, itemName)
    table.insert(itemList, adjustedChance)
end

local function applyBagCategory(bagTable, items, multiplier)
    if not (enableWorldLoot and enableBagsLoot and multiplier > 0) then return end

    for bagType, baseChance in pairs(bagTable) do
        for _, item in ipairs(items) do
            addBagItemWithMultiplier(bagType, item, baseChance, multiplier)
        end
    end
end

local function applyBagIndividualItems(bagTable, itemTable, multiplier)
    if not (enableWorldLoot and enableBagsLoot and multiplier > 0) then return end

    for bagType, _ in pairs(bagTable) do
        for _, entry in ipairs(itemTable) do
            addBagItemWithMultiplier(bagType, entry.item, entry.chance, multiplier)
        end
    end
end

local function addVehicleItemWithMultiplier(containerType, itemName, baseChance, multiplier)
    if not (enableWorldLoot and enableVehicleLoot and multiplier > 0) then return end

    local containerList = VehicleDistributions[containerType]
    if not containerList or not containerList.items then
        print("[ZVirusVaccine][ERROR] Vehicle container not found:", containerType)
        return
    end

    local adjustedChance = baseChance * multiplier
    table.insert(containerList.items, itemName)
    table.insert(containerList.items, adjustedChance)
end

local function applyVehicleCategory(containerTable, items, multiplier)
    if not (enableWorldLoot and enableVehicleLoot and multiplier > 0) then return end

    for container, baseChance in pairs(containerTable) do
        for _, item in ipairs(items) do
            addVehicleItemWithMultiplier(container, item, baseChance, multiplier)
        end
    end
end

--==============================
-- APLICAÇÃO DO LOOT PADRÃO
--==============================

addCategoryToTables(T.chemicalsTables,       T.chemicalItems,                 chemicalsMultiplier)
addCategoryToTables(T.syringesTables,        {"LabItems.LabSyringe"},         syringesMultiplier)
addCategoryToTables(T.syringePackTables,     {"LabItems.LabSyringePack"},     syringesMultiplier)
addCategoryToTables(T.syringesTables,        {"LabItems.CmpAlbuminPills"},    syringesMultiplier)
addCategoryToTables(T.chlorineTabletsTables, {"LabItems.CmpChlorineTablets"}, chemicalsMultiplier)
addCategoryToTables(T.equipmentBookTables,   T.labEquipmentBooks,             equipmentBooksMultiplier)
addCategoryToTables(T.chemistryCourseTables, {"LabBooks.BkChemistryCourse"},  virologyBooksMultiplier)
addCategoryToTables(T.virologyBooksTables,   T.labVirologybooks,              virologyBooksMultiplier)

-- spawn de livros de virologia (modo sandbox)
if enableWorldLoot == true and virologyBooksSpawnMode == 1 then
    debugPrint("Virology Books Spawn Mode: EXPANDED")
    addCategoryToTables(T.virologyExpandedTables, T.bagVirologyBooks, virologyBooksMultiplier)
elseif enableWorldLoot == true and virologyBooksSpawnMode == 3 then
    debugPrint("Virology Books Spawn Mode: FULL SPAWN")
    addCategoryToTables(T.virologyBooksFullTables, T.bagVirologyBooks, virologyBooksMultiplier)
else
    debugPrint("Virology Books is in standard spawn mode. Skipping additional spawn points...")
end

-- spawn de revistas de tintas coloridas
if enableWorldLoot == true and enableLightPaints then
    if debugMode == true then print("[ZVirusVaccine] Adding spawn points for Paint Lights Magazine...") end
    addCategoryToTables(T.paintLightsTables, {"LabBooks.LabPaintLightsMag"}, equipmentBooksMultiplier)
else
    debugPrint("Paint Lights Magazine spawn points disabled. Players won't be able to craft colored light bulbs.")
end

-- spawn expandido de produtos químicos
if enableWorldLoot == true and expandChemicalsLoot then
    debugPrint("Adding additional spawn points for Lab Chemicals...")
    addCategoryToTables(T.expandedChemicalsTables, T.chemicalItems, chemicalsMultiplier)
else
    debugPrint("Additional Lab Chemicals spawn points DISABLED. Skipping additional spawn points...")
end

-- spawn em veículos
if enableWorldLoot == true and enableVehicleLoot then
    debugPrint("Adding spawn points for Vehicle Distributions...")
    applyVehicleCategory(T.vehicleEquipmentContainers, T.labEquipmentBooks, equipmentBooksMultiplier)
    applyVehicleCategory(T.medicalVehicleContainers,   T.medicalItems,      syringesMultiplier)

    if enableLightPaints then
        applyVehicleCategory(T.vehicleEquipmentContainers, {"LabBooks.LabPaintLightsMag"}, equipmentBooksMultiplier)
    end

    if virologyBooksSpawnMode == 3 or virologyBooksSpawnMode == 1 then
        applyVehicleCategory(T.medicalVehicleContainers, T.bagVirologyBooks, virologyBooksMultiplier)
        debugPrint("Virology Books Spawning in vehicles...")
    end

    if expandChemicalsLoot then
        applyVehicleCategory(T.vehicleChemicalContainers, T.chemicalItems, chemicalsMultiplier)
        debugPrint("Additional Lab Chemicals spawning in vehicles...")
    end
else
    debugPrint("Vehicle Distributions spawn points DISABLED. Skipping additional spawn points...")
end

-- spawn em mochilas de sobreviventes
if enableWorldLoot == true and enableBagsLoot then
    applyBagCategory(T.bagEquipmentBookTables, T.labEquipmentBooks, equipmentBooksMultiplier)
    applyBagIndividualItems({ SurvivorItems = true }, T.bagChemicalItems, chemicalsMultiplier)
    debugPrint("Adding spawn points for survivor Bags...")

    if virologyBooksSpawnMode == 3 then
        applyBagCategory(T.bagVirologyTables, T.bagVirologyBooks, virologyBooksMultiplier)
        debugPrint("Virology Books Spawning in survivor Bags...")
    end
else
    debugPrint("Bags spawn points DISABLED. Skipping additional spawn points...")
end

--==============================================
-- REMOÇÃO DE ITENS EM ZONAS RESTRITAS
--==============================================

T.restrictedZones[1].items = T.labVirologybooks

local function buildItemLookup(itemList)
    local lookup = {}
    for _, item in ipairs(itemList) do
        lookup[item] = true
    end
    return lookup
end

for _, zone in ipairs(T.restrictedZones) do
    zone.itemLookup = buildItemLookup(zone.items)
end

local function removeRestrictedItems(container, zone)
    if not container then return end

    local items = container:getItems()
    local removedCount = 0

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        local fullType = item:getFullType()

        if zone.itemLookup[fullType] then
            debugPrint("[removeRestrictedItems] Removing item:", fullType)
            container:Remove(item)
            sendRemoveItemFromContainer(container, item)
            removedCount = removedCount + 1
        end
    end

    if removedCount > 0 then
        debugPrint("[removeRestrictedItems] Zone:", zone.name,
            "| Container:", container:getType(),
            "| Removed:", removedCount)
    end
end

local function restrictedZoneLootFilter(roomType, containerType, container)
    if not container then return end
    if not instanceof(container, "ItemContainer") then return end

    local parent = container:getParent()
    if not parent then return end

    local square = parent:getSquare()
    if not square then return end

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    for _, zone in ipairs(T.restrictedZones) do
        if z == zone.z and
           x >= zone.xMin and x <= zone.xMax and
           y >= zone.yMin and y <= zone.yMax then
            debugPrint("[restrictedZoneLootFilter] Triggered in zone:", zone.name)
            removeRestrictedItems(container, zone)
        end
    end
end

Events.OnFillContainer.Add(restrictedZoneLootFilter)