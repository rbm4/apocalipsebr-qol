require "ISUI/ISInventoryItem"
require "ISUI/ISInventoryPane"

local IMPROVISED_SUPPRESSOR_FULL_TYPE = "SimpleSuppressorB42.ImprovisedSuppressor"
local STANDARD_SUPPRESSOR_FULL_TYPE = "SimpleSuppressorB42.Suppressor"
local IMPROVISED_ICON_TEXTURE_NAME = "Item_ImprovisedSuppressor"
local STANDARD_SUPPRESSOR_REMAINING_KEY = "SimpleSuppressorB42_StandardRemainingCondition"
local STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX = 200

local base_render_item_icon = ISInventoryItem.renderItemIcon
local base_draw_item_details = ISInventoryPane.drawItemDetails

local function isImprovisedSuppressor(item)
    return item and item.getFullType and item:getFullType() == IMPROVISED_SUPPRESSOR_FULL_TYPE
end

local function isStandardSuppressor(item)
    return item and item.getFullType and item:getFullType() == STANDARD_SUPPRESSOR_FULL_TYPE
end

local function getImprovisedIconTexture()
    if not getTexture then
        return nil
    end

    return getTexture(IMPROVISED_ICON_TEXTURE_NAME) or getTexture("item_ImprovisedSuppressor")
end

function ISInventoryItem.renderItemIcon(self, item, x, y, alpha, width, height)
    if isImprovisedSuppressor(item) and item.setTexture then
        local texture = getImprovisedIconTexture()
        if texture then
            local current_texture = item:getTex()
            if not current_texture or current_texture:getName() ~= texture:getName() then
                item:setTexture(texture)
            end
        end
    end

    return base_render_item_icon(self, item, x, y, alpha, width, height)
end

function ISInventoryPane:drawItemDetails(item, y, xoff, yoff, red)
    if isImprovisedSuppressor(item) or isStandardSuppressor(item) then
        local hdrHgt = self.headerHgt
        local top = hdrHgt + y * self.itemHgt + yoff
        local hc = getCore():getGoodHighlitedColor()
        local fgBar = {r=hc:getR(), g=hc:getG(), b=hc:getB(), a=1}
        local fgText = {r=0.6, g=0.8, b=0.5, a=0.6}
        if red then
            fgText = {r=0.0, g=0.0, b=0.5, a=0.7}
        end

        local condition_max = 1
        local condition = 0
        if isImprovisedSuppressor(item) then
            condition_max = math.max(item:getConditionMax() or 0, 1)
            condition = math.max(item:getCondition() or 0, 0)
        else
            local mod_data = item:getModData()
            condition_max = STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX
            condition = tonumber(mod_data[STANDARD_SUPPRESSOR_REMAINING_KEY]) or condition_max
            if condition < 0 then
                condition = 0
            elseif condition > condition_max then
                condition = condition_max
            end
        end
        local text = getText("IGUI_invpanel_Condition") .. ":"
        self:drawTextAndProgressBar(text, condition / condition_max, xoff, top, fgText, fgBar)
        return
    end

    return base_draw_item_details(self, item, y, xoff, yoff, red)
end
