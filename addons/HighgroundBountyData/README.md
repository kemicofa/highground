# Highground Bounty Data

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Shared account-wide storage for Highground, Highground Nearby and Highground Bounties. It has no interface, commands or network activity of its own. Keep this addon enabled: the three bounty clients require it and their ZIPs include it automatically.

One SavedVariables file owns `HighgroundBountyNetworkDB`, so switching bounty clients preserves the contributor ID, contributions, funding reports and claim history. The ID survives character changes within the same WoW account and installation; it is not a verified Blizzard account identifier. Resetting the saved data or using a separate installation can create another ID.

It also stores each character's last recorded gold balance and local guild commitments. Tracking starts on; log into each character to record it. Gold totals use the current server, or Forever realmset, and remain private. Shared bounty data, claims and portrait metadata also use the active Forever realmset. Old Forever data without a realmset stays in its original saved fields and is excluded from the new scoped lists.

The saved file is `WTF/Account/<account>/SavedVariables/HighgroundBountyData.lua`. Updating addon files preserves it. Personal/guild bounties, ordinary settings and enemy history remain in each client's own saved variables.

For development from source, [link this directory](../../docs/monorepo.md#source-installation) into `Interface/AddOns/HighgroundBountyData` alongside whichever bounty client you use. `X-Internal: true` keeps it out of standalone release discovery; [builds](../../docs/releases.md) include it through the clients' `Dependencies` and `X-Bundled-Addons` fields.

See the [shared bounty guide](../Highground/docs/user-guide.md#shared-bounties) for contributions, funding and claims. [MIT](LICENSE).

Shared data format 3 preserves existing contributions and claims while recording the original reviewer, accepted completion terms and replayable decisions for pot contributions. Keep Highground, Bounties and Nearby updated together: older clients intentionally refuse format 3 so they cannot let a contributor override the original poster's decision. Unpaid obligations and the offer snapshots needed for delayed decisions survive expiry and reloads.
