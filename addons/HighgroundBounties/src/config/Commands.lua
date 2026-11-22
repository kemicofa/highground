local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
local A, L = C.Action, C.Link
local function Name() return { { label = "Player name or target", default = "target" } } end
C.Register("bounties", "Bounties", {
  L("bounty", "Open or close the bounty board.", "bountyboard", "Open bounty board", { aliases = { "bounty board" } }),
  A("bounty shared", "Open shared realm/faction bounties.", "Open shared bounties", { aliases = { "bounty shared board" } }),
  L("bounty add", "Create a personal bounty, optionally with gold and a note.", "bountyboard", "Create a bounty", { usage = "[GOLD] NAME [; note]" }),
  L("bounty shared add", "Publish a shared pledge with an expiry and optional note; publishing must be enabled.", "bountyboard", "Create a shared bounty", { usage = "GOLD DURATION NAME [; note]" }),
  L("bounty shared receive", "Enable or disable receiving shared bounties.", "bounty", "Shared bounty receiving", { usage = "on|off" }),
  L("bounty shared publish", "Enable or disable publishing shared bounties.", "bounty", "Shared bounty publishing", { usage = "on|off" }),
  L("bounty shared threshold", "Set the minimum shared bounty gold value for alerts.", "bounty", "Shared bounty alert threshold", { usage = "GOLD" }),
  A("bounty share", "Prepare a bounty chat link; review it before sending.", "Prepare bounty share", { usage = "NAME", fields = Name() }),
  A("bounty export", "Prepare a bounty code and post to copy outside the game.", "Export a bounty", { usage = "NAME", fields = Name() }),
  A("bounty import", "Review a bounty link, code or complete post before importing.", "Import a bounty", { usage = "[CODE]" }),
  A("bounty submit", "Submit a personal bounty to your guild.", "Submit bounty to guild", { usage = "NAME", fields = Name() }),
  A("bounty remove", "Remove a bounty you can manage.", "Remove a bounty", { usage = "NAME", fields = Name(), confirm = "Remove this bounty?" }),
  A("bounty claim", "Report a bounty kill for review.", "Report bounty kill", { usage = "NAME", fields = Name() }),
  A("bounty approve", "Officers: approve a pending bounty submission.", "Approve bounty submission", { usage = "NAME", fields = Name() }),
  A("bounty reject", "Officers: reject a pending bounty submission.", "Reject bounty submission", { usage = "NAME", fields = Name(), confirm = "Reject this bounty submission?" }),
  A("bounty shared claim", "Report a shared bounty kill.", "Report shared bounty kill", { usage = "NAME", fields = Name() }),
  A("bounty shared withdraw", "Withdraw your shared bounty contribution.", "Withdraw shared contribution", { usage = "NAME", fields = Name(), confirm = "Withdraw your shared contribution?" }),
  A("bounty claims", "Review kill claims and record approval or manual payment.", "Review claims and payments", { aliases = { "bounty shared claims" } }),
  A("bounty gold", "Inspect account gold and funding settings.", "Open gold and funding"),
  A("bounty suggestions", "Review attackers, death reports and bounty drafts.", "Open bounty suggestions"),
  L("bounty test", "Start a named sample scene or stop all bounty previews.", "bounties-previews", "Bounty preview controls", { usage = "[FEATURE|stop]" }),
  A("bounty guide", "Open a sample chapter of the bounty feature tour, or stop it.", "Choose bounty sample chapter", { usage = "[CHAPTER|stop]",
    fields = { { label = "Chapter", choices = function()
      local choices = { { key = "stop", label = "Stop bounty tour" } }
      for _, scene in ipairs(ns.Bounty.Preview.scenes) do choices[#choices + 1] = { key = scene.key, label = scene.label } end
      return choices
    end } } }),
  A("guide bounties", "Choose the posting or hunting guide, each with its own saved place.", "Choose bounty guide"),
  A("guide bounty_post", "Start or resume posting and claim review lessons.", "Start posting guide"),
  A("guide bounty_hunt", "Start or resume hunting and claiming lessons.", "Start hunting guide"),
  A("bounty list", "Print current bounties in chat.", "Print bounty list"),
  A("bounty sync", "Request current guild bounties.", "Request guild bounties"),
  A("bounty shared sync", "Request shared realm/faction bounties.", "Request shared bounties"),
  L("bounty on", "Enable or disable bounty alerts.", "bounty", "Bounty alert switch", { aliases = { "bounty off" } }),
}, {
  { cmd = "bounty test", label = "Wanted poster", desc = "Toggle a live-style bounty sighting with sample data" },
  { kind = "open", cmd = "bounty", label = "Bounty board", desc = "Open or close the bounty board" },
})
