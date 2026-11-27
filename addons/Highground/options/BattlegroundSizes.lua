local _, ns = ...
local Core, Kit, Options, L = ns.Core, ns.Kit, ns.Options, ns.Locale

-- Where Highground runs, by battleground size (Core.SizeEnabled). The card
-- sits in Battlegrounds settings below Include unrated battlegrounds; its
-- switches belong to the character and profiles never change them.
Options.BATTLEGROUND_SIZES = {
  { key = "bg10", label = "shared.battlegrounds.10v10_battlegrounds.ebfe4f",
    detail = "shared.battlegrounds.warsong_gulch_twin_peaks_battle_for_gilneas.eb7e94" },
  { key = "bg15", label = "shared.battlegrounds.15v15_battlegrounds.25db3e",
    detail = "shared.battlegrounds.arathi_basin_eye_of_the_storm_deepwind.011449", unrated = true },
  { key = "bg40", label = "shared.battlegrounds.epic_battlegrounds.4b17c3",
    detail = "shared.battlegrounds.alterac_valley_isle_of_conquest_wintergrasp_slayer.bcc493", unrated = true },
}
local UNRATED = "shared.battlegrounds.include_unrated_battlegrounds.c9e060"

-- Open Battlegrounds settings scrolled to the card (Profiles, the context bar).
function Options.ShowBattlegroundSizes()
  local pages = Options.addonPages.battlegrounds
  if not (pages and ns.Modules.Require("battlegrounds")) then return end
  ns.Hub.Open(pages.settings)
  local page = Options.featurePages.battlegrounds
  if not (page and page.sizes) then return end
  local _, top = page.content:GetCenter()
  local _, card = page.sizes:GetCenter()
  if not (top and card) then return end
  local offset = math.max(0, top + page.content:GetHeight() / 2 - card - page.sizes:GetHeight() / 2 - 16)
  if page.scroll.Scroll then page.scroll:Scroll(offset) else page.scroll:SetVerticalScroll(offset) end
end

function Options.CharacterName()
  return Core.me.name or UnitName("player") or ""
end

local function Profiles() return Options.Profiles end
local function Relayout(page) if page.frame:IsVisible() then page.LayoutFeatures() end end

Options.featureWidgets.battlegroundSizes = function(parent, page)
  local card = Kit.SectionCard(parent)
  card.rows = {}
  for i, def in ipairs(Options.BATTLEGROUND_SIZES) do
    local row = Kit.SettingRow(card.body, { label = L:Get(def.label), detail = L:Get(def.detail),
      onChange = function(_, on) Core.SetSizeEnabled(def.key, on); Profiles().Automatic() end })
    row.size = def.key
    row.create = Kit.Button(row, L:Get("battlegrounds.layouts.create"), nil, nil, {
      onClick = function() Profiles().Layouts.Create(def.key); card:Refresh(); Relayout(page) end })
    Kit.Tooltip(row.create, function() return { { L:Get("battlegrounds.layouts.create"), "text", true },
      { L:Get("battlegrounds.layouts.create_hint"), "textMuted", true } } end)
    row.remove = Kit.ConfirmButton(row, function() return L:Get("battlegrounds.layouts.remove") end, {
      confirm = function() return L:Get("battlegrounds.layouts.remove_confirm") end, timeout = 5,
      onArm = function() Relayout(page) end, onDisarm = function() Relayout(page) end,
      onConfirm = function() Profiles().Layouts.Remove(def.key); card:Refresh(); Relayout(page) end })
    Kit.Tooltip(row.remove, function() return { { L:Get("battlegrounds.layouts.remove"), "text", true },
      { L:Get("battlegrounds.layouts.remove_hint"), "textMuted", true } } end)
    row:SetActions({ row.remove, row.create })
    row:SetDivider(true)
    card.rows[i] = row
  end
  card.remember = Kit.SettingRow(card.body, { label = L:Get("battlegrounds.layouts.remember"),
    detail = L:Get("battlegrounds.layouts.remember_desc"), onChange = function(_, on)
      Profiles().Layouts.SetRemember(on)
      if Profiles().RefreshContext then Profiles().RefreshContext() end
    end })
  card.remember:SetDivider(false)
  page.sizes = card

  function card:Refresh()
    self:SetTitle(L:Get("battlegrounds.sizes.title"))
    self:SetHint(L:Format("battlegrounds.sizes.hint", { character = Options.CharacterName() }))
    local module = ns.Modules.Active("battlegrounds")
    local unrated = Core.On("allBGs")
    local current = Core.CurrentBracket and Core.CurrentBracket()
    local layouts = Profiles() and Profiles().Layouts
    local active = layouts and layouts.Active()
    for i, def in ipairs(Options.BATTLEGROUND_SIZES) do
      local row = self.rows[i]
      local blocked = def.unrated and not unrated
      local on = Core.SizeEnabled(def.key)
      local saved = layouts and layouts.Get(def.key) ~= nil
      row:SetLabel(L:Get(def.label))
      row:SetDetail(L:Get(def.detail))
      if not module then
        row:SetNote(L:Get("highground.general.enable_this_addon_and_reload.d99a6e"):match("^%s*(.-)$"))
      elseif blocked then
        row:SetNote(L:Format("battlegrounds.sizes.needs_unrated", { option = L:Get(UNRATED) }))
      else
        row:SetNote(L:Get(active == def.key and "battlegrounds.layouts.active" or saved and "battlegrounds.layouts.saved"
          or "battlegrounds.layouts.none"), saved and "accent" or "textMuted")
      end
      row:SetChecked(on, true)
      row:SetEnabled(module and not blocked)
      row:SetBadge(current == def.key and L:Get("battlegrounds.sizes.current") or nil)
      local usable = module and not blocked and on and layouts ~= nil
      row.create:SetShown(not saved); row.create:SetEnabled(usable)
      row.create:SetText(L:Get("battlegrounds.layouts.create"))
      row.remove:SetShown(saved); row.remove:SetEnabled(usable)
    end
    self.remember:SetLabel(L:Get("battlegrounds.layouts.remember"))
    self.remember:SetDetail(L:Get("battlegrounds.layouts.remember_desc"))
    self.remember:SetChecked(layouts == nil or layouts.Remember(), true)
    self.remember:SetEnabled(module and layouts ~= nil)
  end

  local layout = card.Layout
  function card:Layout(width)
    local inner = math.max(1, width - ns.Theme.Space("lg") * 2)
    local y = 0
    for _, row in ipairs(self.rows) do
      for _, button in ipairs({ row.create, row.remove }) do
        button:SetHeight(Kit.Scale(ns.Theme.Size("control"))); Kit.FitButton(button)
      end
      Kit.Place(row, "TOPLEFT", self.body, "TOPLEFT", 0, -y)
      y = y + row:Layout(inner)
    end
    Kit.Place(self.remember, "TOPLEFT", self.body, "TOPLEFT", 0, -y)
    y = y + self.remember:Layout(inner)
    return layout(self, width, y)
  end

  -- The badge and layout state follow the battleground you are in.
  local function Visible()
    if card:IsVisible() then card:Refresh(); page.LayoutFeatures() end
  end
  ns.Util.Events({ PLAYER_ENTERING_WORLD = Visible, ZONE_CHANGED_NEW_AREA = Visible, PVP_MATCH_STATE_CHANGED = Visible },
    "battleground size controls", "battlegrounds")
  Kit.OnLocale(card, function() card:Refresh(); if card:IsVisible() then page.LayoutFeatures() end end)
  card:Refresh()
  return card
end
