if isClient() then return end

require "BrushToolSaveFix/BTSF_Shared"

local MODULE = BrushToolSaveFix.MODULE

local function onClientCommand(module, command, player, args)
    if module ~= MODULE then
        return
    end

    if not BrushToolSaveFix.canUseBrush(player) then
        BrushToolSaveFix.log("denied " .. tostring(command) .. " from " .. tostring(player and player:getUsername()))
        return
    end

    if type(args) ~= "table" then
        return
    end

    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z)
    if not x or not y or not z then
        return
    end

    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    local square = BrushToolSaveFix.getOrCreateSquare(x, y, z)
    if not square then
        BrushToolSaveFix.log("no square for " .. x .. "," .. y .. "," .. z)
        return
    end

    if command == "placeTile" then
        local sprite = args.sprite
        if type(sprite) ~= "string" or sprite == "" then
            return
        end
        local ok = BrushToolSaveFix.placeTileOnSquare(square, sprite)
        BrushToolSaveFix.log((ok and "placed " or "skipped ") .. sprite .. " @ " .. x .. "," .. y .. "," .. z)
        return
    end

    if command == "destroyTile" then
        local sprite = args.sprite
        local index = tonumber(args.index)
        local ok = BrushToolSaveFix.destroyTileOnSquare(square, sprite, index)
        BrushToolSaveFix.log((ok and "destroyed " or "missed ") .. tostring(sprite) .. " @ " .. x .. "," .. y .. "," .. z)
        return
    end
end

Events.OnClientCommand.Add(onClientCommand)
