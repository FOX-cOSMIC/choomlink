# AnimFeature-Locomotion Implementation Plan (Phase 4b)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remote-Puppets bewegen sich per clientseitiger Interpolation + `AnimFeature_Movement`-Feed statt per `AIFollowTargetCommand` — beseitigt KI-Budget-Limit (50 Puppets), Stop-Totzone und das Proxy-Entity.

**Architecture:** Server unverändert. Client: `eTeleportEntity` speichert nur noch Ziel+Velocity; eine neue Per-Frame-Interpolation (`UpdatePuppetInterpolation`) bewegt Puppets kinematisch (`KinematicMove`, TeleportationFacility); eine redscript-Funktion (`DriveLocomotion`) füttert den Locomotion-Blendgraphen via `AnimationControllerComponent.ApplyFeature` mit einem `AnimFeature_PlayerMovement` (erbt von `AnimFeature_Movement`, liefert die Setter). Stufe 1 beweist den Animations-Feed am stehenden Puppet, BEVOR der Proxy-Pfad entfernt wird.

**Tech Stack:** RED4ext (C++20, RedLib `Red::CallVirtual`), redscript, Bot-Harness (GameNetworkingSockets), `ingame-verify`-Skill.

## Global Constraints

- Spielversion gepinnt v2.31; Spielstart NUR direkt: `Cyberpunk2077.exe --cyberverse-server-address=127.0.0.1 --cyberverse-server-port=1337` (nie Steam-UI).
- Spiel/Server/Bots nach jedem Test beenden (`Stop-Process -Name Cyberpunk2077`), außer der nächste Schritt braucht sie.
- Kein CyberpunkMP-Quellcode lesen. Spiel-eigener Code (decompilierter Dump `C:\Users\G4M3R\Programming\cp2077-decompiled`, RTTI) ist erlaubt.
- Keine Protokolländerung in diesem Plan (kein 6-Stellen-Checklauf nötig).
- Kein neues Unit-Test-Terrain: Änderung ist rein clientseitig/engine-gebunden — Verifikation via Bot-Harness-Zähler + `ingame-verify` (Spec §Tests).
- Code-Repo: `C:\Users\G4M3R\Programming\choomlink-core` (Commits dort); Doku/Spec-Updates im Planungs-Repo `C:\Users\G4M3R\Programming\choomlink`.
- Vor Rebuild des Bot-Harness laufende Instanzen killen (`Stop-Process -Name bot-harness`), sonst schlägt der Link-Schritt fehl.
- Deploy-Ziele: DLL `client\red4ext\build\ninja-vcpkg\src\Cyberverse.Red4Ext.dll` → `<game>\red4ext\plugins\Cyberverse\`; reds `client\RedscriptModule\src\*` → `<game>\r6\scripts\Cyberverse\` (`<game>` = `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077`).
- Nach Spielstart IMMER Log-Gate: `redscript_rCURRENT.log` endet mit `Compilation complete` (ein `[UNRESOLVED_*]` = Abbruch, fixen, neu deployen); neuestes `red4ext-*.log` enthält `Cyberverse.Red4Ext ... has been loaded`.

---

### Task 1: Bot-Harness `--pattern static`

Stufe 1 braucht ein Puppet, das steht, aber 10-Hz-Updates sendet (damit der Server es trackt und der Client es spawnt). Der Harness kennt nur circle/random/boundary.

**Files:**
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\tools\bot-harness\src\Behavior.h`
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\tools\bot-harness\src\main.cpp`

**Interfaces:**
- Produces: `Behavior::Pattern::Static` — `Tick()` liefert unverändert die Spawn-Pose; CLI `--pattern static`.

- [ ] **Step 1: Pattern-Enum + Tick-Zweig in Behavior.h**

In `Behavior.h` das Enum erweitern und den Tick-Switch ergänzen:

```cpp
    enum class Pattern
    {
        Circle,
        Random,
        Boundary,
        Static,
    };
```

Im `Tick(const float dt)`-Switch VOR dem `case Pattern::Random:`-Default einfügen:

```cpp
        case Pattern::Static:
            return { m_position, std::fmod(m_heading * 57.29578f, 360.0f) };
```

(`m_position`/`m_heading` sind im Konstruktor bereits gesetzt — Static-Bots stehen auf ihrer Kreis-Spawnposition.)

- [ ] **Step 2: CLI-Parsing + Usage in main.cpp**

Im `--pattern`-Parsing (nach dem `boundary`-Zweig, vor dem `unknown pattern`-Fehler):

```cpp
            else if (std::strcmp(value, "static") == 0)
            {
                options.pattern = Behavior::Pattern::Static;
            }
```

Fehlertext und Usage-Zeile auf `(circle|random|boundary|static)` erweitern. Im `patternName`-Ternary (Zeile ~176) den Fall ergänzen:

```cpp
    const char* patternName = options.pattern == Behavior::Pattern::Circle     ? "circle"
                              : options.pattern == Behavior::Pattern::Boundary ? "boundary"
                              : options.pattern == Behavior::Pattern::Static   ? "static"
                                                                               : "random";
```

- [ ] **Step 3: Bauen**

```powershell
Stop-Process -Name bot-harness -Force -ErrorAction SilentlyContinue
cmake --build "C:\Users\G4M3R\Programming\choomlink-core\tools\bot-harness\build\ninja-vcpkg"
```
Expected: Build ohne Fehler.

- [ ] **Step 4: Headless-Smoke-Test**

Server starten (falls nicht laufend): `dotnet run` in `server\Managed` (Env `DOTNET_ROLL_FORWARD=LatestMajor`, Hintergrund). Dann:

```powershell
& "C:\Users\G4M3R\Programming\choomlink-core\tools\bot-harness\build\ninja-vcpkg\bot-harness.exe" --count 1 --pattern static
```
Expected: Banner `pattern static`, stats `1/1 running`. Bot wieder stoppen.

- [ ] **Step 5: Commit (choomlink-core)**

```bash
git -C /c/Users/G4M3R/Programming/choomlink-core add tools/bot-harness/src/Behavior.h tools/bot-harness/src/main.cpp
git -C /c/Users/G4M3R/Programming/choomlink-core commit -m "bot-harness: add --pattern static (stationary bot for animation probes)"
```

---

### Task 2: Stufe 1 — Animations-Beweis (Probe-Feed am stehenden Puppet)

Klärt die zwei offenen Engine-Fragen aus der Spec: Graph-Input-Name und Überschreib-Verhalten. Der bestehende Proxy-Follow-Pfad bleibt unangetastet; die Probe läuft zusätzlich, pro Frame (damit ist die Überschreib-Frage gleich mitgetestet), und wendet das Feature unter ALLEN Kandidaten-Namen gleichzeitig an — falsche Input-Namen sind wirkungslos (kein Graph-Input konsumiert sie), der richtige gewinnt. Danach Bisektion.

**Files:**
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\client\RedscriptModule\src\Network\NetworkGameSystem.reds`
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\client\red4ext\src\NetworkGameSystem.cpp` (Probe-Schleife in `OnNetworkUpdate`)

**Interfaces:**
- Consumes: `Cyberverse::Utils::GetDynamicEntity(entityId) -> std::optional<Red::Handle<Red::Entity>>`, `m_networkedEntitiesLookup: std::map<uint64_t, ent::EntityID>`.
- Produces: redscript `ProbeLocomotionFeed(entity: ref<Entity>)` (temporär, fliegt in Task 3 wieder raus) und den **verifizierten Graph-Input-Namen** (Ergebnis, dokumentiert in der Spec).

- [ ] **Step 1: Probe-Funktion in NetworkGameSystem.reds**

Ans Ende der Klasse `NetworkGameSystem` (vor der schließenden Klammer, nach `PuppetAction`):

```reds
    // STAGE-1 PROBE (temporary): feeds constant locomotion data to a puppet's blendgraph
    // under several candidate input names at once — wrong names are consumed by no graph
    // input and are harmless; if the legs move, the name exists and we bisect afterwards.
    public func ProbeLocomotionFeed(entity: ref<Entity>) {
        let puppet = entity as ScriptedPuppet;
        if !IsDefined(puppet) {
            return;
        }
        let feature = new AnimFeature_PlayerMovement();
        feature.SetSpeed(3.0);
        feature.SetMovementDirection(new Vector4(0.0, 1.0, 0.0, 0.0), new Vector4(0.0, 1.0, 0.0, 0.0));
        feature.SetFacingDirection(new Vector4(0.0, 1.0, 0.0, 0.0));
        AnimationControllerComponent.ApplyFeature(puppet, n"Movement", feature);
        AnimationControllerComponent.ApplyFeature(puppet, n"movement", feature);
        AnimationControllerComponent.ApplyFeature(puppet, n"Locomotion", feature);
        AnimationControllerComponent.ApplyFeature(puppet, n"locomotion", feature);
        AnimationControllerComponent.ApplyFeature(puppet, n"MovementData", feature);
        AnimationControllerComponent.ApplyFeature(puppet, n"LocomotionData", feature);
    }
```

- [ ] **Step 2: Probe-Schleife in OnNetworkUpdate (C++)**

In `NetworkGameSystem.cpp`, in `OnNetworkUpdate` direkt nach `PollIncomingMessages();` (Zeile ~110):

```cpp
    // STAGE-1 PROBE (temporary, removed with the interpolation rework): drive every remote
    // puppet's locomotion graph with constant values each frame — proves the ApplyFeature
    // path on NPCs and answers the per-tick-overwrite question in one experiment.
#define CHOOMLINK_LOCOMOTION_PROBE 1
#if CHOOMLINK_LOCOMOTION_PROBE
    for (const auto& [netId, spawnedEntityId] : m_networkedEntitiesLookup)
    {
        if (const auto probeEntity = Cyberverse::Utils::GetDynamicEntity(spawnedEntityId); probeEntity.has_value())
        {
            Red::CallVirtual(this, "ProbeLocomotionFeed", probeEntity.value());
        }
    }
#endif
```

- [ ] **Step 3: Bauen + Deployen**

```powershell
cmake --build "C:\Users\G4M3R\Programming\choomlink-core\client\red4ext\build\ninja-vcpkg"
Copy-Item "C:\Users\G4M3R\Programming\choomlink-core\client\red4ext\build\ninja-vcpkg\src\Cyberverse.Red4Ext.dll" "C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\red4ext\plugins\Cyberverse\" -Force
Copy-Item "C:\Users\G4M3R\Programming\choomlink-core\client\RedscriptModule\src\*" "C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\r6\scripts\Cyberverse\" -Recurse -Force
```
Expected: Build ohne Fehler, Kopien ohne Fehler.

- [ ] **Step 4: In-Game-Probe (ingame-verify-Sequenz)**

Server läuft; 1 Static-Bot nahe am Spieler-Spawn starten (`--count 1 --pattern static`); Spiel mit Connect-Args starten; Log-Gate (Global Constraints) abwarten; „joined the world" im Server-Log per Offset-Scan detektieren. Dann `scripts/capture-burst.ps1` (6 Frames, 500 ms) und PNGs lesen.

Expected (Erfolg): Das stehende Puppet zeigt Laufbewegung in den Beinen (Posen variieren über den Burst, obwohl die Position konstant ist — es „läuft auf der Stelle" oder gleitet vorwärts, beides beweist den Feed).

- [ ] **Step 5: Entscheidungs-Gate**

* **Beine bewegen sich** → Input-Name existiert in der Kandidatenliste. Weiter mit Step 6 (Bisektion).
* **Keine Bewegung** → WolvenKit-Fallback: NPC-`.animgraph` inspizieren, um den echten Input-Namen zu finden (WolvenKit CLI: Archive durchsuchen nach dem im Puppet-`.ent` referenzierten `.animgraph`, JSON-Export, nach `animFeature`-Node-Namen greppen). Neue Kandidaten in `ProbeLocomotionFeed` eintragen, nur reds neu deployen, Spiel neu starten. Nach 2 erfolglosen Runden: STOP, Befund dem Auftraggeber vorlegen (Fallback-Entscheidung PushEvent laut Spec).

- [ ] **Step 6: Bisektion des Input-Namens**

`ProbeLocomotionFeed` auf die Hälfte der Namen kürzen, nur reds deployen (`Copy-Item` wie Step 3, zweite Zeile), Spiel neu starten, Burst — wiederholen bis genau EIN Name übrig ist. (Nur-reds-Zyklus ist schnell: kein C++-Build nötig.) Dabei zugleich prüfen: bewegen sich die Beine **kontinuierlich** (pro Frame-Feed reicht) oder ruckeln sie (native Überschreibung kämpft dagegen — Befund notieren).

- [ ] **Step 7: Befund festhalten + Commit**

Spec (`choomlink/docs/superpowers/specs/2026-07-13-animfeature-locomotion-design.md`) um einen Abschnitt „Stufe-1-Ergebnis" ergänzen: verifizierter Input-Name, Überschreib-Verhalten, ggf. Abweichungen. Probe-Code committen (er fliegt in Task 3 raus, aber der Zwischenstand ist das dokumentierte Experiment):

```bash
git -C /c/Users/G4M3R/Programming/choomlink-core add client/RedscriptModule/src/Network/NetworkGameSystem.reds client/red4ext/src/NetworkGameSystem.cpp
git -C /c/Users/G4M3R/Programming/choomlink-core commit -m "stage 1 probe: AnimFeature_PlayerMovement feed on remote puppets (input-name discovery)"
git -C /c/Users/G4M3R/Programming/choomlink add docs/superpowers/specs/2026-07-13-animfeature-locomotion-design.md
git -C /c/Users/G4M3R/Programming/choomlink commit -m "Spec: record stage-1 probe result (graph input name, overwrite behavior)"
```

Spiel beenden (`Stop-Process -Name Cyberpunk2077`), Bots stoppen; Server kann für Task 4 weiterlaufen.

---

### Task 3: Stufe 2 — Interpolation ersetzt Proxy-Follow (Code-Umbau)

Der eigentliche Umbau. `n"Movement"` steht im Folgenden als Platzhalter für den in Task 2 verifizierten Input-Namen — beim Implementieren den echten Namen einsetzen.

**Files:**
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\client\red4ext\src\NetworkGameSystem.h` (MovementState-Struct, neue Methode)
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\client\red4ext\src\NetworkGameSystem.cpp` (eTeleportEntity, eDestroyEntity, OnNetworkUpdate, neue Methode; Probe raus)
- Modify: `C:\Users\G4M3R\Programming\choomlink-core\client\RedscriptModule\src\Network\NetworkGameSystem.reds` (DriveLocomotion + KinematicMove rein; Proxy-Trio + Probe raus)

**Interfaces:**
- Consumes: verifizierter Input-Name aus Task 2; `Cyberverse::Utils::Entity_GetWorldPosition(entity) -> RED4ext::Vector4`; bestehendes `SetEntityPosition(entityId, worldPosition, yaw)` (Hard-Teleport, bleibt für >8 m).
- Produces: reds `DriveLocomotion(entity: ref<Entity>, speed: Float, direction: Vector4, facing: Vector4)`, reds `KinematicMove(entity: ref<Entity>, position: Vector4, yaw: Float)`, C++ `void UpdatePuppetInterpolation(float deltaTime)`.

- [ ] **Step 1: MovementState-Struct + Methodendeklaration (NetworkGameSystem.h)**

Struct (Zeilen 34–45) ersetzen durch:

```cpp
    // Per-remote-puppet movement bookkeeping (locomotion sync, AI-free): each network update
    // stores only the target pose + the velocity derived from the update interval; a per-frame
    // interpolation moves the puppet kinematically and the locomotion blendgraph is fed the
    // same speed/direction data it normally receives from the movement AI.
    struct MovementState
    {
        RED4ext::Vector4 targetPosition {};
        float targetYaw = 0.0f;
        RED4ext::Vector4 velocity {};    // world units/s toward target
        float speed = 0.0f;              // m/s magnitude, feeds the anim graph
        float timeSinceUpdate = 0.0f;    // accumulated frame dt since the last packet
        bool hasTarget = false;
        bool idleApplied = false;        // idle anim feed sent since arrival (send once)
    };
```

In den privaten Methoden (bei `SetEntityPosition`) ergänzen:

```cpp
    void UpdatePuppetInterpolation(float deltaTime);
    void DriveLocomotionFeed(const Red::Handle<Red::Entity>& entity, const MovementState& state);
```

- [ ] **Step 2: eTeleportEntity-Handler umbauen (NetworkGameSystem.cpp)**

Den kompletten Block ab `auto& moveState = m_movementState[entityId];` (Zeile ~378) bis zum Ende des `case` (vor `break;` Zeile ~421) ersetzen durch:

```cpp
            // Locomotion sync (AI-free): store the new target pose; velocity from the update
            // interval scales automatically with the falloff tier (10 Hz near, 2 Hz far).
            // A per-frame interpolation (UpdatePuppetInterpolation) moves the puppet.
            auto& moveState = m_movementState[entityId];

            const auto lagX = teleport.targetPosition.x - positionSource.X;
            const auto lagY = teleport.targetPosition.y - positionSource.Y;
            const auto lagZ = teleport.targetPosition.z - positionSource.Z;
            const auto puppetLag = std::sqrt(lagX * lagX + lagY * lagY + lagZ * lagZ);

            if (puppetLag > 8.0f)
            {
                // Desync / spawn placement / vehicle exit: hard-teleport to catch up.
                SDK->logger->TraceF(PLUGIN, "Entity %llu is %f m off target, teleport catch-up", teleport.networkedEntityId, puppetLag);
                SetEntityPosition(entityId, worldPosition, teleport.yaw);
                moveState.targetPosition = worldPosition;
                moveState.targetYaw = teleport.yaw;
                moveState.velocity = {};
                moveState.speed = 0.0f;
                moveState.timeSinceUpdate = 0.0f;
                moveState.hasTarget = true;
                moveState.idleApplied = false;
                break;
            }

            if (moveState.hasTarget)
            {
                const float interval = std::clamp(moveState.timeSinceUpdate, 0.05f, 1.0f);
                const float dX = worldPosition.X - moveState.targetPosition.X;
                const float dY = worldPosition.Y - moveState.targetPosition.Y;
                const float dZ = worldPosition.Z - moveState.targetPosition.Z;
                moveState.velocity = { dX / interval, dY / interval, dZ / interval, 0.0f };
                moveState.speed = std::sqrt(dX * dX + dY * dY + dZ * dZ) / interval;
            }

            moveState.targetPosition = worldPosition;
            moveState.targetYaw = teleport.yaw;
            moveState.timeSinceUpdate = 0.0f;
            moveState.hasTarget = true;
            moveState.idleApplied = false;

            DriveLocomotionFeed(entity.value(), moveState);
```

`#include <algorithm>` (für `std::clamp`) oben ergänzen, falls nicht vorhanden.

- [ ] **Step 3: UpdatePuppetInterpolation + DriveLocomotionFeed (NetworkGameSystem.cpp)**

Als neue Methoden (z. B. unter `SetEntityPosition`):

```cpp
void NetworkGameSystem::UpdatePuppetInterpolation(const float deltaTime)
{
    for (auto& [entityId, state] : m_movementState)
    {
        state.timeSinceUpdate += deltaTime;
        if (!state.hasTarget)
        {
            continue;
        }

        const auto entity = Cyberverse::Utils::GetDynamicEntity(entityId);
        if (!entity.has_value())
        {
            continue;
        }

        const auto pos = Cyberverse::Utils::Entity_GetWorldPosition(entity.value());
        const float remX = state.targetPosition.X - pos.X;
        const float remY = state.targetPosition.Y - pos.Y;
        const float remZ = state.targetPosition.Z - pos.Z;
        const float remaining = std::sqrt(remX * remX + remY * remY + remZ * remZ);

        if (remaining < 0.02f || state.speed <= 0.01f)
        {
            if (!state.idleApplied)
            {
                state.speed = 0.0f;
                DriveLocomotionFeed(entity.value(), state); // blend to idle, once
                state.idleApplied = true;
            }
            continue;
        }

        float step = state.speed * deltaTime;
        if (step > remaining)
        {
            step = remaining; // never overshoot the last known target
        }

        const RED4ext::Vector4 newPos = { pos.X + remX / remaining * step,
                                          pos.Y + remY / remaining * step,
                                          pos.Z + remZ / remaining * step, 1.0f };
        Red::CallVirtual(this, "KinematicMove", entity.value(), newPos, state.targetYaw);
    }
}

void NetworkGameSystem::DriveLocomotionFeed(const Red::Handle<Red::Entity>& entity, const MovementState& state)
{
    const float yawRad = state.targetYaw * 0.017453292f;
    const RED4ext::Vector4 facing = { -std::sin(yawRad), std::cos(yawRad), 0.0f, 0.0f };
    RED4ext::Vector4 direction = facing;
    if (state.speed > 0.01f)
    {
        direction = { state.velocity.X / state.speed, state.velocity.Y / state.speed,
                      state.velocity.Z / state.speed, 0.0f };
    }
    Red::CallVirtual(this, "DriveLocomotion", entity, state.speed, direction, facing);
}
```

In `OnNetworkUpdate` die Probe-Schleife (Task 2) komplett entfernen und stattdessen nach `PollIncomingMessages();` einfügen:

```cpp
    UpdatePuppetInterpolation(frame_info.deltaTime);
```

- [ ] **Step 4: eDestroyEntity-Cleanup vereinfachen (NetworkGameSystem.cpp)**

Den Proxy-Cleanup-Block (Zeilen ~474–482) ersetzen durch:

```cpp
            m_movementState.erase(entityId);
```

- [ ] **Step 5: redscript umbauen (NetworkGameSystem.reds)**

(a) `ProbeLocomotionFeed` (Task 2) löschen. (b) `CreateMovementProxy`, `MoveProxy`, `StartFollowingProxy` samt Kommentarblock löschen. (c) Neu einfügen (Input-Name aus Task 2 einsetzen):

```reds
    // AI-free locomotion (phase 4b): the per-frame interpolation in C++ moves the puppet
    // kinematically; this feeds the locomotion blendgraph the same speed/direction data it
    // normally receives from the movement AI. Input name verified in the stage-1 probe.
    public func DriveLocomotion(entity: ref<Entity>, speed: Float, direction: Vector4, facing: Vector4) {
        let puppet = entity as ScriptedPuppet;
        if !IsDefined(puppet) {
            return;
        }
        let feature = new AnimFeature_PlayerMovement();
        feature.SetSpeed(speed);
        feature.SetMovementDirection(direction, facing);
        feature.SetFacingDirection(facing);
        AnimationControllerComponent.ApplyFeature(puppet, n"Movement", feature);
    }

    // Kinematic per-frame move for remote puppets (no AI command, no collider side effects
    // beyond what the teleport facility does itself).
    public func KinematicMove(entity: ref<Entity>, position: Vector4, yaw: Float) {
        let go = entity as GameObject;
        if !IsDefined(go) {
            return;
        }
        let angles: EulerAngles;
        angles.Yaw = yaw;
        GameInstance.GetTeleportationFacility(go.GetGame()).Teleport(go, position, angles);
    }
```

`TeleportIfNotPuppet`, `TeleportPuppet`, `StopAICommand`, `PuppetAction` bleiben unverändert.

- [ ] **Step 6: Bauen + Deployen**

Kommandos wie Task 2 Step 3. Expected: Build ohne Fehler.

- [ ] **Step 7: Commit (choomlink-core)**

```bash
git -C /c/Users/G4M3R/Programming/choomlink-core add client/red4ext/src/NetworkGameSystem.h client/red4ext/src/NetworkGameSystem.cpp client/RedscriptModule/src/Network/NetworkGameSystem.reds
git -C /c/Users/G4M3R/Programming/choomlink-core commit -m "locomotion: replace proxy-follow with client interpolation + AnimFeature feed (AI-free)"
```

---

### Task 4: Stufe 2 — In-Game-Verifikation (Spec §Tests Punkt 3)

**Files:** keine Änderungen — reine `ingame-verify`-Durchführung.

**Interfaces:**
- Consumes: deployter Stand aus Task 3; Bot-Harness-Zähler; `scripts/capture-burst.ps1`.

- [ ] **Step 1: Nah-Test (4-Bot-Kreis).** Server + `--count 4 --pattern circle`; Spiel starten, Log-Gate, Join-Detection. Screenshot-Burst (6 × 500 ms). Expected: 4 Puppets laufen den Kreis **flüssig** — Posen variieren (laufen, nicht gleiten), Positionen wandern stetig, **kein Stop-and-Go** (Totzonen-Gegenprobe), **kein sichtbares Fußgleiten** (Skyrim-Together-Kriterium: Beinbewegung passt zur Verschiebung pro Frame-Paar). Bei Fußgleiten: Befund dokumentieren, Auftraggeber-Urteil einholen (Spec nennt es explizit als sein Feel-Kriterium).
- [ ] **Step 2: Log-Gegenprobe.** Server-Log: keine 8-m-Catch-up-Traces im Normallauf (`teleport catch-up` nur bei echten Desyncs). red4ext-Log: keine Warnungen/Fehler vom neuen Pfad.
- [ ] **Step 3: Boundary-Regression.** Bots stoppen; `--count 1 --pattern boundary` + 1 Observer-Bot im Zentrum (`--count 1 --pattern static`): Spawn/Despawn-Zähler wie in Phase 1 (einmal Spawn, kein Flackern). Der Test läuft headless über die Bot-Zähler — Spiel kann dafür aus bleiben.
- [ ] **Step 4: Fern-Interpolation.** `--pattern boundary --distance 300` gegen Observer: Observer empfängt ~2 Teleports/s (Falloff-Regression); im Spiel (optional, falls noch offen) kein Ruckeln beim 2-Hz-Ziel.
- [ ] **Step 5: Aufräumen + Befund.** Spiel/Bots stoppen. Ergebnis (inkl. Screenshots-Urteil) für Task 5 notieren. Bei Regressionen: STOP, zurück zu Task 3 mit Befund.

---

### Task 5: Stufe 3 — 50-Bot-Dichtetest + Abschluss

**Files:**
- Modify: `C:\Users\G4M3R\Programming\choomlink\docs\superpowers\specs\2026-07-13-animfeature-locomotion-design.md` (Abschnitt „Verifikations-Ergebnisse")

**Interfaces:**
- Consumes: Vergleichsbasis 50-Bot-Test vom 2026-07-13 (dokumentiert in `2026-07-13-interest-management-design.md`: sichtbares Teleport-Stottern durch KI-Budget).

- [ ] **Step 1: 50-Bot-Test.** Server + `--count 50 --pattern random`; Spiel starten (Log-Gate, Join). Screenshot-Burst + Server-/Bot-Zähler. Expected: Puppets bewegen sich kontinuierlich (kein Teleport-Stottern wie beim Proxy-Follow-Lauf), Netzwerk-Zähler verlustfrei, Spiel bleibt spielbar (FPS-Eindruck: Auftraggeber fragen, eigene Beobachtung zuerst berichten).
- [ ] **Step 2: Perf-Ventil (nur falls nötig).** Falls das Spiel bei 50 Puppets durch die Per-Frame-Teleports einbricht: Interpolation auf 30 Hz drosseln (in `UpdatePuppetInterpolation` einen Akkumulator `m_timeSinceInterpolation` einziehen, bei < 1/30 s früh raus) — als separater Commit mit Vorher/Nachher-Beobachtung.
- [ ] **Step 3: Verifikations-Ergebnisse in die Spec** (Muster der bisherigen Specs: Zähler, Bursts, Abweichungen, offene Punkte) + Bean aktualisieren:

```bash
beans update choomlink-mg7p  # Stufen 1-3 Ergebnis eintragen; Status nach Auftraggeber-Feel-Urteil
```

- [ ] **Step 4: Aufräumen (Pflicht).** `Stop-Process -Name Cyberpunk2077`; Bots + Server stoppen.
- [ ] **Step 5: Commits + Push (beide Repos).**

```bash
git -C /c/Users/G4M3R/Programming/choomlink-core push
git -C /c/Users/G4M3R/Programming/choomlink add docs/superpowers/specs/2026-07-13-animfeature-locomotion-design.md
git -C /c/Users/G4M3R/Programming/choomlink commit -m "Spec: verification results for AnimFeature locomotion (stages 1-3)"
git -C /c/Users/G4M3R/Programming/choomlink push
```
