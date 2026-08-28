---@class BicycleDebug
local BicycleDebug = {}

local PREFIX = "[BicycleDebug]"
BicycleDebug.Enabled = false

---@param _message string
local function emitDebug(_message)
    if not BicycleDebug.Enabled then
        return
    end

    print(_message)
end

---@param enabled boolean
function BicycleDebug.setEnabled(enabled)
    BicycleDebug.Enabled = enabled == true
end

---@return string
---@nodiscard
local function getSide()
    if isClient() then
        return "client"
    elseif isServer() then
        return "server"
    end

    return "singleplayer"
end

---@param item InventoryItem|nil
---@return string
---@nodiscard
function BicycleDebug.describeItem(item)
    if not item then
        return "nil"
    end

    local fullType = item.getFullType and item:getFullType() or tostring(item)
    local itemId = item.getID and item:getID() or "?"
    local partType = item.getPartType and item:getPartType() or nil
    local location = "inventory"
    if item.getWorldItem and item:getWorldItem() then
        location = "world"
    end

    local details = fullType .. "#" .. tostring(itemId) .. "@" .. location
    if partType then
        details = details .. ",part=" .. tostring(partType)
    end

    return details
end

---@param square IsoGridSquare|nil
---@return string
---@nodiscard
function BicycleDebug.describeSquare(square)
    if not square then
        return "nil"
    end

    return tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ())
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return string
---@nodiscard
function BicycleDebug.describePlayer(player)
    if not player then
        return "nil"
    end

    local label = player.getDisplayName and player:getDisplayName() or tostring(player)
    if player.getOnlineID then
        label = label .. "#" .. tostring(player:getOnlineID())
    end

    return label
end

---@param value unknown
---@return string
---@nodiscard
function BicycleDebug.describeValue(value)
    if value == nil then
        return "nil"
    end

    if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    end

    if type(value) == "userdata" then
        if value.getFullType and value.getID then
            return BicycleDebug.describeItem(value)
        end
        if value.getDisplayName and value.getOnlineID then
            return BicycleDebug.describePlayer(value)
        end
    end

    return tostring(value) .. " [" .. type(value) .. "]"
end

---@param message string
function BicycleDebug.log(message)
    emitDebug(PREFIX .. "[" .. getSide() .. "] " .. tostring(message))
end

---@param flatWheelType string|nil
function BicycleDebug.spawnFlatWheel(flatWheelType)
    flatWheelType = flatWheelType or "Bicycle.Bicycle_StreetWheelFrontFlatItem"
    local player = getSpecificPlayer(0)
    if not player then
        emitDebug(PREFIX .. " spawnFlatWheel: no player found")
        return
    end
    local item = player:getInventory():AddItem(flatWheelType)
    if not item then
        emitDebug(PREFIX .. " spawnFlatWheel: unknown item type: " .. tostring(flatWheelType))
        return
    end
    emitDebug(PREFIX .. " spawnFlatWheel: spawned " .. flatWheelType)
end

_G.BicycleDebug = BicycleDebug

return BicycleDebug
