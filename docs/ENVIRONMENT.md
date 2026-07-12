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

- **Cyberpunk 2077 (Steam) v2.31** (exe FileVersion 3.0.5294808, Steam buildid 20383525), install path: `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077`
- Mod frameworks **installed 2026-07-12** (zips kept in `C:\Users\G4M3R\Programming\cp2077-mod-staging`):
  - RED4ext 1.30.0 · redscript 0.5.31 · Codeware 1.20.3 · CET 1.37.1 · ArchiveXL 1.26.8 · TweakXL 1.11.3
  - ✅ **All verified in-game on v2.31** (2026-07-12): RED4ext loaded 921876 game addresses, all plugins loaded, redscript compiled clean, CET overlay works.
- Warm-up redscript mod deployed to `<game>\r6\scripts\ChoomLinkWarmup\ChoomLinkWarmup.reds` (source: `choomlink-core\sandbox\warmup\`) — ✅ **verified in-game**: on-screen "ChoomLink warm-up OK" message fired after spawn. Note: FTLog output does not appear in file logs, only in CET's Game Log window.
- All four Cyberverse components build on this machine: Server.Managed (dotnet), Server.Native + Client.RED4extModule (Ninja/vcpkg/MSVC — see `choomlink-core\CLAUDE.md`).

## Windows security note

- **Smart App Control:** disabled 2026-07-12 (registry `VerifiedAndReputablePolicyState=0`, user-approved) because it blocked locally-compiled unsigned binaries (vcpkg's protoc.exe). Took effect without reboot despite docs claiming otherwise.

## Stage A verified (2026-07-12)

- **Cyberverse works on game v2.31 unmodified** — no porting needed despite the README's v2.1 claim. Verified end-to-end on localhost: server (`dotnet run` in `server\Managed`, **needs `DOTNET_ROLL_FORWARD=LatestMajor`** since it targets net9.0 and only runtimes 8/10 are installed; UDP port 1337 hardcoded) ← client connected, player spawned/joined world, weapon-equip packets flowed.
- Server needs the native DLLs (`Cyberverse.Server.Native.dll` + GNS/protobuf/abseil/crypto) copied next to the managed output — no csproj copy step upstream.
- Client deploy: `red4ext\plugins\Cyberverse\` (plugin DLL + 4 deps) + `client\RedscriptModule\src\*` → `r6\scripts\Cyberverse\`. Connection ONLY via game launch args: `--cyberverse-server-address=127.0.0.1 --cyberverse-server-port=1337` (no in-game UI yet).

## Upstream snapshot (2026-07-12)

- TDUniverse/Cyberverse: last push 2026-07-06, 16 open issues, default branch `master`.
- 2026-06-30 commit "Bump red4ext and red-lib" — suggests upstream may track a newer game patch than the README's v2.1 claim. Verify by building.
