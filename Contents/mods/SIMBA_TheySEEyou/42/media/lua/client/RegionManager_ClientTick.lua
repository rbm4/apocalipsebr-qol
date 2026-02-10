-- ============================================================================
-- File: media/lua/client/RegionManager_ClientTick.lua
-- Central client-side tick dispatcher for region-based state management.
-- Handles zone enter/exit detection and notifies registered modules.
-- ============================================================================

if isServer() then return end

require "RegionManager_Config"

RegionManager.ClientTick = RegionManager.ClientTick or {}

local TickCounter = 0
local TickInterval = 120 -- 2 seconds at 60 FPS

---@type table<string, ClientZoneData>
local PreviousZones = {} -- Track zones the player was in last check

---@type TickModuleDef[]
local RegisteredModules = {} -- Modules that want zone enter/exit callbacks

local function log(msg)
    RegionManager.Log("ClientTick", msg)
end

-- ============================================================================
-- Module registration API
-- Modules can register callbacks for zone events and periodic ticks.
--
-- RegionManager.ClientTick.registerModule({
--     name = "MyModule",
--     onZoneEntered = function(player, zoneId, zoneData) end,  -- optional
--     onZoneExited  = function(player, zoneId, zoneData) end,  -- optional
--     onTick        = function(player, currentZones) end,      -- optional (called every tick interval)
-- })
-- ============================================================================
---@param moduleDef TickModuleDef
function RegionManager.ClientTick.registerModule(moduleDef)
    if not moduleDef or not moduleDef.name then
        log("ERROR: registerModule requires a 'name' field")
        return
    end
    table.insert(RegisteredModules, moduleDef)
    log("Registered module: " .. moduleDef.name)
end

-- Notify all registered modules of a zone entry
---@param player IsoPlayer
---@param zoneId string
---@param zoneData ClientZoneData
local function notifyZoneEntered(player, zoneId, zoneData)
    for _, mod in ipairs(RegisteredModules) do
        if mod.onZoneEntered then
            local ok, err = pcall(mod.onZoneEntered, player, zoneId, zoneData)
            if not ok then
                log("ERROR in module '" .. mod.name .. "' onZoneEntered: " .. tostring(err))
            end
        end
    end
end

-- Notify all registered modules of a zone exit
---@param player IsoPlayer
---@param zoneId string
---@param zoneData ClientZoneData
local function notifyZoneExited(player, zoneId, zoneData)
    for _, mod in ipairs(RegisteredModules) do
        if mod.onZoneExited then
            local ok, err = pcall(mod.onZoneExited, player, zoneId, zoneData)
            if not ok then
                log("ERROR in module '" .. mod.name .. "' onZoneExited: " .. tostring(err))
            end
        end
    end
end

-- Notify all registered modules on each tick interval
---@param player IsoPlayer
---@param currentZones table<string, ClientZoneData>
local function notifyTick(player, currentZones)
    for _, mod in ipairs(RegisteredModules) do
        if mod.onTick then
            local ok, err = pcall(mod.onTick, player, currentZones)
            if not ok then
                log("ERROR in module '" .. mod.name .. "' onTick: " .. tostring(err))
            end
        end
    end
end

-- ============================================================================
-- Core zone detection (moved from HYPOTHETIC_TSY_Main)
-- Each client checks its own player and sends state to the server for broadcast.
-- ============================================================================
---@param player IsoPlayer
local function checkPlayerZone(player)
    if not player then return end

    -- Wait until zone data is available
    if not RegionManager or not RegionManager.Client or not RegionManager.Client.zoneData then
        sendClientCommand("RegionManager", "RequestAllBoundaries", {})
        log("Waiting for zone data, RequestAllBoundaries sent")
        return
    end

    local playerX = player:getX()
    local playerY = player:getY()

    -- Build current zones list
    local currentZones = {}
    for _, zone in ipairs(RegionManager.Client.zoneData) do
        local bounds = zone.bounds
        if playerX >= bounds.minX and playerX <= bounds.maxX and
           playerY >= bounds.minY and playerY <= bounds.maxY then
            currentZones[zone.id] = zone
        end
    end

    -- ---- Zone entries (in current but not in previous) ----
    for zoneId, zoneData in pairs(currentZones) do
        if not PreviousZones[zoneId] then
            log("Player ENTERED zone: " .. zoneData.name)

            local isSafeZone = (zoneData.pvpEnabled == false)
            local isPvpZone  = (zoneData.pvpEnabled == true)

            -- Apply Safety state locally
            if isPvpZone then
                player:getSafety():setEnabled(false)
                player:getSafety():setCooldown(999999)
                log("Applied PVP state locally (Safety=false)")
            elseif isSafeZone then
                player:getSafety():setEnabled(true)
                player:getSafety():setCooldown(999999)
                log("Applied Safe Zone state locally (Safety=true)")
            end

            -- Show notification if announceEntry is enabled
            if zoneData.announceEntry ~= false then
                local message = zoneData.message
                local color = zoneData.color or {r=255, g=255, b=255}
                player:Say(message, color.r / 255, color.g / 255, color.b / 255, UIFont.Medium, 3, "radio")
            end

            -- Notify server for broadcast to other clients
            sendClientCommand("RegionManager", "ClientZoneEntered", {
                zoneId = zoneId,
                zoneName = zoneData.name,
                isPvpZone = isPvpZone,
                isSafeZone = isSafeZone,
                safetyEnabled = player:getSafety():isEnabled()
            })

            -- Notify registered modules
            notifyZoneEntered(player, zoneId, zoneData)
        end
    end

    -- ---- Zone exits (in previous but not in current) ----
    for zoneId, zoneData in pairs(PreviousZones) do
        if not currentZones[zoneId] then
            log("Player EXITED zone: " .. zoneData.name)

            -- Restore Safety toggle (disabled because there will always be pvp or no pvp zones, player will not control safety state ever)
            -- player:getSafety():setCooldown(0) 

            -- Show notification if announceExit is enabled
            if zoneData.announceExit then
                local message = "Saiu: " .. zoneData.name
                local color = zoneData.color or {r=255, g=255, b=255}
                player:Say(message, 0.5, 0.5, 0.5, UIFont.Medium, 3, "radio")
            end

            -- Notify server for broadcast to other clients
            -- sendClientCommand("RegionManager", "ClientZoneExited", {
            --     zoneId = zoneId,
            --     zoneName = zoneData.name,
            --     safetyEnabled = player:getSafety():isEnabled()
            -- })

            -- Notify registered modules
            notifyZoneExited(player, zoneId, zoneData)
        end
    end

    -- Update previous zones
    PreviousZones = currentZones

    -- Notify modules with periodic tick (pass current zones for convenience)
    notifyTick(player, currentZones)
end

-- ============================================================================
-- Tick handler – single OnTick for all region-based client logic
-- ============================================================================
local function OnTick()
    TickCounter = TickCounter + 1
    if TickCounter >= TickInterval then
        TickCounter = 0
        local player = getPlayer()
        if player then
            checkPlayerZone(player)
        end
    end
end

-- ============================================================================
-- Player spawn – reset zone state & request boundaries
-- ============================================================================
local function OnPlayerSpawn()
    local player = getPlayer()
    if player then
        PreviousZones = {}
        sendClientCommand("RegionManager", "RequestAllBoundaries", {})
        log("Player spawned – cleared zone state and requested boundaries")
    end
end

-- ============================================================================
-- Public helpers
-- ============================================================================

-- Get the table of zones the player is currently inside
---@return table<string, ClientZoneData>
function RegionManager.ClientTick.getCurrentZones()
    return PreviousZones
end

-- Allow external adjustment of tick interval
---@param ticks number Number of game ticks between checks
function RegionManager.ClientTick.setTickInterval(ticks)
    TickInterval = ticks
end

-- ============================================================================
-- Event registration
-- ============================================================================
Events.OnTick.Add(OnTick)
Events.OnCreatePlayer.Add(OnPlayerSpawn)

log("RegionManager ClientTick dispatcher loaded")

return RegionManager.ClientTick
