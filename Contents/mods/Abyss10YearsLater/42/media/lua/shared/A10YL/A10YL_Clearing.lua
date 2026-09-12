-- Player-cleared A10YL overgrowth suppression.
-- Stores durable operation keys in square ModData so player cleanup is respected
-- even if a square is still finishing a queued ageing pass or a later generator
-- revision revisits the area.
local Identity = require("A10YL/A10YL_Identity")

local Clearing = {}

Clearing.MODDATA_KEY = "A10YL_ClearedOps"

local function getStore(square, create)
    if not square then return nil end
    local modData = square:getModData()
    if not modData then return nil end

    local store = modData[Clearing.MODDATA_KEY]
    if type(store) ~= "table" and create then
        store = {}
        modData[Clearing.MODDATA_KEY] = store
    end
    return type(store) == "table" and store or nil
end

local function isAuthority()
    if type(isServer) == "function" and isServer() then return true end
    return type(isClient) ~= "function" or not isClient()
end

function Clearing.isSuppressed(square, operationKey)
    if not square or type(operationKey) ~= "string" or operationKey == "" then
        return false
    end
    local store = getStore(square, false)
    return store ~= nil and store[operationKey] == true
end

function Clearing.suppressOperation(square, operationKey)
    if not square or type(operationKey) ~= "string" or operationKey == "" then
        return false
    end

    local store = getStore(square, true)
    if not store then return false end
    store[operationKey] = true

    -- Server/SP owns the durable write. In MP the timed action completes on the
    -- server; client copies never need to transmit the suppression marker.
    if isAuthority() then
        local fn = square.transmitModdata
        if type(fn) == "function" then
            pcall(fn, square)
        end
    end
    return true
end

function Clearing.suppressObject(square, obj)
    if not square or not obj then return false end
    local operationKey = Identity.getOperationKey(obj)
    if not operationKey then return false end
    return Clearing.suppressOperation(square, operationKey)
end

function Clearing.findOwned(square, ownedType)
    if not square then return nil end
    local objects = square:getObjects()
    if not objects then return nil end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Identity.isOwnedObject(obj, ownedType) then
            return obj
        end
    end
    return nil
end

function Clearing.findOwnedGrass(square)
    if not square then return nil end
    local objects = square:getObjects()
    if not objects then return nil end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Identity.isOwnedObject(obj, "GroundCover") then
            local spriteName = tostring(obj:getSpriteName() or obj:getTextureName() or "")
            if spriteName:find("grass", 1, true) then
                return obj
            end
        end
    end
    return nil
end

return Clearing
