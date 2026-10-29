---------------------------------------------------------------------------
-- Stateful WoW widgets (CreateFrame and its methods) and the Blizzard
-- frames addons anchor to. Unsupported queries fail instead of inventing
-- values; protected frames refuse layout, visibility and attribute changes
-- in combat (sim.combat). Every frame is kept in sim.frames for events.
---------------------------------------------------------------------------
return function(sim, env)
  local methods = {}
  local function protected(frame)
    return frame.secure or frame.protected
  end
  local function mutable(frame, operation)
    if sim.combat and protected(frame) and (frame.kind == "Frame" or frame.kind == "Button") then
      error("Protected " .. operation .. " in combat: " .. (frame.name or frame.kind))
    end
  end
  local function fire(frame, event, ...)
    if frame.scripts[event] then frame.scripts[event](frame, ...) end
    for _, callback in ipairs(frame.hooks[event] or {}) do callback(frame, ...) end
  end
  local function create(kind, name, parent, template)
    local frame = { kind = kind or "Frame", name = name, parent = parent, children = {},
      scripts = {}, hooks = {}, events = {}, attrs = {}, shown = true, alpha = 1,
      width = 600, height = 400, scale = 1, points = {}, frameLevel = 1,
      secure = template and template:find("SecureActionButtonTemplate", 1, true) ~= nil }
    setmetatable(frame, { __index = methods })
    if parent then parent.children[#parent.children + 1] = frame end
    -- Secure descendants protect their containing panels; plain visual siblings
    -- can still show/hide while those buttons remain fixed in combat.
    if frame.secure then
      local ancestor = parent
      while ancestor and ancestor ~= env.UIParent do
        ancestor.protected = true
        ancestor = ancestor.parent
      end
    end
    if name then assert(not env[name], "Duplicate frame: " .. name); env[name] = frame end
    sim.frames[#sim.frames + 1] = frame
    return frame
  end
  methods.SetScript = function(f, event, callback) f.scripts[event] = callback end
  methods.GetScript = function(f, event) return f.scripts[event] end
  methods.HookScript = function(f, event, callback)
    f.hooks[event] = f.hooks[event] or {}; table.insert(f.hooks[event], callback)
  end
  methods.RegisterEvent = function(f, event) f.events[event] = true end
  methods.UnregisterEvent = function(f, event) f.events[event] = nil end
  methods.Show = function(f)
    mutable(f, "Show"); local changed = not f.shown; f.shown = true
    if changed then fire(f, "OnShow") end
  end
  methods.Hide = function(f)
    mutable(f, "Hide"); local changed = f.shown; f.shown = false
    if changed then fire(f, "OnHide") end
  end
  methods.SetShown = function(f, on) if on then f:Show() else f:Hide() end end
  methods.IsShown = function(f) return f.shown end
  methods.IsMouseOver = function(f) return sim.mouseOver == f end
  methods.GetStringWidth = function(f) return #(f.text or "") * 7 end -- about the code font
  methods.IsVisible = function(f) return f.shown and (type(f.parent) ~= "table" or f.parent:IsVisible()) end
  methods.IsForbidden = function() return false end
  methods.SetAttribute = function(f, key, value) mutable(f, "SetAttribute"); f.attrs[key] = value end
  methods.GetAttribute = function(f, key) return f.attrs[key] end
  methods.RegisterForClicks = function(f, ...)
    f.clicks = {}; for i = 1, select("#", ...) do f.clicks[select(i, ...)] = true end
  end
  methods.EnableMouse = function(f, enabled) f.mouseEnabled = enabled end
  methods.SetPoint = function(f, ...) mutable(f, "SetPoint"); f.points[#f.points + 1] = { ... } end
  methods.GetPoint = function(f, index) return unpack(f.points[index or 1] or {}) end
  methods.ClearAllPoints = function(f) mutable(f, "ClearAllPoints"); f.points = {} end
  methods.SetAllPoints = function(f, parent) mutable(f, "SetAllPoints"); f.allPoints = parent or f.parent end
  methods.SetScale = function(f, value) mutable(f, "SetScale"); f.scale = value end
  methods.GetScale = function(f) return f.scale end
  methods.SetSize = function(f, w, h) mutable(f, "SetSize"); f.width, f.height = w, h end
  methods.SetWidth = function(f, value) mutable(f, "SetWidth"); f.width = value end
  methods.SetHeight = function(f, value) mutable(f, "SetHeight"); f.height = value end
  methods.GetWidth = function(f) return f.width end
  methods.GetCenter = function() return 0, 0 end
  methods.GetEffectiveScale = function(f) return f.scale end
  methods.GetHeight = function(f) return f.height end
  methods.SetFrameLevel = function(f, value) f.frameLevel = value end
  methods.GetFrameLevel = function(f) return f.frameLevel end
  methods.SetText = function(f, text)
    f.text = tostring(text or "")
    f.cursor = nil -- the game puts the cursor at the end
    fire(f, "OnTextChanged", false)
  end
  methods.GetText = function(f) return f.text or "" end
  methods.GetStringHeight = function(f)
    local lines = 0
    for line in ((f.text or "") .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#line / 80)) end
    return lines * 12
  end
  methods.ClearFocus = function(f) fire(f, "OnEditFocusLost") end
  methods.SetFocus = function(f) fire(f, "OnEditFocusGained") end
  methods.SetCursorPosition = function(f, pos) f.cursor = pos end
  methods.GetCursorPosition = function(f) return f.cursor or #(f.text or "") end
  methods.SetChecked = function(f, on) f.checked = not not on end
  methods.GetChecked = function(f) return f.checked end
  methods.Enable = function(f) f.enabled = true end
  methods.Disable = function(f) f.enabled = false end
  methods.SetAlpha = function(f, value) f.alpha = value end
  methods.GetAlpha = function(f) return f.alpha end
  methods.SetValue = function(f, value) f.value = value end
  methods.SetMinMaxValues = function(f, low, high) f.minimum, f.maximum = low, high end
  methods.SetPosition = function(f, x, y) f.x, f.y = x, y end
  methods.SetTexture = function(f, value) f.texture = value end
  methods.SetAtlas = function(f, value) f.atlas = value end
  methods.SetNormalTexture = function(f, value)
    f.normalTexture = create("Texture", nil, f); f.normalTexture.texture = value
  end
  methods.GetNormalTexture = function(f) return f.normalTexture end
  methods.CreateTexture = function(f, name) return create("Texture", name, f) end
  methods.CreateFontString = function(f, name) return create("FontString", name, f) end
  methods.CreateAnimationGroup = function(f) return create("AnimationGroup", nil, f) end
  methods.CreateAnimation = function(f) return create("Animation", nil, f) end
  methods.Play = function(f) f.playing = true end
  methods.Stop = function(f) f.playing = false end
  methods.IsPlaying = function(f) return f.playing or false end
  methods.SetScrollChild = function(f, child) f.scrollChild = child end
  methods.SetVerticalScroll = function(f, value) f.verticalScroll = value end
  methods.GetVerticalScroll = function(f) return f.verticalScroll or 0 end
  methods.SetOrientation = function(f, value) f.orientation = value end
  methods.SetValueStep = function(f, value) f.valueStep = value end
  methods.SetThumbTexture = function(f, value) f.thumbTexture = value end
  methods.SetRotation = function(f, value) f.rotation = value end
  methods.AddLine = function(f, text) f.lines = f.lines or {}; table.insert(f.lines, text) end
  methods.AddDoubleLine = function(f, left, right) f:AddLine(left .. " " .. right) end
  methods.WrapScript = function(f, button, event, snippet)
    button.secureScripts = button.secureScripts or {}; button.secureScripts[event] = snippet
  end
  -- These presentation-only calls do not affect scenario decisions.
  for name in ("SetBackdrop SetBackdropColor SetBackdropBorderColor SetBlendMode SetClampedToScreen "
    .. "SetJustifyV SetDesaturated SetDesaturation SetDuration SetFontObject SetFrameStrata SetFromAlpha SetJustifyH "
    .. "SetLooping SetOrder SetOwner SetShadowColor SetShadowOffset SetSmoothing SetSpacing SetStatusBarColor "
    .. "SetStatusBarTexture SetTexCoord SetToAlpha SetWordWrap SetAutoFocus "
    .. "SetMaxLetters SetMultiLine HighlightText SetMovable "
    .. "StartMoving StopMovingOrSizing RegisterForDrag SetScalingLimits "
    .. "UseFrameLevelType"):gmatch("%S+") do
    methods[name] = function() end
  end
  -- Reparenting (a window can borrow another's pages).
  -- frame.parent may also be InterfaceOptions' category-name string (Cata): not a frame.
  methods.GetParent = function(f) return type(f.parent) == "table" and f.parent or nil end
  methods.SetParent = function(f, parent)
    if type(f.parent) == "table" then
      for i, child in ipairs(f.parent.children) do if child == f then table.remove(f.parent.children, i) break end end
    end
    f.parent = parent
    if parent then parent.children[#parent.children + 1] = f end
  end
  methods.GetNumPoints = function(f) return #f.points end
  methods.SetFrameStrata = function(f, strata) f.strata = strata end
  methods.GetFrameStrata = function(f) return f.strata or "MEDIUM" end
  methods.SetMovable = function(f, on) f.movable = on end
  methods.IsMovable = function(f) return f.movable or false end
  -- Cooldown widgets: the arena trinket sweep reads back what it was given.
  methods.SetCooldown = function(f, start, duration)
    f.cooldown = { start = start, duration = duration }; f:Show()
  end
  methods.SetCooldownFromDurationObject = function(f, duration) f.cooldown = { object = duration }; f:Show() end
  methods.Clear = function(f) f.cooldown = nil; f:Hide() end
  methods.SetDrawBling = function(f, on) f.drawBling = on end
  methods.SetHideCountdownNumbers = function(f, hide) f.hideNumbers = hide end
  -- Appearance scenarios read back the panel fill and bar texture.
  methods.SetBackdrop = function(f, value) f.backdrop = value end
  methods.SetStatusBarTexture = function(f, value) f.barTexture = value end
  methods.SetOwner = function(f, owner) f.owner = owner; f.lines = {} end
  -- Theme scenarios read back painted colours and fonts.
  methods.GetObjectType = function(f) return f.kind end
  methods.SetColorTexture = function(f, r, g, b, a) f.colorTexture = { r, g, b, a or 1 } end
  methods.SetTextColor = function(f, r, g, b, a) f.textColor = { r, g, b, a or 1 } end
  methods.SetVertexColor = function(f, r, g, b, a) f.vertexColor = { r, g, b, a or 1 } end
  methods.SetFont = function(f, file, size, flags) f.font = { file, size, flags }; return true end
  methods.EnableMouseWheel = function(f, on) f.wheel = on end
  methods.GetOwner = function(f) return f.owner end
  env.CreateFrame = create
  env.UIParent = create("Frame", "UIParent")
  env.PlayerFrame = create("Frame", "PlayerFrame", env.UIParent)
  env.Minimap = create("Frame", "Minimap", env.UIParent)
  env.GameTooltip = create("Frame", "GameTooltip", env.UIParent)
  env.GameTooltip_Hide = function() env.GameTooltip:Hide() end
  env.ArenaEnemyFrames = create("Frame", "ArenaEnemyFrames", env.UIParent)
  env.WatchFrame = create("Frame", "WatchFrame", env.UIParent)
  env.SlashCmdList, env.UISpecialFrames = {}, {}
  env.InterfaceOptions_AddCategory = function() end
  env.InterfaceOptionsFrame_OpenToCategory = function(frame) frame:Show() end
  env.hooksecurefunc = function(name, callback)
    local original = assert(env[name]); env[name] = function(...) original(...); callback(...) end
  end
end
