-- Item Inspection (image viewer) with Ctrl+Wheel zoom + Fit-to-window

require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"

local itemImageMap = {
    ["SpecialEmergencyVehicles.SEV_CDCnote1"] = "media/ui/LootableMaps/CDCarwreport1sev.png",
    ["SpecialEmergencyVehicles.SEV_CDCnote2"] = "media/ui/LootableMaps/CDCarwreport2sev.png",
    ["SpecialEmergencyVehicles.SEV_CDCnote3"] = "media/ui/LootableMaps/CDCarwreport3sev.png",
    ["SpecialEmergencyVehicles.SEV_CDCnote4"] = "media/ui/LootableMaps/CDCarwreport4sev.png",
}

local openInspectionWindows = {}

local function showInspectionImage(playerNum, item)
    if not item then return end
    local itemFullType = item:getFullType()
    local imagePath = itemImageMap[itemFullType]
    if not imagePath then return end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    if openInspectionWindows[itemFullType] and openInspectionWindows[itemFullType]:isVisible() then
        openInspectionWindows[itemFullType]:bringToTop()
        return
    end

    local texture = getTexture(imagePath)
    if not texture then return end

    local imageWidth  = texture:getWidth()
    local imageHeight = texture:getHeight()

    local screenWidth  = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()

    local windowWidth  = math.min(800, screenWidth  - 100)
    local windowHeight = math.min(600, screenHeight - 100)

    local posX = (screenWidth  - windowWidth ) / 2
    local posY = (screenHeight - windowHeight) / 2

    local imageWindow = ISCollapsableWindow:new(posX, posY, windowWidth, windowHeight)
    imageWindow:initialise()
    imageWindow:setTitle(item:getDisplayName())
    imageWindow:setResizable(true)
    imageWindow:setVisible(true)
    imageWindow:addToUIManager()
    imageWindow:bringToTop()

    local padding = 10
    local titleBarH = imageWindow:titleBarHeight() or 20
    local contentTop = titleBarH + padding

    -- Viewport container (clip + scroll-children)
    local scrollView = ISPanel:new(padding, contentTop, windowWidth - padding*2, windowHeight - contentTop - padding)
    scrollView:initialise()
    scrollView:setScrollChildren(true)
    scrollView.clip = true
    scrollView:noBackground()
    imageWindow:addChild(scrollView)

    -- Image panel (draggable/zoomable)
    local imagePanel = ISPanel:new(0, 0, imageWidth, imageHeight)
    imagePanel:initialise()
    imagePanel.background = false
    imagePanel.image = texture
    imagePanel.baseW = imageWidth
    imagePanel.baseH = imageHeight
    imagePanel.zoom = 1.0
    imagePanel.minZoom = 0.1   -- allow small if fitting requires it
    imagePanel.maxZoom = 4.0
    imagePanel.scaledW = imageWidth
    imagePanel.scaledH = imageHeight
    imagePanel.fitMode = false -- toggled below after build
    imagePanel.parentView = scrollView
    scrollView:addChild(imagePanel)

    -- helpers
    local function applyZoom(panel)
        panel.scaledW = math.floor(panel.baseW * panel.zoom + 0.5)
        panel.scaledH = math.floor(panel.baseH * panel.zoom + 0.5)
        panel:setWidth(panel.scaledW)
        panel:setHeight(panel.scaledH)
    end

    local function centerImage(panel)
        local vw, vh = panel.parentView:getWidth(), panel.parentView:getHeight()
        local nx = math.floor((vw - panel.scaledW) / 2)
        local ny = math.floor((vh - panel.scaledH) / 2)
        panel:setX(nx)
        panel:setY(ny)
    end

    local function updateFitZoom(panel)
        local vw, vh = panel.parentView:getWidth(), panel.parentView:getHeight()
        local zx = vw / panel.baseW
        local zy = vh / panel.baseH
        -- Fit inside view; don't upscale beyond 1.0 for readability
        local target = math.min(zx, zy, 1.0)
        panel.zoom = math.max(math.min(target, panel.maxZoom), panel.minZoom)
        applyZoom(panel)
        centerImage(panel)
    end

    -- draw / input
    function imagePanel:prerender()
        -- Keep centered while in fit mode
        if self.fitMode then centerImage(self) end
        self:drawTextureScaled(self.image, 0, 0, self.scaledW, self.scaledH, 1, 1, 1, 1)
    end

    function imagePanel:onMouseDown(x, y)
        if self.fitMode then return false end -- disable pan in fit mode
        self.dragging = true
        self.dragX = x
        self.dragY = y
        self:setCapture(true)
        return true
    end

    function imagePanel:onMouseUp(x, y)
        self.dragging = false
        self:setCapture(false)
        return true
    end

    function imagePanel:onMouseUpOutside(x, y)
        self.dragging = false
        self:setCapture(false)
        return true
    end

    function imagePanel:onMouseMove(dx, dy)
        if self.dragging then
            self:setX(self:getX() + dx)
            self:setY(self:getY() + dy)
            return true
        end
    end

    -- Ctrl+Wheel zoom (turns off fit mode)
    function imagePanel:onMouseWheel(del)
        if isKeyDown(Keyboard.KEY_LCONTROL) or isKeyDown(Keyboard.KEY_RCONTROL) then
            if self.fitMode then self.fitMode = false end
            local oldZoom = self.zoom
            if del > 0 then
                self.zoom = math.min(self.zoom * 1.1, self.maxZoom)
            else
                self.zoom = math.max(self.zoom / 1.1, self.minZoom)
            end
            if math.abs(self.zoom - oldZoom) > 0.0001 then
                applyZoom(self)
            end
            return true
        end
        return false
    end

    -- Double-click toggles fit
    function imagePanel:onMouseDoubleClick(x, y)
        self.fitMode = not self.fitMode
        if self.fitMode then
            updateFitZoom(self)
        else
            -- return to 1:1 at current center
            self.zoom = 1.0
            applyZoom(self)
        end
        return true
    end

    -- --- Fit toggle button (top-right of content)
    local btnW, btnH = 60, 22
    local fitBtn = ISButton:new(0, 0, btnW, btnH, "Fit", imageWindow, function()
        imagePanel.fitMode = not imagePanel.fitMode
        if imagePanel.fitMode then
            updateFitZoom(imagePanel)
            fitBtn:setTitle("1:1")
        else
            imagePanel.zoom = 1.0
            applyZoom(imagePanel)
            fitBtn:setTitle("Fit")
        end
    end)
    fitBtn:initialise()
    imageWindow:addChild(fitBtn)

    -- position button in content top-right; keep it there on resize
    local function placeFitBtn()
        local w = imageWindow:getWidth()
        fitBtn:setX(w - padding - btnW)
        fitBtn:setY(contentTop - btnH - 2) -- tuck under titlebar
    end
    placeFitBtn()

    function imageWindow:onResize()
        ISCollapsableWindow.onResize(self)
        local w = self:getWidth()
        local h = self:getHeight()
        scrollView:setWidth(w - padding*2)
        scrollView:setHeight(h - contentTop - padding)
        placeFitBtn()
        if imagePanel.fitMode then
            updateFitZoom(imagePanel)
        end
    end

    -- Hotkey: F toggles fit
    function imageWindow:onKeyPress(key)
        if key == Keyboard.KEY_F then
            fitBtn.onClick() -- reuse button logic
            return true
        end
        return false
    end

    -- Start in fit mode for a pleasant default
    imagePanel.fitMode = true
    updateFitZoom(imagePanel)
    fitBtn:setTitle("1:1")

    openInspectionWindows[itemFullType] = imageWindow
    function imageWindow:close()
        openInspectionWindows[itemFullType] = nil
        ISCollapsableWindow.close(self)
    end
end

local function addInspectOption(playerNum, context, items)
    for _, v in ipairs(items) do
        local item = v
        if not instanceof(v, "InventoryItem") then
            if v and v.items and v.items[1] and instanceof(v.items[1], "InventoryItem") then
                item = v.items[1]
            else
                item = nil
            end
        end
        if item then
            local itemFullType = item:getFullType()
            if itemImageMap[itemFullType] then
                context:addOption(getText("ContextMenu_Inspection"), playerNum, showInspectionImage, item)
            end
        end
    end
end

Events.OnPreFillInventoryObjectContextMenu.Add(addInspectOption)
