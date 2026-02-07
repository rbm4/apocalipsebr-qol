-- ============================================================================
-- File: media/lua/shared/RegionManager_Config.lua
-- Shared configuration for custom region management
-- ============================================================================

RegionManager = RegionManager or {}
RegionManager.Config = RegionManager.Config or {}

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
    }
}

-- Region definitions
-- Each region can have multiple categories applied
RegionManager.Config.Regions = {
    -- Example: Muldraugh Downtown PVP
    {
        id = "muldraugh_downtown_pvp",
        name = "Downtown Muldraugh Arena",
        x = 10500,
        y = 9700,
        z = 0,
        width = 100,
        height = 100,
        categories = {"PVP"},
        enabled = true,
        customProperties = {
            -- Override category defaults here
            pvpEnabled = true,
            message = "You've entered a PVP zone! Watch your back!"
        }
    },
    
    -- Example: Louisville Sprinter Zone
    {
        id = "louisville_sprinters",
        name = "Louisville Outbreak Zone",
        x = 12000,
        y = 2000,
        z = 0,
        width = 300,
        height = 300,
        categories = {"SPRINTERS", "DEADZONE"},
        enabled = true,
        customProperties = {
            zombieSpeed = 3,
            zombieDensity = 5.0,
            message = "WARNING: Infected runners detected in this area!"
        }
    },
    
    -- Example: West Point Safe Zone
    {
        id = "westpoint_safezone",
        name = "West Point Sanctuary",
        x = 11500,
        y = 6900,
        z = 0,
        width = 50,
        height = 50,
        categories = {"SAFEZONE"},
        enabled = true,
        customProperties = {
            noZombies = true,
            pvpEnabled = false,
            message = "You've entered a safe zone. No combat allowed."
        }
    },
    
    -- Example: Rosewood High Loot
    {
        id = "rosewood_loot",
        name = "Rosewood Supply Cache",
        x = 8100,
        y = 11600,
        z = 0,
        width = 80,
        height = 80,
        categories = {"LOOTBONUS"},
        enabled = true,
        customProperties = {
            lootModifier = 2.0,
            message = "This area seems well-stocked..."
        }
    }
    
    -- Add more regions as needed
}

-- Export/Import paths (relative to Zomboid directory)
RegionManager.Config.ExportPath = "RegionManager_Export.json"
RegionManager.Config.ImportPath = "RegionManager_Import.json"

-- ModData key for server-side persistence
RegionManager.Config.MODDATA_KEY = "RegionManager_RegisteredZones"

-- Sandbox option keys
RegionManager.Config.SANDBOX_PREFIX = "RegionManager"

return RegionManager.Config