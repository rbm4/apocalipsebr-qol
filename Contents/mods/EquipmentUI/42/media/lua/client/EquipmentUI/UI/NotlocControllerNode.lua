---@diagnostic disable: duplicate-set-field, redundant-parameter

---@class NotlocControllerNode
---@field uiElement ISUIElement
---@field processRealEvents boolean
---@field childrenNodeProvider function
---@field childrenNodeProviderArgs table
---@field selectedChild NotlocControllerNode
---@field handleJoypadDown function
---@field handleJoypadDir function
---@field handleLoseJoypadFocus function
---@field handleGainJoypadFocus function
---@field isFocused boolean
NotlocControllerNode = {}
NotlocControllerNode.FOCUS_COLOR = { r = 0.2, g = 1.0, b = 1.0, a = 0.4 }
NotlocControllerNode.menuFocusSupression = {}

---@return NotlocControllerNode
function NotlocControllerNode:injectControllerNode(uiElement, processRealEvents)
    local o = {}
    setmetatable(o, { __index = NotlocControllerNode })
    self.__index = self
    o.uiElement = uiElement
    o.processRealEvents = processRealEvents
    uiElement.controllerNode = o
    o:hookJoypadEvents()
    return o
end

---@return NotlocControllerNode
function NotlocControllerNode:doSimpleFocusHighlight()
    self.og_render = self.uiElement.render
    self.uiElement.render = function(uiElement)
        self.og_render(uiElement)
        if self.isFocused then
            uiElement:drawRectBorder(0, 0, uiElement:getWidth(), uiElement:getHeight(), 0.4, self.FOCUS_COLOR.r, self.FOCUS_COLOR.g, self.FOCUS_COLOR.b)
            uiElement:drawRectBorder(1, 1, uiElement:getWidth() - 2, uiElement:getHeight() - 2, 0.4, self.FOCUS_COLOR.r, self.FOCUS_COLOR.g, self.FOCUS_COLOR.b)
        end
    end
    return self
end

---@return NotlocControllerNode
function NotlocControllerNode:setChildrenNodeProvider(func, ...)
    self.childrenNodeProvider = func
    self.childrenNodeProviderArgs = {...}
    return self
end

---@return NotlocControllerNode
function NotlocControllerNode:setJoypadDownHandler(func)
    self.handleJoypadDown = func
    return self
end

---@return NotlocControllerNode
function NotlocControllerNode:setJoypadDirHandler(func)
    self.handleJoypadDir = func
    return self
end

---@return NotlocControllerNode
function NotlocControllerNode:setLoseJoypadFocusHandler(func)
    self.handleLoseJoypadFocus = func
    return self
end

---@return NotlocControllerNode
function NotlocControllerNode:setGainJoypadFocusHandler(func)
    self.handleGainJoypadFocus = func
    return self
end

function NotlocControllerNode:hookJoypadEvents()
    self.og_onJoypadDown = self.uiElement.onJoypadDown
    self.uiElement.onJoypadDown = function(uiElement, button, joypadData)
        self:onJoypadDown(button, joypadData)
    end

    self.og_onJoypadDirLeft = self.uiElement.onJoypadDirLeft
    self.uiElement.onJoypadDirLeft = function(uiElement, joypadData)
        self:onJoypadDir(-1, 0, joypadData)
    end

    self.og_onJoypadDirRight = self.uiElement.onJoypadDirRight
    self.uiElement.onJoypadDirRight = function(uiElement, joypadData)
        self:onJoypadDir(1, 0, joypadData)
    end

    self.og_onJoypadDirUp = self.uiElement.onJoypadDirUp
    self.uiElement.onJoypadDirUp = function(uiElement, joypadData)
        self:onJoypadDir(0, -1, joypadData)
    end

    self.og_onJoypadDirDown = self.uiElement.onJoypadDirDown
    self.uiElement.onJoypadDirDown = function(uiElement, joypadData)
        self:onJoypadDir(0, 1, joypadData)
    end

    self.og_onLoseJoypadFocus = self.uiElement.onLoseJoypadFocus
    self.uiElement.onLoseJoypadFocus = function(uiElement, joypadData)
        self:onLoseJoypadFocus(joypadData)
    end

    self.og_onGainJoypadFocus = self.uiElement.onGainJoypadFocus
    self.uiElement.onGainJoypadFocus = function(uiElement, joypadData)
        self:onGainJoypadFocus(joypadData)
    end
end

function NotlocControllerNode:unhookJoypadEvents()
    self.uiElement.onJoypadDown = self.og_onJoypadDown
    self.uiElement.onJoypadDirLeft = self.og_onJoypadDirLeft
    self.uiElement.onJoypadDirRight = self.og_onJoypadDirRight
    self.uiElement.onJoypadDirUp = self.og_onJoypadDirUp
    self.uiElement.onJoypadDirDown = self.og_onJoypadDirDown
    self.uiElement.onLoseJoypadFocus = self.og_onLoseJoypadFocus
    self.uiElement.onGainJoypadFocus = self.og_onGainJoypadFocus
end

-- All joypad events are handled by the controller node and will follow the same pattern as this one
function NotlocControllerNode:onJoypadDown(button, joypadData)
    -- If we have a selected child node, we try to pass the event to it first
    if self.selectedChild and self.selectedChild:onJoypadDown(button, joypadData) then
        return true
    end

    -- If we have a custom handler for this event, we call it now
    if self.handleJoypadDown and self.handleJoypadDown(self.uiElement, button, joypadData) then
        return true
    end

    -- Lastly, we defer to the original ui element if it has joyfocus
    if self.processRealEvents then
        self.og_onJoypadDown(self.uiElement, button, joypadData)
    end
    return false
end

function NotlocControllerNode:onJoypadDir(dx, dy, joypadData)
    if self.selectedChild and self.selectedChild:onJoypadDir(dx, dy, joypadData) then
        return true
    end

    if self.handleJoypadDir and self.handleJoypadDir(self.uiElement, dx, dy, joypadData) then
        return true
    end

    if self.childrenNodeProvider then
        local childrenNodes = self.childrenNodeProvider(unpack(self.childrenNodeProviderArgs))
        if self:tryNavigateChildren(childrenNodes, dx, dy) then
            return true
        end
    end

    if self.processRealEvents then
        if dx == -1 then
            self.og_onJoypadDirLeft(self.uiElement, joypadData)
        elseif dx == 1 then
            self.og_onJoypadDirRight(self.uiElement, joypadData)
        elseif dy == -1 then
            self.og_onJoypadDirUp(self.uiElement, joypadData)
        elseif dy == 1 then
            self.og_onJoypadDirDown(self.uiElement, joypadData)
        end
    end
    return false
end

function NotlocControllerNode:tryNavigateChildren(children, dx, dy)
    if not children or #children == 0 then
        return false
    end

    local selectedChild = self.selectedChild
    if not selectedChild then
        self.selectedChild = children[1]
        self.selectedChild:onGainJoypadFocus()
        return true
    end

    local x = selectedChild.uiElement:getAbsoluteX()
    local y = selectedChild.uiElement:getAbsoluteY()

    -- Use the input direction to determine the next child to select
    local nearestChild = nil
    local nearestDistance = math.huge
    for _, child in ipairs(children) do
        if child ~= selectedChild then
            local cx = child.uiElement:getAbsoluteX()
            local cy = child.uiElement:getAbsoluteY()

            local isLeft = dx == -1 and cx < x
            local isRight = dx == 1 and cx > x
            local isUp = dy == -1 and cy < y
            local isDown = dy == 1 and cy > y
            if isLeft or isRight or isUp or isDown then
                -- A mid heuristic, but should work for most contemporary UI layouts
                local distance = math.abs(cx - x) + math.abs(cy - y)

                local angle = math.atan2(cy - y, cx - x)
                local isAngleGood = false
                if isRight then
                    isAngleGood = angle > -math.pi/4 and angle < math.pi/4
                elseif isLeft then
                    isAngleGood = angle > 3*math.pi/4 or angle < -3*math.pi/4
                elseif isUp then
                    isAngleGood = angle > -3*math.pi/4 and angle < -math.pi/4
                elseif isDown then
                    isAngleGood = angle > math.pi/4 and angle < 3*math.pi/4
                end

                if isAngleGood and distance < nearestDistance then
                    nearestChild = child
                    nearestDistance = distance
                end
            end
        end
    end

    if nearestChild then
        self:setSelectedChild(nearestChild)
        return true
    end
end

function NotlocControllerNode:setSelectedChild(childNode)
    if not self.isFocused then
        self.selectedChild = childNode
        return
    end

    if self.selectedChild then
        self.selectedChild:onLoseJoypadFocus()
    end
    self.selectedChild = childNode
    if self.selectedChild then
        self.selectedChild:onGainJoypadFocus()
    end
end

function NotlocControllerNode:validateSelectedChild()
    if not self.selectedChild then
        return true
    end

    local children = self.childrenNodeProvider and self.childrenNodeProvider(unpack(self.childrenNodeProviderArgs)) or {}
    for _, child in ipairs(children) do
        if child == self.selectedChild then
            return true
        end
    end
    return false
end

function NotlocControllerNode:refreshSelectedChild()
    if self:validateSelectedChild() then
        return
    end

    local children = self.childrenNodeProvider and self.childrenNodeProvider(unpack(self.childrenNodeProviderArgs)) or {}
    self.selectedChild = children[1]
    if self.selectedChild then
        self.selectedChild:onGainJoypadFocus()
    end
end

function NotlocControllerNode:getLeafChild()
    local current = self
    while current.selectedChild do
        current = current.selectedChild
    end
    return current
end

-- No early returns here, everything needs to know when the focus is lost/gained
function NotlocControllerNode:onLoseJoypadFocus(joypadData)
    -- We do not process the controllerNode lose focus events when opening a context menu
    if not joypadData or not NotlocControllerNode.menuFocusSupression[joypadData.player] then
        self.isFocused = false
        if self.selectedChild then
            self.selectedChild:onLoseJoypadFocus()
        end
        if self.handleLoseJoypadFocus then 
            self.handleLoseJoypadFocus(self.uiElement, joypadData)
        end
    end

    if joypadData then
        NotlocControllerNode.menuFocusSupression[joypadData.player] = nil
    end

    if self.processRealEvents then
        self.og_onLoseJoypadFocus(self.uiElement, joypadData)
    end
end

function NotlocControllerNode:onGainJoypadFocus(joypadData)
    self.isFocused = true

    if self.selectedChild and not self:validateSelectedChild() then
        self.selectedChild = nil -- No onLoseJoypadFocus because it shouldn't have focus in the first place at this point
    end

    if not self.selectedChild then
        local children = self.childrenNodeProvider and self.childrenNodeProvider(unpack(self.childrenNodeProviderArgs)) or {}
        self.selectedChild = children[1]
    end

    if self.selectedChild then
        self.selectedChild:onGainJoypadFocus()
    else
        self.ensureVisible(self.uiElement)
    end
    if self.handleGainJoypadFocus then
        self.handleGainJoypadFocus(self.uiElement, joypadData)
    end
    if self.processRealEvents then
        self.og_onGainJoypadFocus(self.uiElement, joypadData)
    end
end

function NotlocControllerNode:focusContextMenu(playerNum, menu)
    NotlocControllerNode.menuFocusSupression[playerNum] = true -- Prevent the controller nodes from acting like they lost focus
    local origin = getJoypadFocus(playerNum)
    menu.origin = origin
    menu.mouseOver = 1
    setJoypadFocus(playerNum, menu)
end

function NotlocControllerNode.ensureVisible(uiElement)
    local current = uiElement.parent
    while current do
        if current.Type == "NotlocScrollView" then
            current:ensureChildIsVisible(uiElement, 50)
            return
        end
        current = current.parent
    end
end

