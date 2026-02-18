-- Zombie Kill Counter & Player Tracker Configuration
-- This file contains configuration settings for kill tracking and player position features

ZKC_Config = ZKC_Config or {}

-- Storage Configuration (File-based data export)
ZKC_Config.Storage = {
    -- Filename for data export (will be in Zomboid's root directory)
    -- Your external API should read and clear this file periodically
    filename = "ZKC_PlayerData.jsonl",
    
    -- Enable/disable debug logging
    debug = true,
    
    -- Note: File format is newline-delimited JSON (JSONL)
    -- Each line is a complete JSON object that can be parsed independently
}

-- Batch Configuration (for efficiency)
ZKC_Config.Batch = {
    -- Enable batching to reduce API calls
    enabled = true,
    
    -- Maximum kills to batch before sending (OR time-based send)
    maxBatchSize = 100,
    
    -- Maximum time in seconds before forcing a send (even with 0 kills)
    maxBatchTimeSeconds = 60, -- 1 minute
}

-- Player Data Configuration
ZKC_Config.PlayerData = {
    -- Include player position in updates
    includePosition = true,
    
    -- Include health and status
    includeHealth = true,
    
    -- Include vehicle information
    includeVehicle = true,
    
    -- Include nearby entity counts (zombies/players)
    includeNearbyEntities = true,
    
    -- Radius for nearby entity detection (tiles)
    nearbyEntityRadius = 50,
    
    -- Include character info (profession, survival time)
    includeCharacterInfo = true,
    
    -- Only send if player moved this many tiles (0 = always send)
    minimumMovementDistance = 0,
}

-- Performance Settings
ZKC_Config.Performance = {
    -- Skip expensive checks if FPS drops below this
    skipChecksUnderFPS = 30,
    
    -- How often to check for updates (in ticks, 60 = 1 second)
    updateCheckInterval = 600, -- Check every 10 seconds
}

-- Feature toggle
ZKC_Config.enabled = true

return ZKC_Config
