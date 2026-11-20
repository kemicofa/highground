# Highground Reputation Data

Internal storage for Highground and Highground Reputation. Both ZIPs bundle this folder; keep it enabled. It has no runtime code or interface.

`HighgroundReputationNetworkDB` owns reporting identity, feature opt-ins, proposals, moderation history, pending deliveries and preferences in one account-wide SavedVariables file. Native organization IDs reference guilds and WoW communities; membership and roles remain owned by WoW and are checked live.

The generated reporting identity is not a verified Blizzard account identifier and never grants moderator privileges. Switching addon packages preserves records. Switching characters still requires the current character's native membership and permissions.

Back up `WTF/Account/<account>/SavedVariables/HighgroundReputationData.lua` before a reset. WoW saves on logout/reload. Unreleased Watch community records are not automatically migrated to native communities.

See [Highground Reputation](../HighgroundReputation/README.md) for usage and sharing limits.

[MIT](LICENSE).
