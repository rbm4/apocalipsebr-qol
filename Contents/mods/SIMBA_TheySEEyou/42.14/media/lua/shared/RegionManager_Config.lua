-- ============================================================================
-- File: media/lua/shared/RegionManager_Config.lua
-- Shared configuration for custom region management
-- ============================================================================
-- ============================================================================
-- EmmyLua type definitions (no runtime effect, used by Lua Language Server)
-- ============================================================================
---@class ColorRGB
---@field r number Red component (0-255 for config, 0-1 for rendering)
---@field g number Green component
---@field b number Blue component
---@class Bounds
---@field minX number
---@field maxX number
---@field minY number
---@field maxY number
--- Raw region as defined in config or loaded from JSON.
--- `customProperties` overrides category defaults at registration time.
---@class RegionDefinition
---@field id string Unique region identifier
---@field name string Human-readable region name
---@field x1 number First corner X coordinate
---@field y1 number First corner Y coordinate
---@field x2 number Opposite corner X coordinate
---@field y2 number Opposite corner Y coordinate
---@field z number Z level (usually 0)
---@field enabled boolean Whether the region is active
---@field categories string[] Category keys (e.g. {"PVP","SPRINTERS"})
---@field customProperties ZoneProperties Optional property overrides
--- Flat property bag produced by merging category defaults with customProperties.
--- This is what `getMergedProperties()` returns and what gets stored as
--- `RegisteredZoneData.properties` on the server.
---@class ZoneProperties
---@field name string
---@field color ColorRGB
---@field pvpEnabled boolean
---@field safehouse boolean
---@field noZombies boolean
---@field announceEntry boolean
---@field announceExit boolean
---@field zombieSpeed number 1=Shambler, 2=FastShambler, 3=Sprinter
---@field zombieStrength number
---@field zombieDensity number
---@field zombieRespawn boolean
---@field lootModifier number
---@field sprinterChance number 1-100 percentage of zombies that become sprinters
---@field maxHits number Number of extra hits tough zombies can resist before dying (default 2, range 1-99)
---@field message string Notification message shown on zone entry
--- Server-side registered zone data, stored in RegionManager.Server.registeredZones[id].
--- Contains the original RegionDefinition, the merged ZoneProperties, computed Bounds,
--- and the engine zone handle.
---@class RegisteredZoneData
---@field region RegionDefinition Original region definition
---@field properties ZoneProperties Merged flat properties (categories + customProperties)
---@field bounds Bounds Pre-calculated min/max rectangle
---@field zone any Game engine zone handle
--- Zone data as sent to clients via the "AllZoneBoundaries" server command.
--- A subset of RegisteredZoneData flattened for client consumption.
---@class ClientZoneData
---@field id string
---@field name string
---@field bounds Bounds
---@field color ColorRGB
---@field pvpEnabled boolean
---@field sprinterChance number
---@field announceEntry boolean
---@field announceExit boolean
---@field message string
--- Module definition for registering with RegionManager.ClientTick.
---@class TickModuleDef
---@field name string Module identifier
---@field onZoneEntered? fun(player: IsoPlayer, zoneId: string, zoneData: ClientZoneData)
---@field onZoneExited? fun(player: IsoPlayer, zoneId: string, zoneData: ClientZoneData)
---@field onTick? fun(player: IsoPlayer, currentZones: table<string, ClientZoneData>)
-- ============================================================================
RegionManager = RegionManager or {}
RegionManager.Config = RegionManager.Config or {}

-- Centralized logging utility
RegionManager.Log = function(module, msg)
    -- Check sandbox setting for debug mode
    local debugEnabled = false
    if SandboxVars and SandboxVars.RegionManager and SandboxVars.RegionManager.DebugMode then
        debugEnabled = SandboxVars.RegionManager.DebugMode
    end

    if debugEnabled then
        print("[RegionManager " .. tostring(module) .. "] " .. tostring(msg))
    end
end

-- Zone categories and their default properties
---@type table<string, ZoneProperties>
RegionManager.Config.Categories = {
    PVP = {
        name = "PVP Zone",
        color = {
            r = 1.0,
            g = 0.0,
            b = 0.0
        },
        pvpEnabled = true,
        safehouse = false,
        announceEntry = true,
        announceExit = true
    },
    SPRINTERS = {
        name = "Sprinter Zone",
        color = {
            r = 1.0,
            g = 0.5,
            b = 0.0
        },
        announceEntry = true,
        announceExit = true
    },
    SHAMBLERS = {
        name = "Shambler Zone",
        color = {
            r = 1.0,
            g = 0.5,
            b = 0.0
        },
        announceEntry = true,
        announceExit = true
    },
    SAFEZONE = {
        name = "Safe Zone",
        color = {
            r = 0.0,
            g = 1.0,
            b = 0.0
        },
        pvpEnabled = false,
        safehouse = true,
        noZombies = true,
        announceEntry = true,
        announceExit = true
    },
    LOOTBONUS = {
        name = "High Loot Zone",
        color = {
            r = 0.0,
            g = 0.5,
            b = 1.0
        },
        lootModifier = 1.5,
        announceEntry = true,
        announceExit = false
    },
    DEADZONE = {
        name = "Dead Zone",
        color = {
            r = 0.5,
            g = 0.0,
            b = 0.5
        },
        zombieDensity = 3.0,
        zombieRespawn = true,
        announceEntry = true,
        announceExit = true
    },
    CUSTOM = {
        name = "Custom Zone",
        color = {
            r = 0.5,
            g = 0.5,
            b = 0.5
        },
        announceEntry = false,
        announceExit = false
    },
    AUTOSAFE = {
        name = "Auto-Generated Safe Zone",
        color = {
            r = 0.0,
            g = 0.78,
            b = 1.0
        },
        pvpEnabled = false,
        safehouse = false,
        announceEntry = false,
        announceExit = false
    }
}

-- Region definitions
-- Each region uses two opposite corner coordinates to define a rectangle
-- Format: x1, y1 (first corner) and x2, y2 (opposite corner)
---@type RegionDefinition[]
RegionManager.Config.Regions = { -- Example: Muldraugh Downtown PVP
{
    id = "lousville_test_area",
    name = "Lousville test area",
    x1 = 12590, -- Top-left or bottom-left corner
    y1 = 810,
    x2 = 12609, -- Opposite corner
    y2 = 904,
    z = 0,
    categories = {"PVP", "SPRINTERS"},
    enabled = true,
    customProperties = {
        zombieSpeed = 3,
        zombieDensity = 5.0,
        pvpEnabled = true,
        sprinterChance = 100, -- 25% sprinter chance (1-100, default baseline: 50)
        message = "Voce acabou de entrar em territorio hostil e de infeccao alta! Cuidado extremo!"
    }
} -- {
--     id = "muldraugh_downtown_road",
--     name = "Downtown Muldraugh Road",
--     x1 = 10584,  -- Top-left or bottom-left corner
--     y1 = 8852,
--     x2 = 10598,  -- Opposite corner b42map.com/?x
--     y2 = 14250,
--     z = 0,
--     categories = {"PVP"},
--     enabled = true,
--     customProperties = {
--         pvpEnabled = true,
--         sprinterChance = 100,
--         message = "You've entered a PVP zone! Watch your back!"
--     }
-- },
-- Example: Louisville Sprinter Zone
-- {
--     id = "louisville_sprinters",
--     name = "Louisville Outbreak Zone",
--     x1 = 12000,
--     y1 = 2000,
--     x2 = 12300,  -- 300 units away
--     y2 = 2300,
--     z = 0,
--     categories = {"SPRINTERS", "DEADZONE"},
--     enabled = true,
--     customProperties = {
--         zombieSpeed = 3,
--         zombieDensity = 5.0,
--         sprinterChance = 80,  -- 80% chance zombies become sprinters (1-100, default: 50)
--         message = "WARNING: Infected runners detected in this area!"
--     }
-- },
-- Example: West Point Safe Zone
-- {
--     id = "westpoint_safezone",
--     name = "West Point Sanctuary",
--     x1 = 11500,
--     y1 = 6900,
--     x2 = 11550,  -- 50 units away
--     y2 = 6950,
--     z = 0,
--     categories = {"SAFEZONE"},
--     enabled = true,
--     customProperties = {
--         noZombies = true,
--         pvpEnabled = false,
--         message = "You've entered a safe zone. No combat allowed."
--     }
-- },
-- Example: Rosewood High Loot
-- {
--     id = "rosewood_loot",
--     name = "Rosewood Supply Cache",
--     x1 = 8100,
--     y1 = 11600,
--     x2 = 8180,  -- 80 units away
--     y2 = 11680,
--     z = 0,
--     categories = {"LOOTBONUS"},
--     enabled = true,
--     customProperties = {
--         lootModifier = 2.0,
--         message = "This area seems well-stocked..."
--     }
-- }
-- Add more regions as needed
-- Use GetMyCoords() in console to get your current position
}

-- External regions file (read/written by server on startup, managed by external API)
RegionManager.Config.RegionsFilePath = "RegionManager_Regions.json"

-- Export/Import paths (relative to Zomboid directory)
RegionManager.Config.ExportPath = "RegionManager_Export.json"
RegionManager.Config.ImportPath = "RegionManager_Import.json"

-- ModData key for server-side persistence
RegionManager.Config.MODDATA_KEY = "RegionManager_RegisteredZones"

-- Sandbox option keys
RegionManager.Config.SANDBOX_PREFIX = "RegionManager"

return RegionManager.Config
