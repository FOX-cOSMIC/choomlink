# Deep-Research-Auftrag: Remote-Player-Modell (Phase 4b, bean mg7p)

> Vorbereitet 2026-07-13. Status: bereit zum Start (Deep-Research-Session).
> Kontext: Entscheidung des Auftraggebers, ein eigenes Spieler-Puppet zu
> bauen ("fast ein eigener Mod"), weil AIFollowTargetCommand-Locomotion
> keine PvP-taugliche Darstellung trägt (kein Strafing, keine Zielhaltung,
> keine sichtbare Waffe, Stop-Totzone) und bei ~50 Puppets das Engine-
> KI-Budget bricht (empirisch 2026-07-13). Rust/GTA-Plattformen treiben das
> Animations-System des Remote-Spielers direkt aus Netzwerkdaten — für
> Cyberpunk 2077 existiert keine fertige API dafür. Diese Recherche klärt,
> welche engine-nativen Wege es stattdessen gibt, BEVOR Entwicklungszeit
> investiert wird.

## Research question

Wie kann ein Cyberpunk-2077-Mod (RED4ext + redscript + Codeware +
WolvenKit-Assets, Spielversion gepinnt auf v2.31) ein Remote-Spieler-Puppet
darstellen, dessen Bewegung, Haltung und Ausrüstung **direkt aus
Netzwerkdaten getrieben** wird — statt über AI-Kommandos angenähert — und
welche der nötigen Bausteine sind mit heute dokumentierten Community-
Techniken erreichbar vs. brauchen eigene Assets vs. sind unerreichbar?

## Harte Randbedingungen

- **Kein CyberpunkMP-Quellcode lesen** (tiltedphoques/CyberpunkMP —
  Lizenz verbietet es). Öffentliche Docs/Talks/News DARÜBER sind okay.
  Skyrim Togethers ÖFFENTLICHE technische Doku (wiki.tiltedphoques.com)
  ist dagegen ausdrücklich erlaubt und relevant.
- Spielversion fest v2.31 — Techniken müssen auf diesem Build funktionieren,
  Zukunftssicherheit gegenüber Patches ist NICHT gefordert.
- Solo-Dev: Techniken mit riesigem Asset-Aufwand (komplettes Custom-Rig von
  null) sind nur relevant, wenn kein leichterer Weg existiert.
- Web-Recherche kann nur klären, was dokumentiert ist — das Ergebnis ist
  eine **Spike-Landkarte** (was probieren, in welcher Reihenfolge, mit
  welchem Erfolgskriterium), keine fertige Implementierung.

## Fragenblöcke (mit Quellen, adversarial verifiziert)

1. **Animationsgraph direkt füttern (AnimFeatures & Co.).** Wie steuern
   existierende Mods NPC-Animationen zur Laufzeit? Konkret: Codewares
   AnimFeature-API (Setzen von AnimFeature-Datenblöcken auf Entities),
   AnimationControllerComponent (PushEvent/SetParameter), wie Posing-/
   Foto-Mods (Appearance Menu Mod, Nibbles Editor) NPCs in Posen und
   Animationen zwingen, und ob es einen dokumentierten Weg gibt, den
   **Locomotion-Teil** eines NPC-Graphen mit Geschwindigkeit/Richtung zu
   füttern (der Weg, wie das Spiel selbst NPC-Bewegung animiert — welche
   AnimFeatures konsumiert der NPC-Locomotion-Graph?). Was davon geht aus
   redscript, was braucht RED4ext-Native-Zugriff?
2. **Spieler-Animationsgraph auf einem Puppet.** Kann ein gespawntes Puppet
   den **Spieler-Animationsgraphen** (V's Rig/Graph) nutzen — per Custom-
   .ent, das Player-Komponenten referenziert, oder per WolvenKit-Umbau?
   Was ist über die Struktur von Player- vs. NPC-.ent/.anims/.rig-Dateien
   dokumentiert (CDPR-Modding-Wiki, WolvenKit-Doku, REDmod-Doku)? Gibt es
   Mods, die spielerartige Third-Person-Charaktere mit Spieler-Animationen
   darstellen (Third-Person-Mods! Wie machen die das für V selbst)?
3. **Waffe in der Hand.** Wie bekommen NPCs zur Laufzeit Waffen in die Hand
   (TransactionSystem.GiveItem, EquipItemInSlot, AttachmentSlots,
   TweakDB-Equipment-Records — der Mechanismus, mit dem das Spiel Gangs
   bewaffnet)? Community-Beispiele, die beliebigen gespawnten NPCs per
   Skript Waffen geben und sie halten/ziehen lassen. Welche Slots/Records
   braucht es, und funktioniert es auf DynamicEntitySystem-Spawns?
4. **Zielhaltung/Aim ohne Kampf-KI.** Gibt es AI-Kommandos oder Animations-
   Features für "ziele auf Punkt X" ohne echtes Kampfverhalten (AIAimCommand,
   LookAt-System, Upper-Body-IK auf NPCs)? Wie machen Foto-Modus/Posing-Mods
   gerichtete Ober­körper-Posen? Was ist über NPC-LookAt (Kopf/Augen folgen)
   dokumentiert — reicht das als erste Zielhaltungs-Stufe?
5. **Wie Skyrim Together Reborn es löst (öffentliche Doku!).** Deren
   technische Doku ist öffentlich — wie synchronisieren sie Animationen der
   Remote-Actors (Animations-Events? Behavior-Variablen? direkte Graph-
   Steuerung)? Das ist das am nächsten vergleichbare gelöste Problem
   (Singleplayer-Engine, Remote-Actor-Darstellung) mit legaler Quelle.
   Ebenso: was ist über Third-Person-/Multiplayer-Darstellungs-Techniken
   anderer Engine-Retrofit-Projekte öffentlich dokumentiert?
6. **Dichte-Frage mitdenken.** Welche der gefundenen Techniken umgehen das
   KI-Budget-Problem (50 Puppets = 50 aktive AI-Kommandos brachen sichtbar)?
   Direkte Animationssteuerung ohne AI-Komponente wäre auch die Antwort auf
   die Dichte-Grenze — explizit bewerten, welche Technik bei 30–50
   gleichzeitigen Puppets plausibel bleibt.

## Deliverable

Ein zitierter Bericht mit:
(a) **Machbarkeits-Landkarte**: pro Baustein (Locomotion-Animation, Waffe,
    Aim, Strafing/Stances) die Einstufung "dokumentiert erreichbar via
    redscript/Codeware" / "braucht RED4ext-Native" / "braucht Custom-Assets
    via WolvenKit" / "kein bekannter Weg" — mit Quelle je Einstufung;
(b) **Technik-Katalog**: die konkreten APIs/Records/Dateiformate mit
    Fundstellen (Modding-Wiki-Seiten, Codeware-Doku, Mod-Quellcode auf
    GitHub — Mods mit offener Lizenz dürfen studiert werden);
(c) **Priorisierter Spike-Plan**: 3–5 in-engine-Experimente in Reihenfolge
    (je: Hypothese, minimaler Testaufbau, Erfolgskriterium, Zeitbudget),
    beginnend mit dem höchsten Erkenntnis-pro-Aufwand-Verhältnis;
(d) **Risiko-Liste**: was die Recherche NICHT klären konnte und erst der
    Spike zeigt (z. B. "AnimFeatures auf DynamicEntity-Spawns ungetestet").
