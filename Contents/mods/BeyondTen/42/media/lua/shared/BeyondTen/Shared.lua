BeyondTen = BeyondTen or {}

local BT = BeyondTen

BT.VERSION = "1.1.1"
BT.API_VERSION = 1
BT.GAME_BUILD = 42
BT.MODULE = "BeyondTen"
BT.DATA_KEY = "BeyondTen"
BT.NATIVE_MAX_LEVEL = 10
BT.MAX_LEVEL = 15
BT.RESERVOIR_LEVEL = 9
BT._bonusProviders = BT._bonusProviders or {}
BT._actionPerks = BT._actionPerks or {}
BT._trainableOverrides = BT._trainableOverrides or {}
BT._catalog = BT._catalog or { size = -1, trainable = {}, byId = {} }

function BT.IsFinite(value)
    value = tonumber(value)
    return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge
end

function BT.Clamp(value, minimum, maximum)
    value = tonumber(value)
    if not BT.IsFinite(value) then value = minimum end
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function BT.Round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

function BT.ResolvePerk(perkOrId)
    if not perkOrId then return nil end
    local id = perkOrId
    if type(perkOrId) ~= "string" then
        local ok, resolvedId = pcall(function() return perkOrId:getId() end)
        if not ok or type(resolvedId) ~= "string" then return nil end
        id = resolvedId
    end

    local perk = Perks.FromString(id)
    if not perk or perk == Perks.MAX or perk == Perks.None then return nil end
    return perk
end

function BT.RefreshPerkCatalog(force)
    local size = PerkFactory.PerkList:size()
    if not force and BT._catalog.size == size then return BT._catalog end

    local all = {}
    local hasChildren = {}
    for index = 0, size - 1 do
        local perk = PerkFactory.PerkList:get(index)
        if perk and perk ~= Perks.None and perk ~= Perks.MAX then
            all[#all + 1] = perk
            local parent = perk:getParent()
            if parent and parent ~= Perks.None then
                hasChildren[parent:getId()] = true
            end
        end
    end

    local trainable = {}
    local byId = {}
    for _, perk in ipairs(all) do
        local id = perk:getId()
        if (not hasChildren[id] or BT._trainableOverrides[id]) and (tonumber(perk:getXp10()) or 0) > 0 then
            trainable[#trainable + 1] = perk
            byId[id] = perk
        end
    end

    BT._catalog = { size = size, trainable = trainable, byId = byId }
    return BT._catalog
end

function BT.GetTrainablePerks()
    return BT.RefreshPerkCatalog(false).trainable
end

function BT.IsTrainablePerk(perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    return perk ~= nil and BT.RefreshPerkCatalog(false).byId[perk:getId()] == perk
end

function BT.RegisterTrainablePerk(perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    if not perk or (tonumber(perk:getXp10()) or 0) <= 0 then return false end
    BT._trainableOverrides[perk:getId()] = true
    BT.RefreshPerkCatalog(true)
    return true
end

function BT.GetData(character, create)
    if not character then return nil end
    local modData = character:getModData()
    local data = modData[BT.DATA_KEY]
    if type(data) ~= "table" then
        if not create then return nil end
        data = { version = 1, perks = {} }
        modData[BT.DATA_KEY] = data
    end
    if type(data.perks) ~= "table" then
        if not create then return nil end
        data.perks = {}
    end
    data.version = 1
    return data
end

function BT.GetPerkRecord(character, perkOrId, create)
    local perk = BT.ResolvePerk(perkOrId)
    if not perk then return nil end
    local data = BT.GetData(character, create)
    if not data then return nil end

    local id = perk:getId()
    local record = data.perks[id]
    if type(record) == "number" then
        record = { xp = math.max(0, record) }
        data.perks[id] = record
    elseif type(record) ~= "table" then
        if not create then return nil end
        record = { xp = 0 }
        data.perks[id] = record
    end
    if not BT.IsFinite(record.xp) then record.xp = 0 end
    record.xp = math.max(0, tonumber(record.xp) or 0)
    return record
end

function BT.GetStoredXP(character, perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    if not character or not perk then return 0 end

    -- Dedicated servers install a server-authoritative backing store here. Player ModData
    -- remains the persistence/client mirror, but is not trusted as authority.
    if type(BT._storedXPReader) == "function" then
        local value = BT._storedXPReader(character, perk)
        if value ~= nil then
            if not BT.IsFinite(value) then return 0 end
            return math.max(0, tonumber(value) or 0)
        end
    end

    local record = BT.GetPerkRecord(character, perk, false)
    return record and (tonumber(record.xp) or 0) or 0
end

function BT.GetNativeLevel(character, perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    if not character or not perk then return 0 end
    return tonumber(character:getPerkLevel(perk)) or 0
end

function BT.GetMasteryCost(perkOrId, targetLevel)
    local perk = BT.ResolvePerk(perkOrId)
    targetLevel = math.floor(tonumber(targetLevel) or 0)
    if not perk or targetLevel < 11 or targetLevel > BT.MAX_LEVEL then return 0 end

    local xp9 = tonumber(perk:getXp9()) or 0
    local xp10 = tonumber(perk:getXp10()) or 0
    local step = xp10 - xp9
    if step <= 0 then step = math.max(1, BT.Round(xp10 * 0.15)) end
    return math.max(1, BT.Round(xp10 + step * (targetLevel - BT.NATIVE_MAX_LEVEL)))
end

function BT.GetTotalMasteryCost(perkOrId, targetLevel)
    targetLevel = math.floor(tonumber(targetLevel) or BT.NATIVE_MAX_LEVEL)
    if targetLevel <= BT.NATIVE_MAX_LEVEL then return 0 end
    targetLevel = math.min(targetLevel, BT.MAX_LEVEL)
    local total = 0
    for level = 11, targetLevel do
        total = total + BT.GetMasteryCost(perkOrId, level)
    end
    return total
end

function BT.GetMasteryState(character, perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    if not character or not perk then return BT.NATIVE_MAX_LEVEL, 0, 0 end

    local remaining = BT.GetStoredXP(character, perk)
    local level = BT.NATIVE_MAX_LEVEL
    for targetLevel = 11, BT.MAX_LEVEL do
        local cost = BT.GetMasteryCost(perk, targetLevel)
        if remaining + 0.0001 < cost then return level, remaining, cost end
        remaining = remaining - cost
        level = targetLevel
    end
    return BT.MAX_LEVEL, 0, 0
end

function BT.GetEffectiveLevel(character, perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    if not character or not perk then return 0 end
    local nativeLevel = BT.GetNativeLevel(character, perk)
    if nativeLevel < BT.NATIVE_MAX_LEVEL then return nativeLevel end
    return BT.GetMasteryState(character, perk)
end

function BT.GetMasteryRanks(character, perkOrId)
    return math.max(0, BT.GetEffectiveLevel(character, perkOrId) - BT.NATIVE_MAX_LEVEL)
end

function BT.GetLevelProgress(character, perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    if not character or not perk then return 0, 0, 0 end
    local nativeLevel = BT.GetNativeLevel(character, perk)
    if nativeLevel < BT.NATIVE_MAX_LEVEL then
        local required = tonumber(perk:getXpForLevel(nativeLevel + 1)) or 0
        local previous = tonumber(perk:getTotalXpForLevel(nativeLevel)) or 0
        local current = (tonumber(character:getXp():getXP(perk)) or 0) - previous
        return nativeLevel, BT.Clamp(current, 0, math.max(0, required)), math.max(0, required)
    end
    return BT.GetMasteryState(character, perk)
end

function BT.SetStoredXP(character, perkOrId, value)
    local perk = BT.ResolvePerk(perkOrId)
    if not character or not perk or not BT.IsTrainablePerk(perk) then return 0, 0, 0 end
    local oldLevel = BT.GetEffectiveLevel(character, perk)
    local maximum = BT.GetTotalMasteryCost(perk, BT.MAX_LEVEL)
    local stored = BT.Clamp(value, 0, maximum)
    if type(BT._storedXPWriter) == "function" then
        BT._storedXPWriter(character, perk, stored)
    else
        local record = BT.GetPerkRecord(character, perk, true)
        record.xp = stored
    end
    local newLevel = BT.GetEffectiveLevel(character, perk)
    return stored, oldLevel, newLevel
end

function BT.AddStoredXP(character, perkOrId, amount)
    local perk = BT.ResolvePerk(perkOrId)
    if not character or not perk or BT.GetNativeLevel(character, perk) < BT.NATIVE_MAX_LEVEL then
        return 0, 0, 0, 0
    end
    local before = BT.GetStoredXP(character, perk)
    amount = tonumber(amount)
    if not BT.IsFinite(amount) then
        local level = BT.GetEffectiveLevel(character, perk)
        return 0, level, level, before
    end
    local value, oldLevel, newLevel = BT.SetStoredXP(character, perk, before + amount)
    return value - before, oldLevel, newLevel, value
end

function BT.GetReservoirXP(perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    return perk and (tonumber(perk:getTotalXpForLevel(BT.RESERVOIR_LEVEL)) or 0) or 0
end

function BT.GetNativeCapXP(perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    return perk and (tonumber(perk:getTotalXpForLevel(BT.NATIVE_MAX_LEVEL)) or 0) or 0
end

function BT.RegisterBonusProvider(perkOrId, provider)
    local perk = BT.ResolvePerk(perkOrId)
    if not perk or type(provider) ~= "function" then return false end
    BT._bonusProviders[perk:getId()] = provider
    return true
end

function BT.GetBonus(character, perkOrId, context)
    local perk = BT.ResolvePerk(perkOrId)
    if not perk then return 0 end
    local provider = BT._bonusProviders[perk:getId()]
    if provider then
        local ok, value = pcall(provider, character, perk, BT.GetMasteryRanks(character, perk), context)
        if ok and BT.IsFinite(value) then return tonumber(value) end
    end
    return BT.GetMasteryRanks(character, perk)
end

function BT.RegisterActionPerk(actionType, perkOrId)
    local perk = BT.ResolvePerk(perkOrId)
    if type(actionType) ~= "string" or not perk then return false end
    BT._actionPerks[actionType] = perk
    return true
end

function BT.ExportXP(character)
    if type(BT._storedXPExporter) == "function" then
        local values = BT._storedXPExporter(character)
        if type(values) == "table" then return values end
    end

    local result = {}
    local data = BT.GetData(character, false)
    if not data then return result end
    for id, record in pairs(data.perks) do
        local value = type(record) == "table" and tonumber(record.xp) or tonumber(record)
        if value ~= nil then
            if not BT.IsFinite(value) then value = 0 end
            result[id] = math.max(0, value)
        end
    end
    return result
end

function BT.ImportXP(character, values, replace)
    if not character or type(values) ~= "table" then return end
    if replace then
        if type(BT._storedXPClearer) == "function" then
            BT._storedXPClearer(character)
        else
            BT.GetData(character, true).perks = {}
        end
    end
    for id, value in pairs(values) do
        local perk = BT.ResolvePerk(id)
        if perk and BT.IsTrainablePerk(perk) and BT.IsFinite(value) then
            BT.SetStoredXP(character, perk, tonumber(value) or 0)
        end
    end
end

if not BT._sharedBootLogged then
    BT._sharedBootLogged = true
    print("[BeyondTen/B42] shared boot OK v" .. BT.VERSION)
end
