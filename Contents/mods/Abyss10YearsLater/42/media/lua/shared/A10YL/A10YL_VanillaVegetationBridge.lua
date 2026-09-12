-- Extends Project Zomboid B42's normal vegetation-removal timed actions so
-- A10YL-owned bushes, wall vines and grass can be cleared using vanilla player
-- interactions rather than special admin tools.
require "TimedActions/ISRemoveBush"
require "TimedActions/ISRemoveGrass"

local Clearing = require("A10YL/A10YL_Clearing")
local Identity = require("A10YL/A10YL_Identity")

local Bridge = {}

local function isAuthority()
    if type(isServer) == "function" and isServer() then return true end
    return type(isClient) ~= "function" or not isClient()
end

local function removeOwned(square, obj)
    if not square or not obj or not isAuthority() then return false end
    Clearing.suppressObject(square, obj)
    square:transmitRemoveItemFromSquare(obj)
    return true
end

local function addVanillaBushLoot(square)
    if not square or not isAuthority() then return end
    if ZombRand(2) == 0 then
        square:AddWorldInventoryItem("Base.TreeBranch2", 0, 0, 0)
    end
    -- Match B42.20.x vanilla ISRemoveBush behaviour.
    if ZombRand(1) == 0 then
        square:AddWorldInventoryItem("Base.Twigs", 0, 0, 0)
    end
end

local function patchRemoveBush()
    if not ISRemoveBush or ISRemoveBush.A10YL_VANILLA_BRIDGE then return end

    local originalGetBushObject = ISRemoveBush.getBushObject
    local originalGetWallVineObject = ISRemoveBush.getWallVineObject
    local originalComplete = ISRemoveBush.complete

    function ISRemoveBush:getBushObject(square)
        local obj = originalGetBushObject(self, square)
        if obj then return obj end
        return Clearing.findOwned(square, "Bush")
    end

    function ISRemoveBush:getWallVineObject(square)
        local obj, index = originalGetWallVineObject(self, square)
        if obj then return obj, index end
        -- A10YL wall vines are safe standalone overlay objects rather than
        -- vanilla erosion attached-animation sprites. Returning the object here
        -- lets the vanilla action validate, face and animate against it.
        return Clearing.findOwned(square, "Vine"), nil
    end

    function ISRemoveBush:complete()
        local square = self.square
        if not square then return false end

        if self.wallVine then
            local owned = Clearing.findOwned(square, "Vine")
            local topSquare = getCell():getGridSquare(square:getX(), square:getY(), square:getZ() + 1)
            local ownedTop = Clearing.findOwned(topSquare, "Vine")

            if owned or ownedTop then
                if owned then removeOwned(square, owned) end
                -- Vanilla wall-vine removal also removes the continuation above.
                if ownedTop then removeOwned(topSquare, ownedTop) end
                return true
            end

            return originalComplete(self)
        end

        local ownedBush = Clearing.findOwned(square, "Bush")
        if ownedBush then
            if removeOwned(square, ownedBush) then
                addVanillaBushLoot(square)
                return true
            end
            return false
        end

        return originalComplete(self)
    end

    ISRemoveBush.A10YL_VANILLA_BRIDGE = true
end

local function patchRemoveGrass()
    if not ISRemoveGrass or ISRemoveGrass.A10YL_VANILLA_BRIDGE then return end

    local originalIsValid = ISRemoveGrass.isValid
    local originalComplete = ISRemoveGrass.complete

    function ISRemoveGrass:isValid()
        if originalIsValid(self) then return true end
        return Clearing.findOwnedGrass(self.square) ~= nil
    end

    function ISRemoveGrass:complete()
        local square = self.square
        if not square then return false end

        local ownedGrass = Clearing.findOwnedGrass(square)
        if not ownedGrass then
            return originalComplete(self)
        end

        -- Capture the durable key before vanilla complete() may detach/remove
        -- the Java object from the square.
        local operationKey = Identity.getOperationKey(ownedGrass)

        -- Keep the normal Remove Grass fatigue/reward/action semantics by
        -- letting vanilla complete first, then remove any A10YL grass object
        -- that vanilla sprite flags did not cover.
        local result = originalComplete(self)
        local remaining = Clearing.findOwnedGrass(square)
        if remaining then
            removeOwned(square, remaining)
        elseif operationKey then
            Clearing.suppressOperation(square, operationKey)
        end
        return result
    end

    ISRemoveGrass.A10YL_VANILLA_BRIDGE = true
end

function Bridge.install()
    patchRemoveBush()
    patchRemoveGrass()
    return true
end

Bridge.install()
return Bridge
