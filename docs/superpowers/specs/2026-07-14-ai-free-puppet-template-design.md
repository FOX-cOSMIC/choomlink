# AI-freies Custom-Puppet-Template (Phase 4b, Iteration 2) — Design

> Status: vom Auftraggeber genehmigtes Design (2026-07-14). Fortsetzung von
> `2026-07-13-animfeature-locomotion-design.md`: die kinematische
> Interpolation läuft produktiv (kein Proxy, keine KI-Kommandos), aber die
> Bein-Animation blieb aus — 7 Proben zeigten, dass NPC-Animationen hinter
> der KI-Action-Maschinerie gekapselt sind (von außen geschriebene
> Features/Events treiben den Graphen nicht). Der Auftraggeber wählte den
> Pfad mit der meisten Kontrolle: ein eigenes Entity, dem wir den residenten
> KI-/Movement-Stack von vornherein wegnehmen. Bean: `choomlink-mg7p`.
> Recherche-Grundlage: 2 Agenten-Reports 2026-07-14 (Custom-.ent-Muster;
> Crowd-/Scene-/Workspot-/ActionProxy-Mechanismen), plus lokale Analyse von
> `judy.ent` (WolvenKit-JSON-Export) und des decompilierten Spielcodes.

## Ziel

Ein Remote-Spieler-Puppet, das aus **unserem eigenen `.ent`-Template**
gespawnt wird — mit entferntem KI-/Move-Stack, sodass kein residenter
Schreiber gegen unseren externen Animations-Feed kämpft. Zusammen mit der
schon funktionierenden kinematischen Interpolation gibt uns das die
maximale Kontrolle: Wer die Graph-Features füttert, sind per Konstruktion
wir. Endzustand ist das Fundament für das eigene Spielermodell (Rig-Wahl,
Waffen-Slots, LookAt hängen alle an derselben Entity-Definition).

## Kern-Erkenntnisse der Recherche (belegt)

1. **`DynamicEntitySpec.templatePath: ResRef`** spawnt ein beliebiges `.ent`
   direkt (Codeware, dokumentiert, mehrfach von Mods genutzt: CyberScript,
   CP77_entSpawner). CDPRs Warnung *"NPCs may not function properly if
   spawned using template"* ist für uns **das gewünschte Verhalten**, nicht
   der Bug — genau die KI-Entkopplung.
2. **Plain `.archive` reicht** — kein ArchiveXL nötig, solange wir nur neue
   Ressourcen unter neuen Pfaden hinzufügen.
3. **Komponenten sind sauber getrennt** (aus `judy.ent`-Analyse): der
   Anim-Kern (`entAnimatedComponent`, `entAnimationControllerComponent`,
   `entAnimationSetupExtensionComponent`, `entSlotComponent`) ist von KI/Move
   (`AIHumanComponent`, `moveComponent`, `movePoliciesComponent`,
   `moveMotionPlannerComponent`, `senseComponent`, `NPCStatesComponent`,
   `HitReactionComponent`, `ReactionManagerComponent`, diverse
   `gameTargeting`/`gameBreach`/Combat-Komponenten) getrennt — kopier- und
   löschbar.
4. **`ActionAnimationScriptProxy`** (die Klasse hinter `m_hitReactionAction`)
   ist script-instanziierbar: `new` + `Bind(GameObject)` + `Setup(...)` +
   `Launch()` — das Spiel selbst macht es genau so (`aiComponent.script`).
   Der fehlende **Auslöser** hinter unseren wirkungslosen Features.

## Die zentrale Unbekannte (das eigentliche Experiment)

**Treibt oder überschreibt die `moveComponent` den Locomotion-Graphen?**
Zwei entgegengesetzte Möglichkeiten, beide plausibel, keine dokumentiert:
- **Überschreiber-These:** Der Move-Stack schreibt die Locomotion-Features
  jeden Tick und gewinnt gegen unseren Feed. → Entfernen *hilft*, unser Feed
  greift dann.
- **Treiber-These:** Der Move-Stack ist genau die Instanz, die den Graphen
  in Walk/Jog-States versetzt (aus interner Velocity). → Entfernen *schadet*,
  das Puppet bleibt für immer im Idle.

Das ist kein Design-Fehler, sondern die Frage, die dieses Experiment
beantwortet. Deshalb steht die billige, asset-freie Proxy-Probe voran: sie
klärt einen unabhängigen, sowieso gebrauchten Mechanismus, bevor
Asset-Arbeit investiert wird.

## Stufenplan

**Stufe A — `ActionAnimationScriptProxy`-Probe (asset-frei, 1 Build-Zyklus).**
Auf einem *bestehenden* (Vanilla-record-gespawnten) Puppet: `new
ActionAnimationScriptProxy` → `Bind(puppet)` → `Setup(animFeatureName,
animFeature: AnimFeature_AIAction, useRootMotion=false, ...,
updateMovePolicy=false, ...)` → `Launch()`. *Hypothese:* wir können extern
eine Slot-Animation zünden (das, was Features allein nicht konnten).
*Erfolg:* sichtbare Ganzkörper-Animation auf Kommando. *Warum zuerst:* klärt
den generischen Anim-Auslöser (für Kampf-Sync/Gesten in Phase 4 sowieso
gebraucht) ohne jede Asset-Arbeit; Ergebnis informiert Stufe C.
*Risiko:* unklar, ob `Launch()` außerhalb eines laufenden AI-Behavior-Trees
greift — `Bind`-auf-GameObject spricht dafür, muss aber getestet werden.

**Stufe B — AI-freies `.ent`-Template bauen (Asset-Arbeit).**
`judy.ent` (o. ä.) in WolvenKit duplizieren → KI-/Move-/Sense-/Combat-
Komponenten löschen (Liste unten) → Anim-Kern + Appearance/Mesh-Pipeline
behalten → unter `base\choomlink\puppet_base.ent` speichern → als plain
`.archive` packen → nach `archive\pc\mod\` deployen. *Erfolg dieser Stufe
allein:* Puppet spawnt sichtbar über `templatePath`, lädt ohne Crash.

**Stufe C — Locomotion-Feed auf dem AI-freien Puppet erneut testen.**
Spawn-Pfad im Client von `recordID` auf `templatePath` umstellen; den schon
gebauten Feed (`locomotion`- + `crowd_locomotion`-Features, aus Iteration 1)
gegen das neue Puppet laufen lassen. *Entscheidet die zentrale Unbekannte:*
- Beine laufen → **Überschreiber-These bestätigt**, wir haben volle
  Kontrolle; Feed verfeinern (Enum-Feintuning, Übergänge).
- Beine bleiben Idle → **Treiber-These**; eskalieren zu Stufe D.

**Stufe D — Eskalation (nur falls C negativ).** In dieser Reihenfolge:
1. `ActionAnimationScriptProxy` (aus Stufe A) als Locomotion-Treiber: Walk-
   Slot-Anim loopen, Rate über `animScale`-artige Inputs — falls die Probe
   in A positiv war.
2. Workspot-Route (AMM-Muster: `WorkspotGameSystem.PlayInDeviceSimple` +
   `SendJumpToAnimEnt`) — garantiert abspielbar, aber Root-Motion-vs-
   kinematische-Bewegung muss geprüft werden (Workspots pinnen den Actor).
3. Eigener Animgraph-Zweig mit selbst definierten Inputs (Anim-Modding) —
   der „FiveM-artige" Maximal-Kontroll-Endzustand, größter Aufwand.

## Zu entfernende Komponenten (aus judy.ent, Stufe B)

KI/Verhalten: `AIHumanComponent`, `AIObjectSelectionComponent`,
`AISignalHandlerComponent`, `AITargetTrackerComponent`, `NPCStatesComponent`,
`ReactionManagerComponent`, `HitReactionComponent`, `StimBroadcasterComponent`.
Bewegung: `moveComponent`, `movePoliciesComponent`,
`moveMotionPlannerComponent`.
Wahrnehmung/Kampf: `senseComponent`, `senseVisibleObjectComponent`,
`gameTargetingComponent`, `gameTargetShootComponent`, `gameSourceShootComponent`,
`gameWeakspotComponent`, `gameBreachComponent`, `gameBreachControllerComponent`,
`gameDismembermentComponent`, `SquadMemberBaseComponent`, `ScavengeComponent`,
`CrowdMemberBaseComponent` sowie die zugehörigen `*PS`-Persistenz-Einträge.

Behalten (Sicht + Animation): `entAnimatedComponent`,
`entAnimationControllerComponent`, `entAnimationSetupExtensionComponent`,
`entSlotComponent`, `entSkinnedMeshComponent` (über Appearance/.app),
`entColliderComponent`/`entSimpleColliderComponent` (vorerst behalten, für
Sichtbarkeit/Boden), sowie die Appearance-/FX-Grundpipeline.
**Vorgehen bei Unsicherheit:** inkrementell ausdünnen — bei Crash oder
unsichtbarem Puppet eine Komponente zurücknehmen, nicht von Null aufbauen
(das wäre Zuschnitt B, bewusst verworfen als riskanter für die erste
Iteration).

## Was sich am bestehenden Code ändert

- **Client `NetworkGameSystem.reds` `SpawnTransientEntity`:** `recordID`-Spawn
  → `templatePath`-Spawn (bzw. konfigurierbar, Vanilla-Fallback behalten für
  A/B-Vergleich). Einzeiler-Änderung an der DynamicEntitySpec.
- **Kein Protokoll-Touch**, keine Server-Änderung, keine
  6-Stellen-Checkliste.
- Interpolation + Feed aus Iteration 1 bleiben unverändert; nur das
  Spawn-Ziel wechselt.

## Tests & Verifikation (ingame-verify)

- **Stufe A:** 1 Static-Bot, Proxy auf das gespawnte Vanilla-Puppet;
  Screenshot-Burst zeigt Ganzkörper-Anim auf Kommando (Posen variieren).
- **Stufe B:** Puppet spawnt sichtbar über `templatePath`, redscript
  `Compilation complete`, kein red4ext-Crash, kein Watchdog-Timeout.
- **Stufe C:** 4-Bot-Kreis; Beine laufen (Pose-Variation über Burst) **oder**
  bleiben Idle — beides ist ein verwertbares Ergebnis, das die zentrale
  Unbekannte klärt. Interpolation-Regression: weiterhin kein 8-m-Catch-up,
  Zähler verlustfrei.
- **Dichte (falls C positiv):** 50-Bot-Test — der eigentliche Zielnachweis
  (kein KI-Budget mehr, da kein KI-Stack).

## Risiken (was erst der Test zeigt)

- **Zentrale Unbekannte** (moveComponent Treiber vs. Überschreiber) — s. o.
- **Appearance ohne Puppet-Root:** ob die Mesh-/Appearance-Pipeline auf einem
  ausgedünnten Entity ohne NPCPuppet-Root korrekt lädt (Codeware-Warnung
  deutet auf mögliche Probleme) — inkrementelles Ausdünnen als Gegenmittel.
- **Collider/Boden:** ohne Move-Stack evtl. kein Bodenkontakt-Handling —
  Puppet könnte durch den Boden fallen oder schweben; Collider behalten und
  im Test beobachten (die kinematische Teleport-Positionierung setzt die
  Z-Höhe aus den Netzdaten, sollte das abfangen).
- **Tester-Onboarding:** ein eigenes `.archive` muss ausgeliefert werden —
  ein Schritt mehr beim Verteilen (bean `xrpn`), aber unumgänglich für das
  eigene Spielermodell.

## Quellen-Notiz

Spielcode-/Struktur-Zitate aus dem öffentlichen decompilierten redscript-Dump
(Codeberg), CDPR-Modding-Wiki, Codeware/ArchiveXL-Doku, offenen MIT/Unlicense-
Mods (CyberScript, CP77_entSpawner, AMM) und lokal per WolvenKit exportierten
Vanilla-Assets. CyberpunkMP-Quellcode wurde nicht gelesen (Projektregel).
