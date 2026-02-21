require("TimedActions/ISUnequipAction")
require("EuryBugs/AnimalWS")
require("EuryBugs/ServerAnimalWS") -- ensure server module is loaded

do
    local _oldComplete = ISUnequipAction.complete
    function ISUnequipAction:complete()
        local animalID

        if isServer and isServer() then
            local item = self.item
            if item and item.getAnimal then
                local animal = item:getAnimal()
                if animal then
                    -- Ensure copyFrom will copy wild=false into the spawned world animal
                    animal:setWild(false)

                    animalID = animal.getOnlineID and animal:getOnlineID() or nil
                    AnimalWildSync.dlog("S", "Drop Animal (pre) id " .. tostring(animalID))
                end
            end
        end

        local ret = _oldComplete(self)

        if (isServer and isServer()) and animalID ~= nil then
            -- Now the world animal should exist (or be about to); force resend/subscription
            AnimalWildSync.Server.forceDirtyInterest(self.character, animalID)
            AnimalWildSync.dlog("S", "Drop Animal (post) forceDirty id " .. tostring(animalID))
        end

        return ret
    end
end