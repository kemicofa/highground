local _, ns = ...
local B, Core, P = ns.Bounty, ns.Core, ns.Bounty.Public
local R, sent = B.Portraits, {}
B.Listen("scope", function() wipe(sent) end)

function R.GuildMessage(name)
  local a = R.Record(name)
  if not a then return end
  local text = table.concat({ "1:I", a.name, a.guid, a.displayID, a.class, a.race, a.sex, a.at }, ",")
  return #text <= 255 and text or nil
end

function R.SendGuild(name, organization)
  local text = R.GuildMessage(name)
  if text then return B.Send(text, organization) end
  return true
end

function R.Receive(a, sender, channel, name, organization)
  a = R.Validate(a, name)
  if not a then return end
  local group = channel == "GUILD" or channel == "ORGANIZATION"
  local b = group and B.Guild(organization)[B.Key(a.name)] or not group and P.Receiving() and P.Find(a.name)
  if not b or b.state == "removed" or b.publicClosed then return end
  if group and not (B.Organizations.Member(organization) and B.Visible(b)) then return end
  local old = R.Record(a.name)
  if old and old.guid ~= "" and a.guid ~= "" and old.guid ~= a.guid then return end
  for _, offer in ipairs(b.contributions or {}) do
    if offer.guid ~= "" and a.guid ~= "" and offer.guid ~= a.guid then return end
  end
  if R.Save(a) then B.Emit("portrait", a.name) end
end

function R.ReceiveGuild(rest, sender, organization)
  local name, guid, display, class, race, sex, at = rest:match("^,([^,]+),([^,]*),(%d+),([A-Z]*),(%d+),(%d+),(%d+)$")
  if name then R.Receive({ name = name, guid = guid, displayID = tonumber(display), class = class,
    race = tonumber(race), sex = tonumber(sex), at = tonumber(at) }, sender, organization and "ORGANIZATION" or "GUILD", name, organization) end
end

function R.Queue(a, target)
  if not (P.Connected() and P.Publishing()) then return end
  if target or ns.Caps.addonChannel then P.Enqueue("portrait", a, target)
  else for peer in pairs(P.peers) do P.Enqueue("portrait", a, peer) end end
end

function R.Share(a)
  local key, now = B.Key(a.name), GetTime()
  local last = sent[key]
  -- A model can arrive after the race-only snapshot. Allow that upgrade
  -- immediately, while still throttling repeated observations.
  if last and now - last.at < 60 and not (last.displayID == 0 and a.displayID > 0) then return end
  sent[key] = { at = now, displayID = a.displayID }
  for _, list in ipairs(B.Organizations.Lists()) do
    local guild = list[key]
    if guild and guild.state == "approved" and Core.O("bountyShare") then R.SendGuild(a.name, guild.organization) end
  end
  if P.Find(a.name) then R.Queue(a) end
end
