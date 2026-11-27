-- Client title-screen presentation for ApocBR. Keeping a distinct filename
-- lets the vanilla MainScreen.lua load and register its own callbacks first.
local function hasApocBRClientApi()
    -- The title state runs before GameClient.client becomes true, so isClient()
    -- is false here even in the client application. The agent exposes this API
    -- only in client processes, making its presence the client-side gate.
    return type(ApocBRClientApi) == "table"
end

ApocBRMainMenu = ApocBRMainMenu or {}
local SERVER_THEMES = {
    ["apoc-1"] = { r = 0.35, g = 0.74, b = 0.98 },
    ["apoc-2"] = { r = 0.98, g = 0.34, b = 0.31 },
    ["apoc-extraction"] = { r = 1, g = 0.68, b = 0.3 },
    default = { r = 0.66, g = 0.84, b = 1 },
}
ApocBRMainMenu.servers = ApocBRMainMenu.servers or {
    { id = "apoc-1", name = "UI_ApocBR_Server_One", descriptionKey = "UI_ApocBR_Server_One_Description", ip = "apocalipse.cloud", port = "16261" },
    { id = "apoc-2", name = "UI_ApocBR_Server_Two", descriptionKey = "UI_ApocBR_Server_Two_Description", ip = "server2.apocalipse.cloud", port = "16261" },
    { id = "apoc-extraction", name = "UI_ApocBR_Server_Three", descriptionKey = "UI_ApocBR_Server_Extraction_Description", ip = "extracao.apocalipse.cloud", port = "16263" },
}

function ApocBRMainMenu.registerServers(servers)
    ApocBRMainMenu.servers = {}
    for index, server in ipairs(servers or {}) do
        local registered = {}
        for key, value in pairs(server) do
            registered[key] = value
        end
        registered.themeColor = registered.themeColor or SERVER_THEMES[registered.id] or SERVER_THEMES.default
        if registered.descriptionKey then
            registered.description = getText(registered.descriptionKey)
        end
        if registered.name then
            registered.name = getText(registered.name)
        end
        ApocBRMainMenu.servers[index] = registered
    end
    local screen = MainScreen and MainScreen.instance
    if screen and screen.apocBRCustomMenu then
        screen.apocBRRebuildCards = true
    end
end

for _, server in ipairs(ApocBRMainMenu.servers) do
    server.themeColor = server.themeColor or SERVER_THEMES[server.id] or SERVER_THEMES.default
    if server.descriptionKey and not server.description then
        server.description = getText(server.descriptionKey)
    end
    if server.name then
        server.name = getText(server.name)
    end
end

-- Must match SteamLoginPacketPayload.AUTH_TYPE in the client and server agent.
local STEAM_LOGIN_AUTH_TYPE = 0x41504252
local pendingAuthorization

function ApocBRMainMenu.connectToServer(server, card)
    if not hasApocBRClientApi() or pendingAuthorization then
        return
    end

    local status = ApocBRClientApi.status()
    if not status.steamReady or not status.steamId then
        card.ticketState = getText("UI_ApocBR_Auth_SteamUnavailable")
        return
    end
    if not status.apiConfigured or not ApocBRClientApi.requestSteamAuthorization
            or not ApocBRClientApi.requestSteamUsername or not ApocBRClientApi.pollSteamUsername then
        card.ticketState = getText("UI_ApocBR_Auth_BackendUnavailable")
        return
    end

    local requestId = ApocBRClientApi.requestSteamAuthorization()
    if not requestId then
        card.ticketState = getText("UI_ApocBR_Auth_Failed", ApocBRClientApi.status().steamTicketRequest)
        return
    end

    ApocBRMainMenu.authorization = nil
    pendingAuthorization = { id = requestId, server = server, steamId = status.steamId, card = card }
    card.ticketState = getText("UI_ApocBR_Auth_Pending")
end

local function startMultiplayerLogin(screen, attempt, authorization)
    local server = attempt.server
    local connectScreen = screen.connectToServer
    local port = tonumber(server.port)
    if not connectScreen or type(server.ip) ~= "string" or server.ip == ""
            or not port or port < 1 or port > 65535 or port % 1 ~= 0 then
        attempt.card.ticketState = getText("UI_ApocBR_Auth_Failed", "CONNECTION_UNAVAILABLE")
        print("[ApocBR][ClientMenu] APBR login handoff unavailable for server " .. tostring(server.id))
        return
    end

    attempt.card.ticketState = getText("UI_ApocBR_Auth_UsernameReady", authorization.username)
    print("[ApocBR][ClientMenu] Username resolved; starting APBR login for server " .. tostring(server.id))
    getCore():setNoSave(false)
    connectScreen:connect(screen.bottomPanel, server.name or "", authorization.username,
        authorization.token, server.ip, server.localIP or "", tostring(port),
        server.serverPassword or "", server.useSteamRelay == true, false, STEAM_LOGIN_AUTH_TYPE)
    authorization.token = nil
end

local function pollAuthorization(screen)
    local now = getTimestampMs()
    local authorization = ApocBRMainMenu.authorization
    if authorization and now >= authorization.expiresAtMs then
        ApocBRMainMenu.authorization = nil
        authorization = nil
    end

    local attempt = pendingAuthorization
    if not attempt then return end

    if attempt.usernameRequestId then
        if not authorization or now >= attempt.usernameDeadlineMs then
            pendingAuthorization = nil
            attempt.card.ticketState = getText("UI_ApocBR_Auth_Failed",
                authorization and "USERNAME_LOOKUP_TIMED_OUT" or "AUTHORIZATION_EXPIRED")
            return
        end
        if not screen.bottomPanel:isVisible() then return end
        local result = ApocBRClientApi.pollSteamUsername(attempt.usernameRequestId)
        if not result then return end
        pendingAuthorization = nil
        if result.ok then
            authorization.username = result.username
            startMultiplayerLogin(screen, attempt, authorization)
        else
            local reason = result.error
            if result.status ~= 0 then reason = reason .. " " .. tostring(result.status) end
            attempt.card.ticketState = getText("UI_ApocBR_Auth_Failed", reason)
        end
        return
    end

    local result = ApocBRClientApi.pollSteamAuthorization(attempt.id)
    if not result then return end

    if result.ok then
        ApocBRMainMenu.authorization = {
            token = result.token,
            serverId = attempt.server.id,
            expiresAtMs = now + result.expiresInSeconds * 1000,
        }
        attempt.usernameRequestId = ApocBRClientApi.requestSteamUsername(attempt.steamId, result.token)
        if not attempt.usernameRequestId then
            pendingAuthorization = nil
            attempt.card.ticketState = getText("UI_ApocBR_Auth_Failed", "USERNAME_LOOKUP_NOT_STARTED")
            return
        end
        attempt.usernameDeadlineMs = now + 15000
        attempt.card.ticketState = getText("UI_ApocBR_Auth_UsernamePending")
    else
        pendingAuthorization = nil
        local reason = result.error
        if result.status ~= 0 then reason = reason .. " " .. tostring(result.status) end
        attempt.card.ticketState = getText("UI_ApocBR_Auth_Failed", reason)
    end
end

local function wrapText(text, font, maxWidth)
    local lines = {}
    local textManager = getTextManager()
    maxWidth = math.max(1, maxWidth)

    for paragraph in string.gmatch(tostring(text or "") .. "\n", "(.-)\n") do
        local line = ""
        for word in string.gmatch(paragraph, "%S+") do
            local candidate = line == "" and word or line .. " " .. word
            if line ~= "" and textManager:MeasureStringX(font, candidate) > maxWidth then
                lines[#lines + 1] = line
                line = word
            else
                line = candidate
            end
        end
        lines[#lines + 1] = line
    end

    return lines
end

local function createServerCard(screen, server)
    local card = ISPanel:new(0, 0, 100, 475)
    card:initialise()
    card.server = server
    card.hoverAmount = 0
    card.hoverDurationMs = 140
    card.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    card.backgroundColor = { r = 0.04, g = 0.05, b = 0.06, a = 0.78 }
    card.prerender = function(self)
        ISPanel.prerender(self)
        local target = self:isMouseOver() and 1 or 0
        local elapsed = math.max(0, UIManager.getMillisSinceLastRender())
        local step = elapsed / self.hoverDurationMs
        if target > self.hoverAmount then
            self.hoverAmount = math.min(target, self.hoverAmount + step)
        else
            self.hoverAmount = math.max(target, self.hoverAmount - step)
        end
        local themeColor = self.server.themeColor or SERVER_THEMES.default
        local inset = 10 + self.hoverAmount * 4
        self:drawRectBorder(inset, inset, self.width - inset * 2,
            self.height - inset * 2, 0.8 + self.hoverAmount * 0.2,
            themeColor.r, themeColor.g, themeColor.b)
        local textWidth = self.width - 48
        local titleLines = wrapText(self.server.name or "Server", UIFont.Large, textWidth)
        local titleY = 26
        local titleLineHeight = getTextManager():getFontHeight(UIFont.Large)
        for _, line in ipairs(titleLines) do
            self:drawTextCentre(line, self.width / 2, titleY,
                themeColor.r, themeColor.g, themeColor.b, 1, UIFont.Large)
            titleY = titleY + titleLineHeight
        end
        local description = self.server.description or ""
        local descriptionY = math.max(82, titleY + 12)
        local descriptionLineHeight = getTextManager():getFontHeight(UIFont.Medium)
        for _, line in ipairs(wrapText(description, UIFont.Medium, textWidth)) do
            self:drawText(line, 24, descriptionY, 0.9, 0.9, 0.9, 1, UIFont.Medium)
            descriptionY = descriptionY + descriptionLineHeight
        end
        if self.ticketState then
            local ticketY = descriptionY + 16
            local ticketLineHeight = getTextManager():getFontHeight(UIFont.Small)
            for _, line in ipairs(wrapText(self.ticketState, UIFont.Small, textWidth)) do
                self:drawText(line, 24, ticketY, 0.85, 0.88, 0.92, 1, UIFont.Small)
                ticketY = ticketY + ticketLineHeight
            end
        end
        local infoFont = UIFont.Small
        local infoValueColor = { r = 0.9, g = 0.92, b = 0.96 }
        local ipLabel = "IP:"
        local ipY = self.height - 100
        self:drawText(ipLabel, 24, ipY, themeColor.r, themeColor.g, themeColor.b, 1, infoFont)
        self:drawText(tostring(self.server.ip or "Not configured"),
            24 + getTextManager():MeasureStringX(infoFont, ipLabel) + 8, ipY,
            infoValueColor.r, infoValueColor.g, infoValueColor.b, 1, infoFont)
        local portLabel = "Porta:"
        local portY = self.height - 74
        self:drawText(portLabel, 24, portY, themeColor.r, themeColor.g, themeColor.b, 1, infoFont)
        self:drawText(tostring(self.server.port or "Not configured"),
            24 + getTextManager():MeasureStringX(infoFont, portLabel) + 8, portY,
            infoValueColor.r, infoValueColor.g, infoValueColor.b, 1, infoFont)
        if self.hoverAmount > 0.05 then
            local alpha = math.min(1, self.hoverAmount * 1.5)
            local connectY = self.height - 48
            self:drawRect(20, connectY - 4, self.width - 40, 34,
                alpha * 0.9, themeColor.r * 0.22, themeColor.g * 0.22, themeColor.b * 0.22)
            self:drawTextCentre(getText("UI_ApocBR_Server_Connect"), self.width / 2, connectY,
                1, 1, 1, alpha, UIFont.Small)
        end
    end
    card.onMouseDown = function(self)
        ApocBRMainMenu.connectToServer(self.server, self)
        return true
    end
    screen:addChild(card)
    return card
end

local function customizeTitleMenu(screen)
    if not hasApocBRClientApi() or not screen or screen.inGame then
        return
    end

    screen.apocBRCustomMenu = true

    local hiddenOptions = {
        screen.latestSaveOption,
        screen.loadOption,
        screen.tutorialOption,
        screen.survivalOption,
        screen.onlineOption,
        screen.onlineCoopOption,
        screen.modsOption,
        screen.workshopOption,
        screen.creditOption,
        screen.returnOption,
        screen.scoreOption,
        screen.inviteOption,
    }
    for _, option in ipairs(hiddenOptions) do
        if option then
            option:setVisible(false)
        end
    end

    if screen.exitOption and not screen.apocBROriginalExitY then
        screen.apocBROriginalExitY = screen.exitOption:getY()
    end
    if screen.optionsOption then
        screen.optionsOption:setVisible(true)
        screen.optionsOption:setY(screen.exitOption
            and screen.apocBROriginalExitY - screen.optionsOption:getHeight() - 12 or 0)
    end
    if screen.exitOption then
        screen.exitOption:setVisible(true)
        screen.exitOption:setY(screen.apocBROriginalExitY or screen.exitOption:getY())
    end
    if screen.optionsOption and screen.exitOption then
        screen.bottomPanel:setHeight(screen.exitOption:getBottom())
    end

    if not screen.apocBRCards or screen.apocBRRebuildCards then
        for _, card in ipairs(screen.apocBRCards or {}) do
            screen:removeChild(card)
        end
        screen.apocBRCards = {}
        for index, server in ipairs(ApocBRMainMenu.servers) do
            screen.apocBRCards[index] = createServerCard(screen, server)
        end
        screen.apocBRRebuildCards = false
    end
end

local function layoutMenu(screen)
    if not screen.apocBRCustomMenu or not hasApocBRClientApi() then
        return
    end

    pollAuthorization(screen)

    local width = getCore():getScreenWidth()
    local height = getCore():getScreenHeight()
    local logo = screen.logoTexture
    local scale = math.min(width / 1920, height / 1080) * 0.5
    local logoWidth = logo:getWidth() * scale
    local logoHeight = logo:getHeight() * scale

    screen:drawTextureScaled(logo, (width - logoWidth) / 2, 24,
        logoWidth, logoHeight, 1, 1, 1, 1)

    local cardGap = 24
    local cardWidth = (width - cardGap * 4) / 3
    local cardHeight = 475
    local cardY = (height - cardHeight) / 2
    for index, card in ipairs(screen.apocBRCards or {}) do
        card:setX(cardGap + (index - 1) * (cardWidth + cardGap))
        card:setY(cardY)
        card:setWidth(cardWidth)
        card:setHeight(cardHeight)
    end
end

Events.OnMainMenuEnter.Add(function()
    if not hasApocBRClientApi() then
        return
    end

    local screen = MainScreen and MainScreen.instance
    if not screen or screen.inGame then
        return
    end

    customizeTitleMenu(screen)

    if not screen.apocBRPrerenderHooked then
        local originalBottomPanelVisibility = screen.bottomPanel.setVisible
        screen.bottomPanel.setVisible = function(bottomPanel, visible, ...)
            originalBottomPanelVisibility(bottomPanel, visible, ...)
            for _, card in ipairs(screen.apocBRCards or {}) do
                card:setVisible(visible)
            end
        end

        local originalPrerender = screen.prerender
        screen.prerender = function(self, ...)
            local originalDrawTextureScaled = self.drawTextureScaled
            self.drawTextureScaled = function(panel, texture, ...)
                if texture == panel.logoTexture then
                    return
                end
                return originalDrawTextureScaled(panel, texture, ...)
            end
            originalPrerender(self, ...)
            self.drawTextureScaled = originalDrawTextureScaled
            layoutMenu(self)
        end
        screen.apocBRPrerenderHooked = true
    end
end)
