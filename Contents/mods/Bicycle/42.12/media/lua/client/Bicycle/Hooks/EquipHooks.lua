local BicycleAttachments = require("Bicycle/SaddleBag/Saddlebag")
local BicycleHopOnAction = require("Bicycle/TimedAction/BicycleHopOnAction")
local BicycleUtils = require("Bicycle/Utils")

local originalGrabValid = ISGrabItemAction.isValid

function ISGrabItemAction:isValid()
    local item = self.item:getItem():getType()
    if item == ContainerMap[item] then
		return false;
	end
    if BicycleUtils.isBicycleType(item) then
        return false;
    end
    return originalGrabValid(self)
end

local originalIsUnequipValid = ISUnequipAction.isValid

function ISUnequipAction:isValid()
    if self.item
    and type(self.item.getType) == "function"
    and (BicycleUtils.isBicycleItem(self.item) or self.item:getType() == ContainerMap[self.item:getType()]) then
        return false
    end
    return originalIsUnequipValid(self)
end

local originalIsEquipValid = ISEquipWeaponAction.isValid

function ISEquipWeaponAction:isValid()
    local primaryItem = self.character:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) then self.character:Say(getText("IGUI_Bicycle_HopOffFirst")) return false end
    if self.item
    and type(self.item.getType) == "function"
    and self.item:getType() == ContainerMap[self.item:getType()] then
        return false
    end
    return originalIsEquipValid(self)
end

local originalWearClothing = ISWearClothing.isValid

function ISWearClothing:isValid()
    local item = self.item:getType()
    if item == ContainerMap[item] then
        return true;
    end
    return originalWearClothing(self)
end

local originalGetWearClothesDuration = ISWearClothing.getDuration

function ISWearClothing:getDuration()
    local item = self.item:getType()
    if BicycleUtils.isBicycleType(item) or item == ContainerMap[item] then
        return 0
    end
    return originalGetWearClothesDuration(self)
end

local originalDropItem = ISInventoryPaneContextMenu.onDropItems

function ISInventoryPaneContextMenu.onDropItems(items, player)
    items = ISInventoryPane.getActualItems(items)
    local filteredItems = {}
    local pzPlayer = getSpecificPlayer(player)

    for _, item in ipairs(items) do
        if BicycleUtils.isBicycleItem(item) then
            if pzPlayer and pzPlayer:getVariableBoolean("Bicycle_Riding") then
                -- Ignore drop requests while actively riding to avoid interrupting animations
            else
                if pzPlayer then
                    pzPlayer:setBlockMovement(true)
                    pzPlayer:setVariable("droppingBicycle", "true")
                end
                BicycleClearUpdateHandlers()
                if pzPlayer then
                    local emitter = pzPlayer:getEmitter()
                    emitter:stopSoundByName('Bicycle_Riding')
                    BicycleAttachments.dropContainers(item, pzPlayer)
                else
                    BicycleAttachments.dropContainers(item, nil)
                end
                BicycleUtils.runAfter(0.4, function()
                    if pzPlayer then
                        pzPlayer:setBlockMovement(false)
                        pzPlayer:setVariable("BicycleActive", "false")
                        pzPlayer:setVariable("Bicycle_Stopping", false)
                        pzPlayer:setCanShout(true)
                        pzPlayer:setAllowRun(true)
                        pzPlayer:setForceSprint(false)
                        pzPlayer:setBannedAttacking(false)
                        pzPlayer:setVariable("droppingBicycle", "false")
                        pzPlayer:setIgnoreAutoVault(false)
                        BicycleAttachments.onBikeDropped(pzPlayer, item)
                    end
                end)
                table.insert(filteredItems, item)
            end
        else
            table.insert(filteredItems, item)
        end
    end

    if #filteredItems == 0 then
        return
    end

    return originalDropItem(filteredItems, player)
end

local originalCreate

local function onGameStart()

    originalCreate = ISPlace3DItemCursor.create

    function ISPlace3DItemCursor:create()
        local item = self.items and self.items[1]
        if BicycleUtils.isBicycleItem(item) then
            local player = getSpecificPlayer(0)
            player:removeFromHands(item)
            BicycleClearUpdateHandlers()
            local emitter = player:getEmitter()
            emitter:stopSoundByName('Bicycle_Riding')
            player:setVariable("Bicycle_Riding", "false")
            player:setVariable("BicycleActive", "false")
            player:setVariable("Bicycle_Stopping", false)
            player:setAllowRun(true)
            player:setForceSprint(false)
            player:setCanShout(true)
            player:setBannedAttacking(false)
            player:setIgnoreAutoVault(false)

            BicycleUtils.runAfter(0.2, function()
                local plrQueue = ISTimedActionQueue.getTimedActionQueue(player)
                if not plrQueue or not plrQueue.queue then return end

                for _, action in ipairs(plrQueue.queue) do
                    if plrQueue.queue[1].Type == "ISDropWorldItemAction" then
                        BicycleAttachments.dropContainers(item, player)
                        BicycleAttachments.onBikeDropped(player, item)
                        break
                    end
                    if action.Type == "ISWalkToTimedAction" then
                        action:setOnComplete(function()
                            BicycleAttachments.onBikeDropped(player, item)
                        end)
                        break
                    end
                end
            end)
    end

        return originalCreate(self)
    end
end

Events.OnGameStart.Add(onGameStart)

local originalISEquipPerform = ISEquipWeaponAction.perform

function ISEquipWeaponAction:perform()
    originalISEquipPerform(self)

    local item = self.item
    if not item or type(item.getType) ~= "function" then
        return
    end

    if not BicycleUtils.isBicycleItem(item) then
        return
    end

    local player = self.character
    if not player or player:getVariableBoolean("BicycleActive") then
        return
    end

    BicycleHopOnAction.onCompleteEquip(player, item)
end
