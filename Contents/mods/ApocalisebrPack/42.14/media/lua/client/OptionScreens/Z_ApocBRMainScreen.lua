-- Client title-screen presentation for ApocBR. Keeping a distinct filename
-- lets the vanilla MainScreen.lua load and register its own callbacks first.
local function hasApocBRClientApi()
    -- The title state runs before GameClient.client becomes true, so isClient()
    -- is false here even in the client application. The agent exposes this API
    -- only in client processes, making its presence the client-side gate.
    return type(ApocBRClientApi) == "table"
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

    if screen.optionsOption then
        screen.optionsOption:setVisible(true)
        screen.optionsOption:setY(0)
    end
    if screen.exitOption then
        screen.exitOption:setVisible(true)
        screen.exitOption:setY(screen.optionsOption and screen.optionsOption:getBottom() + 12 or 0)
    end
    if screen.optionsOption and screen.exitOption then
        screen.bottomPanel:setHeight(screen.exitOption:getBottom())
    end

    if not screen.apocBRCards then
        screen.apocBRCards = {}
        local cardNames = { "Server One", "Server Two", "Server Three" }
        local cardGap = 24
        local cardWidth = (getCore():getScreenWidth() - cardGap * 4) / 3
        local cardHeight = 190
        local cardY = (getCore():getScreenHeight() - cardHeight) / 2

        for index, cardName in ipairs(cardNames) do
            local card = ISPanel:new(0, cardY, cardWidth, cardHeight)
            card:initialise()
            card.backgroundColor = { r = 0.04, g = 0.05, b = 0.06, a = 0.78 }
            card.borderColor = { r = 0.75, g = 0.75, b = 0.75, a = 0.8 }
            screen:addChild(card)

            local title = ISLabel:new(0, 18, 30, cardName, 1, 1, 1, 1, UIFont.Large, true)
            title:initialise()
            card:addChild(title)
            card.apocBRTitle = title
            screen.apocBRCards[index] = card
        end
    end
end

local function layoutMenu(screen)
    if not screen.apocBRCustomMenu or not hasApocBRClientApi() then
        return
    end

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
    local cardHeight = 190
    local cardY = (height - cardHeight) / 2
    for index, card in ipairs(screen.apocBRCards or {}) do
        card:setX(cardGap + (index - 1) * (cardWidth + cardGap))
        card:setY(cardY)
        card:setWidth(cardWidth)
        card:setHeight(cardHeight)
        card.apocBRTitle:setX((cardWidth - card.apocBRTitle:getWidth()) / 2)
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
