local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme

-- Collection state is derived on each refresh; a previous error or empty
-- result must not survive recovery. Blocking facts win over row counts and
-- filters. Supply true for a default message, or a string for feature copy.
-- A ready collection may have zero rows; count then distinguishes an empty
-- collection from a filter with no results. No timers or data are owned here.
local DEFAULTS = ns.Localization.Define({
  error = ns.Locale:Get("shared.state.could_not_load_entries_try_again.b4579a"),
  unavailable = ns.Locale:Get("shared.state.these_entries_are_unavailable_right_now.0b45ce"),
  disabled = ns.Locale:Get("shared.state.this_feature_is_turned_off.846af1"),
  loading = ns.Locale:Get("shared.state.loading_entries.8b7ccc"),
  filtered = ns.Locale:Get("shared.state.no_matches_clear_the_search_or_try.8b802d"),
  empty = ns.Locale:Get("shared.state.no_entries_yet.db0eca"),
  ready = "",
}, { error = "shared.state.could_not_load_entries_try_again.b4579a", unavailable = "shared.state.these_entries_are_unavailable_right_now.0b45ce", disabled = "shared.state.this_feature_is_turned_off.846af1", loading = "shared.state.loading_entries.8b7ccc", filtered = "shared.state.no_matches_clear_the_search_or_try.8b802d", empty = "shared.state.no_entries_yet.db0eca" })

function Kit.ResolveState(facts)
  facts = facts or {}
  local kind, message
  for _, key in ipairs({ "error", "unavailable", "disabled", "loading" }) do
    local value = facts[key]
    if value ~= nil and value ~= false and value ~= "" then
      kind, message = key, type(value) == "string" and value or nil
      break
    end
  end
  if not kind then
    kind = (facts.count or 0) > 0 and "ready" or facts.filtered and "filtered" or "empty"
    message = type(facts[kind]) == "string" and facts[kind] or nil
  end
  return { kind = kind, message = message or DEFAULTS[kind], tone = kind == "error" and "danger" or "textMuted",
    blocked = kind ~= "ready" and kind ~= "empty" and kind ~= "filtered" }
end

-- Always restore the normal tone too: replacing an error's text alone
-- leaves successful refreshes looking like errors.
function Kit.StatusText(region, message, tone)
  region:SetText(message or "")
  Theme.Paint(region, tone or "textMuted")
end
