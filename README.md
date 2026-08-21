# GroupFound

A trade whitelist addon for **World of Warcraft Classic Era (Hardcore)**.

GroupFound blocks trade, mail, and auction house access with anyone who isn't on
your own, manually curated list of players — enforced automatically, with no way
to switch it off. Built for Hardcore communities that run a "no trading with
strangers" house rule and want the game to enforce it instead of relying on
willpower.

## Features

- **Trade blocked automatically** — if a trade window opens with someone not on
  your list, it's cancelled immediately.
- **Mail blocked both ways** — you can't send mail to an unlisted player, and you
  can't pick up attachments or money from mail sent by one.
- **Auction house disabled** — the auction house UI is closed the moment it opens.
- **Always on** — there are no settings to turn protection off. If GroupFound is
  loaded, the rules apply.
- **Simple whitelist management** — open the panel with `/gf`, type a name and
  click Add, or add whoever you currently have targeted with one click (leave the
  name field empty and click Add).
- **Fully localized** — the UI and all chat messages automatically match your
  game client's language via `GetLocale()`: English, German, French, Spanish,
  Portuguese (BR), Italian, Russian, Korean, and Chinese (Simplified &
  Traditional). Missing translations fall back to English.

## Installation

### From CurseForge

Install via the CurseForge app, or download the latest release zip and extract
it into your `Interface/AddOns` folder.

### From source

1. Clone this repository.
2. Copy (or symlink) the `GroupFound/` folder into your WoW installation's
   `Interface/AddOns` folder, e.g.:
   `World of Warcraft/_classic_era_/Interface/AddOns/GroupFound`
3. Restart WoW (or `/reload`).

## Usage

| Command | Effect |
|---|---|
| `/gf` | Open/close the whitelist window |
| `/gf add <name>` | Add a player to the list |
| `/gf add` | No name given — adds your **current target** instead |
| `/gf remove <name>` | Remove a player from the list |
| `/gf list` | Print the current whitelist to chat |

The in-game panel (`/gf`) covers the same actions with a name field, an Add
button (leave the field empty and click it to add your current target), and a
scrollable list with a remove button per entry.

Whitelist entries can be a plain character name (matches that name on any realm)
or `Name-Realm` (matches only that specific character).

## Project structure

```
GroupFound/           Addon source (this is what ships to Interface/AddOns)
  GroupFound.toc       Addon manifest
  Locales.lua          Client-locale-aware translation table (GroupFound.L)
  Core.lua             Whitelist logic, event/mail hooks, slash commands
  UI.lua               The /gf settings window
scripts/
  Package.ps1          Builds a CurseForge-ready zip into dist/
CURSEFORGE.md          Copy-paste text for the CurseForge project listing
```

## Building a release zip

```powershell
powershell -File scripts\Package.ps1
```

Reads the version from `GroupFound/GroupFound.toc`, and produces
`dist/GroupFound-<version>.zip` with the correct folder layout for a manual
CurseForge upload. Pass `-Deploy` to also copy the current source into your
local WoW `Interface/AddOns` folder:

```powershell
powershell -File scripts\Package.ps1 -Deploy
```

## Requirements

- WoW Classic Era (developed against client version 1.15.9)

## License

MIT — see [LICENSE](LICENSE).
