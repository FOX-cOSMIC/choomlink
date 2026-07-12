# Multiplayer mod landscape — verified research (2026-07-12)

> Deep-research pass run on the Windows PC, 2026-07-12: 18 sources fetched, 89 claims extracted,
> 25 top claims adversarially verified (3 independent verifiers each; **all 25 confirmed 3-0, none refuted**).
> This largely confirms the 2026-07-11 snapshot in [START_HERE.md](START_HERE.md) §3, with the
> corrections and additions below. Statuses are snapshots as of 2026-07-12.

## Confirmed landscape

| Project | Verified status (2026-07-12) | License | Usable? |
|---|---|---|---|
| **Cyberverse** (TDUniverse) | Active — commits through 2026-06-30, pushed 2026-07-06; no published releases; README targets game v2.1 | **MIT** (© 2023 MeFisto94 and TDUniverse) | ✅ Our foundation |
| **CyberMP** (cyber.mp) | Active but unreleased — ~10 devs, six closed betas since 2024, "semi-open beta" advertised, tester-gated proprietary launcher; in development since 2020, alpha since Aug 2024 | Closed source, no public code anywhere on the site | 👀 Watch only (design inspiration from public material) |
| **CyberpunkMP** (Tilted Phoques) | Dormant — last push 2024-12-21 (commit `0ccb0cfa`, 150 commits); repo NOT archived; issues active into Dec 2025 | Custom source-available license, **NOT open source** (GitHub shows "Other"/NOASSERTION) | ⛔ See warning below |

## ⚠️ CyberpunkMP license — DO NOT read its core source

Verified verbatim against `LICENSE.md` (fetched live 2026-07-12):

> "You may not use the Software, or any part thereof, to develop, market, or distribute a product
> or service that competes directly with CyberpunkMP or any related offerings by Tilted Phoques SRL.
> **This restriction includes studying, reverse engineering, or analyzing the Software for the
> purpose of creating, marketing, or distributing a competing product or service.**"

ChoomLink is a competing multiplayer product, so for anyone working on ChoomLink:

- **Do not read, fork, or reference CyberpunkMP's core source code.** Not even "just for ideas."
- Safe exceptions carved out by their own license:
  - Three directories are **MIT-licensed**: `code/scripting/EmotySystem`, `code/scripting/JobSystem`, `code/assets/redscript/Plugins`.
  - Plugins built with their SDK that don't modify/redistribute the core (irrelevant to us).
- README-level public descriptions (feature list, architecture blurbs, blog posts) are fine — that's not the Software.
- Their license also says Tilted Phoques may modify terms at any time, so even the MIT carve-outs are not immutable; snapshot anything we'd rely on.

Their verified public feature set (for the record, from README only): player appearance/equipment/movement/basic-animation sync, full vehicle+passenger sync, .NET server-plugin SDK + redscript client SDK + client↔server RPC. **No quest sync claimed** — nobody in the landscape has demonstrated quest/story sync.

## Cyberverse — verified details

- Four-project architecture (README verbatim): `Server.Native` (C++, GameNetworkingSockets networking/serialization), `Server.Managed` (C#, high-level logic + plugins), `Client.RED4extModule` (C++, packet handling), redscript layer applying server changes in-game.
- Client dependencies: RED4ext, redscript, Codeware.
- "A working sandbox mode, that already handles most of the hard topics in Networking (such as entity sync)."
- Explicitly "only relevant for developers/modders"; targets v2.1 — current-patch compatibility check remains the first technical task (START_HERE §7.9).

## RED4ext — the hooking layer

- MIT (© 2020–present Octavian Dima), actively maintained: **v1.30.0 released 2026-03-09**, ~146k Nexus downloads.
- Two parts: the **loader** (plugin manager only, matches native DLL plugins to game version — this is why every game patch is a potential break) and **RED4ext.SDK** (reverse-engineered engine types; scripting-VM calls, new native classes/functions). Plugin devs compile against the SDK.
- Community analogy (their own README): Script Hook V / Skyrim Script Extender.

## CDPR legal position

⚠️ *These claims were extracted from CDPR's own primary documents but fell outside the
adversarial-verification budget — well-sourced but not triple-verified:*

- **User Agreement** (regulations.cdprojektred.com): prohibits modifying/reverse-engineering games "unless CDPR expressly allows it or applicable law permits it" — hook-based mods operate outside the default grant, relying on tolerance + local-law interop exceptions.
- **REDmod EULA**: non-commercial only; **never mentions multiplayer/online/networking** — CDPR neither endorses nor bans multiplayer mods. It governs only the REDmod tool, not RED4ext-style hooking.
- Modders **retain ownership** of their mods (must license fan content to CDPR under Fan Content Guidelines).
- CDPR reserves takedown rights for Fan Content Guideline breaches (IP-infringing/offensive content); no multiplayer-specific ground stated. CDPR endorses community tooling (WolvenKit) — cooperative posture.
- Official CP2077 multiplayer (planned as a standalone GTA-Online-style release) was cancelled after the 2020 launch; that's why this space is fan-only.
- Practical read: CyberpunkMP and CyberMP have operated publicly for years without takedown. **Stay strictly non-commercial** — be careful even with Patreon-style funding (commercial use requires express CDPR permission).

## Open questions (not settled by research)

1. Why CyberpunkMP halted Dec 2024 (staffing / legal / technical wall?) — relevant as a difficulty signal: the Skyrim Together team went dormant after ~150 commits.
2. CyberMP's actual architecture and release timeline (six closed betas, still no public build).
3. How far real in-game sync goes beyond advertised features anywhere (combat, netrunning, traffic, NPCs).
4. Whether current Cyberverse master runs on the newest game patch (its June-2026 dependency bumps hint it may track newer than the README's v2.1) — **first technical task**.

## Key sources

- https://github.com/TDUniverse/Cyberverse · https://github.com/WopsS/RED4ext · https://docs.red4ext.com/
- https://github.com/tiltedphoques/CyberpunkMP (+ `LICENSE.md`)
- https://cyber.mp/ (+ /download)
- https://regulations.cdprojektred.com/ · REDmod EULA (cdn-l-cyberpunk.cdprojektred.com/redmod_eula_en.pdf) · https://www.cyberpunk.net/en/modding-support
- https://wiki.redmodding.org/ (Core Mods explained) · https://redmodding.org/projects
