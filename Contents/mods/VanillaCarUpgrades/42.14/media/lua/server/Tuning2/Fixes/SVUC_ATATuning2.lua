-- print("Autotsar tunning load start")

require "ATA2TuningTable"

if not ATATuning2 then ATATuning2 = {} end
if not ATATuning2Utils then ATATuning2Utils = {} end
if not ATATuning2.CheckEngine then ATATuning2.CheckEngine = {} end
if not ATATuning2.CheckOperate then ATATuning2.CheckOperate = {} end
if not ATATuning2.ContainerAccess then ATATuning2.ContainerAccess = {} end
if not ATATuning2.Create then ATATuning2.Create = {} end
if not ATATuning2.Init then ATATuning2.Init = {} end
if not ATATuning2.InstallComplete then ATATuning2.InstallComplete = {} end
if not ATATuning2.InstallTest then ATATuning2.InstallTest = {} end
if not ATATuning2.UninstallComplete then ATATuning2.UninstallComplete = {} end
if not ATATuning2.UninstallTest then ATATuning2.UninstallTest = {} end
if not ATATuning2.Update then ATATuning2.Update = {} end
if not ATATuning2.Use then ATATuning2.Use = {} end

-- NightScale5755: Adding these 2 functions to implement new animation compats (Courtesy of Hilvon).

function ATATuning2.Create.SetDefault(vehicle, part)
	ATATuning2.Create.Tuning(vehicle, part)
	part:setModelVisible("Default",true)
end

function ATATuning2.Init.SetDefault(vehicle, part)
    ATATuning2.Init.Tuning(vehicle, part)
	if part:getModData() and part:getModData().tuning2 and part:getModData().tuning2.model then
	else
		part:setModelVisible("Default",true)
	end
end

-- NightScale5755: Overwriting these 4 functions to implement new features.

function ATATuning2.Create.Tuning(vehicle, part)
    local vehicleName = vehicle:getScript():getName()
    local partName = part:getId()
    local item = nil
    part:getModData().tuning2 = {}
    if ATA2TuningTable[vehicleName] 
            and ATA2TuningTable[vehicleName].parts[partName] then
        -- обходим таблицу доступных моделей и проверяем их шанс спавна
        for modelName, tableInfo in pairs(ATA2TuningTable[vehicleName].parts[partName]) do
            if tableInfo.spawnChance and tableInfo.spawnChance > ZombRand(100) then
                item = ATATuning2Utils.createPartInventoryItem(part)
                part:getModData().tuning2.model = modelName

				ATATuning2.InstallComplete.Tuning(vehicle, part)

                break;
            end
        end
    end
    vehicle:transmitPartModData(part)
    ATATuning2Utils.ModelByModData(vehicle, part, item)
end

-- функция обязательна для всех запчастей из Tuning2
function ATATuning2.InstallComplete.Tuning(vehicle, part)
    -- print("ATATuning2.InstallComplete.Tuning")
    local item = part:getInventoryItem();
    if not item then return; end
    ATATuning2Utils.ModelByModData(vehicle, part, item)
    local vehicleName = vehicle:getScript():getName()
    local partName = part:getId()
    if part:getModData().tuning2 and part:getModData().tuning2.model then
        local modelName = part:getModData().tuning2.model
        if ATA2TuningTable[vehicleName] 
                and ATA2TuningTable[vehicleName].parts[partName] 
                and ATA2TuningTable[vehicleName].parts[partName][modelName] then 
            local modelInfo = ATA2TuningTable[vehicleName].parts[partName][modelName]

            -- отключение функции открытия окна
            if modelInfo.disableOpenWindowFromSeat then
                local seatPart = vehicle:getPartById(modelInfo.disableOpenWindowFromSeat)
                if seatPart then
                    seatPart:getModData().t2disableOpenWindow = true
                    vehicle:transmitPartModData(seatPart)
                end
                part:getModData().tuning2.disableOpenWindowFromSeat = modelInfo.disableOpenWindowFromSeat
                -- закрытие окна
                local windowPart = vehicle:getPartById("Window" .. string.sub(modelInfo.disableOpenWindowFromSeat, 5))
                if windowPart and windowPart:getWindow() then
                    windowPart:getWindow():setOpen(false)
                    vehicle:transmitPartWindow(windowPart)
                end
            end
            
            -- активация защиты (сохранение состояний предметов)
            if modelInfo.protection then
                part:getModData().tuning2.protection = modelInfo.protection
                for _, protectionPartName in ipairs(modelInfo.protection) do
                    if protectionPartName ~= "Engine" then -- защита кода от "защиты двигателя"
                        local savePart = vehicle:getPartById(protectionPartName)
                        if savePart then
                            if not savePart:getModData().tuning2 then
                                savePart:getModData().tuning2 = {}
                            end
                            
                            -- добавление запрета на снятие предмета, до снятия защиты
                            if not savePart:getModData().tuning2.protectionRequireUninstalled then
                                local t = {}
                                t[partName] = true
                                savePart:getModData().tuning2.protectionRequireUninstalled = t
                            else
                                local t = savePart:getModData().tuning2.protectionRequireUninstalled
                                t[partName] = true
                            end
                            
                            vehicle:transmitPartModData(savePart)
                            if savePart:getInventoryItem() then
                                savePart:getModData().tuning2.health = savePart:getCondition()
                                savePart:setCondition(100) -- transmit
                                vehicle:transmitPartCondition(savePart)
                            end
                        end
                    end
                end
            end
            -- активация защиты (сохранение состояний предметов)
            if modelInfo.removeIfBroken then
                part:getModData().tuning2.removeIfBroken = modelInfo.removeIfBroken
            end
			-- NightScale5755: Implement engine upgrades, stuff like blowers.
            if modelInfo.engineUpgrade then
				part:getModData().tuning2.oldLoudness = vehicle:getEngineLoudness()
				local enginePower
				enginePower = modelInfo.powerIncrease
				if not modelInfo.powerIncrease then
					enginePower = 100
				end
				local power = vehicle:getEnginePower() + enginePower
				part:getModData().tuning2.enginePower = power
				part:getModData().tuning2.powerIncrease = enginePower
				part:getModData().tuning2.oldPower = vehicle:getEnginePower()
				part:getModData().tuning2.hasAirScoop = true
				vehicle:transmitPartModData(part)

				local power = vehicle:getEnginePower() + enginePower
				local loudness = vehicle:getEngineLoudness() * 2.75
				vehicle:setEngineFeature(vehicle:getEngineQuality(), loudness, power)
				vehicle:transmitEngine()
            end
			-- NightScale5755: Implement protectionTriger and protectionHealthDelta.
            if modelInfo.protectionTriger then
                part:getModData().tuning2.protectionTriger = modelInfo.protectionTriger
            end
            if modelInfo.protectionHealthDelta then
                part:getModData().tuning2.protectionHealthDelta = modelInfo.protectionHealthDelta
            end
        end
    end
    if part:isContainer() then
        part:setContainerContentAmount(part:getItemContainer():getCapacityWeight());
    end
    vehicle:transmitPartModData(part)
    vehicle:doDamageOverlay()
end

-- функция обязательна для всех запчастей из Tuning2
-- в ней мы больше не можем обращаться к ATA2TuningTable, т.к. Имя_модели == nil
function ATATuning2.UninstallComplete.Tuning(vehicle, part, item)
-- print("ATATuning2.UninstallComplete.Tuning")
    ATATuning2Utils.ModelByModData(vehicle, part)
    local vehicleName = vehicle:getScript():getName()
    local partName = part:getId()
    if part:getModData().tuning2 then
        -- восстановление функции открытия окна
        if part:getModData().tuning2.disableOpenWindowFromSeat then
            local seatPart = vehicle:getPartById(part:getModData().tuning2.disableOpenWindowFromSeat)
            if seatPart then
                seatPart:getModData().t2disableOpenWindow = nil
                vehicle:transmitPartModData(seatPart)
            end
            part:getModData().tuning2.disableOpenWindowFromSeat = nil
        end
		-- NightScale5755: Implement engine upgrades, stuff like blowers.
		if part:getModData().tuning2.powerIncrease then
			local power = vehicle:getEnginePower() - part:getModData().tuning2.powerIncrease
			local loudness = part:getModData().tuning2.oldLoudness * 2.75
			vehicle:setEngineFeature(vehicle:getEngineQuality(), loudness, power)
			vehicle:transmitEngine()
			part:getModData().tuning2.oldLoudness = nil
			part:getModData().tuning2.hasAirScoop = false
			vehicle:transmitPartModData(part)
		end
        -- отключение защиты
        if part:getModData().tuning2.protection then
            for _, protectionPartName in ipairs(part:getModData().tuning2.protection) do
                if protectionPartName ~= "Engine" then -- защита кода от "защиты двигателя"
                    local savePart = vehicle:getPartById(protectionPartName)
                    if savePart then
                        if savePart:getModData().tuning2 and savePart:getModData().tuning2.health then 
                            savePart:setCondition(savePart:getModData().tuning2.health) -- transmit
                            vehicle:transmitPartCondition(savePart)
                            
                            savePart:getModData().tuning2.health = nil -- transmit
                            -- снятие запрета на деинсталляцию предмета
                            if savePart:getModData().tuning2.protectionRequireUninstalled then
                                local t = savePart:getModData().tuning2.protectionRequireUninstalled
                                t[partName] = nil
                            end
                            vehicle:transmitPartModData(savePart)
                        end
                    end
                end
            end
        end
    end
    if part:isContainer() then
        part:setContainerContentAmount(part:getItemContainer():getCapacityWeight());
    end
    vehicle:transmitPartModData(part)
    vehicle:doDamageOverlay()
end

function ATATuning2.Update.Protection(vehicle, part, elapsedMinutes)
    -- print("ATATuning2.Update.Protection")
    local item = part:getInventoryItem();
    if not item then return; end

    local areaCenter = vehicle:getAreaCenter(part:getArea()) -- зона для выбрасывания поврежденных деталей
    local vehicleName = vehicle:getScript():getName()
    local partName = part:getId()

    if part:getModData().tuning2 and part:getModData().tuning2.model then
		-- NightScale5755: Implement engine upgrades, stuff like blowers.
		if partName == "ATA2Airscoop" or partName == "ATA2Snorkel" then
			local power = vehicle:getEnginePower()
			local oldPower = part:getModData().tuning2.oldPower
			local newPower = oldPower + part:getModData().tuning2.powerIncrease
			local loudness = part:getModData().tuning2.oldLoudness * 2.75
			if power ~= newPower then
				vehicle:setEngineFeature(vehicle:getEngineQuality(), loudness, newPower)
				vehicle:transmitEngine()
			end
		end
        if part:getModData().tuning2.removeIfBroken and not part:getItemContainer() and areaCenter and part:getCondition() == 0 then
            local square = getCell():getGridSquare(areaCenter:getX(), areaCenter:getY(), vehicle:getZ())
            
            part:setInventoryItem(nil)-- + vehicle:transmitPartItem(part)
            vehicle:transmitPartItem(part)
            
            square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
            ATATuning2.UninstallComplete.Tuning(vehicle, part, item)
		-- отработка защиты
        elseif part:getModData().tuning2.protection then
            for _, protectionPartName in ipairs(part:getModData().tuning2.protection) do
                if protectionPartName ~= "Engine" then -- защита кода от "защиты двигателя"
                    local savePart = vehicle:getPartById(protectionPartName)
					-- NightScale5755: Implement protectionTriger and protectionHealthDelta.
					local healthTriger
					local healthDelta
					healthTriger = part:getModData().tuning2.protectionTriger
					if not healthTriger then
						healthTriger = 80
					end
					healthDelta = part:getModData().tuning2.protectionHealthDelta
					if not healthDelta then
						healthDelta = 1
					end
                    if savePart and savePart:getInventoryItem() then
                        if not savePart:getModData().tuning2 then
                            savePart:getModData().tuning2 = {}
                            vehicle:transmitPartModData(savePart)
                        end
                        if not savePart:getModData().tuning2.health then
                            savePart:getModData().tuning2.health = savePart:getCondition()
                            vehicle:transmitPartModData(savePart)
                        end
                        
                        if (savePart:getCondition() < healthTriger) then
                            part:setCondition(part:getCondition()-healthDelta) -- transmit
                            vehicle:transmitPartCondition(part)
                            
                            savePart:setCondition(100) -- transmit
                            vehicle:transmitPartCondition(savePart)
                        end
                        if string.match(savePart:getId(), "Tire") and savePart:getContainerContentAmount() < 10 then
                            savePart:setContainerContentAmount(20, false, true);
                        end
                    end
                end
            end
        end
    end
end
