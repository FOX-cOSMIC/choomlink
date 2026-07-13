---
# choomlink-d18m
title: 'NPC-Sync: Ownership + Handover für kuratierte Gameplay-NPCs (Ziel ~100)'
status: todo
type: feature
priority: normal
created_at: 2026-07-13T08:36:15Z
updated_at: 2026-07-13T08:36:15Z
---

Phase 5 der Zielarchitektur-Roadmap (docs/research/2026-07-12-architecture-decision.md).

Zwei NPC-Klassen strikt getrennt (FiveM-Vorbild):
- Ambiente NPCs (Verkehr, Passanten): bleiben client-lokal, KEIN Sync.
- Gameplay-relevante NPCs (Encounter-Gegner, Bosse, Händler): synced mit demselben Bauplan wie Remote-Spieler.

Bausteine:
- Ownership: ein Client besitzt die NPC, simuliert KI/Pfadfindung lokal, meldet Zustand als Fakten; Zuweisung proximity-basiert.
- Darstellung auf anderen Clients: Proxy-Follow-Puppet (bestehende Lokomotions-Architektur wiederverwenden).
- Handover: Hysterese-Band wie alt:V (Stream 400 / Migration 150) gegen Ownership-Flackern; explizites Disconnect-Cleanup (FiveM-Footgun: verwaiste Entities).
- Kampf gegen NPCs: gleiches Hit-Gate wie PvP — Server committet NPC-HP als Transaktion.

Ziel: ~100 gleichzeitig aktive kuratierte NPCs, vor jeder Zusage per Bot-Harness lastgetestet (Bots als NPC-Owner-Simulatoren).

Voraussetzungen: Interest-Management (Phase 1) und Kampf-Hit-Gate (Phase 4) — sonst reproduziert NPC-Sync sofort das O(n²)-Fanout-Problem.
