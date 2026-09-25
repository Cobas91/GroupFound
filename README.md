# GroupFound

GroupFound is a trade whitelist and small peer-to-peer group addon for **World of Warcraft Classic Era (Hardcore)**. It blocks trading, sending mail, taking mail attachments or money, and auction house access according to your personal whitelist. Protection is always active while the addon is loaded.

Version 2.0 also shares notable finds and character data between whitelisted players running GroupFound. There is no server or group owner: each client keeps its own list and data. Sharing requires both players to add each other. Adding a name manually does not require an invitation.

## Features

- Trade with a player outside your whitelist is cancelled when the trade window opens.
- Mail to unlisted recipients and taking attachments or money from unlisted senders is blocked. Mail with an unknown sender is blocked too.
- The auction house is closed when opened.
- The members tab shows your whitelist, approximate recent activity, and received snapshots of bags, bank, gold, professions, and recipes. Bank data is available after the player has opened their bank.
- The history tab shows notable looted items. Below level 60, uncommon or better items count; from level 60 onward, rare or better items count.
- A draggable minimap button opens the window.
- English and German cover the current interface. Other supported client locales use available translations and fall back to English for newer text.

## Installation

Install with the CurseForge app, or copy the `GroupFound/` directory into `World of Warcraft/_classic_era_/Interface/AddOns/GroupFound`, then restart WoW or use `/reload`. The addon targets Classic Era interface `11509`.

## Inviting and managing members

Open `/gf`, enter a character name in the members tab, and click **Invite**. The other player needs GroupFound loaded and must accept the popup. On acceptance, both characters add each other to their whitelists. An invitation is valid for 60 seconds. If sending fails immediately, the addon reports it in chat; delivery to an offline player cannot be confirmed.

Leave the name field empty and click **Invite** to add your current player target directly. You can also manage the list with commands. Removing a member stops future sharing with that member; already received history or snapshots are not erased.

| Command | Effect |
|---|---|
| `/gf` | Open or close the window |
| `/gf group` | Open the members tab |
| `/gf invite <name>` | Send an invitation |
| `/gf add <name>` | Add a player directly, without an invitation |
| `/gf add` | Add your current player target directly |
| `/gf remove <name>` | Remove a whitelist entry |
| `/gf list` | List whitelist entries in chat |

Entries can be `Name` (matches that name on any realm) or `Name-Realm` (matches only that realm). Use `Name-Realm` when you know it to avoid ambiguity. A realm suffix is inferred as your own realm when the game provides only a name for a local player.

The whitelist is account-wide. History and snapshots are stored per character. Clients exchange data directly via addon whispers and periodically repeat small batches; this is best effort, so an offline player receives updates only after both clients are online again. Recent activity is an estimate based on received addon messages, not a presence check.

## Project structure

```text
GroupFound/
  GroupFound.toc   Addon manifest and load order
  Locales.lua      Interface translations
  Core.lua         Whitelist and trade/mail/auction protection
  Comm.lua         Invitations, finds, snapshots, and syncing
  UI.lua           Main window and tabs
  GroupUI.lua      Members, detail, and history views
  Minimap.lua      Minimap button
scripts/Package.ps1  Local release ZIP packaging
.github/workflows/release-zip.yml  GitHub/CurseForge release workflow
```

## Packaging

Run `powershell -File scripts/Package.ps1` to create `dist/GroupFound-<version>.zip`. The optional `-Deploy` switch also copies the addon to the local WoW directory configured in that script. Publishing a GitHub release triggers the workflow that uploads the ZIP as a release asset and to CurseForge when `CURSEFORGE_TOKEN` is configured.

Run `lua tests/comm_spec.lua` from the repository root to check invitations, message validation, snapshot splitting, and history syncing with a mocked WoW API. In-game testing remains necessary for client API behavior and the interface.

## License

MIT — see [LICENSE](LICENSE).
