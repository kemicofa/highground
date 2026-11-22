local _, ns = ...
local B, Kit, U = ns.Bounty, ns.Kit, ns.Util
local D, provider = B.Preview, { name = "Test" }

-- Tests use the live views with a session-local provider. The guide owns
-- teaching and progression; neither session writes to the bounty stores.
local function ReleaseAlerts()
  for _, owner in ipairs({ B.Poster, B.Matches, B.Proof }) do
    local w = owner.previewWin
    if w then
      w:SetParent(UIParent); w.tourDocked = nil; w:SetScale(1)
      w:SetMovable(owner ~= B.Matches); w:SetClampedToScreen(true)
      w:SetFrameStrata("FULLSCREEN_DIALOG")
      w:SetFrameLevel(owner == B.Poster and 100 or owner == B.Matches and 105 or 110)
      if owner == B.Poster then Kit.PlaceWindow(w, "bountyPoster", { "TOPRIGHT", "TOPRIGHT", -36, -110 })
      elseif owner == B.Proof then Kit.PlaceWindow(w, "bountyKilled", { "TOPRIGHT", "TOPRIGHT", -36, -90 })
      else Kit.PlaceWindow(w, nil, { "TOPLEFT", "TOPLEFT", 36, -110 }) end
    end
  end
end

function D.EndTest()
  if ns.Nearby and ns.Nearby.test and ns.Nearby.test.owner == D then
    ns.Nearby.test = nil; ns.Nearby.Update()
  end
  if D.testing and provider.board then provider.board.router:Reset("mine") end
  D.testing = nil
  ReleaseAlerts()
end

local function Samples()
  local state, out = D.Ensure(), {}
  for _, key in ipairs({ "create", "nearby", "guild", "shared" }) do
    if state.samples[key] then out[#out + 1] = state.samples[key] end
  end
  state.boardSamples = state.boardSamples or D.BoardSamples()
  for _, sample in ipairs(state.boardSamples) do out[#out + 1] = sample end
  return out
end

local function Use(row)
  for _, sample in ipairs(Samples()) do
    if sample[1] == row then
      D.state.samples.board = sample
      D.Prepare("board")
      return sample
    end
  end
end

local function Tracking(row)
  local interests = D.state.interests or {}
  return row.personal ~= nil or interests[B.Key(row.name)] == "tracking"
end

function provider.rows(tab, query, pending)
  if not D.testing then return {} end
  local out, seen = {}, {}
  for _, sample in ipairs(Samples()) do
    local row = sample[1]
    row.tracking = Tracking(row)
    local match = row.scope == tab or tab == "mine" and row.tracking
    if match and not seen[row.name] and (not pending or row.state == "pending")
      and (not query or query == "" or (row.name .. " " .. row.owner):lower():find(query:lower(), 1, true)) then
      out[#out + 1], seen[row.name] = row, true
    end
  end
  return out
end

function provider.primary(row)
  return row.personal and "Edit reward" or row.tracking and "Stop tracking" or "Start tracking"
end
function provider.runPrimary(row)
  if not row then return end
  local sample = Use(row)
  if row.personal then
    D.state.editingSample = sample
    D.state.draft, D.state.draftMode = B.Public.Copy(D.bounty), "personal"
    D.OpenCreate("personal")
  else D.Interest(row.tracking and "ignored" or "tracking") end
end
provider.create = function() D.SelectTest("create") end
provider.details = function(row) D.TestDetails(row) end
provider.claims = function() D.OpenClaims() end
provider.import = function() B.Exchange.OpenImport(D.CODE, true) end
provider.tools = function() B.GoldView.Open(true) end

function D.TestBoard()
  if not D.testing then return end
  if B.Details.preview and B.Details.win then B.Details.win:Hide() end
  local w = B.Board.Build(provider)
  D.testBoard = w
  Kit.Windows.Show(w); provider.board.Refresh()
  return w
end

function D.RefreshTest()
  if not D.testing then return end
  if D.row then D.row.tracking = Tracking(D.row) end
  if provider.board and provider.board.win:IsVisible() then provider.board.Refresh() end
  if B.Details.preview then B.Details.Refresh() end
end

function D.TestDetails(row)
  if not D.testing then return end
  Use(row)
  local actions = { actions = function()
    local out = {
      { label = "Share bounty", run = function() B.Exchange.PreviewShare(D.bounty, row.personal and "private" or "global"); return true end },
      { label = "Claims & payments", run = function() D.OpenClaims(); return true end },
    }
    if row.personal then
      table.insert(out, 1, { label = "Edit reward", run = function() provider.runPrimary(row); return true end })
    else
      table.insert(out, 1, { label = provider.primary(row), run = function() provider.runPrimary(row); return true end })
      out[#out + 1] = { label = "Claim reward", run = function() D.OpenClaims(); return true end }
    end
    return out
  end, addGold = function(source) B.Pot.Open(source, true) end }
  return B.Details.Open(row, true, actions)
end

local function Nearby()
  if not ns.Nearby then return end
  if ns.Modules and not ns.Modules.Active("nearby") then return end
  ns.Nearby.test = { owner = D, bounty = D.bounty, rows = function()
    return { { name = D.bounty.name, class = D.bounty.class, last = GetTime(), zone = "Tarren Mill" } }
  end }
  ns.Nearby.Update()
end

function D.SelectTest(key)
  if not D.testing or not D.Prepare(key) then return end
  D.state.editingSample = nil
  if key == "create" then D.state.draft, D.state.draftMode = nil, nil end
  ReleaseAlerts()
  if ns.Nearby and ns.Nearby.test then ns.Nearby.test = nil; ns.Nearby.Update() end
  if key == "nearby" then Nearby(); D.Replay()
  elseif key == "shared" or key == "guild" then D.Replay()
  elseif key == "kill" then
    D.Replay()
    local session = D.state
    C_Timer.After(0.3, function()
      if D.testing and D.state == session and D.scene.key == "kill" and B.Proof.previewWin:IsShown() then D.Capture("saved") end
    end)
  elseif key == "board" then return D.TestBoard()
  elseif key == "create" then return D.OpenCreate()
  elseif key == "gold" then return B.GoldView.Open(true)
  elseif key == "claims" then return D.OpenClaims()
  elseif key == "pot" then return B.Pot.Open(D.bounty.contributions[1], true)
  elseif key == "exchange" then return B.Exchange.PreviewShare(D.bounty, "global")
  elseif key == "suggestions" then return B.Suggestions.View.Details(D.Reports(), true) end
end

function D.Command(text)
  if ns.Modules and not ns.Modules.Require("bounties") then return end
  local key = U.Trim(text or ""):lower()
  if key == "stop" or key == "off" or key == "" and D.testing then D.Stop(); return end
  if InCombatLockdown() then B.Say("Leave combat before starting a bounty preview."); return end
  key = ({ [""] = "nearby", poster = "nearby", sighting = "nearby", match = "shared", world = "shared",
    proof = "kill", list = "board", share = "exchange", import = "exchange", settings = "gold" })[key] or key
  local found
  for _, scene in ipairs(D.scenes) do if scene.key == key then found = true end end
  if not found then B.Say("Use " .. B.CMD .. " test [poster|match|kill|board|create|gold|guild|pot|exchange|claims|suggestions|stop]."); return end
  if not D.testing then
    D.onReturn = nil
    if D.guided and ns.Onboarding then ns.Onboarding.StopExploring() end
    D.Stop(); D.testing = true
    local state = D.Ensure()
    for _, sample in ipairs({ "nearby", "guild", "shared" }) do state.samples[sample] = { D.Sample(sample) } end
  end
  return D.SelectTest(key)
end

U.Events({ PLAYER_REGEN_DISABLED = function() if D.testing then D.Stop() end end }, "bounty preview", "bounties")
