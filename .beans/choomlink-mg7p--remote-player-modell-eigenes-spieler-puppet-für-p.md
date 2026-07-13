---
# choomlink-mg7p
title: 'Remote-Player-Modell: eigenes Spieler-Puppet für PvP-Darstellung (Research + Entwicklung)'
status: todo
type: epic
priority: high
created_at: 2026-07-13T15:42:24Z
updated_at: 2026-07-13T17:16:57Z
---


EMPIRISCHER BEFUND (2026-07-13, 50-Bot-Dichte-Test während Phase-1-Verifikation): Bei 50 gleichzeitig sichtbaren Proxy-Follow-Puppets verteilt die Engine ihr KI-Budget auf 50 aktive AIFollowTargetCommands — Puppets fallen laufend über die 8m-Catch-up-Schwelle, sichtbar als 'rennen in eine Richtung, teleportieren in eine andere' (Beobachtung Auftraggeber). Netzwerk-Schicht war dabei verlustfrei (24.500 Pakete/s). Bei 4-8 Puppets flüssig. Das Dichte-Limit der AI-basierten Darstellung liegt zwischen 8 und 50 — dieses Epic ist damit nicht nur PvP-Qualität, sondern auch die Dichte-Skalierung (Events, Encounter-Zonen). Bisektionstest 16/24/32 als erster Schritt des Research-Spikes sinnvoll.
