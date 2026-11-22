local t = dofile("../../tools/harness.lua")("guide localization")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local function click(button) button.scripts.OnClick(button) end
local function hover(frame)
  for _, hook in ipairs(frame.hooks.OnEnter or {}) do hook(frame) end
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
  t.test(client .. " guide messages resolve after saved locale and preserve command syntax", function()
    local s = new(client == "cata" and "cata" or "retail", { locale = "frFR" }, function(sim, env)
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "", "", 16001 end end
      dofile("../../tools/wowsim/geometry.lua")(sim)
    end)
    local ns, O, L = s.ns, s.ns.Onboarding, s.ns.Locale
    local function Registered(messages)
      for _, key in pairs(messages or {}) do assert(L.catalogs.enUS[key], "missing guide message: " .. key) end
    end
    for _, step in ipairs(O.steps) do
      Registered(step.messages)
      for _, action in ipairs(step.actions or {}) do Registered(action.messages) end
    end
    for _, row in ipairs(ns.CommandCatalog.commands) do
      Registered({ description = row.descriptionKey, label = row.labelKey })
    end
    -- Test-only translations exercise long text and reordered placeholders.
    local label = "A longer translated enemy targeting walkthrough"
    assert(L:Register("frFR", {
      ["guide.enemies.label"] = label, ["guide.enemies.caption"] = "Translated targeting",
      ["guide.battlegrounds.title"] = "TRANSLATED BATTLEGROUND GUIDES",
      ["guide.caption"] = "{step} / {total}: {guide}",
      ["commands.guide.enemies.description"] = "Translated command explanation",
      ["commands.guide.enemies.action"] = "Translated targeting action",
    }))
    ns.Core.SetFontScale(1.5)
    s:command("guide battlegrounds")
    t.equal(O.win.title:GetText(), "TRANSLATED BATTLEGROUND GUIDES", "saved locale reaches the chooser")
    t.equal(O.win.cards.enemies.name:GetText(), label, "late-built labels use saved language")
    t.equal(O.win.cards.objectives.name:GetText(), "Objectives & flag carriers", "missing translations use English")
    local card = O.win.cards.enemies
    local name, summary, button = s.bounds(card.name), s.bounds(card.summary), s.bounds(card.start)
    assert(name[2] + name[4] <= summary[2] and summary[2] + summary[4] <= button[2], "long translated copy stays above actions")
    hover(card.start)
    assert(table.concat(s.env.GameTooltip.lines, "\n"):find(label, 1, true), "tooltip resolves translated label")
    click(card.start)
    local C = O.Coach
    t.equal(C.key, "enemies", "guide state keys remain stable")
    t.equal(C.win.caption:GetText(), "1 / " .. #C.steps .. ": Translated targeting", "caption arguments may reorder")
    O.Return()
    ns.Localization.SetPreference("enUS")
    t.equal(card.name:GetText(), "Enemy rows & targeting", "existing labels update through the shared binding")
    ns.Localization.SetPreference("frFR")
    ns.Hub.Open("battlegrounds-commands")
    local item
    for _, row in ipairs(ns.Options.byKey["battlegrounds-commands"].commandRows) do
      if row.definition.command == "guide enemies" then item = row; break end
    end
    t.equal(item.code:GetText(), "/hg guide enemies", "syntax is never translated")
    t.equal(item.description:GetText(), "Translated command explanation", "catalog display is resolved after initialization")
    hover(item.button)
    assert(table.concat(s.env.GameTooltip.lines, "\n"):find("Translated targeting action", 1, true))
    ns.Localization.SetPreference("enUS")
    t.equal(item.description:GetText(), "Learn enemy rows, target markers and status labels.", "built command rows follow language changes")
    ns.Localization.SetPreference("frFR")
    local messages = {}; ns.Commands.help(nil, nil, function(message) messages[#messages + 1] = message end)
    assert(table.concat(messages, "\n"):find("Translated command explanation", 1, true), "chat help uses the same catalog lookup")
    click(item.button); t.equal(C.key, "enemies", "translated catalog action retains its command"); O.Return()
    t.equal(ns.Core.db.locale, "frFR", "guide does not change language preference")
    t.equal(#s.sent, 0, "localized guides do not send sample messages")
    s:assertHealthy()
  end)
end
t.finish()
