local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
C.Register("arena", "Arena", {
  C.Action("arena", "Show Arena and duel panel status in chat.", "Show Arena status"),
  C.Link("arena on", "Enable or disable the Arena and duel panel.", "arena-settings", "Arena panel switch", { aliases = { "arena off" } }),
  C.Link("arena test", "Start or stop a sample opponent panel; Forever shows one duelist.", "arena-previews", "Arena preview controls"),
}, {
  { cmd = "arena test", label = "Arena & duels", desc = "Preview opponents; Forever shows one duelist" },
})
