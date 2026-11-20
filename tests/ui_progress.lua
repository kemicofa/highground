return function(s, t, fire)
  local K, C, T = s.ns.Kit, s.ns.Core, s.ns.Theme
  t.test("progress steppers communicate the full workflow and only revisit completed stages", function()
    local selected
    local progress = K.ProgressStepper(s.env.UIParent, { steps = { "Target", "Reward", "Review" }, onSelect = function(_, index)
      selected = index
    end })
    local first, current, future = unpack(progress.buttons)
    assert(first.halo:IsShown() and first.number:IsShown() and not first.check:IsShown(), "current stage is numbered and highlighted")
    fire(future, "OnClick")
    t.equal(selected, nil, "future steps cannot skip validation")
    progress:SetCurrent(2)
    assert(first.check:IsShown() and not first.number:IsShown() and first:IsEnabled(), "completed stage becomes a clickable check")
    assert(current.halo:IsShown() and current.status:GetText() == "CURRENT STEP", "current stage has a persistent text cue")
    assert(future.number:IsShown() and not future.halo:IsShown() and future.status:GetText() == "UPCOMING", "future stage remains legible")
    fire(first, "OnClick")
    t.equal(selected, 1, "completed stage requests navigation")
    t.equal(progress.current, 2, "the owner controls the current stage")
    progress:SetCurrent(4)
    for _, button in ipairs(progress.buttons) do
      assert(button.check:IsShown() and not button.halo:IsShown(), "finished workflow has all checks and no current stage")
    end
    progress:SetCurrent(1)
    assert(not first.check:IsShown() and not first:IsEnabled() and future.state == "upcoming", "restarting clears stale completion")
    local indicator = K.ProgressStepper(s.env.UIParent, { steps = { "One", "Two" }, current = 2 })
    assert(not indicator.buttons[1]:IsEnabled(), "read-only progress has no dead navigation buttons")
  end)

  t.test("progress markers, connections and labels reflow without new widgets", function()
    local theme, scale = T.Current(), C.FontScale()
    local progress = K.ProgressStepper(s.env.UIParent, { steps = { "Choose a target", "Set the reward", "Review and publish" }, current = 2 })
    progress:SetPoint("TOPLEFT")
    local before = #s.frames
    for _, size in ipairs({ 1, 1.5 }) do
      C.SetFontScale(size)
      for _, width in ipairs({ 540, 720 }) do
        progress:SetWidth(width); fire(progress, "OnSizeChanged")
        for _, palette in ipairs({ "azeroth", "parchment" }) do
          T.Use(palette)
          local bounds = s.bounds(progress)
          for _, button in ipairs(progress.buttons) do
            local marker, label, status = s.bounds(button.marker), s.bounds(button.label), s.bounds(button.status)
            assert(label[2] > marker[2] + marker[4] and status[2] >= label[2] + label[4], "labels clear circles and each other")
            assert(status[2] + status[4] <= bounds[2] + bounds[4] + 0.01, "component height includes its labels")
            assert(button.label:GetStringHeight() <= label[4] and button.status:GetStringHeight() <= status[4], "wrapped copy fits")
            t.equal(button.face.texture, C.PROGRESS_CIRCLE, "theme changes preserve the circle mask")
          end
          for i, line in ipairs(progress.connectors) do
            local a, b, connection = s.bounds(progress.buttons[i].marker), s.bounds(progress.buttons[i + 1].marker), s.bounds(line)
            assert(connection[1] > a[1] + a[3] and connection[1] + connection[3] < b[1], "connections run between circles")
            t.close(connection[2] + connection[4] / 2, a[2] + a[4] / 2, "connections align with marker centers")
          end
        end
      end
    end
    t.equal(#s.frames, before, "resizing and theme changes reuse the same widgets")
    T.Use(theme); C.SetFontScale(scale)
  end)
end
