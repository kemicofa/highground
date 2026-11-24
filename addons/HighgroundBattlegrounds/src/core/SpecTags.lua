local _, ns = ...
local Core, Comms = ns.Core, ns.Comms

---------------------------------------------------------------------------
-- Spec tags: a player names an enemy's talent tree by hand (the enemy
-- panel's spec picker) when the game can't tell. WoW Forever's scoreboard
-- only gives the class, and its auras and casts are secret in a match.
-- Tags are kept per region like scoreboard history and shared with the team
-- (prefix HighgroundS, group channel):
--   1:key,class,tree;key,class,tree;...   (tree 0 = tag removed)
-- Tree indexes, not spec IDs or names, so every client and language reads
-- them the same way.
--
-- Precedence: what the game shows this match (scoreboard, even a secret
-- one, a talent-tree cast, an estimate from buffs) outranks a tag; a tag outranks earlier
-- matches' history and mana estimates.
---------------------------------------------------------------------------
Core.SPEC_TAG_PREFIX = "HighgroundS"
Core.SPEC_TAG_RETRY = 2 -- seconds between attempts while the game refuses
Core.SPEC_TAG_STRONG = { live = true, cast = true, aura = true }

local previewTags = {} -- sample tags while a preview or guide runs
local pending = {} -- [key] = true: tags (or removals) teammates haven't heard
local waiting = false

local function Store()
  if Core.testMode then return previewTags end
  return ns.Scope.Saved("specTags", "social")
end

function Core.ClearPreviewSpecTags() wipe(previewTags) end

-- The tagged spec ID and its record, for an enemy key of that class.
function Core.SpecTag(key, class)
  local t = key and Store()[key]
  if type(t) ~= "table" or t.class ~= class then return end
  local id = Core.classSpecs[class] and Core.classSpecs[class][tonumber(t.tree) or 0]
  if id then return id, t end
end

-- The game draws a scoreboard spec in the row, secret or not: Retail
-- shows it mid-match without letting addons read it.
local function GameShows(e)
  local spec = e.specLive
  if spec == nil then return false end
  if Core.plain(spec) then return spec ~= "" end
  return true
end

-- Whether the panel may offer the picker: the game hasn't identified it.
function Core.SpecTaggable(e)
  return e ~= nil and not Core.SPEC_TAG_STRONG[e.specSrc] and not GameShows(e)
    and Core.classSpecs[e.class] ~= nil and #Core.classSpecs[e.class] > 0
end

-- Put a tag on the enemy unless stronger evidence holds; a removed tag
-- gives back what the enemy had before it (history, an estimate or nothing).
function Core.ApplySpecTag(e)
  if not e or Core.SPEC_TAG_STRONG[e.specSrc] then return end
  local id, t
  if not GameShows(e) then id, t = Core.SpecTag(e.key, e.class) end
  if id then
    if e.specSrc ~= "tag" then e.beforeTag = { e.specID, e.specSrc, e.specReason } end
    e.specID, e.specSrc, e.specReason, e.specBy = id, "tag", nil, t.by
  elseif e.specSrc == "tag" then
    local b = e.beforeTag
    e.specID, e.specSrc, e.specReason = b and b[1], b and b[2], b and b[3]
    e.beforeTag, e.specBy = nil, nil
  end
end

local function Send(text)
  local chan = Core.active and not Core.testMode and Core.db and Core.ShareOn() and Comms.GroupChannel()
  if not chan then return nil end
  if Comms.Blocked() then return false end
  return Comms.Send(Core.SPEC_TAG_PREFIX, text, chan) and true or false
end

-- Send every pending tag that still names a current enemy; refused ones
-- wait and are tried again while the match lasts.
function Core.ShareSpecTags()
  local parts, keys, len = {}, {}, 2
  local function flush()
    if #parts == 0 then return true end
    local sent = Send("1:" .. table.concat(parts, ";"))
    if sent then for _, key in ipairs(keys) do pending[key] = nil end end
    parts, keys, len = {}, {}, 2
    return sent
  end
  for key in pairs(pending) do
    local e = Core.enemies[key]
    if not e then
      pending[key] = nil
    else
      local _, t = Core.SpecTag(key, e.class)
      local tok = string.format("%s,%s,%d", key, e.class, t and tonumber(t.tree) or 0)
      if len + #tok + 1 > 250 and flush() == nil then break end
      parts[#parts + 1], keys[#keys + 1], len = tok, key, len + #tok + 1
    end
  end
  local sent = flush()
  if sent == nil then wipe(pending) end -- nobody to tell
  if next(pending) and not waiting and C_Timer and C_Timer.After then
    waiting = true
    C_Timer.After(Core.SPEC_TAG_RETRY, function()
      waiting = false
      if Core.active then Core.ShareSpecTags() else wipe(pending) end
    end)
  end
end

-- The player tags (tree) or untags (nil, or the tree already tagged) an enemy.
function Core.SetSpecTag(e, tree)
  if not (e and e.key and Core.classSpecs[e.class]) then return false end
  local store = Store()
  local current = Core.SpecTag(e.key, e.class)
  local id = tree and Core.classSpecs[e.class][tree]
  if not id or id == current then
    store[e.key] = nil
  else
    store[e.key] = { class = e.class, tree = tree, t = time() }
  end
  Core.ApplySpecTag(e)
  if not Core.testMode then
    pending[e.key] = true
    Core.ShareSpecTags()
  end
  if Core.Render then Core.Render() end
  return true
end

function Core.ReceiveSpecTags(text, sender)
  if not Core.active or Core.testMode or not Core.On("intelShare") then return end
  local short = type(sender) == "string" and sender:match("^[^-]+")
  if not short or Core.IsMe(sender) then return end
  local body = text:match("^1:(.+)$")
  if not body then return end
  local store, changed = Store(), false
  for tok in body:gmatch("[^;]+") do
    local key, class, tree = tok:match("^([^,]+),(%u+),(%d+)$")
    tree = tonumber(tree)
    local e = key and Core.enemies[key]
    local specs = e and e.class == class and Core.classSpecs[class]
    if specs and (tree == 0 or specs[tree]) then
      store[key] = tree > 0 and { class = class, tree = tree, t = time(), by = short } or nil
      Core.ApplySpecTag(e)
      changed = true
    end
  end
  if changed and Core.Render then Core.Render() end
end

Comms.Listen(Core.SPEC_TAG_PREFIX, function(text, channel, sender)
  if Comms.FromGroup(channel) then Core.ReceiveSpecTags(text, sender) end
end, "spectags", "battlegrounds")
