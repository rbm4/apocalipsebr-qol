VIH_Main = VIH_Main or {}

VIH_Main.Config = {
    enabled = true,
    checkInterval = 60, -- ticks (1 second)
    maxStuckTime = 180, -- ticks (3 seconds)
    autoCancel = true,
    teleportToVehicle = true,
    maxTeleportDistance = 3, -- tiles
    debug = true
}

-- Track player state
VIH_Main.lastPosition = {x = 0, y = 0, z = 0}
VIH_Main.stuckTimer = 0
VIH_Main.wasInteractingWithVehicle = false
VIH_Main.targetVehicle = nil


-- Check if player is stuck trying to interact with vehicle
function VIH_Main.isStuckOnVehicle(player)
    -- Check if player has active timed action
    if not ISTimedActionQueue.hasAction(player) then
        return false
    end
    
    -- Check if player is trying to enter/exit vehicle
    local action = ISTimedActionQueue.getFirstAction(player)
    if not action then return false end
    
    local actionType = action.Type
    if actionType == "ISEnterVehicle" or 
       actionType == "ISExitVehicle" or
       actionType == "ISPathFindAction" then
        
        -- Check if player hasn't moved
        local currentX = math.floor(player:getX())
        local currentY = math.floor(player:getY())
        local currentZ = math.floor(player:getZ())
        
        if currentX == VIH_Main.lastPosition.x and 
           currentY == VIH_Main.lastPosition.y and
           currentZ == VIH_Main.lastPosition.z then
            return true
        end
    end
    
    return false
end

-- Get nearby vehicle player is trying to interact with
function VIH_Main.getNearbyVehicle(player)
    local vehicles = player:getVehicleList()
    if not vehicles then return nil end
    
    local px = player:getX()
    local py = player:getY()
    local closestVehicle = nil
    local closestDist = 999
    
    for i=0, vehicles:size()-1 do
        local vehicle = vehicles:get(i)
        if vehicle then
            local vx = vehicle:getX()
            local vy = vehicle:getY()
            local dist = math.sqrt((px-vx)^2 + (py-vy)^2)
            
            if dist < closestDist and dist < 5 then
                closestDist = dist
                closestVehicle = vehicle
            end
        end
    end
    
    return closestVehicle, closestDist
end

-- Cancel stuck action and optionally teleport
function VIH_Main.fixStuckInteraction(player)
    if VIH_Main.Config.debug then
        print("[VIH] Player stuck on vehicle interaction - fixing...")
    end
    
    -- Cancel all queued actions
    ISTimedActionQueue.clear(player)
    
    -- Stop movement
    player:StopAllActionQueue()
    player:clearVariable("BumpedCar")
    
    if VIH_Main.Config.teleportToVehicle and VIH_Main.targetVehicle then
        local vehicle = VIH_Main.targetVehicle
        local dist = VIH_Main.getNearbyVehicle(player)
        
        -- Only teleport if stuck close to vehicle
        if vehicle and dist and dist < VIH_Main.Config.maxTeleportDistance then
            -- Find valid adjacent square near vehicle
            local vx = math.floor(vehicle:getX())
            local vy = math.floor(vehicle:getY())
            local vz = math.floor(vehicle:getZ())
            
            -- Try positions around vehicle
            local offsets = {
                {0, -1}, {0, 1}, {-1, 0}, {1, 0},
                {-1, -1}, {-1, 1}, {1, -1}, {1, 1}
            }
            
            for _, offset in ipairs(offsets) do
                local tx = vx + offset[1]
                local ty = vy + offset[2]
                local square = getCell():getGridSquare(tx, ty, vz)
                
                if square and square:isFree(false) then
                    player:setX(tx)
                    player:setY(ty)
                    player:setZ(vz)
                    
                    if VIH_Main.Config.debug then
                        print("[VIH] Teleported player to valid position near vehicle")
                    end
                    break
                end
            end
        end
    end
    
    -- Reset stuck timer
    VIH_Main.stuckTimer = 0
    VIH_Main.targetVehicle = nil
    
    -- Show message to player
    player:Say("Vehicle interaction fixed")
    HaloTextHelper.addText(player, "Unstuck!", getCore():getGoodHighlitedColor())
end

-- Main check function
function VIH_Main.checkForStuck()
    if not VIH_Main.Config.enabled then return end
    
    local player = getPlayer()
    if not player or player:isDead() then return end
    
    -- Update last position
    local currentX = math.floor(player:getX())
    local currentY = math.floor(player:getY())
    local currentZ = math.floor(player:getZ())
    
    if VIH_Main.isStuckOnVehicle(player) then
        VIH_Main.stuckTimer = VIH_Main.stuckTimer + VIH_Main.Config.checkInterval
        
        -- Store target vehicle if not already stored
        if not VIH_Main.targetVehicle then
            VIH_Main.targetVehicle = VIH_Main.getNearbyVehicle(player)
        end
        
        if VIH_Main.Config.debug and VIH_Main.stuckTimer % 120 == 0 then
            print("[VIH] Player stuck for " .. (VIH_Main.stuckTimer/60) .. " seconds")
        end
        
        -- Auto-fix if stuck too long
        if VIH_Main.Config.autoCancel and VIH_Main.stuckTimer >= VIH_Main.Config.maxStuckTime then
            VIH_Main.fixStuckInteraction(player)
        end
    else
        -- Reset timer if not stuck
        if VIH_Main.stuckTimer > 0 then
            VIH_Main.stuckTimer = 0
            VIH_Main.targetVehicle = nil
        end
    end
    
    -- Update position tracking
    VIH_Main.lastPosition.x = currentX
    VIH_Main.lastPosition.y = currentY
    VIH_Main.lastPosition.z = currentZ
end

-- Keybind to manually unstuck
function VIH_Main.onKeyPressed(key)
    if key == Keyboard.KEY_U then -- Press U to unstuck
        local player = getPlayer()
        if player and VIH_Main.isStuckOnVehicle(player) then
            VIH_Main.fixStuckInteraction(player)
        end
    end
end

-- Initialize
function VIH_Main.initialize()
    print("[VIH] Vehicle Interaction Helper initialized")
    print("[VIH] Auto-unstuck after " .. (VIH_Main.Config.maxStuckTime/60) .. " seconds")
    print("[VIH] Press U to manually unstuck from vehicle")
    
    local player = getPlayer()
    if player then
        VIH_Main.lastPosition.x = math.floor(player:getX())
        VIH_Main.lastPosition.y = math.floor(player:getY())
        VIH_Main.lastPosition.z = math.floor(player:getZ())
    end
end

-- Keybind to manually unstuck
function VIH_Main.onKeyPressedE(key)
    if key == Keyboard.KEY_E then -- Press U to unstuck
        local player = getPlayer()
        if player and VIH_Main.isStuckOnVehicle(player) then
            VIH_Main.fixStuckInteraction(player)
        end
    end
end

-- Register events
Events.OnGameStart.Add(VIH_Main.initialize)
Events.OnKeyPressed.Add(VIH_Main.onKeyPressedE) -- Adjust frequency as needed
Events.OnKeyPressed.Add(VIH_Main.onKeyPressed)

return VIH_Main