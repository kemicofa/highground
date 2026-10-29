local _, ns = ...
local Core, P, Kit, Theme = ns.Core, ns.Options.Profiles, ns.Kit, ns.Theme
local activities = { { "bg", "Battlegrounds" }, { "arena", "Arena" }, { "world", "Open world" } }

function P.OpenAssignments()
  if not P.assignmentsWin then
    local w = Kit.Dialog("HighgroundProfileAssignments", { title = "AUTOMATIC SWITCHING", titleRole = "title",
      sub = "Profiles", width = 640, height = 430 + P.CONTEXT_HEIGHT, savedKey = "profileAssignments" })
    P.assignmentsWin = w
    w.hint = Theme.Text(w, "body", "textMuted")
    w.hint:SetPoint("TOPLEFT", 24, -78); w.hint:SetPoint("RIGHT", -24, 0)
    w.hint:SetHeight(64); w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP"); w.hint:SetWordWrap(true)
    w.enabled = Kit.Toggle(w, "Switch profiles automatically", { width = 560, onChange = function(_, on)
      Core.pos.autoProfiles = on
      P.lastAssignment = nil; P.Automatic(); w:Refresh()
    end })
    w.enabled:SetPoint("TOPLEFT", 24, -154)
    w.activities = {}
    for i, def in ipairs(activities) do
      local key = def[1]
      local label = Theme.Text(w, "body", "text")
      label:SetPoint("TOPLEFT", 24, -205 - (i - 1) * 42); label:SetText(def[2])
      local select = Kit.Select(w, { width = 350, menu = true, choices = {}, onChange = function(_, name)
        local ok = P.Assign(name, key)
        if ok then P.lastAssignment = nil; P.Automatic() end
        w:Refresh()
      end })
      select:SetPoint("TOPRIGHT", -24, -200 - (i - 1) * 42)
      w.activities[key] = select
    end
    w.status = Theme.Text(w, "body", "textMuted")
    w.status:SetPoint("TOPLEFT", 24, -330); w.status:SetPoint("RIGHT", -24, 0)
    w.status:SetJustifyH("LEFT"); w.status:SetWordWrap(true)
    w.done = Kit.Button(w, "Done", 110, 34, { tone = "accent", onClick = function() w:Hide() end })
    w.done:SetPoint("BOTTOMRIGHT", -24, 18)
    function w:Refresh()
      local choices = { { key = "none", label = "Keep current settings" } }
      for name in P.SortedPairs(Core.db.profiles or {}) do choices[#choices + 1] = { key = name, label = name } end
      local hasProfiles = #choices > 1
      self.hint:SetText(hasProfiles
        and "Choose a profile for each activity. These choices apply to this character and current specialization. Other characters keep their own choices."
        or "Save a named profile on the Profiles page first, then return here to choose when it should load.")
      self.enabled:SetChecked(Core.pos.autoProfiles, true)
      self.enabled:SetEnabled(hasProfiles or Core.pos.autoProfiles)
      for _, def in ipairs(activities) do
        local who, context = P.Context(def[1])
        local name = Core.db.profileAssignments and Core.db.profileAssignments[who] and Core.db.profileAssignments[who][context]
        local select = self.activities[def[1]]
        select:SetChoices(choices)
        select:SetValue(name and Core.db.profiles and Core.db.profiles[name] and name or "none", true)
        select:SetEnabled(hasProfiles)
      end
      self.status:SetText(hasProfiles and (Core.pos.autoProfiles and "Changes save automatically. Switching is on."
        or "Changes save automatically. Switching is off.") or "No saved profiles yet.")
    end
    w:HookScript("OnShow", function() w:Refresh() end)
    P.AttachContext(w, { w.done })
    ns.Util.Events({ PLAYER_SPECIALIZATION_CHANGED = function() if w:IsShown() then w:Refresh() end end,
      ACTIVE_TALENT_GROUP_CHANGED = function() if w:IsShown() then w:Refresh() end end }, "profile assignment window")
  end
  P.assignmentsWin:Refresh(); P.assignmentsWin:Show()
  return P.assignmentsWin
end
