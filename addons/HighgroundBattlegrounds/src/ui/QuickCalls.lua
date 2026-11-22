local _, ns = ...
local Core, T, U, Kit, Theme = ns.Core, ns.Timers, ns.Util, ns.Kit, ns.Theme
local Quick = ns.QuickCalls
local BUTTONS = { ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.quickcalls.help.c47ae1") }, { label = "battlegrounds.quickcalls.help.c47ae1" }), { label = "1", value = 1 }, { label = "2", value = 2 },
  { label = "3+", value = "3+" }, ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.quickcalls.all_clear.360e11"), value = "clear", width = 80 }, { label = "battlegrounds.quickcalls.all_clear.360e11" }) }

local function Layout()
  local w = Quick.win
  if not w then return end
  local scale = math.max(1, Core.FontScale())
  local pad, gap, header = 12 * scale, 4 * scale, 26 * scale
  local width = 2 * pad - gap
  for _, button in ipairs(w.buttons) do width = width + button.baseWidth * scale + gap end
  w:SetWidth(width)
  w.head:SetHeight(header)
  ns.PanelControls.Layout(w, header, pad)
  w.brand:ClearAllPoints(); w.brand:SetPoint("TOPLEFT", pad, -8 * scale); w.brand:SetSize(3, 12 * scale)
  Theme.SetRole(w.title, "heading")
  w.info:Hide()
  w.title:SetPoint("RIGHT", w.gear, "LEFT", -gap, 0)
  w.area:ClearAllPoints(); w.area:SetPoint("TOPLEFT", pad, -header - gap)
  w.area:SetWidth(w:GetWidth() - 2 * pad)
  local height = math.max(20 * scale, w.area:GetStringHeight())
  w.area:SetHeight(height)
  local top = header + gap + height + gap
  local inner, control = width - 2 * pad, 28 * scale
  local function Row(buttons, y, uniform)
    local x = 0
    for _, button in ipairs(buttons) do
      button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, -y)
      button:SetSize(uniform or button.baseWidth * scale, control)
      x = x + button:GetWidth() + gap
    end
  end
  local function Group(group, height)
    group:ClearAllPoints(); group:SetPoint("TOPLEFT", pad, -top)
    group:SetSize(inner, height)
    top = top + height + 2 * gap
  end
  if w.localRow:IsShown() then
    Group(w.localRow, control)
    Row(w.buttons, 0)
  end
  if w.destinationGroup:IsShown() then
    Group(w.destinationGroup, 20 * scale + 2 * control + 2 * gap)
    w.destinationGroup.heading:SetSize(inner, 20 * scale)
    w.destination:ClearAllPoints(); w.destination:SetPoint("TOPLEFT", 0, -20 * scale - gap)
    w.destination:SetSize(inner, control)
    Row(w.destinationButtons, 20 * scale + control + 2 * gap, (inner - 2 * gap) / 3)
  end
  if w.routeGroup:IsShown() then
    Group(w.routeGroup, 20 * scale + control + gap)
    w.routeGroup.heading:SetSize(inner, 20 * scale)
    Row(w.routeButtons, 20 * scale + gap, (inner - 2 * gap) / 3)
  end
  w.status:ClearAllPoints(); w.status:SetPoint("TOPLEFT", pad, -top)
  w.status:SetWidth(w:GetWidth() - 2 * pad); w.status:SetHeight(18 * scale)
  w:SetHeight(top + 18 * scale + pad)
end

local function Build()
  if Quick.win then return Quick.win end
  local w = T.MakeWindow((ns.FRAME_PREFIX or "Highground") .. "QuickCallsFrame", ns.Locale:Get("battlegrounds.quickcalls.quick_callouts.654190"),
    "quickCallsPoint", { "BOTTOM", "BOTTOM", 0, 180 }, false, true)
  Quick.win = w
  w.area = Theme.Text(w, "rowNameSmall", "text")
  w.area:SetJustifyH("LEFT"); w.area:SetWordWrap(true)
  w.status = Theme.Text(w, "label", "textMuted")
  w.status:SetJustifyH("LEFT")
  local function Button(parent, label, width, send, message)
    local button = Kit.Button(parent, label, width, 28, { onClick = function()
      if Quick.guide then
        Quick.guide.message = message(); Quick.guide.clicked = label
        Quick.Update(); return
      end
      local ok, err = send()
      if not ok then U.Say(err) end
    end })
    button:RegisterForClicks("LeftButtonUp")
    Kit.Tooltip(button, function()
      return { { message(), "text", true },
        { Quick.guide and ns.Locale:Get("battlegrounds.quickcalls.sample_only_nothing_is_sent.76ab7b") or w.preview and ns.Locale:Get("battlegrounds.quickcalls.preview_only_messages_are_disabled.8d9e91")
          or ns.Locale:Get("battlegrounds.quickcalls.click_to_send_to_battleground_chat.f52f37"), "textMuted", true } }
    end)
    button.baseWidth = width
    return button
  end
  local function Group(label)
    local group = CreateFrame("Frame", nil, w)
    group.heading = Theme.Text(group, "label", "textMuted")
    group.heading:SetPoint("TOPLEFT"); group.heading:SetJustifyH("LEFT"); group.heading:SetText(label)
    group:Hide()
    return group
  end
  w.localRow = CreateFrame("Frame", nil, w)
  w.buttons = {}
  for i, def in ipairs(BUTTONS) do
    w.buttons[i] = Button(w.localRow, def.label, def.width or 56,
      function() return Quick.Send(def.value) end, function() return Quick.Message(def.value, w.location or "Farm") end)
  end
  w.destinationGroup = Group(ns.Locale:Get("battlegrounds.quickcalls.enemies_going_to.1c6bf7"))
  w.destination = Kit.Select(w.destinationGroup, { menu = true, choices = {}, onChange = function() Quick.Update() end })
  w.destinationButtons = {}
  for i, count in ipairs(Quick.COUNTS) do
    w.destinationButtons[i] = Button(w.destinationGroup, count, 56,
      function() return Quick.SendDestination(count, w.destination:GetValue(), w.context) end,
      function() return Quick.DestinationMessage(count, w.destination:GetValue() ~= "" and w.destination:GetValue() or ns.Locale:Get("battlegrounds.quickcalls.chosen_destination.782f28")) end)
  end
  w.routeGroup = Group(ns.Locale:Get("battlegrounds.quickcalls.enemy_flag_carrier_going.6845f4"))
  w.routeButtons = {}
  for i = 1, 3 do
    w.routeButtons[i] = Button(w.routeGroup, "", 100,
      function() return Quick.SendRoute(w.routeButtons[i].route, w.context) end,
      function() return Quick.RouteMessage(w.routeButtons[i].route or "ramp") end)
  end
  w.relayout = Layout
  Layout()
  return w
end

function Quick.Update()
  local kind = select(2, IsInInstance())
  local guide = Quick.guide and not InCombatLockdown() and kind ~= "pvp" and kind ~= "arena"
  local preview = (guide or T.previewing or ns.IsTestMode()) and kind ~= "pvp" and kind ~= "arena"
  local active = guide or Quick.Enabled() and (preview or Quick.Live())
  local area = active and (preview and "Farm" or Quick.Area())
  local destinations = active and (guide and Quick.guide.mode == "destinations" or not guide and Quick.Enabled("quickCallsDestinations")) and Quick.Destinations(preview) or {}
  local routes = active and (guide and Quick.guide.mode == "routes" or not guide and Quick.Enabled("quickCallsRoutes")) and Quick.Routes(preview) or {}
  if not area and #destinations == 0 and #routes == 0 then
    if Quick.win then Quick.win:Hide(); Quick.win.context = nil end
    if not Quick.Live() then Quick.sentAt = nil end
    return
  end
  local w = Build()
  local context = preview and "preview" or Quick.Context()
  local signature = table.concat(destinations, "\031")
  if context ~= w.context or signature ~= w.destinationSignature then
    local choices = { { key = "", label = ns.Locale:Get("battlegrounds.quickcalls.choose_destination.a311df") } }
    for _, name in ipairs(destinations) do choices[#choices + 1] = { key = name, label = name } end
    w.destination:SetChoices(choices)
    if context ~= w.context then w.destination:SetValue("", true) end
    w.destinationSignature = signature
  end
  w.context, w.location, w.preview = context, area, preview
  local bg = not preview and Quick.Battleground()
  w.area:SetText(area or (bg and bg.name) or ns.Locale:Get("highground.home.battleground.19d4bd"))
  w.localRow:SetShown(not not area)
  w.destinationGroup:SetShown(#destinations > 0)
  w.routeGroup:SetShown(#routes > 0)
  local waiting = Quick.sentAt and GetTime() - Quick.sentAt < Quick.COOLDOWN
  local ready = guide or not preview and not waiting
  w.status:SetText(guide and (Quick.guide.message and ns.Locale:Get("battlegrounds.quickcalls.sample_sent_no_chat_message.a2dfb4") or ns.Locale:Get("battlegrounds.quickcalls.sample_try_a_button.7bdfed"))
    or preview and ns.Locale:Get("battlegrounds.quickcalls.preview_messages_disabled.5b2c28") or waiting and ns.Locale:Get("battlegrounds.quickcalls.sent_to_battleground.b084c4") or ns.Locale:Get("battlegrounds.quickcalls.click_to_send_to_battleground.7dc06a"))
  for _, button in ipairs(w.buttons) do button:SetEnabled(ready and not not area) end
  w.destination:SetEnabled(guide or not preview)
  for _, button in ipairs(w.destinationButtons) do button:SetEnabled(ready and w.destination:GetValue() ~= "") end
  for i, button in ipairs(w.routeButtons) do
    button.route = routes[i]; button:SetText(routes[i] or ""); button:SetShown(routes[i] ~= nil)
    button:SetEnabled(ready and routes[i] ~= nil)
  end
  Layout()
  w:Show()
end

-- The walkthrough uses the live panel builder and its real controls. Only
-- the action boundary changes: clicks produce local feedback, never chat.
function Quick.StartGuide(mode)
  local kind = select(2, IsInInstance())
  if InCombatLockdown() or kind == "pvp" or kind == "arena" then return false end
  Quick.guide = { mode = mode or "local" }
  Quick.Update()
  if mode == "destinations" then Quick.win.destination:SetValue("", true); Quick.Update() end
  return true
end
function Quick.EndGuide()
  if not Quick.guide then return end
  Quick.guide = nil; Quick.Update()
end

Core.OnFontScaleChange(Layout)
Theme.OnChange(Layout)
U.Events({ PLAYER_ENTERING_WORLD = Quick.Update, ZONE_CHANGED = Quick.Update,
  ZONE_CHANGED_INDOORS = Quick.Update, ZONE_CHANGED_NEW_AREA = Quick.Update }, "quick callout areas", "battlegrounds")
U.Every(0.25, Quick.Update, "quick callouts", "battlegrounds")
