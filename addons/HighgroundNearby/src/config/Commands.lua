local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
C.Register("nearby", "Nearby", {
  C.Action("nearby", "Show the nearby enemy list status and remembered count.", "Show Nearby status"),
  C.Link("nearby on", "Enable or disable the nearby enemy list.", "nearby", "Nearby list switch", { aliases = { "nearby off" } }),
  C.Link("nearby test", "Start or stop the nearby enemy sample list.", "nearby-previews", "Nearby preview controls"),
  C.Action("nearby clear", "Clear current nearby sightings.", "Clear nearby sightings", { confirm = "Clear current nearby sightings?" }),
  C.Action("nearby forget", "Forget saved enemy encounter history.", "Forget enemy history", { confirm = "Forget all saved enemy encounter history?" }),
  C.Link("journal", "Search encounters, write notes, mute alerts or place a bounty.", "journal", "Open enemy journal"),
}, {
  { cmd = "nearby test", label = "Nearby enemies", desc = "Open-world enemy list" },
})
