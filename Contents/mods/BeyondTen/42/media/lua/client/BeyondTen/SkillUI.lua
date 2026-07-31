require "BeyondTen/Shared"
require "XpSystem/ISUI/ISSkillProgressBar"
require "XpSystem/ISUI/ISCharacterInfo"

local BT = BeyondTen

if not BT._skillUIB42Patched then
    BT._skillUIB42Patched = true

    local UI_BORDER_SPACING = 10
    local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
    local BUTTON_HGT = FONT_HGT_SMALL + 6
    local FALLBACK_SCROLL_BAR_WIDTH = 17
    local CELL_SIZE = math.floor((FONT_HGT_SMALL + 6) / 2)
    local CELL_SPACING = getCore():getOptionFontSizeReal()
    local CELL_PITCH = CELL_SIZE + CELL_SPACING
    local BAR_WIDTH = CELL_SIZE * BT.MAX_LEVEL + CELL_SPACING * (BT.MAX_LEVEL - 1)

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
        local scrollBarWidth = getScrollBarWidth(characterInfo)
        local progressBarsRight = getProgressBarsRight(characterInfo)
        if progressBarsRight > 0 then
            return progressBarsRight + UI_BORDER_SPACING + scrollBarWidth
        end

        local left = UI_BORDER_SPACING * 2 + BUTTON_HGT + 1
        local progressBarX = left + UI_BORDER_SPACING * 3 + (characterInfo.txtLen or 0)
        return progressBarX + BAR_WIDTH + UI_BORDER_SPACING + scrollBarWidth
    end

    local function syncCharacterInfoLayout(characterInfo)
        local desiredWidth = getDesiredCharacterInfoWidth(characterInfo)
        if characterInfo.width < desiredWidth then
            characterInfo:setWidthAndParentWidth(desiredWidth)
        end

        -- ISScrollBar is right-anchored, but Java applies that anchor during
        -- the next resize update. Move it immediately so the five mastery
        -- cells can never render beneath the previous 10-cell position.
        if characterInfo.vscroll then
            local scrollBarWidth = getScrollBarWidth(characterInfo)
            characterInfo.vscroll:setX(characterInfo.width - scrollBarWidth + 1)
        end
    end

    function ISSkillProgressBar:new(x, y, width, height, playerNum, perk, parent)
        local progressBar = originalNew(self, x, y, width, height, playerNum, perk, parent)
        progressBar:setWidth(BAR_WIDTH)
        progressBar:setHeight(CELL_SIZE)
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

    local function replaceTotalXP(progressBar)
        if BT.GetNativeLevel(progressBar.char, progressBar.perk) < BT.NATIVE_MAX_LEVEL then return end
        local label = getText("IGUI_Total") .. " " .. getText("IGUI_XP_xp")
        local prefix = "\n\n" .. label .. ": "
        local escapedPrefix = string.gsub(prefix, "([^%w])", "%%%1")
        local total = BT.GetNativeCapXP(progressBar.perk) + BT.GetStoredXP(progressBar.char, progressBar.perk)
        progressBar.message = string.gsub(
            progressBar.message or "",
            escapedPrefix .. "[-+%d%.eE]+",
            prefix .. tostring(round(total, 2)),
            1
        )
    end

    local function decorateTooltip(progressBar, selectedLevel)
        if selectedLevel >= BT.NATIVE_MAX_LEVEL then
            local masteryText = getText("IGUI_BeyondTen_Mastery")
            if not string.find(progressBar.message or "", masteryText, 1, true) then
                progressBar.message = (progressBar.message or "")
                    .. " <LINE> <RGB:1,0.66,0.18> " .. masteryText
            end
        end
        replaceTotalXP(progressBar)
    end

    function ISSkillProgressBar:updateTooltip(selectedLevel)
        selectedLevel = math.floor(BT.Clamp(selectedLevel, 0, BT.MAX_LEVEL - 1))
        originalUpdateTooltip(self, selectedLevel)
        decorateTooltip(self, selectedLevel)
    end

    local function drawCell(progressBar, x, y, filled, mastery, r, g, b)
        if mastery then
            r, g, b = r or 1.0, g or 0.66, b or 0.18
        else
            r, g, b = r or 1.0, g or 0.89, b or 0.38
        end
        if filled then
            progressBar:drawTextureScaled(progressBar.SkillUnitFilled, x, y, CELL_SIZE, CELL_SIZE, 1, r, g, b)
        end
        progressBar:drawTextureScaled(progressBar.SkillUnitBorder, x, y, CELL_SIZE, CELL_SIZE, 1, r, g, b)
    end

    function ISSkillProgressBar:renderPerkRect()
        local effectiveLevel, currentXP, requiredXP = BT.GetLevelProgress(self.char, self.perk)
        if self.level ~= effectiveLevel then
            self.level = effectiveLevel
            self.parent.lastLeveledUpPerk = self.perk
            self.parent.lastLevelUpTime = 1
        end
        self.xpForLvl = requiredXP
        self.xp = BT.Clamp(currentXP, 0, math.max(0, requiredXP))

        local highlight = self.parent.lastLeveledUpPerk == self.perk
        local fade = highlight and BT.Clamp(self.parent.lastLevelUpTime, 0, 1) or 0
        local good = getCore():getGoodHighlitedColor()
        local x, y = 0, 0

        for index = 0, effectiveLevel - 1 do
            local mastery = index >= BT.NATIVE_MAX_LEVEL
            local targetR, targetG, targetB = 1.0, mastery and 0.66 or 0.89, mastery and 0.18 or 0.38
            local r = targetR * (1 - fade) + good:getR() * fade
            local g = targetG * (1 - fade) + good:getG() * fade
            local b = targetB * (1 - fade) + good:getB() * fade
            drawCell(self, x, y, true, mastery, r, g, b)
            x = x + CELL_PITCH
        end

        if effectiveLevel < BT.MAX_LEVEL then
            local mastery = effectiveLevel >= BT.NATIVE_MAX_LEVEL
            local percentage = requiredXP > 0 and BT.Clamp(currentXP / requiredXP, 0, 1) or 0
            local r, g, b = mastery and 1.0 or 0.4, mastery and 0.66 or 0.4, mastery and 0.18 or 0.4
            self:drawTextureScaled(self.SkillUnitBorder, x, y, CELL_SIZE, CELL_SIZE, 1, r, g, b)
            if percentage > 0 then
                self:drawTextureScaled(self.SkillUnitFilled, x, y, CELL_SIZE * percentage, CELL_SIZE, 1, r, g, b)
            end
            x = x + CELL_PITCH
        end

        for _index = effectiveLevel + 1, BT.MAX_LEVEL - 1 do
            self:drawTextureScaled(self.SkillUnitBorder, x, y, CELL_SIZE, CELL_SIZE, 1, 0.2, 0.2, 0.2)
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

        for _, perk in ipairs(catalog.trainable) do
            if perk:isCustom() and perk:getParent() == Perks.None and not perks[perk] then
                perks[perk] = { perk }
                self.txtLen = math.max(self.txtLen, getTextManager():MeasureStringX(UIFont.Small, perk:getName()))
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
            self.barWithTooltip:updateTooltip(math.min(self.barWithTooltip.level, BT.MAX_LEVEL - 1))
        elseif self.barWithTooltip then
            self.barWithTooltip:onMouseMoveOutside()
            self.barWithTooltip = nil
        end
    end

    local beyondTenTooltip = ISSkillProgressBar.updateTooltip
    local function installLateTooltipCompatibility()
        local currentTooltip = ISSkillProgressBar.updateTooltip
        if currentTooltip == beyondTenTooltip or BT._lateTooltipB42Installed then return end
        BT._lateTooltipB42Installed = true
        ISSkillProgressBar.updateTooltip = function(progressBar, selectedLevel)
            selectedLevel = math.floor(BT.Clamp(selectedLevel, 0, BT.MAX_LEVEL - 1))
            currentTooltip(progressBar, selectedLevel)
            decorateTooltip(progressBar, selectedLevel)
        end
    end

    Events.OnGameStart.Add(installLateTooltipCompatibility)
    print("[BeyondTen/B42] 15-level Skills UI patch installed")
end
