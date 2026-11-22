local _, ns = ...
local Bounty, Theme, Kit = ns.Bounty, ns.Theme, ns.Kit
local Share, Board = Bounty.Share, Bounty.Board

---------------------------------------------------------------------------
-- Clicking a chat link opens the board and a preview. Only the Import
-- button writes a personal bounty; Close, Cancel and Escape discard it.
---------------------------------------------------------------------------
local function Build()
  if Share.win then return Share.win end
  local w = ns.Localization.BindWidget(Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyImport", {
    title = ns.Locale:Get("shared.import.import_bounty.95c1ac"), sub = ns.Locale:Get("shared.import.personal_bounty.3dc054"), width = 520, height = 390,
    strata = "FULLSCREEN_DIALOG", accent = "gold", alpha = 1, child = true,
    onClose = function(self) self.payload, self.existing = nil, nil end,
  }), { title = "shared.import.import_bounty.95c1ac", sub = "shared.import.personal_bounty.3dc054" })
  Share.win = w
  w.details = Theme.Text(w, "body", "text")
  w.details:SetPoint("TOPLEFT", 18, -76)
  w.details:SetPoint("RIGHT", w, "RIGHT", -18, 0)
  w.details:SetHeight(164)
  w.details:SetJustifyH("LEFT")
  w.details:SetJustifyV("TOP")
  w.notice = Theme.Text(w, "body", "textMuted")
  w.notice:SetPoint("TOPLEFT", 18, -246)
  w.notice:SetPoint("RIGHT", w, "RIGHT", -18, 0)
  w.notice:SetHeight(90)
  w.notice:SetJustifyH("LEFT")
  w.notice:SetJustifyV("TOP")
  w.cancel = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.root.cancel.77dfd2"), 84, 26, { onClick = function() w:Hide() end }), "highground.root.cancel.77dfd2")
  w.cancel:SetPoint("BOTTOMLEFT", 18, 16)
  w.import = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.root.import.d6fbc9"), 180, 26, { tone = "gold", onClick = function() Share.Import() end }), "highground.root.import.d6fbc9")
  w.import:SetPoint("BOTTOMRIGHT", -18, 16)
  return w
end

function Share.ShowImport(payload)
  local b, err = Share.Decode(payload)
  if not b then return Bounty.Say(err) end
  local board = Board.Build()
  if ns.Hub then ns.Hub.Release(board) end
  board:Show()
  Board.Refresh()
  local w = Build()
  w.payload = payload
  w.existing = Bounty.Personal()[Bounty.Key(b.name)]
  local existing = Bounty.Entry(b.name)
  w.details:SetText(ns.Locale:Format("shared.import.audience_value2_target_value4_reward_value6_posted.f7ec79", { value2 = (b.importAudience or "private"):upper(), value4 = ns.Core.DisplayName(b.name), value6 = Bounty.GoldText(b), value8 = ns.Core.DisplayName(b.by), value10 = (b.note or ns.Locale:Get("macros.macros.none.6eef66")), value11 = (b.intel and b.intel.origin and (ns.Locale:Format("shared.import.first_spotted_value2.5267e4", { value2 = Bounty.Sightings.Place(b.intel.origin) })) or "") }))
  local notice = ns.Locale:Get("shared.import.import_to_your_personal_bounties_guild_and.f84c9b")
  if w.existing then
    notice = ns.Locale:Format("shared.import.replace_your_personal_bounty_value2_current_note.78a349", { value2 = Bounty.GoldText(w.existing), value5 = (w.existing.note or ns.Locale:Get("macros.macros.none.6eef66")) })
  elseif existing then
    local audience = existing.organization and "community" or existing.state == "public" and "shared" or "guild"
    notice = ns.Locale:Format("shared.import.you_already_have_a_audience_bounty_on.4e501f", { audience = audience })
  end
  w.notice:SetText(notice)
  Theme.Paint(w.notice, w.existing and "warning" or "textMuted")
  w.import:SetText(w.existing and ns.Locale:Get("shared.import.replace_personal_bounty.c1823d") or ns.Locale:Get("highground.root.import.d6fbc9"))
  Bounty.Widgets.ShowWindow(w)
end

function Share.Import()
  local w = Share.win
  if not (w and w:IsShown() and w.payload) then return end
  local b, err = Share.Decode(w.payload)
  if not b then return Bounty.Say(err) end
  -- A bounty added/removed while the preview was open needs a fresh
  -- confirmation, with the new replacement details on screen.
  if Bounty.Personal()[Bounty.Key(b.name)] ~= w.existing then
    Share.ShowImport(w.payload)
    return Bounty.Say(ns.Locale:Get("shared.import.your_personal_bounty_changed_review_the_import.0c7897"))
  end
  local imported
  imported, err = Bounty.Add(b.name, b.gold, b.note, b)
  if not imported then return Bounty.Say(err) end
  imported.by, imported.importAudience = b.by, b.importAudience
  Bounty.Sightings.Merge(imported, b.intel)
  w:Hide()
  Board.SetTab("mine")
  Board.win.search:SetText(ns.Core.DisplayName(imported.name))
  Bounty.Emit("updated")
  Bounty.Say(ns.Locale:Format("shared.import.imported_value2_value4_as_a_personal_bounty.330e3e", { value2 = ns.Core.DisplayName(imported.name), value4 = Bounty.GoldText(imported) }))
end
