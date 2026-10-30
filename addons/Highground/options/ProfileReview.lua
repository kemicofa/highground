local _, ns = ...
local P, Kit, Theme = ns.Options.Profiles, ns.Kit, ns.Theme
local Share = P.Chat

function Share.Progress(message, failed)
  local w = Share.win
  if not w then return end
  w.status:SetText(message or "")
  Theme.Paint(w.status, failed and "danger" or "textMuted")
end

local function Build()
  if Share.win then return Share.win end
  local w = Kit.Dialog("HighgroundProfileReview", { title = "SHARED PROFILE", titleRole = "title",
    sub = "Review before applying", width = 640, height = 590 + P.CONTEXT_HEIGHT, onClose = function() Share.Cancel() end })
  Share.win = w
  w.summary = Theme.Text(w, "body", "text")
  w.summary:SetPoint("TOPLEFT", 24, -84); w.summary:SetPoint("TOPRIGHT", -24, -84)
  w.summary:SetHeight(300); w.summary:SetJustifyH("LEFT"); w.summary:SetJustifyV("TOP"); w.summary:SetWordWrap(true)
  w.name = Kit.Input(w, 380, "Save a copy as")
  w.name:SetPoint("TOPLEFT", 24, -420)
  w.status = Theme.Text(w, "body", "textMuted")
  w.status:SetPoint("BOTTOMLEFT", 24, 78); w.status:SetPoint("BOTTOMRIGHT", -24, 78)
  w.status:SetHeight(52); w.status:SetJustifyH("LEFT"); w.status:SetJustifyV("BOTTOM"); w.status:SetWordWrap(true)
  w.cancel = Kit.Button(w, "Close", 90, 34, { onClick = function() w:Hide() end })
  w.cancel:SetPoint("BOTTOMLEFT", 24, 24)
  w.apply = Kit.Button(w, "Use this setup", 210, 34, { tone = "accent", onClick = function()
    if not w.text then return end
    local ok, message = P.ImportText(w.text)
    Share.Progress(message, not ok)
    if ok then w.apply:SetEnabled(false) end
  end })
  w.apply:SetPoint("BOTTOMRIGHT", -24, 24)
  w.save = Kit.Button(w, "Save a copy", 200, 34, { onClick = function()
    if not w.text then return end
    local name = P.CleanName(w.name:GetText())
    if not name then return Share.Progress("Enter a name for this profile.", true) end
    if ns.Core.db.profiles and ns.Core.db.profiles[name] then
      return Share.Progress("That name is already saved. Choose a new name for this copy.", true)
    end
    local ok, message = P.SaveImported(w.text, name)
    Share.Progress(message, not ok)
  end })
  w.save:SetPoint("RIGHT", w.apply, "LEFT", -12, 0)
  P.AttachContext(w, { w.cancel, w.apply, w.status })
  return w
end

-- The transfer must pass the same validation as a clipboard import before
-- either action is offered. The name is editable and never overwrites a copy.
function Share.Review(text, source, label)
  local w = Build()
  w.text = nil
  w.save:SetEnabled(false); w.apply:SetEnabled(false)
  w.name:SetText(label or "Shared setup")
  w.summary:SetText("Shared by " .. source .. "\n\nWaiting for the profile. Keep this window open to receive it.")
  Share.Progress("Requesting profile…")
  w:Show()
  if not text then return end
  local snap, err = P.ParseString(text)
  if not snap then return Share.Progress("Cannot import this profile: " .. err, true) end
  local prepared, problem, _, skipped = P.Prepare(snap)
  if not prepared then return Share.Progress("Cannot import this profile: " .. problem, true) end
  w.text = text
  local name = P.CleanName(snap.name or label) or "Shared setup"
  local base, suffix = name, 2
  while ns.Core.db.profiles and ns.Core.db.profiles[name] do
    name = base:sub(1, 33) .. " (" .. suffix .. ")"; suffix = suffix + 1
  end
  w.name:SetText(name)
  local description = "Includes targeting scores, weights, specialization ratings and targeting behavior only."
  if prepared.setup then
    local n = 0
    for _, on in pairs(prepared.setup.features) do if on then n = n + 1 end end
    local modes = { essential = "Essentials", everything = "Everything", critical = "Critical only", objectives = "Objectives", quiet = "Text only" }
    local alerts = modes[prepared.setup.alerts.mode or "everything"]
    description = n .. " features enabled · Alerts: " .. alerts .. "\n" .. ns.Options.PROFILE_CONTENTS
  end
  w.summary:SetText("Shared by " .. source .. "\n\n" .. description .. "\n\n" .. ns.Options.PROFILE_EXCLUSIONS
    .. "\n\nSave a copy keeps your current setup. Use this setup replaces the included settings.")
  Share.Progress(skipped > 0 and "Some settings are unavailable on this game version and will be skipped."
    or "Use this setup replaces your current settings.")
  w.save:SetEnabled(true); w.apply:SetEnabled(true)
end
