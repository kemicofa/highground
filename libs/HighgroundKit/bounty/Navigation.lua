local _, ns = ...
local B, Kit = ns.Bounty, ns.Kit
local N = { boards = { mine = true, guild = true, public = true, suggestions = true } }
B.Navigation = N

local function CaptureBoard(board)
  local w = board.win
  return { query = w.search:GetText(), offset = board.offset, scroll = w.list.offset, help = board.help,
    guideScroll = w.guide.offset, pendingOnly = board.pendingOnly, showIgnored = board.showIgnored, organization = board.organization }
end

local function BoardPage(board, to)
  local w, state = board.win or B.Board.Build(), to.state or {}
  if w.page then w.page:Hide() end
  board.tab, board.help, board.message, board.messageTone = to.name, state.help, nil, nil
  board.organization = state.organization or to.params.organization or (board.provider and "guild" or B.Organizations.Selected())
  board.pendingOnly, board.showIgnored = state.pendingOnly, state.showIgnored
  -- Restoring the query is not a new search; refresh once below.
  board.restoring = true; w.search:SetText(state.query or ""); board.restoring = nil
  board.offset = state.offset or 0
  w.browser:Show(); w.title:Show(); w.close:SetShown(w:IsMovable())
  board.Refresh(); w.list:Scroll(state.scroll or 0); w.guide:Scroll(state.guideScroll or 0)
end

function N.RegisterBoards(board, router)
  for name in pairs(N.boards) do
    router:Register(name, { enter = function(to) BoardPage(board, to) end,
      capture = function() return CaptureBoard(board) end })
  end
end

function N.UpdateBoard(board, changes)
  local state = CaptureBoard(board)
  for key, value in pairs(changes) do state[key] = value end
  local ok, failure = board.router:Navigate({ name = board.tab, state = state }, { restoreState = true })
  if not ok then board.Refresh() end
  return ok, failure
end

function N.Page(board, delta)
  local w = board.win
  local rows = board.provider and board.provider.rows or B.BoardModel.Rows
  local list = rows(board.tab, w.search:GetText(), board.tab == "suggestions" and board.showIgnored
    or board.tab == "guild" and board.pendingOnly)
  local size = w.visible or 1
  local offset = math.max(0, math.min(board.offset + delta * size, math.floor(math.max(0, #list - 1) / size) * size))
  if offset == board.offset then return true end
  return N.UpdateBoard(board, { offset = offset, scroll = 0 })
end

local function Suggestion(name)
  for _, row in ipairs(B.Suggestions.Rows(nil, true)) do
    if B.Key(row.name) == B.Key(name) then return row end
  end
end

function N.GetRouter()
  if N.router then return N.router end
  local router = ns.Router.New()
  N.router = router
  N.RegisterBoards(B.Board, router)
  router:Register("form", {
    capture = function() return B.Form.Capture() end,
    enter = function(to)
      local p = to.params
      return B.Form.Render(p.name, p.mode, p.source, false, to.state, p.organization)
    end,
  })
  router:Register("claims", { capture = function() return B.Ledger.win:CaptureNavigation() end, enter = function(to)
    local w = B.Ledger.Build()
    N.Mount(w)
    w:RestoreNavigation(to.state)
    if not to.state and to.params.name then B.Ledger.Focus(w, to.params.name, to.params.killedAt, to.params.claimID) end
  end })
  router:Register("preferences", {
    capture = function() return { threshold = B.Preferences.win.threshold:GetText() } end,
    enter = function(to) return B.Preferences.Render(false, to.state) end,
  })
  router:Register("suggestion", {
    beforeEnter = function(to) if not Suggestion(to.params.name) then return "suggestions" end end,
    capture = function() return { scroll = B.Suggestions.View.details.scroll:GetVerticalScroll() } end,
    enter = function(to) return B.Suggestions.View.Render(Suggestion(to.params.name), false, to.state) end,
  })
  return router
end

function N.Attach(w)
  local router = N.GetRouter()
  B.Board.router = router
  Kit.AttachNavigation(w, router)
  if not router:Current() and not router._busy then router:Navigate(B.Board.tab) end
end

function N.SetTab(key, board)
  board = board or B.Board
  local name = key == "all" and "mine" or key == "pending" and "guild" or key
  if not N.boards[name] then return false, { code = "unknown_route", message = "Unknown bounty board" } end
  local router, pending = board.router or N.GetRouter(), key == "pending"
  local current = router:Current()
  if current and current.name == name and not board.help and (board.pendingOnly == true) == pending then
    return router:Navigate(current)
  end
  return router:Navigate({ name = name, state = { pendingOnly = pending } })
end

function N.Help(on)
  return N.UpdateBoard(B.Board, { help = on })
end

function N.Open(name, params)
  B.Board.Build()
  local ok, failure = N.GetRouter():Navigate({ name = name, params = params }, { refresh = true })
  if not ok then return nil, failure end
  return B.Board.win.page or B.Board.win
end

function N.Mount(w)
  Kit.AttachNavigation(w, N.GetRouter())
  B.Widgets.MountPage(w)
end

function N.Resume()
  local router = N.GetRouter()
  if not router._busy and router:Current() then return router:Refresh() end
end

function N.BackToBoard()
  local router = N.GetRouter()
  local entries, index = router:History()
  for i = index - 1, 1, -1 do
    if N.boards[entries[i].name] then
      local ok, failure = router:Go(i - index)
      if ok then router:TrimForward() end
      return ok, failure
    end
  end
  return router:Reset(B.Board.tab)
end

function N.Closed()
  if N.router and not N.router._busy and B.Board.win:IsVisible() then N.BackToBoard() end
end

B.Listen("scope", function()
  if N.router then N.router:Reset("mine") end
end)
