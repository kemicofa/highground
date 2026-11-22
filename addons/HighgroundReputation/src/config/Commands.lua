local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
C.Register("reputation", "Reputation", {
  C.Link("reputation", "Reports, moderation and chat filtering for guilds and communities.", "reputation", "Open player reputation"),
  C.Action("reputation communities", "Open the organization directory and account enable/disable controls.", "Open organizations", { aliases = { "reputation organizations" } }),
  C.Action("reputation manage", "Open Blizzard's Guild & Communities UI.", "Manage native organizations"),
  C.Action("reputation report", "Open a report for your target or a full player name.", "Prepare player report", { usage = "[target|NAME]",
    fields = { { label = "Player name or target", default = "target" } } }),
  C.Action("reputation sync", "Request updates from online native moderators.", "Request reputation updates"),
  C.Action("reputation status", "Print the selected organization's sharing status.", "Show sharing status"),
  C.Link("reputation on", "Enable or disable reputation chat filtering.", "reputation-settings", "Chat filtering switch", { aliases = { "reputation off" } }),
  C.Action("reputation help", "Print Reputation command help.", "Print Reputation help"),
})
