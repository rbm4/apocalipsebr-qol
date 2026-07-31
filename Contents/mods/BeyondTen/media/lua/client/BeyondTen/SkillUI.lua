require "BeyondTen/Shared"
require "XpSystem/ISUI/ISSkillProgressBar"
require "XpSystem/ISUI/ISCharacterInfo"

local BT = BeyondTen

if not BT._skillUIPatched then
    BT._skillUIPatched = true

    local UI_BORDER_SPACING = 10
    local FALLBACK_SCROLL_BAR_WIDTH = 17
    local CELL_PITCH = 20
    local BAR_WIDTH = BT.MAX_LEVEL * CELL_PITCH
    local originalNew = ISSkillProgressBar.new
    local originalOnMouseUp = ISSkillProgressBar.onMouseUp
    local originalUpdateTooltip = ISSkillProgressBar.updateTooltip
    local originalGetXpForLvl = ISSkillProgressBar.getXpForLvl
    local originalGetPreviousXpLvl = ISSkillProgressBar.getPreviousXpLvl
    local originalGetPerkXp = ISSkillProgressBar.getPerkXp
    local originalCharacterPrerender = ISCharacterInfo.prerender
    local originalCharacterRender = ISCharacterInfo.render
    local originalLoadPerk = ISCharacterInfo.loadPerk

    local function getScrollBarWidth(characterInfo)
        if characterInfo.vscroll then
            local width = characterInfo.vscroll:getWidth()
            if width and width > 0 then return width end
        end
        return FALLBACK_SCROLL_BAR_WIDTH
    end

    local function getProgressBarsRight(characterInfo)
        local right = 0
        for _, progressBar in ipairs(characterInfo.progressBars or {}) do
            right = math.max(right, progressBar:getX() + progressBar:getWidth())
        end
        return right
    end

    local function getDesiredCharacterInfoWidth(characterInfo)
        local progressBarsRight = getProgressBarsRight(characterInfo)
        if progressBarsRight > 0 then
            return progressBarsRight + UI_BORDER_SPACING + getScrollBarWidth(characterInfo)
        end
        return math.max(characterInfo.width or 0, (characterInfo.txtLen or 0) + 380)
    end

    local function syncCharacterInfoLayout(characterInfo)
        local desiredWidth = getDesiredCharacterInfoWidth(characterInfo)
        if characterInfo.width < desiredWidth then
            characterInfo:setWidthAndParentWidth(desiredWidth)
        end

        if characterInfo.vscroll then
            local scrollBarWidth = getScrollBarWidth(characterInfo)
            characterInfo.vscroll:setX(characterInfo.width - scrollBarWidth + 1)
        end
    end

    function ISSkillProgressBar:new(x, y, width, height, playerNum, perk, parent)
        local progressBar = originalNew(self, x, y, width, height, playerNum, perk, parent)
        progressBar:setWidth(BAR_WIDTH)
        progressBar.level = BT.GetEffectiveLevel(progressBar.char, perk)
        local _, currentXP, requiredXP = BT.GetLevelProgress(progressBar.char, perk)
        progressBar.xp = currentXP
        progressBar.xpForLvl = requiredXP
        progressBar.BeyondTenCellPitch = CELL_PITCH
        return progressBar
    end

    function ISSkillProgressBar:onMouseUp(x, y)
        if BT.GetNativeLevel(self.char, self.perk) < BT.NATIVE_MAX_LEVEL then
            return originalOnMouseUp(self, x, y)
        end
    end

    function ISSkillProgressBar:onMouseMove(dx, dy)
        if not self:isMouseOver() then
            self:onMouseMoveOutside(dx, dy)
            return
        end

        local selectedLevel = math.floor(self:getMouseX() / CELL_PITCH)
        if selectedLevel < 0 or selectedLevel >= BT.MAX_LEVEL then return end
        self:updateTooltip(selectedLevel)
    end

    function ISSkillProgressBar:updateTooltip(selectedLevel)
        selectedLevel = math.floor(BT.Clamp(selectedLevel, 0, BT.MAX_LEVEL - 1))
        originalUpdateTooltip(self, selectedLevel)
        if selectedLevel >= BT.NATIVE_MAX_LEVEL then
            self.message = self.message .. " <LINE> <RGB:1,0.74,0.20> " .. getText("IGUI_BeyondTen_Mastery")
        end

        -- Skill Recovery Journal appends the raw Java XP total. While mastery
        -- is active that raw value is intentionally a reservoir, so replace
        -- only its recognizable Total XP line with the effective total.
        if BT.GetNativeLevel(self.char, self.perk) >= BT.NATIVE_MAX_LEVEL then
            local label = getText("IGUI_Total") .. " " .. getText("IGUI_XP_xp")
            local prefix = "\n\n" .. label .. ": "
            local escapedPrefix = string.gsub(prefix, "([^%w])", "%%%1")
            local total = BT.GetNativeCapXP(self.perk) + BT.GetStoredXP(self.char, self.perk)
            self.message = string.gsub(self.message, escapedPrefix .. "[-+%d%.eE]+", prefix .. tostring(round(total, 2)), 1)
        end
    end

    local function drawUnlocked(progressBar, x, y, mastery, unlockedLevel)
        if mastery then
            if progressBar.parent.lastLeveledUpPerk == progressBar.perk
                and progressBar.BeyondTenLastUnlockedLevel == unlockedLevel then
                local fade = 1 - progressBar.parent.lastLevelUpTime
                progressBar:drawTexture(progressBar.UnlockedSkill, x, y, 1, 1.00, 0.72 * fade, 0.16 * fade)
            else
                progressBar:drawTexture(progressBar.UnlockedSkill, x, y, 1, 1.00, 0.72, 0.16)
            end
        elseif progressBar.parent.lastLeveledUpPerk == progressBar.perk then
            local fade = 1 - progressBar.parent.lastLevelUpTime
            progressBar:drawTexture(progressBar.UnlockedSkill, x, y, 1, 1, fade, fade)
        else
            progressBar:drawTexture(progressBar.UnlockedSkill, x, y, 1, 1, 1, 1)
        end
    end

    function ISSkillProgressBar:renderPerkRect()
        local effectiveLevel, currentXP, requiredXP = BT.GetLevelProgress(self.char, self.perk)
        if self.level ~= effectiveLevel then
            local previousLevel = self.level
            self.level = effectiveLevel
            if effectiveLevel > previousLevel and effectiveLevel > BT.NATIVE_MAX_LEVEL then
                self.BeyondTenLastUnlockedLevel = effectiveLevel
            end
            self.parent.lastLeveledUpPerk = self.perk
            self.parent.lastLevelUpTime = 1
        end

        self.xpForLvl = requiredXP
        self.xp = BT.Clamp(currentXP, 0, math.max(0, requiredXP))

        local x = 0
        local y = 0
        for index = 0, self.level - 1 do
            drawUnlocked(self, x, y, index >= BT.NATIVE_MAX_LEVEL, index + 1)
            x = x + CELL_PITCH
        end

        if self.level < BT.MAX_LEVEL then
            local percentage = 0
            if self.xpForLvl > 0 then percentage = BT.Clamp(self.xp / self.xpForLvl, 0, 1) end
            local mastery = self.level >= BT.NATIVE_MAX_LEVEL

            self:drawTexture(self.SkillBtnEmpty, x, y, 1, 1, 1, 1)
            if percentage >= 1 then
                drawUnlocked(self, x, y, mastery, self.level + 1)
            elseif percentage > 0 then
                if mastery then
                    self:drawTextureScaled(self.ProgressSkill, x, y, 18 * percentage, 18, 1, 1.00, 0.72, 0.16)
                else
                    self:drawTextureScaled(self.ProgressSkill, x, y, 18 * percentage, 18, 1, 1, 1, 1)
                end
            end
            x = x + CELL_PITCH
        end

        for _index = self.level + 1, BT.MAX_LEVEL - 1 do
            self:drawTexture(self.SkillBtnEmpty, x, y, 1, 1, 1, 1)
            x = x + CELL_PITCH
        end
    end

    ISSkillProgressBar.getXpForLvl = function(perk, level)
        if level < BT.NATIVE_MAX_LEVEL then return originalGetXpForLvl(perk, level) end
        if level >= BT.MAX_LEVEL then return 0 end
        return BT.GetMasteryCost(perk, level + 1)
    end

    ISSkillProgressBar.getPreviousXpLvl = function(perk, level)
        if level <= BT.NATIVE_MAX_LEVEL then return originalGetPreviousXpLvl(perk, level) end
        return BT.GetNativeCapXP(perk) + BT.GetTotalMasteryCost(perk, level)
    end

    ISSkillProgressBar.getPerkXp = function(progressBar)
        if BT.GetNativeLevel(progressBar.char, progressBar.perk) < BT.NATIVE_MAX_LEVEL then
            return originalGetPerkXp(progressBar)
        end
        local _, currentXP = BT.GetLevelProgress(progressBar.char, progressBar.perk)
        return currentXP
    end

    ISCharacterInfo.loadPerk = function(self)
        local perks = originalLoadPerk(self)
        local catalog = BT.RefreshPerkCatalog(false)

        for parent, perkList in pairs(perks) do
            for index = #perkList, 1, -1 do
                if not BT.IsTrainablePerk(perkList[index]) then table.remove(perkList, index) end
            end
            if #perkList == 0 then perks[parent] = nil end
        end

        -- Conventional custom skills already have a parent and are included by
        -- vanilla. A top-level custom leaf gets its own small group so it is not
        -- silently hidden from the Skills panel.
        for _, perk in ipairs(catalog.trainable) do
            if perk:isCustom() and perk:getParent() == Perks.None and not perks[perk] then
                perks[perk] = { perk }
                local width = getTextManager():MeasureStringX(UIFont.Small, perk:getName())
                if width > self.txtLen then self.txtLen = width end
            end
        end
        return perks
    end

    function ISCharacterInfo:prerender()
        syncCharacterInfoLayout(self)
        originalCharacterPrerender(self)
    end

    function ISCharacterInfo:render()
        syncCharacterInfoLayout(self)
        originalCharacterRender(self)
        syncCharacterInfoLayout(self)
    end

    function ISCharacterInfo:updateTooltipForJoypad()
        if self.joypadIndex and self.joypadIndex >= 1 and self.joypadIndex <= #self.progressBars then
            if self.barWithTooltip then self.barWithTooltip:onMouseMoveOutside() end
            self.barWithTooltip = self.progressBars[self.joypadIndex]
            local selectedLevel = math.min(self.barWithTooltip.level, BT.MAX_LEVEL - 1)
            self.barWithTooltip:updateTooltip(selectedLevel)
        elseif self.barWithTooltip then
            self.barWithTooltip:onMouseMoveOutside()
            self.barWithTooltip = nil
        end
    end

    local beyondTenTooltip = ISSkillProgressBar.updateTooltip
    local function installLateTooltipCompatibility()
        local currentTooltip = ISSkillProgressBar.updateTooltip
        if currentTooltip == beyondTenTooltip or BT._lateTooltipCompatibilityInstalled then return end
        BT._lateTooltipCompatibilityInstalled = true
        ISSkillProgressBar.updateTooltip = function(progressBar, selectedLevel)
            currentTooltip(progressBar, math.floor(BT.Clamp(selectedLevel, 0, BT.MAX_LEVEL - 1)))
            if BT.GetNativeLevel(progressBar.char, progressBar.perk) >= BT.NATIVE_MAX_LEVEL then
                local label = getText("IGUI_Total") .. " " .. getText("IGUI_XP_xp")
                local prefix = "\n\n" .. label .. ": "
                local escapedPrefix = string.gsub(prefix, "([^%w])", "%%%1")
                local total = BT.GetNativeCapXP(progressBar.perk) + BT.GetStoredXP(progressBar.char, progressBar.perk)
                progressBar.message = string.gsub(progressBar.message, escapedPrefix .. "[-+%d%.eE]+", prefix .. tostring(round(total, 2)), 1)
            end
        end
    end

    Events.OnGameStart.Add(installLateTooltipCompatibility)

    print("[BeyondTen] 15-level Skills UI patch installed")
end
