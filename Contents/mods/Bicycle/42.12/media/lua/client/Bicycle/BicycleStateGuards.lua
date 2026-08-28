local BicycleAttachments = require("Bicycle/SaddleBag/Saddlebag")
local BicycleUtils = require("Bicycle/Utils")

local bicycleTypes = BicycleUtils.getBicycleTypes()

local function clearMountedState(player)
    if not player then return end
    local emitter = player.getEmitter and player:getEmitter() or nil
    if emitter then
        emitter:stopSoundByName('Bicycle_Riding')
    end
    if player.setBlockMovement then
        player:setBlockMovement(false)
    end
    if player.setVariable then
        player:setVariable("Bicycle_Riding", "false")
        player:setVariable("BicycleActive", "false")
        player:setVariable("Bicycle_Stopping", false)
        player:setVariable("droppingBicycle", "false")
    end
    if player.setIgnoreAutoVault then
        player:setIgnoreAutoVault(false)
    end
    if player.setAllowRun then
        player:setAllowRun(true)
    end
    if player.setForceSprint then
        player:setForceSprint(false)
    end
    if player.setBannedAttacking then
        player:setBannedAttacking(false)
    end
    if player.setCanShout then
        player:setCanShout(true)
    end
    BicycleClearUpdateHandlers()
end

local function playerHasEquippedBicycle(player)
    if not player then return false end
    local primary = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    local secondary = player.getSecondaryHandItem and player:getSecondaryHandItem() or nil
    if BicycleUtils.isBicycleItem(primary) then
        return true
    end
    if BicycleUtils.isBicycleItem(secondary) then
        return true
    end
    return false
end

local function followInventoryBicycles(player)
    if not player then return end

    local inventory = player.getInventory and player:getInventory() or nil
    if not inventory then return end
    if inventory.containsTypeRecurse then
        local containsBicycle = false
        for _, typeName in ipairs(bicycleTypes) do
            if inventory:containsTypeRecurse(typeName) then
                containsBicycle = true
                break
            end
        end
        if not containsBicycle then
            return
        end
    end

    local seenItems = {}
    local visitedContainers = {}

    local followContainer

    local function followItem(item)
        if not item then return end
        if seenItems[item] then return end

        if BicycleUtils.isBicycleItem(item) then
            seenItems[item] = true
            BicycleAttachments.followPlayer(player, item)
        end

        if item.getInventory then
            local sub = item:getInventory()
            if sub then
                followContainer(sub)
            end
        end
    end

    followContainer = function(container)
        if not container then return end
        if visitedContainers[container] then return end
        visitedContainers[container] = true

        local items = container.getItems and container:getItems() or nil
        if not items then return end
        for i = 0, items:size() - 1 do
            followItem(items:get(i))
        end
    end

    followContainer(inventory)
    followItem(player.getPrimaryHandItem and player:getPrimaryHandItem() or nil)
    followItem(player.getSecondaryHandItem and player:getSecondaryHandItem() or nil)
end

local function ensurePlayerUnmounted(player)
    if not player then return end
    local active = player.getVariableBoolean and player:getVariableBoolean("BicycleActive") or false
    local riding = player.getVariableBoolean and player:getVariableBoolean("Bicycle_Riding") or false
    if not active and not riding then
        return
    end
    if playerHasEquippedBicycle(player) then
        return
    end

    clearMountedState(player)

    local worldObj = BicycleAttachments.FindBicycle(player)
    local bikeItem = worldObj and worldObj.getItem and worldObj:getItem() or nil
    if not bikeItem then
        local inventory = player.getInventory and player:getInventory() or nil
        if inventory and inventory.getFirstTypeRecurse then
            for _, typeName in ipairs(bicycleTypes) do
                bikeItem = inventory:getFirstTypeRecurse(typeName)
                if bikeItem then
                    break
                end
            end
        end
    end
    if bikeItem then
        BicycleAttachments.onBikeDropped(player, bikeItem)
    end
end

local function onPlayerUpdate(player)
    followInventoryBicycles(player)
    ensurePlayerUnmounted(player)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
