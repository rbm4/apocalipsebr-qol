CHBCommonUnit = {}
CHBCommonUnit.textureCache = {}
CHBCommonUnit.isLoaded = false
CHBCommonUnit.DEFAULT_SCALE_FACTOR = 0.65

function CHBCommonUnit.loadTextures()
    if CHBCommonUnit.isLoaded then return end
    
    for i = 0, 9 do
        CHBCommonUnit.textureCache[tostring(i)] = getTexture("media/ui/CleanHotBar/normal_numbers/" .. i .. ".png")
    end

    CHBCommonUnit.textureCache["/"] = getTexture("media/ui/CleanHotBar/normal_numbers/slash.png")
    CHBCommonUnit.textureCache[":"] = getTexture("media/ui/CleanHotBar/normal_numbers/colon.png")
    CHBCommonUnit.textureCache["A"] = getTexture("media/ui/CleanHotBar/normal_numbers/A.png")
    CHBCommonUnit.textureCache["L"] = getTexture("media/ui/CleanHotBar/normal_numbers/L.png")
    
    CHBCommonUnit.isLoaded = true
end

-- Get Size
function CHBCommonUnit.getTextureSize()
    if not CHBCommonUnit.isLoaded then
        CHBCommonUnit.loadTextures()
    end
    if CHBCommonUnit.textureCache["8"] then
        return CHBCommonUnit.textureCache["8"]:getWidth(), CHBCommonUnit.textureCache["8"]:getHeight()
    end
    
    return 17, 25
end

-- Measure TextWidth
function CHBCommonUnit.measureTextWidth(text, scale)
    if not CHBCommonUnit.isLoaded then
        CHBCommonUnit.loadTextures()
    end
    
    scale = (scale or 1.0) * CHBCommonUnit.DEFAULT_SCALE_FACTOR
    local baseWidth, _ = CHBCommonUnit.getTextureSize()
    local totalWidth = 0
    
    for i = 1, #text do
        local char = string.sub(text, i, i)
        
        if CHBCommonUnit.textureCache[char] then
            totalWidth = totalWidth + (baseWidth * scale)
        else
            totalWidth = totalWidth + getTextManager():MeasureStringX(UIFont.Small, char)
        end
    end
    
    return totalWidth
end

-- Render Text
function CHBCommonUnit.renderText(panel, text, x, y, scale, alpha, r, g, b)
    if not CHBCommonUnit.isLoaded then
        CHBCommonUnit.loadTextures()
    end
    
    scale = (scale or 1.0) * CHBCommonUnit.DEFAULT_SCALE_FACTOR
    alpha = alpha or 1.0
    r = r or 1.0
    g = g or 1.0
    b = b or 1.0
    
    local baseWidth, baseHeight = CHBCommonUnit.getTextureSize()
    local scaledWidth = baseWidth * scale
    local scaledHeight = baseHeight * scale
    local currentX = x
    
    for i = 1, #text do
        local char = string.sub(text, i, i)
        
        if CHBCommonUnit.textureCache[char] then
            panel:drawTextureScaled(
                CHBCommonUnit.textureCache[char], 
                currentX, 
                y, 
                scaledWidth, 
                scaledHeight, 
                alpha, r, g, b
            )
            currentX = currentX + scaledWidth
        end
    end
    
    return currentX - x
end

-- Draw 3-Patch
function CHBCommonUnit.drawThreeSliceBar(panel, x, y, width, barHeight, leftTexture, middleTexture, rightTexture, alpha, r, g, b)
    if not leftTexture or not middleTexture or not rightTexture then return end

    x = math.floor(x)
    y = math.floor(y)
    width = math.floor(width)
    barHeight = math.floor(barHeight)
    
    local leftOriginalWidth = leftTexture:getWidth()
    local leftOriginalHeight = leftTexture:getHeight()
    local rightOriginalWidth = rightTexture:getWidth()
    local rightOriginalHeight = rightTexture:getHeight()
    
    local heightRatio = barHeight / leftOriginalHeight
    local leftActualWidth = math.floor(leftOriginalWidth * heightRatio)
    
    heightRatio = barHeight / rightOriginalHeight
    local rightActualWidth = math.floor(rightOriginalWidth * heightRatio)
    
    local minSidesWidth = leftActualWidth + rightActualWidth
    
    if width <= minSidesWidth then
        local leftRatio = leftActualWidth / minSidesWidth
        leftActualWidth = math.floor(width * leftRatio)
        rightActualWidth = width - leftActualWidth
        
        panel:drawTextureScaled(leftTexture, x, y, leftActualWidth, barHeight, alpha, r, g, b)
        panel:drawTextureScaled(rightTexture, x + leftActualWidth, y, rightActualWidth, barHeight, alpha, r, g, b)
    else
        local middleWidth = width - leftActualWidth - rightActualWidth
        
        panel:drawTextureScaled(leftTexture, x, y, leftActualWidth, barHeight, alpha, r, g, b)
        panel:drawTextureScaled(middleTexture, x + leftActualWidth, y, middleWidth, barHeight, alpha, r, g, b)
        panel:drawTextureScaled(rightTexture, x + leftActualWidth + middleWidth, y, rightActualWidth, barHeight, alpha, r, g, b)
    end
end

-- Draw 3-Patch Fill
function CHBCommonUnit.drawThreeSliceBarFill(panel, x, y, width, barHeight, fillRatio, leftTexture, middleTexture, rightTexture, alpha, r, g, b)
    if not leftTexture or not middleTexture or not rightTexture then return end

    x = math.floor(x)
    y = math.floor(y)
    width = math.floor(width)
    barHeight = math.floor(barHeight)
    
    local leftWidth = leftTexture:getWidth()
    local leftHeight = leftTexture:getHeight()
    local rightWidth = rightTexture:getWidth()
    local rightHeight = rightTexture:getHeight()
    
    local leftActualHeight = barHeight
    local rightActualHeight = barHeight
    
    local leftActualWidth = math.floor((leftWidth / leftHeight) * leftActualHeight)
    local rightActualWidth = math.floor((rightWidth / rightHeight) * rightActualHeight)
    
    local fillWidth = math.floor(width * fillRatio)
    if fillWidth < 1 then return end
    
    if width < (leftActualWidth + rightActualWidth) then
        panel:setStencilRect(x, y, fillWidth, barHeight)
        panel:drawTextureScaled(middleTexture, x, y, width, barHeight, alpha, r, g, b)
        panel:clearStencilRect()
        return
    end
    
    panel:setStencilRect(x, y, fillWidth, barHeight)
    
    panel:drawTextureScaledAspect(leftTexture, x, y, leftActualWidth, leftActualHeight, alpha, r, g, b)
    
    local middleWidth = width - leftActualWidth - rightActualWidth
    
    if middleWidth > 0 then
        panel:drawTextureScaled(middleTexture, x + leftActualWidth, y, middleWidth, barHeight, alpha, r, g, b)
    end
    
    panel:drawTextureScaledAspect(rightTexture, x + leftActualWidth + middleWidth, y, rightActualWidth, rightActualHeight, alpha, r, g, b)
    
    panel:clearStencilRect()
end

return CHBCommonUnit