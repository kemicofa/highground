-- Shared building blocks, exercised through every retained host manifest
-- by ui_components.lua.
return function(s, t, fire)
  local K, env = s.ns.Kit, s.env
  local tip = env.GameTooltip

  t.test("tooltips replace their content without stacking hooks and close with their owner", function()
    local button = K.Button(env.UIParent, "Apply", 120, 24)
    local function Count(event) return #(button.hooks[event] or {}) end
    local enter, leave, hide = Count("OnEnter"), Count("OnLeave"), Count("OnHide")
    K.Tooltip(button, { "First", "Old detail" })
    for i = 1, 20 do K.Tooltip(button, { "Refreshed " .. i, "New detail" }) end
    t.equal(Count("OnEnter") - enter, 1, "repeated tooltip setup keeps one hover hook")
    t.equal(Count("OnLeave") - leave, 1, "one leave hook")
    t.equal(Count("OnHide") - hide, 1, "one hide hook")
    fire(button, "OnEnter")
    t.equal(tip.lines[1], "Refreshed 20", "the latest content wins")
    t.equal(#tip.lines, 2, "earlier content is not appended")
    fire(button, "OnLeave"); assert(not tip:IsShown(), "leaving closes the tooltip")

    local other = K.Button(env.UIParent, "Other", 120, 24)
    K.Tooltip(other, function() return { "Other owner" } end)
    fire(button, "OnEnter"); fire(other, "OnEnter")
    fire(button, "OnLeave")
    assert(tip:IsShown() and tip:GetOwner() == other, "leaving one control keeps another owner's tooltip")
    fire(other, "OnLeave")

    fire(button, "OnEnter"); button:Hide()
    assert(not tip:IsShown(), "hiding the owner closes its tooltip")
    button:Show()
    K.Tooltip(button, function() return nil end)
    fire(other, "OnEnter"); fire(button, "OnEnter")
    assert(tip:IsShown() and tip:GetOwner() == other, "empty content shows nothing and keeps the current tooltip")
    fire(other, "OnLeave"); button:Hide(); other:Hide()
  end)

  local function Writes(regions)
    local count = { n = 0 }
    for _, region in ipairs(regions) do
      for _, method in ipairs({ "ClearAllPoints", "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetShown" }) do
        local native = region[method]
        if native then region[method] = function(...) count.n = count.n + 1; return native(...) end end
      end
    end
    return count
  end

  t.test("toolbars fit labels, wrap in reading order and reuse geometry", function()
    local host = env.CreateFrame("Frame", nil, env.UIParent)
    host:SetPoint("TOPLEFT"); host:SetSize(600, 200)
    local bar = K.Toolbar(host)
    bar:SetPoint("TOPLEFT")
    local short, long = bar:Add(K.Button(bar, "Import")), bar:Add(K.Button(bar, "Share profile in chat"))
    local hidden, last = bar:Add(K.Button(bar, "Hidden")), bar:Add(K.Button(bar, "Delete"))
    hidden:Hide()
    local height = bar:Layout(600)
    t.equal(height, s.ns.Theme.Size("control"), "one row when everything fits")
    assert(short:GetWidth() < long:GetWidth(), "buttons size to their labels")
    assert(short.label:GetStringWidth() < short:GetWidth(), "labels fit inside their buttons")
    local a, b, c = s.bounds(short), s.bounds(long), s.bounds(last)
    assert(a[1] < b[1] and b[1] < c[1] and a[2] == c[2], "reading order on one line")
    t.close(c[1] - (b[1] + b[3]), s.ns.Theme.Space("md"), "hidden items leave no gap")
    local writes = Writes({ short, long, last, bar })
    for _ = 1, 20 do bar:Layout(600) end
    t.equal(writes.n, 0, "unchanged toolbars write no geometry")
    height = bar:Layout(200)
    assert(height > s.ns.Theme.Size("control") * 2, "narrow toolbars wrap onto more rows")
    assert(s.bounds(last)[2] > s.bounds(short)[2], "wrapped items follow reading order")
    for _, item in ipairs({ short, long, last }) do
      assert(s.bounds(item)[1] + s.bounds(item)[3] <= s.bounds(bar)[1] + 200 + 0.01, "items stay inside the width")
    end
    local right = K.Toolbar(host, { align = "RIGHT", items = { K.Button(host, "Cancel"), K.Button(host, "Save") } })
    right:SetPoint("TOPLEFT"); right:Layout(400)
    local save = s.bounds(right.items[2])
    t.close(save[1] + save[3], s.bounds(right)[1] + 400, "right-aligned rows end at the edge")
    s.ns.Core.SetFontScale(1.5)
    assert(bar:Layout(600) >= math.floor(s.ns.Theme.Size("control") * 1.5), "controls grow with text size")
    s.ns.Core.SetFontScale(1)
    host:Hide()
  end)

  t.test("confirm buttons arm once, confirm on the second click and reset on hide or disable", function()
    local confirmed, armed = 0, 0
    local b = K.ConfirmButton(env.UIParent, "Delete", { confirm = "Confirm delete",
      onArm = function() armed = armed + 1 end, onConfirm = function() confirmed = confirmed + 1 end })
    fire(b, "OnClick")
    assert(b:IsArmed() and b.text == "Confirm delete" and b.tone == "danger", "first click arms with a danger cue")
    t.equal(confirmed, 0, "arming never runs the action")
    fire(b, "OnClick")
    t.equal(confirmed, 1, "second click confirms")
    assert(not b:IsArmed() and b.text == "Delete" and b.tone == "surface", "confirming returns to rest")
    fire(b, "OnClick"); b:Hide(); b:Show()
    assert(not b:IsArmed(), "hiding forgets an armed confirmation")
    fire(b, "OnClick"); b:Disable()
    assert(not b:IsArmed() and not b:IsEnabled(), "disabling disarms")
    b:Arm(); assert(not b:IsArmed(), "disabled buttons cannot arm")
    b:Enable(); fire(b, "OnClick"); b:SetLabels("Remove", "Really remove")
    t.equal(b.text, "Really remove", "relabelling keeps the armed state")
    b:Disarm(); t.equal(b.text, "Remove", "new rest label")
    t.equal(armed, 4, "each arming notifies once")
    local timed = K.ConfirmButton(env.UIParent, "Clear", { confirm = "Confirm clear", timeout = 2 })
    fire(timed, "OnClick"); s:advance(1)
    assert(timed:IsArmed(), "still armed before the timeout")
    s:advance(1.5)
    assert(not timed:IsArmed(), "the timeout disarms")
    fire(timed, "OnClick"); s:advance(1.5); timed:Disarm(); fire(timed, "OnClick"); s:advance(0.8)
    assert(timed:IsArmed(), "an earlier timer cannot disarm a newer confirmation")
    b:Hide(); timed:Hide()
  end)

  t.test("segmented choices select one mode with a shape cue and confirm changes", function()
    local seen = {}
    local seg = K.Segmented(env.UIParent, { choices = { { key = "pvp", label = "PvP" }, { key = "pve", label = "PvE" } },
      onChange = function(_, key) seen[#seen + 1] = key end })
    seg:SetPoint("TOPLEFT")
    t.equal(seg:GetValue(), "pvp", "first choice by default")
    assert(seg.byKey.pvp.line:IsShown() and not seg.byKey.pve.line:IsShown(), "selected segment has an underline")
    fire(seg.byKey.pve, "OnClick")
    t.equal(seg:GetValue(), "pve", "clicks select"); t.equal(seen[1], "pve", "user changes notify")
    fire(seg.byKey.pve, "OnClick"); t.equal(#seen, 1, "reselecting does not notify")
    assert(not seg:SetValue("missing") and seg:GetValue() == "pve", "unknown keys are rejected")
    seg:SetValue("pvp", true); t.equal(#seen, 1, "silent updates do not notify")
    seg:SetEnabled("pve", false); assert(not seg.byKey.pve:IsEnabled(), "segments can be disabled")
    local height = seg:Layout(300)
    local first, second = s.bounds(seg.buttons[1]), s.bounds(seg.buttons[2])
    t.close(first[3], second[3], "equal segment widths"); t.equal(height, s.ns.Theme.Size("control"), "control height")
    local writes = Writes(seg.buttons)
    for _ = 1, 10 do seg:Layout(300) end
    t.equal(writes.n, 0, "unchanged segments write no geometry")
    seg:Hide()
  end)

  t.test("badges, labelled values, section cards and empty states fit their text", function()
    local T = s.ns.Theme
    local badge = K.Badge(env.UIParent, "Pending", "pending")
    local narrow = badge:GetWidth()
    badge:Set("Approved by a moderator", "success")
    assert(badge:GetWidth() > narrow and badge.label.textColor[1] == T.Rgb("success")[1], "badge fits and recolours")
    local kv = K.KeyValue(env.UIParent, { label = "Kill goal", value = "3 kills" })
    kv:SetPoint("TOPLEFT")
    local one = kv:Layout(400)
    kv:Set(string.rep("A long shared expiry explanation. ", 8), "warning")
    local wrapped = kv:Layout(400)
    assert(wrapped > one, "long values wrap and grow the row")
    assert(s.bounds(kv.value)[1] > s.bounds(kv.label)[1] + s.bounds(kv.label)[3], "value sits beside its label")
    local card = K.SectionCard(env.UIParent, { title = "Saved profiles", hint = "Choose one to review.", strip = "accent" })
    card:SetPoint("TOPLEFT")
    local h = card:Layout(500, 100)
    t.close(card.body:GetHeight(), 100, "body keeps the requested height")
    assert(h > 100 + T.Space("lg") * 2 and s.bounds(card.body)[2] > s.bounds(card.hint)[2], "body follows title and hint")
    card:SetHint(""); local shorter = card:Layout(500, 100)
    assert(shorter < h and not card.hint:IsShown(), "empty hints take no space")
    local writes = Writes({ card, card.body, card.title })
    for _ = 1, 10 do card:Layout(500, 100) end
    t.equal(writes.n, 0, "unchanged cards write no geometry")
    local clicks = 0
    local empty = K.EmptyState(env.UIParent, { title = "No profiles yet", message = "Create one from your current settings.",
      action = "New profile", onAction = function() clicks = clicks + 1 end })
    empty:SetPoint("TOPLEFT")
    local eh = empty:Layout(400)
    assert(eh > T.Size("control") and empty.button:IsShown(), "message and action are laid out")
    fire(empty.button, "OnClick"); t.equal(clicks, 1, "the action runs")
    empty:SetState(K.ResolveState({ error = "Could not read saved data." }))
    t.equal(empty.message:GetText(), "Could not read saved data.", "states supply their message")
    t.equal(empty.message.textColor[1], T.Rgb("danger")[1], "and their tone")
    t.equal(empty.title:GetText(), "No profiles yet", "the title is kept")
    empty:SetState(K.ResolveState({ count = 0, empty = "Nothing saved." }))
    t.equal(empty.message.textColor[1], T.Rgb("textMuted")[1], "recovery restores the muted tone")
    for _, frame in ipairs({ badge, kv, card, empty }) do frame:Hide() end
  end)

  t.test("virtual lists recycle a bounded window of rows while scrolling", function()
    local area = K.ScrollArea(env.UIParent)
    area:SetPoint("TOPLEFT"); area:SetSize(200, 100)
    local created, rendered = 0, {}
    local list = K.VirtualList(area, { rowHeight = 20, gap = 5,
      create = function(body) created = created + 1; return K.Button(body, "", 10, 10) end,
      render = function(row, item, index) row:SetText(item); rendered[index] = row end })
    local items = {}
    for i = 1, 200 do items[i] = "Row " .. i end
    list:SetItems(items)
    t.close(area.body:GetHeight(), 200 * 25, "body covers every item")
    local pool = created
    assert(pool <= math.ceil(100 / 25) + 1, "only the visible window is created")
    local frames = #s.frames
    for offset = 0, 4000, 37 do area:Scroll(offset) end
    t.equal(created, pool, "scrolling reuses rows")
    t.equal(#s.frames, frames, "no new widgets while scrolling")
    area:Scroll(25 * 50)
    local row = rendered[51]
    t.equal(row.text, "Row 51", "rows render their item at the scrolled position")
    t.close(s.bounds(row)[2] - s.bounds(area.view)[2], 0, "the first visible item sits at the top of the viewport")
    list:SetItems({ "Only" })
    t.close(area.offset, 0, "shrinking clamps the offset")
    local shown = 0
    for _, r in ipairs(list.rows) do if r:IsShown() then shown = shown + 1 end end
    t.equal(shown, 1, "rows beyond the items hide")
    local observed
    area.onScroll = nil
    local observing = K.VirtualList(K.ScrollArea(env.UIParent), { create = function(body) return K.Button(body, "") end,
      render = function() end })
    observing.area.onScroll = (function(next) return function(o) observed = o; next(o) end end)(observing.area.onScroll)
    observing:SetItems({ "a" }); t.equal(observed, 0, "existing scroll observers keep running")
    area:Hide(); observing.area:Hide()
  end)
end
