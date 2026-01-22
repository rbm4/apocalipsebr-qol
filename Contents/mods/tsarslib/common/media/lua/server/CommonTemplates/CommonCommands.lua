if isClient() then return end

ATACommonCommands = {}
ATACommands = {}
local CommonCommands = {}
local Commands = {}

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
local deserializeItemFromModData
local serializeContainerToModData
local deserializeContainerFromModData

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

function Commands.toggleBatteryHeater(playerObj, args)
    local vehicle = playerObj:getVehicle();
    if vehicle then
        local part = vehicle:getPartById("BatteryHeater");
        if not part:getModData().tsarslib then part:getModData().tsarslib = {} end
        if part then
            part:getModData().tsarslib.active = args.on;
            part:getModData().tsarslib.temperature = args.temp;
            vehicle:transmitPartModData(part);
        end
    else
        noise('player not in vehicle');
    end
end

function Commands.bulbSmash(playerObj, args)
    if args.vehicle then
        local vehicle = getVehicleById(args.vehicle)
        local part = vehicle:getPartById("LightCabin")
        if part and part:getInventoryItem() then
            part:setCondition(0)
            vehicle:transmitPartCondition(part)
        end
    end
end

function ATACommands.installTuning(vehicle, part, model)
    local item = instanceItem("Base.LightBulb")
    if part then
        part:setInventoryItem(item)
        part:getModData().tuning2 = {}
        part:getModData().tuning2.model = model
        vehicle:transmitPartModData(part)
        local tbl = part:getTable("install")
        if tbl and tbl.complete then
            VehicleUtils.callLua(tbl.complete, vehicle, part, nil)
        end
        vehicle:transmitPartItem(part)
    end
end

function Commands.installTuning(playerObj, args)
    if args.vehicle then
        local vehicle = getVehicleById(args.vehicle)
        local part = vehicle:getPartById(args.part)
        ATACommands.installTuning(vehicle, part, args.model)
    end
end

function ATACommands.uninstallTuning(vehicle, part)
    if part and part:getInventoryItem() then
        part:setInventoryItem(nil)
        local tbl = part:getTable("uninstall")
        part:getModData().tuning2 = {}
        vehicle:transmitPartModData(part)
        if tbl and tbl.complete then
            VehicleUtils.callLua(tbl.complete, vehicle, part, nil)
        end
        vehicle:transmitPartItem(part)
    end
end

function Commands.uninstallTuning(playerObj, args)
    if args.vehicle then
        local vehicle = getVehicleById(args.vehicle)
        local part = vehicle:getPartById(args.part)
        ATACommands.uninstallTuning(vehicle, part)
    end
end

function Commands.cabinlightsOn(playerObj, args)
    if args.vehicle then
        local vehicle = getVehicleById(args.vehicle)
        local part = vehicle:getPartById("LightCabin")
        if part and part:getInventoryItem() then
            local apipart = vehicle:getPartById("HeadlightRearRight")
            local newItem = instanceItem("Base.LightBulb")
            local partCondition = part:getCondition()
            newItem:setCondition(partCondition)
            apipart:setInventoryItem(newItem, 10)
            vehicle:transmitPartItem(apipart)
            partCondition = partCondition - 1
            part:setCondition(partCondition)
            vehicle:transmitPartCondition(part)
        end
    end
end

function Commands.updatePaintVehicle(playerObj, args)
    if args.vehicle then
        local vehicle = getVehicleById(args.vehicle)
        local part = vehicle:getPartById("TireFrontLeft")
        local invItem = part:getInventoryItem()
        part:setInventoryItem(nil)
        vehicle:transmitPartItem(part)
        part:setInventoryItem(invItem)
        vehicle:transmitPartItem(part)
        part = vehicle:getPartById("TireFrontRight")
        invItem = part:getInventoryItem()
        part:setInventoryItem(nil)
        vehicle:transmitPartItem(part)
        part:setInventoryItem(invItem)
        vehicle:transmitPartItem(part)
        part = vehicle:getPartById("TireRearLeft")
        invItem = part:getInventoryItem()
        part:setInventoryItem(nil)
        vehicle:transmitPartItem(part)
        part:setInventoryItem(invItem)
        vehicle:transmitPartItem(part)
        part = vehicle:getPartById("TireRearRight")
        invItem = part:getInventoryItem()
        part:setInventoryItem(nil)
        vehicle:transmitPartItem(part)
        part:setInventoryItem(invItem)
        vehicle:transmitPartItem(part)
    end
end

function Commands.usePortableMicrowave(playerObj, args)
    if args.vehicle then
        local vehicle = getVehicleById(args.vehicle)
        local part = vehicle:getPartById(args.oven)
        if not part:getModData().tsarslib then part:getModData().tsarslib = {} end
        part:getModData().tsarslib.maxTemperature = args.maxTemperature
        part:getModData().tsarslib.timer = args.timer
        if part:getItemContainer():isActive() and not args.on then
            part:getItemContainer():setActive(false)
            part:getModData().tsarslib.timer = 0
            part:getModData().tsarslib.timePassed = 0
        elseif part:getModData().tsarslib.timer > 0 and args.on then
            part:getItemContainer():setActive(true)
            part:getModData().tsarslib.timePassed = 0.001
            part:setLightActive(true)
        end
        vehicle:transmitPartModData(part)
    end
end

function Commands.loadVehicle(playerObj, args)
    -- print("Commands.loadVehicle - Starting")
    if args.trailer and args.vehicle then
        local trailer = getVehicleById(args.trailer)
        local vehicle = getVehicleById(args.vehicle)

        if not trailer or not vehicle then
            print("ERROR: Trailer or vehicle not found! loadVehicle")
            return
        end

        if trailer:getPartById("ATAVehicleWrecker") then
            -- print('Commands.loadVehicle - Using ATAVehicleWrecker')
            CommonCommands.exchangePartsVehicleToTrailer(vehicle, trailer)
            vehicle:permanentlyRemove()
        elseif trailer:getPartById("ATA2VehicleWrecker") then
            -- print('Commands.loadVehicle - Using ATA2VehicleWrecker')
            CommonCommands.exchangePartsVehicleToTrailer2(vehicle, trailer)
            vehicle:permanentlyRemove()
        else
            print("ERROR: No wrecker part found on trailer! loadVehicle")
        end
    end
end

function Commands.launchVehicle(playerObj, args)
    -- print("Commands.launchVehicle - Starting")
    if args.trailer then
        local trailer = getVehicleById(args.trailer)
        if not trailer then
            print("ERROR: Trailer not found! launchVehicle")
            return
        end

        local wreckerPart = trailer:getPartById("ATAVehicleWrecker")
        if not wreckerPart then
            wreckerPart = trailer:getPartById("ATA2VehicleWrecker")
        end

        if wreckerPart then
            local scriptName = wreckerPart:getModData()["scriptName"]
            if not scriptName then
                print("ERROR: No scriptName in wrecker ModData! launchVehicle")
                return
            end

            local square = getSquare(args.x, args.y, 0)
            if square then
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

                -- print("Commands.launchVehicle - Vehicle spawned successfully")
            else
                print("ERROR: Square not found at coordinates! launchVehicle")
            end
        else
            print("ERROR: Wrecker part not found! launchVehicle")
        end
    end
end

CommonCommands.OnClientCommand = function(module, command, playerObj, args)
    if module == 'commonlib' and Commands[command] then
        local argStr = ''
        args = args or {}
        for k,v in pairs(args) do
            argStr = argStr..' '..k..'='..tostring(v)
        end
        -- print('Received command: '..module..' '..command..argStr)
        Commands[command](playerObj, args)
    end
end

Events.OnClientCommand.Add(CommonCommands.OnClientCommand)