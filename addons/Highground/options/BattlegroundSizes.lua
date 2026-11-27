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

function Options.CharacterName()
  return Core.me.name or UnitName("player") or ""
end

Options.featureWidgets.battlegroundSizes = function(parent, page)
  local card = Kit.SectionCard(parent)
  card.rows = {}
  for i, def in ipairs(Options.BATTLEGROUND_SIZES) do
    local row = Kit.SettingRow(card.body, { label = L:Get(def.label), detail = L:Get(def.detail),
      onChange = function(_, on) Core.SetSizeEnabled(def.key, on) end })
    row.size = def.key
    row:SetDivider(i < #Options.BATTLEGROUND_SIZES)
    card.rows[i] = row
  end
  page.sizes = card

  function card:Refresh()
    self:SetTitle(L:Get("battlegrounds.sizes.title"))
    self:SetHint(L:Format("battlegrounds.sizes.hint", { character = Options.CharacterName() }))
    local module = ns.Modules.Active("battlegrounds")
    local unrated = Core.On("allBGs")
    local current = Core.CurrentBracket and Core.CurrentBracket()
    for i, def in ipairs(Options.BATTLEGROUND_SIZES) do
      local row = self.rows[i]
      local blocked = def.unrated and not unrated
      row:SetLabel(L:Get(def.label))
      row:SetDetail(L:Get(def.detail))
      row:SetNote(not module and (L:Get("highground.general.enable_this_addon_and_reload.d99a6e"):match("^%s*(.-)$"))
        or blocked and L:Format("battlegrounds.sizes.needs_unrated", { option = L:Get(UNRATED) }) or nil)
      row:SetChecked(Core.SizeEnabled(def.key), true)
      row:SetEnabled(module and not blocked)
      row:SetBadge(current == def.key and L:Get("battlegrounds.sizes.current") or nil)
    end
  end

  local layout = card.Layout
  function card:Layout(width)
    local inner = math.max(1, width - ns.Theme.Space("lg") * 2)
    local y = 0
    for _, row in ipairs(self.rows) do
      Kit.Place(row, "TOPLEFT", self.body, "TOPLEFT", 0, -y)
      y = y + row:Layout(inner)
    end
    return layout(self, width, y)
  end

  -- The badge follows the battleground you are in.
  local function Visible()
    if card:IsVisible() then card:Refresh(); page.LayoutFeatures() end
  end
  ns.Util.Events({ PLAYER_ENTERING_WORLD = Visible, ZONE_CHANGED_NEW_AREA = Visible, PVP_MATCH_STATE_CHANGED = Visible },
    "battleground size controls", "battlegrounds")
  Kit.OnLocale(card, function() card:Refresh(); if card:IsVisible() then page.LayoutFeatures() end end)
  card:Refresh()
  return card
end
