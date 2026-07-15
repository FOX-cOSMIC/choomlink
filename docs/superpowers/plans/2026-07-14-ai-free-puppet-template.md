# AI-freies Custom-Puppet-Template Implementation Plan (Phase 4b, Iteration 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ein Remote-Puppet aus eigenem KI-freiem `.ent`-Template spawnen, damit kein residenter Move-Stack unseren externen Locomotion-Feed überschreibt — und den entscheidenden Test durchführen, ob der Animgraph dann läuft.

**Architecture:** Rein clientseitig. Stage A prüft asset-frei den generischen Anim-Auslöser (`ActionAnimationScriptProxy`). Stage B baut das KI-freie `.ent` per WolvenKit-CLI-JSON-Roundtrip (kein GUI). Stage C stellt den Spawn auf `templatePath` um und testet den bestehenden Feed erneut — das Entweder-Oder-Experiment (moveComponent Treiber vs. Überschreiber). Stage D eskaliert nur bei negativem C.

**Tech Stack:** RED4ext (C++20, RedLib), redscript, WolvenKit.CLI (`C:\Users\G4M3R\Tools\wolvenkit-cli\WolvenKit.CLI.exe`), Bot-Harness, `ingame-verify`.

## Global Constraints

- Spielversion gepinnt v2.31; Spielstart NUR direkt (nie Steam-UI): `Cyberpunk2077.exe --cyberverse-server-address=127.0.0.1 --cyberverse-server-port=1337`.
- Spiel/Server/Bots nach jedem Test beenden (`Stop-Process -Name Cyberpunk2077`), außer der nächste Schritt braucht sie.
- Kein CyberpunkMP-Quellcode. Spiel-eigener Code (decompilierter Dump `C:\Users\G4M3R\Programming\cp2077-decompiled`, RTTI, WolvenKit-Assets) erlaubt.
- Kein Protokoll-Touch, keine Server-Änderung.
- Neuer Protokoll-Native-Method-Bedarf: jede neue `public func` in `NetworkGameSystem.reds`, die C++ per `Red::CallVirtual` aufruft, muss existieren BEVOR die DLL lädt, sonst UNRESOLVED_METHOD beim Start.
- Code-Repo: `C:\Users\G4M3R\Programming\choomlink-core`. Planungs-Repo (Specs/Docs): `C:\Users\G4M3R\Programming\choomlink`.
- Build red4ext: `cmd /c '"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -no_logo && cmake --build "C:\Users\G4M3R\Programming\choomlink-core\client\red4ext\build\ninja-vcpkg"'`
- Deploy: DLL → `<game>\red4ext\plugins\Cyberverse\`; reds `client\RedscriptModule\src\*` → `<game>\r6\scripts\Cyberverse\`; Archiv → `<game>\archive\pc\mod\`. `<game>` = `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077`.
- Log-Gate nach Spielstart: `redscript_rCURRENT.log` endet mit `Compilation complete` (ein `[UNRESOLVED_*]` = fixen/neu deployen); neuestes `red4ext-*.log` enthält `has been loaded`.

---

### Task 1: Stage A — ActionAnimationScriptProxy-Probe (asset-frei)

Klärt, ob wir extern eine Ganzkörper-Slot-Animation auf einem bestehenden Puppet zünden können — der Auslöser, den unsere Features allein nicht hatten. Für Kampf-Sync (Phase 4) sowieso gebraucht.

**Files:**
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\client\RedscriptModule\src\Network\NetworkGameSystem.reds`
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\client\red4ext\src\NetworkGameSystem.cpp` (temporäre Probe-Schleife in `UpdatePuppetInterpolation`, wie bei den hit-Proben)

**Interfaces:**
- Consumes: `m_movementState` (map entityId→state), `Cyberverse::Utils::GetDynamicEntity`.
- Produces: reds `func TryActionAnim(entity: ref<Entity>, actionRecordId: TweakDBID) -> Bool` (temporär, Stage A only).

Verifizierte API (decompiled `orphans.swift:25110`):
- `ActionAnimationScriptProxy extends CActionScriptProxy` (script-`new`-bar): `Bind(go: ref<GameObject>)`, `Launch()`, `Stop()`, `GetStatus() -> gameEActionStatus`.
- `Setup(animFeatureName: CName, animFeature: ref<AnimFeature_AIAction>, useRootMotion: Bool, usePoseMatching: Bool, resetRagdollOnStart: Bool, motionDynamicObjectsCheck: Bool, updadeMovePolicy: Bool, slideParams: ActionAnimationSlideParams, targetObject: wref<GameObject>, marginToPlayer: Float, opt tagetPositionProvider) -> Bool`.
- `AnimFeature_AIAction`: `state: Int32`, `stateDuration: Float`, `animVariation: Int32`, `direction: Float`.
- Das Spiel holt `animFeatureName` aus einem `AIActionAnimData_Record` (`tweakAIAction.swift:1263`: `m_actionRecord.AnimData().AnimFeature()`). Wir brauchen einen gültigen Record-Pfad — Discovery in Step 1.

- [ ] **Step 1: Einen gültigen AIActionAnimData-Record-Pfad finden**

TweakDB nach AIActionAnimData-Records durchsuchen (WolvenKit CLI kann TweakDB dumpen, oder decompiled Referenzen). Kandidaten aus dem Spielcode greppen:

```bash
grep -rn "t\"AIAction" /c/Users/G4M3R/Programming/cp2077-decompiled | grep -i "anim\|takedown\|reaction" | head -20
```
Notiere 2-3 konkrete Record-IDs (z. B. eine Takedown-/Reaction-Anim). Erwartung: mindestens ein `t"AIAction..."`-Pfad, der `.AnimData()` liefert. Falls kein passender im redscript auftaucht: `WolvenKit.CLI.exe` TweakDB-Export (`tweakdb.bin`) nach Records vom Typ `AIActionAnimData` filtern.

- [ ] **Step 2: reds-Helper `TryActionAnim` schreiben**

In `NetworkGameSystem.reds` vor der schließenden Klammer der Klasse:

```reds
    // STAGE-A PROBE (temporary): fire a full-body slot animation on a puppet via the game's
    // own ActionAnimationScriptProxy — the trigger our raw AnimFeatures lacked.
    public func TryActionAnim(entity: ref<Entity>, actionRecordId: TweakDBID) -> Bool {
        let puppet = entity as ScriptedPuppet;
        if !IsDefined(puppet) {
            return false;
        }
        let record = TweakDBInterface.GetAIActionAnimDataRecord(actionRecordId);
        if !IsDefined(record) {
            FTLog(s"[ChoomLink] TryActionAnim: no record for \(TDBID.ToStringDEBUG(actionRecordId))");
            return false;
        }
        let proxy = new ActionAnimationScriptProxy();
        proxy.Bind(puppet);
        let feature = new AnimFeature_AIAction();
        feature.state = 1;
        feature.stateDuration = 3.0;
        let slideParams: ActionAnimationSlideParams;
        let ok = proxy.Setup(record.AnimFeature(), feature, false, false, false, false, false, slideParams, null, 0.0);
        FTLog(s"[ChoomLink] TryActionAnim Setup=\(ok) feature=\(NameToString(record.AnimFeature()))");
        proxy.Launch();
        return ok;
    }
```

(Falls `TweakDBInterface.GetAIActionAnimDataRecord` nicht existiert: Signatur ist `orphans.swift:12015` `GetAIActionAnimDataRecord(path: TweakDBID) -> ref<AIActionAnimData_Record>` — als `TweakDBInterface`-Methode aufrufen.)

- [ ] **Step 3: C++-Probe-Schleife einbauen**

In `NetworkGameSystem.cpp`, in `UpdatePuppetInterpolation`, denselben Timer-Block wie die hit-Probe nutzen (alle 2,5 s), aber `TryActionAnim` aufrufen. Record-ID aus Step 1 als `RED4ext::TweakDBID` hart eintragen:

```cpp
    if (fireHitProbe)  // reuse the 2.5s timer
    {
        if (const auto probeEntity = Cyberverse::Utils::GetDynamicEntity(entityId); probeEntity.has_value())
        {
            RED4ext::TweakDBID recordId("<AIActionAnimData-Pfad aus Step 1>");
            Red::CallVirtual(this, "TryActionAnim", probeEntity.value(), recordId);
        }
    }
```
(Den hit-Feature-Block aus der Vor-Iteration ersetzen, nicht zusätzlich.)

- [ ] **Step 4: Bauen, deployen, in-game testen**

Build (Global Constraints) → DLL+reds deployen → Server + 1 Static-Bot → Spiel starten → Log-Gate → `capture-burst.ps1`. Erwartung Erfolg: sichtbare Ganzkörper-Animation auf dem Puppet (Posen variieren über den Burst; nicht Idle). FTLog `Setup=true` im CET-Game-Log. Bei `Setup=false` oder keine Anim: 2. Record-ID aus Step 1 probieren.

- [ ] **Step 5: Ergebnis festhalten + Commit**

Spec `2026-07-14-ai-free-puppet-template-design.md` um „Stage-A-Ergebnis" ergänzen (Anim ja/nein, welcher Record, Setup-Rückgabe). Commit:

```bash
git -C /c/Users/G4M3R/Programming/choomlink-core add client/RedscriptModule/src/Network/NetworkGameSystem.reds client/red4ext/src/NetworkGameSystem.cpp
git -C /c/Users/G4M3R/Programming/choomlink-core commit -m "stage A probe: ActionAnimationScriptProxy slot-anim trigger on existing puppet"
```
Spiel/Bots stoppen.

---

### Task 2: Stage B — KI-freies `.ent` per JSON-Roundtrip bauen

Kein WolvenKit-GUI: wir editieren den bereits exportierten `judy.ent.json`, deserialisieren zurück, packen als Archiv.

**Files:**
- Quelle: `C:\Users\G4M3R\Tools\wolvenkit-out\base\characters\entities\main_npc\judy.ent.json` (existiert schon)
- Create: `C:\Users\G4M3R\Programming\choomlink-core\client\assets\choomlink\puppet_base.ent` (Zwischenprodukt)
- Create: `C:\Users\G4M3R\Programming\choomlink-core\client\assets\choomlink_puppet.archive` (deploybares Archiv)

**Interfaces:**
- Produces: Archiv mit auflösbarem ResRef `base\choomlink\puppet_base.ent`.

- [ ] **Step 1: JSON kopieren und KI-/Move-Komponenten entfernen**

`judy.ent.json` nach `puppet_base.ent.json` (im choomlink-core `client/assets/`-Ordner) kopieren. Im `components`-Array die Chunks löschen, deren `$type` einer aus dieser Liste ist (Spec §Zu entfernende Komponenten):
`AIHumanComponent, AIObjectSelectionComponent, AISignalHandlerComponent, AITargetTrackerComponent, NPCStatesComponent, ReactionManagerComponent, HitReactionComponent, StimBroadcasterComponent, moveComponent, movePoliciesComponent, moveMotionPlannerComponent, senseComponent, senseVisibleObjectComponent, gameTargetingComponent, gameTargetShootComponent, gameSourceShootComponent, gameWeakspotComponent, gameBreachComponent, gameBreachControllerComponent, gameDismembermentComponent, SquadMemberBaseComponent, ScavengeComponent, CrowdMemberBaseComponent`
plus alle `*PS`-Persistenz-Chunks derselben.
Behalten: `entAnimatedComponent, entAnimationControllerComponent, entAnimationSetupExtensionComponent, entSlotComponent, entColliderComponent/entSimpleColliderComponent`, sowie die `appearances`/Appearance-Referenzen und `entTemplateAppearance`.
Den `appearanceName`/Default beibehalten (sonst unsichtbar). Das JSON-Editieren mit einem Skript (jq nicht vorhanden auf Windows — mit einem kleinen Node/PowerShell-Snippet oder händisch per Edit, da die Chunks klar abgegrenzt sind).

- [ ] **Step 2: Zurück nach .ent deserialisieren**

```bash
/c/Users/G4M3R/Tools/wolvenkit-cli/WolvenKit.CLI.exe convert deserialize "<pfad>/puppet_base.ent.json" -o "<pfad>/puppet_base.ent"
```
Erwartung: `.ent`-Datei erzeugt, keine Schema-Fehler. Bei Fehler: den zuletzt entfernten Chunk zurücknehmen (inkrementelles Ausdünnen, Spec §Vorgehen bei Unsicherheit).

- [ ] **Step 3: In Archiv unter Zielpfad packen**

WolvenKit-Projektstruktur anlegen: die `.ent` unter einem `archive\`-Wurzelordner am Pfad `base\choomlink\puppet_base.ent` platzieren, dann packen:

```bash
/c/Users/G4M3R/Tools/wolvenkit-cli/WolvenKit.CLI.exe pack "<projektordner>" -o "<pfad>/choomlink_puppet.archive"
```
(Exakte `pack`-Syntax vorab mit `WolvenKit.CLI.exe pack --help` prüfen; ggf. Ordner `source\archive\base\choomlink\puppet_base.ent` als Layout.) Erwartung: `.archive` erzeugt.

- [ ] **Step 4: Archiv deployen + Spawn-Test (noch Vanilla-Spawnpfad)**

Archiv nach `<game>\archive\pc\mod\` kopieren. Noch KEIN Client-Umbau — nur prüfen, dass das Archiv das Spiel nicht bricht: Spiel starten, Log-Gate, kein Crash/Watchdog. Erwartung: Spiel lädt normal (das Puppet wird noch nicht gespawnt, da der Client weiter `recordID` nutzt — dies ist nur der Archiv-Ladetest).

- [ ] **Step 5: Commit**

```bash
git -C /c/Users/G4M3R/Programming/choomlink-core add client/assets/
git -C /c/Users/G4M3R/Programming/choomlink-core commit -m "assets: AI-free puppet_base.ent template + packed archive (stripped move/AI stack)"
```
Spiel stoppen.

---

### Task 3: Stage C — templatePath-Spawn + Feed-Retest (das Kern-Experiment)

**Files:**
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\client\RedscriptModule\src\Network\NetworkGameSystem.reds` (`SpawnTransientEntity`)

**Interfaces:**
- Consumes: bestehender `DriveLocomotionFeed`-Pfad (C++, unverändert), `UpdatePuppetInterpolation`.
- Produces: Puppet gespawnt aus `templatePath` statt `recordID`.

- [ ] **Step 1: Spawn auf templatePath umstellen**

In `SpawnTransientEntity` die `DynamicEntitySpec` ändern — `recordID` weglassen, `templatePath` setzen (Codeware-Feld `templatePath: ResRef`):

```reds
        let npcSpec = new DynamicEntitySpec();
        npcSpec.templatePath = r"base\\choomlink\\puppet_base.ent";
        npcSpec.alwaysSpawned = true;
        npcSpec.position = worldPosition;
        npcSpec.orientation = worldOrientation;
        npcSpec.persistState = false;
        npcSpec.persistSpawn = false;
        npcSpec.tags = [n"RED4ext"];
        return GameInstance.GetDynamicEntitySystem().CreateEntity(npcSpec);
```
(Den `entityName`-Parameter der Funktion vorerst ignorieren/behalten für Vanilla-Fallback; die Umstellung ist der Kern.)

- [ ] **Step 2: Die Stage-A-Probe aus Task 1 entfernen**

Den temporären `TryActionAnim`-Aufruf + reds-Helper wieder herausnehmen (Stage A ist abgeschlossen, Ergebnis dokumentiert). `DriveLocomotionFeed` bleibt aktiv.

- [ ] **Step 3: Bauen, deployen, Spawn-Sichtbarkeit prüfen**

reds deployen (kein C++-Change nötig, falls nur Step 2 C++ berührt: dann auch DLL). Server + 1 Static-Bot → Spiel → Log-Gate → Burst. Erwartung dieser Stufe: **Puppet erscheint sichtbar** am Bot-Ort (Appearance lädt). Bei unsichtbar/Crash: zurück zu Task 2 Step 1 (Komponente zu viel entfernt) — inkrementell.

- [ ] **Step 4: Das Kern-Experiment — 4-Bot-Kreis, Beine beobachten**

Server + 4-Bot-Kreis (`--count 4 --pattern circle`) → Spiel → Burst (2×, je 6 Frames). Auswertung:
- **Beine laufen** (Pose-Variation über Burst, kein Gleiten) → **Überschreiber-These bestätigt**, volle Kontrolle erreicht. Weiter Step 5.
- **Beine Idle** (gleiten) → **Treiber-These**; Stage C negativ → Task 4 (Eskalation).
Regression in beiden Fällen prüfen: Interpolation weiter flüssig, kein 8-m-Catch-up im Log, Zähler verlustfrei.

- [ ] **Step 5: Ergebnis + Commit**

Spec um „Stage-C-Ergebnis" ergänzen (welche These, Screenshots-Urteil, Feel beim Auftraggeber). Commit:

```bash
git -C /c/Users/G4M3R/Programming/choomlink-core add client/RedscriptModule/src/Network/NetworkGameSystem.reds client/red4ext/src/NetworkGameSystem.cpp
git -C /c/Users/G4M3R/Programming/choomlink-core commit -m "locomotion: spawn remote puppets from AI-free template; feed-retest result recorded"
git -C /c/Users/G4M3R/Programming/choomlink-core push
```
Spiel/Bots stoppen.

- [ ] **Step 6: Falls positiv — 50-Bot-Dichtetest**

Nur wenn Step 4 „Beine laufen": `--count 50 --pattern random` → Spiel → Burst + Zähler. Erwartung: kontinuierliche Bewegung ohne KI-Budget-Stottern (kein KI-Stack mehr), Zähler verlustfrei, FPS-Eindruck vom Auftraggeber. Ergebnis in die Spec. Das ist der eigentliche Zielnachweis von Phase 4b.

---

### Task 4: Stage D — Eskalation (NUR falls Task 3 Step 4 negativ)

Bedingt. Nicht ausführen, wenn Stage C die Beine schon zum Laufen brachte. Reihenfolge (Spec §Stufe D), jede als eigener Mini-Zyklus mit In-Game-Check:

- [ ] **D1 — Proxy als Locomotion-Treiber:** Falls Stage A (Task 1) positiv war: eine Walk-Slot-Anim per `ActionAnimationScriptProxy` loopen (nach `Launch` bei `GetStatus`-Ende neu triggern), Abspielrate über `AnimFeature_AIAction`/`animScale`-Inputs. In-Game-Check: laufende Beine auf dem interpolierten Puppet, kein Root-Motion-Konflikt (Füße gleiten nicht gegen die kinematische Bewegung).
- [ ] **D2 — Workspot-Route:** `GameInstance.GetWorkspotSystem().PlayInDeviceSimple(...)` + `SendJumpToAnimEnt(actor, animName, false)` (AMM-Muster). Prüfen, ob der Workspot den Actor an eine feste Position pinnt (Konflikt mit kinematischer Bewegung) — dann verworfen.
- [ ] **D3 — Eigener Animgraph-Zweig:** Anim-Modding: eigene Feature-Inputs (state/speed) in einen Custom-Zweig des Puppet-Graphen einhängen, aus dem Netz-Code füttern. Größter Aufwand, eigener Spec-Zyklus — hier nur als Marker; bei Erreichen dieses Punktes zurück zu `brainstorming` für ein eigenes Design.

Nach Abschluss (welcher Zweig auch greift): Spec-Ergebnis, Commit, Push, 50-Bot-Dichtetest wie Task 3 Step 6.
