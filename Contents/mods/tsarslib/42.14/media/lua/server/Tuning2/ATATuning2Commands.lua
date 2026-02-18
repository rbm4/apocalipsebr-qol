if isClient() then return end
require "ATA2TuningTable"

local Commands = {}
ATA2Commands = {}

function ATA2Commands.installTuning(vehicle, part, modelName, condition)
    if not vehicle then return end
    if not part then return end
    local vehicleName = vehicle:getScript():getName()
    local item = VehicleUtils.createPartInventoryItem(part);
    if not item then return end
    
    local partName = part:getId()
    local vehicleTable = ATA2TuningTable[vehicleName]
    local partTable = vehicleTable and vehicleTable.parts[partName]
    local modelTable = partTable and partTable[modelName]
    if modelTable then
        if modelTable.containerCapacity then
            item:setMaxCapacity(modelTable.containerCapacity)
        end
        local modelInstalTable = modelTable.install
        if modelInstalTable and modelInstalTable.weight then
            item:setWeight(modelTable.install.weight)
        end
        if condition and modelInstalTable and modelTable.install.transmitFirstItemCondition and modelTable.install.use then
            item:setCondition(condition);
            part:setCondition(condition)
        else
            item:setCondition(100);
            part:setCondition(100)
        end
    end
    part:setInventoryItem(item)
    part:getModData().tuning2 = {}
    part:getModData().tuning2.model = modelName
    vehicle:transmitPartModData(part)
    vehicle:transmitPartItem(part)
    local tbl = part:getTable("install")
    if tbl and tbl.complete then
        VehicleUtils.callLua(tbl.complete, vehicle, part, nil)
    end
end


function ATA2Commands.uninstallTuning(vehicle, part, modelName, playerObj)
    local vehicleName = vehicle:getScript():getName()
    local vehicleTable = ATA2TuningTable[vehicleName]
    local partName = part:getId()
    local partTable = vehicleTable and vehicleTable.parts[partName]
    local modelTable = partTable and partTable[modelName]
    local resultTable = modelTable and modelTable.uninstall.result or {}
    if part:getInventoryItem() then
        part:setInventoryItem(nil)
        local tbl = part:getTable("uninstall")
        part:getModData().tuning2 = part:getModData().tuning2 or {}
        part:getModData().tuning2.model = nil
        vehicle:transmitPartModData(part)
        if tbl and tbl.complete then
            VehicleUtils.callLua(tbl.complete, vehicle, part, nil)
        end
        vehicle:transmitPartItem(part)
        local transmitCondition = modelTable and modelTable.uninstall.transmitConditionOnFirstItem
        local inventory = playerObj and playerObj:getInventory()
        if inventory then
            for itemType, num in pairs(resultTable) do
                itemType = itemType:gsub("__", ".")
                -- transmitCondition означает вернуть один предмет того же состояния, что и деталь / means to return one item of the same condition as the part
                if transmitCondition then
                    local item = inventory:AddItem(itemType)
                    item:setCondition(part:getCondition())
                    sendAddItemToContainer(inventory, item);
                    transmitCondition = false
                else
                    local items = inventory:AddItems(itemType, num)
                    sendAddItemsToContainer(inventory, items);
                end
            end
        end
    end
end


-- sendClientCommand(playerObj, 'atatuning2', 'installTuning', {vehicle = vehicle:getId(), part = self.part:getId(),})
function Commands.installTuning(playerObj, args)
    if args.vehicle then
        local vehicle = getVehicleById(args.vehicle)
        local part = vehicle and vehicle:getPartById(args.partName)
        if part then
            -- part:setInventoryItem(item)
            ATA2Commands.installTuning(vehicle, part, args.modelName, args.condition)
        end
    end
end

-- sendClientCommand(playerObj, 'atatuning2', 'uninstallTuning', {vehicle = vehicle:getId(), partName = self.part:getId(),})
function Commands.uninstallTuning(playerObj, args)
    if args.vehicle then
        local vehicle = getVehicleById(args.vehicle)
        if vehicle then
            local part = vehicle:getPartById(args.partName)
            if part then
                ATA2Commands.uninstallTuning(vehicle, part, args.modelName, playerObj)
            end
        end
    end
end

-- sendClientCommand(playerObj, 'atatuning2', 'usePart', {vehicle = vehicle:getId(), partName = self.part:getId(),})
function Commands.usePart(playerObj, args)
    if args.vehicle then
        local vehicle = getVehicleById(args.vehicle)
        if vehicle then
            local vehicleName = vehicle:getScript():getName()
            local part = vehicle:getPartById(args.partName)
            if part then
                VehicleUtils.callLua(part:getLuaFunction("use"), vehicle, part, playerObj)
            end
        end
    end
end

Events.OnClientCommand.Add(function(module, command, playerObj, args)
    --print("Tuning2Commands.OnClientCommand")
    if module == 'atatuning2' and Commands[command] then
        --print("trailer")
        local argStr = ''
        args = args or {}
        for k,v in pairs(args) do
            argStr = argStr..' '..k..'='..tostring(v)
        end
        --noise('received '..module..' '..command..' '..tostring(trailer)..argStr)
        Commands[command](playerObj, args)
    end
end)
