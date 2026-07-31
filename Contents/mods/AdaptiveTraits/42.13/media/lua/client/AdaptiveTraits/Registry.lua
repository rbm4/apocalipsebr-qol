local Config = require("AdaptiveTraits/Config")
local Store = require("AdaptiveTraits/Store")
local Manager = require("AdaptiveTraits/Manager")

local TWO_DAYS = 24 * 2
local ONE_WEEK = 24 * 7
local TWO_WEEKS = 24 * 7 * 2
local ONE_MONTH = 24 * 7 * 4
local TWO_MONTHS = 24 * 7 * 4 * 2
local FOUR_MONTHS = 24 * 7 * 4 * 4

local entries = {}

entries.AdrenalineJunkie = {
    update = function(player)
        local threshold = Config.getOption("AdrenalineJunkie_GainKills", 20000)
        local gainable = Config.getOption("AdrenalineJunkie_CanGain", false)
        if player:getZombieKills() >= threshold and gainable then
            if player:hasTrait(CharacterTrait.COWARDLY) then
                return
            end
            Manager.addTrait(player, CharacterTrait.ADRENALINE_JUNKIE, true)
        end
    end,
}

entries.Agoraphobic = {
    update = function(player)
        local minutes = Store.getValue(player, "Agoraphobic.Minutes", 0)
        if player:isOutside() then
            minutes = minutes + 1
            Store.setValue(player, "Agoraphobic.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Agoraphobic_LoseHours", ONE_WEEK)
        local losable = Config.getOption("Agoraphobic_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.AGORAPHOBIC, true)
        end
    end,
}

entries.AllThumbs = {
    update = function(player)
        local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
        if not actionQueue then
            return
        end
        local minutes = Store.getValue(player, "AllThumbs.Minutes", 0)
        if actionQueue:indexOfType("ISInventoryTransferAction") == 1 then
            minutes = minutes + 1
            Store.setValue(player, "AllThumbs.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("AllThumbs_LoseHours", ONE_WEEK)
        local losable = Config.getOption("AllThumbs_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.ALL_THUMBS, true)
        end
    end,
}

entries.Axeman = {
    update = function(player)
        local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
        if not actionQueue then
            return
        end
        local minutes = Store.getValue(player, "Axeman.Minutes", 0)
        if actionQueue:indexOfType("ISChopTreeAction") == 1 then
            minutes = minutes + 1
            Store.setValue(player, "Axeman.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Axeman_GainHours", TWO_WEEKS)
        local gainable = Config.getOption("Axeman_CanGain", false)
        if hours >= threshold and gainable then
            Manager.addTrait(player, CharacterTrait.AXEMAN, true)
        end
    end,
}

entries.Brave = {
    update = function(player)
        local threshold = Config.getOption("Brave_GainKills", 20000)
        local gainable = Config.getOption("Brave_CanGain", false)
        if player:getZombieKills() >= threshold and gainable then
            if player:hasTrait(CharacterTrait.COWARDLY) then
                return
            end
            Manager.addTrait(player, CharacterTrait.BRAVE, true)
        end
    end,
}

entries.CatEyes = {
    update = function(player)
        local gameTime = getGameTime()
        local minutes = Store.getValue(player, "CatEyes.Minutes", 0)
        if player:isOutside() and gameTime:isNight() then
            minutes = minutes + 1
            Store.setValue(player, "CatEyes.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("CatEyes_GainHours", TWO_WEEKS)
        local gainable = Config.getOption("CatEyes_CanGain", false)
        if hours >= threshold and gainable then
            Manager.addTrait(player, CharacterTrait.NIGHT_VISION, true)
        end
    end,
}

entries.Claustrophobic = {
    update = function(player)
        local minutes = Store.getValue(player, "Claustrophobic.Minutes", 0)
        if not player:isOutside() then
            minutes = minutes + 1
            Store.setValue(player, "Claustrophobic.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Claustrophobic_LoseHours", ONE_WEEK)
        local losable = Config.getOption("Claustrophobic_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.CLAUSTROPHOBIC, true)
        end
    end,
}

entries.Clumsy = {
    update = function(player)
        local minutes = Store.getValue(player, "Clumsy.Minutes", 0)
        if player:isStrafing() then
            minutes = minutes + 1
            Store.setValue(player, "Clumsy.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Clumsy_LoseHours", TWO_WEEKS)
        local losable = Config.getOption("Clumsy_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.CLUMSY, true)
        end
    end,
}

entries.Conspicuous = {
    update = function(player)
        local minutes = Store.getValue(player, "Conspicuous.Minutes", 0)
        if player:isWalking() and player:isSneaking() then
            minutes = minutes + 1
            Store.setValue(player, "Conspicuous.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Conspicuous_LoseHours", TWO_WEEKS)
        local losable = Config.getOption("Conspicuous_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.CONSPICUOUS, true)
        end
    end,
}

entries.Cowardly = {
    update = function(player)
        local threshold = Config.getOption("Cowardly_LoseKills", 20000)
        local losable = Config.getOption("Cowardly_CanLose", false)
        if player:getZombieKills() >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.COWARDLY, true)
        end
    end,
}

entries.Desensitized = {
    update = function(player)
        local threshold = Config.getOption("Desensitized_GainKills", 20000)
        local gainable = Config.getOption("Desensitized_CanGain", false)
        if player:getZombieKills() >= threshold and gainable then
            if player:hasTrait(CharacterTrait.COWARDLY) then
                return
            end
            Manager.addTrait(player, CharacterTrait.DESENSITIZED, true)
        end
    end,
}

entries.Dextrous = {
    update = function(player)
        local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
        if not actionQueue then
            return
        end
        local minutes = Store.getValue(player, "Dextrous.Minutes", 0)
        if actionQueue:indexOfType("ISInventoryTransferAction") == 1 then
            minutes = minutes + 1
            Store.setValue(player, "Dextrous.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Dextrous_GainHours", FOUR_MONTHS)
        local gainable = Config.getOption("Dextrous_CanGain", false)
        if hours >= threshold and gainable then
            if player:hasTrait(CharacterTrait.ALL_THUMBS) then
                return
            end
            Manager.addTrait(player, CharacterTrait.DEXTROUS, true)
        end
    end,
}

entries.Disorganized = {
    update = function(player)
        local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
        if not actionQueue then
            return
        end
        local minutes = Store.getValue(player, "Disorganized.Minutes", 0)
        if actionQueue:indexOfType("ISInventoryTransferAction") == 1 then
            minutes = minutes + 1
            Store.setValue(player, "Disorganized.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Disorganized_LoseHours", ONE_WEEK)
        local losable = Config.getOption("Disorganized_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.DISORGANIZED, true)
        end
    end,
}

entries.FearOfBlood = {
    update = function(player)
        local minutes = Store.getValue(player, "FearOfBlood.Minutes", 0)
        local wornItems = player:getWornItems()
        for i = 0, wornItems:size() - 1 do
            local item = wornItems:getItemByIndex(i)
            if item:getBloodLevel() > 0 then
                minutes = minutes + 1
                Store.setValue(player, "FearOfBlood.Minutes", minutes)
                break
            end
        end
        local hours = minutes / 60
        local threshold = Config.getOption("FearOfBlood_LoseHours", TWO_MONTHS)
        local losable = Config.getOption("FearOfBlood_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.HEMOPHOBIC, true)
        end
    end,
}

entries.FastHealer = {
    update = function(player)
        local minutes = Store.getValue(player, "FastHealer.Minutes", 0)
        local bodyDamage = player:getBodyDamage()
        local bodyParts = bodyDamage:getBodyParts()
        for i = 0, bodyParts:size() - 1 do
            local part = bodyParts:get(i)
            local injured = part:getBiteTime() > 0
                or part:getBleedingTime() > 0
                or part:getBurnTime() > 0
                or part:getCutTime() > 0
                or part:getDeepWoundTime() > 0
                or part:getFractureTime() > 0
                or part:getScratchTime() > 0
            local treated = part:bandaged() or part:stitched()
            if injured and treated then
                minutes = minutes + 1
                Store.setValue(player, "FastHealer.Minutes", minutes)
                break
            end
        end
        local hours = minutes / 60
        local threshold = Config.getOption("FastHealer_GainHours", ONE_MONTH)
        local gainable = Config.getOption("FastHealer_CanGain", false)
        if hours >= threshold and gainable then
            Manager.addTrait(player, CharacterTrait.FAST_HEALER, true)
        end
    end,
}

entries.FastReader = {
    update = function(player)
        local minutes = Store.getValue(player, "FastReader.Minutes", 0)
        if player:isReading() then
            minutes = minutes + 1
            Store.setValue(player, "FastReader.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("FastReader_GainHours", ONE_MONTH)
        local gainable = Config.getOption("FastReader_CanGain", false)
        if hours >= threshold and gainable then
            if player:hasTrait(CharacterTrait.SLOW_READER) then
                return
            end
            Manager.addTrait(player, CharacterTrait.FAST_READER, true)
        end
    end,
}

entries.Graceful = {
    update = function(player)
        local minutes = Store.getValue(player, "Graceful.Minutes", 0)
        if player:isStrafing() then
            minutes = minutes + 1
            Store.setValue(player, "Graceful.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Graceful_GainHours", TWO_WEEKS)
        local gainable = Config.getOption("Graceful_CanGain", false)
        if hours >= threshold and gainable then
            if player:hasTrait(CharacterTrait.CLUMSY) then
                return
            end
            Manager.addTrait(player, CharacterTrait.GRACEFUL, true)
        end
    end,
}

entries.HighThirst = {
    update = function(player)
        if player:hasTrait(CharacterTrait.LOW_THIRST) then
            return
        end
        local nutrition = player:getNutrition()
        local carbohydrates = nutrition:getCarbohydrates()
        local loseThreshold = Config.getOption("HighThirst_LoseCarbs", 200)
        local loseMinutes = Store.getValue(player, "HighThirst.LoseMinutes", 0)
        if carbohydrates <= loseThreshold then
            loseMinutes = loseMinutes + 1
        else
            loseMinutes = 0
        end
        Store.setValue(player, "HighThirst.LoseMinutes", loseMinutes)
        local loseHours = loseMinutes / 60
        local loseHoursThreshold = Config.getOption("HighThirst_LoseHours", ONE_WEEK)
        local losable = Config.getOption("HighThirst_CanLose", false)
        if loseHours >= loseHoursThreshold and losable then
            Store.setValue(player, "HighThirst.LoseMinutes", 0)
            Manager.removeTrait(player, CharacterTrait.HIGH_THIRST, true)
        end
        local gainThreshold = Config.getOption("HighThirst_GainCarbs", 300)
        local gainMinutes = Store.getValue(player, "HighThirst.GainMinutes", 0)
        if carbohydrates >= gainThreshold then
            gainMinutes = gainMinutes + 1
        else
            gainMinutes = 0
        end
        Store.setValue(player, "HighThirst.GainMinutes", gainMinutes)
        local gainHours = gainMinutes / 60
        local gainHoursThreshold = Config.getOption("HighThirst_GainHours", ONE_WEEK)
        local gainable = Config.getOption("HighThirst_CanGain", false)
        if gainHours >= gainHoursThreshold and gainable then
            Store.setValue(player, "HighThirst.GainMinutes", 0)
            Manager.addTrait(player, CharacterTrait.HIGH_THIRST, false)
        end
    end,
}

entries.Hiker = {
    update = function(player)
        local square = player:getCurrentSquare()
        if not square then
            return
        end
        local zone = square:getZone()
        if not zone then
            return
        end
        local zoneType = zone:getType()
        local minutes = Store.getValue(player, "Hiker.Minutes", 0)
        if zoneType ~= "Nav" and zoneType ~= "TownZone" then
            minutes = minutes + 1
            Store.setValue(player, "Hiker.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Hiker_GainHours", TWO_MONTHS)
        local gainable = Config.getOption("Hiker_CanGain", false)
        if hours > threshold and gainable then
            Manager.addTrait(player, CharacterTrait.HIKER, true)
        end
    end,
}

entries.Inconspicuous = {
    update = function(player)
        local minutes = Store.getValue(player, "Inconspicuous.Minutes", 0)
        if player:isWalking() and player:isSneaking() then
            minutes = minutes + 1
            Store.setValue(player, "Inconspicuous.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Inconspicuous_GainHours", ONE_MONTH)
        local gainable = Config.getOption("Inconspicuous_CanGain", false)
        if hours >= threshold and gainable then
            if player:hasTrait(CharacterTrait.CONSPICUOUS) then
                return
            end
            Manager.addTrait(player, CharacterTrait.INCONSPICUOUS, true)
        end
    end,
}

entries.LowThirst = {
    update = function(player)
        if player:hasTrait(CharacterTrait.HIGH_THIRST) then
            return
        end
        local nutrition = player:getNutrition()
        local carbohydrates = nutrition:getCarbohydrates()
        local loseThreshold = Config.getOption("LowThirst_LoseCarbs", 100)
        local loseMinutes = Store.getValue(player, "LowThirst.LoseMinutes", 0)
        if carbohydrates >= loseThreshold then
            loseMinutes = loseMinutes + 1
        else
            loseMinutes = 0
        end
        Store.setValue(player, "LowThirst.LoseMinutes", loseMinutes)
        local loseHours = loseMinutes / 60
        local loseHoursThreshold = Config.getOption("LowThirst_LoseHours", ONE_WEEK)
        local losable = Config.getOption("LowThirst_CanLose", false)
        if loseHours >= loseHoursThreshold and losable then
            Store.setValue(player, "LowThirst.LoseMinutes", 0)
            Manager.removeTrait(player, CharacterTrait.LOW_THIRST, false)
        end
        local gainThreshold = Config.getOption("LowThirst_GainCarbs", -50)
        local gainMinutes = Store.getValue(player, "LowThirst.GainMinutes", 0)
        if carbohydrates <= gainThreshold then
            gainMinutes = gainMinutes + 1
        else
            gainMinutes = 0
        end
        Store.setValue(player, "LowThirst.GainMinutes", gainMinutes)
        local gainHours = gainMinutes / 60
        local gainHoursThreshold = Config.getOption("LowThirst_GainHours", ONE_WEEK)
        local gainable = Config.getOption("LowThirst_CanGain", false)
        if gainHours >= gainHoursThreshold and gainable then
            Store.setValue(player, "LowThirst.GainMinutes", 0)
            Manager.addTrait(player, CharacterTrait.LOW_THIRST, true)
        end
    end,
}

entries.MotionSensitive = {
    update = function(player)
        local minutes = Store.getValue(player, "MotionSensitive.Minutes", 0)
        local vehicle = player:getVehicle()
        if vehicle and not vehicle:isStopped() then
            minutes = minutes + 1
            Store.setValue(player, "MotionSensitive.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("MotionSensitive_LoseHours", ONE_MONTH)
        local losable = Config.getOption("MotionSensitive_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.MOTION_SENSITIVE, true)
        end
    end,
}

entries.NightOwl = {
    update = function(player)
        local gameTime = getGameTime()
        local minutes = Store.getValue(player, "NightOwl.Minutes", 0)
        if not player:isAsleep() and gameTime:isNight() then
            minutes = minutes + 1
            Store.setValue(player, "NightOwl.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("NightOwl_GainHours", ONE_MONTH)
        local gainable = Config.getOption("NightOwl_CanGain", false)
        if hours >= threshold and gainable then
            Manager.addTrait(player, CharacterTrait.NIGHT_OWL, true)
        end
    end,
}

entries.Organized = {
    update = function(player)
        local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
        if not actionQueue then
            return
        end
        local minutes = Store.getValue(player, "Organized.Minutes", 0)
        if actionQueue:indexOfType("ISInventoryTransferAction") == 1 then
            minutes = minutes + 1
            Store.setValue(player, "Organized.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Organized_GainHours", TWO_MONTHS)
        local gainable = Config.getOption("Organized_CanGain", false)
        if hours >= threshold and gainable then
            if player:hasTrait(CharacterTrait.DISORGANIZED) then
                return
            end
            Manager.addTrait(player, CharacterTrait.ORGANIZED, true)
        end
    end,
}

entries.Outdoorsy = {
    update = function(player)
        local minutes = Store.getValue(player, "Outdoorsy.Minutes", 0)
        if player:isOutside() then
            minutes = minutes + 1
            Store.setValue(player, "Outdoorsy.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Outdoorsy_GainHours", FOUR_MONTHS)
        local gainable = Config.getOption("Outdoorsy_CanGain", false)
        if hours >= threshold and gainable then
            Manager.addTrait(player, CharacterTrait.OUTDOORSMAN, true)
        end
    end,
}

entries.Runner = {
    update = function(player)
        local minutes = Store.getValue(player, "Runner.Minutes", 0)
        if player:isRunning() then
            minutes = minutes + 1
            Store.setValue(player, "Runner.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("Runner_GainHours", TWO_MONTHS)
        local gainable = Config.getOption("Runner_CanGain", false)
        if hours >= threshold and gainable then
            Manager.addTrait(player, CharacterTrait.JOGGER, true)
        end
    end,
}

entries.SlowHealer = {
    update = function(player)
        local minutes = Store.getValue(player, "SlowHealer.Minutes", 0)
        local bodyDamage = player:getBodyDamage()
        local bodyParts = bodyDamage:getBodyParts()
        for i = 0, bodyParts:size() - 1 do
            local part = bodyParts:get(i)
            local injured = part:getBiteTime() > 0
                or part:getBleedingTime() > 0
                or part:getBurnTime() > 0
                or part:getCutTime() > 0
                or part:getDeepWoundTime() > 0
                or part:getFractureTime() > 0
                or part:getScratchTime() > 0
            local treated = part:bandaged() or part:stitched()
            if injured and treated then
                minutes = minutes + 1
                Store.setValue(player, "SlowHealer.Minutes", minutes)
                break
            end
        end
        local hours = minutes / 60
        local threshold = Config.getOption("SlowHealer_LoseHours", ONE_WEEK)
        local losable = Config.getOption("SlowHealer_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.SLOW_HEALER, true)
        end
    end,
}

entries.SlowReader = {
    update = function(player)
        local minutes = Store.getValue(player, "SlowReader.Minutes", 0)
        if player:isReading() then
            minutes = minutes + 1
            Store.setValue(player, "SlowReader.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("SlowReader_LoseHours", TWO_WEEKS)
        local losable = Config.getOption("SlowReader_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.SLOW_READER, true)
        end
    end,
}

entries.Smoker = {
    update = function(player)
        local gameTime = getGameTime()
        local timeStamp = gameTime:getMinutesStamp()
        local count = Store.getValue(player, "Smoker.Count", 0)
        if gameTime:getMinutes() == 0 and count > 0 then
            count = count - 0.45
        end
        local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
        if actionQueue then
            local currentAction = actionQueue.current or nil
            if currentAction and currentAction.item and instanceof(currentAction.item, "InventoryItem") then
                local itemFullType = currentAction.item:getFullType()
                if
                    itemFullType == "Base.Cigar"
                    or itemFullType == "Base.CigarettePack"
                    or itemFullType == "Base.CigaretteRolled"
                    or itemFullType == "Base.CigaretteSingle"
                    or itemFullType == "Base.Cigarillo"
                then
                    count = count + 1
                end
            end
        end
        Store.setValue(player, "Smoker.Count", count)
        local lastSmoke = player:getTimeSinceLastSmoke()
        if lastSmoke == 10 then
            lastSmoke = math.max(lastSmoke, Store.getValue(player, "Smoker.LastSmoke", 0))
            if gameTime:getMinutes() == 0 then
                lastSmoke = lastSmoke + 1
            end
            Store.setValue(player, "Smoker.LastSmoke", lastSmoke)
        else
            Store.setValue(player, "Smoker.LastSmoke", 0)
        end
        local loseThreshold = Config.getOption("Smoker_LoseHours", TWO_WEEKS)
        local losable = Config.getOption("Smoker_CanLose", false)
        if timeStamp >= loseThreshold * 60 and lastSmoke >= loseThreshold and losable then
            Store.setValue(player, "Smoker.Count", 0)
            Manager.removeTrait(player, CharacterTrait.SMOKER, true)
        end
        local gainThreshold = Config.getOption("Smoker_GainCount", 12)
        local gainable = Config.getOption("Smoker_CanGain", false)
        if count >= gainThreshold and gainable then
            Manager.addTrait(player, CharacterTrait.SMOKER, false)
        end
    end,
}

entries.SundayDriver = {
    update = function(player)
        local minutes = Store.getValue(player, "SundayDriver.Minutes", 0)
        if player:isDriving() then
            minutes = minutes + 1
            Store.setValue(player, "SundayDriver.Minutes", minutes)
        end
        local hours = minutes / 60
        local threshold = Config.getOption("SundayDriver_LoseHours", TWO_MONTHS)
        local losable = Config.getOption("SundayDriver_CanLose", false)
        if hours >= threshold and losable then
            Manager.removeTrait(player, CharacterTrait.SUNDAY_DRIVER, true)
        end
    end,
}

local M = {}

M.getEntries = function()
    return entries
end

return M
