-- ============================================================================
-- File: media/lua/client/RegionManager_AdminPanel.lua
-- Admin-only UI for region management and teleportation
-- ============================================================================

if not isClient() then return end

require "RegionManager_Config"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"

RegionManager.AdminPanel = RegionManager.AdminPanel or {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

-- Main panel class
ISRegionManagerAdminPanel = ISPanel:derive("ISRegionManagerAdminPanel")

function ISRegionManagerAdminPanel:initialise()
    ISPanel.initialise(self)
end

function ISRegionManagerAdminPanel:createChildren()
    ISPanel.createChildren(self)
    
    local btnWid = 100
    local btnHgt = math.max(25, FONT_HGT_SMALL + 3 * 2)
    local padBottom = 10
    
    -- Title
    self.titleLabel = ISLabel:new(10, 10, FONT_HGT_MEDIUM, "Region Manager - Admin Panel", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self:addChild(self.titleLabel)
    
    -- Region list
    local listY = 60
    local listHeight = self.height - listY - btnHgt - padBottom - 20
    
    self.regionList = ISScrollingListBox:new(10, listY, self.width - 20, listHeight)
    self.regionList:initialise()
    self.regionList:instantiate()
    self.regionList.itemheight = FONT_HGT_SMALL + 4 * 2
    self.regionList.selected = 0
    self.regionList.joypadParent = self
    self.regionList.font = UIFont.Small
    self.regionList.doDrawItem = self.drawRegionListItem
    self.regionList.drawBorder = true
    self:addChild(self.regionList)
    
    -- Teleport button
    local btnY = self.height - btnHgt - padBottom
    self.teleportBtn = ISButton:new(10, btnY, btnWid, btnHgt, "Teleport", self, ISRegionManagerAdminPanel.onTeleport)
    self.teleportBtn:initialise()
    self.teleportBtn:instantiate()
    self.teleportBtn.borderColor = {r=1, g=1, b=1, a=0.4}
    self:addChild(self.teleportBtn)
    
    -- Refresh button
    self.refreshBtn = ISButton:new(10 + btnWid + 10, btnY, btnWid, btnHgt, "Refresh", self, ISRegionManagerAdminPanel.onRefresh)
    self.refreshBtn:initialise()
    self.refreshBtn:instantiate()
    self.refreshBtn.borderColor = {r=1, g=1, b=1, a=0.4}
    self:addChild(self.refreshBtn)
    
    -- Close button
    self.closeBtn = ISButton:new(self.width - btnWid - 10, btnY, btnWid, btnHgt, "Close", self, ISRegionManagerAdminPanel.onClose)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self.closeBtn.borderColor = {r=1, g=1, b=1, a=0.4}
    self:addChild(self.closeBtn)
    
    -- Populate list
    self:populateList()
end

function ISRegionManagerAdminPanel:drawRegionListItem(y, item, alt)
    local a = 0.9
    
    -- Background
    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
    end
    
    -- Region name
    self:drawText(item.text, 10, y + 4, 1, 1, 1, a, self.font)
    
    -- Coordinates on second line with more spacing
    local region = item.item.region
    local coordText = string.format("(%d, %d) → (%d, %d)", region.x1, region.y1, region.x2, region.y2)
    self:drawText(coordText, 10, y + 6 + FONT_HGT_SMALL, 0.7, 0.7, 0.7, a, UIFont.Small)
    
    -- Status on first line, right-aligned
    local statusText = region.enabled and "Enabled" or "Disabled"
    local statusColor = region.enabled and {r=0.3, g=1, b=0.3} or {r=1, g=0.3, b=0.3}
    self:drawText(statusText, self:getWidth() - 90, y + 4, statusColor.r, statusColor.g, statusColor.b, a, UIFont.Small)
    
    return y + self.itemheight
end

function ISRegionManagerAdminPanel:populateList()
    self.regionList:clear()
    
    -- Use zones received from server (stored in Client.zoneData)
    if RegionManager and RegionManager.Client and RegionManager.Client.zoneData then
        local zoneData = RegionManager.Client.zoneData
        
        if #zoneData > 0 then
            for i, zone in ipairs(zoneData) do
                local displayName = zone.name or zone.id
                
                -- Create a region structure from zone data
                local region = {
                    id = zone.id,
                    name = zone.name,
                    x1 = zone.bounds.minX,
                    y1 = zone.bounds.minY,
                    x2 = zone.bounds.maxX,
                    y2 = zone.bounds.maxY,
                    z = 0,
                    enabled = true,
                    categories = {}  -- Categories not sent by server currently
                }
                
                self.regionList:addItem(displayName, {region = region, bounds = zone.bounds})
            end
            
            print("[RegionManager Admin] Populated list with " .. #zoneData .. " zones from server")
            return
        end
    end
    
    -- Fallback to config if no zones received from server yet
    print("[RegionManager Admin] WARNING: No zones received from server, using config fallback")
    if RegionManager and RegionManager.Config and RegionManager.Config.Regions then
        for i, region in ipairs(RegionManager.Config.Regions) do
            local displayName = region.name or region.id
            local categories = table.concat(region.categories or {}, ", ")
            if categories ~= "" then
                displayName = displayName .. " [" .. categories .. "]"
            end
            
            -- Wrap config region in data structure
            self.regionList:addItem(displayName, {region = region, properties = {}, zone = nil})
        end
    end
end

function ISRegionManagerAdminPanel:onTeleport()
    local selectedItem = self.regionList.items[self.regionList.selected]
    if not selectedItem then
        local player = getPlayer()
        if player then
            player:Say("Please select a region first.", 1, 0.5, 0, UIFont.Small, 2, "radio")
        end
        return
    end
    
    local region = selectedItem.item.region
    local player = getPlayer()
    
    if player then
        -- Use teleport command instead of direct teleportation
        local z = region.z or 0
        local command = string.format("/teleportto %d,%d,%d", region.x1, region.y1, z)
        
        -- Send command through chat processor
        player:Say(command)
        
        -- Message
        local msg = string.format("Teleporting to %s (%d, %d, %d)", region.name or region.id, region.x1, region.y1, z)
        player:Say(msg, 0.3, 1, 0.3, UIFont.Medium, 3, "radio")
        
        -- Log
        print("[RegionManager Admin] Teleport command: " .. command)
    end
    
    -- Close panel after teleport
    self:close()
end

function ISRegionManagerAdminPanel:onRefresh()
    self:populateList()
    local player = getPlayer()
    if player then
        player:Say("Region list refreshed", 0.7, 0.7, 1, UIFont.Small, 2, "radio")
    end
end

function ISRegionManagerAdminPanel:onClose()
    self:close()
end

function ISRegionManagerAdminPanel:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

function ISRegionManagerAdminPanel:new(x, y, width, height)
    local o = {}
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0, g=0, b=0, a=0.9}
    o.moveWithMouse = true
    return o
end

-- Helper function to check if player is admin or in debug mode
local function isAdminOrDebug(player)
    if not player then return false end
    
    -- Check debug mode
    if isDebugEnabled() then return true end
    
    -- Check access level
    local accessLevel = player:getAccessLevel()
    return accessLevel == "admin" or accessLevel == "moderator"
end

-- Public function to open the admin panel
function RegionManager.AdminPanel.Open()
    local player = getPlayer()
    if not player then return end
    
    -- Check admin access or debug mode
    if not isAdminOrDebug(player) then
        player:Say("Access denied. Admin only.", 1, 0.3, 0.3, UIFont.Medium, 2, "radio")
        return
    end
    
    -- Create and show panel
    local width = 600
    local height = 500
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    
    local panel = ISRegionManagerAdminPanel:new(x, y, width, height)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    
    print("[RegionManager Admin] Panel opened by: " .. player:getUsername())
end

-- Context menu integration
local function OnFillWorldObjectContextMenu(player, context, worldobjects, test)
    if not player then return end
    
    -- Only show for admins or debug mode
    if not isAdminOrDebug(player) then return end
    
    -- Add admin menu option (simple version without tooltip)
    context:addOption("Region Manager (Admin)", nil, RegionManager.AdminPanel.Open)
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)

print("[RegionManager Admin] Admin panel module loaded")

return RegionManager.AdminPanel
