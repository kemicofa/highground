return function(s, t, fire)
  t.test("compact action rows keep full details on hover and one-line geometry", function()
    local K, env, calls = s.ns.Kit, s.env, 0
    local label = "/hg example with a long argument list and aliases"
    local detail = "This deliberately long description remains available in full without expanding the reference row."
    local row = K.ActionRow(env.UIParent, { label = label, detail = detail, action = "Open", role = "code",
      onClick = function() calls = calls + 1 end })
    row:SetPoint("TOPLEFT", 20, -20)
    local count = #s.frames
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      for _, width in ipairs({ 760, 280, 560 }) do
        local height = row:Layout(width)
        assert(height <= (scale == 1 and 32 or 40), "row never becomes a stack of text and controls")
        local title, action = s.bounds(row.label), s.bounds(row.button)
        t.close(title[2] + title[4] / 2, action[2] + action[4] / 2, "text and action share a center line")
        assert(title[1] + title[3] < action[1], "text cannot overlap the action")
        assert(action[1] + action[3] <= s.bounds(row)[1] + width + 1, "action stays in the available width")
        assert(row.button.label:GetStringWidth() < action[3], "action label fits at enlarged text size")
        if width == 280 then assert(not row.detail:IsShown(), "narrow views reserve space for command and action") end
        if width == 760 then assert(row.detail:IsShown(), "wide views show the description inline") end
        for _, target in ipairs({ row, row.button }) do
          fire(target, "OnEnter")
          local tip = table.concat(env.GameTooltip.lines, "\n")
          assert(tip:find(label, 1, true) and tip:find(detail, 1, true), "full content survives clipping and hidden details")
          t.equal(calls, 0, "hover does not execute actions")
          fire(target, "OnLeave"); assert(not env.GameTooltip:IsShown(), "tooltip closes")
        end
      end
    end
    t.equal(#s.frames, count, "resizing and font changes reuse every control")
    fire(row.button, "OnClick"); t.equal(calls, 1, "only the action button executes the callback")
    row.button:SetEnabled(false); assert(not row.button:IsEnabled(), "disabled actions retain the shared button guard")
    fire(row, "OnEnter"); row:Hide()
    assert(not env.GameTooltip:IsShown(), "hiding a reference clears its tooltip")
    s.ns.Core.SetFontScale(1)
  end)

  t.test("unchanged action rows avoid geometry writes and layout callbacks", function()
    local row = s.ns.Kit.ActionRow(s.env.UIParent, { label = "Command", detail = "Description", action = "Run" })
    row:Layout(600)
    local writes = 0
    for _, region in ipairs({ row, row.label, row.detail, row.button }) do
      for _, method in ipairs({ "ClearAllPoints", "SetPoint", "SetSize", "SetShown" }) do
        local original = region[method]
        region[method] = function(...) writes = writes + 1; return original(...) end
      end
    end
    local count = #s.frames
    for _ = 1, 20 do row:Layout(600) end
    t.equal(writes, 0, "stable layout performs no native writes")
    t.equal(#s.frames, count, "stable layout allocates no widgets")
    assert(not row.scripts.OnUpdate, "rows do not poll during gameplay")
    row:Layout(280); assert(writes > 0 and not row.detail:IsShown(), "a real resize reflows the existing controls")
    row:Hide()
  end)
end
