# GroupFound — CurseForge Listing

Copy the pieces below into the matching fields when creating/editing the project on CurseForge.

---

## Summary (short tagline / project card, ~255 chars max)

```
Hardcore trade whitelist: block trade, mail, and the auction house for anyone not on your personal player list. Configurable in-game via /gf.
```

German alternative, if you'd rather lead with German (the addon's default audience for now):

```
Hardcore-Handelsschutz: Handel, Post und Auktionshaus werden für alle Spieler blockiert, die nicht auf deiner persönlichen Liste stehen. Einstellbar per /gf.
```

---

## Full description (Markdown, for the project's Description page)

```markdown
# GroupFound

**A trade whitelist for WoW Classic Hardcore.** GroupFound blocks trade, mail, and
auction house access with anyone who isn't on your own, manually curated list of
players — enforced automatically, with no way to switch it off.

Many Hardcore communities run a "no trading with strangers" house rule to keep
runs fair and avoid account-sharing or boosting through the back door. GroupFound
turns that rule into something the game enforces for you instead of something you
have to remember.

## Features

- **Trade blocked automatically** — if a trade window opens with someone not on
  your list, it's cancelled immediately.
- **Mail blocked both ways** — you can't send mail to an unlisted player, and you
  can't pick up attachments or money from mail sent by one.
- **Auction house disabled** — the auction house UI is closed the moment it opens.
- **Always on** — there are no settings to turn protection off. If GroupFound is
  loaded, the rules apply. No accidental (or "just this once") disabling.
- **Simple whitelist management** — open the panel with `/gf`, type a name and
  click Add, or add whoever you currently have targeted with one click.
- **Fully localized** — the UI and all chat messages automatically match your
  game client's language: English, German, French, Spanish, Portuguese (BR),
  Italian, Russian, Korean, and Chinese (Simplified & Traditional).

## How it works

Add a character name to your list (with or without `-Realm`), and only that
character can trade with you, mail you, or receive mail/attachments from you.
Everyone else is blocked with a clear chat message explaining why.

## Commands

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

## Requirements

- WoW Classic Era (tested on 1.15.9)
- Works with any ruleset, but is built for Hardcore "no trading with randoms"
  house rules

## Notes

- Your whitelist is account-wide (`SavedVariables`), so it carries over between
  characters on the same account.
- Protection cannot be disabled from the addon UI or slash commands by design —
  that's the whole point.
```

---

## Suggested project metadata

- **Category:** Chat & Communication / Role-Playing / Miscellaneous (whichever
  CurseForge bucket fits "social/behavior" addons best on the day you upload)
- **Client:** WoW Classic Era
- **License:** pick whatever you're comfortable with (e.g. All Rights Reserved,
  or MIT/GPL if you want others to reuse the code)
