local t = dofile("../../tools/harness.lua")("reputation states")
local F = dofile("tests/fixture.lua")
local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")

for _, addon in ipairs({ "HighgroundReputation", "Highground" }) do
  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(addon .. " " .. build .. ": roster loading and filtered emptiness recover without stale rows", function()
      local s = F.new("Owner", { addon = addon, build = build, client = build == 40402 and "cata" or "retail",
        native = F.native("Owner"), runtime = addon == "Highground" and runtime or nil })
      local W, O = s.ns.Reputation, s.ns.Organizations
      F.community(s)
      local w = W.Open()
      W.UI.SetMode("organizations")
      w.search:SetText("Does not exist")
      t.equal(w.viewState.kind, "filtered", "organization search is not a membership failure")
      assert(w.empty.message:GetText():find("No matches", 1, true))
      W.UI.SetMode("members")
      t.equal(w.viewState.kind, "ready", "ready roster")
      s.rosterLoading = true; W.UI.Refresh()
      t.equal(select(2, O.Members("club:42")), "loading", "service exposes native pending state")
      t.equal(w.viewState.kind, "loading", "pending roster is not empty")
      assert(not w.rows[1]:IsShown() and not w.rows[1].action:IsEnabled())
      assert(not w.rows[1].action:GetScript("OnClick"), "hidden row loses its old action")
      w.search:SetText("missing")
      t.equal(w.viewState.kind, "loading", "loading wins over a search mismatch")
      s.rosterLoading = false; W.UI.Refresh()
      t.equal(w.viewState.kind, "filtered", "recovery respects current search")
      w.search:SetText("")
      t.equal(w.viewState.kind, "ready", "roster restored")
      assert(w.rows[1]:IsShown() and w.rows[1].action:IsEnabled())
      s.clubsLoading = true; W.UI.Refresh()
      t.equal(w.viewState.kind, "loading", "temporarily missing organization keeps member view pending")
      s.clubsLoading = false; W.UI.Refresh()
      s.env.C_Club.GetClubMembers = nil; W.UI.Refresh()
      t.equal(w.viewState.kind, "unavailable", "missing roster API is not a loading spinner")
      W.UI.SetMode("organizations"); s.clubsLoading = true; W.UI.Refresh()
      t.equal(select(2, O.List()), "loading", "subscription loading is explicit")
      t.equal(w.viewState.kind, "loading", "loading subscriptions do not tell members to rejoin")
      s.clubsLoading = false; W.UI.Refresh()
      t.equal(w.viewState.kind, "ready", "subscription recovery")
      s:assertHealthy()
    end)
  end
end
t.test("members show readable native roles and presence", function()
  for _, case in ipairs({ { "retail", 120100 }, { "cata", 40402 } }) do
    local guild = case[1] == "cata"
    local s = F.new("Owner", { client = case[1], build = case[2], guild = guild and "Test Guild" or nil,
      native = not guild and F.native("Owner") or nil })
    local W = s.ns.Reputation
    if guild then
      s.guildRoster = { { "Owner-Realm", 0 }, { "Officer-Realm", 1 }, { "Guildmember-Realm", 2, false } }
      s.env.C_GuildInfo = { GuildControlGetRankFlags = function(order) return { true, [22] = order == 2 } end }
      s.ns.Guild.ReadRoster()
    end
    F.community(s)
    local w = W.Open()
    W.UI.SetMode("members")
    local hints = {}
    for _, row in ipairs(w.rows) do if row:IsShown() then hints[row.title:GetText()] = row.hint:GetText() end end
    if guild then
      t.equal(hints.Officer, "Officer · Online", "officer rank")
      t.equal(hints.Guildmember, "Member · Offline", "offline member")
      t.equal(W.UI.MemberHint("owner", true, "guild"), "Guild master · Online", "guild master")
    else
      t.equal(hints.Moderator, "Moderator · Online", "community moderator")
      t.equal(hints.Member, "Member · Online", "community member")
      t.equal(W.UI.MemberHint("owner", true, "community"), "Owner · Online", "community owner")
      t.equal(W.UI.MemberHint("leader", false, "community"), "Leader · Offline", "community leader")
    end
    t.equal(W.UI.MemberHint(nil, false, "community"), "Role unavailable · Offline", "unknown role")
    w.search:SetText("officer")
    if guild then t.equal(w.viewState.kind, "ready", "readable roles are searchable") end
    s:assertHealthy()
  end
end)

t.test("pending guild roster requests are bounded while many consumers ask for members", function()
  local requests = 0
  local s = F.new("Owner", { client = "cata", guild = "Guild", configure = function(_, e)
    e.GuildRoster = function() requests = requests + 1 end
  end })
  s.guildRoster = {}; s.ns.Guild.Clear()
  local id = s.ns.Organizations.Guild().id
  requests = 0
  for _ = 1, 20 do
    t.equal(select(2, s.ns.Organizations.Members(id)), "loading", "empty guild data remains pending")
  end
  t.equal(requests, 1, "one request within retry window")
  s.now = s.now + 5
  s.ns.Organizations.Members(id)
  t.equal(requests, 2, "pending roster can retry later")
end)
t.finish("Reputation states: " .. t.tests .. " scenarios")
