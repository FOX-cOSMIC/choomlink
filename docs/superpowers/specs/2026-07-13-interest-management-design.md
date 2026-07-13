# Interessens-Management (Phase 1) — Design

> Status: vom Auftraggeber genehmigtes Design (2026-07-13). Ansatz C
> (Spatial Grid) auf Wunsch des Auftraggebers statt des minimaleren
> Ansatzes B — inkl. aller Härtungen, die B enthalten hätte.
> Kontext: Phase 1 der Zielarchitektur-Roadmap
> (`docs/research/2026-07-12-architecture-decision.md`).

## Ziel

Der Server sendet Positions-Updates, Spawn/Despawn und Actions nur noch an
Spieler, für die die betreffende Entity relevant ist (Distanz-basiert),
statt an alle. Wandelt den O(n²)-Payload-Fanout in O(n·k) und beseitigt
dabei fünf konkrete Schwächen des bestehenden `EntityTracker`-Prototyps.

## Ist-Zustand (choomlink-core, server/Managed)

`EntityTracker` hat bereits ein primitives Interessens-Management:
hartkodierter 100m-Radius, Spawn/Despawn beim Überschreiten, per-Spieler-
Tracked-Set, ein `EntityVisibilityFilter`-Hook für Plugins. Der Code nennt
sich selbst "hacked prototype". Gefundene Schwächen:

1. Keine Hysterese — eine harte Schwelle, Spawn/Despawn-Flackern an der
   Grenze (das dokumentierte Boundary-Thrashing-Problem aus FiveM/alt:V).
2. 100m ist zu kurz für Night-City-Sichtlinien — Remote-Spieler poppen
   mitten im Sichtfeld weg (FiveM-Referenz: 424 Einheiten).
3. `EntityAction` (Jump, später Hits) umgeht den Tracker — geht an ALLE
   Spieler, egal wie weit weg (`PlayerPacketHandler.HandleActionTracked`).
4. `_trackedEntities` (Dictionary connectionId → List) wird beim Disconnect
   nie bereinigt; `List.Contains` ist O(n).
5. Pro Positions-Update LINQ-Query über alle SpawnedEntities
   (`HandlePositionUpdate`, `UpdateTrackingOf`).
6. (Beim Lesen gefunden, wird mitgefixt:) Tracking wird nur aktualisiert,
   wenn sich die *beobachtete* Entity bewegt. Ein Spieler, der sich einer
   ruhenden Entity nähert, beginnt nie sie zu tracken. Fällt heute nicht auf
   (alles sendet 10 Hz), bricht aber, sobald Phase 2 ruhende Entities
   überspringt.

## Architektur

Zwei Bausteine, klare Schnittstelle:

### SpatialGrid (neu: `server/Managed/Services/SpatialGrid.cs`)

- Unterteilt die Welt in quadratische Zellen; **2D (X/Y)** — die Höhe fließt
  in die exakte Distanzprüfung ein, nicht in die Zellstruktur (Night City
  ist horizontal riesig, vertikal ~200m; ein 3D-Grid verwaltete fast nur
  leere Zellen).
- Datenstruktur: `Dictionary<(int cx, int cy), HashSet<Entity>>`; jede
  Entity merkt sich ihre aktuelle Zelle. `Move(entity)` prüft auf
  Zellwechsel und hängt bei Bedarf um (zwei HashSet-Operationen). `Remove`
  beim Entity-Despawn.
- **Query ring-generisch** (Entscheidung nach Nachfrage des Auftraggebers):
  `QueryCandidates(position, radius)` durchsucht `ceil(radius / cellSize)`
  Ringe um die Ausgangszelle — keine fest verdrahtete 3×3-Annahme. Damit ist
  die Zellgröße ein freier Tuning-Parameter: heute Default = Exit-Radius
  (470) → effektiv 3×3; wenn NPC-Sync (Phase 5) die Dichte hochtreibt,
  können kleinere Zellen per Config erprobt werden, ohne Code-Änderung.
- Das Grid ist ein reiner **Kandidaten-Vorfilter**. Die präzise
  3D-Distanzprüfung (`DistanceSquared`) entscheidet wie bisher. Korrektheit
  hängt damit nie an der Zellgeometrie.

### EntityTracker-Härtung (bestehende Datei)

- **Hysterese-Band:** nicht getrackte Entity wird getrackt, wenn Distanz ≤
  **Enter-Radius (Default 425)**; getrackte Entity wird erst despawnt, wenn
  Distanz > **Exit-Radius (Default 470)**. Welcher Radius gilt, entscheidet
  der aktuelle Tracked-Zustand des Paars (Spieler, Entity).
- **Beidseitige Aktualisierung:** Bewegt sich eine Entity, wird (a) für alle
  Kandidaten-Spieler deren Tracking dieser Entity aktualisiert (wie bisher)
  und (b) falls die Entity einem Spieler gehört, auch das Tracking dieses
  Spielers gegenüber allen Kandidaten-Entities (fixt Schwäche 6).
- **Reverse-Index:** zusätzlich zum bestehenden Tracked-Set pro Spieler
  hält der Tracker `Dictionary<ulong entityId, HashSet<uint> trackers>` —
  beide Richtungen werden in `OnStart/OnStopTrackingEntity` synchron
  gepflegt. Er dient zwei Zwecken: (a) Action-Routing und Teleport-Versand
  in O(1) ("wer trackt Entity X?"), (b) **Despawn-Korrektheit**: der
  Grid-Vorfilter liefert nur Spieler *innerhalb* des Query-Radius — ein
  Spieler, der aus dem Radius gefallen ist, taucht dort nicht auf und würde
  die Entity nie despawnt bekommen. Deshalb läuft die Exit-Prüfung über die
  aktuellen Tracker (Reverse-Index), nicht über die Grid-Kandidaten.
- **Action-Routing:** `HandleActionTracked` nutzt
  `GetPlayersTracking(entity)` (Reverse-Index) statt über alle
  ConnectedPlayers zu iterieren.
- `HashSet<ulong>` statt `List<ulong>`; `OnPlayerDisconnected(connectionId)`
  entfernt den Tracked-Set-Eintrag (Aufruf aus
  `GameServer.OnConnectionStateChange`).
- Der bestehende `EntityVisibilityFilter`-Hook bleibt unverändert erhalten
  (Plugin-Kompatibilität; künftige Bucket-/Dimension-Logik aus Phase 6
  dockt hier an).

### Konfiguration (neu: `server/Managed/ServerConfig.cs` + `config.json`)

JSON-Datei neben der Server-Exe, geladen beim Start, mit Defaults wenn
fehlend/unvollständig:

```json
{
  "interest": {
    "enterRadius": 425.0,
    "exitRadius": 470.0,
    "cellSize": 470.0
  }
}
```

Validierung beim Laden: `exitRadius > enterRadius > 0`, `cellSize > 0`;
bei Verstoß Warnung loggen und Defaults verwenden (Server startet immer).

## Datenfluss (Positions-Update)

1. `HandlePositionUpdate` → Entity-Transform aktualisieren
2. `grid.Move(entity)` (nur bei Zellwechsel teuer)
3. **Enter-Seite:** `grid.QueryCandidates(entity.pos, enterRadius)` →
   Spieler-Kandidaten in der Nähe; pro Kandidat, der die Entity noch nicht
   trackt und ≤ enterRadius ist: `OnStartTrackingEntity` (SpawnEntity-Paket)
4. **Exit-Seite:** über den Reverse-Index (aktuelle Tracker der Entity),
   NICHT über die Grid-Kandidaten: jeder Tracker mit Distanz > exitRadius →
   `OnStopTrackingEntity` (DestroyEntity-Paket). So werden auch Spieler
   erfasst, die längst außerhalb des Query-Radius sind.
5. An alle verbleibenden Tracker (Reverse-Index): `TeleportEntity`-Paket
   (Positions-Update; Name ist Protokoll-Erbe — das sichtbare Puppet
   teleportiert nicht, es folgt dem Proxy)
6. Gehört die bewegte Entity einem Spieler: Schritte 3–5 zusätzlich aus
   Sicht dieses Spielers gegenüber Kandidaten-Entities (Schwäche 6)

**Keine Protokolländerung, keine Client-Änderung.** Spawn/Despawn/Teleport/
EntityAction-Pakete existieren alle schon; es ändert sich nur, wer sie
bekommt. Die 6-Stellen-Packet-Checkliste wird nicht berührt.

## Fehlerfälle / Randfälle

- **Entity exakt auf Zellgrenze:** Zellzuordnung per `floor(coord/cellSize)`
  ist deterministisch; Korrektheit hängt eh an der Distanzprüfung.
- **Radius > cellSize (Config):** ring-generische Query deckt es ab.
- **Disconnect:** Grid-`Remove` für alle Entities des Spielers (passiert
  über bestehendes `RemoveEntity`) + Tracked-Set-Cleanup + die Entities
  verschwinden bei anderen über bestehendes `StopTrackingOf`.
- **Join (InitialSpawnForPlayer):** nutzt künftig ebenfalls die Grid-Query
  statt über alle Entities zu iterieren — gleiche Semantik, ein Codepfad.
- **Fehlende/kaputte config.json:** Defaults + Warnung, kein Startabbruch.

## Tests & Verifikation

1. **Unit-Tests** (neues Projekt `server/Managed.Tests`, xUnit — erstes
   Testprojekt im Repo):
   - SpatialGrid: Einfügen/Move/Remove, Zellwechsel, Positionen exakt auf
     Zellkanten, Query-Vollständigkeit (Property-artig: alle Entities im
     Radius sind in den Kandidaten), Radius > cellSize.
   - Hysterese: Oszillation innerhalb des Bands (426→468→426…) erzeugt nach
     dem initialen Spawn null weitere Spawn/Despawn-Übergänge; Übergang
     erst außerhalb.
   - Despawn-Korrektheit über Reverse-Index: Entity springt weit (>Query-
     Radius) — alle bisherigen Tracker bekommen genau ein Despawn; Tracked-
     Set und Reverse-Index bleiben konsistent (beide Richtungen geprüft,
     auch nach Disconnect-Cleanup).
   - Config-Validierung (exit ≤ enter → Defaults).
2. **Bot-Harness** (Erweiterung `tools/bot-harness`):
   - Neues Pattern `--pattern boundary --distance <m>`: Bots pendeln radial
     um eine konfigurierbare Distanz zum Ursprung (z. B. 440±20 → im Band).
   - Bot-seitige Zähler existieren schon (teleports/actions received) —
     Erfolgskriterien: (a) Fernbot (>500m) empfängt 0 Teleports/Actions
     eines Nahbots, (b) Band-Pendler erzeugt keine wiederholten
     SpawnEntity/DestroyEntity beim Gegenüber (neuer Zähler: spawns/despawns
     received), (c) Nahbots verhalten sich unverändert (Regression).
3. **50-Bot-Dichte-Test** (Frage des Auftraggebers "50 Spieler in einem
   Grid"): `--count 50`, enges Kreis-Pattern, ein echter Client mittendrin —
   misst Client-FPS/Verhalten bei ~100 always-spawned Entities (50 Puppets +
   50 Proxies) und Server-Paketrate (~24.500 Positions-Pakete/s) auf realer
   Hardware. Ergebnis fließt in die Dichte-Erwartungen für Phase 5 ein.
   Achtung: ggf. limitiert der Client vorher — das ist dann selbst der
   Befund (Proxy-Konstruktion unter Dichte), kein Testfehler.
4. **In-Game** (`ingame-verify`): Bot bei ~400m sichtbar; nach Entfernen auf
   >470m despawnt; Jump eines Fernbots kommt nicht an (CET-Log/Screenshot).

## Nicht-Ziele (Phase 1)

- Kein Frequenz-Falloff, keine Quantisierung/Delta (Phase 2).
- Keine Entity-Ownership-Migration (Phase 5 — Grid ist dafür vorbereitet).
- Keine Buckets/Dimensionen (Phase 6 — Filter-Hook bleibt als Andockpunkt).
- Kein Versions-Check beim Join (separates, kleines Arbeitspaket aus der
  Versionspinning-Entscheidung).

## Verifikations-Ergebnisse (2026-07-13, nach Implementierung)

- **Unit-Tests:** 24/24 grün (Config 4, SpatialGrid 8, EntityTracker 12 —
  inkl. beider Despawn-Korrektheits-Richtungen und Hysterese-Oszillation).
- **Fern-Isolation (headless):** 2 Gruppen à 4 Bots, 1414m getrennt — exakt
  120 Teleports/s je Gruppe (nur eigene 3 Peers × 10 Hz), 12 Spawns je
  Gruppe, 0 Despawns, kein Cross-Traffic.
- **Boundary-Hysterese (headless):** Bot pendelt 417,5–462,5m um Beobachter,
  130 s: exakt 1 Spawn, 0 Despawns, Position fließt mit 10/s. Gegenprobe
  Pendel um 500m: 0 Spawns über 45 s.
- **Action-Isolation (in-game-Session):** Nahgruppe empfing 0 Actions,
  während die Ferngruppe (600m) untereinander 92 Jump-Actions austauschte.
- **50-Bot-Dichte:** Netzwerk-Schicht verlustfrei (24.500 Teleports/s
  empfangen = exakt 50×49×10 Hz; Server ~0 CPU, 112 MB). In-Game bestätigt
  der Test die vermutete Grenze der **Darstellungs-Schicht**: Puppets
  hängen hinter ihren Proxies (Engine-KI-Budget auf 50 aktive
  AIFollowTargetCommands verteilt), der 8m-Catch-up-Teleport feuert laufend
  — sichtbar als "rennen in eine Richtung, teleportieren in eine andere"
  (Beobachtung des Auftraggebers). Bei 4–8 Bots flüssig (mehrfach
  verifiziert). **Folgerung: Dichte-Limit der heutigen Proxy-Follow-
  Darstellung liegt zwischen 8 und 50 gleichzeitig sichtbaren Puppets;
  Bisektion (16/24/32) steht aus. Nachhaltiger Fix ist das Phase-4b-
  Remote-Player-Modell (bean mg7p), kein Tuning der 8m-Konstante.**

## Upstream-Verhältnis

Alle Änderungen liegen in Server.Managed + Bot-Harness — upstream-PR-fähig
zu TDUniverse/Cyberverse als Ersatz des "hacked prototype"-Trackers, ohne
Protokolländerung. Kandidat nach Verifikation.
