require "ISUI/ISPanel"
require "Drugzz_Core"

DrugzzMoodlePanel = ISPanel:derive("DrugzzMoodlePanel")
DrugzzMoodlePanel.instances = DrugzzMoodlePanel.instances or {}

local familyMoodles = {
    cannabis = { icon = "Cannabis", tint = { 0.28, 0.55, 0.28 }, title = "IGUI_Drugzz_Moodle_Cannabis", description = "IGUI_Drugzz_Moodle_CannabisDesc" },
    psychedelic = { icon = "Psychedelic", tint = { 0.45, 0.31, 0.68 }, title = "IGUI_Drugzz_Moodle_Psychedelic", description = "IGUI_Drugzz_Moodle_PsychedelicDesc" },
    cocaine = { icon = "Cocaine", tint = { 0.47, 0.56, 0.61 }, title = "IGUI_Drugzz_Moodle_Cocaine", description = "IGUI_Drugzz_Moodle_CocaineDesc" },
    crack = { icon = "Crack", tint = { 0.55, 0.37, 0.21 }, title = "IGUI_Drugzz_Moodle_Crack", description = "IGUI_Drugzz_Moodle_CrackDesc" },
    meth = { icon = "Meth", tint = { 0.25, 0.52, 0.68 }, title = "IGUI_Drugzz_Moodle_Meth", description = "IGUI_Drugzz_Moodle_MethDesc" },
    mdma = { icon = "MDMA", tint = { 0.67, 0.25, 0.47 }, title = "IGUI_Drugzz_Moodle_MDMA", description = "IGUI_Drugzz_Moodle_MDMADesc" },
    prescription = { icon = "Prescription", tint = { 0.68, 0.37, 0.20 }, title = "IGUI_Drugzz_Moodle_Prescription", description = "IGUI_Drugzz_Moodle_PrescriptionDesc" },
}

local symptomMoodles = {
    dryMouth = { icon = "Cottonmouth", tint = { 0.68, 0.50, 0.20 }, title = "IGUI_Drugzz_Moodle_Cottonmouth", description = "IGUI_Drugzz_Moodle_CottonmouthDesc" },
    nausea = { icon = "Nausea", tint = { 0.38, 0.55, 0.24 }, title = "IGUI_Drugzz_Moodle_Nausea", description = "IGUI_Drugzz_Moodle_NauseaDesc" },
    badTrip = { icon = "BadTrip", tint = { 0.50, 0.22, 0.46 }, title = "IGUI_Drugzz_Moodle_BadTrip", description = "IGUI_Drugzz_Moodle_BadTripDesc" },
    stimulantPanic = { icon = "HeartRacing", tint = { 0.68, 0.19, 0.23 }, title = "IGUI_Drugzz_Moodle_HeartRacing", description = "IGUI_Drugzz_Moodle_HeartRacingDesc" },
    overheating = { icon = "Overheating", tint = { 0.76, 0.24, 0.13 }, title = "IGUI_Drugzz_Moodle_Overheating", description = "IGUI_Drugzz_Moodle_OverheatingDesc" },
    tremor = { icon = "Tremor", tint = { 0.61, 0.41, 0.18 }, title = "IGUI_Drugzz_Moodle_Tremor", description = "IGUI_Drugzz_Moodle_TremorDesc" },
    jawPain = { icon = "JawPain", tint = { 0.54, 0.31, 0.27 }, title = "IGUI_Drugzz_Moodle_JawPain", description = "IGUI_Drugzz_Moodle_JawPainDesc" },
}

local familyOrder = {
    "cannabis",
    "psychedelic",
    "cocaine",
    "crack",
    "meth",
    "mdma",
    "prescription",
}

local symptomOrder = {
    "overheating",
    "stimulantPanic",
    "badTrip",
    "nausea",
    "tremor",
    "jawPain",
    "dryMouth",
}

local moodleBackground = getTexture("media/ui/Moodles/64/_Moodles_BGsolid.png")
local moodleOutline = getTexture("media/ui/Moodles/64/_Moodles_BGoutline.png")
local vanillaMoodleTypes = {
    MoodleType.ENDURANCE,
    MoodleType.TIRED,
    MoodleType.HUNGRY,
    MoodleType.PANIC,
    MoodleType.SICK,
    MoodleType.BORED,
    MoodleType.UNHAPPY,
    MoodleType.BLEEDING,
    MoodleType.WET,
    MoodleType.HAS_A_COLD,
    MoodleType.ANGRY,
    MoodleType.STRESS,
    MoodleType.THIRST,
    MoodleType.INJURED,
    MoodleType.PAIN,
    MoodleType.HEAVY_LOAD,
    MoodleType.DRUNK,
    MoodleType.DEAD,
    MoodleType.ZOMBIE,
    MoodleType.HYPERTHERMIA,
    MoodleType.HYPOTHERMIA,
    MoodleType.WINDCHILL,
    MoodleType.CANT_SPRINT,
    MoodleType.UNCOMFORTABLE,
    MoodleType.NOXIOUS_SMELL,
    MoodleType.FOOD_EATEN,
}

local function translated(key, fallback)
    local value = getText and getText(key) or key
    if not value or value == key then
        return fallback or key
    end
    return value
end

local function severityLevel(value)
    return math.max(1, math.min(4, math.ceil((value or 1) / 25)))
end

local function addStatus(statuses, definition, level, detail)
    table.insert(statuses, {
        icon = getTexture("media/ui/Moodles/DrugzzMoodle_" .. definition.icon .. ".png"),
        title = translated(definition.title, definition.icon),
        description = translated(definition.description, detail or ""),
        level = math.max(1, math.min(4, level or 1)),
        detail = detail,
        tint = definition.tint or { 0.45, 0.45, 0.43 },
    })
end

local function getRegisteredMoodleTypes()
    if Registries and Registries.MOODLE_TYPE then
        local ok, values = pcall(function()
            return Registries.MOODLE_TYPE:values()
        end)
        if ok and values then
            return values
        end
    end
    return nil
end

local function countVisibleVanillaMoodles(character)
    if not character then
        return 0
    end

    local moodles = character:getMoodles()
    if not moodles then
        return 0
    end

    local count = 0
    local registered = getRegisteredMoodleTypes()
    if registered then
        for index = 0, registered:size() - 1 do
            local moodleType = registered:get(index)
            local level = moodles:getMoodleLevel(moodleType)
            if level > 0 and (moodleType ~= MoodleType.FOOD_EATEN or level >= 3) then
                count = count + 1
            end
        end
        return count
    end

    for _, moodleType in ipairs(vanillaMoodleTypes) do
        if moodleType then
            local level = moodles:getMoodleLevel(moodleType)
            if level > 0 and (moodleType ~= MoodleType.FOOD_EATEN or level >= 3) then
                count = count + 1
            end
        end
    end
    return count
end

local function getVanillaMoodleLayout(playerNum, character)
    local screenLeft = getPlayerScreenLeft(playerNum)
    local screenTop = getPlayerScreenTop(playerNum)
    local screenWidth = getPlayerScreenWidth(playerNum)
    local moodleUI = UIManager and UIManager.getMoodleUI and UIManager.getMoodleUI(playerNum) or nil

    if moodleUI and moodleUI:isVisible() then
        local size = math.max(32, math.floor((moodleUI:getWidth() or 44) + 0.5))
        local moodleX = math.floor(moodleUI:getAbsoluteX() or (screenWidth - 10 - size))
        local moodleY = math.floor(moodleUI:getAbsoluteY() or 120)
        if screenLeft > 0 and moodleX < screenLeft then
            moodleX = moodleX + screenLeft
        end
        if screenTop > 0 and moodleY < screenTop then
            moodleY = moodleY + screenTop
        end
        return {
            x = moodleX,
            y = moodleY,
            size = size,
            gap = 10,
            count = countVisibleVanillaMoodles(character),
        }
    end

    return {
        x = screenLeft + screenWidth - 54,
        y = screenTop + 120,
        size = 44,
        gap = 10,
        count = countVisibleVanillaMoodles(character),
    }
end

local function buildStatuses(character)
    local statuses = {}
    if not character then
        return statuses
    end

    local state = Drugzz.getState(character)
    local now = Drugzz.getWorldHours()
    local comedowns = {}

    for _, family in ipairs(familyOrder) do
        local effect = state.effects and state.effects[family] or nil
        local definition = familyMoodles[family]
        if effect and definition and now <= (effect.untilHour or 0) then
            addStatus(statuses, definition, severityLevel(effect.intensity))
        elseif effect and now <= (effect.comedownUntil or 0) then
            table.insert(comedowns, translated(definition and definition.title or "", family))
        end
    end

    if #comedowns > 0 then
        addStatus(statuses, {
            icon = "Comedown",
            tint = { 0.36, 0.38, 0.40 },
            title = "IGUI_Drugzz_Moodle_Comedown",
            description = "IGUI_Drugzz_Moodle_ComedownDesc",
        }, math.min(4, #comedowns), table.concat(comedowns, ", "))
    end

    for _, symptomName in ipairs(symptomOrder) do
        local symptom = state.symptoms and state.symptoms[symptomName] or nil
        if symptom and now <= (symptom.untilHour or 0) and symptomMoodles[symptomName] then
            addStatus(statuses, symptomMoodles[symptomName], math.ceil(symptom.intensity or 1))
        end
    end

    local withdrawing = {}
    for _, family in ipairs(familyOrder) do
        local active = state.withdrawalNoted and state.withdrawalNoted[family] or nil
        if active then
            table.insert(withdrawing, translated(familyMoodles[family] and familyMoodles[family].title or "", family))
        end
    end
    if #withdrawing > 0 then
        addStatus(statuses, {
            icon = "Withdrawal",
            tint = { 0.55, 0.27, 0.23 },
            title = "IGUI_Drugzz_Moodle_Withdrawal",
            description = "IGUI_Drugzz_Moodle_WithdrawalDesc",
        }, math.min(4, #withdrawing), table.concat(withdrawing, ", "))
    end

    if (state.hardLoad or 0) >= 85 then
        addStatus(statuses, {
            icon = "Overdose",
            tint = { 0.70, 0.12, 0.12 },
            title = "IGUI_Drugzz_Moodle_Overdose",
            description = "IGUI_Drugzz_Moodle_OverdoseDesc",
        }, severityLevel((state.hardLoad or 0) - 60))
    elseif (state.cannabisLoad or 0) >= 85 then
        addStatus(statuses, {
            icon = "GreenOut",
            tint = { 0.30, 0.50, 0.20 },
            title = "IGUI_Drugzz_Moodle_GreenOut",
            description = "IGUI_Drugzz_Moodle_GreenOutDesc",
        }, severityLevel((state.cannabisLoad or 0) - 60))
    end

    return statuses
end

function DrugzzMoodlePanel:prerender()
    if not Drugzz.getOption("EnableEffectMoodles", true) then
        self.statuses = {}
        return
    end

    local left = getPlayerScreenLeft(self.playerNum)
    local top = getPlayerScreenTop(self.playerNum)
    local width = getPlayerScreenWidth(self.playerNum)
    local height = getPlayerScreenHeight(self.playerNum)
    local character = getSpecificPlayer(self.playerNum)
    self.statuses = buildStatuses(character)

    local layout = getVanillaMoodleLayout(self.playerNum, character)
    local statusCount = #self.statuses
    local customHeight = statusCount > 0
        and ((statusCount * layout.size) + ((statusCount - 1) * layout.gap))
        or layout.size
    local belowY = layout.y + (layout.count * (layout.size + layout.gap))
    local screenBottom = top + height - 8
    local anchorY = belowY
    self.placement = "below"

    if belowY + customHeight > screenBottom then
        anchorY = math.max(top + 8, layout.y - layout.gap - customHeight)
        self.placement = "above"
    end

    self.iconSize = layout.size
    self.iconGap = layout.gap
    self:setX(layout.x)
    self:setY(anchorY)
    self:setWidth(layout.size)
    self:setHeight(math.max(layout.size, math.min(customHeight, height - 16)))
end

function DrugzzMoodlePanel:render()
    local iconSize = self.iconSize or 44
    local gap = self.iconGap or 10
    local iconX = 0
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local hovered = nil

    for index, status in ipairs(self.statuses or {}) do
        local y = (index - 1) * (iconSize + gap)
        local alpha = 0.88 + (status.level * 0.025)
        local tint = status.tint or { 0.45, 0.45, 0.43 }
        if moodleBackground then
            self:drawTextureScaled(moodleBackground, iconX, y, iconSize, iconSize, alpha, tint[1], tint[2], tint[3])
        else
            self:drawRect(iconX + 4, y + 4, iconSize - 8, iconSize - 8, alpha, tint[1], tint[2], tint[3])
        end
        if status.icon then
            self:drawTextureScaled(status.icon, iconX, y, iconSize, iconSize, 1, 1, 1, 1)
        end
        if moodleOutline then
            self:drawTextureScaled(moodleOutline, iconX, y, iconSize, iconSize, 1, 1, 1, 1)
        end

        if mouseX >= iconX and mouseX <= iconX + iconSize and mouseY >= y and mouseY <= y + iconSize then
            hovered = { status = status, y = y }
        end
    end

    if hovered then
        local tooltipWidth = 224
        local tooltipHeight = hovered.status.detail and 72 or 58
        local tooltipX = iconX - tooltipWidth - 8
        local tooltipY = math.max(0, hovered.y - 3)
        self:drawRect(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 0.90, 0.06, 0.07, 0.065)
        self:drawRectBorder(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 0.95, 0.70, 0.68, 0.57)
        self:drawText(hovered.status.title, tooltipX + 9, tooltipY + 7, 0.95, 0.92, 0.80, 1, UIFont.Small)
        self:drawText(hovered.status.description, tooltipX + 9, tooltipY + 27, 0.82, 0.84, 0.79, 1, UIFont.Small)
        if hovered.status.detail then
            self:drawText(hovered.status.detail, tooltipX + 9, tooltipY + 47, 0.70, 0.82, 0.70, 1, UIFont.Small)
        end
    end
end

function DrugzzMoodlePanel:new(playerNum)
    local panel = ISPanel.new(self, 0, 0, 44, 500)
    panel.playerNum = playerNum
    panel.statuses = {}
    panel.iconSize = 44
    panel.iconGap = 10
    panel.placement = "below"
    panel:noBackground()
    panel.borderColor.a = 0
    return panel
end

local function createPanel(playerNum)
    if playerNum == nil or not getSpecificPlayer(playerNum) then
        return
    end

    local existing = DrugzzMoodlePanel.instances[playerNum]
    if existing and existing.javaObject then
        return
    end

    local panel = DrugzzMoodlePanel:new(playerNum)
    panel:initialise()
    panel:addToUIManager()
    -- B42.18 / B42.19 compatibility: some ISUI methods are not present in every build.
    -- Keep the original behavior when the method exists; safely skip it when it does not.
    if panel.setWantMouseEvents then
        panel:setWantMouseEvents(false)
    end
    if panel.setRenderThisPlayerOnly then
        panel:setRenderThisPlayerOnly(playerNum)
    end
    if panel.setAlwaysOnTop then
        panel:setAlwaysOnTop(true)
    end
    panel:setVisible(true)
    DrugzzMoodlePanel.instances[playerNum] = panel
    print("[Knox Cannabis & Contraband] Drug effect moodlet HUD initialized for player " .. tostring(playerNum))
end

local function createAllPanels()
    for playerNum = 0, getNumActivePlayers() - 1 do
        createPanel(playerNum)
    end
end

Events.OnCreatePlayer.Add(createPanel)
Events.OnGameStart.Add(createAllPanels)
