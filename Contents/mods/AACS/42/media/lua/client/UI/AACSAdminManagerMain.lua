-- UI/AACSAdminManagerMain.lua
-- Admin window to view/manage all adopted animals.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISPanel"
require "UI/AACSUITheme"

AACSAdminManagerMain = ISCollapsableWindow:derive("AACSAdminManagerMain")

-- ===== Icons in list (best-effort) =====
-- We try to use the same inventory icons as vanilla (AnimalDefinitions.breeds[*].invIconMale/Female/Baby),
-- including breed variations when we can infer them. This is client-only UI and MP-safe.

local _BASE_SPECIES = {
    cow=true, chicken=true, pig=true, sheep=true, deer=true, turkey=true, rabbit=true, raccoon=true, rat=true, mouse=true, horse=true,
}

-- Some servers/modpacks expose AnimalType as stage/sex ("boar","hen","buck"). Normalize back to the base species.
local _TYPE_NORMALIZE = {
    -- Chicken
    hen="chicken", rooster="chicken", cockerel="chicken", chick="chicken",
    -- Pig
    boar="pig", sow="pig", piglet="pig",
    -- Cow
    calf="cow", cowcalf="cow", bull="cow",
    -- Sheep
    lamb="sheep", ram="sheep", ewe="sheep",
    -- Deer
    buck="deer", doe="deer", fawn="deer",
    -- Turkey
    poult="turkey", turkeypoult="turkey", turkeyhen="turkey", gobbler="turkey", gobblers="turkey",
    -- Rabbit
    rabbuck="rabbit", rabdoe="rabbit", rabkitten="rabbit",
    -- Raccoon
    raccoonboar="raccoon", raccoonsow="raccoon", raccoonkit="raccoon",
    -- Rat/Mouse stages (if any)
    ratfemale="rat", ratbaby="rat",
    mousefemale="mouse", mousepups="mouse",
}

-- Breed hints (best-effort from AnimalName). Keys are AnimalDefinitions breed keys.
local _BREED_HINTS = {
    chicken = {
        leghorn = {"leghorn"},
        rhodeisland = {"rhode", "rhode island"},
    },
    cow = {
        simmental = {"simmental"},
        holstein = {"holstein"},
        angus = {"angus"},
    },
    pig = {
        landrace = {"landrace"},
        largeblack = {"large black", "largeblack"},
    },
    deer = {
        whitetailed = {"whitetail", "white-tailed", "white tailed"},
    },
    rabbit = {
        cottontail = {"cottontail"},
        swamp = {"swamp"},
        appalachian = {"appalachian"},
    },
}

-- Fallback icons (B42 vanilla item texture names) in case AnimalDefinitions isn't loaded.
local _ICON_FALLBACK = {
    cow     = "Item_CowBlack_Calf",
    chicken = "Item_Chicken_HenBrown",
    pig     = "Item_PigWhite_Piglet",
    sheep   = "Item_SheepSuffolk_Lamb",
    turkey  = "Item_Turkey",
    deer    = "Item_DeerMale_Dead",
    rabbit  = "Item_Rabbit",
    raccoon = "Item_Raccoon",
    rat     = "Item_Rat",
    mouse   = "Item_Mouse",
}

-- Sex-class fallbacks (when we can infer male/female/baby)
local _ICON_FALLBACK_SEX = {
    chicken = { male="Item_Chicken_RoosterBrown", female="Item_Chicken_HenBrown", baby="Item_Chicken_Chick" },
    pig     = { male="Item_PigWhite_Piglet",      female="Item_PigWhite_Piglet",  baby="Item_PigWhite_Piglet" },
    cow     = { male="Item_CowBlack_Calf",        female="Item_CowBlack_Calf",    baby="Item_CowBlack_Calf" },
    sheep   = { male="Item_SheepSuffolk_Lamb",    female="Item_SheepSuffolk_Lamb",baby="Item_SheepSuffolk_Lamb" },
    deer    = { male="Item_DeerMale_Dead",        female="Item_DeerFemale_Dead",  baby="Item_DeerFawn_Dead" },
    turkey  = { male="Item_Turkey",               female="Item_TurkeyHen",        baby="Item_TurkeyPoult" },
    rabbit  = { male="Item_Rabbit",               female="Item_Rabbit",           baby="Item_Rabbit" },
    raccoon = { male="Item_Raccoon",              female="Item_Raccoon",          baby="Item_Raccoon" },
    rat     = { male="Item_Rat",                  female="Item_Rat",              baby="Item_Rat" },
    mouse   = { male="Item_Mouse",                female="Item_Mouse",            baby="Item_Mouse" },
}

local _ICON_CACHE = {} -- key => Texture

local function _normalizeTypeKey(k)
    if not k then return "" end
    k = tostring(k):lower()
    return _TYPE_NORMALIZE[k] or k
end

local function _normName(s)
    s = tostring(s or ""):lower()
    s = s:gsub("%s+", " ")
    return s
end

local function _speciesKeyForEntry(e)
    local t = _normalizeTypeKey(e and e.AnimalType)
    if _BASE_SPECIES[t] then return t end

    -- If AnimalType is ambiguous stage (boar/hen/etc), use AnimalName as hint.
    local nm = _normName(e and (e.AnimalName or e.Nickname))
    if nm ~= "" then
        if nm:find("raccoon", 1, true) then return "raccoon" end
        if nm:find("turkey",  1, true) then return "turkey" end
        if nm:find("chicken", 1, true) then return "chicken" end
        if nm:find("deer",    1, true) then return "deer" end
        if nm:find("rabbit",  1, true) then return "rabbit" end
        if nm:find("sheep",   1, true) then return "sheep" end
        if nm:find("cow",     1, true) then return "cow" end
        if nm:find("pig",     1, true) then return "pig" end
    end

    return t
end

local _SEXCLASS_BY_TYPE = {
    -- Chicken
    rooster="male", cockerel="male", hen="female", chick="baby",
    -- Pig
    boar="male", sow="female", piglet="baby",
    -- Cow
    bull="male", calf="baby", cowcalf="baby",
    -- Sheep
    ram="male", ewe="female", lamb="baby",
    -- Deer
    buck="male", doe="female", fawn="baby",
    -- Turkey
    gobbler="male", gobblers="male", turkeyhen="female", poult="baby", turkeypoult="baby",
    -- Rabbit
    rabbuck="male", rabdoe="female", rabkitten="baby",
    -- Raccoon
    raccoonboar="male", raccoonsow="female", raccoonkit="baby",
    -- Rat/Mouse
    ratfemale="female", ratbaby="baby",
    mousefemale="female", mousepups="baby",
}

local function _sexClassForEntry(e, species)
    local t = tostring(e and e.AnimalType or ""):lower()
    if _SEXCLASS_BY_TYPE[t] then return _SEXCLASS_BY_TYPE[t] end

    local nm = _normName(e and (e.AnimalName or ""))
    if nm ~= "" then
        -- baby first (avoid matching "hen" inside "turkeyhen" issues)
        if nm:find("piglet", 1, true) or nm:find("chick", 1, true) or nm:find("fawn", 1, true) or nm:find("calf", 1, true)
           or nm:find("lamb", 1, true) or nm:find("poult", 1, true) or nm:find("kitten", 1, true) then
            return "baby"
        end
        if nm:find("boar", 1, true) or nm:find("rooster", 1, true) or nm:find("cockerel", 1, true) or nm:find("buck", 1, true)
           or nm:find("ram", 1, true) or nm:find("bull", 1, true) or nm:find("gobbler", 1, true) then
            return "male"
        end
        if nm:find("sow", 1, true) or nm:find("hen", 1, true) or nm:find("doe", 1, true) or nm:find("ewe", 1, true)
           or nm:find("turkeyhen", 1, true) then
            return "female"
        end
    end

    -- unknown => let icon picker choose any
    return nil
end

local function _breedKeyForEntry(e, species)
    local nm = _normName(e and (e.AnimalName or ""))
    if nm == "" then return nil end

    local hintsBySpecies = _BREED_HINTS[species]
    if hintsBySpecies then
        for breedKey, hints in pairs(hintsBySpecies) do
            for _, h in ipairs(hints) do
                if h and h ~= "" and nm:find(h, 1, true) then
                    return breedKey
                end
            end
        end
    end

    -- Generic fallback: if AnimalDefinitions is available, try to match breed keys directly
    if AnimalDefinitions and AnimalDefinitions.breeds and AnimalDefinitions.breeds[species] and AnimalDefinitions.breeds[species].breeds then
        for bKey, _ in pairs(AnimalDefinitions.breeds[species].breeds) do
            local k = tostring(bKey):lower()
            if k ~= "" and nm:find(k, 1, true) then
                return bKey
            end
        end
    end

    return nil
end

local function _pickInvIconForEntry(e)
    local species = _speciesKeyForEntry(e)
    if species == "" then return nil end

    local sexClass = _sexClassForEntry(e, species)
    local breedKey = _breedKeyForEntry(e, species)

    if AnimalDefinitions and AnimalDefinitions.breeds and AnimalDefinitions.breeds[species] then
        local t = AnimalDefinitions.breeds[species]

        local function pickFromBreed(b)
            if not b then return nil end
            if sexClass == "male"   then return b.invIconMale   or b.invIcon end
            if sexClass == "female" then return b.invIconFemale or b.invIcon end
            if sexClass == "baby"   then return b.invIconBaby   or b.invIcon end
            return b.invIconMale or b.invIconFemale or b.invIconBaby or b.invIcon
        end

        -- Prefer detected breed
        if breedKey and t.breeds and t.breeds[breedKey] then
            local icon = pickFromBreed(t.breeds[breedKey])
            if icon then return icon end
        end

        -- Fallback: any breed
        if t.breeds then
            for _, b in pairs(t.breeds) do
                local icon = pickFromBreed(b)
                if icon then return icon end
            end
        end

        -- Some packs put invIcon at type-level
        local icon = pickFromBreed(t)
        if icon then return icon end
    end

    -- No AnimalDefinitions: fallback by sex class if possible, else base fallback.
    if sexClass and _ICON_FALLBACK_SEX[species] and _ICON_FALLBACK_SEX[species][sexClass] then
        return _ICON_FALLBACK_SEX[species][sexClass]
    end
    return _ICON_FALLBACK[species]
end

local function _tryGetTexture(icon)
    if not icon or icon == "" or not getTexture then return nil end
    local tex = getTexture(icon)
    if tex then return tex end
    if icon:sub(1,5) ~= "Item_" then
        tex = getTexture("Item_" .. icon)
        if tex then return tex end
    end
    return nil
end

local function _iconTextureForEntry(entry)
    if not entry then return nil end

    local species = _speciesKeyForEntry(entry)
    local sexClass = _sexClassForEntry(entry, species) or ""
    local breedKey = _breedKeyForEntry(entry, species) or ""
    local cacheKey = species .. "|" .. sexClass .. "|" .. breedKey

    local cached = _ICON_CACHE[cacheKey]
    if cached then return cached end

    local icon = _pickInvIconForEntry(entry)
    if not icon then return nil end
    icon = tostring(icon)

    local iconNoExt = icon
    if iconNoExt:sub(-4):lower() == ".png" then
        iconNoExt = iconNoExt:sub(1, -5)
    end

    local tex = _tryGetTexture(iconNoExt) or _tryGetTexture(icon)
    if tex then
        _ICON_CACHE[cacheKey] = tex
        return tex
    end
    return nil
end

local function _formatLastSeen(v)
    if v == nil then return "-" end
    local n = tonumber(v)
    if not n then return tostring(v) end

    -- Server uses AACS.Now() which is milliseconds.
    if n >= 1000000000000 then n = math.floor(n / 1000) end

    if n >= 1000000000 then
        if os and os.date then
            local ok, s = pcall(os.date, "%d/%m/%Y %H:%M", n)
            if ok and s then return s end
        end
        return tostring(n)
    end

    local hours = n
    if hours < 0 then return tostring(v) end
    local days = math.floor(hours / 24)
    local h = math.floor(hours % 24)
    local m = math.floor((hours - math.floor(hours)) * 60)
    return string.format("Dia %d %02d:%02d", days + 1, h, m)
end


function AACSAdminManagerMain:initialise()
    ISCollapsableWindow.initialise(self)
end

function AACSAdminManagerMain:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.title = getText("IGUI_AACS_AdminTitle")
    self:setTitle(self.title)

    self.entries = {}
    self.selectedEntry = nil

    -- Theme + adaptive fonts
    self._ui = self._ui or {}
    self._ui.pad = 14
    self._ui.topY = 35
    self._ui.bottomH = 48

    self:_applyTheme()

    local c = AACSUITheme.Colors

    -- Panels (containers) to prevent overlap and keep layout responsive
    self.leftPanel = ISPanel:new(0, 0, 100, 100)
    self.leftPanel:initialise()
    self.leftPanel.backgroundColor = { r=AACSUITheme.Colors.panelBg.r, g=AACSUITheme.Colors.panelBg.g, b=AACSUITheme.Colors.panelBg.b, a=1.00 }
    self.leftPanel.borderColor = { r=AACSUITheme.Colors.panelBorder.r, g=AACSUITheme.Colors.panelBorder.g, b=AACSUITheme.Colors.panelBorder.b, a=1.00 }
    self:addChild(self.leftPanel)

    
    function self.leftPanel:prerender()
        local c = AACSUITheme.Colors
        self:drawRect(0, 0, self.width, self.height, 1.00, c.panelBg.r, c.panelBg.g, c.panelBg.b)
        self:drawRectBorder(0, 0, self.width, self.height, 1.00, c.panelBorder.r, c.panelBorder.g, c.panelBorder.b)
    end
self.rightPanel = ISPanel:new(0, 0, 100, 100)
    self.rightPanel:initialise()
    self.rightPanel.backgroundColor = { r=AACSUITheme.Colors.panelBg.r, g=AACSUITheme.Colors.panelBg.g, b=AACSUITheme.Colors.panelBg.b, a=1.00 }
    self.rightPanel.borderColor = { r=AACSUITheme.Colors.panelBorder.r, g=AACSUITheme.Colors.panelBorder.g, b=AACSUITheme.Colors.panelBorder.b, a=1.00 }
    self:addChild(self.rightPanel)


    
    function self.rightPanel:prerender()
        local c = AACSUITheme.Colors
        self:drawRect(0, 0, self.width, self.height, 1.00, c.panelBg.r, c.panelBg.g, c.panelBg.b)
        self:drawRectBorder(0, 0, self.width, self.height, 1.00, c.panelBorder.r, c.panelBorder.g, c.panelBorder.b)
    end
-- ===== Left: Search + Animal list =====
    self.lblSearch = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Search") .. ":", c.normalText.r, c.normalText.g, c.normalText.b, 1, self._ui.labelFont, true)
    self.leftPanel:addChild(self.lblSearch)

    self.searchBox = ISTextEntryBox:new("", 0, 0, 200, 24)
    self.searchBox:initialise()
    self.searchBox:instantiate()
    self.searchBox.onTextChange = function() self:refreshList() end
    AACSUITheme.styleTextEntry(self.searchBox)
    self.leftPanel:addChild(self.searchBox)

    self.list = ISScrollingListBox:new(0, 0, 200, 200)
    self.list:initialise()
    self.list:instantiate()
    self.list.drawBorder = false
    self.list.drawBackground = false
    self.list._font = self._ui.listFont
    self.list.itemheight = self._ui.listRowH
    self.list.doDrawItem = AACSAdminManagerMain._doDrawRow
    self.list.onmousedown = function(_, x, y)
        -- Default list selection is already handled by ISScrollingListBox:onMouseDown.
        -- Here we only refresh the right-side details.
        self:onSelect()
    end
    AACSUITheme.styleListBox(self.list)
    self.leftPanel:addChild(self.list)

    -- ===== Right: Details + Permissions =====
    self.lblCode = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Code") .. ": -", c.normalText.r, c.normalText.g, c.normalText.b, 1, self._ui.labelFont, true)
    self.rightPanel:addChild(self.lblCode)

    self.lblOwner = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Owner") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblOwner)

    self.lblType = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Type") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblType)

    self.lblName = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Name") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblName)

    self.lblLastSeen = ISLabel:new(0, 0, 18, getText("IGUI_AACS_LastSeen") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblLastSeen)

    self.lblExpiresAt = ISLabel:new(0, 0, 18, getText("IGUI_AACS_ExpiresAt") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblExpiresAt)

    self.lblLoc = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Location") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblLoc)

    self.btnTeleport = ISButton:new(0, 0, 110, 24, getText("IGUI_AACS_Teleport"), self, self.onClick)
    self.btnTeleport.internal = "TELEPORT"
    self.btnTeleport:initialise()
    AACSUITheme.styleButton(self.btnTeleport, "info")
    self.btnTeleport:setEnable(false)
    self.rightPanel:addChild(self.btnTeleport)


    self.lblPickup = ISLabel:new(0, 0, 18, getText("IGUI_AACS_PickupPerm") .. ":", c.normalText.r, c.normalText.g, c.normalText.b, 1, self._ui.labelFont, true)
    self.rightPanel:addChild(self.lblPickup)

    self.comboPickup = ISComboBox:new(0, 0, 200, 24)
    self.comboPickup:initialise()
    AACSUITheme.styleComboBox(self.comboPickup)
    self.rightPanel:addChild(self.comboPickup)

    self.lblLeash = ISLabel:new(0, 0, 18, getText("IGUI_AACS_LeashPerm") .. ":", c.normalText.r, c.normalText.g, c.normalText.b, 1, self._ui.labelFont, true)
    self.rightPanel:addChild(self.lblLeash)

    self.comboLeash = ISComboBox:new(0, 0, 200, 24)
    self.comboLeash:initialise()
    AACSUITheme.styleComboBox(self.comboLeash)
    self.rightPanel:addChild(self.comboLeash)

    self:fillModeCombos()

    -- Bottom actions
    self.btnSave = ISButton:new(0, 0, 140, 26, getText("IGUI_AACS_Save"), self, self.onClick)
    self.btnSave.internal = "SAVE"
    self.btnSave:initialise()
    AACSUITheme.styleButton(self.btnSave, "success")
    self:addChild(self.btnSave)

    self.btnUnadopt = ISButton:new(0, 0, 220, 26, getText("IGUI_AACS_Unadopt"), self, self.onClick)
    self.btnUnadopt.internal = "UNADOPT"
    self.btnUnadopt:initialise()
    AACSUITheme.styleButton(self.btnUnadopt, "warning")
    self:addChild(self.btnUnadopt)

    self.btnClose = ISButton:new(0, 0, 140, 26, getText("IGUI_AACS_Close"), self, self.onClick)
    self.btnClose.internal = "CLOSE"
    self.btnClose:initialise()
    AACSUITheme.styleButton(self.btnClose, nil)
    self:addChild(self.btnClose)

    self:doLayout()
    self:updateFromCache()
end


function AACSAdminManagerMain:_applyTheme()
    local titleFont, labelFont, listFont = AACSUITheme.pickFonts(self.width)
    self._ui.titleFont = titleFont
    self._ui.labelFont = labelFont
    self._ui.smallFont = UIFont.Small
    self._ui.listFont = listFont

    local tm = getTextManager()
    self._ui.listRowH = tm:getFontHeight(listFont) + 14

    local c = AACSUITheme.Colors
    -- (panels are created once in createChildren; do not recreate here)

    self.backgroundColor = { r=c.panelBg.r, g=c.panelBg.g, b=c.panelBg.b, a=1.00 }
    self.borderColor = { r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=1.00 }
end

function AACSAdminManagerMain._doDrawRow(self, y, row, alt)
    local h = tonumber(row and row.height) or tonumber(self.itemheight) or 24
    local w = self:getWidth()
    local c = AACSUITheme.Colors

    local isHover = false
    if self and self.isMouseOver and self.rowAt and getMouseX and getMouseY then
        if self:isMouseOver() then
            local mx = getMouseX() - self:getAbsoluteX()
            local my = getMouseY() - self:getAbsoluteY()
            local r = self:rowAt(mx, my)
            if r == row.index then isHover = true end
        end
    end

    local bg = alt and c.listAltBg or c.listBg
    if isHover then bg = c.listHover end
    if self.selected == row.index then bg = c.listSelected end

    self:drawRect(0, y, w, h, bg.a, bg.r, bg.g, bg.b)
    self:drawRectBorder(0, y, w, h, 0.22, c.panelBorder.r, c.panelBorder.g, c.panelBorder.b)

    local font = self._font or UIFont.Medium
    local txt = tostring(row.text or "")

    local textX = 10
    local iconTex = nil
    local e = row and row.item or nil
    if e then
        iconTex = _iconTextureForEntry(e)
    end
    if iconTex then
        local iconSize = math.min(18, h - 6)
        local iy = y + math.floor((h - iconSize) / 2)
        if self.drawTextureScaledAspect then
            self:drawTextureScaledAspect(iconTex, 8, iy, iconSize, iconSize, 1, 1, 1, 1)
        else
            self:drawTextureScaled(iconTex, 8, iy, iconSize, iconSize, 1, 1, 1, 1)
        end
        textX = 8 + iconSize + 8
    end

    txt = AACSUITheme.truncateText(txt, w - textX - 8, font)

    local tm = getTextManager()
    local fh = tm:getFontHeight(font)
    local ty = y + math.floor((h - fh) / 2)

    self:drawText(txt, textX, ty, c.normalText.r, c.normalText.g, c.normalText.b, c.normalText.a, font)
    return y + h
end


function AACSAdminManagerMain:prerender()
    ISCollapsableWindow.prerender(self)

    -- Avoid heavy relayout every frame; only when size actually changes (integer) or flagged dirty.
    local w = math.floor(self.width)
    local h = math.floor(self.height)
    if self._layoutDirty or self._lastW ~= w or self._lastH ~= h then
        self._layoutDirty = false
        self._lastW = w
        self._lastH = h
        self:_applyTheme()
        self:doLayout()
    end
end

function AACSAdminManagerMain:doLayout()
    if not self._ui or not self.leftPanel or not self.rightPanel or not self.list or not self.lblCode or not self.lblType or not self.lblName or not self.lblOwner then return end
    if not self._ui then return end
    local pad = self._ui.pad or 14
    local topY = self._ui.topY or 35
    local bottomH = self._ui.bottomH or 48

    local panelY = topY
    local panelH = self.height - panelY - bottomH
    if panelH < 220 then panelH = 220 end

    local leftX = pad
    local leftW = AACSUITheme.clamp(math.floor(self.width * 0.36), 320, 460)
    local rightX = leftX + leftW + pad
    local rightW = self.width - rightX - pad
    if rightW < 340 then
        rightW = 340
        leftW = self.width - rightW - pad * 3
        leftW = AACSUITheme.clamp(leftW, 260, 560)
        rightX = leftX + leftW + pad
    end

    self._layout = { leftX=leftX, leftW=leftW, rightX=rightX, rightW=rightW, panelY=panelY, panelH=panelH }

    -- Position container panels
    if self.leftPanel then
        self.leftPanel:setX(leftX)
        self.leftPanel:setY(panelY)
        self.leftPanel:setWidth(leftW)
        self.leftPanel:setHeight(panelH)
    end
    if self.rightPanel then
        self.rightPanel:setX(rightX)
        self.rightPanel:setY(panelY)
        self.rightPanel:setWidth(rightW)
        self.rightPanel:setHeight(panelH)
    end

    local tm = getTextManager()
    local entryH = 24

    -- ===== Left panel (relative coords) =====
    local lx = pad
    local ly = pad
    local lw = leftW - pad * 2

    local searchText = getText("IGUI_AACS_Search") .. ":"
    local labelW = tm:MeasureStringX(self._ui.labelFont, searchText) + 10

    self.lblSearch:setX(lx)
    self.lblSearch:setY(ly + 2)
    self.lblSearch.font = self._ui.labelFont

    self.searchBox:setX(lx + labelW)
    self.searchBox:setY(ly)
    self.searchBox:setWidth(math.max(80, lw - labelW))
    self.searchBox:setHeight(entryH)

    local listY = ly + entryH + pad
    local listH = (panelH - pad) - listY
    if listH < 90 then listH = 90 end

    self.list:setX(lx)
    self.list:setY(listY)
    self.list:setWidth(lw)
    self.list:setHeight(listH)
    self.list._font = self._ui.listFont
    self.list.itemheight = self._ui.listRowH
    AACSUITheme.styleListBox(self.list)

    -- ===== Right panel (relative coords) =====
    local rx = pad + 10
    local ry = pad
    local rw = rightW - (rx + pad)

    local y = ry
    local smallFH = tm:getFontHeight(self._ui.smallFont)
    local labelFH = tm:getFontHeight(self._ui.labelFont)
    local gap = 4

    self.lblCode:setX(rx); self.lblCode:setY(y); self.lblCode.font = self._ui.labelFont
    y = y + labelFH + 6

    self.lblType:setX(rx); self.lblType:setY(y); self.lblType.font = self._ui.smallFont
    y = y + smallFH + gap
    self.lblName:setX(rx); self.lblName:setY(y); self.lblName.font = self._ui.smallFont
    y = y + smallFH + gap
    self.lblOwner:setX(rx); self.lblOwner:setY(y); self.lblOwner.font = self._ui.smallFont
    y = y + smallFH + gap
    self.lblLastSeen:setX(rx); self.lblLastSeen:setY(y); self.lblLastSeen.font = self._ui.smallFont
    y = y + smallFH + gap
    self.lblExpiresAt:setX(rx); self.lblExpiresAt:setY(y); self.lblExpiresAt.font = self._ui.smallFont
    y = y + smallFH + gap
    self.lblLoc:setX(rx); self.lblLoc:setY(y); self.lblLoc.font = self._ui.smallFont
    local tpW = math.max(90, math.min(140, math.floor(rw * 0.30)))
    self.btnTeleport:setX(rx + rw - tpW)
    self.btnTeleport:setY(y - 2)
    self.btnTeleport:setWidth(tpW)
    self.btnTeleport:setHeight(entryH)

    y = y + math.max(smallFH, entryH) + 14

    local labelColW = math.min(220, math.floor(rw * 0.46))
    local comboW = math.max(140, rw - labelColW)

    self.lblPickup:setX(rx); self.lblPickup:setY(y); self.lblPickup.font = self._ui.labelFont
    self.comboPickup:setX(rx + labelColW)
    self.comboPickup:setY(y - 2)
    self.comboPickup:setWidth(comboW)
    self.comboPickup:setHeight(entryH)
    y = y + entryH + 8

    self.lblLeash:setX(rx); self.lblLeash:setY(y); self.lblLeash.font = self._ui.labelFont
    self.comboLeash:setX(rx + labelColW)
    self.comboLeash:setY(y - 2)
    self.comboLeash:setWidth(comboW)
    self.comboLeash:setHeight(entryH)

    -- ===== Bottom buttons (absolute coords, aligned to right panel) =====
    local absRX = rightX + pad
    local absRW = rightW - pad * 2
    local btnY = self.height - (pad + self.btnSave.height)

    local minW = 110
    local saveW = math.max(minW, math.min(150, math.floor(absRW * 0.22)))
    local closeW = math.max(minW, math.min(150, math.floor(absRW * 0.22)))
    local unadoptW = absRW - saveW - closeW - pad * 2
    if unadoptW < 170 then
        unadoptW = 170
        saveW = math.max(95, math.floor((absRW - unadoptW - closeW - pad * 2)))
        if saveW < 95 then saveW = 95 end
    end

    self.btnSave:setX(absRX)
    self.btnSave:setY(btnY)
    self.btnSave:setWidth(saveW)

    self.btnUnadopt:setX(absRX + saveW + pad)
    self.btnUnadopt:setY(btnY)
    self.btnUnadopt:setWidth(unadoptW)

    self.btnClose:setX(absRX + absRW - closeW)
    self.btnClose:setY(btnY)
    self.btnClose:setWidth(closeW)
end



function AACSAdminManagerMain:onResize()
    if ISCollapsableWindow.onResize then
        ISCollapsableWindow.onResize(self)
    end
    self._layoutDirty = true
    -- prerender will apply theme + layout once.
end

local function _selectComboByData(combo, data)
    if not combo or not combo.options then return end
    for i = 1, #combo.options do
        if combo:getOptionData(i) == data then
            combo.selected = i
            return
        end
    end
    combo.selected = 1
end

function AACSAdminManagerMain:fillModeCombos()
    self.comboPickup:clear()
    self.comboLeash:clear()

    local modes = (AACS.GetAllowedModes and AACS.GetAllowedModes()) or { 1, 2, 3, 4 }
    for _, mode in ipairs(modes) do
        local label = (AACS.GetModeLabel and AACS.GetModeLabel(mode)) or tostring(mode)
        self.comboPickup:addOptionWithData(label, mode)
        self.comboLeash:addOptionWithData(label, mode)
    end
end

function AACSAdminManagerMain:spBuildAllEntries()
    local reg = AACS.SP_GetRegistry()
    local out = {}
    for uid, e in pairs(reg) do
        if e then table.insert(out, e) end
    end
    table.sort(out, function(a,b) return tostring(a.UID) < tostring(b.UID) end)
    return out
end

function AACSAdminManagerMain:updateFromCache()
    self.entries = AACS.ClientCache.allEntries or {}
    AACS.Log("[AdminManager] updateFromCache called, entries count: " .. #self.entries)
    self:refreshList()
end

function AACSAdminManagerMain:refreshList()
    self.list:clear()
    local q = string.lower(self.searchBox:getText() or "")
    for _, e in ipairs(self.entries) do
        local name = tostring(e.AnimalName or "")
        if name == "" then name = "Sem nome" end
        local atype = tostring(e.AnimalType or "")
        if atype == "" then atype = "-" end
        local owner = tostring(e.Owner or "")
        if owner == "" then owner = "-" end
        local displayText = string.format("%s (%s)  |  %s", name, atype, owner)
        -- Keep UID searchable without showing it in the list row
        local searchBlob = string.format("%s %s %s %s", tostring(e.UID or ""), owner, atype, name)
        local text = searchBlob
        if q == "" or string.find(string.lower(text), q, 1, true) then
            local it = self.list:addItem(displayText, e)
            if it then it.tooltip = string.format("%s: %s", getText("IGUI_AACS_Code"), tostring(e.UID or "")) end
        end
    end
    self:onSelect()
end

function AACSAdminManagerMain:onSelect()
    local item = self.list and self.list.items and self.list.items[self.list.selected] or nil
    if not item then
        self.selectedEntry = nil
        self:setDetails(nil)
        return
    end
    self.selectedEntry = item.item

    local ok, err = pcall(function()
        self:setDetails(self.selectedEntry)
    end)
    if not ok then
        if self._lastUIErr ~= err then
            self._lastUIErr = err
            print("[AACS] UI onSelect error: " .. tostring(err))
        end
        self:setDetails(nil)
    end
end

function AACSAdminManagerMain:setDetails(e)
    if not e then
        self.lblCode:setName(getText("IGUI_AACS_Code")..": -")
        self.lblOwner:setName(getText("IGUI_AACS_Owner")..": -")
        self.lblType:setName(getText("IGUI_AACS_Type")..": -")
        self.lblName:setName(getText("IGUI_AACS_Name")..": -")
        self.lblLastSeen:setName(getText("IGUI_AACS_LastSeen")..": -")
        self.lblExpiresAt:setName(getText("IGUI_AACS_ExpiresAt")..": -")
        self.lblLoc:setName(getText("IGUI_AACS_Location")..": -")
        self.btnTeleport:setEnable(false)
        _selectComboByData(self.comboPickup, AACS.MODE_OWNER_ONLY)
        _selectComboByData(self.comboLeash, AACS.MODE_OWNER_ONLY)
        self.btnSave:setEnable(false)
        self.btnUnadopt:setEnable(false)
        return
    end

    self.lblCode:setName(getText("IGUI_AACS_Code")..": "..tostring(e.UID))
    self.lblOwner:setName(getText("IGUI_AACS_Owner")..": "..tostring(e.Owner or "-"))
    self.lblType:setName(getText("IGUI_AACS_Type")..": "..tostring(e.AnimalType or "-"))
    self.lblName:setName(getText("IGUI_AACS_Name")..": "..tostring(e.AnimalName or "-"))
    self.lblLastSeen:setName(getText("IGUI_AACS_LastSeen")..": ".._formatLastSeen(e.LastSeen))

    -- Expiry (based on owner's last login/activity)
    local expiryDays = 0
    if SandboxVars and SandboxVars.AACS then
        expiryDays = tonumber(SandboxVars.AACS.AdoptionExpiryDays) or 0
    end
    if expiryDays <= 0 then
        self.lblExpiresAt:setName(getText("IGUI_AACS_ExpiresAt")..": "..getText("IGUI_AACS_Never"))
    else
        local owner = e.Owner
        local lastLogin = (AACS.GetPlayerLastLogin and owner) and AACS.GetPlayerLastLogin(owner) or nil
        if lastLogin and lastLogin > 0 then
            local expiresAt = lastLogin + math.floor(expiryDays * 86400)
            self.lblExpiresAt:setName(getText("IGUI_AACS_ExpiresAt")..": ".._formatLastSeen(expiresAt))
        else
            self.lblExpiresAt:setName(getText("IGUI_AACS_ExpiresAt")..": -")
        end
    end

    self.lblLoc:setName(getText("IGUI_AACS_Location")..": "..AACS.FormatLocation(e))

    local canTp = (tonumber(e.LastX) ~= nil) and (tonumber(e.LastY) ~= nil) and (tonumber(e.LastZ) ~= nil)
    self.btnTeleport:setEnable(canTp)

    local pickupMode = AACS.SanitizeMode(tonumber(e.PickupMode) or AACS.MODE_OWNER_ONLY)
    local leashMode = AACS.SanitizeMode(tonumber(e.LeashMode) or AACS.MODE_OWNER_ONLY)
    _selectComboByData(self.comboPickup, pickupMode)
    _selectComboByData(self.comboLeash, leashMode)

    self.btnSave:setEnable(true)
    self.btnUnadopt:setEnable(true)
end

function AACSAdminManagerMain:onClick(button)
    if button.internal == "CLOSE" then
        self:setVisible(false)
        self:removeFromUIManager()
        return
    end

    if not self.selectedEntry then return end

    if button.internal == "TELEPORT" then
        local x = tonumber(self.selectedEntry.LastX)
        local y = tonumber(self.selectedEntry.LastY)
        local z = tonumber(self.selectedEntry.LastZ)
        if not x or not y or z == nil then return end
        z = tonumber(z) or 0

        if isClient() then
            sendClientCommand(getPlayer(), "AACS", "teleportToLocation", { x = x, y = y, z = z, uid = tostring(self.selectedEntry.UID or "") })
        else
            local p = getPlayer()
            if p then
                if p.teleportTo then
                    pcall(function() p:teleportTo(x + 0.5, y + 0.5, z) end)
                else
                    pcall(function() if p.setX then p:setX(x + 0.5) end end)
                    pcall(function() if p.setY then p:setY(y + 0.5) end end)
                    pcall(function() if p.setZ then p:setZ(z) end end)
                end
            end
        end
        return
    end


    if button.internal == "UNADOPT" then
        if isClient() then
            sendClientCommand(getPlayer(), "AACS", "unadoptAnimal", { uid = self.selectedEntry.UID })
        else
            local reg = AACS.SP_GetRegistry()
            reg[self.selectedEntry.UID] = nil
        end
        return
    end

    if button.internal == "SAVE" then
        local pickupMode = self.comboPickup:getOptionData(self.comboPickup.selected) or 1
        local leashMode  = self.comboLeash:getOptionData(self.comboLeash.selected) or 1

        if isClient() then
            -- Admin can edit permissions; allowList is unchanged here.
            sendClientCommand(getPlayer(), "AACS", "setPermissions", {
                uid = self.selectedEntry.UID,
                pickupMode = pickupMode,
                leashMode = leashMode,
                allowList = self.selectedEntry.AllowList or {},
            })
        else
            local reg = AACS.SP_GetRegistry()
            local e = reg[self.selectedEntry.UID]
            if e then
                e.PickupMode = pickupMode
                e.LeashMode  = leashMode
                reg[self.selectedEntry.UID] = e
            end
        end
        return
    end
end

function AACSAdminManagerMain:new(x, y, w, h)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.background = true
    o.drawFrame = true
    o.resizable = true
    return o
end
