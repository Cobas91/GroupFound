# GroupFound — CurseForge Listing

Copy the pieces below into the matching fields when creating/editing the project on CurseForge.

---

## Summary (short tagline / project card, ~255 chars max)

```
Hardcore trade whitelist with mutual invites, shared finds and character snapshots. Blocks trade, mail, and auction access for players outside your list. Open with /gf.
```

German alternative, if you'd rather lead with German (the addon's default audience for now):

```
Hardcore-Handelsschutz mit Einladungen und geteilter Fundhistorie. Handel, Post und Auktionshaus sind für Spieler außerhalb deiner Liste gesperrt. Öffnen mit /gf.
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
- **Invites and direct adds** — enter a name in `/gf` to invite another GroupFound
  player. Acceptance adds each player to the other's whitelist. An empty field
  adds your current player target directly; `/gf add <name>` adds a name directly.
- **Shared data** — members exchange notable finds, bags, bank, gold, professions,
  and recipes through addon whispers. Data is stored locally per character and
  synchronized on a best-effort basis while players are online.
- **Localized interface** — English and German cover current features. Other
  supported client locales fall back to English for newer text.

## How it works

Add a character name to your list (with or without `-Realm`), and only that
character can trade with you, mail you, or receive mail/attachments from you.
Everyone else is blocked with a clear chat message explaining why.

## Commands

| Command | Effect |
|---|---|
| `/gf` | Open/close the window |
| `/gf group` | Open the members tab |
| `/gf invite <name>` | Invite a player running GroupFound |
| `/gf add <name>` | Add a player directly |
| `/gf add` | No name given — adds your **current target** instead |
| `/gf remove <name>` | Remove a player from the list |
| `/gf list` | Print the current whitelist to chat |

The in-game panel has members and history tabs. Entering a name and clicking
Invite sends an invitation; leaving the field empty adds your current target.
An invitation lasts 60 seconds. The receiving player must have GroupFound loaded
and accept the popup.

## Requirements

- WoW Classic Era (tested on 1.15.9)
- Works with any ruleset, but is built for Hardcore "no trading with randoms"
  house rules

## Notes

- Your whitelist is account-wide (`SavedVariables`), so it carries over between
  characters on the same account.
- History and snapshots are stored per character. Removing a member stops future
  sharing with that member but does not erase previously received data.
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
