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
pwsh ./bbs-game-run.ps1
```

Optional:

```powershell
pwsh ./bbs-game-run.ps1 -SavePath ./saves/my-save.json
pwsh ./bbs-game-run.ps1 -NoColor

# Scriptable simulation (no prompts): advance N days then exit
pwsh ./bbs-game-run.ps1 -NewGame -NewGameName "The Rusty Modem" -SimDays 30 -SavePath ./saves/sim.json
```

## Parameters

- `-SavePath` (default: `./saves/save.json`)
	- Path to a JSON save file. Relative paths are interpreted from the current working directory.
- `-NoColor`
	- Disables colored output.
- `-SimDays <int>`
	- Runs the simulation for N days without prompts, saves, prints a short summary, and exits.
- `-NewGame`
	- Starts a new game even if the save file already exists.
- `-NewGameName <string>`
	- Name for a new game (otherwise it prompts in interactive mode, or falls back to a default in scripted mode).

## Save files

Saves are JSON files stored under `./saves/` by default.

If the game crashes, it writes a best-effort crash log to `./saves/last-crash.txt`.

## Roadmap ideas (if you want them next)

- More random events (hardware failures, long distance bills, “warez” drama, net splits)
- Per-door popularity, file area storage pressure, nightly mail events
- Better user simulation (new user signups vs active callers)
- Scenarios: "1990 dial-up only" vs "1996 Internet transition"
