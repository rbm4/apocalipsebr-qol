-- ============================================================================
-- File: media/lua/server/RegionManager_AutoSafeZones.lua
-- Automatic safe zone generation by subtracting PVP zones from entire map
-- ============================================================================

if not isServer() then
    return
end

RegionManager.AutoSafeZones = RegionManager.AutoSafeZones or {}

local function log(msg)
    RegionManager.Log("AutoSafeZones", msg)
end

-- Base map coordinates (entire playable area)
local BASE_MAP = {
    x1 = -1780,
    y1 = -2272,
    x2 = 20455,
    y2 = 16541
}

-- Rectangle subtraction algorithm
-- Subtracts rectB from rectA, returns array of remaining rectangles
local function subtractRectangle(rectA, rectB)
    local result = {}
    
    -- Calculate intersection
    local intX1 = math.max(rectA.x1, rectB.x1)
    local intY1 = math.max(rectA.y1, rectB.y1)
    local intX2 = math.min(rectA.x2, rectB.x2)
    local intY2 = math.min(rectA.y2, rectB.y2)
    
    -- No intersection, return original rectangle
    if intX1 >= intX2 or intY1 >= intY2 then
        table.insert(result, {
            x1 = rectA.x1,
            y1 = rectA.y1,
            x2 = rectA.x2,
            y2 = rectA.y2
        })
        return result
    end
    
    -- Generate up to 4 rectangles around the intersection
    
    -- Top strip (above intersection)
    if rectA.y1 < intY1 then
        table.insert(result, {
            x1 = rectA.x1,
            y1 = rectA.y1,
            x2 = rectA.x2,
            y2 = intY1
        })
    end
    
    -- Bottom strip (below intersection)
    if intY2 < rectA.y2 then
        table.insert(result, {
            x1 = rectA.x1,
            y1 = intY2,
            x2 = rectA.x2,
            y2 = rectA.y2
        })
    end
    
    -- Left strip (between top and bottom strips)
    if rectA.x1 < intX1 then
        table.insert(result, {
            x1 = rectA.x1,
            y1 = intY1,
            x2 = intX1,
            y2 = intY2
        })
    end
    
    -- Right strip (between top and bottom strips)
    if intX2 < rectA.x2 then
        table.insert(result, {
            x1 = intX2,
            y1 = intY1,
            x2 = rectA.x2,
            y2 = intY2
        })
    end
    
    return result
end

-- Validate that a rectangle has valid dimensions
local function isValidRectangle(rect)
    return rect.x2 > rect.x1 and rect.y2 > rect.y1
end

-- Calculate area of a rectangle
local function calculateArea(rect)
    return (rect.x2 - rect.x1) * (rect.y2 - rect.y1)
end

-- Merge adjacent rectangles to reduce total count (optimization)
local function mergeAdjacentRectangles(rectangles)
    -- Simple horizontal merge: if two rectangles share same Y coords and X edges touch
    local merged = true
    
    while merged do
        merged = false
        for i = 1, #rectangles do
            for j = i + 1, #rectangles do
                local rectA = rectangles[i]
                local rectB = rectangles[j]
                
                if rectA and rectB then
                    -- Check if they can be merged horizontally
                    if rectA.y1 == rectB.y1 and rectA.y2 == rectB.y2 then
                        if rectA.x2 == rectB.x1 then
                            -- Merge B into A (A is to the left of B)
                            rectA.x2 = rectB.x2
                            table.remove(rectangles, j)
                            merged = true
                            break
                        elseif rectB.x2 == rectA.x1 then
                            -- Merge A into B (B is to the left of A)
                            rectA.x1 = rectB.x1
                            table.remove(rectangles, j)
                            merged = true
                            break
                        end
                    end
                    
                    -- Check if they can be merged vertically
                    if rectA.x1 == rectB.x1 and rectA.x2 == rectB.x2 then
                        if rectA.y2 == rectB.y1 then
                            -- Merge B into A (A is above B)
                            rectA.y2 = rectB.y2
                            table.remove(rectangles, j)
                            merged = true
                            break
                        elseif rectB.y2 == rectA.y1 then
                            -- Merge A into B (B is above A)
                            rectA.y1 = rectB.y1
                            table.remove(rectangles, j)
                            merged = true
                            break
                        end
                    end
                end
            end
            
            if merged then break end
        end
    end
    
    return rectangles
end

-- Main function: Generate safe zones by subtracting PVP zones from base map
function RegionManager.AutoSafeZones.generateSafeZones(configuredRegions)
    log("=== Starting Automatic Safe Zone Generation ===")
    log("Base map: (" .. BASE_MAP.x1 .. "," .. BASE_MAP.y1 .. ") to (" .. BASE_MAP.x2 .. "," .. BASE_MAP.y2 .. ")")
    
    -- Start with the entire map as one safe zone
    local safeZones = {
        {
            x1 = BASE_MAP.x1,
            y1 = BASE_MAP.y1,
            x2 = BASE_MAP.x2,
            y2 = BASE_MAP.y2
        }
    }
    
    -- Extract PVP zones from configured regions
    local pvpZones = {}
    for _, region in ipairs(configuredRegions) do
        if region.enabled then
            -- Check if this region has PVP enabled
            local isPvpZone = false
            for _, catName in ipairs(region.categories or {}) do
                local category = RegionManager.Config.Categories[catName]
                if category and category.pvpEnabled == true then
                    isPvpZone = true
                    break
                end
            end
            
            -- Check custom properties override
            if region.customProperties and region.customProperties.pvpEnabled ~= nil then
                isPvpZone = region.customProperties.pvpEnabled == true
            end
            
            if isPvpZone then
                local minX = math.min(region.x1, region.x2)
                local maxX = math.max(region.x1, region.x2)
                local minY = math.min(region.y1, region.y2)
                local maxY = math.max(region.y1, region.y2)
                
                table.insert(pvpZones, {
                    x1 = minX,
                    y1 = minY,
                    x2 = maxX,
                    y2 = maxY,
                    id = region.id
                })
                
                log("Found PVP zone: " .. region.id .. " at (" .. minX .. "," .. minY .. ") to (" .. maxX .. "," .. maxY .. ")")
            end
        end
    end
    
    log("Found " .. #pvpZones .. " PVP zones to subtract")
    
    -- Subtract each PVP zone from all current safe zones
    for _, pvpZone in ipairs(pvpZones) do
        local newSafeZones = {}
        
        for _, safeZone in ipairs(safeZones) do
            local remainingRects = subtractRectangle(safeZone, pvpZone)
            
            -- Add all valid remaining rectangles
            for _, rect in ipairs(remainingRects) do
                if isValidRectangle(rect) then
                    table.insert(newSafeZones, rect)
                end
            end
        end
        
        safeZones = newSafeZones
        log("After subtracting " .. pvpZone.id .. ": " .. #safeZones .. " safe zone fragments")
    end
    
    -- Optimize by merging adjacent rectangles
    log("Merging adjacent rectangles...")
    safeZones = mergeAdjacentRectangles(safeZones)
    log("After merging: " .. #safeZones .. " safe zones")
    
    -- Calculate total coverage
    local totalSafeArea = 0
    for _, zone in ipairs(safeZones) do
        totalSafeArea = totalSafeArea + calculateArea(zone)
    end
    
    local baseArea = calculateArea(BASE_MAP)
    local coveragePercent = (totalSafeArea / baseArea) * 100
    
    log("Generated " .. #safeZones .. " automatic safe zones")
    log("Coverage: " .. string.format("%.2f", coveragePercent) .. "% of map area")
    
    -- Convert safe zones to region format
    local autoRegions = {}
    for i, zone in ipairs(safeZones) do
        table.insert(autoRegions, {
            id = "AutoSafeZone_" .. i,
            name = "Safe Zone " .. i,
            x1 = zone.x1,
            y1 = zone.y1,
            x2 = zone.x2,
            y2 = zone.y2,
            z = 0, -- Ground level
            enabled = true,
            categories = {"AUTOSAFE"},
            customProperties = {
                pvpEnabled = false,
                announceEntry = false,
                announceExit = false,
                color = {r=0, g=200, b=255}
            }
        })
    end
    
    log("=== Safe Zone Generation Complete ===")
    
    return autoRegions
end

-- Merge auto-generated safe zones with configured regions
function RegionManager.AutoSafeZones.mergeWithConfigured(configuredRegions)
    local autoSafeZones = RegionManager.AutoSafeZones.generateSafeZones(configuredRegions)
    
    -- Combine: auto-generated safe zones first, then configured regions
    local mergedRegions = {}
    
    -- Add auto-generated safe zones
    for _, region in ipairs(autoSafeZones) do
        table.insert(mergedRegions, region)
    end
    
    -- Add configured regions
    for _, region in ipairs(configuredRegions) do
        table.insert(mergedRegions, region)
    end
    
    log("Merged regions: " .. #autoSafeZones .. " auto-generated + " .. #configuredRegions .. " configured = " .. #mergedRegions .. " total")
    
    return mergedRegions
end

log("RegionManager AutoSafeZones module loaded")

return RegionManager.AutoSafeZones
