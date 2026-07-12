# Deep-Research-Auftrag: Zielarchitektur für ChoomLink

> Vorbereitet 2026-07-12. Status: bereit zum Start (Deep-Research-Session).
> Klärungen des Auftraggebers: Zielhorizont = öffentliche Community-Server (FiveM-Größenordnung),
> Scope = Technik UND Spiel-Ebene, Fundament = alles offen (Cyberverse-Fork darf neu bewertet werden).

## Research question

What is the right target architecture — network model, authority model, and game-session
model — for ChoomLink, a GTA-Online-style shared-world multiplayer mod for Cyberpunk 2077,
designed from the start to eventually support public, community-hosted servers (FiveM-scale
ambitions), and what is the evolution path from the current Cyberverse-fork codebase toward
that target (including an honest assessment of whether to keep evolving the fork or rebuild)?

## Context & hard constraints

- Cyberpunk 2077 is a closed engine: the server can NEVER run the game simulation itself.
  All world simulation happens inside player clients (RED4ext/redscript modding). Any
  architecture must work with clients as the only source of game-world computation.
- Current state (working today): fork of TDUniverse/Cyberverse — C# authoritative-relay
  server (plugin-extensible), C++ native transport (Valve GameNetworkingSockets, UDP),
  shared C++ protocol headers (zpp_bits), RED4ext client module + redscript layer.
  Verified on live patch v2.31: connect/auth/world join, position broadcast at 10 Hz,
  action relay, engine-native locomotion sync via proxy-follow, headless bot harness.
- Solo developer, non-commercial (CDPR EULA), Windows clients; server may be anything.
- Do NOT study tiltedphoques/CyberpunkMP source code (license forbids). Public docs,
  talks, and blog posts ABOUT it are fine.

## Questions to answer (with sources, adversarially verified)

1. **Reference architectures.** How are the successful community-hosted open-world
   multiplayer platforms actually designed: FiveM/Cfx.re and alt:V and RAGE:MP (GTA V),
   MTA:SA, SkyrimTogether (public material only), and relevant survival/sandbox servers
   (Rust, DayZ, Minecraft as contrast)? For each: topology, authority split, tick/sync
   model, entity ownership, scripting/plugin model, persistence, typical player counts.
   Why did Rockstar's own P2P model fail quality-wise, and why did FiveM's model win the
   community?
2. **Authority without server-side simulation.** Given the server cannot simulate the
   world: which authority splits are proven to work? Client-authoritative movement with
   server arbitration? Server-authoritative health/inventory/economy as pure data? How do
   FiveM/alt:V handle combat validation and anti-cheat on community servers where the
   server owner is trusted but players are not? What is realistic anti-cheat posture for
   a modded closed game?
3. **Sync & scale mechanics.** Interest management (grid/range) for 20–64+ players in one
   city; entity ownership & migration (who simulates NPCs/traffic near which player, what
   happens on handover); tick rates and bandwidth budgets typical for this class; state
   replication patterns (full snapshots vs deltas vs event streams) appropriate for a
   relay-style server.
4. **Game-session layer.** Freeroam-as-lobby + instanced activities (races, deathmatch):
   how do GTA-style platforms structure sessions, matchmaking-into-instances, drop-in/
   drop-out, and cross-session persistence (characters, inventory, money — server-side DB
   patterns)? What made FiveM's resource/scripting ecosystem thrive (packaging, permissions,
   server-side vs client-side scripts) — lessons for our Server.Managed plugin system?
5. **Evolution path & fork verdict.** Map the current Cyberverse architecture against the
   recommended target: what can stay (transport, protocol approach, plugin server), what
   must be rebuilt (entity ownership, interest management, persistence), and in which
   order? Honest verdict: does evolving the fork reach the target, or does the target
   justify a rebuild (and if so, what to salvage)? Consider maintenance cost for a solo
   dev and the upstream-PR relationship.

## Deliverable

A cited report with: (a) a recommended target architecture (one page, decisive), (b) a
comparison matrix of the reference platforms, (c) a phased evolution roadmap from today's
codebase (phases sized for a solo dev, each phase independently shippable), (d) explicit
trade-off records for the 3–5 biggest decisions, (e) a risks section (what breaks first at
16/32/64 players).
