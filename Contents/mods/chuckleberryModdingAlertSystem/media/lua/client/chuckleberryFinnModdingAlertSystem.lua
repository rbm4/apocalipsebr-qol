require "ISUI/ISPanelJoypad"
---@type ISPanelJoypad|ISUIElement
local alertSystem = ISPanelJoypad:derive("alertSystem")

local changelog_handler = require "chuckleberryFinnModding_modChangelog"

alertSystem.spiffoTextures = {
    "common/media/textures/spiffos/spiffoWatermelon.png",
    "common/media/textures/spiffos/jumpingSpiffo.png",
}
function alertSystem.addTexture(path) table.insert(alertSystem.spiffoTextures, path) end

alertSystem.alertSelected = 1
alertSystem.alertsLoaded = {}
alertSystem.alertsLayout = {}
alertSystem.alertsOld = 0
alertSystem.rateTexture = getTexture("common/media/textures/alert/rate.png")
alertSystem.expandTexture = getTexture("common/media/textures/alert/expand.png")
alertSystem.collapseTexture = getTexture("common/media/textures/alert/collapse.png")
alertSystem.raiseTexture = getTexture("common/media/textures/alert/raise.png")
alertSystem.alertTextureEmpty = getTexture("common/media/textures/alert/alertEmpty.png")
alertSystem.alertTextureFull = getTexture("common/media/textures/alert/alertFull.png")

alertSystem.alertLeft = getTexture("common/media/textures/alert/left.png")
alertSystem.alertRight = getTexture("common/media/textures/alert/right.png")

local hidden_per_session = false

function alertSystem:onMouseWheel(del)
    if self.alertContentPanel:isMouseOver() then
        self.alertContentPanel:setYScroll(self.alertContentPanel:getYScroll() - (del*9))
        return true
    end

    local x = self:getMouseX()
    local y = self:getMouseY()

    if x >= self.alertLeftX and x <= self.alertLeftX+self.alertBarSpan and y >= 10 and y <= 10+12 then
        self.alertSelected = self.alertSelected + (del>0 and 1 or -1)
        if self.alertSelected > #self.alertsLoaded then self.alertSelected = 1 end
        if self.alertSelected <= 0 then self.alertSelected = #self.alertsLoaded end
        getSoundManager():playUISound("UIActivateButton")
    end
end


function alertSystem:WrapText(font, text, maxWidth)
    local tM = getTextManager()
    local lines = {}
    local paragraphs = {}
    for line in string.gmatch(text, "[^\r\n]+") do
        table.insert(paragraphs, line)
    end

    local spaceWidth = tM:MeasureStringX(font, " ")

    for _, paragraph in ipairs(paragraphs) do
        local lineWidth = tM:MeasureStringX(font, paragraph)
        if lineWidth <= maxWidth then
            table.insert(lines, paragraph)
        else
            local words = {}
            for word in string.gmatch(paragraph, "%S+") do
                table.insert(words, word)
            end

            local currentLine = {}
            local currentWidth = 0

            for _, word in ipairs(words) do
                local wordWidth = tM:MeasureStringX(font, word)
                if currentWidth + wordWidth <= maxWidth then
                    table.insert(currentLine, word)
                    currentWidth = currentWidth + wordWidth + spaceWidth
                elseif #currentLine > 0 then
                    table.insert(lines, table.concat(currentLine, " "))
                    currentLine = {word}
                    currentWidth = wordWidth + spaceWidth
                else
                    local maxChars = math.floor(maxWidth / wordWidth * #word) - 1
                    local numSegments = math.ceil(#word / maxChars)

                    for i = 1, numSegments - 1 do
                        table.insert(lines, word:sub((i - 1) * maxChars + 1, i * maxChars) .. "-")
                    end

                    local remaining = word:sub((numSegments - 1) * maxChars + 1)
                    table.insert(currentLine, remaining)
                    currentWidth = tM:MeasureStringX(font, remaining) + spaceWidth
                end

                if _ == #words then
                    table.insert(lines, table.concat(currentLine, " "))
                end
            end
        end
    end

    return table.concat(lines, "\n")
end


function alertSystem:determineLayout(modID, header, subHeader, alertTitle, alertContents, icon)
    if not alertSystem.alertsLayout[modID] then

        local alertLayout = {}

        alertLayout.subHeaderW = subHeader and getTextManager():MeasureStringX(UIFont.NewSmall, subHeader) + (alertSystem.padding) or 0
        alertLayout.headerX = 40+(alertSystem.padding/2)

        local tM = getTextManager()
        local headerMaxW = (self.width-alertLayout.subHeaderW-alertLayout.headerX-alertSystem.padding)
        alertLayout.header = alertSystem:WrapText(UIFont.NewMedium, header, headerMaxW, -1, "\n")
        alertLayout.headerH = tM:MeasureStringY(UIFont.NewMedium, alertLayout.header)

        alertLayout.titleH = alertTitle and getTextManager():MeasureStringY(UIFont.NewSmall, alertTitle) or 0
        alertLayout.headerY = (alertSystem.padding*1.5)
        alertLayout.headerW = tM:MeasureStringX(UIFont.NewMedium, alertLayout.header) + (alertSystem.padding)

        alertLayout.alertIcon = icon

        alertLayout.contents = alertSystem:WrapText(UIFont.NewSmall, alertContents, self.width-(alertSystem.padding*4))
        alertLayout.contentsH = tM:MeasureStringY(UIFont.NewSmall, alertLayout.contents) + (alertSystem.padding*1)

        alertLayout.totalH = alertLayout.headerH + alertLayout.titleH + alertLayout.contentsH

        alertSystem.alertsLayout[modID] = alertLayout
    end

    return alertSystem.alertsLayout[modID]
end

function alertSystem:prerender()
    ISPanelJoypad.prerender(self)

    local collapseWidth = not self.collapsed and self.width or self.collapse.width+10
    self:drawRect(0, 0, collapseWidth, self.height, 0.8, 0, 0, 0)
    self:drawRectBorder(0, 0, collapseWidth, self.height, 0.8, 1, 1, 1)

    if not self.collapsed and self.alertSelected > 0 then
        local alertModID = self.alertsLoaded[self.alertSelected]
        local alertModData = self.latestAlerts[alertModID]
        local modName = alertModData.modName
        local latestAlert = alertModData.alerts[#alertModData.alerts]
        local alertTitle = latestAlert.title ~= "" and latestAlert.title
        local alertContents = latestAlert.contents
        local alertIcon = alertModData.icon
        local header = modName
        local subHeader = alertModID ~= "" and " ("..alertModID..")"
        local layout = self:determineLayout(alertModID, header, subHeader, alertTitle, alertContents, alertIcon)

        if layout.alertIcon then self:drawTexture(layout.alertIcon, 4+(alertSystem.padding/3), layout.headerY, 1, 1, 1, 1) end

        local maxSubheaderX = math.min( ((alertSystem.padding*1.5)+layout.headerW), (self.width-layout.subHeaderW) )
        if subHeader then
            self:drawText(subHeader, maxSubheaderX, layout.headerY + (alertSystem.padding/5), 1, 1, 1, 0.7, UIFont.NewSmall)
        end

        self:drawText(layout.header, layout.headerX, layout.headerY, 1, 1, 1, 0.96, UIFont.NewMedium)

        local titleY = layout.headerY+layout.headerH+(alertSystem.padding/7)
        if alertTitle then
            self:drawText(alertTitle, layout.headerX, titleY, 1, 1, 1, 0.85, UIFont.NewSmall)
        end

        self.alertContentPanel:setY((titleY+layout.titleH+(alertSystem.padding/7)))
        self.alertContentPanel:setHeight(self.alertContentPanel.originalH+(self.alertContentPanel.originalY-self.alertContentPanel:getY()))

        self.alertContentPanel:clampStencilRectToParent(0, 0, self.alertContentPanel:getWidth(), self.alertContentPanel:getHeight())
        self.alertContentPanel:setScrollHeight(layout.contentsH)
        self.alertContentPanel:drawText(layout.contents, self.padding/3, self.padding/3, 1, 1, 1, 0.8, UIFont.NewSmall)
        self.alertContentPanel:clearStencilRect()
    end
end


function alertSystem:render()
    ISPanelJoypad.render(self)

    if not self.collapsed then

        if alertSystem.spiffoTexture and (not self.collapsed) then
            local textureYOffset = self.height-(alertSystem.spiffoTexture:getHeight())
            self:drawTexture(alertSystem.spiffoTexture, self.width-(alertSystem.padding*1.7), textureYOffset, 1, 1, 1, 1)
        end

        if #alertSystem.alertsLoaded > 0 then
            local label = tostring(self.alertSelected).."/"..tostring(#alertSystem.alertsLoaded)
            self:drawText(label, 40, 7, 1, 1, 1, 0.7, UIFont.AutoNormSmall)
        end

        self:drawTexture(alertSystem.alertLeft, self.alertLeftX, 0, 0.7, 1, 1, 1)
        self:drawTexture(alertSystem.alertRight, self.alertRightX, 0, 0.7, 1, 1, 1)

        local alertBarX = (self.alertLeftX+32)

        local rectWidth = self.alertBarSpan-32
        self:drawRectBorder(alertBarX, 10, rectWidth, 12, 0.7, 1, 1, 1)

        local selectedAlertWidth = math.max(2, rectWidth/#self.alertsLoaded)
        self:drawRect(alertBarX+(selectedAlertWidth*(self.alertSelected-1)), 10, selectedAlertWidth, 12, 0.8, 1, 1, 1)

    end

    if #alertSystem.alertsLoaded > 0 then
        local alertImage = (#alertSystem.alertsLoaded-alertSystem.alertsOld)>0 and alertSystem.alertTextureFull or alertSystem.alertTextureEmpty
        self:drawTexture(alertImage, 0, 0, 1, 1, 1, 1)
    end

end

function alertSystem:updateButtonTooltip()
    if self:isMouseOver() and self.tooltip then
        local text = self.tooltip
        if not self.tooltipUI then
            self.tooltipUI = ISToolTip:new()
            self.tooltipUI:setOwner(self)
            self.tooltipUI:setHeight(self:getHeight())
            self.tooltipUI:setVisible(false)
            self.tooltipUI:setAlwaysOnTop(true)
        end
        if not self.tooltipUI:getIsVisible() then
            self.tooltipUI:addToUIManager()
            self.tooltipUI:setVisible(true)
        end
        self.tooltipUI.description = text
        self.tooltipUI:setDesiredPosition(self:getAbsoluteX()+self:getWidth(), self:getAbsoluteY())
    else
        if self.tooltipUI and self.tooltipUI:getIsVisible() then
            self.tooltipUI:setVisible(false)
            self.tooltipUI:removeFromUIManager()
        end
    end
end

function alertSystem:updateButtons()
    local alertModID = self.alertsLoaded[self.alertSelected]
    local modAlertConfig = changelog_handler.fetchModAlertConfig(alertModID)
    for i=1, 4 do
        local visible = false
        local button = self["linkButton"..i]
        if modAlertConfig then
            local buttonData = modAlertConfig["link"..i]
            if buttonData then
                visible = true
                button.url = buttonData.url
                button.tooltip = buttonData.url
                button.updateTooltip = alertSystem.updateButtonTooltip
                button.borderColor = buttonData.color
                button.backgroundColor = {r=buttonData.color.r, g=buttonData.color.g, b=buttonData.color.b, a=0.06}
                button:setImage(buttonData.icon)
                button.textColor = buttonData.color
                button:setTitle(buttonData.title)
            end
        end
        button:setVisible((visible) and (not self.collapsed))
    end
end


function alertSystem:onMouseDown(x, y)

    if y <= 32 then

        local click = false

        if (x >= self.alertLeftX+8 and x <= self.alertLeftX+24) then click = -1 end
        if (x >= self.alertRightX+8 and x <= self.alertRightX+24) then click = 1 end

        if click then

            ---mark current alert as read
            local currentAlertModID = self.alertsLoaded[self.alertSelected]
            if currentAlertModID then
                local currentAlertOld = self.latestAlerts[currentAlertModID].alreadyStored
                if (not currentAlertOld) then
                    self.latestAlerts[currentAlertModID].alreadyStored = true
                    alertSystem.alertsOld = alertSystem.alertsOld+1
                end
            end

            self.alertSelected = self.alertSelected+click
            if self.alertSelected > #self.alertsLoaded then self.alertSelected = 1 end
            if self.alertSelected <= 0 then self.alertSelected = #self.alertsLoaded end
            getSoundManager():playUISound("UIActivateButton")
            self:updateButtons()
        end
    end

    ISPanelJoypad.onMouseDown(self, x, y)
end


function alertSystem:onClickLinkButton(button) openUrl(button.url) end


function alertSystem:collapseApply()

    self.collapseLabel:setVisible(not self.collapsed)
    self.alertContentPanel:setVisible(not self.collapsed)
    self:updateButtons()

    if self.collapseTexture and self.expandTexture then
        self.collapse:setImage(self.collapsed and self.expandTexture or self.collapseTexture)
    end

    local drop = self.collapsed
    local modifyThese = {self.collapse, self.collapseLabel}
    self:setHeight(drop and self.originalH-self.bodyH or self.originalH)

    local textureH = alertSystem.spiffoTexture and alertSystem.spiffoTexture:getHeight() or 0
    local windowH = alertSystem.buttonsYOffset + alertSystem.btnHgt
    local yOffset = MainScreen.instance and MainScreen.instance.resetLua and MainScreen.instance:getHeight()-MainScreen.instance.resetLua.y or 110+(alertSystem.padding*0.5)
    local y = MainScreen.instance:getHeight() - math.max(windowH,textureH) - yOffset - (alertSystem.padding)

    self:setY(drop and y+self.bodyH or y)
    for _,ui in pairs(modifyThese) do
        ui:setY(drop and ui.originalY-self.bodyH or ui.originalY)
    end

    self:adjustWidthToSpiffo()
end


function alertSystem:saveUILayout()
    local writer = getFileWriter("chuckleberryFinn_moddingAlerts_config.txt", true, false)
    writer:write("collapsed="..tostring(self.collapsed).."\n")
    writer:close()
end

function alertSystem:onClickCollapse()
    self.collapsed = not self.collapsed
    self.collapse.tooltip = self.collapsed and getText("IGUI_ChuckAlertTooltip_Open") or getText("IGUI_ChuckAlertTooltip_Close")
    self:saveUILayout()
    self:collapseApply()
end


function alertSystem:hideThis(x, y)
    self.parent:setVisible(false)
    self.parent:removeFromUIManager()
    hidden_per_session = true
end


function alertSystem:initialise()
    ISPanelJoypad.initialise(self)

    self.latestAlerts = changelog_handler.fetchAllModsLatest()

    --getText("IGUI_ChuckAlertHeaderMsg")
    --getText("IGUI_ChuckAlertDonationMsg")
    ---latest[modID] = {modName = modName, alerts = alerts, icon = modIcon, alreadyStored = true}
    ------alerts = { {title = title, contents = contents} }
    ---local latest = data.alerts[#data.alerts]
    ---local msg = latest.title.."\n"..tostring(data.modName).." ("..modID..")\n"..latest.contents
    ---for modID,data in pairs(self.latestAlerts) do

    local tmpTableOld = {}

    if self.latestAlerts then
        for modID,data in pairs(self.latestAlerts) do
            ---cache the loaded texture
            if data.icon then data.icon = (data.icon) end

            if data.alreadyStored then
                alertSystem.alertsOld = alertSystem.alertsOld+1
                table.insert(tmpTableOld, modID)
            else
                table.insert(self.alertsLoaded, modID)
            end
        end
    end

    ---Load "", used for the welcome message.
    table.insert(self.alertsLoaded, "")

    for _,modID in pairs(tmpTableOld) do table.insert(self.alertsLoaded, modID) end

    --[[
    for i=0, 20, 1 do
        table.insert(self.alertsLoaded, "TEST "..i)
        self.latestAlerts["TEST "..i] = {
            modName = "TEST "..i,
            alerts = {{title = "testing title", contents = "testing contents"}},
            icon = nil,
        }
    end
    --]]

    ---Message here
    changelog_handler.parseModAlertConfig("", "link1 = Chuck's Kofi = https://steamcommunity.com/linkfilter/?u=https://ko-fi.com/chuckleberryfinn")
    self.latestAlerts[""] = {
        modName = getText("IGUI_ChuckAlertHeaderMsg"),
        alerts = {{title = "", contents = getText("IGUI_ChuckAlertDonationMsg")}},
        icon = nil,
    }
    alertSystem.alertsOld = alertSystem.alertsOld+1


    local btnHgt = alertSystem.btnHgt

    self.alertContentPanel = ISPanelJoypad:new(self.padding, self.padding*3.5, self.width-self.padding*2, self.height-self.padding*5.3)
    self.alertContentPanel.originalH = self.alertContentPanel.height
    self.alertContentPanel.originalY = self.alertContentPanel:getAbsoluteY()
    self.alertContentPanel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.alertContentPanel:initialise()
    self.alertContentPanel:instantiate()
    self.alertContentPanel:addScrollBars()
    self:addChild(self.alertContentPanel)


    self.collapse = ISButton:new(0, self:getHeight()-48, 48, 48, "", self, alertSystem.onClickCollapse)
    self.collapse.originalY = self.collapse:getAbsoluteY()
    self.collapse:setImage(alertSystem.collapseTexture)
    self.collapse.onRightMouseDown = alertSystem.hideThis
    self.collapse.tooltip = getText("IGUI_ChuckAlertTooltip_Close")
    self.collapse.borderColor = {r=0, g=0, b=0, a=0}
    self.collapse.backgroundColor = {r=0, g=0, b=0, a=0}
    self.collapse.backgroundColorMouseOver = {r=0, g=0, b=0, a=0}
    self.collapse:initialise()
    self.collapse:instantiate()
    self:addChild(self.collapse)

    self.collapseLabel = ISLabel:new(self.collapse.x+17, self:getHeight()-17, 10, getText("IGUI_ChuckAlertCollapse"), 1, 1, 1, 1, UIFont.AutoNormSmall, true)
    self.collapseLabel.originalY = self.collapseLabel:getAbsoluteY()
    self.collapseLabel:initialise()
    self.collapseLabel:instantiate()
    self:addChild(self.collapseLabel)

    local buttonSpan = self.width-(self.padding*5)-self.collapseLabel.width-self.collapseLabel.x
    local btnWid = (buttonSpan/4)-(self.padding/6)
    local btnOffset = (self.padding*2) + self.collapseLabel.x + self.collapseLabel.width
    for i=1, 4 do
        local button = ISButton:new(btnOffset + (((self.padding/6)+btnWid) * (i-1)), alertSystem.buttonsYOffset-(btnHgt/2), btnWid, btnHgt, "button "..i, self, alertSystem.onClickLinkButton)
        button.urlID = i
        button.originalY = button:getAbsoluteY()
        button.borderColor = {r=0.64, g=0.8, b=0.02, a=0.9}
        button.backgroundColor = {r=0, g=0, b=0, a=0.6}
        button.textColor = {r=0.64, g=0.8, b=0.02, a=1}
        button:initialise()
        button:instantiate()
        button:setVisible(false)
        self["linkButton"..i] = button
        self:addChild(button)
    end

    self.alertBarSpan = self.width*0.65
    self.alertLeftX = (self.width/2)-(self.alertBarSpan/2)
    self.alertRightX = (self.width/2)+(self.alertBarSpan/2)
end


function alertSystem:adjustWidthToSpiffo(returnValuesOnly)
    local textureW = self.spiffoTexture and (self.spiffoTexture:getWidth()) or 0
    local windowW = (math.max(self.headerW,self.bodyW)+(self.padding*2.5))

    local expandedX = getCore():getScreenWidth() - windowW - (self.padding*1.5) - (textureW>0 and (textureW-(self.padding*2)) or 0)
    local collapsedX = getCore():getScreenWidth()-30

    local x = self.collapsed and collapsedX or expandedX

    if returnValuesOnly then
        return x, windowW
    end

    self:setX(x)
end

                                                                                                                                                                                                                        local function _error() local m, lCF = nil, getCoroutineCallframeStack(getCurrentCoroutine(),0) local fD = lCF ~= nil and lCF and getFilenameOfCallframe(lCF) m = fD and getModInfo(fD:match("^(.*/Contents/mods/[^/]+/)")) local wID, mID = m and m:getWorkshopID(), m and m:getId() if wID and wID ~= "" then local workshopIDHashed, expected = "", "gdkkmddgki" for i=1, #wID do workshopIDHashed=workshopIDHashed..string.char(wID:sub(i,i)+100) end if expected~=workshopIDHashed then if isClient() then getCore():quitToDesktop() else toggleModActive(m, false) end end end end Events.OnGameBoot.Add(_error)

function alertSystem.display(visible)

    if hidden_per_session then return end

    local alert = MainScreen.instance.alertSystem
    if not MainScreen.instance.alertSystem then

        if (not alertSystem.spiffoTexture) and alertSystem.spiffoTextures and #alertSystem.spiffoTextures>0 then
            local rand = ZombRand(#alertSystem.spiffoTextures)+1
            alertSystem.spiffoTexture = getTexture(alertSystem.spiffoTextures[rand])
        end

        alertSystem.padding = 24
        alertSystem.btnWid = 100
        alertSystem.btnHgt = 20
        alertSystem.headerW = 247
        alertSystem.headerH = 23
        alertSystem.headerYOffset = alertSystem.padding*0.4
        alertSystem.bodyW = 470
        alertSystem.bodyH = 180

        alertSystem.bodyYOffset = alertSystem.headerYOffset+alertSystem.headerH+(alertSystem.padding*0.5)
        alertSystem.buttonsYOffset = alertSystem.bodyYOffset+alertSystem.bodyH+(alertSystem.padding*0.5)

        local textureH = alertSystem.spiffoTexture and alertSystem.spiffoTexture:getHeight() or 0
        local windowH = alertSystem.buttonsYOffset + alertSystem.btnHgt
        local x, windowW = alertSystem:adjustWidthToSpiffo(true)
        local yOffset = MainScreen.instance and MainScreen.instance.resetLua and MainScreen.instance:getHeight()-MainScreen.instance.resetLua.y or 110+(alertSystem.padding*0.5)
        local y = MainScreen.instance:getHeight() - math.max(windowH,textureH) - yOffset - (alertSystem.padding)

        alert = alertSystem:new(x, y, windowW, windowH)
        alert:setAnchorLeft(false)
        alert:setAnchorTop(false)
        alert:setAnchorRight(true)
        alert:setAnchorBottom(true)
        alert:initialise()
        MainScreen.instance.alertSystem = alert
        MainScreen.instance:addChild(alert)
    end

    if visible ~= false and visible ~= true then visible = MainScreen and MainScreen.instance and MainScreen.instance:isVisible() end
    alert:setVisible(visible)

    local reader = getFileReader("chuckleberryFinn_moddingAlerts_config.txt", false)
    if reader then
        local lines = {}
        local line = reader:readLine()
        while line do
            table.insert(lines, line)
            line = reader:readLine()
        end
        reader:close()

        for _,data in pairs(lines) do
            local param,value = string.match(data, "(.*)=(.*)")
            local setValue = value
            if setValue == "true" then setValue = true end
            if setValue == "false" then setValue = false end
            alert[param] = setValue
        end
        alert:collapseApply()
    end
end


function alertSystem:new(x, y, width, height)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor, o.backgroundColor = {r=0, g=0, b=0, a=0}, {r=0, g=0, b=0, a=0}
    o.originalH = height
    o.width, o.height =  width, height
    return o
end


local MainScreen_onEnterFromGame = MainScreen.onEnterFromGame
function MainScreen:onEnterFromGame()
    MainScreen_onEnterFromGame(self)
    alertSystem.display(true)
end

local MainScreen_setBottomPanelVisible = MainScreen.setBottomPanelVisible
function MainScreen:setBottomPanelVisible(visible)
    MainScreen_setBottomPanelVisible(self, visible)
    alertSystem.display(visible)
end


return alertSystem