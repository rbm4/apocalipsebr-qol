local WRAPS_TYPE = "IAmBruceLeeNow.MartialArtsHandWraps"
local WORLD_DATA_KEY = "IABLN_GuaranteedPoliceStationWraps"

local CANDIDATES = {
    evidenceroom = { other = 1, filingcabinet = 1 },
    policelocker = { locker = 2 },
    policeoffice = { desk = 3 },
}

local pending = {}
local finalizeHookInstalled = false

local function getBuildingKey(itemContainer)
    local parent = itemContainer and itemContainer:getParent() or nil
    local square = parent and parent:getSquare() or nil
    local building = square and square:getBuilding() or nil
    local buildingDef = building and building:getDef() or nil
    if not buildingDef then return nil end
    return tostring(buildingDef:getIDString())
end

local function finalizePending()
    Events.OnTick.Remove(finalizePending)
    finalizeHookInstalled = false

    local suppliedStations = ModData.getOrCreate(WORLD_DATA_KEY)
    local changed = false

    for key, candidate in pairs(pending) do
        if not suppliedStations[key] then
            local wraps = candidate.container:AddItem(WRAPS_TYPE)
            if wraps then
                suppliedStations[key] = true
                changed = true
            end
        end
        pending[key] = nil
    end

    if changed and isServer() then ModData.transmit(WORLD_DATA_KEY) end
end

local function onFillContainer(roomName, containerType, itemContainer)
    local room = string.lower(tostring(roomName or ""))
    local container = string.lower(tostring(containerType or ""))
    local rank = CANDIDATES[room] and CANDIDATES[room][container] or nil
    if not rank or not itemContainer then return end

    local key = getBuildingKey(itemContainer)
    if not key then return end

    local suppliedStations = ModData.getOrCreate(WORLD_DATA_KEY)
    if suppliedStations[key] then return end

    local current = pending[key]
    if not current or rank < current.rank then
        pending[key] = {
            container = itemContainer,
            containerType = container,
            room = room,
            rank = rank,
        }
    end

    -- Container events arrive in a loading batch. Waiting until the next tick
    -- lets an evidence-room candidate replace a desk or locker seen first.
    if not finalizeHookInstalled then
        finalizeHookInstalled = true
        Events.OnTick.Add(finalizePending)
    end
end

Events.OnFillContainer.Add(onFillContainer)
