require("DebugUIs/AttachmentEditorUI")

local BicycleDebug = require("Bicycle/Debug")

local options = PZAPI.ModOptions:getOptions("BicycleMod")

BicycleDebug.log("AttachmentEditorHooks loaded")

---@return boolean
---@nodiscard
local function useVanillaAttachmentEditor()
    return options:getOption("BicycleEditorFix"):getValue()
end

local originalNewAttachmentEditor = AttachmentEditorUI.new

---@param x number
---@param y number
---@param width number
---@param height number
---@return AttachmentEditorUI
function AttachmentEditorUI:new(x, y, width, height)
    if useVanillaAttachmentEditor() then
        return originalNewAttachmentEditor(self, x, y, width, height)
    end

    local o = ISPanel.new(self, x, y, width, height)
    o:setAnchorRight(true)
    o:setAnchorBottom(true)
    o:noBackground()
    o:setWantKeyEvents(true)
    return o
end

local originalAttachmentOnExit = AttachmentEditorUI.onExit

---@param button ISButton|nil
---@param x number
---@param y number
---@return unknown
function AttachmentEditorUI:onExit(button, x, y)
    if useVanillaAttachmentEditor() then
        return originalAttachmentOnExit(self, button, x, y)
    end
    getAttachmentEditorState():fromLua0("exit")
end

local originalAttachmentOnSave = AttachmentEditorUI.onSave

---@param button ISButton|nil
---@param x number
---@param y number
---@return unknown
function AttachmentEditorUI:onSave(button, x, y)
    if useVanillaAttachmentEditor() then
        return originalAttachmentOnSave(self, button, x, y)
    end

    local item = self.editUI.attachments.list:getSelectedItems()[1]
    if item then
    end
end

local EditAttachment = AttachmentEditorUI_EditAttachment
local originalSetPlayerAnimationCombo = EditAttachment.setPlayerAnimationCombo

---@return unknown
function EditAttachment:setPlayerAnimationCombo()
    if useVanillaAttachmentEditor() then
        return originalSetPlayerAnimationCombo(self)
    end
end
