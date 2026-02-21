local version = require("EuryBugs/_Version")

-- Apply our server-side fix only up to and including 42.13.1.
-- On newer versions we keep the callback alive but forward to vanilla.
local APPLY_FIX = (version and version.isAtMax and version.isAtMax("42.13.1")) == true

local MOD = "FireHardenedSpearFix"
local DEBUG = getCore():getDebug()

local function dlog(msg)
    if not DEBUG then return end
    DebugLog.log(DebugType.General, "[" .. MOD .. "][SH] " .. tostring(msg))
end

if not APPLY_FIX then
    dlog("skipped patch")
end

FHSF = FHSF or {}
FHSF._ctxCharacter = nil
FHSF._wrapped = false

local function isNearOpenFireForCharacter(chr)
    if not chr then return false end
    local sq = chr:getCurrentSquare()
    if not sq then return false end

    local squares = sq.getRadius and sq:getRadius(2) or nil
    if squares then
        for i = 0, squares:size() - 1 do
            local rsq = squares:get(i)
            if rsq then
                local objs = rsq:getObjects()
                for j = 0, objs:size() - 1 do
                    local obj = objs:get(j)
                    if obj then
                        if instanceof(obj, "IsoFireplace") or instanceof(obj, "IsoBarbecue") then
                            if obj.isLit and obj:isLit() then
                                return true
                            end
                        elseif instanceof(obj, "IsoThumpable") then
                            local md = obj:getModData()
                            if md and md.isLit == true then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    if sq.hasAdjacentFireObject then
        return sq:hasAdjacentFireObject()
    end

    return false
end

local function callVanillaOpenFire(...)
    if not (RecipeCodeOnTest and RecipeCodeOnTest.openFire) then
        -- If vanilla isn't available for some reason, be permissive (avoid blocking crafting).
        dlog("RecipeCodeOnTest does not exist - auto allow")
        return true
    end

    -- First: try forwarding exactly what we were given (best compatibility with UI/mods).
    local ok, ret = pcall(RecipeCodeOnTest.openFire, ...)
    if ok then
        return ret == true
    end
    dlog("RecipeCodeOnTest failed to run - fall back")

    -- Second: some call sites may include extra args; retry with the first InventoryItem we can find.
    local item = nil
    local n = select("#", ...)
    for i = 1, n do
        local v = select(i, ...)
        if v and instanceof(v, "InventoryItem") then
            item = v
            break
        end
    end

    if item then
        local ok2, ret2 = pcall(RecipeCodeOnTest.openFire, item)
        if ok2 then
            return ret2 == true
        end
    end

    dlog("Vanilla openFire call failed: " .. tostring(ret))
    return true
end

-- This is what your recipe override calls: OnTest:FHSF.OpenFire
function FHSF.OpenFire(...)
    -- Newer builds: don't change behaviour, just use vanilla.
    if not APPLY_FIX then
        return callVanillaOpenFire(...)
    end

    -- Client: keep UI consistent with vanilla (and Neat Crafting probing).
    if not isServer() then
        return callVanillaOpenFire(...)
    end

    -- Server: authoritative check using context we capture from ISHandcraftAction.
    local chr = FHSF._ctxCharacter
    if not chr then
        dlog("OpenFire called with no context character")
        return false
    end

    return isNearOpenFireForCharacter(chr)
end

local function wrapHandcraft()
    if FHSF._wrapped then return end

    local ok = pcall(require, "Entity/TimedActions/ISHandcraftAction")
    if not ok or not ISHandcraftAction then
        dlog("ISHandcraftAction not available")
        return
    end

    FHSF._wrapped = true

    local oldServerStart = ISHandcraftAction.serverStart
    ISHandcraftAction.serverStart = function(self, ...)
        local prev = FHSF._ctxCharacter
        FHSF._ctxCharacter = self and self.character or nil

        local ok2, ret = pcall(oldServerStart, self, ...)

        FHSF._ctxCharacter = prev
        if not ok2 then error(ret) end
        return ret
    end

    local oldPerformRecipe = ISHandcraftAction.performRecipe
    ISHandcraftAction.performRecipe = function(self, ...)
        local prev = FHSF._ctxCharacter
        FHSF._ctxCharacter = self and self.character or nil

        local ok2, ret = pcall(oldPerformRecipe, self, ...)

        FHSF._ctxCharacter = prev
        if not ok2 then error(ret) end
        return ret
    end

    dlog("Wrapped ISHandcraftAction.serverStart + performRecipe")
end

if APPLY_FIX then
    wrapHandcraft()
end