require "ISUI/ISUIElement"

NotlocScrollView = ISUIElement:derive("NotlocScrollView");

function NotlocScrollView:new(x, y, w, h)
	local o = {};
	o = ISUIElement:new(x, y, w, h);
	setmetatable(o, self);
    self.__index = self;

    o:setAnchorLeft(true);
    o:setAnchorRight(true);
    o:setAnchorTop(true);
    o:setAnchorBottom(true);

    o.scrollChildren = {};
    o.lastX = 0;
    o.lastY = 0;

    o.scrollSensitivity = 12;

    return o;
end

function NotlocScrollView:createChildren()
    ISUIElement.createChildren(self);
    self:addScrollBars(self.addHorizontalScrollbar);
end

function NotlocScrollView:addScrollChild(child)
    self:addChild(child);
    table.insert(self.scrollChildren, child);

    child.keepOnScreen = false

    local x = self:getXScroll()
    local y = self:getYScroll()
    child:setX(child:getX() + x)
    child:setY(child:getY() + y)

    self:sendScrollbarsToFront()
end

function NotlocScrollView:removeScrollChild(child)
    self:removeChild(child);
    for i, v in ipairs(self.scrollChildren) do
        if v == child then
            table.remove(self.scrollChildren, i);
            return
        end
    end
end

function NotlocScrollView:sendScrollbarsToFront()
    if self.hscroll then
        self.hscroll:bringToTop();
    end

    if self.vscroll then
        self.vscroll:bringToTop();
    end
end

function NotlocScrollView:isChildVisible(child)
    local childY = child:getY()
    local childH = child:getHeight()
    local selfH = self:getHeight()
    return childY + childH > 0 and childY < selfH
end

function NotlocScrollView:prerender()
    self:setStencilRect(0, 0, self.width, self.height);
    self:updateScrollbars();

    self:updateScroll();

	ISUIElement.prerender(self)
end

function NotlocScrollView:render()
    ISUIElement.render(self);
    self:clearStencilRect();
end

function NotlocScrollView:onMouseWheel(del)
    -- if the ctrl key is held down, scroll horizontally
    if isCtrlKeyDown() then
        self:setXScroll(self:getXScroll() - (del * self.scrollSensitivity));
        return true;
    end
	self:setYScroll(self:getYScroll() - (del * self.scrollSensitivity));
    return true;
end

function NotlocScrollView:updateScroll()
    local xScroll = self:getXScroll()
    local yScroll = self:getYScroll()

    local scrollAreaWidth = self:getScrollAreaWidth()

    if scrollAreaWidth - self.scrollwidth > xScroll then
        xScroll = math.min(0, scrollAreaWidth - self.scrollwidth)
        self:setXScroll(xScroll)
    end

    local deltaX = xScroll - self.lastX
    local deltaY = yScroll - self.lastY
    for _, child in pairs(self.scrollChildren) do
        child:setX(child:getX() + deltaX)
        child:setY(child:getY() + deltaY)
    end

    self.lastX = xScroll
    self.lastY = yScroll
end

function NotlocScrollView:resetScroll()
    self:setXScroll(0);
    self:setYScroll(0);
    self:updateScroll();
end

-- TODO: Rename this to scroll to screen position, change child to the screen Y position
function NotlocScrollView:ensureChildIsVisible(child, padding)
    padding = padding or 50

    local childYTop = child:getAbsoluteY()
    childYTop = childYTop - self:getAbsoluteY()

    local scrollY = self:getYScroll()

    local delta = childYTop - padding
    local newScroll = scrollY - delta
    if newScroll > 0 then
        newScroll = 0
    end
    self:setYScroll(newScroll)
end