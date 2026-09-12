
local MODULE = "IABLN"
local COMMAND = "syncAnimationState"
local WRAPS_TYPE = "IAmBruceLeeNow.MartialArtsHandWraps"
local HANDS_LOCATION = ItemBodyLocation.get(ResourceLocation.of("base:hands"))
-- Keep animation traffic local to the area where another player could render
-- the attacker. This is intentionally larger than ordinary visual range so a
-- recipient receives state before the attacker appears on screen.
local RELEVANCE_DISTANCE = 100
local RELEVANCE_DISTANCE_SQUARED = RELEVANCE_DISTANCE * RELEVANCE_DISTANCE

local function isWearingHandWraps(player)
    local wraps = player and player:getWornItem(HANDS_LOCATION) or nil
    return wraps and wraps:getFullType() == WRAPS_TYPE
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or not player or not args then
        return
    end

    if command ~= COMMAND then return end

    local combo = tonumber(args.combo) or 0
    local active = args.active == true
    if combo < 0 or combo > 6 or combo ~= math.floor(combo) then return end
    if active and (combo == 0 or not isWearingHandWraps(player)) then return end

    -- The server supplies the identity; clients cannot impersonate another
    -- player by putting an arbitrary online ID in their packet.
    local relay = {
        onlineID = player:getOnlineID(),
        active = active,
        combo = active and combo or 0,
        left = active and args.left == true,
        attacking = active and args.attacking == true,
    }

    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local recipient = players:get(index)
        if recipient and recipient:getOnlineID() ~= player:getOnlineID() then
            local dx = recipient:getX() - player:getX()
            local dy = recipient:getY() - player:getY()
            if dx * dx + dy * dy <= RELEVANCE_DISTANCE_SQUARED then
                sendServerCommand(recipient, MODULE, COMMAND, relay)
            end
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
