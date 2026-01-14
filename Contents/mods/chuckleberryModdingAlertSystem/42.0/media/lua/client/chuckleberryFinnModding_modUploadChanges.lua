require "OptionScreens/WorkshopSubmitScreen"
local changelog_handler = require "chuckleberryFinnModding_modChangelog"

---@param workshopItem SteamWorkshopItem
local function WorkshopSubmitScreen_generateChangelog(workshopItem)

    if not workshopItem or workshopItem:getChangeNote() ~= "" then return end

    local desc = workshopItem:getSubmitDescription()

    local mod_id
    for line in desc:gmatch("[^\r\n]+") do
        mod_id = line:match("^Mod ID:%s*(.+)$")
    end

    if not mod_id then return end

    local alerts = changelog_handler.fetchMod("\\"..mod_id)
    local latest = alerts and alerts[#alerts]

    local latestTitle = latest and latest.title or ""
    local latestContents = latest and latest.contents or ""

    local latestChangeLog = latestTitle.."\n"..latestContents
    
    if latestChangeLog:match("^%s*\n") then
        latestChangeLog = latestChangeLog:gsub("^%s*\n", "", 1)
    end

    workshopItem:setChangeNote(latestChangeLog)
end


local original_create = WorkshopSubmitScreen.create

function WorkshopSubmitScreen:create()
    original_create(self)

    local pg2 = self.page2
    local original_setWorkshopItem = pg2.setWorkshopItem
    pg2.setWorkshopItem = function(self, item)
        original_setWorkshopItem(self, item)
        WorkshopSubmitScreen_generateChangelog(self.parent.item)
    end
end

