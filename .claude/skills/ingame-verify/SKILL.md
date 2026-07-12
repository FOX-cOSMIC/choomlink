---
name: ingame-verify
description: Autonomously verify ChoomLink/Cyberverse multiplayer sync features in the real game — start server + bot harness, launch Cyberpunk 2077 with connect args, check the mod loaded via logs, capture screenshot bursts and evaluate them visually. Use whenever a sync feature (locomotion, weapons, damage, actions) needs in-game verification, when the user asks "teste das im Spiel", "starte den Test", "sieh dir an ob es funktioniert", or after client/redscript changes that need a live check — even if the user doesn't say "verify".
---

# In-game verification (ChoomLink)

Verify sync features end-to-end with the real game. Most of this runs without the user;
their eye is only needed for animation *quality* (fluidity), not for "does it work".

Paths (see `..\..\..\docs\ENVIRONMENT.md` for versions):
- Game: `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077`
- Fork: `C:\Users\G4M3R\Programming\choomlink-core`

## Sequence

1. **Deploy current builds** (skip pieces that didn't change):
   - `client\red4ext\build\ninja-vcpkg\src\Cyberverse.Red4Ext.dll` → `<game>\red4ext\plugins\Cyberverse\`
   - `client\RedscriptModule\src\*` → `<game>\r6\scripts\Cyberverse\`
   - `server\Native\build\ninja-vcpkg\src\Cyberverse.Server.Native.dll` → `server\Managed\bin\Debug\net9.0\`
2. **Start the server** (background): `dotnet run` in `server\Managed` with
   `DOTNET_ROLL_FORWARD=LatestMajor`. Confirm UDP 1337 is listening (`Get-NetUDPEndpoint -LocalPort 1337`).
3. **Start bots** (background): `tools\bot-harness\build\ninja-vcpkg\bot-harness.exe`
   — pick `--count/--pattern/--jump-every` to exercise the feature under test. Confirm via
   its stats line that all bots are `running`; peer counters (`teleports`, `actions`)
   already prove the server pipeline without the game.
4. **Launch the game** with connect args (never via Steam UI):
   `Cyberpunk2077.exe --cyberverse-server-address=127.0.0.1 --cyberverse-server-port=1337`
   (working dir `<game>\bin\x64`).
5. **Gate on the mod actually loading** — don't wait blindly; the logs tell you:
   - `<game>\r6\logs\redscript_rCURRENT.log` must end with `Compilation complete`.
     An `[UNRESOLVED_*]` error means the .reds and the C++ RTTI disagree (a native method/
     field added on one side only) — fix, redeploy, relaunch. The game will NOT recover.
   - newest `<game>\red4ext\logs\red4ext-*.log`: `Cyberverse.Red4Ext ... has been loaded`.
     `Watchdog timeout` = the game hung and died; check for an error popup cause first.
6. **World entry is automatic** — connected clients auto-load the last save (redscript
   OnSavesForLoadReady). Detect it yourself from the server log; scan incrementally from
   a recorded offset, NEVER by grepping a moving `tail` window (a 10 Hz TRACE log scrolls
   a 20-line window in ~1 s and the join line races past between polls):
   ```bash
   OFF=$(wc -c < "$SRV")   # record BEFORE launching the game
   until tail -c +$OFF "$SRV" | grep -q "joined the world"; do sleep 2; done
   ```
7. **Capture + evaluate**: run `scripts/capture-burst.ps1` (captures ONLY the game
   window via PrintWindow/PW_RENDERFULLCONTENT — works with the game in the background,
   user keeps their terminal in front) and Read the PNGs. Screenshots show whatever view
   the game renders — if the user is in a menu, the burst shows the menu; check for menu
   UI in frame 1 before judging. Judge against the feature's success criteria,
   e.g. for locomotion: puppets present at expected spots, positions differ across the
   burst (moving), leg poses differ (walking, not gliding), mid-air frames (jump).
   A burst of 6 at 500 ms covers one bot walking ~2 m — enough to see pose variation.
8. **Watch the logs during the session** — server log (broadcast activity, errors),
   `redscript_rCURRENT.log` is compile-time only; FTLog output appears ONLY in the CET
   Game Log window (not in files), so don't search files for it.
9. **Clean up** (standing user rule): quit the game (`Stop-Process -Name Cyberpunk2077`),
   stop bots and server, unless the user is actively playing or the next step needs them.

## Reading the evidence

Server-side proof beats screenshots where possible — packet counters are objective:
8 bots × 7 peers × 10 Hz = 560 teleports/s received means lossless broadcast. Use the
bots as measuring instruments first, screenshots for what only rendering can show.

## Known limits

- Per-window capture (PrintWindow) is verified working with borderless windowed mode;
  exclusive fullscreen may capture black — if so, tell the user to switch modes.
- Animation fluidity/feel cannot be judged from stills — that verdict stays with the user.
- One real client only; multi-client visuals need a second machine or a friend.
