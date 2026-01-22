require "TimedActions/ISBaseTimedAction"

local CommonCommands = {}

ATAISLoadVehicle = ISBaseTimedAction:derive("ATAISLoadVehicle")


function ATAISLoadVehicle:isValid()
    return self.trailer and not self.trailer:isRemovedFromWorld() and not self.trailer:getCharacter(0);
end

function ATAISLoadVehicle:update()
    self.character:faceThisObject(self.trailer)
    -- speed 1 = 1, 2 = 5, 3 = 20, 4 = 40
    self.character:setMetabolicTarget(Metabolics.HeavyWork);
end

function ATAISLoadVehicle:start()
    setGameSpeed(1)
    self:setActionAnim("Loot")
    self.trailer:getEmitter():playSound("ATAVehicleWrecker")
end

function ATAISLoadVehicle:stop()
    self.trailer:getEmitter():stopSoundByName("ATAVehicleWrecker")
    ISBaseTimedAction.stop(self)
end

function ATAISLoadVehicle:perform()
    setGameSpeed(1)
    self.trailer:getEmitter():stopSoundByName("ATAVehicleWrecker")
    ISBaseTimedAction.perform(self)
end

function ATAISLoadVehicle:complete()
    if self.vehicle:getCharacter(0) then
        return false
    end
        
    if self.vehicle:isKeysInIgnition() then
        local key = self.vehicle:createVehicleKey()
        self.character:getInventory():AddItem(key)
        sendAddItemToContainer(self.character:getInventory(), key)
    end
    sendClientCommand(self.character, 'commonlib', 'loadVehicle', {trailer = self.trailer:getId(), vehicle = self.vehicle:getId()})
    
    if self.trailer:getPartById("ATAVehicleWrecker") then
        -- print('Commands.loadVehicle - Using ATAVehicleWrecker')
        CommonCommands.exchangePartsVehicleToTrailer(self.vehicle, self.trailer)
        self.vehicle:permanentlyRemove()
    elseif self.trailer:getPartById("ATA2VehicleWrecker") then
        -- print('Commands.loadVehicle - Using ATA2VehicleWrecker')
        CommonCommands.exchangePartsVehicleToTrailer2(self.vehicle, self.trailer)
        self.vehicle:permanentlyRemove()
    end
    
    return true
end

function ATAISLoadVehicle:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 330
end

function ATAISLoadVehicle:new(character, trailer, vehicle)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.trailer = trailer
    o.vehicle = vehicle
    o.maxTime = o:getDuration();
    o.stopOnAim  = false;
    
    return o
end


------------------ server side without sendCommand -----------

-- Helper function to safely copy a table
local function deepCopyTable(original)
    if type(original) ~= 'table' then
        return original
    end
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == 'table' then
            copy[k] = deepCopyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- FORWARD DECLARATIONS (for recursive function calls)
local serializeItemToModData
local serializeContainerToModData

-- RECURSIVE serialization of a single item (including nested containers!)
serializeItemToModData = function(item, depth)
    if not item then return nil end

    -- Protection against too deep nesting
    depth = depth or 0
    if depth > 10 then
        print("WARNING: Container nesting too deep (depth > 10), stopping recursion")
        return nil
    end

    local itemData = {}
    itemData.fullType = item:getFullType()

    -- Save condition
    if item.getCondition then
        itemData.condition = item:getCondition()
    end

    -- Save count/uses
    if item.getCount then
        itemData.count = item:getCount()
    end

    -- Save current uses (for items with durability/uses)
    if item.getCurrentUses then
        itemData.currentUses = item:getCurrentUses()
    end

    -- Save uses delta (for items with degradation)
    if item.getUsesDelta then
        itemData.usesDelta = item:getUsesDelta()
    end

    -- Detect drainable robustly
    local isDrainable = (type(item.getUsedDelta) == "function" and type(item.setUsedDelta) == "function")
        or (type(item.getCurrentUsesFloat) == "function")
        or (instanceof and instanceof(item, "DrainableComboItem") == true)

    if isDrainable then
        -- Prefer usedDelta for drainables (Whiskey, lighters, etc.)
        if type(item.getUsedDelta) == "function" then
            local ok, ud = pcall(function() return item:getUsedDelta() end)
            if ok and type(ud) == "number" then
                itemData.usedDelta = ud
            end
        end
        -- Optional fallback for mods using fill level API
        if not itemData.usedDelta and type(item.getCurrentUsesFloat) == "function" then
            local ok, fill = pcall(function() return item:getCurrentUsesFloat() end)
            if ok and type(fill) == "number" then
                itemData.fillLevel = fill
            end
        end
    else
        -- WARNING: Detect FluidContainer items (water bottles etc.) - cannot be restored via Lua
        if type(item.getFluidContainer) == "function" then
            local fluidContainer = item:getFluidContainer()
            if fluidContainer then
                local amount = fluidContainer:getAmount()
                if amount and type(amount) == "number" and amount > 0 then
                    print("WARNING: Item " .. itemData.fullType .. " contains " .. tostring(amount) .. " units of liquid (FluidContainer)" .. ". This liquid CANNOT be restored - Project Zomboid engine limitation!")
                    itemData.hadFluidContainer = true
                end
            end
        end
    end

    -- Save written content (for maps, notes, etc.)
    if item.getNote then
        itemData.note = item:getNote()
    end

    -- IMPORTANT: Save KeyID AND name for car keys
    if item.getKeyId then
        local success, keyId = pcall(function() return item:getKeyId() end)
        if success and keyId and keyId >= 0 then
            itemData.keyId = keyId
            if item.getName then
                itemData.keyName = item:getName()
            end
        end
    end

    -- IMPORTANT: Save custom name (e.g. "My Backpack")
    if item.getName then
        local itemName = item:getName()
        if itemName and itemName ~= "" then
            itemData.customName = itemName
        end
    end

    -- Save favorite status
    if item.isFavorite then
        itemData.favorite = item:isFavorite()
    end

    -- Save activation status (for radios, etc.)
    if item.isActivated then
        itemData.activated = item:isActivated()
    end

    -- Save worker/job data (for tools with progress)
    if item.getJobType then
        itemData.jobType = item:getJobType()
    end

    if item.getJobDelta then
        itemData.jobDelta = item:getJobDelta()
    end

    -- Save remote controller ID (for devices)
    if item.getRemoteControlID then
        itemData.remoteControlID = item:getRemoteControlID()
    end

    if item.getRemoteRange then
        itemData.remoteRange = item:getRemoteRange()
    end

    -- Save recording media data (for cassettes, VHS, etc.) - ONLY for compatible items
    if instanceof and instanceof(item, "Radio") and item.getRecordedMediaIndex then
        local success, mediaIndex = pcall(function() return item:getRecordedMediaIndex() end)
        if success and mediaIndex and type(mediaIndex) == "number" then
            itemData.recordedMediaIndex = mediaIndex
        end
    end

    if instanceof and instanceof(item, "Radio") and item.getMediaType then
        local success, mediaType = pcall(function() return item:getMediaType() end)
        if success and mediaType then
            itemData.mediaType = mediaType
        end
    end

    -- Save age/freshness (for food items)
    if item.getAge then
        itemData.age = item:getAge()
    end

    if item.getOffAge then
        itemData.offAge = item:getOffAge()
    end

    if item.getOffAgeMax then
        itemData.offAgeMax = item:getOffAgeMax()
    end

    -- Save last aged time (for aging calculations)
    if item.getLastAged then
        itemData.lastAged = item:getLastAged()
    end

    -- Save cooked status (for food)
    if item.isCooked then
        itemData.cooked = item:isCooked()
    end

    if item.isBurnt then
        itemData.burnt = item:isBurnt()
    end

    -- Save wetness (for items that can get wet)
    if item.getWetness then
        itemData.wetness = item:getWetness()
    end

    if item.getItemWetness then
        itemData.itemWetness = item:getItemWetness()
    end

    -- Save world sprite (for placed items)
    if item.getWorldSprite then
        itemData.worldSprite = item:getWorldSprite()
    end

    -- Save custom weight (if modified)
    if item.getActualWeight then
        itemData.actualWeight = item:getActualWeight()
    end

    -- RECURSIVE: Check if the item itself is a container (e.g. backpack)
    if instanceof and instanceof(item, "InventoryContainer") and item.getItemContainer then
        local itemContainer = item:getItemContainer()
        if itemContainer then
            itemData.nestedContainer = serializeContainerToModData(itemContainer, depth + 1)
        end
    end

    -- Copy the item's own ModData (this catches custom mod data)
    if item.getModData then
        itemData.itemModData = deepCopyTable(item:getModData())
    end

    return itemData
end

-- RECURSIVE serialization of a container
serializeContainerToModData = function(container, depth)
    if not container then return nil end

    depth = depth or 0
    if depth > 10 then
        print("WARNING: Container nesting too deep (depth > 10), stopping recursion")
        return nil
    end

    local containerData = {
        capacity = container:getCapacity(),
        items = {}
    }

    local items = container:getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local serializedItem = serializeItemToModData(item, depth)
        if serializedItem then
            table.insert(containerData.items, serializedItem)
        end
    end

    return containerData
end







function CommonCommands.exchangePartsVehicleToTrailer(veh1, trailer)
    local partsTable = {}
    for i=1, veh1:getScript():getPartCount() do
        local part = veh1:getPartByIndex(i-1)
        local partStruct = {}
        partStruct["InventoryItem"] = part:getInventoryItem()
        partStruct["Condition"] = part:getCondition()
        partStruct["modData"] = deepCopyTable(part:getModData())
        partStruct["ItemContainer"] = part:getItemContainer()

        -- Serialize container for persistence (with recursion!)
        if part:getItemContainer() then
            local containerData = serializeContainerToModData(part:getItemContainer(), 0)
            if containerData then
                partStruct["serializedContainer"] = containerData
            end
        end
        partsTable["wrecker_" .. part:getId()] = partStruct
    end
    for i=1, trailer:getScript():getPartCount() do
        local part = trailer:getPartByIndex(i-1)
        if part:getId() == "ATAVehicleWrecker" then
            part:setInventoryItem(instanceItem(part:getItemType():get(0)))
            part:getModData()["scriptName"] = veh1:getScript():getName()
            part:getModData()["skin"] = veh1:getSkinIndex()
            part:getModData()["rust"] = veh1:getRust()
            part:getModData()["keyId"] = veh1:getKeyId()
        elseif partsTable[part:getId()] then
            part:setInventoryItem(partsTable[part:getId()]["InventoryItem"])
            part:setCondition(partsTable[part:getId()]["Condition"])
            if partsTable[part:getId()]["ItemContainer"] then
                part:setItemContainer(partsTable[part:getId()]["ItemContainer"])
            end
            -- Save serialized container to ModData
            if partsTable[part:getId()]["serializedContainer"] then
                part:getModData().serializedContainer = partsTable[part:getId()]["serializedContainer"]
            end
            if partsTable[part:getId()]["modData"] then
                for a, b in pairs(partsTable[part:getId()]["modData"]) do
                    if a ~= "serializedContainer" then
                        part:getModData()[a] = b
                    end
                end
            end
        end
        trailer:transmitPartItem(part)
        trailer:transmitPartModData(part)
    end
    trailer:setRust(veh1:getRust())
    trailer:setKeyId(veh1:getKeyId())
    return trailer
end

function CommonCommands.exchangePartsVehicleToTrailer2(veh1, trailer)
    -- print("exchangePartsVehicleToTrailer2 - Starting vehicle data serialization")

    local wreckerPart = trailer:getPartById("ATA2VehicleWrecker")
    if not wreckerPart then
        print("ERROR: ATA2VehicleWrecker part not found! exchangePartsVehicleToTrailer2")
        return trailer
    end

    -- Initialize wrecker part with vehicle metadata
    wreckerPart:setInventoryItem(instanceItem(wreckerPart:getItemType():get(0)))
    wreckerPart:getModData()["scriptName"] = veh1:getScript():getName()
    wreckerPart:getModData()["skin"] = veh1:getSkinIndex()
    wreckerPart:getModData()["h"] = veh1:getColorHue()
    wreckerPart:getModData()["s"] = veh1:getColorSaturation()
    wreckerPart:getModData()["v"] = veh1:getColorValue()
    wreckerPart:getModData()["rust"] = veh1:getRust()
    wreckerPart:getModData()["keyId"] = veh1:getKeyId()
    wreckerPart:getModData().parts = {}

    local modDataParts = wreckerPart:getModData().parts
    local containerID = 1

    -- Serialize all vehicle parts
    for i=1, veh1:getScript():getPartCount() do
        local part = veh1:getPartByIndex(i-1)
        local partId = part:getId()

        local trailerPart = trailer:getPartById("wrecker_" .. partId)

        if trailerPart then
            -- Direct part mapping
            trailerPart:setInventoryItem(part:getInventoryItem())
            trailerPart:setCondition(part:getCondition())

            -- Transfer container and serialize to ModData for persistence (with recursion!)
            if part:getItemContainer() then
                trailerPart:setItemContainer(part:getItemContainer())

                local containerData = serializeContainerToModData(part:getItemContainer(), 0)
                if containerData then
                    trailerPart:getModData().serializedContainer = containerData
                    -- print("Serialized container for " .. partId .. " with " .. #containerData.items .. " items")
                end
            end

            -- Copy all ModData
            if part:getModData() then
                for a, b in pairs(part:getModData()) do
                    if a ~= "serializedContainer" then
                        if type(b) ~= "table" then
                            trailerPart:getModData()[a] = b
                        else
                            trailerPart:getModData()[a] = deepCopyTable(b)
                        end
                    end
                end
            end

            trailer:transmitPartItem(trailerPart)
            trailer:transmitPartModData(trailerPart)

        else
            -- Store in wrecker ModData for parts without direct mapping
            modDataParts[partId] = {}
            modDataParts[partId]["Condition"] = part:getCondition()
            modDataParts[partId]["modData"] = deepCopyTable(part:getModData())

            if part:getItemContainer() then
                local contPartName = "wrecker_Container" .. containerID
                local contPart = trailer:getPartById(contPartName)

                if contPart then
                    containerID = containerID + 1
                    contPart:setInventoryItem(part:getInventoryItem())
                    contPart:setCondition(part:getCondition())
                    contPart:setItemContainer(part:getItemContainer())

                    -- Serialize to ModData (with recursion!)
                    local containerData = serializeContainerToModData(part:getItemContainer(), 0)
                    if containerData then
                        contPart:getModData().serializedContainer = containerData
                        -- print("Serialized container for " .. partId .. " -> " .. contPartName .. " with " .. #containerData.items .. " items")
                    end

                    if part:getModData() then
                        for a, b in pairs(part:getModData()) do
                            if a ~= "serializedContainer" then
                                if type(b) ~= "table" then
                                    contPart:getModData()[a] = b
                                else
                                    contPart:getModData()[a] = deepCopyTable(b)
                                end
                            end
                        end
                    end

                    trailer:transmitPartItem(contPart)
                    trailer:transmitPartModData(contPart)

                    modDataParts[partId].contPart = contPartName
                else
                    print("WARNING: Container part not found: " .. contPartName)
                end
            else
                -- Store item data
                if part:getInventoryItem() then
                    modDataParts[partId]["InventoryItemData"] = serializeItemToModData(part:getInventoryItem(), 0)
                    modDataParts[partId]["InventoryItem"] = part:getInventoryItem():getFullType()
                else
                    modDataParts[partId]["InventoryItem"] = false
                end
            end
        end
    end

    trailer:transmitPartItem(wreckerPart)
    trailer:transmitPartModData(wreckerPart)
    trailer:setRust(veh1:getRust())
    trailer:setKeyId(veh1:getKeyId())

    -- print("exchangePartsVehicleToTrailer2 - Completed serialization")
    return trailer
end

