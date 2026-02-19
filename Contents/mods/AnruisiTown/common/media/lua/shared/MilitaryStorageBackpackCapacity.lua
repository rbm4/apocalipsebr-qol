local function getScriptName()
    return "Base.MilitaryStorageBackpack"
end

local function getCapacity()
    return 28
end

local function GetNewEffectiveCapacity(ori)
    local function New_GetEffectiveCapacity(self, player)
        local raw_value = ori(self, player)
        local item = self:getContainingItem()
        if item == nil then
            return raw_value
        end
        if item:getFullType() ~= getScriptName() then
            return raw_value
        end
        local cap = getCapacity()
        if player then
            if player:hasTrait(CharacterTrait.ORGANIZED) then
                cap = cap * 1.3
            elseif player:hasTrait(CharacterTrait.DISORGANIZED) then
                cap = cap * 0.7
            end
        end
        return raw_value + cap
    end
    return New_GetEffectiveCapacity
end

local function GetNewHasRoomFor(ori)
    local function New_HasRoomFor(self, player, arg1)
        local item = self:getContainingItem()
        if item == nil then
            return ori(self, player, arg1)
        end
        if instanceof(arg1, 'InventoryItem') then
            arg1 = arg1:getUnequippedWeight()
        end
        local content = self:getContentsWeight()
        local total_capacity = self:getEffectiveCapacity(player)
        return arg1 + content <= total_capacity
    end

    return New_HasRoomFor
end
local event = Events.OnGameStart
if isServer() then
    event = Events.OnServerStarted
end

event.Add(function()
    local index = __classmetatables[ItemContainer.class].__index
    --for k, v in pairs(index) do
    --    print('ItemContainer:' .. k)
    --end
    if index['getEffectiveCapacity'] then
        local ori = index['getEffectiveCapacity']
        --print('do repalce getEffectiveCapacity')
        index['getEffectiveCapacity'] = GetNewEffectiveCapacity(ori)
    end
    if index['hasRoomFor'] then
        local ori = index['hasRoomFor']
        --print('do replace hasRoomFor')
        index['hasRoomFor'] = GetNewHasRoomFor(ori)
    end
end)