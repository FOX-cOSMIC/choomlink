# START_HERE — Cyberpunk 2077 Windows Modding Project

> **Purpose of this document:** bootstrap file for the first Claude Code session of a NEW project on the Windows PC. Read top to bottom before doing anything. It encodes context, the recommended approach, environment setup, and the open decisions that must be made in session 1.
>
> Written 2026-07-12 on the old Mac, from the closing session of the predecessor project.

---

## 1. Who / context

- The developer previously ran **`cp2077-mac-mods`** (github.com/FOX-cOSMIC, local: `~/Programming/cp2077-mac-mods/`) — a research project porting the CP2077 modding stack to native macOS. It is **on ice** (commit `cad737d`), not abandoned. Do not resume it; but its docs are a goldmine of transferable knowledge:
  - Deep familiarity with **TweakDB internals**, **redscript** (verified working end-to-end), **RED4ext architecture**, Ghidra-based RE of the game binary, and the discipline of FACTS / FAILED_APPROACHES / HYPOTHESES documentation.
  - Key lesson learned there: verify community claims empirically before building on them (see its F-047/F-053 stories).
- The developer now has a **Windows gaming PC**. On Windows, the *entire* mature modding stack just works — no porting needed. The game changes from "reverse-engineering target" to "platform to build on."
- Interest area: **multiplayer**. Prior research (2026-07-11) established the landscape — see §3.

## 2. The goal (DECIDED 2026-07-12)

**A GTA-Online-style shared-world multiplayer for Cyberpunk 2077: fork Cyberverse as the technical foundation, borrow CyberMP's design direction (open-world freeroam, players visible to each other, later PvP/racing/activities), and make it our own. Near-term capacity target: 8 concurrent players on one server.**

Why this shape:
- **CyberMP** proves the concept and sets the design bar, but is closed-source — it can only be studied from the outside (their Discord/test notes), never forked.
- **Cyberverse** (MIT) is the only active open-source foundation and has already solved the hardest plumbing (entity sync, RED4ext↔server bridge, GameNetworkingSockets transport). Forking it skips months of groundwork.
- 8 players is trivially within GameNetworkingSockets' capability — the real work is *game-side sync* (locomotion, appearance, combat, vehicles), which is exactly Cyberverse's open-issue list. Our roadmap is largely "close their open issues, in our fork, ordered by what an 8-player freeroam needs first."

**Still recommended as step zero:** one trivial standalone redscript mod (hours, not days, given prior macOS redscript experience) purely to validate the Windows toolchain before touching the fork.

## 3. Multiplayer landscape (researched 2026-07-11)

| Project | Status | Notes |
|---|---|---|
| **CyberMP** (cyber.mp) | Active, **closed source**, closed beta | ~10 devs, GTA-Online-style shared world (PvP/racing), explicitly NOT campaign co-op. Access via their Discord (discord.com/invite/cybermp) tester waves only. Watch it; can't build on it. |
| **TDUniverse/Cyberverse** | **Active + MIT open source** (pushed 2026-07-06) | The one to build on. 4-part architecture: `Server.Native` (C++ networking, GameNetworkingSockets), `Server.Managed` (C# game logic, plugin-extensible), `Client.RED4extModule` (C++), `Client.Redscript`. Client deps: RED4ext + redscript + Codeware. Has working sandbox + entity sync. **Not playable for regular users yet** — core sync features are open issues from Dec 2023: locomotion #6, damage/health #5, weapons #4, vehicle mount #3, server browser #7, auth #9. Targets game **v2.1** (version pinning is a real risk — check current compatibility first). Docker server image reportedly broken (#14, #22). |
| tiltedphoques/CyberpunkMP | **Dead** (last push Dec 2024) | SkyrimTogether team's attempt. Reference only. |
| CyberScript | Dead, pulled from Nexus | Ignore. |

## 4. Working with Claude Code — yes, in the terminal

- **Install Claude Code natively on Windows** (PowerShell) — it supports Windows directly. Alternative: WSL2, but **don't**: the game, MSVC toolchain, and mod deployment paths are all Windows-native; WSL adds a boundary for zero benefit here.
- Recommended terminal: **Windows Terminal + PowerShell 7** (`winget install Microsoft.PowerShell Microsoft.WindowsTerminal`).
- Session conventions to carry over from the Mac project (they worked well):
  - A `CLAUDE.md` + `AGENTS.md` in the repo root; docs-as-engineering-record (`FACTS.md`, `FAILED_APPROACHES.md` if RE work happens — likely much less needed on Windows since the community has already mapped the binary).
  - Issue tracking: install **beans** if available on Windows, else GitHub Issues. (Decide in session 1.)
  - Append-only discipline for facts; verify community claims before building on them.

### Toolchain checklist (session 1, before any code)

- [ ] Cyberpunk 2077 installed — **Steam copy** (decided). Record exact game version. Note: if the fork needs an older game version (Cyberverse targets v2.1), Steam requires **DepotDownloader** (github.com/SteamRE/DepotDownloader) or `steamcmd` with manifest IDs to fetch it — works fine, just less convenient than GOG's offline installers. Verify current-version compatibility FIRST before downgrading anything.
- [ ] **Git for Windows** + **gh CLI** (`winget install Git.Git GitHub.cli`)
- [ ] **Visual Studio 2022 Build Tools** with "Desktop development with C++" workload + CMake (needed for RED4ext plugin / Cyberverse client module builds)
- [ ] **.NET 8+ SDK** (Cyberverse `Server.Managed` is C#)
- [ ] **Node.js** (Claude Code) — if not already present
- [ ] Core mod frameworks installed into the game: **RED4ext**, **redscript**, **Codeware**, **Cyber Engine Tweaks (CET)**, **ArchiveXL/TweakXL** (grab from Nexus Mods or GitHub releases; check each supports the installed game version)
- [ ] **WolvenKit** (asset/archive tooling — optional until asset work)
- [ ] Smoke test: install one known-good simple Nexus mod, confirm it works in-game → proves the framework install before blaming your own code.

## 5. GitHub setup

- Account exists: **FOX-cOSMIC**. Auth on the new PC: `gh auth login` (browser flow).
- Git identity: `git config --global user.name/user.email` to match the Mac setup.
- **The fork (decided: public from day one):** `gh repo fork TDUniverse/Cyberverse --clone` — this keeps `upstream` remote automatically. Rename the fork to the project's own name once chosen (`gh repo rename`). Keep MIT, keep upstream attribution in the README. Divergent direction (GTA-style freeroam) lives in our fork; generic fixes (build breaks, sync primitives) should be PR'd upstream where practical — goodwill and free review.
- The step-zero warm-up redscript mod can live in a `sandbox/` folder of the fork or a throwaway repo — don't over-structure it.
- `.gitignore`: `build/`, `*.archive` outputs, any paths into the game install. **Never commit game binaries/assets** — same disclaimer discipline as the Mac repo.
- Optional later: GitHub Actions CI on `windows-latest` can build RED4ext plugins and the C# server headlessly.

## 6. Testing multiplayer — what's actually needed

This is the hard practical question. A multiplayer loop needs a **server + ≥2 clients**, and each client needs a legal game copy and (usually) its own machine.

**Decided testing model: mostly solo dev, with friends-with-the-game as real second/Nth players.** Consequences:

- Build a **headless bot / fake-client harness EARLY** (a process that speaks the server protocol and simulates a player — spawn, move, maybe shoot). This is the single highest-leverage dev tool for a solo developer targeting 8 players: 1 real client + 7 bots exercises the 8-player goal without 7 humans. Treat it as a first-class deliverable, not an afterthought.
- Write a **friend onboarding guide** (install RED4ext/redscript/Codeware + our client module, connect via Tailscale) as soon as there's anything joinable — friends' patience is a scarce resource; a broken first install burns it.

Realistic staged setup:

1. **Stage A — server + 1 client (enough for most dev work):** run the Cyberverse server locally (bare `dotnet run` on the same PC — skip Docker, it's reported broken), connect the single game client over localhost. This exercises connection, auth, entity spawn, and one side of every sync feature. *Most of the open Cyberverse issues can be developed this way.*
2. **Stage B — 2 clients:** options, in order of preference:
   - **A friend with the game** connecting over the internet/Tailscale to your server — cheapest and most realistic.
   - **Second game copy on a second machine.** Note: the Mac runs CP2077 natively, but RED4ext/Codeware are Windows-only, so the Mac **cannot** be the second modded client. A second cheap Windows box or laptop could.
   - **Two instances on one PC:** the game doesn't officially support multi-instance; sometimes possible with sandboxing tricks but fragile — treat as last resort, research before sinking time.
3. **Server observability from day 1:** structured logs + a headless "fake client" / bot harness if the protocol allows — lets one developer simulate the second player for sync testing without a second human.

- Network basics: localhost first; LAN second; internet via **Tailscale** (avoids port forwarding) when a remote friend joins.
- **Version pinning:** Cyberverse targets game v2.1; the live game is newer. First technical task is confirming what game version current Cyberverse master actually builds/runs against — GOG lets you install older versions easily; Steam needs depot tricks.

## 7. Decisions — ALL answered 2026-07-12 (do not re-litigate; flag if reality contradicts one)

1. **End goal:** GTA-Online-style shared-world freeroam, own fork of Cyberverse using CyberMP's design direction as inspiration, **8 concurrent players** as the near-term capacity target. (§2)
2. **Path:** tiny redscript warm-up → fork Cyberverse.
3. **Game copy:** Steam (already owned). Version pinning via DepotDownloader if needed. (§4)
4. **Test players:** mostly solo dev (→ bot harness is a priority deliverable) + friends with the game as real clients. (§6)
5. **Fork visibility:** public from day one, MIT, upstream-friendly. (§5)
6. **Work tracking:** **beans** — install it on Windows in session 1; if it doesn't run there, fall back to GitHub Issues and note the substitution.

7. **Project name: ChoomLink.** ("Choom" = friend in Night City slang, ubiquitous in Edgerunners — a mod that links you with your chooms.) The project home repo **github.com/FOX-cOSMIC/choomlink already exists** (created 2026-07-12 from the Mac; holds this doc). Since that name is taken, rename the Cyberverse fork to **`choomlink-core`** (`gh repo rename choomlink-core`), or keep code planning in `choomlink` and link the fork from its README. Keep "fork of TDUniverse/Cyberverse" attribution prominent either way.
8. **First target experience: player-vs-player COMBAT that works well.** This sets the dependency chain — combat is not one feature but the top of a stack:
   - **locomotion sync** (upstream #6) — you must see the other player move before you can fight them;
   - **weapon spawn/mount sync** (upstream #4) — see what they're holding, where they're aiming;
   - **damage/health sync** (upstream #5) — hits register, health bars agree on both clients;
   - then combat polish: hit feedback, death/respawn, netcode feel (latency compensation).
   Appearance sync (#10/#12) and vehicles (#3) come after combat works. Re-read the upstream issues fresh in session 1 — this snapshot is from 2026-07-11.
9. **Game version: the NEWEST live patch (decided).** Do NOT downgrade the Steam install. Consequence: since upstream Cyberverse targets v2.1, an early work item is likely **porting the fork to the current patch** (RED4ext/red-lib/Codeware version bumps, possibly changed offsets). Check upstream master's actual compatibility first — the June-2026 dependency-bump commits suggest they may already track newer versions than the README says. If it truly only runs on 2.1, porting to current IS the first technical milestone (and a great upstream PR).
10. **EULA awareness:** same posture as the Mac project — interoperability modding of owned copies, no asset redistribution, standard disclaimer in the README. (Not really open, just: keep it.)

## 8. First-session script (suggested)

1. Read this file. All decisions are made (§7) — no re-litigating; just confirm nothing has changed since 2026-07-12 (esp. upstream Cyberverse activity and game patch level).
2. Run the §4 toolchain checklist; record versions in the new repo's `docs/ENVIRONMENT.md`. Install beans (or fall back to GitHub Issues).
3. Set up GitHub per §5: public fork of TDUniverse/Cyberverse, renamed **choomlink**.
4. Warm-up: write + deploy a trivial redscript mod (e.g. a `@wrapMethod` log/HUD tweak — the developer has done exactly this on macOS already, facts F-050–F-052 in the old repo), verify in-game on the current patch.
5. Determine upstream's real game-version compatibility; if it doesn't run on the newest patch, porting-to-current becomes milestone 1 (§7.9). Then build server + client module, get Stage A (server + 1 client on localhost) running against the Steam install.
6. Write ChoomLink's own `CLAUDE.md`/`AGENTS.md` and status doc; create the initial bean backlog along the combat dependency chain (§7.8): port-to-current-patch (if needed) → bot harness → locomotion sync → weapon sync → damage/health sync → combat polish; plus friend onboarding guide and an 8-player load test.

## 9. Reference links

- Cyberverse: https://github.com/TDUniverse/Cyberverse (MIT, active)
- CyberMP Discord: https://discord.com/invite/cybermp (watch for beta access)
- RED4ext: https://github.com/WopsS/RED4ext · redscript: https://github.com/jac3km4/redscript
- Codeware: https://github.com/psiberx/cp2077-codeware · CET: https://github.com/maximegmd/CyberEngineTweaks
- WolvenKit: https://github.com/WolvenKit/WolvenKit
- Community: CP2077 Modding Community Discord (linked from the RED Modding wiki: https://wiki.redmodding.org/)
- Predecessor project (on ice, knowledge base): `~/Programming/cp2077-mac-mods/` — esp. `docs/FACTS.md`, `docs/ARCHITECTURE.md`
