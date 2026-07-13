# Deep-Research-Auftrag: Was macht ChoomLink möglich — und gut anfühlbar

> Vorbereitet 2026-07-13. Status: bereit zum Start (Deep-Research-Session).
> Klärungen des Auftraggebers: Scope = Technik-Meilensteine & Testing +
> Community & Distribution + rechtliche Lage + Solo-Dev-Nachhaltigkeit;
> "fühlt sich gut an" = beides — Moment-to-Moment-Gamefeel UND Spieler-Journey.
> Baut auf der Zielarchitektur-Entscheidung auf (2026-07-12-architecture-decision.md):
> FiveM-artiger Relay-Server, dreistufige Autorität, Fork evolvieren, 7-Phasen-Roadmap.

## Research question

Beyond the technical architecture (already decided): what are the concrete steps,
practices, and success factors that turn a solo-developer multiplayer mod for
Cyberpunk 2077 into a project that (a) actually survives to a public community
launch and (b) *feels good* — both moment-to-moment in the game (movement, combat,
latency) and across the player journey (install → join → first great session)?

## Context & hard constraints

- Current state: working Cyberverse fork on live patch v2.31 — connect/auth/world
  join, 10 Hz position broadcast, action relay, engine-native proxy-follow
  locomotion, headless bot harness. Architecture target decided (see
  2026-07-12-architecture-decision.md): server-arbitrated relay, three-tier
  authority, 7-phase roadmap (interest management → delta encoding → economy →
  combat gate → NPC sync → sessions → priority accumulator).
- Solo developer, non-commercial (CDPR EULA), Windows clients, German-based.
- The known graveyard: every public CP2077 multiplayer attempt is cancelled,
  abandoned after 1-2 years, or in multi-year alpha (prior research). alt:V and
  RAGE:MP were shut down by Take-Two in 2026 despite technical success. This
  research should extract *why projects die* and *what the survivors did differently*.
- Do NOT study tiltedphoques/CyberpunkMP source code (license forbids). Public
  docs, roadmaps, Patreon/community posts ABOUT it are fine as market context.

## Questions to answer (with sources, adversarially verified)

1. **Path from tech demo to living project (technical milestones & testing).**
   In what order do successful community multiplayer mods sequence their public
   milestones (closed friends test → closed beta → open beta → launch)? What did
   FiveM/MTA/Skyrim Together Reborn/successful survival-game mods actually gate
   each stage on (stability metrics, feature completeness, player counts)? How do
   mod projects handle QA with a tiny tester pool — what testing infrastructure
   (automated harnesses, telemetry/crash reporting, canary servers) pays off
   earliest? Critically for CP2077: how do RED4ext/redscript-based projects
   survive game patches (the #1 documented mod-killer) — what patch-resilience
   practices exist (version pinning, compatibility layers, fast-update playbooks,
   communicating downtime to the community)?

2. **Moment-to-moment game feel (the netcode the player *feels*).**
   What separates multiplayer that feels responsive/smooth from multiplayer that
   feels floaty/janky, at the concrete technique level: interpolation buffers and
   their tuning (Source's 100ms interp as reference), extrapolation limits,
   animation blending for remote players, how remote-player *gait/turn/stop*
   quality is achieved (relevant to our proxy-follow approach), hit feedback and
   damage confirmation timing (client-predicted hit markers vs server-confirmed
   kills — how shooters hide the round trip), audio/VFX cues that mask latency.
   What do players of FiveM/RAGE:MP servers actually complain about regarding
   feel (forum evidence), and which server-side settings/techniques fixed it?
   What benchmarks exist for "feels good" (latency thresholds from research:
   at what ms does movement/combat feel degraded)?

3. **Player journey: install → join → first session.**
   What makes mod installation feel trustworthy and effortless — analysis of
   FiveM's launcher model (own launcher, auto-updates, server browser in-client),
   r2modman/Thunderstore, Vortex, Wabbajack-style one-click lists? What is the
   documented drop-off cost of manual multi-step installs? How do successful
   community servers design the first 10 minutes (spawn experience, tutorial-free
   orientation, immediately visible other players)? What server-browser/discovery
   UX matters at small scale (5 servers) vs large (thousands)? What role does
   Discord play as the de-facto onboarding funnel for mod communities?

4. **Community & distribution playbook.**
   How did FiveM grow from a modder hack to 250k+ concurrent — which growth
   phases are documented (early adopter servers, the RP/Twitch flywheel with
   NoPixel, content-creator dynamics)? What can a niche project with ZERO
   marketing budget realistically replicate: where do CP2077 modding communities
   live (Nexus, CyberpunkMods discord, Reddit), how do new mods get discovered,
   what makes testers stick around vs churn? How do small multiplayer mod
   projects run their Discord (roles, feedback channels, build distribution,
   expectation management for an alpha)? What communication cadence do surviving
   projects keep (devlogs, changelogs, public roadmaps)?

5. **Legal posture (make-or-break, needs precision).**
   What exactly do CDPR's mod policy, fan-content guidelines, REDmod license,
   and the CP2077 EULA permit and forbid for a multiplayer mod: distribution of
   the mod itself, requiring game ownership, hosting servers, accepting
   donations (Patreon/Ko-fi), paid server access, use of the game's name/assets
   in branding? What is CDPR's documented track record toward mods and
   specifically toward multiplayer mods (public statements about CyberpunkMP's
   existence, history with Witcher mods, REDkit)? Contrast with the Take-Two
   shutdowns of alt:V/RAGE:MP in 2026: what specifically triggered enforcement
   (monetization? scale? asset redistribution?), and which behaviors made FiveM
   acquirable instead of sued? Distill into a concrete do/don't list for
   ChoomLink (conservative, source-backed — no speculation presented as fact).

6. **Solo-dev sustainability over years.**
   What do postmortems and interviews of solo/small-team mod and indie
   multiplayer developers say about lasting multiple years: scope discipline
   (shipping thin vertical slices vs feature sprawl), when and how to take on
   contributors (what roles first — testers, community mods, artists, coders;
   how open-source contribution actually plays out for mod projects),
   burnout patterns and mitigations, sustainable funding without violating a
   non-commercial EULA (donation models used by comparable projects — note
   CyberpunkMP's public Patreon as market precedent, Skyrim Together's history
   including its donation controversy as a cautionary tale). What cadence of
   visible progress keeps both the dev and the community motivated?

## Deliverable

A cited report with:
(a) a **staged viability plan** (friends-test → closed → open → launch) with
    gate criteria per stage, aligned to the existing 7-phase technical roadmap;
(b) a **game-feel playbook**: concrete, prioritized techniques with parameters
    (interp buffer sizes, feedback timing) mapped to ChoomLink's proxy-follow
    architecture, plus a "feels good" acceptance checklist usable in playtests;
(c) a **player-journey blueprint**: install-to-first-session flow with the
    documented friction points to avoid;
(d) a **community playbook** sized for zero budget and one developer;
(e) a **legal do/don't list** with sources, separating established fact from
    inference;
(f) a **sustainability section**: scope/contributor/funding/burnout guidance
    with named precedents;
(g) a **"why projects like this die" risk list** — the failure modes from the
    graveyard, each paired with the mitigation this plan adopts.
