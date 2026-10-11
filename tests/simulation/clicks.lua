-- Limited secure-click boundary, following Blizzard's SecureTemplates.lua:
-- https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua
-- Executes addon snippets and target/focus macros, not WoW's full secure runtime.
return function(sim, env)
  sim.clickActions = {}
  local function target(unit)
    if sim.units.target == unit then return end
    sim.lastTarget, sim.units.target = sim.units.target, unit
    sim:event("PLAYER_TARGET_CHANGED")
  end
  local function named(name)
    for token, unit in pairs(sim.units) do
      local short, realm = env.UnitName(token)
      if short and (name == short or name == short .. "-" .. (realm or ""):gsub("%s", "")) then
        return unit
      end
    end
  end
  local function macro(text)
    for line in text:gmatch("[^\n]+") do
      local command, argument = line:match("^(/%S+)%s*(.-)%s*$")
      if command == "/targetexact" then
        local unit = named(argument)
        if unit then target(unit) end
      elseif command == "/focus" then
        assert(argument == "", "Unsupported focus argument")
        sim.units.focus = sim.units.target
      elseif command == "/targetlasttarget" then
        if sim.lastTarget then target(sim.lastTarget) end
      elseif command == "/cleartarget" then
        target(nil)
      else
        error("Unsupported simulated macro: " .. line)
      end
    end
  end
  local function modified(frame, name, button)
    local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2" or "3"
    local prefix = sim.shift and "shift-" or ""
    local a = frame.attrs
    return a[prefix .. name .. suffix] or a[prefix .. name .. "*"]
      or a["*" .. name .. suffix] or a["*" .. name .. "*"] or a[name .. suffix] or a[name]
  end
  local function wrapper(frame, button, down)
    local snippet = frame.secureScripts and frame.secureScripts.OnClick
    if not snippet then return end
    local proxy = {
      GetAttribute = function(_, key) return frame.attrs[key] end,
      -- Attribute writes are permitted only while evaluating the secure snippet.
      SetAttribute = function(_, key, value) frame.attrs[key] = value end,
    }
    local code = assert(loadstring("return function(self, button, down)\n" .. snippet .. "\nend"))
    setfenv(code, { UnitExists = env.UnitExists })
    code()(proxy, button, down)
  end
  function sim:click(frame, button, shift, upOnly)
    frame = type(frame) == "string" and assert(env[frame]) or frame
    assert(frame.secure, "Click fixture expects a secure action button")
    assert(frame:IsVisible() and frame.enabled ~= false and frame.mouseEnabled ~= false, "Button is not clickable")
    button, self.shift = button or "LeftButton", shift or false
    local function phase(down)
      local suffix = down and "Down" or "Up"
      if not (frame.clicks["Any" .. suffix] or frame.clicks[button .. suffix]) then return end
      if frame.scripts.PreClick then frame.scripts.PreClick(frame, button, down) end
      wrapper(frame, button, down)
      local useDown = frame.attrs.useOnKeyDown
      if useDown == nil then useDown = self.useOnKeyDown ~= false end
      if down == useDown then
        local kind = modified(frame, "type", button)
        if kind == "macro" then
          local text = modified(frame, "macrotext", button)
          if text and text ~= "" then
            self.clickActions[#self.clickActions + 1] = { frame = frame.name, text = text }
            macro(text)
          end
        elseif kind and kind ~= "" then
          error("Unsupported simulated action: " .. kind)
        end
      end
      if frame.scripts.PostClick then frame.scripts.PostClick(frame, button, down) end
      self:assertHealthy()
    end
    if not upOnly then phase(true) end
    phase(false)
    self.shift = false
  end
end
