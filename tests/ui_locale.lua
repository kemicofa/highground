-- Kit labels follow a language change, exercised through every retained host
-- manifest by ui_components.lua.
return function(s, t, fire)
  local K, env, L, Localization = s.ns.Kit, s.env, s.ns.Locale, s.ns.Localization
  local BACK, CLOSE, REFRESH, EMPTY = "highground.coachview.back.b52b36", "highground.profilereview.close.bbfa77",
    "shared.board.refresh.56e3ba", "shared.state.no_entries_yet.db0eca"

  t.test("tabs, segments, confirmations, badges and empty states relabel after a language change", function()
    local previous = Localization.preference or "enUS"
    Localization.SetPreference("enUS")
    local declared = Localization.Define({ key = "declared", label = L:Get(CLOSE) }, { label = CLOSE })
    local group = K.TabGroup(env.UIParent, { width = 800, items = { declared,
      { key = "descriptor", label = { key = BACK } }, { key = "fn", label = function() return L:Get(REFRESH) end },
      { key = "literal", label = "Fixed" } } })
    local tab = K.Tab(env.UIParent, { key = BACK })
    local seg = K.Segmented(env.UIParent, { choices = { { key = "a", label = { key = BACK }, tooltip = { key = CLOSE } },
      { key = "b", label = function() return L:Get(REFRESH) end } } })
    local confirm = K.ConfirmButton(env.UIParent, { key = REFRESH }, { confirm = { key = CLOSE } })
    local badge = K.Badge(env.UIParent, { key = CLOSE }, "pending")
    local empty = K.EmptyState(env.UIParent, { title = { key = CLOSE }, message = { key = EMPTY }, action = { key = REFRESH } })
    empty:Layout(300)
    t.equal(group.buttons.descriptor.label:GetText(), "Back", "English descriptor label")
    fire(confirm, "OnClick"); t.equal(confirm.text, "Close", "armed English label")
    local englishWidth = group.buttons.declared.tabWidth
    Localization.SetPreference("deDE")
    t.equal(group.buttons.declared.label:GetText(), L:Get(CLOSE), "declared display tables relabel")
    t.equal(group.buttons.descriptor.label:GetText(), L:Get(BACK), "message descriptors relabel")
    t.equal(group.buttons.fn.label:GetText(), L:Get(REFRESH), "function labels relabel")
    t.equal(group.buttons.literal.label:GetText(), "Fixed", "literal labels stay")
    assert(group.buttons.declared.tabWidth ~= englishWidth, "the strip refits translated labels")
    t.equal(tab.label:GetText(), L:Get(BACK), "single tabs relabel")
    t.equal(seg.byKey.a.label:GetText(), L:Get(BACK), "segments relabel")
    t.equal(seg.byKey.b.label:GetText(), L:Get(REFRESH), "function segments relabel")
    fire(seg.byKey.a, "OnEnter")
    t.equal(env.GameTooltip.lines[2], L:Get(CLOSE), "segment tooltips read the current language")
    fire(seg.byKey.a, "OnLeave")
    t.equal(confirm.text, L:Get(CLOSE), "an armed confirmation keeps its confirm label")
    confirm:Disarm(); t.equal(confirm.text, L:Get(REFRESH), "and rests on the translated label")
    t.equal(badge.label:GetText(), L:Get(CLOSE), "badges relabel")
    t.equal(empty.title:GetText(), L:Get(CLOSE), "empty-state titles relabel")
    t.equal(empty.message:GetText(), L:Get(EMPTY), "empty-state messages relabel")
    t.equal(empty.button.text, L:Get(REFRESH), "empty-state actions relabel")
    assert(L:Get(BACK) ~= "Back" and L:Get(CLOSE) ~= "Close", "the German catalog supplies these labels")
    Localization.SetPreference(previous)
    t.equal(group.buttons.descriptor.label:GetText(), L:Get(BACK), "switching back relabels again")
    for _, frame in ipairs({ group, tab, seg, confirm, badge, empty }) do frame:Hide() end
  end)
end
