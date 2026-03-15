BAM = BAM or {}


function BAM:OnMechanicActionDone(success)
    -- OnMechanicActionDone is only ever called in multiplayer, but if its called in singleplayer, do nothing
    if not isClient() then return end
    if not BAM.IsCurrentlyTraining then return end
    if not BAM.Vehicle or not BAM.LastWorkedPart then return end

    local player = self
    --DebugLog.log("-> Mechanic action done! Player: " .. tostring(player) .. " " .. BAM.LastWorkedPart:getId() .. " " .. BAM.LastWorkedActionType .. " Success: " .. tostring(success))

    -- If the action was successful, save the XP data and sync to server
    -- TODO: This should be done even without training, but we don't have access to the currently worked on part in that case
    if success then
        BAM.RecordXPAction(player, BAM.Vehicle, BAM.LastWorkedPart, BAM.LastWorkedActionType)
        --DebugLog.log("BAM: XP Cooldown saved for part " .. BAM.LastWorkedPart:getId())
    end

    -- Start a tick countdown, after which 'workOnNextPart' is called to continue the training
    -- This gives the server enough time to update the game state
    BAM.WorkOnNextPartInXTicks(20)  -- 20 ticks is approx 0.33 seconds
    --DebugLog.log("Waiting " .. BAM.WorkDelayTimer .. " ticks before working on next part...")
end


-- The Tick Handler: Runs every single frame (approx 60 times/sec)
local function BAM_OnTick()
    -- Fail fast. If not training, do nothing immediately.
    if not BAM.IsCurrentlyTraining then return end

    -- Only run logic if the WorkDelayTimer is active (greater than 0)
    if BAM.WorkDelayTimer > 0 then
        BAM.WorkDelayTimer = BAM.WorkDelayTimer - 1

        -- When the timer hits exactly 0, execute the delayed action
        if BAM.WorkDelayTimer == 0 then
            --DebugLog.log("Delay finished: executing workOnNextPart...")
            BAM.workOnNextPart(getPlayer(), BAM.Vehicle)
        end
    end

    -- Stop here if in MP
    if isClient() then return end

    -- Only run logic if the WorkDelayTimer is active (greater than 0)
    if BAM.GameSpeedCheckTimer > 0 then
        BAM.GameSpeedCheckTimer = BAM.GameSpeedCheckTimer - 1

        -- When the timer hits exactly 0, execute the delayed action
        if BAM.GameSpeedCheckTimer == 0 then
            BAM.RestoreGameSpeed()
        end
    end
end


-- If the player presses Escape/Cancel or any movement keys, stop the training immediately.
local function BAM_StopTrainingOnKey(key)
    if not BAM.IsCurrentlyTraining then return end

    local core = getCore()

    -- 1. Get the current keybindings for Escape/Cancel
    local cancelKey = core:getKey("CancelAction")
    local escKey = Keyboard.KEY_ESCAPE

    -- 2. Get the current keybindings for Movement
    local forwardKey = core:getKey("Forward")
    local backwardKey = core:getKey("Backward")
    local leftKey = core:getKey("Left")
    local rightKey = core:getKey("Right")

    -- 3. Check if the pressed key matches ANY of the above
    if key == cancelKey or key == escKey or
       key == forwardKey or key == backwardKey or
       key == leftKey or key == rightKey then
        DebugLog.log("BAM: Player pressed an interrupt key! Aborting mechanics training.")
        BAM.StopMechanicsTraining(nil)
    end
end


-- Register events
Events.OnTick.Add(BAM_OnTick)
Events.OnKeyStartPressed.Add(BAM_StopTrainingOnKey)
if isClient() then
    -- Only register this event if we are running in multiplayer
    Events.OnMechanicActionDone.Add(BAM.OnMechanicActionDone)
end
