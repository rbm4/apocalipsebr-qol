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

---@class Rect
---@field x1 number
---@field y1 number
---@field x2 number
---@field y2 number
---@field id? string Only present on PVP zone rects

-- Base map coordinates (entire playable area)
---@type Rect
local BASE_MAP = {
    x1 = -1780,
    y1 = -2272,
    x2 = 20455,
    y2 = 16541
}

-- Rectangle subtraction algorithm (INCLUSIVE coordinates: both x1,y1 and x2,y2 are part of the rectangle)
-- Subtracts rectB from rectA, returns array of remaining rectangles
---@param rectA Rect
---@param rectB Rect
---@return Rect[]
local function subtractRectangle(rectA, rectB)
    local result = {}
    
    -- Calculate intersection (inclusive boundaries)
    local intX1 = math.max(rectA.x1, rectB.x1)
    local intY1 = math.max(rectA.y1, rectB.y1)
    local intX2 = math.min(rectA.x2, rectB.x2)
    local intY2 = math.min(rectA.y2, rectB.y2)
    
    -- No intersection (inclusive: overlap exists when intX1 <= intX2 AND intY1 <= intY2)
    if intX1 > intX2 or intY1 > intY2 then
        table.insert(result, {
            x1 = rectA.x1,
            y1 = rectA.y1,
            x2 = rectA.x2,
            y2 = rectA.y2
        })
        return result
    end
    
    -- Generate up to 4 rectangles around the intersection.
    -- Each strip is adjusted by ±1 so boundary tiles belong ONLY to the intersection,
    -- preventing 1-tile overlaps between safe zones and PVP zones.
    
    -- Top strip (above intersection, full width)
    if rectA.y1 < intY1 then
        table.insert(result, {
            x1 = rectA.x1,
            y1 = rectA.y1,
            x2 = rectA.x2,
            y2 = intY1 - 1
        })
    end
    
    -- Bottom strip (below intersection, full width)
    if intY2 < rectA.y2 then
        table.insert(result, {
            x1 = rectA.x1,
            y1 = intY2 + 1,
            x2 = rectA.x2,
            y2 = rectA.y2
        })
    end
    
    -- Left strip (between top and bottom strips, intersection height)
    if rectA.x1 < intX1 then
        table.insert(result, {
            x1 = rectA.x1,
            y1 = intY1,
            x2 = intX1 - 1,
            y2 = intY2
        })
    end
    
    -- Right strip (between top and bottom strips, intersection height)
    if intX2 < rectA.x2 then
        table.insert(result, {
            x1 = intX2 + 1,
            y1 = intY1,
            x2 = rectA.x2,
            y2 = intY2
        })
    end
    
    return result
end

-- Validate that a rectangle has valid dimensions (inclusive: single-tile rect is valid)
---@param rect Rect
---@return boolean
local function isValidRectangle(rect)
    return rect.x2 >= rect.x1 and rect.y2 >= rect.y1
end

-- Calculate area of a rectangle (inclusive: a (0,0)-(2,2) rect has 3x3 = 9 tiles)
---@param rect Rect
---@return number
local function calculateArea(rect)
    return (rect.x2 - rect.x1 + 1) * (rect.y2 - rect.y1 + 1)
end

-- Check whether two rectangles overlap (inclusive coordinates)
---@param a Rect
---@param b Rect
---@return boolean
local function rectanglesOverlap(a, b)
    return a.x1 <= b.x2 and a.x2 >= b.x1 and a.y1 <= b.y2 and a.y2 >= b.y1
end

-- Merge adjacent rectangles to reduce total count (optimization)
-- Only merges when the resulting rectangle does not overlap any PVP zone.
---@param rectangles Rect[]
---@param pvpZones Rect[]
---@return Rect[]
local function mergeAdjacentRectangles(rectangles, pvpZones)
    -- Inclusive adjacency: rect ending at x=N is adjacent to rect starting at x=N+1
    local merged = true
    
    while merged do
        merged = false
        for i = 1, #rectangles do
            for j = i + 1, #rectangles do
                local rectA = rectangles[i]
                local rectB = rectangles[j]
                
                if rectA and rectB then
                    local candidate = nil
                    
                    -- Check if they can be merged horizontally (same height, adjacent X)
                    if rectA.y1 == rectB.y1 and rectA.y2 == rectB.y2 then
                        if rectA.x2 + 1 == rectB.x1 then
                            candidate = { x1 = rectA.x1, y1 = rectA.y1, x2 = rectB.x2, y2 = rectA.y2 }
                        elseif rectB.x2 + 1 == rectA.x1 then
                            candidate = { x1 = rectB.x1, y1 = rectA.y1, x2 = rectA.x2, y2 = rectA.y2 }
                        end
                    end
                    
                    -- Check if they can be merged vertically (same width, adjacent Y)
                    if not candidate and rectA.x1 == rectB.x1 and rectA.x2 == rectB.x2 then
                        if rectA.y2 + 1 == rectB.y1 then
                            candidate = { x1 = rectA.x1, y1 = rectA.y1, x2 = rectA.x2, y2 = rectB.y2 }
                        elseif rectB.y2 + 1 == rectA.y1 then
                            candidate = { x1 = rectA.x1, y1 = rectB.y1, x2 = rectA.x2, y2 = rectA.y2 }
                        end
                    end
                    
                    -- Only merge if the result does not overlap any PVP zone
                    if candidate then
                        local safe = true
                        for _, pvp in ipairs(pvpZones or {}) do
                            if rectanglesOverlap(candidate, pvp) then
                                safe = false
                                break
                            end
                        end
                        if safe then
                            rectangles[i] = candidate
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
---@param configuredRegions RegionDefinition[]
---@return RegionDefinition[] autoRegions Auto-generated safe zone regions
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
    
    -- Optimize by merging adjacent rectangles (PVP-zone-aware)
    log("Merging adjacent rectangles...")
    safeZones = mergeAdjacentRectangles(safeZones, pvpZones)
    log("After merging: " .. #safeZones .. " safe zones")
    
    -- Final validation: re-subtract any overlapping PVP zones from safe zones.
    -- This is a safety net in case subtraction or merge introduced any overlap.
    -- local overlapFixed = false
    -- for pass = 1, 3 do -- max 3 passes to resolve cascading issues
    --     local hadOverlap = false
    --     for _, pvpZone in ipairs(pvpZones) do
    --         local newSafeZones = {}
    --         for _, safeZone in ipairs(safeZones) do
    --             if rectanglesOverlap(safeZone, pvpZone) then
    --                 -- This safe zone overlaps a PVP zone — split it
    --                 hadOverlap = true
    --                 log("Validation pass " .. pass .. ": fixing overlap between safe zone and PVP " .. (pvpZone.id or "?"))
    --                 local fragments = subtractRectangle(safeZone, pvpZone)
    --                 for _, frag in ipairs(fragments) do
    --                     if isValidRectangle(frag) then
    --                         table.insert(newSafeZones, frag)
    --                     end
    --                 end
    --             else
    --                 table.insert(newSafeZones, safeZone)
    --             end
    --         end
    --         safeZones = newSafeZones
    --     end
    --     if not hadOverlap then
    --         log("Validation pass " .. pass .. ": no overlaps found")
    --         break
    --     else
    --         overlapFixed = true
    --     end
    -- end
    -- if overlapFixed then
    --     log("Overlaps were detected and fixed. Final safe zone count: " .. #safeZones)
    -- end
    
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
---@param configuredRegions RegionDefinition[]
---@return RegionDefinition[] mergedRegions All regions (auto-safe + configured)
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
