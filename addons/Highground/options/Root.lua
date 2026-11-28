local _, ns = ...
local Core, O, Theme, Kit, L = ns.Core, ns.Options, ns.Theme, ns.Kit, ns.Locale
local P, p = O.Profiles, O.panel
local S = Theme.Space

---------------------------------------------------------------------------
-- Profiles: every character keeps its own settings for each addon. Pick an
-- addon, then copy another character's or an imported friend's settings into
-- this character (Battlegrounds: every size), export them or import a code.
---------------------------------------------------------------------------
local function CS() return ns.CharacterSettings end
p.rows = {}

local function Addons()
  local list = {}
  for _, addon in ipairs(ns.SettingsParts.ADDONS) do
    if addon == "shared" or ns.Modules.byKey[addon] and ns.Modules.Active(addon) then
      list[#list + 1] = { key = addon, label = { key = "profiles.addon." .. addon } }
    end
  end
  return list
end

local function Status(text, failed)
  Kit.StatusText(p.status, text or "", failed and "danger" or nil)
end

local function Detail(item)
  if item.kind == "self" then return L:Get("profiles.list.this_character") end
  if item.kind == "import" then
    return L:Format("profiles.list.imported_on", { date = date("%Y-%m-%d", item.received or time()) })
  end
  return L:Format("profiles.list.your_character", { class = ns.Util.ClassName(item.class) or "" })
end

local function Row(i)
  if p.rows[i] then return p.rows[i] end
  local row = CreateFrame("Frame", nil, p.list.body)
  row.name = Theme.Text(row, "control", "text"); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
  row.detail = Theme.Text(row, "body", "textMuted"); row.detail:SetJustifyH("LEFT"); row.detail:SetWordWrap(false)
  row.copy = Kit.ConfirmButton(row, function() return L:Format("profiles.list.copy", { name = CS().Name() }) end, {
    confirm = function() return L:Format("profiles.list.copy_confirm", { addon = P.AddonLabel(p.addon) }) end, timeout = 5,
    subject = function() return row.item and row.item.kind .. ":" .. row.item.name end,
    onArm = function() p.LayoutProfiles() end, onDisarm = function() p.LayoutProfiles() end,
    onConfirm = function()
      local item = row.item -- copying refreshes the rows
      local ok, problem = CS().Copy(item.source, p.addon)
      Status(ok and L:Format("profiles.list.copied", { name = item.name, addon = P.AddonLabel(p.addon) }) or problem, not ok)
    end })
  row.delete = Kit.ConfirmButton(row, function() return L:Get("profiles.list.delete") end, {
    confirm = function() return L:Get("profiles.list.delete_confirm") end, timeout = 5,
    subject = function() return row.item and row.item.kind .. ":" .. row.item.name end,
    onArm = function() p.LayoutProfiles() end, onDisarm = function() p.LayoutProfiles() end,
    onConfirm = function()
      local item = row.item
      if CS().Delete(item.source) then Status(L:Format("profiles.list.deleted", { name = item.name })) end
    end })
  row.line = Theme.Fill(row, "BACKGROUND", "border")
  row.line:SetPoint("BOTTOMLEFT"); row.line:SetPoint("BOTTOMRIGHT"); row.line:SetHeight(1)
  p.rows[i] = row
  return row
end

local function Build()
  p.header = Kit.Header(p, { title = L:Get("profiles.page.title"), titleRole = "title", padding = S("xl") })
  p.header:SetPoint("TOPLEFT"); p.header:SetPoint("TOPRIGHT")
  -- Shown in Blizzard's settings, where this page is Highground's root.
  O.openHub = Kit.Button(p, L:Get("profiles.page.open"), 150, 28, { onClick = function()
    if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
    if ns.Hub then ns.Hub.Open() end
  end })
  p.header:SetActions({ O.openHub })
  p.hint = Kit.Paragraph(p, "body", "textMuted")
  local choices = Addons()
  p.addons = Kit.Segmented(p, { choices = choices, value = choices[1].key, onChange = function(_, addon)
    p.addon = addon; Status(""); p.RefreshProfiles()
  end })
  p.addon = choices[1].key
  p.list = Kit.ScrollArea(p)
  p.footer = Kit.Toolbar(p, { height = 30, fitHeight = true })
  p.export = Kit.Button(p, L:Get("profiles.page.export"), 140, 32, { onClick = function() P.ShowExport(p.addon) end })
  p.import = Kit.Button(p, L:Get("profiles.page.import"), 140, 32, { onClick = function() P.ShowImport() end })
  p.chat = Kit.Button(p, L:Get("profiles.share.chat"), 140, 32, { onClick = function()
    local ok, message = P.Chat.ToChat(p.addon)
    Status(message, not ok)
  end })
  p.footer:SetItems({ p.export, p.import, p.chat })
  p.status = Kit.Paragraph(p, "body", "textMuted")
  p.empty = Kit.Paragraph(p.list.body, "body", "textMuted")
end

function p.RefreshProfiles()
  if not (p.built and Core.db and CS() and CS().loaded) then return end
  p.header:SetTitle(L:Get("profiles.page.title"))
  O.openHub:SetText(L:Get("profiles.page.open"))
  O.openHub:SetShown(not (ns.Hub and p:GetParent() == ns.Hub.content))
  local addon = p.addon
  p.hint:SetText(L:Format(addon == "battlegrounds" and "profiles.page.hint_battlegrounds" or "profiles.page.hint",
    { name = CS().Name(), addon = P.AddonLabel(addon) }))
  local items = CS().Profiles(addon)
  p.items = items
  for i, item in ipairs(items) do
    local row = Row(i)
    if row.item and (row.item.name ~= item.name or row.item.kind ~= item.kind) then row.copy:Disarm(); row.delete:Disarm() end
    row.item = item
    row.name:SetText(item.name)
    local color = item.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.class]
    if color then Theme.PaintClass(row.name, color) else Theme.Paint(row.name, "text") end
    row.detail:SetText(Detail(item))
    row.copy:SetShown(item.kind ~= "self"); row.delete:SetShown(item.kind ~= "self")
    row.copy:ShowLabel(); row.delete:ShowLabel()
    row.copy:SetEnabled(not InCombatLockdown())
    row:Show()
  end
  for i = #items + 1, #p.rows do p.rows[i]:Hide(); p.rows[i].item = nil end
  -- Only this character: say how others get here.
  p.empty:SetShown(#items <= 1)
  p.empty:SetText(L:Format("profiles.list.empty", { addon = P.AddonLabel(addon) }))
  p.export:SetText(L:Format("profiles.page.export_addon", { addon = P.AddonLabel(addon) }))
  p.import:SetText(L:Get("profiles.page.import")); p.chat:SetText(L:Get("profiles.share.chat"))
  p.LayoutProfiles()
end

function p.LayoutProfiles()
  if not p.built then return end
  local width, pad = math.max(1, p:GetWidth()), S("xl")
  local inner = math.max(1, width - pad * 2)
  local y = p.header:GetHeight() + S("sm")
  p.hint:SetWidth(inner); Kit.Place(p.hint, "TOPLEFT", p, "TOPLEFT", pad, -y)
  y = y + math.ceil(p.hint:GetStringHeight()) + S("md")
  local h = p.addons:Layout(inner); Kit.Place(p.addons, "TOPLEFT", p, "TOPLEFT", pad, -y)
  y = y + h + S("md")
  local footer = p.footer:Layout(inner)
  p.status:SetWidth(inner)
  local statusHeight = math.max(math.ceil(Kit.Scale(16)), math.ceil(p.status:GetStringHeight()))
  Kit.Place(p.footer, "BOTTOMLEFT", p, "BOTTOMLEFT", pad, pad)
  Kit.Place(p.status, "BOTTOMLEFT", p, "BOTTOMLEFT", pad, pad + footer + S("sm"))
  p.list:ClearAllPoints()
  p.list:SetPoint("TOPLEFT", pad, -y); p.list:SetPoint("BOTTOMRIGHT", -pad, pad + footer + S("sm") + statusHeight + S("md"))
  p.list:Refresh()
  local listWidth, ry = math.max(1, p.list.body:GetWidth() > 1 and p.list.body:GetWidth() or inner - S("xl")), 0
  local rowHeight = math.ceil(Kit.Scale(52))
  for _, row in ipairs(p.rows) do
    if row:IsShown() then
      local right = 0
      for _, button in ipairs({ row.delete, row.copy }) do
        if button:IsShown() then
          button:SetHeight(Kit.Scale(Theme.Size("control"))); Kit.FitButton(button, 90)
          Kit.Place(button, "RIGHT", row, "RIGHT", -right, 0)
          right = right + button:GetWidth() + S("sm")
        end
      end
      local text = math.max(1, listWidth - right - S("md"))
      row.name:SetWidth(text); row.detail:SetWidth(text)
      Kit.Place(row.name, "TOPLEFT", row, "TOPLEFT", 0, -S("sm"))
      Kit.Place(row.detail, "TOPLEFT", row.name, "BOTTOMLEFT", 0, -S("xs"))
      Kit.Place(row, "TOPLEFT", p.list.body, "TOPLEFT", 0, -ry, listWidth, rowHeight)
      ry = ry + rowHeight
    end
  end
  if p.empty:IsShown() then
    p.empty:SetWidth(listWidth); Kit.Place(p.empty, "TOPLEFT", p.list.body, "TOPLEFT", 0, -(ry + S("md")))
    ry = ry + S("md") + math.ceil(p.empty:GetStringHeight())
  end
  p.list.body:SetHeight(math.max(1, ry))
  p.list:Refresh()
end

-- Built on first show; guides and commands open it before its controls.
function O.BuildProfiles()
  if not p.built then p.built = true; Build() end
  return p
end
-- Show an addon's profiles (commands, guides).
function O.ShowProfiles(addon)
  if ns.Hub then ns.Hub.Open("profiles") else O.Open() end
  O.BuildProfiles()
  if addon and p.addons:SetValue(addon, true) then p.addon = addon end
  p.RefreshProfiles()
  return p
end
p:HookScript("OnSizeChanged", function() if p.built and p:IsVisible() then p.LayoutProfiles() end end)
p:HookScript("OnShow", function() O.BuildProfiles(); p.RefreshProfiles() end)
Core.OnFontScaleChange(function() if p.built and p:IsVisible() then p.LayoutProfiles() end end)
p.locale = { SetText = function() if p.built and p:IsVisible() then p.RefreshProfiles() end end }
ns.Localization.Bind(p.locale, "profiles.page.title")
ns.CharacterSettings.Listen(function() if p.built then p.RefreshProfiles() end end)
