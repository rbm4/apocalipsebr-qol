require "AutoMechanics"

--this handles the case pathfinding returns failed by error to the cost moving to the infinity of time when it should fail
local vanilla_ISPathFindAction_stop = ISPathFindAction.stop
function ISPathFindAction:stop()
    vanilla_ISPathFindAction_stop(self);
    if AutoMechanics.isAutoMechanicsTrain_started() then
        if self.character:hasHitReaction() then-- attacked by Z
            AutoMechanics.StopMechanicsTrain(true);--stop and freeze
        else-- failed pathfinding
            --try going away from car center with 1 distance
            local playerPosX = self.character:getX();
            local playerPosY = self.character:getY();
            local playerPosZ = self.character:getZ() or 0;
            local vehiclePosX = AutoMechanics.getVehicle():getX();
            local vehiclePosY = AutoMechanics.getVehicle():getY();
            local deltaX = playerPosX - vehiclePosX;
            local deltaY = playerPosY - vehiclePosY;
            local normH = math.sqrt(deltaX*deltaX+deltaY*deltaY);
            local ratio = 0;
            if normH > 0 then  ratio = 1./normH; end
            local targetX = playerPosX + deltaX * ratio;
            local targetY = playerPosY + deltaY * ratio;
            local targetZ = playerPosZ;
            
            if AutoMechanics.getVerbose() then print ("ISPathFindAction:stop."
                .." "..targetX
                .." "..targetY
                .." "..targetZ
                .." "..self.character:getPathFindBehavior2():getTargetX()
                .." "..self.character:getPathFindBehavior2():getTargetY()
                .." "..self.character:getPathFindBehavior2():getTargetZ()
            ); end
            
            ISTimedActionQueue.add(ISPathFindAction:pathToLocationF(self.character, targetX, targetY, targetZ))
            
            AutoMechanics.doPendingJob();--and retry
        end
    end
end

local vanilla_ISPathFindAction_pathToVehicleArea = ISPathFindAction.pathToVehicleArea
function ISPathFindAction:pathToVehicleArea_inactive(character, vehicle, areaId)
    local o = vanilla_ISPathFindAction_pathToVehicleArea(self, character, vehicle, areaId)
    o.ignoreAction = true--inhibits the action when adding to queue
    return o
end

