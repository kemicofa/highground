local _, ns = ...
local B = ns.Bounty
local T = { MAX_KILLS = 20 }
B.Terms = T

-- Preferences are reviewed against proof; they never establish a killing blow.
-- These use the classic class toolkit available in Forever.
T.methods = {
  { id = "fall", label = "Fall damage", hint = "A lethal fall. A Priest's Mind Control can set up a cliff finish; include a clip showing the fall." },
  { id = "drown", label = "Drowning", hint = "The target dies from drowning. Include a clip showing the underwater fight and death." },
  { id = "control", label = "Mind Control", hint = "Use Priest Mind Control to set up the death. Show the control and the finish in a clip." },
  { id = "fear", label = "Fear into danger", hint = "Use Fear or Psychic Scream to send the target into danger. Show the fear and resulting death." },
  { id = "execute", label = "Execute finish", hint = "Land the killing blow with Warrior Execute." },
  { id = "ambush", label = "Ambush finish", hint = "Land the killing blow with Rogue Ambush from stealth." },
  { id = "dot", label = "Damage over time", hint = "A bleed, poison, Corruption or Shadow Word: Pain delivers the final damage." },
  { id = "pet", label = "Pet killing blow", hint = "A Hunter pet or Warlock demon delivers the final blow." },
  { id = "wand", label = "Wand finish", hint = "Finish the target with a wand shot." },
  { id = "reflect", label = "Reflected damage", hint = "Thorns, Retribution Aura or another damage shield delivers the final damage." },
  { id = "trap", label = "Trap finish", hint = "A Hunter's damaging trap delivers the final damage." },
  { id = "unarmed", label = "Unarmed finish", hint = "Unequip your weapons and land the final blow with an unarmed attack." },
}

function T.Gold(value)
  if value == nil or value == "" then return 0 end
  if type(value) == "string" then value = value:lower():match("^%s*(%d+)%s*g?%s*$") end
  local n = tonumber(value)
  return n and n == math.floor(n) and n >= 0 and n <= B.MAX_GOLD and n or nil
end

function T.Count(b) return b and b.killsRequired or 1 end
function T.Custom(b) return T.Count(b) > 1 or b and b.killMethods and b.killMethods ~= "" end
function T.Budget(b) return b.gold * (T.Count(b) - (b.killsStarted or 0)) end

function T.Validate(count, methods)
  count, methods = count == nil and 1 or tonumber(count), methods or ""
  if not count or count ~= math.floor(count) or count < 1 or count > T.MAX_KILLS then
    return nil, "Choose a whole kill count from 1 to " .. T.MAX_KILLS .. "."
  end
  if type(methods) ~= "string" or #methods > 120 then return nil, "Invalid kill preferences." end
  local known, selected, ordered = {}, {}, {}
  for _, method in ipairs(T.methods) do known[method.id] = true end
  for id in methods:gmatch("[^.]+") do
    if not known[id] or selected[id] then return nil, "Invalid kill preferences." end
    selected[id] = true
  end
  for _, method in ipairs(T.methods) do if selected[method.id] then ordered[#ordered + 1] = method.id end end
  if table.concat(ordered, ".") ~= methods then return nil, "Invalid kill preferences." end
  return { killsRequired = count, killMethods = methods }
end

function T.Copy(to, from)
  to.killsRequired, to.killMethods = T.Count(from), from and from.killMethods or ""
  return to
end

function T.Same(a, b)
  return T.Count(a) == T.Count(b) and (a.killMethods or "") == (b.killMethods or "")
end

function T.Methods(b)
  local labels, selected = {}, "." .. (b.killMethods or "") .. "."
  for _, method in ipairs(T.methods) do
    if selected:find("." .. method.id .. ".", 1, true) then labels[#labels + 1] = method.label end
  end
  return table.concat(labels, ", ")
end

function T.Summary(b)
  local count = T.Count(b)
  local text = count .. (count == 1 and " kill" or " kills") .. " requested"
  if b.gold > 0 then text = text .. " · " .. ns.Util.Gold(b.gold) .. " per approved kill"
    .. (count > 1 and (" · up to " .. ns.Util.Gold(T.Budget(b))) or "") end
  local methods = T.Methods(b)
  return text .. (methods ~= "" and ("\nPreferred finish (any): " .. methods .. ". Proof reviewed manually.") or "")
end

local function Progress(b)
  local done, pending, personal = 0, 0, b.state == "personal"
  local tracking = personal and b.by == B.Me() and not b.potID
  if b.id then
    b = B.Public.Data().offers[b.id] or b
    done = b.killsAwarded or (b.winner and b.winner ~= "" and 1 or 0)
    local accepted = 0
    for _, c in pairs(B.Public.Data().claims) do
      if c.pledge == b.id then
        if c.state == "claimed" then pending = pending + 1
        elseif c.state == "approved" or c.state == "paid" then accepted = accepted + 1 end
      end
    end
    done = math.max(done, accepted)
  else
    for _, c in ipairs(B.Ledger.All()) do
      if B.Pot.MatchesClaim(c, b) and (personal and c.personal or not personal and B.Organizations.SameClaim(c, b)) then
        if c.state == "approved" or c.state == "paid" or tracking and c.state == "claimed" then done = done + 1
        elseif c.state == "claimed" then pending = pending + 1 end
      end
    end
  end
  done = math.max(done, b.killsAwarded or 0)
  local count = T.Count(b)
  return "Progress: " .. done .. "/" .. count .. (tracking and " kills recorded" or " kills approved")
    .. (pending > 0 and (" · " .. pending .. " pending review") or "")
    .. (done >= count and " · Complete" or "")
end

function T.Progress(b)
  local lines = {}
  if b.contributions then
    for _, p in ipairs(b.contributions) do
      lines[#lines + 1] = (#b.contributions > 1 and (ns.Core.DisplayName(p.by) .. " · ") or "") .. Progress(p)
    end
  else lines[1] = Progress(b) end
  return table.concat(lines, "\n")
end
