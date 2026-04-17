# BBS Tycoon (PowerShell 7)

A small single-player console game about running a late-80s to 90s era Bulletin Board System (BBS): phone lines, door games, message networks, upgrades, and the eternal struggle of paying monthly bills.

## Historical context (quick but grounded)

BBSes were dial-up systems typically run by a **sysop** (system operator) from home or a small office, often on DOS-era PCs with one or more **modems** attached.

Common ingredients you’ll see reflected in the game:

- **Nodes / phone lines**: Each phone line generally supported one caller at a time. Adding lines was a big deal: more callers, but also more monthly cost.
- **BBS software “packages”**: There were many popular packages and styles (often shareware → registered → commercial tiers). Sysops tweaked configs, menus, ANSI art, user classes, time limits, and file areas.
- **Door games and utilities**: “Doors” were external programs launched from the BBS (classic examples include *LORD* and *TradeWars 2002*-style games). They increased engagement and kept callers coming back.
- **Message networks (FidoNet / RIME-style)**: Networks let boards exchange mail and “echoes” (shared discussion areas) via scheduled transfers, historically over dial-up. This expanded a board’s community beyond local callers.
- **The bridge to the Internet**: In the mid-90s, some boards added IP connectivity (telnet gateways, shell accounts, email integration). That changed who could connect and how.

This game is *inspired by* that era, but it uses simplified numbers so it stays playable.

## Run

From the repo root:

```powershell
pwsh ./bbs-game.ps1
```

Optional:

```powershell
pwsh ./bbs-game.ps1 -SavePath ./saves/my-save.json
pwsh ./bbs-game.ps1 -NoColor
```

## Save files

Saves are JSON files stored under `./saves/` by default.

## Roadmap ideas (if you want them next)

- More random events (hardware failures, long distance bills, “warez” drama, net splits)
- Per-door popularity, file area storage pressure, nightly mail events
- Better user simulation (new user signups vs active callers)
- Scenarios: "1990 dial-up only" vs "1996 Internet transition"
