# Highground Match Data

Load-on-demand storage for [match history](../Highground/docs/user-guide.md#match-history) timelines, bundled with Highground. It has no code, interface or commands of its own. Keep it beside Highground and enabled.

Highground keeps each match's summary (result, duration, stats) in its own saved data and moves the full objective timelines here. This addon's SavedVariables, `HighgroundMatchArchiveDB`, load only when a timeline is needed: when you open match history, or after a battleground once 20 newer timelines are waiting. WoW leaves the file of an addon that did not load untouched, so a session without match history costs no memory for old timelines.

The saved file is `WTF/Account/<account>/SavedVariables/HighgroundMatchData.lua`. Without this addon, Highground keeps timelines in its own saved data, at most 200 events per match as before, and match history says when an older timeline cannot be shown. See [saved data](../Highground/docs/saved-data.md#match-history-archive) for the limits.

For development from source, [link this directory](../../docs/monorepo.md#source-installation) into `Interface/AddOns/HighgroundMatchData` alongside Highground. `X-Internal: true` keeps it out of release discovery; builds include it through Highground's `X-Bundled-Addons`.

[MIT](LICENSE).
