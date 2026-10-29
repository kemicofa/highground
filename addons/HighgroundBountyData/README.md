# Highground Bounty Data

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Shared account-wide storage for Highground, Highground Nearby and Highground Bounties. It has no interface, commands or network activity of its own. Keep this addon enabled: the three bounty clients require it and their ZIPs include it automatically.

One SavedVariables file owns `HighgroundBountyNetworkDB`, so switching bounty clients preserves the contributor ID, contributions, funding reports and claim history. The ID survives character changes within the same WoW account and installation; it is not a verified Blizzard account identifier. Resetting the saved data or using a separate installation can create another ID.

The saved file is `WTF/Account/<account>/SavedVariables/HighgroundBountyData.lua`. Updating addon files preserves it. Personal/guild bounties, ordinary settings and enemy history remain in each client's own saved variables.

For development from source, [link this directory](../../docs/monorepo.md#source-installation) into `Interface/AddOns/HighgroundBountyData` alongside whichever bounty client you use. `X-Internal: true` keeps it out of standalone release discovery; [builds](../../docs/releases.md) include it through the clients' `Dependencies` and `X-Bundled-Addons` fields.

See the [shared bounty guide](../Highground/docs/user-guide.md#shared-bounties) for contributions, funding and claims. [MIT](LICENSE).
