local changelog_handler = {}

changelog_handler.scannedMods = nil--{}
changelog_handler.freshAlerts = nil--{}
changelog_handler.modAlertConfig = {}

changelog_handler.defaultButtonColor = {r=0.64, g=0.8, b=0.02, a=0.75}
changelog_handler.buttonData = {
    ["https://steamcommunity.com/"] = { color = { r = 0.4, g = 0.753, b = 0.957, a = 0.75 }, icon = getTexture("common/media/textures/alert/steam.png"), },
    ["https://ko%-fi.com/"] = { color = { r = 0.447, g = 0.647, b = 0.949, a = 0.75 }, icon = getTexture("common/media/textures/alert/kofi.png"), },
    ["https://twitch.com/"] = { color = { r = 0.392, g = 0.255, b = 0.647, a = 0.75 }, icon = getTexture("common/media/textures/alert/twitch.png"), },
    ["https://discord.gg/"] = { color = { r = 0.345, g = 0.396, b = 0.949, a = 0.75 }, icon = getTexture("common/media/textures/alert/discord.png"), },
    ["https://youtube.com/"] = { color = { r = 0.95, g = 0.0, b = 0.0, a = 0.75 }, icon = getTexture("common/media/textures/alert/youtube.png"), },
    ["https://github.com/"] = { color = { r = 0.510, g = 0.314, b = 0.875, a = 0.75 }, icon = getTexture("common/media/textures/alert/github.png"), },
    ["https://patreon.com/"] = { color = { r = 0.976, g = 0.408, b = 0.329, a = 0.75 }, icon = getTexture("common/media/textures/alert/patreon.png"), },
    ["https://theindiestone.com/"] = { color = { r = 0.976, g = 0.149, b = 0.062, a = 0.75 }, icon = getTexture("common/media/textures/alert/theIndieStone.png"), },
    ["https://projectzomboid.com/"] = { color = { r = 0.976, g = 0.149, b = 0.062, a = 0.75 }, icon = getTexture("common/media/textures/alert/theIndieStone.png"), },
    ---Funny easter-egg haha... 🗿
    ["https://onlyfans.com/"] = { color = { r = 0.0, g = 0.686, b = 0.941, a = 0.75 }, icon = getTexture("common/media/textures/alert/fans.png"), },
}


function changelog_handler.fetchModAlertConfig(modID)
    return changelog_handler.modAlertConfig[modID]
end


function changelog_handler.parseModAlertConfig(modID, configText)

    local configTable = {}
    for key, t, u in configText:gmatch("(%w+)%s*=%s*([^=]+)%s*=%s*([^,]+),?") do

        local title = t:match("^%s*(.-)%s*$")
        local url = u:match("^%s*(.-)%s*$")
        local sanitizedUrl = string.gsub(url, "https://steamcommunity%.com/linkfilter/%?u=", "")
        local color = changelog_handler.defaultButtonColor
        local icon = nil
        for uu,data in pairs(changelog_handler.buttonData) do
            if string.find(sanitizedUrl, uu) then
                if data.color then color = data.color end
                if data.icon then icon = data.icon end
                break
            end
        end
        configTable[key] = { title = (icon and "" or title), url = url, color = color, icon = icon}
    end

    changelog_handler.modAlertConfig[modID] = configTable
end


function changelog_handler.scanMods()

    changelog_handler.scannedMods = {}
    local reader = getFileReader("chuckleberryFinn_moddingAlerts.txt", true)
    if reader then
        local lines = {}
        local line = reader:readLine()
        while line do
            table.insert(lines, line)
            line = reader:readLine()
        end
        reader:close()

        for _, line in ipairs(lines) do
            local key, value = string.match(line, "(.+) = (.+)")
            if key and value then
                changelog_handler.scannedMods[key] = value
            end
        end
    end
end


function changelog_handler.fetchAllModsLatest()

    if not changelog_handler.scannedMods then changelog_handler.scanMods() end

    local latest = nil--{}
    local writer = getFileWriter("chuckleberryFinn_moddingAlerts.txt", true, false)
    local activeModIDs = getActivatedMods()

    for i=1,activeModIDs:size() do
        local modID = activeModIDs:get(i-1)

        local modInfo = getModInfoByID(modID)
        local modName = modInfo and modInfo:getName()
        local latestTitleStored = changelog_handler.scannedMods and changelog_handler.scannedMods[modID]
        local alerts = changelog_handler.fetchMod(modID, latestTitleStored)
        if alerts then
            local latestCurrent = alerts[#alerts]
            local lCTitle = latestCurrent and latestCurrent.title

            latest = latest or {}
            latest[modID] = {modName = modName, alerts = alerts}

            if latestTitleStored and latestTitleStored == lCTitle then
                latest[modID].alreadyStored = true
            end

            if lCTitle then writer:write(modID.." = "..lCTitle.."\n") end
        end
    end

    writer:close()

    return latest
end


function changelog_handler.fetchMod(modID, latest)

    local reader = getModFileReader(modID, "media"..getFileSeparator().."ChangeLog.txt", false)

    local md = false
    if not reader then
        md = true
        reader = getModFileReader(modID, "media"..getFileSeparator().."ChangeLog.md", false)
    end

    if not reader then return end

    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()

    local completeText = table.concat(lines, "\n")

    local alerts = {}
    local pattern = md and "###%s*(.-)%s*###%s*(.-)%s*#" or "%[ ([^%]]+)% ](.-)%[ ------ %]"

    local config = md and completeText:match("<!%-%- ALERT_CONFIG\n(.-)\n%-%->")
    if config then
        changelog_handler.parseModAlertConfig(modID, config)
    end

    for title, contents in string.gmatch(completeText, pattern) do
        local cleaned_contents = contents:gsub("^%s*\n", "")
        if title == "ALERT_CONFIG" then
            changelog_handler.parseModAlertConfig(modID, cleaned_contents)
        else
            table.insert(alerts, {title = title, contents = cleaned_contents})
        end
    end

    if latest then
        local splitHere
        for i, alert in ipairs(alerts) do
            if alert.title == latest then
                splitHere = i
                break
            end
        end

        if splitHere then
            local newAlerts = {}
            for i = splitHere, #alerts do
                table.insert(newAlerts, alerts[i])
            end
            alerts = newAlerts
        end
    end

    if #alerts == 0 then return end
    return alerts
end


return changelog_handler