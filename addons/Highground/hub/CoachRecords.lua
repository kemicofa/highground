local _, ns = ...
local C = ns.Onboarding.Coach

function C.RecordSteps()
  local H, N = ns.MatchHistory, C.Native
  local data = C.matchSample or {}; C.matchSample = data
  data.records = {
    { id = "warsong", name = "Warsong Gulch", result = "Win", character = "Example", game = "Sample",
      started = time() - 3600, duration = 840, specName = "Example", stats = { killingBlows = 3, deaths = 2 },
      events = { { at = 0, text = "Joined Warsong Gulch" }, { at = 242, text = "Your team captured the flag" }, { at = 840, text = "Victory" } } },
    { id = "arathi", name = "Arathi Basin", result = "Left early", character = "Example", game = "Sample",
      started = time() - 7200, duration = 250, specName = "Example", stats = {},
      events = { { at = 0, text = "Joined Arathi Basin" }, { at = 250, text = "Left before the result was observed" } } },
  }
  data.entries = function()
    local entries, summary = H.Entries(data.records); data.summary = "Sample records · " .. summary
    return entries
  end
  local function Open()
    local w = H.Build(data); w:Open(); N.Track(w); N.Fit(w)
    return w
  end
  local function Context() return data.win end
  return {
    { id = "find", title = "Find a previous match", text = "Search by map, result or character. These sample records use the same history window as your own matches.",
      enter = Open, target = function() return data.win.search end, context = Context },
    { id = "result", title = "Choose a match to inspect", text = "Select Warsong Gulch or Arathi Basin. Left early means the result was not observed; missing stats stay missing.",
      enter = Open, target = function() return data.win.rows[1] end, context = Context },
    { id = "timeline", title = "Open the recorded timeline", text = "Full timeline lists the objective events observed during the selected match.",
      enter = Open, target = function() return data.win.actions[1] end, context = Context,
      requireAction = true, advance = function() return data.timeline and data.timeline:IsVisible() end, hint = "Click Full timeline." },
    { id = "events", title = "Follow what happened", text = "Times are measured from joining the match. You can select and copy these events.",
      enter = function()
        if data.timeline and data.timeline:IsVisible() then N.Track(data.timeline); N.Fit(data.timeline)
        else Open() end
      end,
      target = function() return data.timeline and data.timeline:IsVisible() and data.timeline.box or data.win.actions[1] end,
      context = function() return data.timeline and data.timeline:IsVisible() and data.timeline or data.win end },
  }
end

-- A separate source drives the native Reputation windows. Only these local
-- examples can change; no live model, listener, transport or handler is swapped.
local W, K = ns.Reputation, ns.Kit
local R = { provider = { ready = true, UI = { mode = "organizations", page = 1 } } }
C.ReputationSample = R
local P, U = R.provider, R.provider.UI
for _, key in ipairs({ "CATEGORIES", "REPLY_INTERVALS", "DEFAULT_REPLY", "Text", "Copy", "Target", "CategoryText" }) do P[key] = W[key] end
U.Label = W.UI.Label
function U.Dialog(key, title, width, height)
  local f = W.UI.Dialog(key, title, width, height, true)
  f:SetSub("Sample organization · Nothing is sent")
  f:HookScript("OnShow", function() C.Native.Track(f); C.Native.Fit(f) end)
  return f
end
function U.Refresh() return W.UI.Refresh(P) end
function U.RefreshDialogs() return W.UI.RefreshDialogs(P) end
function U.CommunityChoices(_, all) return W.UI.CommunityChoices(P, all) end
function U.Result(f, value, err) return W.UI.Result(f, value, err, P) end
function U.GetRouter() return W.UI.GetRouter(P) end
function U.SetMode(mode, organization) return W.UI.SetMode(mode, organization, P) end
function U.GoPage(delta) return W.UI.GoPage(delta, P) end
function U.BuildOverview(f) return W.UI.BuildOverview(f, P) end
function U.RefreshOverview(_, org, c) return W.UI.RefreshOverview(P, org, c) end
function P.Build() return W.Build(P) end
function P.Open() return W.Open(false, P) end
function P.Joined(c) return R.data and c == R.data.community and c.enabled == true end
function P.Get(id) return R.data and (not id or id == R.data.community.id) and R.data.community or nil end
function P.List() return P.Joined(P.Get()) and { P.Get() } or {} end
function P.Name() return "Silverwing Scouts · Sample" end
function P.Role(c) return P.Joined(c) and (R.data.moderator and "Officer" or "Member") or nil end
function P.CanModerate(c) return P.Joined(c) and c.activated == true and R.data.moderator == true end
function P.MemberCount() return 3 end
function P.Status() return R.data.message or "SAMPLE · Reports, decisions and settings stay in this guide." end
function P.Changed() U.Refresh(); U.RefreshDialogs() end
function P.Say(message) R.data.message = message; U.Refresh() end
function P.Enable() R.data.community.enabled, R.data.community.activated = true, true; P.Changed(); return R.data.community end
function P.Follow() R.data.community.enabled = true; P.Changed(); return R.data.community end
function P.Discover() end
function P.Availability()
  if not P.Joined(P.Get()) then return { code = "paused", label = "Off on this account", message = "Enable the sample explicitly in Overview. Nothing is sent." } end
  return { ready = true, label = "Enabled · Moderator online", message = "A sample moderator can receive this proposal. Nothing is sent." }
end
function P.DeliveryText() return "Received · Awaiting review" end
function P.Disable() R.data.community.enabled = false; P.Changed() end
function P.RequestSync() P.Say("Sample organization is up to date. No sync request was sent.") end
function P.SendReports() end
function P.OpenNative() P.Say("Sample guild. Real membership and roles are managed in WoW's Guild & Communities.") end
function P.ReplyInterval()
  for _, choice in ipairs(P.REPLY_INTERVALS) do if P.db.settings.replyInterval == choice.key then return choice.key end end
  return 0
end
P.organizations = {
  CanModerate = function() return R.data.moderator == true end,
  Role = function() return R.data.moderator and "moderator" or "member" end,
  List = function() return { { id = P.Get().id, name = P.Name(), kind = "guild" } } end,
  Get = function(id) return id == P.Get().id and { id = id, name = P.Name(), kind = "guild" } end,
  Members = function() return { { name = "Sample Member-Example", role = "Member", online = true },
    { name = "Sample Officer-Example", role = "Officer", online = true }, { name = "Sample Scout-Example", role = "Member", online = false } } end,
}
function P.FindCase(_, target)
  local row = R.data.row
  return row and W.Same(row.target, target) and row or nil
end
function P.OwnReport(c, target)
  local row = P.FindCase(c, target)
  return row and row.reports.sample or nil
end
function P.Rows(_, mode)
  local row = R.data.row
  return row and (mode == "history" or mode == "proposals" and row.pending > 0 or mode == "blacklist" and row.active)
    and { row } or {}
end
function P.Submit(c, target, categories, note)
  if not P.Joined(c) then return nil, "Enable the sample organization first." end
  if not W.ValidTarget(target) then return nil, "Select an exact player identity." end
  categories = W.Categories(categories)
  if not categories then return nil, "Choose at least one category." end
  local row = P.FindCase(c, target) or { target = W.Copy(target), reports = {}, actions = {}, count = 1 }
  local report = { by = "Sample Member-Example", categories = categories, note = W.Text(note, 280), delivery = "received in sample" }
  row.reports.sample, row.pending, row.state = report, 1, row.active and "blacklisted" or "proposed"
  R.data.row, R.data.submissions = row, R.data.submissions + 1
  P.Changed(); return report
end
function P.Decide(c, target, kind, categories, note)
  if not P.CanModerate(c) then return nil, "Only a sample officer can do this." end
  if not W.ValidTarget(target) then return nil, "Select an exact player identity." end
  if not ({ ban = true, revoke = true, dismiss = true })[kind] then return nil, "Unknown moderation action." end
  categories, note = W.Categories(categories), W.Text(note, 280)
  if kind == "ban" and not categories then return nil, "Choose at least one category." end
  if kind ~= "ban" and note == "" then return nil, "A reason is required." end
  local row = P.FindCase(c, target) or { target = W.Copy(target), reports = {}, actions = {}, count = 0 }
  local op = { id = "sample:" .. (#row.actions + 1), clock = #row.actions + 1, kind = kind,
    at = time(), by = "Sample Officer-Example", categories = categories or {}, note = note }
  row.actions[#row.actions + 1] = op
  if kind == "ban" then row.active = op elseif kind == "revoke" then row.active = nil end
  row.pending, row.state = 0, row.active and "blacklisted" or kind == "revoke" and "revoked" or "dismissed"
  R.data.row, R.data.decisions = row, R.data.decisions + 1
  P.Changed(); return op
end
function P.OpenReport(target, community)
  W.OpenReport(target or R.data.target, community, P)
  if not P.OwnReport(community, target or R.data.target) then
    U.report.categories.other:SetChecked(true, true)
    U.report.note:SetText("Example encounter for learning the report workflow.")
  end
end
function P.OpenDetails(c, row) return W.OpenDetails(c, row, P) end
function P.OpenReason(c, target, kind) return W.OpenReason(c, target, kind, P) end
function R.Stop()
  W.UI.CloseDialogs(P)
  if U.window then K.Windows.Forget(U.window); U.window:Hide() end
  R.data = nil
end
function R.Ensure()
  if R.data then return end
  R.data = { community = { id = "guild:sample@guide", enabled = false, activated = true, synced = true }, submissions = 0, decisions = 0,
    target = assert(W.Target(ns.Caps.hideRealmNames and "Practice Player" or "PracticePlayer", "Example")) }
  P.db = { settings = {} }
  U.mode, U.page = "organizations", 1
  if U.router then U.router:Reset({ name = "organizations" }) end
end
local function Visible(f) return f and f:IsVisible() end
local function DetailsClosed() return not Visible(U.details) and not Visible(U.reason) and not Visible(U.report) end
local function Context()
  for _, key in ipairs({ "reason", "report", "details", "window" }) do if Visible(U[key]) then return U[key] end end
end
local function Open(mode, moderator)
  R.Ensure()
  R.data.moderator = moderator == true
  if mode ~= "organizations" then P.Enable() end
  P.Open(); U.SetMode(mode, P.Get().id); C.Native.Track(U.window); C.Native.Fit(U.window)
end
local function Proposal()
  if not R.data.row or R.data.row.pending == 0 then
    P.Submit(P.Get(), R.data.target, { other = true }, "Example encounter for learning the report workflow.")
  end
end
local function Decision()
  if not R.data.row or not R.data.row.active then
    Proposal(); P.Decide(P.Get(), R.data.row.target, "ban", { other = true }, "Reviewed example encounter.")
  end
end
local function Details(approved)
  if Visible(U.details) then return end
  Open(approved and "blacklist" or "proposals", true)
  if approved then Decision() else Proposal() end
  P.OpenDetails(P.Get(), R.data.row)
end
function C.ReputationSteps()
  local function Step(id, title, text, enter, target, advance, hint)
    return { id = id, title = title, text = text, enter = enter, target = target, context = Context,
      requireAction = advance ~= nil, advance = advance, hint = hint }
  end
  return {
    Step("organization", "Choose your guild or community", "Organizations lists your native guild and communities. Open shows their Overview without enabling or resuming anything. On Forever, discovery and sharing stay within your ruleset.",
      function() Open("organizations"); P.Disable() end, function() return U.window.rows[1].action end,
      function() return U.mode == "overview" end, "Click Open. This sample never sends reports."),
    Step("participation", "Choose when to participate", "Overview keeps participation controls together. This sample is paused: resume explicitly to share reports and use its blacklist. Officers and community moderators can also enable Reputation here.",
      function() Open("overview"); P.Disable() end, function() return U.window.disable end,
      function() return P.Joined(P.Get()) end, "Click Enable on this account."),
    Step("report_open", "Open the report form", "Report player opens the same form used from a player's portrait or chat name.",
      function() Open("blacklist") end, function() return U.window.add end,
      function() return Visible(U.report) end, "Click Report player."),
    Step("proposal", "Submit a proposal", "Check the player, category and note, then submit. A member's report awaits a moderator's decision.",
      function()
        R.Ensure(); R.submissionStart = R.data.submissions
        if not Visible(U.report) then Open("blacklist"); P.OpenReport(nil, P.Get()) end
      end, function() return U.report.submit end,
      function()
        if not Visible(U.report) then return R.data.submissions > R.submissionStart and "proposals_open" or "report_open" end
      end, "Edit the sample report, then click Submit proposal."),
    Step("proposals_open", "Find pending reports", "The Proposals tab lists reports awaiting review. Click it to find the report you submitted.",
      function() Open("blacklist"); Proposal() end, function() return U.window.tabs.proposals end,
      function() return U.mode == "proposals" end, "Click Proposals."),
    Step("moderation", "Enable moderation when you are ready", "Sample officer view: if you already participate but moderation is not enabled yet, Overview offers Enable moderation. Only native officers, owners, leaders and moderators can take this action.",
      function() Open("overview", true); P.Get().activated = false; P.Changed() end,
      function() return U.window.openReports end,
      function() return P.CanModerate(P.Get()) and U.mode == "proposals" end, "Click Enable moderation. Your real role stays unchanged."),
    Step("details_open", "Inspect the proposal", "Sample officer view: Details opens the player's reports and moderation history. Your real role stays unchanged.",
      function() Open("proposals", true); Proposal() end, function() return U.window.rows[1].action end,
      function() return Visible(U.details) end, "Click Details."),
    Step("review", "Review before approving", "Read the report and its note. Review / blacklist opens the decision form; Dismiss proposals asks for a reason.",
      function() Details(false) end, function() return Visible(U.reason) and U.reason.submit or U.details.approve end,
      function()
        if Visible(U.report) then return "approve" end
        if DetailsClosed() then return R.data.row.pending == 0 and "overview_open" or "details_open" end
      end, function() return Visible(U.reason) and "Enter a reason, then save or close to return." or "Click Review / blacklist." end),
    Step("approve", "Save the decision", "An officer chooses the approved categories and public explanation. Save this sample decision to see the result.",
      function()
        R.Ensure(); R.decisionStart = R.data.decisions
        if not Visible(U.report) then Details(false); P.OpenReport(R.data.row.target, P.Get()) end
      end, function() return U.report.submit end,
      function()
        if not Visible(U.report) then return R.data.decisions > R.decisionStart and "return" or "review" end
      end, "Click Save blacklist decision."),
    Step("return", "Return to the list", "The sample decision is recorded. Close this player's history to return to the organization.",
      function()
        R.Ensure(); if not Visible(U.details) then Open("proposals", true); Decision() end
        Details(true); P.OpenDetails(P.Get(), R.data.row)
      end, function() return Visible(U.reason) and U.reason.submit or U.details.close end,
      function() if DetailsClosed() then return R.data.row.active and "blacklist_open" or "overview_open" end end,
      "Click the window's close button."),
    Step("blacklist_open", "Find approved entries", "Blacklist contains approved decisions. A proposal alone does not put someone on this list.",
      function() Open("proposals", true); Decision() end, function() return U.window.tabs.blacklist end,
      function() return U.mode == "blacklist" end, "Click Blacklist."),
    Step("decision", "Read the approved record", "Open Details to see the public reason and the recorded decision together.",
      function() Open("blacklist", true); Decision() end, function() return U.window.rows[1].action end,
      function() return Visible(U.details) end, "Click Details."),
    Step("history", "Decisions keep their history", "The history records who approved the entry, when and why. Revoke asks for a reason and records the removal. Close this window to continue.",
      function() Details(true) end, function() return Visible(U.reason) and U.reason.submit or U.details.close end,
      DetailsClosed, function() return Visible(U.reason) and "Enter a reason, then save or close to return." or "Close the player history." end),
    Step("overview_open", "Manage participation in one place", "Return to Overview to pause this organization, check for updates or open its membership settings in WoW.",
      function() Open("blacklist", true) end, function() return U.window.tabs.overview end,
      function() return U.mode == "overview" end, "Click Overview."),
    Step("pause", "Turn participation off without losing records", "Disabling stops this organization's sharing and filtering on your account. Reports and history are kept. Other members keep their own settings.",
      function() Open("overview", true) end, function() return U.window.disable end,
      function() return not P.Joined(P.Get()) end, "Click Disable on this account."),
    Step("resume", "Turn participation back on when you choose", "The same control turns participation back on. Opening an organization or report never enables a disabled organization by itself.",
      function() Open("overview", true); P.Disable() end, function() return U.window.disable end,
      function() return P.Joined(P.Get()) end, "Click Enable on this account."),
    Step("settings_open", "Choose your personal preferences", "Preferences controls chat filtering, whisper replies and player tooltips for every organization on this account.",
      function() Open("blacklist", true); if not R.data.row then Decision() end end, function() return U.window.tabs.settings end,
      function() return U.mode == "settings" end, "Click Preferences."),
    Step("settings", "Try the display settings", "These are the real settings controls with sample values. Try a switch, reply frequency or reply message. Your saved preferences stay unchanged.",
      function() Open("settings", true); U.window.settings:SetVerticalScroll(0) end,
      function() return U.window.toggles.filter end, nil, "Done closes the sample. No reports or whispers were sent."),
  }
end
