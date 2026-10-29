local _, ns = ...
local Bounty, Theme, Kit = ns.Bounty, ns.Theme, ns.Kit
local Share, Board = Bounty.Share, Bounty.Board

---------------------------------------------------------------------------
-- Clicking a chat link opens the board and a preview. Only the Import
-- button writes a personal bounty; Close, Cancel and Escape discard it.
---------------------------------------------------------------------------
local function Build()
  if Share.win then return Share.win end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyImport", {
    title = "IMPORT BOUNTY?", sub = "PERSONAL BOUNTY", width = 520, height = 390,
    strata = "FULLSCREEN_DIALOG", accent = "gold", alpha = 1,
    onClose = function(self) self.payload, self.existing = nil, nil end,
  })
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
  w.cancel = Kit.Button(w, "Cancel", 84, 26, { onClick = function() w:Hide() end })
  w.cancel:SetPoint("BOTTOMLEFT", 18, 16)
  w.import = Kit.Button(w, "Import", 180, 26, { tone = "gold", onClick = function() Share.Import() end })
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
  w.details:SetText("Target: " .. b.name .. "\nReward: " .. Bounty.GoldText(b)
    .. "\nPosted by: " .. b.by .. "\nNote: " .. (b.note or "None"))
  local notice = "Import to your personal bounties. This alerts only you; guild submission is a separate action."
  if w.existing then
    notice = "Replace your personal bounty (" .. Bounty.GoldText(w.existing) .. ")?"
      .. "\nCurrent note: " .. (w.existing.note or "None") .. "\nThe imported bounty alerts only you."
  elseif Bounty.Entry(b.name) then
    notice = "You already have a guild bounty on this target. Import adds a personal copy for your alerts."
  end
  w.notice:SetText(notice)
  Theme.Paint(w.notice, w.existing and "warning" or "textMuted")
  w.import:SetText(w.existing and "Replace personal bounty" or "Import")
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
    return Bounty.Say("your personal bounty changed; review the import again")
  end
  local imported
  imported, err = Bounty.Add(b.name, b.gold, b.note)
  if not imported then return Bounty.Say(err) end
  imported.by = b.by
  w:Hide()
  Board.tab, Board.offset = "mine", 0
  Board.win.search:SetText(imported.name)
  Bounty.Emit("updated")
  Bounty.Say("imported " .. ns.Core.DisplayName(imported.name) .. " (" .. Bounty.GoldText(imported) .. ") as a personal bounty")
end
