require "Items/ProceduralDistributions"
require "Items/SuburbsDistributions"
require "Items/Distributions"

local MAGAZINE_TYPE = "IAmBruceLeeNow.KungFuMagazine"
local PRISON_DATA_KEY = "IABLN_PrisonLibraryMagazineRolls"

local PROCEDURAL_POOLS = {
    PoliceEvidence = 8,      -- Uncommon
    PawnShopCases = 8,       -- Uncommon
    GunStoreLiterature = 2,  -- Rare
}

local SURVIVOR_CACHE_POOLS = {
    "SurvivorCache1",
    "SurvivorCache2",
}

local function addWeightedItem(items, itemType, weight)
    if not items then return false end

    for index = 1, #items, 2 do
        if items[index] == itemType then return false end
    end

    table.insert(items, itemType)
    table.insert(items, weight)
    return true
end

local function installMagazineDistributions()
    for poolName, weight in pairs(PROCEDURAL_POOLS) do
        local pool = ProceduralDistributions.list[poolName]
        if pool then
            addWeightedItem(pool.items, MAGAZINE_TYPE, weight)
        end
    end

    for _, cacheName in ipairs(SURVIVOR_CACHE_POOLS) do
        local cache = SuburbsDistributions[cacheName]
        local crate = cache and cache.SurvivorCrate or nil
        if crate then
            addWeightedItem(crate.items, MAGAZINE_TYPE, 8) -- Uncommon
        end
    end
end

local function getBuilding(itemContainer)
    local parent = itemContainer and itemContainer:getParent() or nil
    local square = parent and parent:getSquare() or nil
    return square and square:getBuilding() or nil
end

local function getBuildingKey(building)
    local buildingDef = building and building:getDef() or nil
    return buildingDef and tostring(buildingDef:getIDString()) or nil
end

local function onFillContainer(roomName, containerType, itemContainer)
    if string.lower(tostring(roomName or "")) ~= "library"
        or string.lower(tostring(containerType or "")) ~= "shelves"
        or not itemContainer then
        return
    end

    local building = getBuilding(itemContainer)
    if not building or not building:getRandomRoom("prisoncells") then return end

    local key = getBuildingKey(building)
    if not key then return end

    local resolvedPrisons = ModData.getOrCreate(PRISON_DATA_KEY)
    if resolvedPrisons[key] then return end

    -- Resolve only once per prison, regardless of its number of library shelves.
    -- Status 1 means checked/no magazine; status 2 means the magazine spawned.
    local status = 1
    if ZombRand(100) < 10 and itemContainer:AddItem(MAGAZINE_TYPE) then
        status = 2
    end
    resolvedPrisons[key] = status

    if isServer() then ModData.transmit(PRISON_DATA_KEY) end
end

Events.OnPreDistributionMerge.Add(installMagazineDistributions)
Events.OnFillContainer.Add(onFillContainer)
