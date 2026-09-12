local function setOption(option, value)
    option:setValue(value)
    option:setDefaultToCurrentValue()
end

local options = DebugOptions.instance

setOption(options.worldChunkMap5x5, false)
setOption(options.worldChunkMap7x7, false)
setOption(options.worldChunkMap9x9, false)
setOption(options.worldChunkMap11x11, false)
setOption(options.worldChunkMap13x13, true)