require "ISUI/ISUIElement"
require "EnergyRouting/Init"

EnergyRouting = EnergyRouting or {}
EnergyRouting.RangeOverlay = EnergyRouting.RangeOverlay or {}

local RangeOverlay = EnergyRouting.RangeOverlay
local DEFAULT_DURATION_MS = 20000
local GRID_COLOR = { r = 0.30, g = 0.95, b = 0.35, a = 0.10 }
local ACTIVE_COLOR = { r = 0.15, g = 1.00, b = 0.25, a = 0.28 }
local LABEL_COLOR = { r = 0.85, g = 1.00, b = 0.90, a = 0.95 }

local function nowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    if getTimeInMillis then
        return getTimeInMillis()
    end
    return os.time() * 1000
end

local function isUiVisible(ui)
    if not ui then
        return false
    end
    if ui.getIsVisible then
        return ui:getIsVisible()
    end
    if type(ui.isVisible) == "function" then
        return ui:isVisible()
    end
    return ui.visible == true
end

local function normalizeSquares(source)
    local list = {}
    if type(source) ~= "table" then
        return list
    end

    local seen = {}
    local function pushSquare(x, y, z)
        local nx = tonumber(x)
        local ny = tonumber(y)
        local nz = tonumber(z)
        if not nx or not ny or not nz then
            return
        end
        nx = math.floor(nx)
        ny = math.floor(ny)
        nz = math.floor(nz)
        local key = tostring(nx) .. "_" .. tostring(ny) .. "_" .. tostring(nz)
        if seen[key] then
            return
        end
        seen[key] = true
        list[#list + 1] = { x = nx, y = ny, z = nz }
    end

    local hasArrayEntries = false
    for _, entry in ipairs(source) do
        hasArrayEntries = true
        if type(entry) == "table" then
            pushSquare(entry.x, entry.y, entry.z)
        elseif type(entry) == "string" then
            local xs, ys, zs = entry:match("^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            pushSquare(xs, ys, zs)
        end
    end
    if hasArrayEntries then
        return list
    end

    for key, value in pairs(source) do
        if value == true and type(key) == "string" then
            local xs, ys, zs = key:match("^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            pushSquare(xs, ys, zs)
        elseif type(value) == "table" then
            pushSquare(value.x, value.y, value.z)
        elseif type(value) == "string" then
            local xs, ys, zs = value:match("^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            pushSquare(xs, ys, zs)
        end
    end

    return list
end

local function normalizeControllerId(controllerId)
    if type(controllerId) ~= "string" then
        return controllerId
    end
    if string.find(controllerId, ",", 1, true) then
        local xs, ys, zs = controllerId:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
        if xs and ys and zs then
            return string.format("network_%d_%d_%d", tonumber(xs), tonumber(ys), tonumber(zs))
        end
    end
    local xs, ys, zs = controllerId:match("^energy_net_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
    if xs and ys and zs then
        return string.format("network_%d_%d_%d", tonumber(xs), tonumber(ys), tonumber(zs))
    end
    return controllerId
end

local function parseControllerCoordsFromId(controllerId)
    controllerId = normalizeControllerId(controllerId)
    if type(controllerId) ~= "string" then
        return nil, nil, nil
    end
    local xs, ys, zs = controllerId:match("^network_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
    if xs and ys and zs then
        return tonumber(xs), tonumber(ys), tonumber(zs)
    end
    xs, ys, zs = controllerId:match("^energy_net_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
    if xs and ys and zs then
        return tonumber(xs), tonumber(ys), tonumber(zs)
    end
    return nil, nil, nil
end

local function parseControllerCoords(controllerId, state)
    local x, y, z = parseControllerCoordsFromId(controllerId)
    if x and y and z then
        return x, y, z
    end
    if type(state) == "table" then
        x = tonumber(state.x)
        y = tonumber(state.y)
        z = tonumber(state.z)
        if x and y and z then
            return math.floor(x), math.floor(y), math.floor(z)
        end
    end
    return nil, nil, nil
end

local function isControllerObjectOnSquare(obj, controllerId)
    if not obj then
        return false
    end
    local md = obj.getModData and obj:getModData() or nil
    local networkId = md and type(md.energyController) == "table" and md.energyController.networkId or nil
    if networkId then
        return normalizeControllerId(networkId) == normalizeControllerId(controllerId)
    end
    local item = (obj.getItem and obj:getItem()) or (obj.getInventoryItem and obj:getInventoryItem()) or nil
    local fullType = item and item.getFullType and item:getFullType()
    if not fullType and obj.getItem then
        local worldItem = obj:getItem()
        fullType = worldItem and worldItem.getFullType and worldItem:getFullType() or nil
    end
    if fullType ~= "EnergyRouting.EnergyController" and fullType ~= "EnergyController" then
        return false
    end
    return true
end

local function controllerStillExists(controllerId)
    local x, y, z = parseControllerCoordsFromId(controllerId)
    if not x then
        return false
    end
    local cell = getCell and getCell() or nil
    if not cell then
        return false
    end
    local square = cell:getGridSquare(x, y, z)
    if not square then
        return false
    end
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            if isControllerObjectOnSquare(objects:get(i), controllerId) then
                return true
            end
        end
    end
    local worldObjects = square:getWorldObjects()
    if worldObjects then
        for i = 0, worldObjects:size() - 1 do
            if isControllerObjectOnSquare(worldObjects:get(i), controllerId) then
                return true
            end
        end
    end
    return false
end

local function getControllerRadius()
    if EnergyNetwork and EnergyNetwork.GetConfigValue then
        local value = tonumber(EnergyNetwork.GetConfigValue("ControllerConnectRadius"))
        if value and value > 0 then
            return math.floor(value)
        end
    end
    if EnergyRouting and EnergyRouting.CONTROLLER_RADIUS then
        local value = tonumber(EnergyRouting.CONTROLLER_RADIUS)
        if value and value > 0 then
            return math.floor(value)
        end
    end
    return 20
end

local function buildCoverageSquares(cx, cy, cz, radius)
    local list = {}
    local r = math.max(1, math.floor(tonumber(radius) or 20))
    local r2 = r * r
    for dx = -r, r do
        for dy = -r, r do
            if (dx * dx + dy * dy) <= r2 then
                local x = cx + dx
                local y = cy + dy
                local z = cz
                local key = tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(z)
                list[#list + 1] = { x = x, y = y, z = z, key = key }
            end
        end
    end
    return list
end

local function worldToScreen(x, y, z)
    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    local playerNum = (player and player.getPlayerNum and player:getPlayerNum()) or 0
    local screenLeft = (type(getPlayerScreenLeft) == "function" and tonumber(getPlayerScreenLeft(playerNum))) or 0
    local screenTop = (type(getPlayerScreenTop) == "function" and tonumber(getPlayerScreenTop(playerNum))) or 0

    if IsoUtils and type(IsoUtils.XToScreen) == "function" and type(IsoUtils.YToScreen) == "function" then
        local okX, sx = pcall(IsoUtils.XToScreen, x, y, z, 0)
        local okY, sy = pcall(IsoUtils.YToScreen, x, y, z, 0)
        if okX and okY and type(sx) == "number" and type(sy) == "number" then
            return sx + screenLeft, sy + screenTop
        end
    end

    if type(isoToScreenX) == "function" and type(isoToScreenY) == "function" then
        local okX, sx = pcall(isoToScreenX, playerNum, x, y, z)
        local okY, sy = pcall(isoToScreenY, playerNum, x, y, z)
        if okX and okY and type(sx) == "number" and type(sy) == "number" then
            return sx, sy
        end

        okX, sx = pcall(isoToScreenX, x, y, z, 0)
        okY, sy = pcall(isoToScreenY, x, y, z, 0)
        if okX and okY and type(sx) == "number" and type(sy) == "number" then
            return sx, sy
        end
    end

    return nil, nil
end

local function tileToScreenPoints(x, y, z)
    local tx, ty = worldToScreen(x, y, z)
    local rx, ry = worldToScreen(x + 1, y, z)
    local bx, by = worldToScreen(x + 1, y + 1, z)
    local lx, ly = worldToScreen(x, y + 1, z)
    if not tx or not ty or not rx or not ry or not bx or not by or not lx or not ly then
        return nil
    end
    return tx, ty, rx, ry, bx, by, lx, ly
end

local function tileIsVisible(width, height, tx, ty, rx, ry, bx, by, lx, ly)
    local minX = math.min(tx, rx, bx, lx)
    local maxX = math.max(tx, rx, bx, lx)
    local minY = math.min(ty, ry, by, ly)
    local maxY = math.max(ty, ry, by, ly)
    local margin = 64
    if maxX < -margin or maxY < -margin then
        return false
    end
    if minX > width + margin or minY > height + margin then
        return false
    end
    return true
end

ERS_RangeOverlay = ISUIElement:derive("ERS_RangeOverlay")

local function makeOverlayInputPassive(o)
    if not o then
        return
    end
    o.capture = false
    o.ignoreStencil = true
    if o.setCapture then
        o:setCapture(false)
    end
    if o.setWantMouseEvents then
        o:setWantMouseEvents(false)
    end
    if o.setMouseEnabled then
        o:setMouseEnabled(false)
    end
    if o.setWantKeyEvents then
        o:setWantKeyEvents(false)
    end
    if o.setScrollChildren then
        o:setScrollChildren(false)
    end
end

function ERS_RangeOverlay:new(x, y, width, height)
    local o = ISUIElement.new(self, x, y, width, height)
    o.noBackground = true
    o.controllerId = nil
    o.state = nil
    o.energizedSquares = {}
    o.energizedSquaresMap = {}
    o.coverageSquares = {}
    o.coverageCenter = nil
    o.coverageRadius = 0
    o.coverageCacheKey = nil
    o.expiresAtMs = 0
    o.anchorLeft = true
    o.anchorRight = true
    o.anchorTop = true
    o.anchorBottom = true
    makeOverlayInputPassive(o)
    return o
end

function ERS_RangeOverlay:initialise()
    ISUIElement.initialise(self)
    makeOverlayInputPassive(self)
end

function ERS_RangeOverlay:onMouseDown()
    return false
end

function ERS_RangeOverlay:onMouseUp()
    return false
end

function ERS_RangeOverlay:onMouseUpOutside()
    return false
end

function ERS_RangeOverlay:onRightMouseDown()
    return false
end

function ERS_RangeOverlay:onRightMouseUp()
    return false
end

function ERS_RangeOverlay:onRightMouseUpOutside()
    return false
end

function ERS_RangeOverlay:onMouseMove()
    return false
end

function ERS_RangeOverlay:onMouseMoveOutside()
    return false
end

function ERS_RangeOverlay:onMouseWheel()
    return false
end

function ERS_RangeOverlay:setController(controllerId, state)
    self.controllerId = normalizeControllerId(controllerId)
    self:updateState(state)
end

function ERS_RangeOverlay:updateState(state)
    self.state = state
    self.energizedSquares = normalizeSquares(state and state.energizedSquares)
    self.energizedSquaresMap = {}
    for _, square in ipairs(self.energizedSquares) do
        local key = tostring(square.x) .. "_" .. tostring(square.y) .. "_" .. tostring(square.z)
        self.energizedSquaresMap[key] = true
    end
    self:refreshCoverage()
end

function ERS_RangeOverlay:refreshCoverage()
    local cx, cy, cz = parseControllerCoords(self.controllerId, self.state)
    if not cx or not cy or not cz then
        self.coverageCenter = nil
        self.coverageSquares = {}
        self.coverageRadius = 0
        self.coverageCacheKey = nil
        return
    end
    local radius = getControllerRadius()
    local key = tostring(cx) .. "_" .. tostring(cy) .. "_" .. tostring(cz) .. "|" .. tostring(radius)
    if self.coverageCacheKey == key and self.coverageSquares and #self.coverageSquares > 0 then
        return
    end
    self.coverageCenter = { x = cx, y = cy, z = cz }
    self.coverageRadius = radius
    self.coverageCacheKey = key
    self.coverageSquares = buildCoverageSquares(cx, cy, cz, radius)
end

function ERS_RangeOverlay:drawIsoTileOutline(square, color)
    if type(addAreaHighlight) == "function" then
        addAreaHighlight(
            square.x,
            square.y,
            square.x + 1,
            square.y + 1,
            square.z,
            color.r,
            color.g,
            color.b,
            color.a
        )
        return true
    end

    local tx, ty, rx, ry, bx, by, lx, ly = tileToScreenPoints(square.x, square.y, square.z)
    if not tx then
        if type(renderIsoRect) == "function" then
            renderIsoRect(
                square.x + 1,
                square.y + 1,
                square.z,
                1.0,
                color.r,
                color.g,
                color.b,
                color.a,
                1
            )
            return true
        end
        return false
    end
    local ax = (self.getAbsoluteX and self:getAbsoluteX()) or 0
    local ay = (self.getAbsoluteY and self:getAbsoluteY()) or 0

    local ltx = tx - ax
    local lty = ty - ay
    local lrx = rx - ax
    local lry = ry - ay
    local lbx = bx - ax
    local lby = by - ay
    local llx = lx - ax
    local lly = ly - ay

    if not tileIsVisible(self.width, self.height, ltx, lty, lrx, lry, lbx, lby, llx, lly) then
        return false
    end
    self:drawLine(ltx, lty, lrx, lry, color.a, color.r, color.g, color.b)
    self:drawLine(lrx, lry, lbx, lby, color.a, color.r, color.g, color.b)
    self:drawLine(lbx, lby, llx, lly, color.a, color.r, color.g, color.b)
    self:drawLine(llx, lly, ltx, lty, color.a, color.r, color.g, color.b)
    return true
end

function ERS_RangeOverlay:render()
    if not self.controllerId then
        return
    end
    if not controllerStillExists(self.controllerId) then
        RangeOverlay.Hide()
        return
    end
    if self.expiresAtMs > 0 and nowMs() >= self.expiresAtMs then
        RangeOverlay.Hide()
        return
    end
    local squares = self.energizedSquares or {}
    local count = #squares
    local coverageCount = self.coverageSquares and #self.coverageSquares or 0
    self:drawText(
        "ERS energized: " .. tostring(count) .. " / coverage: " .. tostring(coverageCount),
        18,
        18,
        LABEL_COLOR.r,
        LABEL_COLOR.g,
        LABEL_COLOR.b,
        LABEL_COLOR.a,
        UIFont.Small
    )

    local drew = 0
    if coverageCount > 0 then
        for _, square in ipairs(self.coverageSquares) do
            local color = self.energizedSquaresMap and self.energizedSquaresMap[square.key] and ACTIVE_COLOR or GRID_COLOR
            if self:drawIsoTileOutline(square, color) then
                drew = drew + 1
            end
        end
    elseif count > 0 then
        for _, square in ipairs(squares) do
            if self:drawIsoTileOutline(square, ACTIVE_COLOR) then
                drew = drew + 1
            end
        end
    end

    if drew <= 0 and count > 0 and DebugDraw and type(DebugDraw.addCircle) == "function" then
        for _, square in ipairs(squares) do
            DebugDraw.addCircle(
                square.x + 0.5,
                square.y + 0.5,
                0.46,
                ACTIVE_COLOR.r,
                ACTIVE_COLOR.g,
                ACTIVE_COLOR.b,
                ACTIVE_COLOR.a
            )
        end
    end
end

local function ensureInstance()
    local overlay = RangeOverlay.instance
    if overlay then
        return overlay
    end
    local core = getCore and getCore() or nil
    local width = core and core.getScreenWidth and core:getScreenWidth() or 1920
    local height = core and core.getScreenHeight and core:getScreenHeight() or 1080
    overlay = ERS_RangeOverlay:new(0, 0, width, height)
    overlay:initialise()
    RangeOverlay.instance = overlay
    return overlay
end

function RangeOverlay.Show(controllerId, state, durationMs)
    controllerId = normalizeControllerId(controllerId)
    if not controllerId then
        return false
    end
    if type(state) == "table" and state.id then
        state.id = normalizeControllerId(state.id)
    end
    local overlay = ensureInstance()
    makeOverlayInputPassive(overlay)
    overlay:setController(controllerId, state)
    overlay.expiresAtMs = nowMs() + math.max(1000, tonumber(durationMs) or DEFAULT_DURATION_MS)
    if not isUiVisible(overlay) then
        overlay:addToUIManager()
    end
    overlay:setVisible(true)
    return true
end

function RangeOverlay.Hide()
    local overlay = RangeOverlay.instance
    if not overlay then
        return
    end
    overlay:setVisible(false)
    overlay.controllerId = nil
    overlay.state = nil
    overlay.energizedSquares = {}
    overlay.energizedSquaresMap = {}
    overlay.coverageSquares = {}
    overlay.coverageCenter = nil
    overlay.coverageRadius = 0
    overlay.coverageCacheKey = nil
    overlay.expiresAtMs = 0
    if isUiVisible(overlay) then
        overlay:removeFromUIManager()
    end
end

function RangeOverlay.HideIfController(controllerId)
    controllerId = normalizeControllerId(controllerId)
    local overlay = RangeOverlay.instance
    if not overlay then
        return
    end
    if normalizeControllerId(overlay.controllerId) == controllerId then
        RangeOverlay.Hide()
    end
end

function RangeOverlay.IsVisibleFor(controllerId)
    controllerId = normalizeControllerId(controllerId)
    local overlay = RangeOverlay.instance
    if not overlay then
        return false
    end
    if normalizeControllerId(overlay.controllerId) ~= controllerId then
        return false
    end
    return isUiVisible(overlay)
end

function RangeOverlay.Toggle(controllerId, state, durationMs)
    if RangeOverlay.IsVisibleFor(controllerId) then
        RangeOverlay.Hide()
        return false
    end
    return RangeOverlay.Show(controllerId, state, durationMs)
end

function RangeOverlay.OnStateUpdated(edcState)
    local overlay = RangeOverlay.instance
    if not overlay or not edcState or not edcState.id then
        return
    end
    local stateId = normalizeControllerId(edcState.id)
    if stateId ~= edcState.id then
        edcState.id = stateId
    end
    if normalizeControllerId(overlay.controllerId) ~= stateId then
        return
    end
    overlay:updateState(edcState)
end
