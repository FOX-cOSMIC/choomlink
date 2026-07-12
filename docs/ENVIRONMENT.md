# ENVIRONMENT — ChoomLink dev machine

> Windows gaming PC. Recorded during session 1 (2026-07-12). Update when versions change.

## OS / hardware

- Windows 11 Home 10.0.26200

## Toolchain

| Tool | Version | Notes |
|---|---|---|
| Git for Windows | 2.55.0.windows.1 | |
| GitHub CLI (gh) | 2.96.0 | installed 2026-07-12 via winget; authed as FOX-cOSMIC |
| Node.js | v26.4.0 | (Claude Code host) |
| .NET SDK | 10.0.301 | installed 2026-07-12 via winget (`Microsoft.DotNet.SDK.10`); Cyberverse `Server.Managed` needs .NET 8+ — SDK 10 can target it |
| VS 2022 Build Tools | 17.14 (MSVC toolset 14.44.35207, cl 14.44.35228.0) | C++ workload; bundled CMake 3.31.6-msvc6 |
| beans | 0.4.2 (670ecf3) | issue tracker (decision §7.6) — installed manually to `%LOCALAPPDATA%\Programs\beans` (winget was busy), on user PATH; `beans init` done in this repo |

## Game

- **Cyberpunk 2077 (Steam)**, install path: `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077`
- ⏳ **Still downloading** as of session 1 (72.6 / 86.6 GB, Steam target buildid **20383525**). Exact game version: record from `Cyberpunk2077.exe` ProductVersion once download completes.
- Mod frameworks: **not installed yet** (blocked on game download), but latest releases are **staged** in `C:\Users\G4M3R\Programming\cp2077-mod-staging`:
  - RED4ext 1.30.0 · redscript 0.5.31 · Codeware 1.20.3 · CET 1.37.1 · ArchiveXL 1.26.8 · TweakXL 1.11.3
  - Check each supports the installed patch once the game version is known (CET is usually the most version-sensitive).
- Warm-up redscript mod written: `choomlink-core\sandbox\warmup\ChoomLinkWarmup.reds` — deploy to `<game>\r6\scripts\ChoomLinkWarmup\` once frameworks are in.

## Upstream snapshot (2026-07-12)

- TDUniverse/Cyberverse: last push 2026-07-06, 16 open issues, default branch `master`.
- 2026-06-30 commit "Bump red4ext and red-lib" — suggests upstream may track a newer game patch than the README's v2.1 claim. Verify by building.
