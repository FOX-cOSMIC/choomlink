# Remote-Player-Modell (Phase 4b) — Recherche-Ergebnisse & Spike-Plan

> 6 parallele Recherche-Agenten, 2026-07-13. Kein CyberpunkMP-Quellcode
> gelesen (ein Agent stieß per GitHub-Suche zufällig darauf, hat es
> nachweislich nicht geöffnet/verwendet). Quellen: Codeware (MIT),
> CDPR-Modding-Docs (öffentliches Wiki), einzelne MIT/Unlicense-Mods,
> Skyrim Togethers öffentliche Doku, akademische/Industrie-Engine-Literatur.

## Ergebnis in einem Satz

**Die Recherche kippt die Entscheidung von "vielleicht nötig" zu "lohnt sich
mit hoher Wahrscheinlichkeit"** — drei der vier Bausteine (Waffe, Zielhaltung,
Locomotion-Daten) haben dokumentierte, mehrfach unabhängig reproduzierte
Mechanismen; die einzige offene Frage (läuft das auch auf NPCs/Puppets, nicht
nur auf dem Spieler) ist eine einzige, klar umrissene Engine-Frage, die ein
gezielter Spike beantwortet — kein Forschungsprojekt.

## Machbarkeits-Landkarte

| Baustein | Einstufung | Konfidenz |
|---|---|---|
| **Locomotion-Daten füttern** (`AnimFeature_Movement`: Richtung/Speed/Beschleunigung) | Für Spieler dokumentiert per-Tick machbar (redscript, `StateGameScriptInterface`). Für NPCs/Puppets: nur diskrete Events (`PushEvent`) in reinem redscript bestätigt — kontinuierliches Feature-Feeding auf NPCs vermutlich RED4ext-nativ nötig | **Mechanismus: hoch** / **NPC-Anwendbarkeit: offen, Spike nötig** |
| **Waffe in der Hand** | `GiveItem` → `AddItemToSlot` → `AIEquipCommand`, dreifach unabhängig reproduziert, nachweislich auf `DynamicEntitySystem`-Puppets (unsere Spawn-Methode) | **Hoch** |
| **Zielhaltung ohne Kampf-KI** | `LookAtAddEvent`/`IKTargetAddEvent` — natives Event-System, vom Spiel selbst für Scanning/Dialog-Blickkontakt genutzt (Nicht-Kampf), unterstützt Live-Tracking eines Weltpunkts | **Mechanismus: hoch** / **exakte Feldnamen: mittel** (NativeDB-Gegenprobe empfohlen) |
| **Spieler-Rig auf Puppet** | `.ent`→`.rig`/`.animgraph`-Zuweisung ist dokumentiert daten-getrieben und umsteckbar (ArchiveXL); V und NPCs teilen sich den Third-Person-Rig-Pool. Ob eine *laufende* Animgraph-**Instanz** (nicht nur die Asset-Referenz) auf ein zweites Entity übertragbar ist: kein Beleg gefunden | **Assets: hoch** / **Live-Instanz-Sharing: offen, Spike nötig** |
| **Dichte-Fix** (Animation statt KI-Kommando) | Branchenmuster (Unreal Mass AI, Assassin's Creed Unitys "Puppet Bulk": animiert, ohne Pfadfindung) zeigt genau diese Trennung als Standard-Skalierungstechnik. Unser Fall ist günstiger als die Referenzen — die Zielposition ist schon bekannt, keine Entscheidung nötig | **Richtung: hoch** / **Größenordnung für REDengine 4: unbekannt** |

## Technik-Katalog (konkrete APIs)

- **`AnimFeature_Movement`** (Codeware, `@addField`-exponierte native Felder):
  `movementDirection`, `speed`, `desiredSpeed`, `acceleration`, `locomotionState` —
  exakt die Blöcke, die der Locomotion-Blendgraph des Spiels selbst konsumiert.
  Quelle: github.com/psiberx/cp2077-codeware (MIT).
- **`StateGameScriptInterface.SetAnimationParameterFeature(name, feature[, target])`** —
  bewiesen per-Tick in Produktions-Mods (Paraglide, Weapon Inspection), aber
  nur innerhalb der Player-State-Machine beobachtet.
- **`AnimationControllerComponent.PushEvent(entity, name)`** /
  `PushEventToObjAndHeldItems` — entity-generisch, funktioniert auf NPCs,
  reines redscript (ZKV_Takedowns-Mod als Beleg).
- **`TransactionSystem.GiveItem`/`GiveItemByTDBID`** + `AddItemToSlot` +
  `AIEquipCommand` (`AttachmentSlots.WeaponRight`/`WeaponLeft`) — CDPRs
  eigenes Wiki-Tutorial demonstriert das exakt auf einem
  `DynamicEntitySpec`-gespawnten Entity.
- **`LookAtAddEvent extends AnimTargetAddEvent`** / **`IKTargetAddEvent`** —
  natives Event, `QueueEvent`-fähig, unterstützt `RealPosition`-Tracking-Modus
  auf eine statische Weltposition, Body-Part-Gewichtung, Limit-Klammern
  (`softLimitDegrees`/`hardLimitDegrees`).
- **`entAnimatedComponent.rig`/`.graph`** (ResourceRef auf `.rig`/`.animgraph`) —
  per ArchiveXL-`.xl`-Patch umsteckbar, dokumentiertes Modding-Muster
  ("For V or NPC — How to make a rig mod").

## Priorisierter Spike-Plan

**Spike 1 — Locomotion-Daten direkt auf einen Puppet füttern (höchste Priorität).**
*Hypothese:* `AnimFeature_Movement` lässt sich per RED4ext-nativem Aufruf
kontinuierlich auf ein `DynamicEntitySystem`-Puppet schreiben und erzeugt
flüssige Lauf-/Richtungsanimation — ganz ohne `AIFollowTargetCommand`.
*Testaufbau:* Ein Puppet spawnen, statt `AIFollowTargetCommand` einen
RED4ext-Aufruf bauen, der pro Netzwerk-Update `movementDirection`/`speed`
setzt (aus Delta zur letzten Position berechnet). *Erfolgskriterium:*
sichtbar flüssige Bewegung bei 1 Puppet — dann sofort mit 30–50 gleichzeitig
wiederholen (derselbe Bot-Harness-Aufbau wie beim 50-Bot-Test). *Warum
zuerst:* löst potenziell zwei Probleme gleichzeitig (Feel + Dichte-Limit) und
ist die Grundvoraussetzung, bevor Waffe/Zielhaltung überhaupt Sinn ergeben.
*Zeitbudget:* 1–2 Tage.

**Spike 2 — Waffe in der Hand (geringstes Risiko, schneller Erfolg).**
*Hypothese:* `GiveItem`→`AddItemToSlot`→`AIEquipCommand` funktioniert
unverändert auf unseren bestehenden Puppets. *Testaufbau:* auf einem
laufenden Puppet aus Phase 1/2 ausprobieren. *Erfolgskriterium:* Waffe
sichtbar in der Hand, übersteht Bewegung. *Zeitbudget:* 0,5 Tage — macht
sich am ehesten unmittelbar bezahlt, unabhängig vom Ausgang von Spike 1.

**Spike 3 — Zielhaltung via LookAt/IKTarget.**
*Hypothese:* `LookAtAddEvent` mit `RealPosition`-Modus lässt ein Puppet
lebendig auf einen sich bewegenden Weltpunkt (z. B. den lokalen Spieler)
zeigen, ohne Kampf-KI auszulösen. *Testaufbau:* Event auf ein Puppet queuen,
Zielpunkt manuell bewegen. *Erfolgskriterium:* Kopf/Oberkörper folgt live,
kein Kampfverhalten wird getriggert. *Zeitbudget:* 1 Tag (Feldnamen zuerst
gegen NativeDB verifizieren).

**Spike 4 — Rig-Umstecken (V-Rig auf Puppet).**
*Hypothese:* Ein Puppet-`.ent`, dessen `entAnimatedComponent.rig`/`.graph`
auf den geteilten Third-Person-Rig-Pool zeigt (den V ohnehin nutzt), sieht
glaubwürdiger aus als das Standard-NPC-Rig. *Testaufbau:* WolvenKit-Patch
nach dem dokumentierten ArchiveXL-Muster. *Erfolgskriterium:* Puppet lädt
ohne Crash, Animationen spielen (auch wenn zunächst nur die Asset-Referenz,
nicht die Live-Instanz). *Zeitbudget:* 1–2 Tage. Niedrigere Priorität als
1–3, weil der Fidelity-Gewinn optisch ist, nicht funktional.

**Spike 5 (optional, nur bei Kapazität) — Live-Animgraph-Instanz-Sharing.**
Die ungeklärteste, riskanteste Frage: ob die *laufende* Player-Animgraph-
Instanz auf ein zweites Entity übertragbar ist. Kein Beleg in der Recherche
gefunden, weder positiv noch negativ. Nur angehen, wenn Spikes 1–4 zeigen,
dass die eigenständige Puppet-Route (AnimFeature-Feed statt Instanz-Sharing)
nicht ausreicht.

## Risiko-Liste (was der Spike zeigen muss, nicht die Recherche)

- **RED4ext-Nativ-Bedarf für Spike 1:** Ob `AnimFeature_Movement` auf NPCs
  auch aus reinem redscript kontinuierlich schreibbar ist oder zwingend
  einen RED4ext-C++-Aufruf braucht, ist unklar — im schlimmsten Fall mehr
  C++-Arbeit als erhofft.
- **Skyrim Togethers Warnung ernst nehmen:** deren öffentliches GitHub-Issue
  #372 zeigt ungelöstes Root-Motion-vs-Netzwerk-Foot-Sliding bei
  Animationsgraph-Rework — dasselbe Risiko droht uns bei Spike 1, wenn
  Root-Motion und Netzwerk-Position auseinanderlaufen. Muss im Spike-Erfolg
  kriterium explizit geprüft werden (Fuß-Sliding sichtbar?).
- **`AIControllerComponent`-Voraussetzung für `AIEquipCommand`:** unklar, ob
  ein raw `DynamicEntitySpec`-Puppet (Prop-artiges Template) diese Komponente
  automatisch mitbringt oder ein NPC-Archetyp-Template braucht.
- **Größenordnung des Dichte-Gewinns unbekannt:** die Richtung (animationsbasiert
  skaliert besser als KI-basiert) ist gut belegt, aber ob das bei 50 Puppets
  2× oder 10× bringt, weiß niemand ohne Test in dieser Engine.
