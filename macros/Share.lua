local _, ns = ...
local Core, Macros = ns.Core, ns.Macros
local W = ns.Widgets
local C = Core.THEME.colors
local Share = {}
Macros.Share = Share

---------------------------------------------------------------------------
-- Sharing macros as one base64 string (like profiles):
--   base64("WBM1;" .. entries joined by ";"), entry = b64(name):c|g:b64(body)
-- Import previews every macro, compiled, before writing any of them.
---------------------------------------------------------------------------
local function P() return ns.Options.Profiles end

function Share.Encode(list)
  local parts = { "WBM1" }
  for _, m in ipairs(list) do
    parts[#parts + 1] = P().Encode64(m.name) .. ":" .. (m.perCharacter and "c" or "g") .. ":" .. P().Encode64(m.body or "")
  end
  return P().Encode64(table.concat(parts, ";"))
end

-- list or nil, error.
function Share.Decode(text)
  local raw = P().Decode64(text)
  if not raw or not (raw == "WBM1" or raw:match("^WBM1;")) then return nil, "not a Warboard macro string" end
  local list = {}
  for token in raw:gmatch("[^;]+") do
    if token ~= "WBM1" then
      local name, scope, body = token:match("^([^:]*):([cg]):([^:]*)$")
      name = name and P().Decode64(name)
      body = body == "" and "" or (body and P().Decode64(body))
      if not (name and body) or name == "" then return nil, "damaged macro entry" end
      list[#list + 1] = { name = name:sub(1, Macros.NAME_MAX), body = body, perCharacter = scope == "c" }
    end
  end
  if #list == 0 then return nil, "no macros in this string" end
  return list
end

local win
local function Build()
  if win then return win end
  win = CreateFrame("Frame", "WarboardMacroShare", UIParent, "BackdropTemplate")
  win:SetSize(480, 320)
  win:SetPoint("CENTER", 0, 40)
  win:SetFrameStrata("FULLSCREEN_DIALOG")
  win:SetBackdrop({ bgFile = Core.WHITE, edgeFile = Core.WHITE, edgeSize = 1 })
  win:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.98)
  win:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
  win:EnableMouse(true)
  win:SetMovable(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "WarboardMacroShare") end
  win.title = Core.Text(win, "bold", 16)
  win.title:SetPoint("TOPLEFT", 12, -10)
  win.hint = Core.Text(win, "medium", 11)
  win.hint:SetPoint("TOPLEFT", 12, -30)
  win.hint:SetPoint("RIGHT", -12, 0)
  win.hint:SetJustifyH("LEFT")
  win.hint:SetTextColor(unpack(C.muted))
  local well = Core.Fill(win, "BACKGROUND", 0, 0, 0, 0.35)
  well:SetPoint("TOPLEFT", 10, -50)
  well:SetPoint("BOTTOMRIGHT", -10, 130)
  win.box = CreateFrame("EditBox", nil, win)
  win.box:SetMultiLine(true)
  win.box:SetAutoFocus(false)
  win.box:SetMaxLetters(0)
  Core.SetFace(win.box, "mono", 10)
  win.box:SetTextColor(unpack(C.text))
  win.box:SetPoint("TOPLEFT", 14, -54)
  win.box:SetSize(452, 130)
  win.box:SetScript("OnEscapePressed", function() win:Hide() end)
  win.box:SetScript("OnTextChanged", function() Share.Preview() end)
  win.preview = Core.Text(win, "medium", 11)
  win.preview:SetPoint("TOPLEFT", 12, -196)
  win.preview:SetPoint("RIGHT", -12, 0)
  win.preview:SetJustifyH("LEFT")
  win.preview:SetJustifyV("TOP")
  win.preview:SetWordWrap(true)
  win.preview:SetHeight(84)
  win.close = W.Button(win, "Close", 70, 22, C.surface, function() win:Hide() end)
  win.close:SetPoint("BOTTOMLEFT", 10, 10)
  local function import(scope)
    return function() Share.Import(scope) end
  end
  win.asExported = W.Button(win, "As exported", 100, 22, C.surface, import(nil))
  win.asExported:SetPoint("BOTTOMRIGHT", -10, 10)
  win.toCharacter = W.Button(win, "To Character", 100, 22, C.surface, import(true))
  win.toCharacter:SetPoint("RIGHT", win.asExported, "LEFT", -4, 0)
  win.toGeneral = W.Button(win, "To General", 100, 22, C.surface, import(false))
  win.toGeneral:SetPoint("RIGHT", win.toCharacter, "LEFT", -4, 0)
  win:Hide()
  return win
end

function Share.ShowExport(list)
  local w = Build()
  w.mode = "export"
  w.title:SetText("EXPORT " .. #list .. " MACRO" .. (#list == 1 and "" or "S"))
  w.hint:SetText("Ctrl+C to copy, then paste it anywhere. Import it with /wb macros import.")
  for _, b in ipairs({ w.asExported, w.toCharacter, w.toGeneral }) do b:Hide() end
  local names = {}
  for _, m in ipairs(list) do names[#names + 1] = m.name end
  w:Show()
  w.box:SetText(Share.Encode(list))
  w.preview:SetText(table.concat(names, ", "))
  w.box:SetFocus()
  w.box:HighlightText()
end

function Share.ShowImport()
  local w = Build()
  w.mode = "import"
  w.title:SetText("IMPORT MACROS")
  w.hint:SetText("Paste a Warboard macro string (Ctrl+V). Each macro is checked before anything is written.")
  for _, b in ipairs({ w.asExported, w.toCharacter, w.toGeneral }) do b:Show() end
  w:Show()
  w.box:SetText("")
  w.box:SetFocus()
  Share.Preview()
end

-- Import mode: decode and compile each macro as the text changes.
function Share.Preview()
  local w = win
  if not (w and w:IsShown() and w.mode == "import") then return end
  local text = w.box:GetText()
  if text == "" then w.list = nil; w.preview:SetText(""); return end
  local list, err = Share.Decode(text)
  w.list = list
  if not list then w.preview:SetText("|cffff5555" .. err .. "|r"); return end
  local lines = {}
  for _, m in ipairs(list) do
    local r = Macros.Analyze(m.body)
    local state = r.errors > 0 and "|cffff5555" .. r.errors .. " error(s)|r"
      or r.warnings > 0 and "|cffffb347" .. r.warnings .. " warning(s)|r" or "|cff66e08cok|r"
    local exists = Macros.Where(m.name)
    lines[#lines + 1] = string.format("%s  (%s)  %s%s", m.name, m.perCharacter and "character" or "general", state,
      exists and ("  · replaces your " .. exists .. " macro") or "")
  end
  w.preview:SetText(table.concat(lines, "\n"))
end

-- scope: nil = as exported, true = Character, false = General.
function Share.Import(scope)
  local w = win
  if not (w and w.list) then return false end
  local done, failed = 0, {}
  for _, m in ipairs(w.list) do
    local perCharacter = scope == nil and m.perCharacter or scope == true
    local ok, msg = Macros.Save(m.name, m.body, perCharacter)
    if ok then done = done + 1 else failed[#failed + 1] = m.name .. ": " .. msg end
  end
  print("|cffff5533Warboard|r imported " .. done .. " macro" .. (done == 1 and "" or "s")
    .. (#failed > 0 and (" (failed: " .. table.concat(failed, "; ") .. ")") or ""))
  if Macros.Window.Refresh then Macros.Window.Refresh() end
  w:Hide()
  return #failed == 0
end
