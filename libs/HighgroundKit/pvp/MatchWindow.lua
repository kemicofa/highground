local _, ns = ...
local H, U, Kit = ns.MatchHistory, ns.Util, ns.Kit
local LABELS = ns.Localization.Define(ns.Localization.Define({ killingBlows = ns.Locale:Get("shared.matchwindow.killing_blows.a52d07"), honorableKills = ns.Locale:Get("shared.matchwindow.honorable_kills.028a89"), deaths = ns.Locale:Get("shared.matchwindow.deaths.41cd88"),
  honorGained = ns.Locale:Get("shared.matchwindow.honor.01e896"), damageDone = ns.Locale:Get("highground.setup.damage.7bf6d1"), healingDone = ns.Locale:Get("shared.matchwindow.healing.87272f"), ratingChange = ns.Locale:Get("shared.matchwindow.rating_change.60e13f") }, { deaths = "shared.matchwindow.deaths.41cd88", honorGained = "shared.matchwindow.honor.01e896", damageDone = "highground.setup.damage.7bf6d1", healingDone = "shared.matchwindow.healing.87272f" }), { killingBlows = "shared.matchwindow.killing_blows.a52d07", honorableKills = "shared.matchwindow.honorable_kills.028a89", ratingChange = "shared.matchwindow.rating_change.60e13f" })

local RESULTS = ns.Localization.Define({}, {
  ["Win"] = "highground.coachrecords.win.4973f4",
  ["Loss"] = "shared.copy.loss.12e24a",
  ["Completed"] = "shared.copy.completed.1798b3",
  ["Left early"] = "highground.coachrecords.left_early.3e26fd",
})

function H.Entries(records)
  local entries, wins, losses = {}, 0, 0
  for _, match in ipairs(records or H.All()) do
    if match.result == "Win" then wins = wins + 1 elseif match.result == "Loss" then losses = losses + 1 end
    local result = RESULTS[match.result] or match.result
    local detail = { match.name .. " — " .. result, match.character .. " · " .. (match.game or ""),
      ns.Locale:Format("shared.matchwindow.specialization_value2.ea49eb", { value2 = (match.specName or tostring(match.spec or "unknown")) }),
      ns.Locale:Format("shared.matchwindow.duration_value2.58b84c", { value2 = U.Clock(match.duration or 0) }), ns.Locale:Format("shared.matchwindow.joined_value2.4132f0", { value2 = date("%Y-%m-%d %H:%M", match.started) }) }
    for _, key in ipairs({ "killingBlows", "honorableKills", "deaths", "honorGained", "damageDone", "healingDone", "ratingChange" }) do
      if match.stats and match.stats[key] ~= nil then detail[#detail + 1] = LABELS[key] .. ": " .. match.stats[key] end
    end
    detail[#detail + 1] = ns.Locale:Get("shared.matchwindow.observed_objectives_latest_events.17a86f")
    for i = math.max(1, #match.events - 10), #match.events do
      local e = match.events[i]; detail[#detail + 1] = U.Clock(e.at) .. "  " .. e.text
    end
    entries[#entries + 1] = { key = match.id, title = match.name .. " · " .. result,
      summary = match.character .. " · " .. U.Clock(match.duration or 0), detail = table.concat(detail, "\n"),
      search = match.name .. " " .. result .. " " .. match.character .. " " .. tostring(match.spec or "") .. " " .. (match.specName or ""), match = match }
  end
  local summary = ns.Locale:Format("shared.matchwindow.wins_wins_losses_losses_value3_win_rate.aad517", { wins = string.format("%d", wins), losses = string.format("%d", losses), value3 = string.format("%.0f", wins + losses > 0 and wins / (wins + losses) * 100 or 0) })
  if not records then H.summary = summary end
  return entries, summary
end

function H.Build(provider)
  local owner = provider or H
  if not owner.win then
    owner.win = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "MatchHistory" .. (provider and "Sample" or ""), {
      title = ns.Locale:Get("shared.matchwindow.match_history.c2b12f"), hint = ns.Locale:Get("shared.matchwindow.this_character_s_matches_on_the_current.2a625b"),
      data = provider and provider.entries or function() return H.Entries() end,
      empty = ns.Locale:Get("shared.matchwindow.completed_matches_will_appear_here_only_observed.5ced7c"),
      selected = function(_, w) w:SetSub(owner.summary or "") end,
      actions = {
        { label = ns.Locale:Get("shared.matchwindow.full_timeline.a0c4d1"), run = function(entry)
          if not owner.timeline then owner.timeline = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "MatchTimeline" .. (provider and "Sample" or ""), {
            title = ns.Locale:Get("shared.matchwindow.objective_timeline.f6ac0d"), width = 650, height = 500 }) end
          local lines = {}
          for _, e in ipairs(entry.match.events) do lines[#lines + 1] = U.Clock(e.at) .. "  " .. e.text end
          owner.timeline:Open(entry.match.name, ns.Locale:Get("shared.matchwindow.observed_events_since_joining.6ff0e9"), table.concat(lines, "\n"), true)
        end },
        { label = ns.Locale:Get("shared.matchwindow.delete_entry.ccaf75"), run = function(entry)
          local removed, index
          local records = provider and provider.records or H.All()
          for i, m in ipairs(records) do if m.id == entry.key then removed, index = table.remove(records, i), i; break end end
          return true, ns.Locale:Get("shared.matchwindow.match_removed_you_can_undo_this_below.5afa45"), function()
            if removed then table.insert(records, math.min(index, #records + 1), removed) end
          end
        end },
      },
    })
  end
  return owner.win
end

function H.Open(embedded)
  H.Build()
  if not embedded then H.win:Open() end
  return H.win
end
