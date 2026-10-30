local _, ns = ...
local Core, T, U, Kit, Theme = ns.Core, ns.Timers, ns.Util, ns.Kit, ns.Theme
local Quick = {}
ns.QuickCalls = Quick
local COUNTS = { ["1"] = true, ["2"] = true, ["3+"] = true }
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

function Quick.Message(count, area)
  if count ~= nil and not COUNTS[tostring(count)] then return nil end
  local enemies = count and (" (" .. count .. (tostring(count) == "1" and " enemy)" or " enemies)")) or ""
  return "Need help — " .. area .. enemies
end

-- Called synchronously by the click: no chat edit box, queued sends or
-- automatic reports. Re-read the area so a zone change cannot send an old one.
function Quick.Send(count)
  if not Enabled() or not Live() then return false, "Quick callouts are only available in a battleground." end
  local area = Quick.Area()
  if not area then return false, "Enter a named battleground area first." end
  local text = Quick.Message(count, area)
  if not text then return false, "Choose 1, 2 or 3+ enemies." end
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
  w:SetWidth(260 * scale)
  w.head:SetHeight(header)
  w.brand:ClearAllPoints(); w.brand:SetPoint("TOPLEFT", pad, -8 * scale); w.brand:SetSize(3, 12 * scale)
  Theme.SetRole(w.title, "heading")
  w.info:Hide()
  w.area:ClearAllPoints(); w.area:SetPoint("TOPLEFT", pad, -header - gap)
  w.area:SetWidth(w:GetWidth() - 2 * pad)
  local height = math.max(20 * scale, w.area:GetStringHeight())
  w.area:SetHeight(height)
  local top = header + gap + height + gap
  for i, button in ipairs(w.buttons) do
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", pad + (i - 1) * 60 * scale, -top)
    button:SetSize(56 * scale, 28 * scale)
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
  for i, label in ipairs({ "Help", "1", "2", "3+" }) do
    local count = i > 1 and label or nil
    local button = Kit.Button(w, label, 56, 28, { onClick = function()
      local ok, err = Quick.Send(count)
      if not ok then U.Say(err) end
    end })
    button:RegisterForClicks("LeftButtonUp")
    Kit.Tooltip(button, function()
      return { { Quick.Message(count, w.location or "Farm"), "text", true },
        { w.preview and "Preview only; messages are disabled." or "Click to send to battleground chat.", "textMuted", true } }
    end)
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
