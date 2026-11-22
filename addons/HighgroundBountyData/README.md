# Highground Bounty Data

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Required account-wide bounty storage, bundled with Highground. It has no interface, commands or network activity of its own. Keep it enabled. The deprecated Nearby and Bounties addons used this same storage owner, so shared records remain available after migration.

One SavedVariables file owns `HighgroundBountyNetworkDB`, so migrating to Highground preserves the contributor ID, contributions, funding reports and claim history. The ID survives character changes within the same WoW account and installation; it is not a verified Blizzard account identifier. Resetting the saved data or using a separate installation can create another ID.

It also stores each character's last recorded gold balance and local guild commitments. Tracking starts on; log into each character to record it. Gold totals use the current server, or Forever realmset, and remain private. Shared bounty data, claims and portrait metadata also use the active Forever realmset. Old Forever data without a realmset stays in its original saved fields and is excluded from the new scoped lists.

The saved file is `WTF/Account/<account>/SavedVariables/HighgroundBountyData.lua`. Updating addon files preserves it. Personal/guild bounties, ordinary settings and enemy history remain in each host’s own saved variables and are not automatically imported when migrating. See [standalone migration](../Highground/docs/getting-started.md#moving-from-a-standalone-addon).

For development from source, [link this directory](../../docs/monorepo.md#source-installation) into `Interface/AddOns/HighgroundBountyData` alongside Highground. `X-Internal: true` keeps it out of standalone release discovery; [builds](../../docs/releases.md) include it through Highground’s `Dependencies` and `X-Bundled-Addons` fields.

See the [shared bounty guide](../Highground/docs/user-guide.md#shared-bounties) for contributions, funding and claims. [MIT](LICENSE).

Shared data format 3 preserves existing contributions and claims while recording the original reviewer, accepted completion terms and replayable decisions for pot contributions. Update Highground: older clients intentionally refuse format 3 so they cannot let a contributor override the original poster's decision. Unpaid obligations and the offer snapshots needed for delayed decisions survive expiry and reloads.
