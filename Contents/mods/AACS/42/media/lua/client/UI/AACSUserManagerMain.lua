-- UI/AACSUserManagerMain.lua
-- Minimal modern-ish text UI (no images) for managing adopted animals.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISPanel"
require "ISUI/ISTickBox"
require "UI/AACSUITheme"

AACSUserManagerMain = ISCollapsableWindow:derive("AACSUserManagerMain")

AACSUserManagerMain.TabModes = {
    ALL = "all",
    MINE = "mine",
    OTHERS = "others",
}

function AACSUserManagerMain:onTabClick(btn)
    if not btn or not btn.internal then return end
    self:setTab(btn.internal)
end

function AACSUserManagerMain:setTab(mode)
    if self.tabMode == mode then return end
    self.tabMode = mode
    self:_updateTabStyles()
    self:refreshList()
end

function AACSUserManagerMain:_updateTabStyles()
    if not self.tabButtons then return end
    for _, btn in ipairs(self.tabButtons) do
        AACSUITheme.styleTabButton(btn, btn.internal == self.tabMode)
    end
end

function AACSUserManagerMain:_getUsername()
    local p = self.player or (getPlayer and getPlayer()) or nil
    if p and p.getUsername then return tostring(p:getUsername() or "") end
    return ""
end

-- Safe text formatting for PZ translations that use %1, %2 placeholders
-- (string.format crashes on these because they're not valid Lua format specifiers)
local function _safeTextFormat(text, ...)
    local args = {...}
    local result = text or ""
    for i, v in ipairs(args) do
        result = result:gsub("%%" .. tostring(i), tostring(v))
    end
    return result
end

local function _copyAllowList(list)
    local out = {}
    if not list then return out end
    for _, u in ipairs(list) do table.insert(out, u) end
    return out
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

local function _entryAllowListContains(entry, username)
    if not entry or not entry.AllowList or not username then return false end
    for _, u in ipairs(entry.AllowList) do
        if u == username then return true end
    end
    return false
end

local function _entryModeAllows(owner, username, mode)
    if not owner or not username then return false end
    if mode == AACS.MODE_SAFEHOUSE then
        return AACS.IsSafehouseMember(owner, username)
    elseif mode == AACS.MODE_FACTION then
        return AACS.IsFactionMember(owner, username)
    elseif mode == AACS.MODE_SAFE_OR_FACT then
        return AACS.IsSafehouseMember(owner, username) or AACS.IsFactionMember(owner, username)
    end
    return false
end

local _TYPE_TKEY = {
    -- Base species
    horse   = "IGUI_AACS_Horse",
    chicken = "IGUI_AACS_Chicken",
    cow     = "IGUI_AACS_Cow",
    pig     = "IGUI_AACS_Pig",
    sheep   = "IGUI_AACS_Sheep",
    deer    = "IGUI_AACS_Deer",
    turkey  = "IGUI_AACS_Turkey",
    rat     = "IGUI_AACS_Rat",
    mouse   = "IGUI_AACS_Mouse",
    rabbit  = "IGUI_AACS_Rabbit",
    raccoon = "IGUI_AACS_Raccoon",

    -- Variants/stages (map to base species label)
    -- Cow
    bull = "IGUI_AACS_Cow",
    cowcalf = "IGUI_AACS_Cow",

    -- Chicken
    hen = "IGUI_AACS_Chicken",
    cockerel = "IGUI_AACS_Chicken",
    chick = "IGUI_AACS_Chicken",

    -- Deer
    buck = "IGUI_AACS_Deer",
    doe = "IGUI_AACS_Deer",
    fawn = "IGUI_AACS_Deer",

    -- Pig
    boar = "IGUI_AACS_Pig",
    sow = "IGUI_AACS_Pig",
    piglet = "IGUI_AACS_Pig",

    -- Sheep
    ram = "IGUI_AACS_Sheep",
    ewe = "IGUI_AACS_Sheep",
    lamb = "IGUI_AACS_Sheep",

    -- Turkey
    turkeyhen = "IGUI_AACS_Turkey",
    gobblers = "IGUI_AACS_Turkey",
    turkeypoult = "IGUI_AACS_Turkey",

    -- Rat
    ratfemale = "IGUI_AACS_Rat",
    ratbaby = "IGUI_AACS_Rat",

    -- Mouse
    mousefemale = "IGUI_AACS_Mouse",
    mousepups = "IGUI_AACS_Mouse",

    -- Rabbit
    rabbuck = "IGUI_AACS_Rabbit",
    rabdoe = "IGUI_AACS_Rabbit",
    rabkitten = "IGUI_AACS_Rabbit",

    -- Raccoon
    raccoonboar = "IGUI_AACS_Raccoon",
    raccoonsow = "IGUI_AACS_Raccoon",
    raccoonkit = "IGUI_AACS_Raccoon",
}


local _KNOWN_BASE_TYPES = {
    "cow", "chicken", "deer", "pig", "sheep", "turkey", "rat", "mouse", "rabbit", "raccoon", "horse",
}

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

local function _typeLabel(typeKey)
    if not typeKey or typeKey == "" then return getText("IGUI_AACS_Unknown") end
    local k = tostring(typeKey):lower()
    local tkey = _TYPE_TKEY[k]
    if tkey then
        local ok, txt = pcall(getText, tkey)
        if ok and txt and txt ~= "" then return txt end
    end
    return tostring(typeKey)
end



local function _formatLastSeen(v)
    if v == nil then return "-" end
    local n = tonumber(v)
    if not n then return tostring(v) end

    -- Server uses AACS.Now() which is milliseconds.
    if n >= 1000000000000 then n = math.floor(n / 1000) end

    -- Heuristic:
    --  >= 1e9  => unix-like seconds timestamp (real date/time)
    --  <  1e9  => world-age hours (fallback)
    if n >= 1000000000 then
        if os and os.date then
            local ok, s = pcall(os.date, "%d/%m/%Y %H:%M", n)
            if ok and s then return s end
        end
        return tostring(n)
    end

    -- Assume "hours since world start" (can be float)
    local hours = n
    if hours < 0 then return tostring(v) end
    local days = math.floor(hours / 24)
    local h = math.floor(hours % 24)
    local m = math.floor((hours - math.floor(hours)) * 60)
    return string.format("Dia %d %02d:%02d", days + 1, h, m)
end


function AACSUserManagerMain:initialise()
    ISCollapsableWindow.initialise(self)
end

function AACSUserManagerMain:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.title = getText("IGUI_AACS_Title")
    self:setTitle(self.title)

    self.entries = {}
    self.selectedEntry = nil

    -- Theme + adaptive fonts
    self._ui = self._ui or {}
    self._ui.pad = 14
    self._ui.topY = 35
    self._ui.bottomH = 58

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

    -- Filter by Type
    self.lblFilterType = ISLabel:new(0, 0, 18, getText("IGUI_AACS_FilterType") .. ":", c.normalText.r, c.normalText.g, c.normalText.b, 1, self._ui.smallFont, true)
    self.leftPanel:addChild(self.lblFilterType)

    self.comboFilterType = ISComboBox:new(0, 0, 200, 24)
    self.comboFilterType:initialise()
    AACSUITheme.styleComboBox(self.comboFilterType)
    self.comboFilterType.onChange = function() self:refreshList() end
    self.leftPanel:addChild(self.comboFilterType)

    -- Filter by Status
    self.lblFilterStatus = ISLabel:new(0, 0, 18, getText("IGUI_AACS_FilterStatus") .. ":", c.normalText.r, c.normalText.g, c.normalText.b, 1, self._ui.smallFont, true)
    self.leftPanel:addChild(self.lblFilterStatus)

    self.comboFilterStatus = ISComboBox:new(0, 0, 200, 24)
    self.comboFilterStatus:initialise()
    AACSUITheme.styleComboBox(self.comboFilterStatus)
    self.comboFilterStatus.onChange = function() self:refreshList() end
    self.leftPanel:addChild(self.comboFilterStatus)

    -- Tabs: All / Mine / Others
    self.tabAll = ISButton:new(0, 0, 80, 24, getText("IGUI_AACS_Tab_All"), self, self.onTabClick)
    self.tabAll.internal = AACSUserManagerMain.TabModes.ALL
    self.tabAll:initialise()
    self.tabAll.tooltip = getText("IGUI_AACS_Tab_All_Tooltip")
    self.leftPanel:addChild(self.tabAll)

    self.tabMine = ISButton:new(0, 0, 80, 24, getText("IGUI_AACS_Tab_Mine"), self, self.onTabClick)
    self.tabMine.internal = AACSUserManagerMain.TabModes.MINE
    self.tabMine:initialise()
    self.tabMine.tooltip = getText("IGUI_AACS_Tab_Mine_Tooltip")
    self.leftPanel:addChild(self.tabMine)

    self.tabOthers = ISButton:new(0, 0, 80, 24, getText("IGUI_AACS_Tab_Others"), self, self.onTabClick)
    self.tabOthers.internal = AACSUserManagerMain.TabModes.OTHERS
    self.tabOthers:initialise()
    self.tabOthers.tooltip = getText("IGUI_AACS_Tab_Others_Tooltip")
    self.leftPanel:addChild(self.tabOthers)

    self.tabButtons = { self.tabAll, self.tabMine, self.tabOthers }
    self.tabMode = AACSUserManagerMain.TabModes.ALL
    self:_updateTabStyles()

    self.list = ISScrollingListBox:new(0, 0, 200, 200)
    self.list:initialise()
    self.list:instantiate()
    self.list.drawBorder = false
    self.list.drawBackground = false
    self.list._font = self._ui.listFont
    self.list.itemheight = self._ui.listRowH
    self.list.doDrawItem = AACSUserManagerMain._doDrawRow
    self.list.onmousedown = function(_, x, y)
        self:onSelect()
    end
    AACSUITheme.styleListBox(self.list)
    self.leftPanel:addChild(self.list)

    -- ===== Right: Details + Permissions =====
    self.lblCode = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Code") .. ": -", c.normalText.r, c.normalText.g, c.normalText.b, 1, self._ui.labelFont, true)
    self.rightPanel:addChild(self.lblCode)

    self.lblType = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Type") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblType)

    self.lblName = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Name") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblName)

    -- Nickname field
    self.lblNickname = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Nickname") .. ":", c.normalText.r, c.normalText.g, c.normalText.b, 1, self._ui.labelFont, true)
    self.rightPanel:addChild(self.lblNickname)

    self.txtNickname = ISTextEntryBox:new("", 0, 0, 200, 24)
    self.txtNickname:initialise()
    self.txtNickname:instantiate()
    AACSUITheme.styleTextEntry(self.txtNickname)
    self.rightPanel:addChild(self.txtNickname)

    self.btnRename = ISButton:new(0, 0, 100, 24, getText("IGUI_AACS_Rename"), self, self.onClick)
    self.btnRename.internal = "RENAME"
    self.btnRename:initialise()
    AACSUITheme.styleButton(self.btnRename, "info")
    self.rightPanel:addChild(self.btnRename)

    self.lblLastSeen = ISLabel:new(0, 0, 18, getText("IGUI_AACS_LastSeen") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblLastSeen)

    self.lblExpiresAt = ISLabel:new(0, 0, 18, getText("IGUI_AACS_ExpiresAt") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblExpiresAt)

    self.lblLoc = ISLabel:new(0, 0, 18, getText("IGUI_AACS_Location") .. ": -", c.dimText.r, c.dimText.g, c.dimText.b, 1, self._ui.smallFont, true)
    self.rightPanel:addChild(self.lblLoc)

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

    self.lblAllow = ISLabel:new(0, 0, 18, getText("IGUI_AACS_AllowList") .. ":", c.normalText.r, c.normalText.g, c.normalText.b, 1, self._ui.labelFont, true)
    self.rightPanel:addChild(self.lblAllow)

    self.allowListBox = ISScrollingListBox:new(0, 0, 200, 120)
    self.allowListBox:initialise()
    self.allowListBox:instantiate()
    self.allowListBox.drawBorder = false
    self.allowListBox.drawBackground = false
    self.allowListBox._font = self._ui.smallFont
    self.allowListBox.itemheight = self._ui.smallRowH
    self.allowListBox.doDrawItem = AACSUserManagerMain._doDrawRow
    AACSUITheme.styleListBox(self.allowListBox)
    self.rightPanel:addChild(self.allowListBox)

    self.allowEntry = ISTextEntryBox:new("", 0, 0, 200, 24)
    self.allowEntry:initialise()
    self.allowEntry:instantiate()
    AACSUITheme.styleTextEntry(self.allowEntry)
    self.rightPanel:addChild(self.allowEntry)

    self.btnAdd = ISButton:new(0, 0, 80, 24, getText("IGUI_AACS_Add"), self, self.onClick)
    self.btnAdd.internal = "ADD"
    self.btnAdd:initialise()
    AACSUITheme.styleButton(self.btnAdd, "info")
    self.rightPanel:addChild(self.btnAdd)

    self.btnRemove = ISButton:new(0, 0, 80, 24, getText("IGUI_AACS_Remove"), self, self.onClick)
    self.btnRemove.internal = "REMOVE"
    self.btnRemove:initialise()
    AACSUITheme.styleButton(self.btnRemove, "dangerTiny")
    self.rightPanel:addChild(self.btnRemove)

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

    self:fillFilterCombos()
    self:doLayout()
    self:updateFromCache()
end


function AACSUserManagerMain:_applyTheme()
    local titleFont, labelFont, listFont = AACSUITheme.pickFonts(self.width)
    self._ui.titleFont = titleFont
    self._ui.labelFont = labelFont
    self._ui.smallFont = UIFont.Small
    self._ui.listFont = listFont

    local tm = getTextManager()
    self._ui.listRowH = tm:getFontHeight(listFont) + 14
    self._ui.smallRowH = tm:getFontHeight(UIFont.Small) + 10

    local c = AACSUITheme.Colors

    self.backgroundColor = { r=c.panelBg.r, g=c.panelBg.g, b=c.panelBg.b, a=1.00 }
    self.borderColor = { r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=1.00 }
end

-- ISScrollingListBox: doDrawItem MUST return next y in B42
function AACSUserManagerMain._doDrawRow(self, y, row, alt)
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

    -- Icon (if available)
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


function AACSUserManagerMain:prerender()
    ISCollapsableWindow.prerender(self)

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

function AACSUserManagerMain:doLayout()
    if not self._ui or not self.leftPanel or not self.rightPanel or not self.list or not self.lblCode or not self.lblType or not self.lblName then return end
    local pad = self._ui.pad or 14
    local topY = self._ui.topY or 35
    local bottomH = self._ui.bottomH or 48

    local panelY = topY
    local panelH = self.height - panelY - bottomH
    if panelH < 200 then panelH = 200 end

    local leftX = pad
    local leftW = AACSUITheme.clamp(math.floor(self.width * 0.34), 280, 420)
    local rightX = leftX + leftW + pad
    local rightW = self.width - rightX - pad
    if rightW < 320 then
        rightW = 320
        leftW = self.width - rightW - pad * 3
        leftW = AACSUITheme.clamp(leftW, 240, 520)
        rightX = leftX + leftW + pad
    end

    self._layout = { leftX=leftX, leftW=leftW, rightX=rightX, rightW=rightW, panelY=panelY, panelH=panelH }

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

    local filterY = ly + entryH + 8

    -- Filter by Type
    self.lblFilterType:setX(lx)
    self.lblFilterType:setY(filterY + 2)
    self.lblFilterType.font = self._ui.smallFont

    local filterLabelW = tm:MeasureStringX(self._ui.smallFont, getText("IGUI_AACS_FilterType") .. ":") + 10

    self.comboFilterType:setX(lx + filterLabelW)
    self.comboFilterType:setY(filterY)
    self.comboFilterType:setWidth(math.max(80, lw - filterLabelW))
    self.comboFilterType:setHeight(entryH)
    filterY = filterY + entryH + 6

    -- Filter by Status
    self.lblFilterStatus:setX(lx)
    self.lblFilterStatus:setY(filterY + 2)
    self.lblFilterStatus.font = self._ui.smallFont

    self.comboFilterStatus:setX(lx + filterLabelW)
    self.comboFilterStatus:setY(filterY)
    self.comboFilterStatus:setWidth(math.max(80, lw - filterLabelW))
    self.comboFilterStatus:setHeight(entryH)
    filterY = filterY + entryH + 6

    if self.tabAll and self.tabMine and self.tabOthers then
        local tabGap = 6
        local tabW = math.floor((lw - tabGap * 2) / 3)
        local tabH = entryH
        self.tabAll:setX(lx)
        self.tabAll:setY(filterY)
        self.tabAll:setWidth(tabW)
        self.tabAll:setHeight(tabH)

        self.tabMine:setX(lx + tabW + tabGap)
        self.tabMine:setY(filterY)
        self.tabMine:setWidth(tabW)
        self.tabMine:setHeight(tabH)

        self.tabOthers:setX(lx + (tabW + tabGap) * 2)
        self.tabOthers:setY(filterY)
        self.tabOthers:setWidth(lw - (tabW + tabGap) * 2)
        self.tabOthers:setHeight(tabH)

        filterY = filterY + tabH + 8
    end

    local listY = filterY + 10
    local listH = (panelH - pad) - listY
    if listH < 80 then listH = 80 end

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
    local rh = panelH - pad * 2
    self._layout.detailX = rx

    local y = ry
    local smallFH = tm:getFontHeight(self._ui.smallFont)
    local labelFH = tm:getFontHeight(self._ui.labelFont)
    local gap = 4

    self.lblCode:setX(rx); self.lblCode:setY(y); self.lblCode.font = self._ui.labelFont
    y = y + labelFH + 6

    self.lblType:setX(rx); self.lblType:setY(y); self.lblType.font = self._ui.smallFont
    y = y + smallFH + gap
    self.lblName:setX(rx); self.lblName:setY(y); self.lblName.font = self._ui.smallFont
    y = y + smallFH + 10

    -- Nickname field
    self.lblNickname:setX(rx); self.lblNickname:setY(y); self.lblNickname.font = self._ui.labelFont
    y = y + labelFH + 4

    local nicknameW = rw - 110
    self.txtNickname:setX(rx)
    self.txtNickname:setY(y)
    self.txtNickname:setWidth(nicknameW)
    self.txtNickname:setHeight(entryH)

    self.btnRename:setX(rx + nicknameW + 8)
    self.btnRename:setY(y)
    self.btnRename:setWidth(100)
    self.btnRename:setHeight(entryH)
    y = y + entryH + 10

    self.lblLastSeen:setX(rx); self.lblLastSeen:setY(y); self.lblLastSeen.font = self._ui.smallFont
    y = y + smallFH + gap
    self.lblExpiresAt:setX(rx); self.lblExpiresAt:setY(y); self.lblExpiresAt.font = self._ui.smallFont
    y = y + smallFH + gap
    self.lblLoc:setX(rx); self.lblLoc:setY(y); self.lblLoc.font = self._ui.smallFont
    y = y + smallFH + 12

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
    y = y + entryH + 12

    self.lblAllow:setX(rx); self.lblAllow:setY(y); self.lblAllow.font = self._ui.labelFont
    y = y + labelFH + 6

    local allowH = math.floor(rh * 0.25)
    if allowH < 90 then allowH = 90 end
    if allowH > 160 then allowH = 160 end

    self.allowListBox:setX(rx)
    self.allowListBox:setY(y)
    self.allowListBox:setWidth(rw)
    self.allowListBox:setHeight(allowH)
    self.allowListBox._font = self._ui.smallFont
    self.allowListBox.itemheight = self._ui.smallRowH
    AACSUITheme.styleListBox(self.allowListBox)
    y = y + allowH + 10

    local btnW = 90
    local entryW = rw - (btnW * 2 + 10)
    if entryW < 140 then
        entryW = math.max(140, rw - 10)
    end

    self.allowEntry:setX(rx)
    self.allowEntry:setY(y)
    self.allowEntry:setWidth(entryW)
    self.allowEntry:setHeight(entryH)

    self.btnAdd:setX(rx + entryW + 5)
    self.btnAdd:setY(y)
    self.btnAdd:setWidth(btnW)
    self.btnAdd:setHeight(entryH)

    self.btnRemove:setX(rx + entryW + 5 + btnW + 5)
    self.btnRemove:setY(y)
    self.btnRemove:setWidth(btnW)
    self.btnRemove:setHeight(entryH)

    -- ===== Bottom buttons (absolute coords, aligned to right panel) =====
    local absRX = rightX + pad
    local absRW = rightW - pad * 2
    local btnY = self.height - (pad + self.btnSave.height + 6)

    -- 3 buttons: Save, Unadopt, Close
    local totalGap = pad * 2
    local btnTotalW = absRW - totalGap
    local saveW = math.max(110, math.floor(btnTotalW * 0.28))
    local unadoptW = math.max(130, math.floor(btnTotalW * 0.38))
    local closeW = math.max(110, btnTotalW - saveW - unadoptW)

    self.btnSave:setX(absRX)
    self.btnSave:setY(btnY)
    self.btnSave:setWidth(saveW)

    self.btnUnadopt:setX(absRX + saveW + pad)
    self.btnUnadopt:setY(btnY)
    self.btnUnadopt:setWidth(unadoptW)

    self.btnClose:setX(absRX + saveW + pad + unadoptW + pad)
    self.btnClose:setY(btnY)
    self.btnClose:setWidth(closeW)
end

function AACSUserManagerMain:_pinDetailLabels()
    if not self._layout or not self._layout.detailX then return end
    local rx = self._layout.detailX
    if self.lblType then self.lblType:setX(rx) end
    if self.lblName then self.lblName:setX(rx) end
    if self.lblLastSeen then self.lblLastSeen:setX(rx) end
    if self.lblExpiresAt then self.lblExpiresAt:setX(rx) end
    if self.lblLoc then self.lblLoc:setX(rx) end
end


function AACSUserManagerMain:onResize()
    if ISCollapsableWindow.onResize then
        ISCollapsableWindow.onResize(self)
    end
    self._layoutDirty = true
end

function AACSUserManagerMain:fillModeCombos()
    self.comboPickup:clear()
    self.comboLeash:clear()

    local modes = (AACS.GetAllowedModes and AACS.GetAllowedModes()) or { 1, 2, 3, 4 }
    for _, mode in ipairs(modes) do
        local label = (AACS.GetModeLabel and AACS.GetModeLabel(mode)) or tostring(mode)
        self.comboPickup:addOptionWithData(label, mode)
        self.comboLeash:addOptionWithData(label, mode)
    end
end

function AACSUserManagerMain:fillFilterCombos()
    if self.comboFilterType then
        local prevKey = self.comboFilterType:getOptionData(self.comboFilterType.selected)

        self.comboFilterType:clear()
        self.comboFilterType:addOptionWithData(getText("IGUI_AACS_FilterAll"), nil)

        -- Build a union of known vanilla types + current entries (keeps MP-safe ids).
        local seen = {}
        local keys = {}

        -- Known base types (even if you don't have one adopted yet)
        for _, k in ipairs(_KNOWN_BASE_TYPES) do
            local kk = tostring(k or ""):lower()
            if kk ~= "" and not seen[kk] then
                seen[kk] = true
                table.insert(keys, kk)
            end
        end

        -- Types present in current entries (includes stage variants)
        for _, e in ipairs(self.entries or {}) do
            local k = _speciesKeyForEntry(e)
            if k ~= "" and not seen[k] then
                seen[k] = true
                table.insert(keys, k)
            end
        end

        table.sort(keys)

        for _, k in ipairs(keys) do
            self.comboFilterType:addOptionWithData(_typeLabel(k), k)
        end

        -- Restore previous selection if still present
        if prevKey ~= nil then
            for i = 1, #self.comboFilterType.options do
                if self.comboFilterType:getOptionData(i) == prevKey then
                    self.comboFilterType.selected = i
                    break
                end
            end
        end
    end

    if self.comboFilterStatus then
        local prevText = self.comboFilterStatus.options[self.comboFilterStatus.selected]

        self.comboFilterStatus:clear()
        self.comboFilterStatus:addOption(getText("IGUI_AACS_FilterAll"))
        self.comboFilterStatus:addOption(getText("IGUI_AACS_StatusActive"))
        self.comboFilterStatus:addOption(getText("IGUI_AACS_StatusIdle"))
        self.comboFilterStatus:addOption(getText("IGUI_AACS_StatusLost"))

        if prevText then
            for i = 1, #self.comboFilterStatus.options do
                if self.comboFilterStatus.options[i] == prevText then
                    self.comboFilterStatus.selected = i
                    break
                end
            end
        end
    end
end

function AACSUserManagerMain:matchesFilters(entry)
    if self.comboFilterType and self.comboFilterType.selected > 1 then
        local wanted = self.comboFilterType:getOptionData(self.comboFilterType.selected)
        if wanted then
            local animalType = _speciesKeyForEntry(entry)
            if animalType ~= tostring(wanted):lower() then
                return false
            end
        end
    end

    if self.comboFilterStatus and self.comboFilterStatus.selected > 1 then
        local selectedStatus = self.comboFilterStatus.options[self.comboFilterStatus.selected]
        if selectedStatus and selectedStatus ~= getText("IGUI_AACS_FilterAll") then
            local status = AACSUITheme.getStatusIcon(entry.LastSeen)

            if selectedStatus == getText("IGUI_AACS_StatusActive") then
                if status ~= AACSUITheme.StatusIcons.ACTIVE then return false end
            elseif selectedStatus == getText("IGUI_AACS_StatusIdle") then
                if status ~= AACSUITheme.StatusIcons.IDLE then return false end
            elseif selectedStatus == getText("IGUI_AACS_StatusLost") then
                if status ~= AACSUITheme.StatusIcons.LOST then return false end
            end
        end
    end

    -- Tabs (all / mine / others)
    if self.tabMode then
        local me = self:_getUsername()
        if self.tabMode == AACSUserManagerMain.TabModes.MINE then
            if me ~= "" and tostring(entry.Owner or "") ~= me then
                return false
            end
        elseif self.tabMode == AACSUserManagerMain.TabModes.OTHERS then
            if me ~= "" and tostring(entry.Owner or "") == me then
                return false
            end
        end
    end

    local query = AACSUITheme.normQuery(self.searchBox:getInternalText())

    if query then
        local name = entry.Nickname or entry.AnimalName or ""
        local uid = entry.UID or ""
        local searchText = string.lower(name .. " " .. uid)

        if not string.find(searchText, query, 1, true) then
            return false
        end
    end

    return true
end

function AACSUserManagerMain:spBuildMyEntries()
    local reg = AACS.SP_GetRegistry()
    local me = getPlayer():getUsername()
    local out = {}
    for uid, e in pairs(reg) do
        if e and e.Owner == me then
            table.insert(out, e)
        end
    end
    table.sort(out, function(a,b) return tostring(a.UID) < tostring(b.UID) end)
    return out
end

function AACSUserManagerMain:spBuildInteractEntries()
    local reg = AACS.SP_GetRegistry()
    local me = getPlayer():getUsername()
    local out = {}
    for uid, e in pairs(reg) do
        if e then
            if e.Owner == me then
                table.insert(out, e)
            else
                local pickupMode = tonumber(e.PickupMode) or AACS.MODE_OWNER_ONLY
                local leashMode = tonumber(e.LeashMode) or AACS.MODE_OWNER_ONLY
                if _entryAllowListContains(e, me)
                    or _entryModeAllows(e.Owner, me, pickupMode)
                    or _entryModeAllows(e.Owner, me, leashMode) then
                    table.insert(out, e)
                end
            end
        end
    end
    table.sort(out, function(a,b) return tostring(a.UID) < tostring(b.UID) end)
    return out
end

function AACSUserManagerMain:updateFromCache()
    -- Build the combined entry list for this player:
    -- myEntries   = animals owned by this player
    -- interactEntries = animals this player can interact with (may include admin-bypass entries)
    -- We merge both but deduplicate, so "Others" tab shows shared animals without the admin-bypass flood.
    local myEntries = AACS.ClientCache.myEntries or {}
    local interactEntries = AACS.ClientCache.interactEntries or {}

    -- Build a set of own UIDs so we can separate them
    local myUIDSet = {}
    for _, e in ipairs(myEntries) do
        if e and e.UID then myUIDSet[e.UID] = true end
    end

    -- Get own player username to filter out admin-bypass flood from interactEntries
    local me = self:_getUsername()

    -- Merge: own animals + only interact entries that are genuinely NOT owned by me
    -- (skip admin-bypass entries that belong to other players when admin bypass is active)
    local merged = {}
    local mergedUIDs = {}
    for _, e in ipairs(myEntries) do
        if e and e.UID and not mergedUIDs[e.UID] then
            table.insert(merged, e)
            mergedUIDs[e.UID] = true
        end
    end
    for _, e in ipairs(interactEntries) do
        if e and e.UID and not mergedUIDs[e.UID] then
            -- Only include interact entries that this player can genuinely interact with
            -- by permission (safehouse/faction/allowlist), NOT by admin bypass
            local owner = tostring(e.Owner or "")
            if owner ~= me then
                -- Check real permission (not admin bypass)
                local pickupMode = tonumber(e.PickupMode) or AACS.MODE_OWNER_ONLY
                local leashMode = tonumber(e.LeashMode) or AACS.MODE_OWNER_ONLY
                local hasRealPerm = _entryAllowListContains(e, me)
                    or _entryModeAllows(owner, me, pickupMode)
                    or _entryModeAllows(owner, me, leashMode)
                if hasRealPerm then
                    table.insert(merged, e)
                    mergedUIDs[e.UID] = true
                end
            end
        end
    end

    self.entries = merged
    AACS.Log("[UserManager] updateFromCache called, entries count: " .. #self.entries)
    self:fillFilterCombos()
    self:refreshList()
end


local function _entryBaseName(e)
    if not e then return getText("IGUI_AACS_Unknown") end
    local nn = tostring(e.Nickname or "")
    if nn ~= "" then return nn end

    local an = tostring(e.AnimalName or "")
    if an ~= "" then
        -- If some setups return a placeholder name for all animals, fall back to a unique label.
        local lc = string.lower(an)
        if lc ~= "bob" then
            return an
        end
    end

    -- Fallback: Type + UID (unique, stable)
    local tl = _typeLabel(e.AnimalType)
    local uid = tostring(e.UID or "?")
    return string.format("%s #%s", tl, uid)
end

local function _entryListLabel(e)
    local base = _entryBaseName(e)
    local tl = _typeLabel(e and e.AnimalType)
    local uid = tostring(e and e.UID or "")
    if uid ~= "" then
        return string.format("%s (%s) [%s]", base, tl, uid)
    end
    return string.format("%s (%s)", base, tl)
end

function AACSUserManagerMain:refreshList()
    self.list:clear()

    for _, e in ipairs(self.entries) do
        if self:matchesFilters(e) then
            local displayText = _entryListLabel(e)

            local it = self.list:addItem(displayText, e)
            if it then
                it.tooltip = string.format("%s: %s", getText("IGUI_AACS_Code"), tostring(e.UID or ""))
            end
        end
    end

    self:onSelect()
end

function AACSUserManagerMain:onSelect()
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

function AACSUserManagerMain:setDetails(e)
    self:_pinDetailLabels()
    if not e then
        self.lblCode:setName(getText("IGUI_AACS_Code")..": -")
        self.lblType:setName(getText("IGUI_AACS_Type")..": -")
        self.lblName:setName(getText("IGUI_AACS_Name")..": -")
        self.txtNickname:setText("")
        self.txtNickname:setEditable(false)
        self.btnRename:setEnable(false)
        self.lblLastSeen:setName(getText("IGUI_AACS_LastSeen")..": -")
        self.lblExpiresAt:setName(getText("IGUI_AACS_ExpiresAt")..": -")
        self.lblLoc:setName(getText("IGUI_AACS_Location")..": -")
        self.allowListBox:clear()
        _selectComboByData(self.comboPickup, AACS.MODE_OWNER_ONLY)
        _selectComboByData(self.comboLeash, AACS.MODE_OWNER_ONLY)
        self.btnSave:setEnable(false)
        self.btnUnadopt:setEnable(false)
        return
    end

    self.lblCode:setName(getText("IGUI_AACS_Code")..": "..tostring(e.UID))
    self.lblType:setName(getText("IGUI_AACS_Type")..": ".._typeLabel(e.AnimalType))
    self.lblName:setName(getText("IGUI_AACS_Name")..": "..tostring(_entryBaseName(e) or "-"))

    self.txtNickname:setText(e.Nickname or "")
    self.txtNickname:setEditable(true)
    self.btnRename:setEnable(true)

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
        local username = getPlayer() and getPlayer():getUsername() or nil
        local canSee = (AACS.IsAdmin and AACS.IsAdmin(getPlayer())) or (owner and username and owner == username)
        if not canSee then
            self.lblExpiresAt:setName(getText("IGUI_AACS_ExpiresAt")..": -")
        else
            local lastLogin = (AACS.GetPlayerLastLogin and owner) and AACS.GetPlayerLastLogin(owner) or nil
            if lastLogin and lastLogin > 0 then
                local expiresAt = lastLogin + math.floor(expiryDays * 86400)
                self.lblExpiresAt:setName(getText("IGUI_AACS_ExpiresAt")..": ".._formatLastSeen(expiresAt))
            else
                self.lblExpiresAt:setName(getText("IGUI_AACS_ExpiresAt")..": -")
            end
        end
    end

    self.lblLoc:setName(getText("IGUI_AACS_Location")..": "..AACS.FormatLocation(e))

    local pickupMode = AACS.SanitizeMode(tonumber(e.PickupMode) or AACS.MODE_OWNER_ONLY)
    local leashMode = AACS.SanitizeMode(tonumber(e.LeashMode) or AACS.MODE_OWNER_ONLY)
    _selectComboByData(self.comboPickup, pickupMode)
    _selectComboByData(self.comboLeash, leashMode)

    self.allowListBox:clear()
    local allow = e.AllowList or {}
    for _, u in ipairs(allow) do
        self.allowListBox:addItem(tostring(u), tostring(u))
    end

    self.btnSave:setEnable(true)
    self.btnUnadopt:setEnable(true)
end

function AACSUserManagerMain:onUnadoptConfirm(button)
    -- PZ B42 ISModalDialog calls: onclick(target, button)
    -- target = self (the manager), button = the clicked ISButton
    if not button or button.internal ~= "YES" then return end

    local uidToRemove = self._pendingUnadoptUID
    self._pendingUnadoptUID = nil

    if not uidToRemove or uidToRemove == "" then return end

    if isClient() then
        sendClientCommand(getPlayer(), "AACS", "unadoptAnimal", { uid = uidToRemove })
    else
        local reg = AACS.SP_GetRegistry()
        reg[uidToRemove] = nil
        self:updateFromCache()
    end
end

function AACSUserManagerMain:onClick(button)
    if button.internal == "CLOSE" then
        self:setVisible(false)
        self:removeFromUIManager()
        return
    end

    if not self.selectedEntry then return end

    if button.internal == "ADD" then
        local u = self.allowEntry:getText() or ""
        u = (u:gsub("^%s*(.-)%s*$", "%1"))
        if u ~= "" then
            self.allowListBox:addItem(u, u)
            self.allowEntry:setText("")
        end
        return
    end

    if button.internal == "REMOVE" then
        local sel = self.allowListBox.selected
        if sel and self.allowListBox.items[sel] then
            table.remove(self.allowListBox.items, sel)
            self.allowListBox.selected = 0
        end
        return
    end

    if button.internal == "RENAME" then
        local e = self.selectedEntry
        if not e or not e.UID then return end

        local nickname = self.txtNickname:getInternalText() or ""
        nickname = nickname:gsub("^%s+", ""):gsub("%s+$", "")

        if nickname == "" then
            local modal = ISModalDialog:new(0, 0, 300, 150,
                getText("IGUI_AACS_NicknameEmptyError"), false, nil, nil)
            modal:initialise()
            modal:addToUIManager()
            return
        end

        if isClient() then
            sendClientCommand(getPlayer(), "AACS", "renameAnimal", {
                uid = e.UID,
                nickname = nickname
            })
        else
            local reg = AACS.SP_GetRegistry()
            if reg[e.UID] then
                reg[e.UID].Nickname = nickname
                e.Nickname = nickname
                self:refreshList()
            end
        end
        return
    end

    if button.internal == "UNADOPT" then
        local e = self.selectedEntry
        if not e or not e.UID then return end
        local animalName = e.Nickname or e.AnimalName or getText("IGUI_AACS_Unknown")
        local uidToRemove = tostring(e.UID)

        -- Store UID for the callback
        self._pendingUnadoptUID = uidToRemove

        -- Create confirmation modal (PZ B42 pattern: target=self, callback receives (self, button))
        local modal = ISModalDialog:new(
            0, 0, 400, 180,
            _safeTextFormat(getText("IGUI_AACS_UnadoptConfirm"), animalName, uidToRemove),
            true,
            self,
            AACSUserManagerMain.onUnadoptConfirm
        )
        modal:initialise()
        modal:addToUIManager()
        return
    end

    if button.internal == "SAVE" then
        local allow = {}
        for i=1,#self.allowListBox.items do
            table.insert(allow, self.allowListBox.items[i].item)
        end

        local pickupMode = self.comboPickup:getOptionData(self.comboPickup.selected) or 1
        local leashMode  = self.comboLeash:getOptionData(self.comboLeash.selected) or 1

        if isClient() then
            sendClientCommand(getPlayer(), "AACS", "setPermissions", {
                uid = self.selectedEntry.UID,
                pickupMode = pickupMode,
                leashMode = leashMode,
                allowList = allow,
            })
        else
            local reg = AACS.SP_GetRegistry()
            local e = reg[self.selectedEntry.UID]
            if e then
                e.PickupMode = pickupMode
                e.LeashMode  = leashMode
                e.AllowList  = allow
                reg[self.selectedEntry.UID] = e
            end
        end
        return
    end
end

function AACSUserManagerMain:new(x, y, w, h)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.background = true
    o.drawFrame = true
    o.resizable = true
    return o
end
