local _, ns = ...

---------------------------------------------------------------------------
-- What Highground's core gives the bounty files, for Highground Bounties:
-- the command table libs/bounty/Commands.lua fills, the command named in chat
-- lines (/hgb), the chat label and the key binding header (Bindings.xml).
---------------------------------------------------------------------------
ns.Commands = {}
ns.BOUNTY_CMD = "/hgb"

-- The label already says "Bounties": no extra "bounty" before bounty lines.
ns.Util.SAY_KINDS.bounty.label = ns.LABEL

BINDING_HEADER_HIGHGROUNDBOUNTIES = ns.LABEL

-- Settings page lines (config/Options.lua) that name Highground's pages,
-- commands or other features.
local DESC = ns.Localization.Define({
  bounty = ns.Locale:Get("bounties.host.personal_guild_community_and_shared_bounties_sound.0032f7"),
  bountyMarks = ns.Locale:Get("bounties.host.gold_coin_beside_a_bounty_target_s.8e4766"),
  nearby = ns.Locale:Get("bounties.host.open_world_list_of_hostile_players_you.6e4b99"),
  sound = ns.Locale:Get("bounties.host.every_sound_of_this_addon_bounty_and.7581c3"),
}, { bounty = "bounties.host.personal_guild_community_and_shared_bounties_sound.0032f7", bountyMarks = "bounties.host.gold_coin_beside_a_bounty_target_s.8e4766", nearby = "bounties.host.open_world_list_of_hostile_players_you.6e4b99", sound = "bounties.host.every_sound_of_this_addon_bounty_and.7581c3" })
for _, def in ipairs(ns.OptionsConfig.features) do
  if DESC[def.key] then ns.Localization.Define(def, { desc = ns.Localization.Key(DESC, def.key) }) end
end
