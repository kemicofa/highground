local _, ns = ...

---------------------------------------------------------------------------
-- What Highground's core gives the bounty files, for Highground Bounties:
-- the command table commands/Bounty.lua fills, the command named in chat
-- lines (/hgb), the chat label and the key binding header (Bindings.xml).
---------------------------------------------------------------------------
ns.Commands = {}
ns.BOUNTY_CMD = "/hgb"

-- The label already says "Bounties": no extra "bounty" before bounty lines.
ns.Util.SAY_KINDS.bounty.label = ns.LABEL

BINDING_HEADER_HIGHGROUNDBOUNTIES = ns.LABEL

-- Settings page lines (config/Options.lua) that name Highground's pages,
-- commands or other features.
local DESC = {
  bounty = "Personal and guild bounties: sound and alert when a bounty target shows up, anywhere. Bounty board: /hgb",
  bountyMarks = "Gold coin beside a bounty target's nameplate and a gold frame on their nearby-enemies row",
  nearby = "Open-world list of hostile players you have seen, most recent first",
  sound = "Every sound of this addon: bounty and nearby-enemy alerts",
}
for _, def in ipairs(ns.OptionsConfig.features) do
  if DESC[def.key] then def.desc = DESC[def.key] end
end
