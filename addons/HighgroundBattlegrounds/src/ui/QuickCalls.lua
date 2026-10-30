local _, ns = ...
local Core, T, U, Kit, Theme = ns.Core, ns.Timers, ns.Util, ns.Kit, ns.Theme
local Quick = {}
ns.QuickCalls = Quick
local COUNTS = { ["1"] = true, ["2"] = true, ["3+"] = true }
local BUTTONS = { { label = "Help" }, { label = "1", value = 1 }, { label = "2", value = 2 },
  { label = "3+", value = "3+" }, { label = "All clear", value = "clear", width = 80 } }
local COOLDOWN = 2

local function Enabled()
  local db = ns.GetDB()
  return not ns.STANDBY and db and db.quickCalls == true
end

local function Live()
  return ns.IsActive() and select(2, IsInInstance()) == "pvp"
end

-- Roads or a map-wide zone name do not identify a useful destination.
-- Use the client's localized area even when timer tracking is switched off.
function Quick.Area()
  local area = U.Trim(U.read(GetSubZoneText) or "")
  if area == "" then area = U.Trim(U.read(GetMinimapZoneText) or "") end
  if area == "" or ns.IsZoneName(ns.Intel.MapID(), area) then return nil end
  return area:gsub("[%c|]", ""):sub(1, 90)
end

function Quick.Message(choice, area)
  if choice == "clear" then return "All clear — " .. area end
  if choice ~= nil and not COUNTS[tostring(choice)] then return nil end
  local enemies = choice and (" (" .. choice .. (tostring(choice) == "1" and " enemy)" or " enemies)")) or ""
  return "Need help — " .. area .. enemies
end

-- Called synchronously by the click: no chat edit box, queued sends or
-- automatic reports. Re-read the area so a zone change cannot send an old one.
function Quick.Send(choice)
  if not Enabled() or not Live() then return false, "Quick callouts are only available in a battleground." end
  local area = Quick.Area()
  if not area then return false, "Enter a named battleground area first." end
  local text = Quick.Message(choice, area)
  if not text then return false, "Choose Help, 1, 2, 3+ or All clear." end
  if Quick.sentAt and GetTime() - Quick.sentAt < COOLDOWN then return false, "Wait a moment before another callout." end
  -- Never fall back to a premade party/raid: this message is for the whole BG.
  if ns.Comms.GroupChannel() ~= "INSTANCE_CHAT" then return false, "Battleground chat is unavailable." end
  local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
  if not send then return false, "Battleground chat is unavailable." end
  local ok, result = pcall(send, text, "INSTANCE_CHAT")
  if not ok or result == false then return false, "The callout could not be sent." end
  Quick.sentAt = GetTime()
  Quick.Update()
  return true
end

local function Layout()
  local w = Quick.win
  if not w then return end
  local scale = math.max(1, Core.FontScale())
  local pad, gap, header = 12 * scale, 4 * scale, 26 * scale
  local width = 2 * pad - gap
  for _, button in ipairs(w.buttons) do width = width + button.baseWidth * scale + gap end
  w:SetWidth(width)
  w.head:SetHeight(header)
  w.brand:ClearAllPoints(); w.brand:SetPoint("TOPLEFT", pad, -8 * scale); w.brand:SetSize(3, 12 * scale)
  Theme.SetRole(w.title, "heading")
  w.info:Hide()
  w.area:ClearAllPoints(); w.area:SetPoint("TOPLEFT", pad, -header - gap)
  w.area:SetWidth(w:GetWidth() - 2 * pad)
  local height = math.max(20 * scale, w.area:GetStringHeight())
  w.area:SetHeight(height)
  local top = header + gap + height + gap
  local x = pad
  for _, button in ipairs(w.buttons) do
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, -top)
    button:SetSize(button.baseWidth * scale, 28 * scale)
    x = x + button:GetWidth() + gap
  end
  top = top + 28 * scale + gap
  w.status:ClearAllPoints(); w.status:SetPoint("TOPLEFT", pad, -top)
  w.status:SetWidth(w:GetWidth() - 2 * pad); w.status:SetHeight(18 * scale)
  w:SetHeight(top + 18 * scale + pad)
end

local function Build()
  if Quick.win then return Quick.win end
  local w = T.MakeWindow((ns.FRAME_PREFIX or "Highground") .. "QuickCallsFrame", "QUICK CALLOUTS",
    "quickCallsPoint", { "BOTTOM", "BOTTOM", 0, 180 }, false, true)
  Quick.win = w
  w.area = Theme.Text(w, "rowNameSmall", "text")
  w.area:SetJustifyH("LEFT"); w.area:SetWordWrap(true)
  w.status = Theme.Text(w, "label", "textMuted")
  w.status:SetJustifyH("LEFT")
  w.buttons = {}
  for i, def in ipairs(BUTTONS) do
    local button = Kit.Button(w, def.label, def.width or 56, 28, { onClick = function()
      local ok, err = Quick.Send(def.value)
      if not ok then U.Say(err) end
    end })
    button:RegisterForClicks("LeftButtonUp")
    Kit.Tooltip(button, function()
      return { { Quick.Message(def.value, w.location or "Farm"), "text", true },
        { w.preview and "Preview only; messages are disabled." or "Click to send to battleground chat.", "textMuted", true } }
    end)
    button.baseWidth = def.width or 56
    w.buttons[i] = button
  end
  w.relayout = Layout
  Layout()
  return w
end

function Quick.Update()
  local kind = select(2, IsInInstance())
  local preview = (T.previewing or ns.IsTestMode()) and kind ~= "pvp" and kind ~= "arena"
  local area = Enabled() and (preview and "Farm" or (Live() and Quick.Area()))
  if not area then
    if Quick.win then Quick.win:Hide() end
    if not Live() then Quick.sentAt = nil end
    return
  end
  local w = Build()
  if w.location ~= area then
    w.location = area; w.area:SetText(area); Layout()
  end
  w.preview = preview
  local waiting = Quick.sentAt and GetTime() - Quick.sentAt < COOLDOWN
  w.status:SetText(preview and "Preview · messages disabled" or waiting and "Sent to battleground" or "Click to send to battleground")
  for _, button in ipairs(w.buttons) do button:SetEnabled(not preview and not waiting) end
  w:Show()
end

Core.OnFontScaleChange(Layout)
Theme.OnChange(Layout)
U.Events({ PLAYER_ENTERING_WORLD = Quick.Update, ZONE_CHANGED = Quick.Update,
  ZONE_CHANGED_INDOORS = Quick.Update, ZONE_CHANGED_NEW_AREA = Quick.Update }, "quick callout areas")
U.Every(0.25, Quick.Update, "quick callouts")
