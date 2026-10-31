-- Export running player-facing windows for the HTML preview tool.
-- Run from addons/Highground: luajit ../../tools/macro_preview.lua [theme] [scale] [state]
local sim = dofile("../../tools/wowsim/battleground/runtime.lua")("cata", nil, function(s)
  dofile("../../tools/wowsim/geometry.lua")(s)
  local methods = getmetatable(s.env.UIParent).__index
  methods.SetBackdropColor = function(f, ...) f.backdropColor = { ... } end
  methods.SetBackdropBorderColor = function(f, ...) f.backdropBorder = { ... } end
end)
sim.ns.Theme.Use(arg[1] or "azeroth")
sim.ns.Core.SetFontScale(tonumber(arg[2]) or 1)
sim:command("macros build")
local P, w = sim.ns.Macros.BuildPanel, sim.ns.Macros.Window.win
local p = P.frame
sim.known.Kick = true
if arg[3] ~= "empty" then
  p.spell:SetText("Kick")
  p.target:SetValue("focus")
  p.kind:SetValue("harm")
  for _, b in ipairs(p.toggles) do
    if b.value == "fallback" or b.value == "stopcast" then b.scripts.OnClick(b) end
  end
  p.name:SetText("Focus Kick")
end
if arg[3] == "presets" or arg[3] == "presets-code" or arg[3] == "hub-presets-code" then
  sim.ns.Macros.Window.SetTab("all"); w.search:SetText("Kick")
  if arg[3] ~= "presets" then w.showCode.scripts.OnClick(w.showCode) end
  if arg[3] == "hub-presets-code" then sim.ns.Hub.Open("macros"); sim.ns.Macros.Window.Refresh() end
end
if arg[3] == "expanded" then p.conditionsGroup.open = true end
if arg[3] == "target" then p.of.scripts.OnClick(p.of) end
if arg[3] == "manual" then
  P.Load({ name = "Focus Kick", body = "#showtooltip\n/cast [@focus] Kick", perCharacter = true })
end
if arg[3] == "hub" then sim.ns.Hub.Open("macros"); sim.ns.Macros.Window.Refresh() end
if arg[3] == "home" then w:Hide(); sim.ns.Hub.Open("home") end
local pages = { features = "general", alerts = "alerts", guide = "checklist", setup = "setup",
  journal = "journal", bounties = "bountyboard" }
if pages[arg[3]] then w:Hide(); sim.ns.Hub.Open(pages[arg[3]]) end
local extraWindow
local hud = arg[3] == "battleground"
if hud then w:Hide(); sim.ns.Setup.BeginPlacement(); sim:advance(0.5) end
if arg[3] == "bounty-form" then
  w:Hide(); sim.ns.Bounty.Board.Open()
  sim.ns.Bounty.Form.Open()
  extraWindow = sim.ns.Bounty.Form.win
end
if ({ ["bounty-list"] = true, ["bounty-shared"] = true, ["bounty-details"] = true, ["bounty-claims"] = true })[arg[3]] then
  w:Hide(); sim.ns.Hub.Open("bountyboard")
  local B = sim.ns.Bounty
  if arg[3] == "bounty-list" then
    B.Add("Nightshade-Whitemane", 0, "Watch for this rogue near Tarren Mill")
    B.Add("Ironclaw-Realm", 250, "Seen at the crossroads")
    B.Add("Ashveil-Realm", 100, "")
  elseif arg[3] == "bounty-shared" then B.Board.SetTab("public")
  elseif arg[3] == "bounty-details" then
    sim.env.GetMoney = function() return 100000000 end
    sim.ns.Core.SetOption("bountyReceive", true)
    local offer = assert(B.Public.Post("Nightshade-Whitemane", 500, "2h", "Hunting near Tarren Mill", true))
    local other = B.Public.Copy(offer)
    other.id, other.contributor, other.by = "preview-other", "preview-account", "Huntmaster-Realm"
    other.gold, other.note = 250, "Report your killing blow for review"
    assert(B.Public.Merge(other, other.by))
    B.Board.SetTab("public"); B.Details.Open(B.BoardModel.Rows("public")[1])
  else B.Ledger.Open() end
  B.Board.Refresh()
end
P.Layout()
if arg[3] == "completion" then
  p.code:SetFocus()
  p.code:SetText("#showtooltip\n/cast [@fo")
  local x, y, h = 62, -14, 14
  p.code.scripts.OnCursorChanged(p.code, x, y, 1, h)
  for _, hook in ipairs(p.code.hooks.OnCursorChanged) do hook(p.code, x, y, 1, h) end
end
local function quote(v)
  return '"' .. v:gsub('[%z\1-\31\\"]', function(c)
    return c == '"' and '\\"' or c == '\\' and '\\\\' or string.format('\\u%04x', c:byte())
  end) .. '"'
end
local function json(v)
  if type(v) == "string" then return quote(v) end
  if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
  if type(v) ~= "table" then return "null" end
  local out = {}
  if #v > 0 then for _, item in ipairs(v) do out[#out + 1] = json(item) end; return "[" .. table.concat(out, ",") .. "]" end
  for key, item in pairs(v) do out[#out + 1] = quote(key) .. ":" .. json(item) end
  return "{" .. table.concat(out, ",") .. "}"
end
local rows = {}
for _, f in ipairs(sim.frames) do
  if f:IsVisible() and (f.text or f.colorTexture or f.backdropColor) then
    local ancestor, depth, clip, include, popup, alpha = f, 0, nil, false, false, 1
    while ancestor do
      if ancestor == w or ancestor == sim.ns.Hub.win or ancestor == extraWindow then include = true end
      if hud and (ancestor == sim.ns.Core.frame or ancestor == sim.ns.Setup.layoutBar
        or ancestor == sim.ns.Flags.flagWin) then include = true end
      if hud then for _, timer in ipairs(sim.ns.Timers.timerWindows) do if ancestor == timer then include = true end end end
      if ancestor == sim.ns.Kit.Dropdown.Frame() then include, popup = true, true end
      if ancestor.kind == "ScrollFrame" then clip = sim.bounds(ancestor) end
      alpha = alpha * (ancestor.alpha or 1)
      depth, ancestor = depth + 1, ancestor.parent
    end
    if include then
      local r = { kind = f.kind, bounds = sim.bounds(f), text = f.kind == "FontString" or f.kind == "EditBox" and f.text and f.text or nil,
        color = f.colorTexture or f.backdropColor, ink = f.textColor, border = f.backdropBorder, rotation = f.rotation,
        font = f.font, align = f.justifyH, depth = depth, layer = f.layer, clip = clip, popup = popup, alpha = alpha }
      if f.kind == "FontString" then r.text = f.text end
      rows[#rows + 1] = r
    end
  end
end
print(json({ frames = rows, window = sim.bounds(w), theme = sim.ns.Theme.Current() }))
