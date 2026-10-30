local _, ns = ...
local H, Kit, U = ns.NearbyHistory, ns.Kit, ns.Util
local J = {}
ns.EnemyJournal = J

function H.Muted(name)
  local key = ns.Core.Canon(name)
  for who, entry in pairs(H.All()) do
    if (who == name or (key and ns.Core.Canon(who) == key)) and entry.muted then return true end
  end
  return false
end

function J.Entries()
  local out = {}
  for name, h in pairs(H.All()) do
    local class = h.class and U.ClassName(h.class) or "Unknown class"
    out[#out + 1] = { key = name, record = h, title = name,
      summary = class .. "  ·  " .. (h.zone or "Unknown zone") .. (h.muted and "  ·  muted" or ""),
      detail = name .. "\n" .. class .. "\n" .. (h.guild or "") .. "\n\n" .. H.Summary(h)
        .. "\nFirst met " .. H.Ago(time() - (h.first or time())) .. " ago"
        .. "\nLast zone: " .. (h.zone or "unknown") .. "\n\nNotes:\n" .. (h.note or "No notes") }
  end
  table.sort(out, function(a, b) return (a.record.last or 0) > (b.record.last or 0)
    or ((a.record.last or 0) == (b.record.last or 0) and a.key < b.key) end)
  return out
end

local function Note(entry)
  if not J.noteWindow then
    J.noteWindow = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "EnemyNote", {
      title = "ENEMY NOTE", width = 480, height = 300,
      buttons = { { key = "save", label = "Save note", onClick = function()
        local box = J.noteWindow
        if box.entry then box.entry.record.note = box:GetText():gsub("|", ""):sub(1, 500) end
        box:Hide(); J.win:Refresh()
      end } } })
  end
  J.noteWindow.entry = entry
  J.noteWindow:Open("NOTE: " .. entry.key, "Saved locally. Up to 500 bytes of text.", entry.record.note or "")
end

function J.Open(embedded)
  if not J.win then
    J.win = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "EnemyJournal", {
      title = "ENEMY JOURNAL", hint = "Search by name, class, guild, zone, or note. Most recently seen first.",
      data = J.Entries, empty = "No enemies recorded yet. Turn on Nearby enemies in settings; players you encounter outside matches will appear here.",
      actions = {
        { label = "Edit note", run = Note },
        { label = "Mute alerts", text = function(e) return e and e.record.muted and "Unmute alerts" or "Mute alerts" end,
          run = function(e) e.record.muted = not e.record.muted; return true, "Sighting and stealth alerts updated." end },
        { label = "Add bounty", enabled = function() return ns.Bounty ~= nil end, run = function(e)
          local b = ns.Bounty
          b.Board.Open(e.key)
          return true, "Set a reward on the bounty board."
        end },
        { label = "Delete entry", run = function(e)
          local record = H.All()[e.key]; H.All()[e.key] = nil
          return true, "Entry removed. You can undo this below.", function()
            if not H.All()[e.key] then H.All()[e.key] = record end
          end
        end },
      },
    })
  end
  if not embedded then J.win:Open() end
  return J.win
end
