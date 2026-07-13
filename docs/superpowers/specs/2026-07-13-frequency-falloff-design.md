# Frequenz-Falloff nach Distanz (Phase 2a) — Design

> Status: vom Auftraggeber genehmigtes Design (2026-07-13). Scope-Entscheidung:
> Phase 2 wurde geteilt — (a) Frequenz-Falloff jetzt (dieses Dokument, nur
> Server), (b) Quantisierung/Delta-Encoding später, wenn Bandbreite real
> drückt (YAGNI; Protokolländerung an 6 Stellen wäre nötig).
> Baut auf dem verifizierten Interest-Management auf
> (`2026-07-13-interest-management-design.md`).

## Ziel

Ferne Spieler bekommen Positions-Updates seltener als nahe: die Bandbreite
pro Beobachter sinkt bei dichten Szenen um einen Faktor ~3–5, ohne sichtbaren
Qualitätsverlust — ein 2m-Schritt in 300m Entfernung ist wenige Pixel.

## Mechanik

- Der `EntityTracker` führt **pro Entity einen Update-Zähler** (jedes
  eingehende Positions-Update inkrementiert; `ulong`, Überlauf irrelevant).
- Beim Versand an einen einzelnen Tracker entscheidet die **ohnehin schon
  berechnete Distanz** (aus der Hysterese-Prüfung) das Tier, und das Tier
  einen Teiler: gesendet wird nur, wenn `counter % divisor == 0`.
- Kein neuer Per-Paar-State, keine Timer — reine Arithmetik auf dem
  vorhandenen Versandpfad in `UpdateTrackingOf`.

## Tiers (Defaults, konfigurierbar)

| Distanz | Rate (bei 10-Hz-Sender) | Teiler |
|---|---|---|
| 0–100 m | 10 Hz (jedes Update) | 1 |
| 100–250 m | ~3,3 Hz (jedes 3.) | 3 |
| 250 m–Exit-Radius | 2 Hz (jedes 5.) | 5 |

**Warum Fern-Tier 2 Hz statt 1 Hz:** Ein sprintender Spieler (~9 m/s) legt
zwischen 1-Hz-Updates bis zu 9 m zurück — das würde clientseitig den
8m-Catch-up-Teleport triggern (sichtbares Springen). Bei 2 Hz bleibt die
Lücke ≤ 4,5 m; der Proxy-Follow glättet das.

**Keine Hysterese an Tier-Grenzen nötig:** Ein Distanz-Flackern zwischen
Tiers wechselt nur die Rate (unsichtbar), nie Spawn/Despawn.

## Konfiguration

Erweiterung von `config.json` (bestehende `ServerConfig`/`InterestConfig`):

```json
{
  "interest": {
    "enterRadius": 425.0,
    "exitRadius": 470.0,
    "cellSize": 470.0,
    "falloff": [
      { "maxDistance": 100.0, "divisor": 1 },
      { "maxDistance": 250.0, "divisor": 3 },
      { "maxDistance": 1e9,   "divisor": 5 }
    ]
  }
}
```

Validierung: Liste nach `maxDistance` aufsteigend sortiert, `divisor >= 1`;
bei Verstoß Warnung + Default-Tiers (Muster aus Phase 1). Fehlt `falloff`,
gelten die Default-Tiers. Das letzte Tier fängt alles bis zum Exit-Radius
ab (`1e9`-Sentinel statt Sonderfall-Logik).

## Was sich NICHT ändert

- **Protokoll: null Änderungen.** Keine 6-Stellen-Checkliste, kein
  Client-Deploy, keine Bot-Harness-Protokolländerung.
- Spawn/Despawn-Logik und Hysterese (Phase 1) unverändert.
- **Action-Routing ohne Falloff:** Jumps/Hits sind seltene Einzel-Events —
  die gehen immer sofort an alle Tracker. Falloff dort wäre spürbar
  (verpasster Sprung) ohne relevante Ersparnis.
- `InitialSpawnForPlayer`/Join-Verhalten unverändert (Spawn enthält die
  Position; das erste reguläre Update folgt spätestens nach `divisor`
  Sender-Ticks).

## Randfälle

- **Frisch getrackte Entity:** SpawnEntity trägt die aktuelle Position —
  kein "leeres" Intervall. Erstes Teleport-Update folgt nach spätestens
  `divisor` Ticks (500 ms worst case, fern) — akzeptiert.
- **Tier-Wechsel:** wirkt ab dem nächsten Update automatisch (Distanz wird
  je Update neu bewertet). Kein State zum Aufräumen.
- **Ruhende Entities:** senden keine Updates — Falloff ändert nichts (der
  Zähler tickt nur bei Bewegung).

## Tests & Verifikation

1. **Unit-Tests** (bestehendes Testprojekt, RecordingSink):
   - Beobachter bei 50 m: 10 Updates → 10 Teleports.
   - Beobachter bei 150 m: 10 Updates → 3–4 Teleports (je nach Zählerphase).
   - Beobachter bei 300 m: 10 Updates → 2 Teleports.
   - Zwei Beobachter (50 m und 300 m) gleichzeitig: einer bekommt 10, der
     andere 2 — aus demselben Update-Strom.
   - Entity wandert von 50 m auf 300 m: Rate sinkt entsprechend.
   - Config-Validierung: unsortierte Tiers/divisor 0 → Defaults.
2. **Bot-Messung:** Boundary-Bot `--distance 300` um einen Beobachter:
   Beobachter empfängt ~2 Teleports/s statt 10. Nahbots (Kreis, ~10 m):
   unverändert ~10/s pro Peer (Regression).
3. **In-Game** (`ingame-verify`): Nahbots unverändert flüssig (Regression);
   ein Bot bei ~300 m bewegt sich noch glaubwürdig für die Distanz —
   Screenshot-Burst + mein Urteil, Feinheit beim Auftraggeber.

## Upstream-Verhältnis

Wie Phase 1: reine Server.Managed-Änderung, upstream-PR-fähig als Teil des
Interest-Management-Pakets.
