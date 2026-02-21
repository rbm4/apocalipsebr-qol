local MOD = "RemoveCropFix"

local DEBUG = getCore():getDebug()

local function log(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][SH] " .. tostring(msg))
    end
end

local version = require("EuryBugs/_Version")
if not (version and version.isAtMax("42.13.1")) then
    log("skipped patch")
    return
end

require "Farming/TimedActions/ISShovelAction"

local function side()
    local s = ""
    if isServer and isServer() then s = s .. "S" end
    if isClient and isClient() then s = s .. "C" end
    if s == "" then s = "?" end
    return s
end

local function state(self, tag)
    local plantStr = "nil"
    if self and self.plant then plantStr = tostring(self.plant) end

    local xyz = "nil"
    if self and self.x and self.y and self.z then
        xyz = tostring(self.x) .. "," .. tostring(self.y) .. "," .. tostring(self.z)
    end

    local itemStr = "nil"
    if self and self.item then itemStr = tostring(self.item.getFullType and self.item:getFullType() or self.item) end

    log(tag .. " side " .. side() .. " xyz " .. xyz .. " plant " .. plantStr .. " item " .. itemStr)
end

local function resolvePlant(self)
    if not self then return nil end

    -- If we already have the lua-object, use it.
    if self.plant and self.plant.updateFromIsoObject then
        self.plant:updateFromIsoObject()
        return self.plant
    end

    if not (self.x and self.y and self.z) then return nil end

    -- Client: CFarmingSystem owns the plant globals
    if isClient and isClient() then
        if not (CFarmingSystem and CFarmingSystem.instance and getCell) then return nil end
        local sq = getCell():getGridSquare(self.x, self.y, self.z)
        if not sq then return nil end

        local plant = CFarmingSystem.instance:getLuaObjectOnSquare(sq)
        if plant and plant.updateFromIsoObject then
            plant:updateFromIsoObject()
        end
        return plant
    end

    -- Server: SFarmingSystem owns the authoritative data
    if isServer and isServer() then
        if not (SFarmingSystem and SFarmingSystem.instance) then return nil end
        local plant = SFarmingSystem.instance:getLuaObjectAt(self.x, self.y, self.z)
        if plant and plant.updateFromIsoObject then
            plant:updateFromIsoObject()
        end
        return plant
    end

    return nil
end

local function resolveSquare(self, plant)
    if plant and plant.getSquare then
        return plant:getSquare()
    end
    if getCell and self and self.x and self.y and self.z then
        local cell = getCell()
        if cell then
            return cell:getGridSquare(self.x, self.y, self.z)
        end
    end
    return nil
end

local function guarded(self, fnName, fn)
    state(self, fnName .. " enter")
    local ok, ret = pcall(fn)
    if not ok then
        log(fnName .. " ERROR " .. tostring(ret))
        state(self, fnName .. " state")
        return false
    end
    state(self, fnName .. " exit")
    return ret
end

-- Patch ISShovelAction:new so it can accept plant OR square, and always stores x y z
local _oldNew = ISShovelAction.new
function ISShovelAction:new(character, item, plantOrSq, maxTime, x, y, z)
    local o = _oldNew(self, character, item, plantOrSq, maxTime)

    -- Prefer explicit xyz (so NetTimedAction can carry it)
    if x and y and z then
        o.x, o.y, o.z = x, y, z
        o.plant = nil
        return o
    end

    -- Fallback: square passed in locally
    if plantOrSq and plantOrSq.getX then
        o.x, o.y, o.z = plantOrSq:getX(), plantOrSq:getY(), plantOrSq:getZ()
        o.plant = nil
    elseif plantOrSq then
        o.x, o.y, o.z = plantOrSq.x, plantOrSq.y, plantOrSq.z
    end

    return o
end

-- Patch isValid to never crash and to log what is missing
local _oldIsValid = ISShovelAction.isValid
function ISShovelAction:isValid()
    return guarded(self, "isValid", function()
        local plant = resolvePlant(self)
        if not plant then
            log("isValid no plant")
            return false
        end
        if not (plant.getIsoObject and plant:getIsoObject()) then
            log("isValid no isoObject")
            return false
        end
        return true
    end)
end

local _oldWaitToStart = ISShovelAction.waitToStart
function ISShovelAction:waitToStart()
    return guarded(self, "waitToStart", function()
        local plant = resolvePlant(self)
        if plant and plant.getObject then
            local obj = plant:getObject()
            if obj then
                self.character:faceThisObject(obj)
                return self.character:isTurning() or self.character:shouldBeTurning()
            end
        end
        return false
    end)
end

local _oldUpdate = ISShovelAction.update
function ISShovelAction:update()
    return guarded(self, "update", function()
        if self.item and self.item.setJobDelta then
            self.item:setJobDelta(self:getJobDelta())
        end

        local plant = resolvePlant(self)
        if plant and plant.getObject then
            local obj = plant:getObject()
            if obj then
                self.character:faceThisObject(obj)
            end
        end

        -- Guard Metabolics (server may not have it)
        if Metabolics and Metabolics.DiggingSpade and self.character and self.character.setMetabolicTarget then
            self.character:setMetabolicTarget(Metabolics.DiggingSpade)
        end
    end)
end

local _oldStart = ISShovelAction.start
function ISShovelAction:start()
    return guarded(self, "start", function()
        if self.item then
            self.item:setJobType(getText("ContextMenu_Remove"))
            self.item:setJobDelta(0.0)
        end

        -- Client-only niceties (log whether they exist)
        if not (isServer and isServer()) then
            local plant = resolvePlant(self)
            local sq = resolveSquare(self, plant)

            log("start client path sq " .. tostring(sq))

            if sq and getSoundManager then
                self.sound = getSoundManager():PlayWorldSound("Shoveling", sq, 0, 10, 1, true)
            else
                log("start no soundmanager or sq")
            end

            if BuildingHelper and BuildingHelper.getShovelAnim then
                local anim = BuildingHelper.getShovelAnim(self.character:getPrimaryHandItem())
                self:setActionAnim(anim)
            else
                log("start no BuildingHelper.getShovelAnim")
            end
        else
            log("start server path")
        end
    end)
end

local _oldPerform = ISShovelAction.perform
function ISShovelAction:perform()
    return guarded(self, "perform", function()
        if not (isServer and isServer()) then
            if self.sound and self.sound.isPlaying and self.sound:isPlaying() then
                self.sound:stop()
            end
        end

        if self.item and self.item.getContainer then
            local c = self.item:getContainer()
            if c and c.setDrawDirty then c:setDrawDirty(true) end
            self.item:setJobDelta(0.0)
        end

        if not (isServer and isServer()) and ISFarmingMenu and ISFarmingMenu.info then
            local info = ISFarmingMenu.info[self.character]
            if info and info.isVisible and info:isVisible() then
                info:setVisible(false)
            end
        end

        ISBaseTimedAction.perform(self)
    end)
end

local _oldComplete = ISShovelAction.complete
function ISShovelAction:complete()
    return guarded(self, "complete", function()
        local plant = resolvePlant(self)
        local sq = resolveSquare(self, plant)

        log("complete resolved plant " .. tostring(plant) .. " sq " .. tostring(sq))

        if sq then
            SFarmingSystem:removeTallGrass(sq)
            local floor = sq:getFloor()
            if floor and floor:getSprite()
                and floor:getSprite():getProperties():get("grassFloor")
                and sq:checkHaveGrass() == true
            then
                sq:removeGrass()
            end
        else
            log("complete no sq")
        end

        if SFarmingSystem and SFarmingSystem.instance then
            local realPlant = nil

            if plant and plant.x and plant.y and plant.z then
                realPlant = SFarmingSystem.instance:getLuaObjectAt(plant.x, plant.y, plant.z)
            elseif self.x and self.y and self.z then
                realPlant = SFarmingSystem.instance:getLuaObjectAt(self.x, self.y, self.z)
            end

            log("complete realPlant " .. tostring(realPlant))

            if realPlant then
                SFarmingSystem.instance:removePlant(realPlant)
            else
                log("complete no realPlant to remove")
            end
        else
            log("complete no SFarmingSystem.instance")
        end

        return true
    end)
end
