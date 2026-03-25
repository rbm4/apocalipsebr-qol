-- ============================================================================
-- Server-side handler for Skill Recovery Journal XP grants (42.14+)
-- In 42.14, addXpNoMultiplier only works server-side in multiplayer.
-- The client sends "addXp" commands here for the server to execute.
-- ============================================================================

local function SRJ_OnClientCommand(module, command, player, args)
    if module ~= "SkillRecoveryJournal" then return end

    if command == "addXp" then
        if player and args and args.perkID and args.amount then
            local perk = Perks[args.perkID]
            if perk then
                addXpNoMultiplier(player, perk, args.amount)
            end
        end
    end
end

Events.OnClientCommand.Add(SRJ_OnClientCommand)
