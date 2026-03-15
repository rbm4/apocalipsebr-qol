local function isModLoaded(modid)
    local mods = getActivatedMods()
    for i = 0, mods:size() - 1 do
        local name = mods:get(i)
        if name:sub(1, 1) == "\\" then
            name = name:sub(2)
        end
        if name == modid then
            return true
        end
    end
    return false
end

local function drawTextureFitted(ui, tex, x, y, maxW, maxH, alpha, r, g, b)
    if not tex or maxW <= 0 or maxH <= 0 then
        return
    end

    local tw = tex.getWidthOrig and tex:getWidthOrig() or tex:getWidth()
    local th = tex.getHeightOrig and tex:getHeightOrig() or tex:getHeight()

    if not tw or not th or tw <= 0 or th <= 0 then
        return
    end

    local scale = math.min(maxW / tw, maxH / th)
    local drawW = math.max(1, math.floor((tw * scale) + 0.5))
    local drawH = math.max(1, math.floor((th * scale) + 0.5))
    local drawX = x + math.floor(((maxW - drawW) / 2) + 0.5)
    local drawY = y + math.floor(((maxH - drawH) / 2) + 0.5)

    ui:drawTextureScaled(tex, drawX, drawY, drawW, drawH, alpha or 1, r or 1, g or 1, b or 1)
end

local function applyEquipmentUIIconPatch()
    if not isModLoaded("EQUIPMENT_UI") then
        return
    end

    if _G.TTF_EquipmentUIIconScalePatchApplied then
        return
    end

    local okSettings, Settings = pcall(require, "EquipmentUI/Settings")
    local okDrag, DragAndDrop = pcall(require, "EquipmentUI/DragAndDrop")
    local okEquipmentSlot, EquipmentSlot = pcall(require, "EquipmentUI/UI/Slots/EquipmentSlot")
    local okEquipmentSuperSlot, EquipmentSuperSlot = pcall(require, "EquipmentUI/UI/Slots/EquipmentSuperSlot")

    if not (okSettings and okDrag and okEquipmentSlot and okEquipmentSuperSlot) then
        return
    end

    function EquipmentSlot:render()
        local item = self.item
        if not item then
            return
        end

        local alpha = 1.0
        if self.item == DragAndDrop.getDraggedItem() then
            alpha = 0.5
        end

        local tex = item:getTex()
        local r, g, b = EquipmentSlot.getItemColor(self.item)
        drawTextureFitted(self, tex, 1, 1, self.width - 2, self.height - 2, alpha, r, g, b)

        if not self.isController and self:isMouseOver() then
            self.bodySlotDisplay:doTooltipForItem(self, self.item)
        elseif self.controllerNode.isFocused then
            self.bodySlotDisplay:doTooltipForItem(self, self.item)
        end
    end

    function EquipmentSuperSlot:render()
        if self:isMouseOver() or self.controllerNode.isFocused then
            local name = getText(self.slotDefinition.name)
            local width = getTextManager():MeasureStringX(UIFont.Small, name)
            local height = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()

            local center = Settings.SUPER_SLOT_SIZE / 2
            local x = center - width / 2 - 3
            local y = -height - 2

            self:drawRect(x, y, width + 8, height + 4, 0.9, 0, 0, 0)
            self:drawRectBorder(x, y, width + 8, height + 4, 1, 1, 1, 1)
            self:drawTextCentre(name, center, y, 1, 1, 1, 1, UIFont.Small)
        end

        local itemsToDraw = {}

        local index = 1
        for _, bodyLocation in ipairs(self.slotDefinition.bodyLocations) do
            local slot = self.slotsByBodyLocation[bodyLocation]
            if slot.item and index <= 4 then
                itemsToDraw[index] = slot.item
                index = index + 1
            end
        end

        local count = index - 1
        if count == 0 then
            return
        end

        local xOff = (Settings.SUPER_SLOT_SIZE - Settings.SLOT_SIZE) / 2
        local yOff = (Settings.SUPER_SLOT_SIZE - Settings.SLOT_SIZE) / 2
        local mainAlpha = 1.0
        if itemsToDraw[1] == DragAndDrop.getDraggedItem() then
            mainAlpha = 0.5
        end

        local mainBoxSize = math.max(1, Settings.SLOT_SIZE - (Settings.SCALE * 2))
        local mainR, mainG, mainB = EquipmentSlot.getItemColor(itemsToDraw[1])
        drawTextureFitted(
            self,
            itemsToDraw[1]:getTex(),
            xOff + Settings.SCALE,
            yOff + Settings.SCALE,
            mainBoxSize,
            mainBoxSize,
            mainAlpha,
            mainR,
            mainG,
            mainB
        )

        if count > 1 then
            local slotSize = Settings.SUPER_SLOT_SIZE + Settings.SUPER_SLOT_SUB_ITEM_WIDTH
            local scaledSize = (32 * 0.375) * Settings.SCALE

            for i = 2, count do
                local boxX = slotSize - scaledSize
                local boxY = scaledSize * (i - 2)

                self:drawRect(boxX - 1, boxY, scaledSize + 1, scaledSize + 1, 0.7, 0, 0, 0)
                self:drawRectBorder(boxX - 1, boxY, scaledSize + 1, scaledSize + 1, 0.4, 1, 1, 1)

                local subR, subG, subB = EquipmentSlot.getItemColor(itemsToDraw[i])
                drawTextureFitted(
                    self,
                    itemsToDraw[i]:getTex(),
                    boxX,
                    boxY,
                    scaledSize,
                    scaledSize,
                    1,
                    subR,
                    subG,
                    subB
                )
            end

            self:drawRectBorder(Settings.SUPER_SLOT_SIZE - 1, 0, Settings.SUPER_SLOT_SUB_ITEM_WIDTH + 1,
                Settings.SUPER_SLOT_SIZE, 1, 1, 1, 1)
        end

        if not self.isController and not DragAndDrop.isDragging() and self:isMouseOver() then
            local x = self:getMouseX()
            local y = self:getMouseY()

            if y > Settings.SUPER_SLOT_SIZE then
                return
            end

            local hoveredIndex = self:mousePositionToSlotIndex(x, y)
            if hoveredIndex ~= -1 and hoveredIndex <= count then
                self.bodySlotDisplay:doTooltipForItem(self, itemsToDraw[hoveredIndex])
            else
                self.bodySlotDisplay:closeTooltip()
            end
        elseif self.controllerNode.isFocused and not self.controllerNode.selectedChild then
            self.bodySlotDisplay:doTooltipForItem(self, itemsToDraw[1])
        end
    end

    _G.TTF_EquipmentUIIconScalePatchApplied = true
end

Events.OnGameBoot.Add(applyEquipmentUIIconPatch)
