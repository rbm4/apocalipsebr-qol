-- ============================================================================
-- File: media/lua/shared/RegionManager_Config.lua
-- Shared configuration for custom region management
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
RegionManager.Config.Categories = {
    PVP = {
        name = "PVP Zone",
        color = {r=1.0, g=0.0, b=0.0},
        pvpEnabled = true,
        safehouse = false,
        announceEntry = true,
        announceExit = true
    },
    SPRINTERS = {
        name = "Sprinter Zone",
        color = {r=1.0, g=0.5, b=0.0},
        zombieSpeed = 3, -- 1=Shambler, 2=FastShambler, 3=Sprinter
        zombieStrength = 2,
        announceEntry = true,
        announceExit = true
    },
    SAFEZONE = {
        name = "Safe Zone",
        color = {r=0.0, g=1.0, b=0.0},
        pvpEnabled = false,
        safehouse = true,
        noZombies = true,
        announceEntry = true,
        announceExit = true
    },
    LOOTBONUS = {
        name = "High Loot Zone",
        color = {r=0.0, g=0.5, b=1.0},
        lootModifier = 1.5,
        announceEntry = true,
        announceExit = false
    },
    DEADZONE = {
        name = "Dead Zone",
        color = {r=0.5, g=0.0, b=0.5},
        zombieDensity = 3.0,
        zombieRespawn = true,
        announceEntry = true,
        announceExit = true
    },
    CUSTOM = {
        name = "Custom Zone",
        color = {r=0.5, g=0.5, b=0.5},
        announceEntry = false,
        announceExit = false
    },
    AUTOSAFE = {
        name = "Auto-Generated Safe Zone",
        color = {r=0.0, g=0.78, b=1.0},
        pvpEnabled = false,
        safehouse = false,
        announceEntry = false,
        announceExit = false
    }
}

-- Region definitions
-- Each region uses two opposite corner coordinates to define a rectangle
-- Format: x1, y1 (first corner) and x2, y2 (opposite corner)
RegionManager.Config.Regions = {
    -- Example: Muldraugh Downtown PVP
    {
        id = "muldraugh_downtown_pvp",
        name = "Downtown Muldraugh Arena",
        x1 = 10500,  -- Top-left or bottom-left corner
        y1 = 9700,
        x2 = 10600,  -- Opposite corner (100 units away)
        y2 = 9800,
        z = 0,
        categories = {"PVP"},
        enabled = true,
        customProperties = {
            pvpEnabled = true,
            message = "You've entered a PVP zone! Watch your back!"
        }
    },
    {
        id = "muldraugh_downtown_road",
        name = "Downtown Muldraugh Road",
        x1 = 10584,  -- Top-left or bottom-left corner
        y1 = 8852,
        x2 = 10598,  -- Opposite corner b42map.com/?x
        y2 = 14250,
        z = 0,
        categories = {"PVP"},
        enabled = true,
        customProperties = {
            pvpEnabled = true,
            message = "You've entered a PVP zone! Watch your back!"
        }
    },
    
    -- Example: Louisville Sprinter Zone
    {
        id = "louisville_sprinters",
        name = "Louisville Outbreak Zone",
        x1 = 12000,
        y1 = 2000,
        x2 = 12300,  -- 300 units away
        y2 = 2300,
        z = 0,
        categories = {"SPRINTERS", "DEADZONE"},
        enabled = true,
        customProperties = {
            zombieSpeed = 3,
            zombieDensity = 5.0,
            message = "WARNING: Infected runners detected in this area!"
        }
    },
    
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
    {
        id = "rosewood_loot",
        name = "Rosewood Supply Cache",
        x1 = 8100,
        y1 = 11600,
        x2 = 8180,  -- 80 units away
        y2 = 11680,
        z = 0,
        categories = {"LOOTBONUS"},
        enabled = true,
        customProperties = {
            lootModifier = 2.0,
            message = "This area seems well-stocked..."
        }
    }
    
    -- Add more regions as needed
    -- Use GetMyCoords() in console to get your current position
}

-- Export/Import paths (relative to Zomboid directory)
RegionManager.Config.ExportPath = "RegionManager_Export.json"
RegionManager.Config.ImportPath = "RegionManager_Import.json"

-- ModData key for server-side persistence
RegionManager.Config.MODDATA_KEY = "RegionManager_RegisteredZones"

-- Sandbox option keys
RegionManager.Config.SANDBOX_PREFIX = "RegionManager"

return RegionManager.Config