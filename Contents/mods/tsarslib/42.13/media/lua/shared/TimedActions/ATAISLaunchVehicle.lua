require "TimedActions/ISBaseTimedAction"

local CommonCommands = {}


ATAISLaunchVehicle = ISBaseTimedAction:derive("ATAISLaunchVehicle")


function ATAISLaunchVehicle:isValid()
    return self.trailer and not self.trailer:isRemovedFromWorld();
end

function ATAISLaunchVehicle:update()
    self.character:faceThisObject(self.trailer)
    -- speed 1 = 1, 2 = 5, 3 = 20, 4 = 40
    self.character:setMetabolicTarget(Metabolics.HeavyWork);
end

function ATAISLaunchVehicle:start()
    setGameSpeed(1)
    self:setActionAnim("Loot")
    self.trailer:getEmitter():playSound("ATAVehicleWrecker")
end

function ATAISLaunchVehicle:stop()
    self.trailer:getEmitter():stopSoundByName("ATAVehicleWrecker")
    ISBaseTimedAction.stop(self)
end

function ATAISLaunchVehicle:perform()
    setGameSpeed(1)
    self.trailer:getEmitter():stopSoundByName("ATAVehicleWrecker")
    -- self.trailer:getEmitter():stopSoundByName("boat_launching")
    ISBaseTimedAction.perform(self)
end


function ATAISLaunchVehicle:complete()
    local trailer = self.trailer
    if not trailer then
        print("ERROR: Trailer not found! launchVehicle")
        return false
    end

    local wreckerPart = trailer:getPartById("ATAVehicleWrecker")
    if not wreckerPart then
        wreckerPart = trailer:getPartById("ATA2VehicleWrecker")
    end
    if not wreckerPart then
        print("ERROR: Wrecker part not found! launchVehicle")
        return false
    end
    
    local scriptName = wreckerPart:getModData()["scriptName"]
    if not scriptName then
        print("ERROR: No scriptName in wrecker ModData! launchVehicle")
        return false
    end

    local square = self.square
    if not square then
        print("ERROR: square not found! launchVehicle")
        return false
    end
    
    local vehicle = addVehicleDebug(scriptName, IsoDirections.N, trailer:getSkinIndex(), square)
    if not vehicle then
        print("ERROR: Failed to spawn vehicle! launchVehicle")
        return
    end

    vehicle:setAngles(trailer:getAngleX(), trailer:getAngleY(), trailer:getAngleZ())

    -- Restore skin
    local skinIndex = wreckerPart:getModData()["skin"]
    if skinIndex ~= nil then
        vehicle:setSkinIndex(skinIndex)
        vehicle:updateSkin()
    end

    -- Restore color
    local colH, colS, colV = wreckerPart:getModData()["h"], wreckerPart:getModData()["s"], wreckerPart:getModData()["v"]
    if colH ~= nil and colS ~= nil and colV ~= nil then
        vehicle:setColorHSV(colH, colS, colV)
        vehicle:transmitColorHSV()
    end

    -- Restore parts
    if trailer:getPartById("ATAVehicleWrecker") then
        CommonCommands.exchangePartsTrailerToVehicle(vehicle, trailer)
    elseif trailer:getPartById("ATA2VehicleWrecker") then
        CommonCommands.exchangePartsTrailerToVehicle2(vehicle, trailer, playerObj)
    end

    -- Clean up wrecker part
    wreckerPart:setInventoryItem(nil)
    trailer:transmitPartItem(wreckerPart)

    -- Delete keys in nearby area with improved error handling
    local xx = vehicle:getX()
    local yy = vehicle:getY()
    local keyId = vehicle:getKeyId()

    -- print("Cleaning up keys with keyId: " .. tostring(keyId))

    for z=0, 3 do
        for i=xx - 15, xx + 15 do
            for j=yy - 15, yy + 15 do
                local tmpSq = getCell():getGridSquare(i, j, z)
                if tmpSq and tmpSq:getObjects() then
                    for k=0, tmpSq:getObjects():size()-1 do
                        local ttt = tmpSq:getObjects():get(k)
                        if ttt then
                            if ttt:getContainer() then
                                local items = ttt:getContainer():getItems()
                                if items then
                                    for ii=items:size()-1, 0, -1 do
                                        local checkItem = items:get(ii)
                                        if checkItem and checkItem.getKeyId and checkItem:getKeyId() == keyId then
                                            items:remove(checkItem)
                                            -- print("Removed key from container")
                                        end
                                    end
                                end
                            end

                            if instanceof and instanceof(ttt, "IsoWorldInventoryObject") then
                                local item = ttt:getItem()
                                if item then
                                    if item:getContainer() then
                                        local items = item:getContainer():getItems()
                                        if items then
                                            for ii=items:size()-1, 0, -1 do
                                                local checkItem = items:get(ii)
                                                if checkItem and checkItem.getKeyId and checkItem:getKeyId() == keyId then
                                                    items:remove(checkItem)
                                                    -- print("Removed key from world inventory object container")
                                                end
                                            end
                                        end
                                    end

                                    if item.getKeyId and item:getKeyId() == keyId then
                                        tmpSq:removeWorldObject(ttt)
                                        -- print("Removed key world object")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return true
end

function ATAISLaunchVehicle:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 330
end

function ATAISLaunchVehicle:new(character, trailer, sq)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.trailer = trailer
    o.square = sq
    o.isFadeOut = false
    o.stopOnAim  = false;
    o.maxTime = o:getDuration();
    return o
end



------------------------------------------

local deserializeItemFromModData
local deserializeContainerFromModData

-- RECURSIVE restoration of an item (including nested containers!)
deserializeItemFromModData = function(itemData, depth)
    if not itemData or not itemData.fullType then return nil end

    depth = depth or 0
    if depth > 10 then
        print("WARNING: Container nesting too deep (depth > 10), stopping recursion")
        return nil
    end

    local item = instanceItem(itemData.fullType)
    if not item then return nil end

    local isDrainable = (type(item.setUsedDelta) == "function" or type(item.setCurrentUsesFloat) == "function")
        or (instanceof and instanceof(item, "DrainableComboItem") == true)

    -- Restore condition
    if itemData.condition and item.setCondition then
        item:setCondition(itemData.condition)
    end

    -- Restore count/uses for non-drainable items
    if not isDrainable and itemData.count and item.setCount then
        item:setCount(itemData.count)
    end

    if not isDrainable and itemData.currentUses and item.setCurrentUses then
        item:setCurrentUses(itemData.currentUses)
    end

    -- Restore uses delta (generic, if present)
    if itemData.usesDelta and item.setUsesDelta then
        item:setUsesDelta(itemData.usesDelta)
    end

    -- IMPORTANT: Restore drainable usedDelta FIRST for DrainableComboItem (e.g., Whiskey)
    if isDrainable and itemData.usedDelta and item.setUsedDelta then
        item:setUsedDelta(itemData.usedDelta)
    elseif isDrainable and itemData.fillLevel and item.setCurrentUsesFloat then
        -- Fallback if only fillLevel was saved
        pcall(function()
            item:setCurrentUsesFloat(itemData.fillLevel)
        end)
    end

    -- WARNING: FluidContainer cannot be restored (water bottles only!)
    if itemData.hadFluidContainer then
        print("WARNING: Item " .. item:getFullType() .. " had FluidContainer liquid (water bottle)" .. ". Liquid content LOST - this is a Project Zomboid engine limitation!")
    end

    -- IMPORTANT: Restore KeyID AND name for car keys
    if itemData.keyId and item.setKeyId then
        pcall(function()
            item:setKeyId(itemData.keyId)
            if itemData.keyName and item.setName then
                item:setName(itemData.keyName)
            end
        end)
    end

    -- IMPORTANT: Restore custom name (e.g. "My Backpack")
    if itemData.customName and item.setName then
        item:setName(itemData.customName)
    end

    -- Restore favorite status
    if itemData.favorite and item.setFavorite then
        item:setFavorite(itemData.favorite)
    end

    -- Restore activation status
    if itemData.activated ~= nil and item.setActivated then
        item:setActivated(itemData.activated)
    end

    -- Restore worker/job data
    if itemData.jobType and item.setJobType then
        item:setJobType(itemData.jobType)
    end

    if itemData.jobDelta and item.setJobDelta then
        item:setJobDelta(itemData.jobDelta)
    end

    -- Restore remote controller ID
    if itemData.remoteControlID and item.setRemoteControlID then
        item:setRemoteControlID(itemData.remoteControlID)
    end

    if itemData.remoteRange and item.setRemoteRange then
        item:setRemoteRange(itemData.remoteRange)
    end

    -- Restore recording media data (WITH VALIDATION!) - ONLY for Radio items
    if itemData.recordedMediaIndex and instanceof and instanceof(item, "Radio") and item.setRecordedMediaIndex then
        if type(itemData.recordedMediaIndex) == "number" then
            pcall(function()
                item:setRecordedMediaIndex(itemData.recordedMediaIndex)
            end)
        end
    end

    if itemData.mediaType and instanceof and instanceof(item, "Radio") and item.setMediaType then
        pcall(function()
            item:setMediaType(itemData.mediaType)
        end)
    end

    -- Restore written content
    if itemData.note and item.setNote then
        item:setNote(itemData.note)
    end

    -- Restore age/freshness
    if itemData.age and item.setAge then
        item:setAge(itemData.age)
    end

    if itemData.offAge and item.setOffAge then
        item:setOffAge(itemData.offAge)
    end

    if itemData.offAgeMax and item.setOffAgeMax then
        item:setOffAgeMax(itemData.offAgeMax)
    end

    -- Restore last aged time
    if itemData.lastAged and item.setLastAged then
        item:setLastAged(itemData.lastAged)
    end

    -- Restore cooked status
    if itemData.cooked ~= nil and item.setCooked then
        item:setCooked(itemData.cooked)
    end

    if itemData.burnt ~= nil and item.setBurnt then
        item:setBurnt(itemData.burnt)
    end

    -- Restore wetness
    if itemData.wetness and item.setWetness then
        item:setWetness(itemData.wetness)
    end

    if itemData.itemWetness and item.setItemWetness then
        item:setItemWetness(itemData.itemWetness)
    end

    -- Restore world sprite
    if itemData.worldSprite and item.setWorldSprite then
        item:setWorldSprite(itemData.worldSprite)
    end

    -- Restore custom weight
    if itemData.actualWeight and item.setActualWeight then
        item:setActualWeight(itemData.actualWeight)
    end

    -- RECURSIVE: Restore nested containers (e.g. backpack contents)
    if itemData.nestedContainer and instanceof and instanceof(item, "InventoryContainer") and item.getItemContainer then
        local itemContainer = item:getItemContainer()
        if itemContainer then
            deserializeContainerFromModData(itemData.nestedContainer, itemContainer, depth + 1)
        end
    end

    -- Restore item's ModData (must be done last to preserve all custom data)
    if itemData.itemModData then
        local modData = item:getModData()
        for k, v in pairs(itemData.itemModData) do
            modData[k] = v
        end
    end

    return item
end

-- RECURSIVE restoration of a container
deserializeContainerFromModData = function(containerData, container, depth)
    if not containerData or not container then return end

    depth = depth or 0
    if depth > 10 then
        print("WARNING: Container nesting too deep (depth > 10), stopping recursion")
        return
    end

    -- Set capacity
    if containerData.capacity then
        container:setCapacity(containerData.capacity)
    end

    -- Clear existing items
    container:removeAllItems()

    -- Restore items
    if containerData.items then
        for _, itemData in ipairs(containerData.items) do
            local item = deserializeItemFromModData(itemData, depth)
            if item then
                container:AddItem(item)
            end
        end
    end
end


function CommonCommands.exchangePartsTrailerToVehicle(veh1, trailer)
    local partsTable = {}
    for i=1, trailer:getScript():getPartCount() do
        local part = trailer:getPartByIndex(i-1)

        local partNameTrim = string.sub(part:getId(), 9)
        if partNameTrim ~= "" then
            partsTable[partNameTrim] = {}
            partsTable[partNameTrim]["InventoryItem"] = part:getInventoryItem()
            partsTable[partNameTrim]["Condition"] = part:getCondition()
            partsTable[partNameTrim]["modData"] = part:getModData()
            partsTable[partNameTrim]["ItemContainer"] = part:getItemContainer()
            partsTable[partNameTrim]["serializedContainer"] = part:getModData().serializedContainer
        end
    end
    for i=1, veh1:getScript():getPartCount() do
        local part = veh1:getPartByIndex(i-1)
        if partsTable[part:getId()] then
            part:setInventoryItem(partsTable[part:getId()]["InventoryItem"])
            part:setCondition(partsTable[part:getId()]["Condition"])

            -- Restore container (with recursion!)
            if partsTable[part:getId()]["ItemContainer"] then
                part:setItemContainer(partsTable[part:getId()]["ItemContainer"])
            elseif partsTable[part:getId()]["serializedContainer"] then
                local container = part:getItemContainer()
                if container then
                    deserializeContainerFromModData(partsTable[part:getId()]["serializedContainer"], container, 0)
                end
            end

            if partsTable[part:getId()]["modData"] then
                for a, b in pairs(partsTable[part:getId()]["modData"]) do
                    if a ~= "serializedContainer" then
                        part:getModData()[a] = b
                    end
                end
            end
            veh1:transmitPartItem(part)
            veh1:transmitPartModData(part)
        end
    end
    veh1:setRust(trailer:getRust())
    veh1:setKeyId(trailer:getKeyId())
    return veh1
end

function CommonCommands.exchangePartsTrailerToVehicle2(veh1, trailer, playerObj)
    -- print("exchangePartsTrailerToVehicle2 - Starting vehicle data restoration")

    local wreckerPart = trailer:getPartById("ATA2VehicleWrecker")
    if not wreckerPart then
        print("ERROR: ATA2VehicleWrecker part not found! exchangePartsTrailerToVehicle2")
        return veh1
    end

    -- Restore directly mapped parts
    for i=1, trailer:getScript():getPartCount() do
        local part = trailer:getPartByIndex(i-1)
        if string.sub(part:getId(), 1, 7) == "wrecker" then
            local partNameTrim = string.sub(part:getId(), 9)
            if partNameTrim ~= "" then
                local vehPart = veh1:getPartById(partNameTrim)
                if vehPart then
                    vehPart:setInventoryItem(part:getInventoryItem())
                    vehPart:setCondition(part:getCondition())

                    -- Restore ModData
                    if part:getModData() then
                        for a, b in pairs(part:getModData()) do
                            if a ~= "serializedContainer" then
                                vehPart:getModData()[a] = b
                            end
                        end
                    end

                    -- Restore container contents (with recursion!)
                    if part:getItemContainer() then
                        vehPart:setItemContainer(part:getItemContainer())
                    elseif part:getModData().serializedContainer then
                        local container = vehPart:getItemContainer()
                        if container then
                            deserializeContainerFromModData(part:getModData().serializedContainer, container, 0)
                        end
                    end

                    veh1:transmitPartItem(vehPart)
                    veh1:transmitPartModData(vehPart)

                    if vehPart:getLuaFunction("init") then
                        VehicleUtils.callLua(vehPart:getLuaFunction("init"), veh1, vehPart, playerObj)
                    end
                end
            end
        end
    end

    -- Restore parts stored in wrecker ModData
    local modDataParts = wreckerPart:getModData().parts
    if modDataParts then
        for wPartName, wTable in pairs(modDataParts) do
            local vehPart = veh1:getPartById(wPartName)
            if vehPart then
                if modDataParts[wPartName].contPart then
                    local part = trailer:getPartById(modDataParts[wPartName].contPart)
                    if part then
                        vehPart:setInventoryItem(part:getInventoryItem())
                        vehPart:setCondition(part:getCondition())

                        if part:getModData() then
                            for a, b in pairs(part:getModData()) do
                                if a ~= "serializedContainer" then
                                    vehPart:getModData()[a] = b
                                end
                            end
                        end

                        -- Restore container (with recursion!)
                        if part:getItemContainer() then
                            vehPart:setItemContainer(part:getItemContainer())
                        elseif part:getModData().serializedContainer then
                            local container = vehPart:getItemContainer()
                            if container then
                                deserializeContainerFromModData(part:getModData().serializedContainer, container, 0)
                            end
                        end
                    end
                else
                    -- Restore simple part
                    if modDataParts[wPartName]["InventoryItemData"] then
                        local item = deserializeItemFromModData(modDataParts[wPartName]["InventoryItemData"], 0)
                        vehPart:setInventoryItem(item)
                    elseif modDataParts[wPartName]["InventoryItem"] then
                        vehPart:setInventoryItem(instanceItem(modDataParts[wPartName]["InventoryItem"]))
                    else
                        vehPart:setInventoryItem(nil)
                    end

                    vehPart:setCondition(modDataParts[wPartName]["Condition"])

                    if modDataParts[wPartName]["modData"] then
                        for a, b in pairs(modDataParts[wPartName]["modData"]) do
                            vehPart:getModData()[a] = b
                        end
                    end
                end

                veh1:transmitPartItem(vehPart)
                veh1:transmitPartModData(vehPart)

                if vehPart:getLuaFunction("init") then
                    VehicleUtils.callLua(vehPart:getLuaFunction("init"), veh1, vehPart, playerObj)
                end
            end
        end
    end

    -- Clean up wrecker part
    wreckerPart:getModData()["scriptName"] = nil
    wreckerPart:getModData()["skin"] = nil
    wreckerPart:getModData()["h"] = nil
    wreckerPart:getModData()["s"] = nil
    wreckerPart:getModData()["v"] = nil
    wreckerPart:getModData()["rust"] = nil
    wreckerPart:getModData()["keyId"] = nil
    wreckerPart:getModData().parts = nil
    trailer:transmitPartModData(wreckerPart)

    -- Restore vehicle properties
    veh1:setRust(trailer:getRust())
    local keyId = wreckerPart:getModData()["keyId"] or trailer:getKeyId()
    veh1:setKeyId(keyId)

    -- print("exchangePartsTrailerToVehicle2 - Completed restoration")
    return veh1
end
