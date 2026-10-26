local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Windows in the kit style: dialogs (header band, accent bar, title, close
-- button, drag, saved position), the copy/paste box, and the small HUD
-- windows used in battlegrounds.
---------------------------------------------------------------------------
local ANCHORS = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
  TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

local function Offset(v)
  return type(v) == "number" and v == v and math.abs(v) < 10000
end

-- Saved position { point, relativePoint, x, y } in WarboardDB.windows[key],
-- or nil. A damaged entry is dropped.
function Kit.SavedPoint(key)
  local db = Core.db
  local all = db and db.windows
  if not key or type(all) ~= "table" then return nil end
  local p = all[key]
  if type(p) == "table" and ANCHORS[p[1]] and ANCHORS[p[2]] and Offset(p[3]) and Offset(p[4]) then return p end
  all[key] = nil
end

function Kit.SavePoint(key, frame)
  local db = Core.db
  if not (key and db) then return end
  if type(db.windows) ~= "table" then db.windows = {} end
  local p, _, rp, x, y = frame:GetPoint()
  if p then db.windows[key] = { p, rp, x, y } end
end

-- Put a window at its saved position, else at opts.point
-- ({ point, relativePoint, x, y }, default centred).
function Kit.PlaceWindow(frame, key, default)
  local p = Kit.SavedPoint(key) or default or { "CENTER", "CENTER", 0, 0 }
  frame:ClearAllPoints()
  frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

-- Dialog window. opts: title, sub, width, height, strata ("DIALOG"),
-- savedKey (position in WarboardDB.windows), point (default position),
-- header (band height, size.header), titleRole ("display"), alpha (fill,
-- alpha.dialog), opacity (true: follow Background opacity instead),
-- frameless (true: obey the Frameless setting), noClose, onClose(self).
-- Returns the frame with .head, .bar, .title, .sub, .close, .content and
-- :SetTitle(text), :SetSub(text). Escape closes it when it has a name.
-- Dragging checks IsMovable, so a host can pin it (hub/Hub.lua).
function Kit.Dialog(name, opts)
  opts = opts or {}
  local header = opts.header or Z("header")
  local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  w:SetSize(opts.width or 480, opts.height or 320)
  w:SetFrameStrata(opts.strata or "DIALOG")
  Theme.Backdrop(w, { alpha = not opts.opacity and (opts.alpha or Theme.Alpha("dialog")) or nil,
    border = "borderAccent", frameless = opts.frameless or false })
  w:SetMovable(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self)
    if self:IsMovable() then self:StartMoving() end
  end)
  w:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    Kit.SavePoint(opts.savedKey, self)
  end)
  w.savedKey = opts.savedKey
  Kit.PlaceWindow(w, opts.savedKey, opts.point)
  if name and type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, name) end

  w.head = Theme.Fill(w, "BORDER", "accent", "band")
  w.head:SetPoint("TOPLEFT", 1, -1)
  w.head:SetPoint("TOPRIGHT", -1, -1)
  w.head:SetHeight(header)
  w.bar = Theme.Fill(w, "ARTWORK", "accent")
  w.bar:SetPoint("TOPLEFT", 1, -1)
  w.bar:SetSize(Z("accentBar"), header)
  w.title = Theme.Text(w, opts.titleRole or "display")
  w.title:SetPoint("TOPLEFT", S("xl") + S("xs"), -(header >= Z("header") and S("lg") or S("md")))
  w.title:SetText(opts.title or "")
  w.sub = Theme.Text(w, "label", "textMuted")
  w.sub:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 1, -(S("xs") + 1))
  w.sub:SetText(opts.sub or "")
  if not opts.noClose then
    w.close = Kit.Button(w, "X", Z("close"), Z("close"), { onClick = function() w:Hide() end })
    w.close:SetPoint("TOPRIGHT", -(S("md") + S("xs")), -(S("md") + S("xs")))
  end
  w.content = CreateFrame("Frame", nil, w)
  w.content:SetPoint("TOPLEFT", S("lg"), -header - S("md"))
  w.content:SetPoint("BOTTOMRIGHT", -S("lg"), S("lg"))
  function w:SetTitle(text) self.title:SetText(text or "") end
  function w:SetSub(text) self.sub:SetText(text or "") end
  w:Hide()
  w:SetScript("OnHide", function(self) if opts.onClose then opts.onClose(self) end end)
  return w
end

-- Copy/paste window: title, hint, a multi-line box on a well, a status
-- line, Close at the bottom left and optional action buttons from the
-- bottom right. opts: Kit.Dialog opts plus hint, buttons ({ key, label,
-- tone?, width?, onClick(box) }), onText(box, text).
-- Returns the dialog with .hint, .box (EditBox), .status, .actions[key],
-- :Open(title, hint, text[, select]), :SetStatus(text[, color]), :GetText().
function Kit.CopyBox(name, opts)
  opts = opts or {}
  local o = {}
  for k, v in pairs(opts) do o[k] = v end
  o.header, o.titleRole = o.header or Z("headerSmall"), o.titleRole or "title"
  o.width, o.height = o.width or 480, o.height or 300
  local c = Kit.Dialog(name, o)
  local foot = Z("control") + S("lg") * 2
  c.hint = Theme.Text(c, "body", "textMuted")
  c.hint:SetPoint("TOPLEFT", S("lg"), -o.header - S("sm"))
  c.hint:SetPoint("RIGHT", -S("lg"), 0)
  c.hint:SetJustifyH("LEFT")
  c.hint:SetText(o.hint or "")
  local top = o.header + S("sm") + S("xl") + S("xs")
  local well = Theme.Fill(c, "BACKGROUND", "well")
  well:SetPoint("TOPLEFT", S("md") + S("xs"), -top)
  well:SetPoint("BOTTOMRIGHT", -(S("md") + S("xs")), foot + S("lg"))
  c.scroll = CreateFrame("ScrollFrame", name and (name .. "Scroll") or nil, c, "UIPanelScrollFrameTemplate")
  c.scroll:SetPoint("TOPLEFT", well, "TOPLEFT", S("sm"), -S("sm"))
  c.scroll:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -S("xl") - S("md"), S("sm"))
  c.box = CreateFrame("EditBox", nil, c.scroll)
  c.box:SetMultiLine(true)
  c.box:SetAutoFocus(false)
  c.box:SetMaxLetters(0)
  c.box:SetWidth(o.width - S("xl") * 4)
  Theme.SetRole(c.box, "code")
  Theme.Paint(c.box, "text")
  c.box:SetScript("OnEscapePressed", function() c:Hide() end)
  if o.onText then c.box:SetScript("OnTextChanged", function(self) o.onText(c, self:GetText()) end) end
  c.scroll:SetScrollChild(c.box)
  c.status = Theme.Text(c, "body")
  c.status:SetPoint("BOTTOMLEFT", S("lg"), foot)
  c.status:SetPoint("RIGHT", -S("lg"), 0)
  c.status:SetJustifyH("LEFT")
  c.done = Kit.Button(c, "Close", 70, Z("control"), { onClick = function() c:Hide() end })
  c.done:SetPoint("BOTTOMLEFT", S("lg"), S("lg"))
  c.actions = {}
  local prev
  for i = #(o.buttons or {}), 1, -1 do
    local def = o.buttons[i]
    local b = Kit.Button(c, def.label, def.width or 100, Z("control"),
      { tone = def.tone, onClick = function() if def.onClick then def.onClick(c) end end })
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -S("sm"), 0) else b:SetPoint("BOTTOMRIGHT", -S("lg"), S("lg")) end
    c.actions[def.key or i] = b
    prev = b
  end
  function c:SetStatus(text, color)
    self.status:SetText(text or "")
    Theme.Paint(self.status, color or "text")
  end
  function c:GetText() return self.box:GetText() or "" end
  function c:Open(title, hint, text, select)
    if title then self:SetTitle(title) end
    if hint then self.hint:SetText(hint) end
    self:SetStatus("")
    self:Show()
    self.box:SetText(text or "")
    self.box:SetFocus()
    if select then self.box:HighlightText() end
  end
  return c
end

-- Battleground HUD window (resurrection timers, bases, flags, arena):
-- movable, position saved per character under key, docked in the compact
-- layout, title and info line in the header. Same behaviour as
-- Timers.MakeWindow; needs ns.Timers (rows, layout and placement).
function Kit.HudWindow(name, title, key, def, secure)
  local Timers = ns.Timers
  if not Timers then return nil end
  local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  w.key, w.def, w.rows, w.secure = key, def, {}, secure
  w.docks = name ~= "WarboardArenaFrame"
  w:SetSize(Timers.WIN_W, Timers.TOP + Timers.ROW_H + S("sm"))
  Theme.Backdrop(w)
  w:SetMovable(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self)
    local db = Timers.DB()
    if self.docks and ns.DockDrag and ns.DockDrag(self, true) then
      return -- compact: the whole column moves
    end
    if self.secure and InCombatLockdown() then
      return -- holds secure buttons: can't move in combat
    end
    if not (db and db.locked) then self:StartMoving() end
  end)
  w:SetScript("OnDragStop", function(self)
    if self.docks and ns.DockDrag and ns.DockDrag(self, false) then return end
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    local pos = Timers.Positions()
    if pos then pos[self.key] = { p, rp, x, y } end
  end)
  w.head = Core.Surface(w, "BORDER")
  Theme.Paint(w.head, "surface")
  w.head:SetPoint("TOPLEFT", 1, -1)
  w.head:SetPoint("TOPRIGHT", -1, -1)
  w.brand = Theme.Fill(w, "ARTWORK", "accent")
  w.title = Theme.Text(w, "heading")
  w.title:SetPoint("LEFT", w.brand, "RIGHT", S("sm"), 0)
  w.title:SetText(title)
  w.info = Theme.Text(w, "label", "textMuted")
  w.info:SetJustifyH("RIGHT")
  Core.Chrome(w.head, w.brand, w.title, w.info)
  Timers.windows[#Timers.windows + 1] = w
  if not secure then Timers.timerWindows[#Timers.timerWindows + 1] = w end
  Timers.LayoutWindow(w)
  Timers.PlaceWin(w)
  w:Hide()
  return w
end
