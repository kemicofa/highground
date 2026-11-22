local t, new = ...

-- A populated board: one row build per refresh, no work under a mounted page
-- and no repeated portrait restores while the likeness cannot change.
local function Board(client)
  local s = new(client, {})
  local e = s.env
  e.C_CreatureInfo = { GetRaceInfo = function() return { clientFileString = "Human" } end }
  e.GetRaceAtlas = function(race, gender, hiRes) return (hiRes and "raceicon128-" or "raceicon-") .. race .. "-" .. gender end
  e.C_Texture = e.C_Texture or {}
  e.C_Texture.GetAtlasInfo = function() return {} end
  e.SetPortraitTextureFromCreatureDisplayID = function(texture, id) texture.texture = "model:" .. id end
  local B = s.ns.Bounty
  local db = B.Public.Data()
  db.portraits = db.portraits or {}
  for i = 1, 8 do
    local name = "Target" .. string.char(96 + i)
    s:command("bounty add " .. (100 + i) .. " " .. name)
    name = s.ns.Core.Canon(name)
    db.portraits[B.Key(name)] = { name = name, guid = "", displayID = 0, class = "ROGUE", race = 1, sex = 2, at = B.Public.Now() }
  end
  s:advance(3)
  return s, B
end

for _, client in ipairs({ "cata", "retail" }) do
  t.test(client .. " a populated board builds its rows once per refresh and keeps every tab count", function()
    local s, B = Board(client)
    local builds, rows = 0, B.BoardModel.Rows
    B.BoardModel.Rows = function(...) builds = builds + 1; return rows(...) end
    B.Board.Open(); B.Board.SetTab("mine")
    local w = B.Board.win
    builds = 0; B.Emit("updated")
    t.equal(builds, 1, "an update builds only the open tab's rows")
    for _, key in ipairs({ "mine", "guild", "public", "suggestions" }) do
      t.equal(tonumber(w.tabs[key].count:GetText()) or 0, #rows(key), key .. " count matches its rows")
    end
    builds = 0; w.search:SetText("Targeta")
    t.equal(builds, 1, "a search keystroke builds one filtered list")
    t.equal(w.tabs.mine.count:GetText(), "8", "the tab keeps its unfiltered count")
    builds = 0; B.Navigation.UpdateBoard(B.Board, { query = "Targetb" })
    t.equal(builds, 1, "restoring a saved search refreshes once")
    t.equal(w.rows[1].entry.name, s.ns.Core.Canon("Targetb"), "restored search applied")
    local form = B.Form.Open("Targetc", "personal")
    builds = 0; B.Emit("updated"); s:advance(6)
    t.equal(builds, 0, "a mounted form stops board refreshes underneath it")
    form:Hide()
    assert(builds > 0 and w.rows[1]:IsVisible(), "closing the form refreshes the board")
    B.BoardModel.Rows = rows
    s:assertHealthy()
  end)

  t.test(client .. " shown likenesses retry only for a unit, a new record or a captured image", function()
    local s, B = Board(client)
    local R = B.Portraits
    B.Board.Open(); B.Board.SetTab("mine")
    local card = B.Board.win.rows[1]
    t.equal(card.portrait.atlas, "raceicon128-human-male", "saved race likeness shown")
    local applies, apply = 0, R.Apply
    R.Apply = function(...) applies = applies + 1; return apply(...) end
    s:advance(5)
    t.equal(applies, 0, "an unchanged likeness is not restored every half second")
    local name = card.posterBounty.name
    local record = R.Record(name); record.displayID, record.at = 4242, record.at + 1
    assert(R.Save(record)); s:advance(0.6)
    assert(applies > 0, "a newly saved likeness is applied to open posters")
    t.equal(card.portraitKind, "model", "model likeness replaces the race portrait")
    applies = 0; s:advance(5)
    t.equal(applies, 0, "settled again")
    s.units.target = { name = name:match("^[^-]+"), realm = "Realm", classID = 4, enemy = true }
    s:advance(0.6)
    assert(applies > 0, "a visible unit is still tried for a live portrait")
    R.Apply = apply
    s:assertHealthy()
  end)
end
