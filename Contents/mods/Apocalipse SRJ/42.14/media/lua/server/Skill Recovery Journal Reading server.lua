-- ============================================================================
-- Server-side handler for Skill Recovery Journal XP grants (42.14+)
-- In 42.14, addXpNoMultiplier only works server-side in multiplayer.
-- The client sends "addXp" commands here for the server to execute.
-- ============================================================================

local SRJ = require "Skill Recovery Journal Main"

local function isFinite(value)
    value = tonumber(value)
    return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge
end

local function syncBeyondTenPerk(player, BT, perk)
    if not player or not BT or not perk then return end
    if type(sendServerCommand) ~= "function" or type(BT.GetStoredXP) ~= "function" then return end

    sendServerCommand(player, BT.MODULE or "BeyondTen", "SyncPerk", {
        player = player:getOnlineID(),
        perk = perk:getId(),
        xp = BT.GetStoredXP(player, perk),
    })
end

local function SRJ_OnClientCommand(module, command, player, args)
    if module ~= "SkillRecoveryJournal" then return end

    if command == "addXp" then
        if player and args and args.perkID and args.amount then
            local perk = Perks[args.perkID]
            if perk then
                addXpNoMultiplier(player, perk, args.amount+1)
            end
        end
    elseif command == "addBeyondTenXp" then
        if not player or not args or not args.perkID or not isFinite(args.amount) then return end
        if player:isDead() then return end

        local BT = SRJ.getBeyondTen()
        local perk = Perks[args.perkID]
        if not SRJ.isBeyondTenPerkValid(BT, perk) then return end

        local amount = math.max(0, tonumber(args.amount) or 0)
        if amount <= 0 then return end

        if type(BT.AddRecoveredXP) == "function" then
            BT.AddRecoveredXP(player, perk, amount)
            syncBeyondTenPerk(player, BT, perk)
        end
    end
end

Events.OnClientCommand.Add(SRJ_OnClientCommand)
