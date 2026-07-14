# AnimFeature-getriebene Puppet-Locomotion (Phase 4b, Spike 1 → produktiv) — Design

> Status: vom Auftraggeber genehmigtes Design (2026-07-13). Entscheidung des
> Auftraggebers: kein isolierter Wegwerf-Spike, sondern direkter produktiver
> Umbau in beweisbaren Stufen. Ersetzt die Proxy-Follow-Locomotion
> (`AIFollowTargetCommand`) für Spieler-Puppets. Bean: `choomlink-mg7p`.
> Recherche-Grundlage: `docs/research/2026-07-13-player-model-findings.md`
> plus Spielcode-Verifikation (decompilierter redscript-Dump, lokal geklont
> nach `..\..\..\..\cp2077-decompiled`, Codeberg adamsmasher/cyberpunk).

## Ziel

Remote-Spieler-Puppets bewegen sich **direkt aus Netzwerkdaten**: Position
per clientseitiger Interpolation, Lauf-Animation per `AnimFeature_Movement`-
Feed an den Locomotion-Blendgraphen — ohne KI-Kommandos. Damit fallen
strukturell weg: das 50-Puppet-KI-Budget-Limit (empirisch 2026-07-13), die
`AIFollowTargetCommand`-Stop-Totzone (stehen/sprinten auf engen Kreisen) und
das Proxy-Entity pro Spieler (halbiert die gespawnten Entities).

## Spielcode-Befunde (Grundlage, 2026-07-13 verifiziert)

1. **`AnimationControllerComponent.ApplyFeature(obj: ref<GameObject>,
   inputName: CName, value: ref<AnimFeature>, opt delay: Float)`** — public,
   statisch, entity-generisch, pures redscript
   (`core/components/animationControllerComponent.swift:30`). Das Spiel
   selbst nutzt es laufend auf NPC-Puppets: `n"hit"` (HitReactions),
   `n"CoverStance"`, `n"Equip"`/`n"Unequip"`, `n"NonCombatAim"`.
2. **Vererbungs-Trick für die Setter:** `AnimFeature_Movement` bietet aus
   redscript nur `SetSpeed(Float)`. `AnimFeature_PlayerMovement` **extends
   AnimFeature_Movement** und ergänzt `SetMovementDirection(Vector4,
   Vector4)`, `SetFacingDirection(Vector4)`, `SetVerticalSpeed(Float)`
   (`orphans.swift:47953-47964`). Wir instanziieren die Kind-Klasse — sie
   IST ein `AnimFeature_Movement` für jeden Graph-Input dieses Typs.
   Native Struktur (RED4ext-Header, v2.31): `movementDirection: Vector4`,
   `speed`, `desiredSpeed`, `stabilizedSpeed`, `acceleration`,
   `timeToChangeLocomotion`, `strafeYaw`, `yawSpeed`: Float,
   `locomotionState: Int32`.
3. **`SetAnimationParameterFeature`** existiert nur auf
   `StateGameScriptInterface` (Player-State-Machine) — für NPCs irrelevant,
   `ApplyFeature` ist der generische Weg.
4. **Offen (klärt Stufe 1):** (a) der **Graph-Input-Name**, unter dem der
   NPC-Locomotion-Graph das Movement-Feature liest — steht in den
   `.animgraph`-Assets, nicht in Skripten; Kandidaten empirisch testen
   (`n"Movement"` zuerst), sonst WolvenKit-Blick in den NPC-Animgraph.
   (b) Ob die native Movement-Engine das Feature auf NPCs pro Tick
   **überschreibt** — dann `ApplyFeature` pro Frame statt pro Update, im
   schlimmsten Fall Fallback (unten).

## Architektur

**Server: null Änderungen.** TeleportEntity-Pakete kommen weiter mit 10 Hz
plus Distanz-Falloff (Phase 2a). Kein Protokoll-Touch, keine
6-Stellen-Checkliste.

**Client: der `eTeleportEntity`-Pfad wird zerlegt in die zwei Aufgaben, die
bisher die Follow-KI beide erledigt hat:**

### 1. Position bewegen — C++, pro Frame

`m_movementState` (NetworkGameSystem.h) wird umgebaut: statt
`{proxyId, proxyRequested, followIssued, followCommand}` speichert es pro
Puppet `{targetPosition, targetYaw, velocity, lastUpdateTime}`.

- **Beim Netzwerk-Update** (`eTeleportEntity`): neues Ziel speichern;
  `velocity` = Positionsdelta ÷ Zeit seit letztem Update (damit skaliert
  die Interpolation automatisch mit dem Falloff-Tier: 10 Hz nah, 2 Hz fern).
- **Pro Frame** (`OnNetworkUpdate`, läuft jeden Frame): jedes Puppet um
  `velocity · dt` Richtung Ziel bewegen (`SetEntityPosition`, existiert
  schon), Yaw mitführen. Am Ziel angekommen: stehen bleiben (speed → 0).
  Klassische Client-Side-Interpolation (Rust/FiveM-Muster) — das Puppet
  erreicht das Ziel ungefähr beim Eintreffen des nächsten Updates.
- **Desync-Ventil bleibt:** Distanz zum Ziel > 8 m → Hard-Teleport
  (unverändert zur heutigen Regel).

### 2. Beine animieren — redscript, pro Update (bei Bedarf pro Frame)

Neue redscript-Funktion im bestehenden `NetworkGameSystem.reds`:

```
public func DriveLocomotion(entity: ref<Entity>, speed: Float,
                            direction: Vector4, facing: Vector4)
```

Instanziiert/cached ein `AnimFeature_PlayerMovement` pro Puppet, setzt
`SetSpeed(speed)` + `SetMovementDirection(direction, facing)` +
`SetFacingDirection(facing)` und ruft
`AnimationControllerComponent.ApplyFeature(puppet, n"<InputName>", feature)`.
Aufgerufen aus C++ per `Red::CallVirtual` bei jedem Netzwerk-Update mit den
in Schritt 1 berechneten Werten. Der Locomotion-Blendgraph erledigt
Walk/Jog/Sprint-Blending und Übergänge nativ — dieselben Daten, die er sonst
von der KI bekommt.

### Was ersatzlos entfällt (nach Stufen-Erfolg)

- `CreateMovementProxy` / `MoveProxy` / `StartFollowingProxy` (redscript)
- Proxy-Spawn-Logik + Follow-Zustand im C++-`eTeleportEntity`-Pfad
- Das unsichtbare Proxy-Entity pro Spieler (Character.Judy-Trick)
- `TeleportIfNotPuppet` bleibt (Fahrzeuge/Items unverändert).

## Umbau-Stufen (produktiv, aber einzeln beweisbar)

**Stufe 1 — Animations-Beweis (klärt die offene Engine-Frage zuerst).**
Bestehender Pfad bleibt an; zusätzlich eine Testschleife, die auf einem
stehenden Puppet per `DriveLocomotion` konstante Werte setzt (z. B. speed 3,
Richtung vorwärts). *Erfolg:* Beine laufen sichtbar (Screenshot-Burst,
Posen-Vergleich). *Klärt:* Input-Name (Kandidaten durchprobieren, notfalls
WolvenKit-Animgraph-Dump) und Überschreib-Frage (Werte flackern zurück →
pro Frame anwenden). Erst nach Stufe-1-Erfolg wird Bestehendes angefasst.

**Stufe 2 — Interpolation ersetzt Proxy-Follow.** C++-Umbau wie oben;
Proxy-Bausteine raus. *Erfolg:* Bot-Kreis (4 Bots, 5–8 m) läuft flüssig und
**ohne sichtbares Fußgleiten** — die Skyrim-Together-Warnung (deren
öffentliches Issue #372: Root-Motion vs. Netzwerk-Position) ist explizites
Prüfkriterium: Screenshot-Burst durch mich, Feel-Urteil beim Auftraggeber.
Regression: Boundary-/Fern-Bots weiter korrekt (Spawn/Despawn-Zähler).

**Stufe 3 — Dichte-Test.** Exakt der 50-Bot-Aufbau vom 2026-07-13
(Vergleichsbasis dokumentiert in
`2026-07-13-interest-management-design.md`). *Erfolg:* kein
Teleport-Stottern mehr bei 50 Puppets; Netzwerk-Zähler weiter verlustfrei.

## Fallback (wenn Stufe 1 endgültig scheitert)

Diskrete Zustands-Events per `AnimationControllerComponent.PushEvent`
(entity-generisch bestätigt, wird für Jump schon benutzt): Schwellen auf der
berechneten Geschwindigkeit → `idle`/`walk`/`jog`/`sprint`-Übergänge. Gröber
als echtes Blending, aber Stufe 2 (Interpolation) und Stufe 3 (Dichte)
bleiben unverändert gültig — der Architektur-Gewinn hängt nicht am
Feature-Feed.

## Randfälle

- **Jump/Actions:** `PuppetAction`-Pfad (PushEvent) unverändert.
- **Ruhende Puppets:** keine Updates → Interpolation läuft aus (speed 0,
  Idle) — kein Timer nötig.
- **Falloff-Fernbereich (2 Hz):** velocity-basierte Interpolation
  überbrückt 500 ms glatt; 8-m-Regel fängt Ausreißer.
- **Spawn:** erstes Update setzt Ziel = Ist (kein Sprung); die bestehende
  Frisch-Spawn-Sonderbehandlung (Position 0,0,0) bleibt.
- **Kollision:** interpolierte Positionen ignorieren Geometrie — für
  Spieler-Puppets akzeptiert (der Sender kollidiert real). Clipping an
  Türen/Wänden wird in Stufe 2 beobachtet, nicht vorab gelöst.
- **Vehikel:** `TeleportIfNotPuppet` unverändert; Mount/Unmount-Pakete
  unberührt.

## Tests & Verifikation

1. **Kein neues Unit-Test-Terrain:** Änderung ist rein clientseitig
   (C++/redscript, engine-gebunden) — Verifikation läuft über Bot-Harness +
   `ingame-verify`, wie bei Proxy-Follow.
2. **Stufe 1:** Screenshot-Burst eines stehenden Puppets mit aktivem
   Feature-Feed — Beinposen variieren über den Burst.
3. **Stufe 2:** (a) 4-Bot-Kreis nah: flüssig, kein Fußgleiten, kein
   Stop-and-Go (der Totzonen-Bug ist damit strukturell weg — Gegenprobe);
   (b) Boundary-Bot 440 m: Spawn/Despawn-Zähler wie Phase 1;
   (c) Fern-Bot 300 m: 2-Hz-Interpolation glatt (kein 8-m-Teleport im Log).
4. **Stufe 3:** 50 Bots, gleicher Aufbau wie 2026-07-13: Screenshot-Burst
   (keine Teleport-Sprünge), Server-Zähler verlustfrei, FPS-Eindruck vom
   Auftraggeber.
5. **Logs:** kein `AIFollowTargetCommand` mehr im Trace; 8-m-Catch-up nur
   noch bei echten Desyncs.

## Upstream-Verhältnis

Clientseitiger Umbau im Fork (red4ext + RedscriptModule). Als Upstream-PR
erst sinnvoll, wenn Stufe 3 bestanden ist — dann als Paket
"AI-free locomotion" anbieten.

## Stufe-1/2-Ergebnisse (2026-07-14, nach Implementierung)

**Was funktioniert (verifiziert):**
- **Interpolation ersetzt Proxy-Follow vollständig.** 4-Bot-Kreis: Puppets
  gleiten exakt auf der Netzwerkbahn, **null 8-m-Catch-up-Teleports** im
  Log (vorher der Dauerzustand bei Desyncs), Zähler stabil/verlustfrei,
  keine Fehler. Proxy-Entity, Follow-Kommando und damit KI-Budget-Verbrauch
  und Stop-Totzone sind ersatzlos weg.
- **Event-Pipeline bis zum Entity:** native Feature-Konstruktion
  (`Red::MakeScriptedHandle`) + `AnimInputSetterAnimFeature`-`QueueEvent`
  laufen fehlerfrei (keine Warnungen).

**Was (noch) nicht funktioniert:** Beinanimation. Puppets bewegen sich in
Idle-Pose ("gleiten"). Fünf In-Game-Zyklen, alle Hypothesen dokumentiert:

1. Runde 1 (redscript, `AnimFeature_PlayerMovement` unter 6 Namen): negativ —
   **falsche Klasse**, der NPC-Graph liest kein `AnimFeature_Movement`.
2. WolvenKit-Dump `base\gameplay\anim_graphs\humanoid.animgraph` (420 MB
   JSON): Feature-Inputs explizit deklariert — `locomotion`
   (`AnimFeature_Locomotion`), `crowd_locomotion`/`crowdAnimFeature`
   (Crowd), `lookAt`, `hit`, `stanceState`… **Landkarte für alle künftigen
   Spikes.** Transition-Conditions decodiert: `locomotion.action` ist
   `move::LocomotionAction` (Greater 1 = bewegt; 5=Start/6=Move/7=Stop),
   `locomotion.style` ist `Locomotion_Style` (2=Walk/3=Jog/4=Sprint).
3. Runde 2-4 (C++-Feed, korrekte Klassen+Enums, pro Update → pro Frame →
   plus Crowd-Zweig): alle negativ.
4. **PushEvent-Fallback der Spec ist falsifiziert:** die
   `ExternalEvent`-Vokabeln des Graphen sind reine Kampf-Events
   (hit/Shoot/Reload) — es gibt keine Locomotion-Events.

**Arbeits-Hypothese (nach Runde 1-4):** Der residente KI-/Movement-Stack des
Puppets schreibt die Locomotion-Features jeden Tick und gewinnt gegen unsere
Events; ein Script-Hebel zum Abschalten existiert nicht (`AIComponent`
bietet nur `StopExecutingCommand`/`DisableCollider`).

**Diskriminator-Runden 5-7 (hit-Feature, 2026-07-14) — Hypothese verschärft:**
Ein `hit`-Feature (`hitType=3` Stagger) wurde als unübersehbarer Testfall
alle 2,5 s auf stehende Puppets angewandt — (a) per direktem
`AnimInputSetterAnimFeature`-QueueEvent, (b) per Spiel-eigenem
`AnimationControllerComponent.ApplyFeature`-Helper, (c) zusätzlich mit
`PushEvent(n"hit")` (der Graph hat 16 ExternalEvent-Transitions auf "hit").
**Alle drei negativ — kein Stagger.** Der decompilierte Spielcode erklärt
warum (`aiHitReactionTasks.swift:402-405`): normale Treffer starten ein
**`m_hitReactionAction`-Objekt** (`Stop/Setup/Launch`) aus dem KI-Action-
System; Feature+Event sind nur Begleitdaten. **Strukturelle Erkenntnis:
NPC-Animationen sind durchgängig hinter der KI-Action-Maschinerie gekapselt
— von außen geschriebene Features/Events allein treiben den Graphen nicht.**

**Offene Forschungspfade (Aufwand geschätzt):**
1. **KI-Action-Route:** die `AIActionAnimation`-/ActionHelper-Objekte
   verstehen und selbst starten (wie `m_hitReactionAction`) — mittlerer
   RE-Aufwand, bleibt aber im KI-Budget-Problem (Actions laufen im
   AI-Kontext).
2. **AI-freies Puppet-Template:** eigenes `.ent` ohne KI-Komponenten
   (ArchiveXL, Spike-4-Territorium) — klärt, ob der Graph ohne residenten
   KI-Stack auf externe Features hört; passt zur langfristigen
   "eigenes Spielermodell"-Richtung. Aufwand: Asset-Arbeit + Spawn-Umbau.
3. **Workspot-/Slot-Animation-Route:** Walk-Zyklen als Slot-Anims direkt
   abspielen (AMM-Posen-Muster) — garantiert sichtbar, aber Blending/
   Übergänge manuell.
4. **Pragmatischer Zwischenstand:** Nah-Cap-Hybrid (Proxy-Follow nur für
   die N nächsten Puppets, Interpolation für alle weiteren) — ein Tag,
   löst Dichte + Nah-Feel mit bewährter Technik, überbrückt bis 1-3.

## Quellen-Notiz

Spielcode-Zitate stammen aus dem öffentlichen decompilierten
redscript-Dump (Codeberg adamsmasher/cyberpunk, lokal:
`C:\Users\G4M3R\Programming\cp2077-decompiled`). CyberpunkMP-Quellcode
wurde nicht gelesen (Projektregel).
