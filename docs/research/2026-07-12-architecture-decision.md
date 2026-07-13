# Zielarchitektur für ChoomLink — Entscheidungsbericht

> Synthese aus 5 parallelen Recherche-Sessions (2026-07-12) zum Auftrag
> `2026-07-12-architecture-model-research-prompt.md`. Alle Rohberichte mit
> vollständigen Quellenlisten liegen im Transcript dieser Session; hier nur
> die verdichtete Entscheidungsgrundlage. Kein CyberpunkMP-Quellcode wurde
> in irgendeiner Recherche gelesen — nur öffentliche Dokumentation/Talks.

## a) Empfohlene Zielarchitektur (eine Seite, entscheidend)

**ChoomLink wird ein server-vermittelter Relay mit clientseitiger Simulation
und dreistufiger Autoritätsverteilung** — architektonisch am nächsten an
FiveM/alt:V, nicht an GTA Onlines P2P-Modell und nicht an Skyrim Togethers
"partial authority ohne Weltrepräsentation".

**Warum dieses Modell und keine Alternative:** Die Recherche zu Referenz-
architekturen liefert einen klaren, mehrfach belegten Kausalzusammenhang:
GTA Onlines schlechter Ruf (Mod-Menüs, Geld-Injection, IP-Sniffing für DDoS,
sogar ein RCE-fähiger CVE 2023) kommt strukturell daher, dass es **keinen
vertrauenswürdigen Schiedsrichter** gibt — jeder Peer kann Zustand injizieren,
den niemand validiert. FiveM gewann die Community genau deshalb, weil sein
Server diese Rolle übernimmt: er kann Entity-Erzeugung verbieten
(`SetRoutingBucketEntityLockdownMode`), besitzt Entities unabhängig von der
Anwesenheit eines Spielers, und ist der einzige Ort, an dem Wirtschaft/
Inventar/Berechtigungen als Fakten existieren. Das ist erreichbar, **ohne**
dass der Server das Spiel simuliert — das ist exakt die Einschränkung, unter
der auch FiveM/alt:V/RAGE:MP/MTA:SA arbeiten (keiner von ihnen führt eine
Kopie von GTA V serverseitig aus).

Skyrim Together Reborn ist die Gegenprobe: weil dort selbst die NPC-KI von
dem Client simuliert wird, der die Zelle geladen hat (nicht zentral
arbitriert), bleibt es bei 2–8 Spielern und produziert framerate-abhängigen
Desync. Das ist die Falle, die ChoomLink vermeiden muss — auch wenn der
Server nicht simulieren kann, muss er so viel wie architektonisch möglich
zentral **arbitrieren**, statt reine Weiterleitung zwischen Clients zu sein.

**Die drei Autoritäts-Ebenen (aus der Authority-Recherche, branchenweit
konvergent):**

1. **Bewegung/Lokomotion — client-simuliert, server-bucht, server-verwirft
   Unplausibles.** Der Client, der eine Entity "besitzt" (analog FiveMs
   Net-Owner / alt:Vs netOwner), simuliert sie; der Server hält nur die
   kanonische letzte Position/Velocity/Timestamp als Autoritäts-Register und
   wendet einen billigen Plausibilitätsfilter an (Max-Speed-pro-Zeit,
   Teleport-Distanz-Ablehnung) — genau das "server veto"-Muster aus der
   Anti-Cheat-Literatur, keine Physik-Nachsimulation.
2. **Kampf/Schaden — client-erkannt, server-gegated, server-committed.**
   Hit-Detection kann nur clientseitig passieren (niemand in der Branche
   macht das anders). Der Client meldet ein strukturiertes Ereignis
   (Angreifer, Ziel, Waffe, Position, Zeitstempel); der Server prüft
   Reichweite/Winkel-Plausibilität/Feuerrate gegen die zuletzt bekannten
   Positionen, bevor er die **Konsequenz** (HP-Abzug, Tod, Loot) als eigene
   Transaktion committet. Ein Client darf nie direkt HP setzen — das schließt
   die schlimmste Cheat-Klasse (Godmode, One-Shot-Kill-Injection), ohne dass
   der Server je simulieren müsste.
3. **Inventar/Wirtschaft — vollständig serverautoritativ, reine Daten.**
   Dies ist die einzige Ebene ohne Echtzeit-Physik-Abhängigkeit und damit die
   billigste, höchst-hebelige Investition: Geld/Items existieren nur als
   Server-DB-Zeilen; jede Mutation ist eine validierte, atomare Transaktion.
   Clients fragen nur an und zeigen an — sie behaupten nie Zustand.

**Anti-Cheat-Erwartungshaltung, ehrlich formuliert:** Kein Server in diesem
Genre erreicht simulationsgenauen Schutz. Der realistische Anspruch ist
"Kosten des Cheatens erhöhen, Schaden begrenzen" über die drei Ebenen oben
plus später eine Erkennungsschicht — kein Kernel-Level-Anti-Cheat, das ist
eine andere, für einen Solo-Modder nicht sinnvolle Gewichtsklasse.

**Sync/Skalierung:** Das aktuelle naive Full-Broadcast-Modell (10 Hz an
alle) skaliert O(n²) im Payload-Fanout — 8→32 Spieler ist nicht 4×, sondern
grob 16× Traffic. Interessens-Management (Culling-Radius, FiveM/alt:V/
RAGE:MP: 400–500 Einheiten) ist der mit Abstand größte Hebel, gefolgt von
Delta-Encoding und Quantisierung.

**Session-Ebene:** Freeroam + Instanzen (Rennen, Deathmatch) sollten als
**ein persistenter Serverprozess mit einem In-Memory-Partitionierungsschlüssel**
gebaut werden (FiveM "routing buckets", alt:V "dimensions") — nicht als
Prozess-pro-Instanz. Instanz-Eintritt über serverseitige Trigger-Zonen
(Collision-Volumes), analog zu GTA Onlines Missions-Blips.

**Fork-Verdikt:** Evolvieren, nicht neu bauen (Details unter e).

---

## b) Vergleichsmatrix der Referenzplattformen

| Plattform | Topologie | Autorität | Tick/Sync | Entity-Ownership | Scripting | Persistenz | Typische Spielerzahl |
|---|---|---|---|---|---|---|---|
| **GTA Online** | P2P (Host + Peers) | Kein Schiedsrichter — Peer-vertraut | ~30 Hz (Community-Quelle) | Kein dokumentiertes Ownership-Modell | Keine (offiziell geschlossen) | Rockstar-Backend, kein Community-Zugriff | ~30/Session; berüchtigt für Mod-Menüs, CVE-2023-24059 |
| **FiveM/Cfx.re** | Dedizierter Server | Client-forwarding (Net-Owner) + Server-Konvention für Economy/Trust | OneSync Infinity: 424-Einheiten Focus-Zone, Delta-Sync-Trees | Explizit "net owner", Orphan-Modus, Routing-Buckets | Lua/JS/C#, Resource-Manifest (client/server/shared) | Community-Standard: MySQL/MariaDB (ESX/QBCore) | Bis 2048 (Infinity); Community-Peak ~270k CCU plattformweit |
| **alt:V** *(2026 abgeschaltet — Take-Two C&D)* | Dedizierter Server | Server-autoritativ + delegierte Peer-Simulation | Worker-Threads (syncSend/Receive/migration/streamer) | `netOwner` mit proximity-Migration, Hysterese (stream 400 / migration 150) | JS/TS, C#, C++ SDK | MongoDB (Rebar/Athena) | 300–600 pro Server üblich |
| **RAGE:MP** *(2026 abgeschaltet — Take-Two C&D)* | Dedizierter Server | Stärker server-autoritativ (sync vars nur serverseitig schreibbar) | Fix ~40 ms (25 Hz) | Streaming-in/-out, kein explizites Ownership-API | Node.js/JS server, JS/C# client, CEF-UI | MySQL/MariaDB, oft EF Core | Default 100, community bis ~1000 möglich |
| **MTA:SA** | Dedizierter Server (RakNet/UDP) | Hybrid: Server-Logik autoritativ, Bewegung client-"syncer" mit Server-Override | Event-driven Key-Sync + Intervall-Korrektur (100–2000 ms je Typ) | Automatischer, proximity-basierter Syncer mit `persist`-Lock | Lua (Server+Client), ACL-Sandbox | SQLite (Accounts) + optional MySQL (Gamemode) | 500+ pro Server dokumentiert, 36k+ plattformweit gleichzeitig |
| **Skyrim Together Reborn** | Dedizierter Server | "Partially authoritative" — keine serverseitige Weltrepräsentation | Kein fixer Tick, framerate-gekoppelt | LocalActor (Zell-Owner simuliert KI) / RemoteActor | Keine — reiner Sync-Layer über Papyrus | Keine — unabhängige Spielstände je Spieler | Empfohlen 2–8, experimentell bis ~30 mit Desync |
| **Rust** | Dedizierter Server | Voll server-autoritativ | ~10 Hz historisch | Serverseitig simuliert, kein Client-Ownership | C# (Oxide/uMod, Carbon) | Binäre Saves + Wipe-Zyklus | 100–200+ üblich |
| **DayZ** | Dedizierter Server (Enfusion) | Server-autoritativ inkl. Shot-Validation | Server-FPS-gekoppelt (25–35 bei 60+ Spielern) | Distanz-gestaffelte "Network Bubbles" (20/150/1000/4000m) | Enforce Script (C#-artig) | Central Economy XML + periodische Backups | Referenz-Config 60, Warteschlange bis 500 |
| **Minecraft (Java)** | Dedizierter Server/Proxy | Voll server-autoritativ, Client-Input validiert | Fix 20 TPS (50 ms) | Chunk-/Simulationsdistanz-basiert | Plugin (Bukkit/Paper) vs. Mod (Forge/Fabric) | Region-Files (Anvil/NBT) | 50–150 pro Prozess, Proxy-Verbund 1000+ |

---

## c) Phasierte Evolutions-Roadmap (solo-dev-tauglich, jede Phase einzeln shippable)

Ausgangspunkt: heutiger Cyberverse-Fork — Server.Native (C++, GameNetworkingSockets),
Server.Managed (C#/.NET, Plugin-fähig), shared/protocol (zpp_bits), RED4ext +
Redscript-Client. Verifiziert: Connect/Auth/World-Join, 10 Hz Full-Broadcast-
Position, Action-Relay, Proxy-Follow-Lokomotion, Bot-Harness.

**Phase 1 — Interessens-Management (höchster Hebel, kleinster Aufwand).**
Distanz-Radius (Vorbild 400–500 Einheiten) im Server.Managed-Broadcast-Pfad:
nur Peers innerhalb des Radius bekommen Positions-Updates eines Spielers.
Wandelt den O(n²)-Fanout in O(n·k) — die Voraussetzung, um überhaupt über
~16 Spieler hinauszukommen. Reine Filter-Ergänzung vor dem bestehenden
Broadcast, kein Redesign. *Shippable: sichtbar bessere Bandbreite schon bei
den nächsten Bot-Harness-Lasttests.*

**Phase 2 — Frequenz-Falloff + Quantisierung/Delta-Encoding.**
Nahe Peers 10 Hz, mittlere 3–5 Hz, ferne 1 Hz/on-change. Positions-/
Rotations-Quantisierung (Gaffer-On-Games-Muster: ~50 Bit statt Rohfloats)
plus Delta gegen letzten bestätigten Zustand. Reines Protokoll-Update
innerhalb des bestehenden zpp_bits-Layers — einer der "6 Stellen" aus dem
Packet-Checklist, aber lokal begrenzt. *Shippable: Bandbreiten-Budget für
32+ Spieler.*

**Phase 3 — Server-autoritative Wirtschaft/Inventar (Fundament für alles
Spätere).** Erste echte Persistenzschicht: relationale DB (MySQL/MariaDB,
Community-Standard) mit Kern-Tabelle für Charakter/Identität + JSON-Spalten
für Inventar/Metadata (QBCore-Schema als Vorlage). Jede Mutation eine
atomare Server-Transaktion. Kein Physik-Bezug — geringstes Risiko, höchster
Sicherheitsgewinn zuerst. *Shippable: erste dauerhafte Spieler-Identität
über Sessions hinweg.*

**Phase 4 — Kampf/Schaden mit Plausibilitäts-Gate.** EntityAction-Familie
(existiert schon für Jump) erweitern um Hit-Events; Server prüft Reichweite/
Winkel/Cooldown gegen zuletzt bekannte Positionen, committet HP-Änderung
selbst. *Shippable: PvP-Grundlage, bean 2hum/y9rd.*

**Phase 5 — NPC-Sync: Entity-Ownership & Handover für kuratierte
Gameplay-NPCs (Ziel: ~100 gleichzeitig).** Zwei NPC-Klassen werden strikt
getrennt (FiveM-Vorbild): **ambiente NPCs** (Verkehr, Passanten) bleiben
komplett client-lokal und unsynchronisiert — jeder Client rendert seine
eigene Population, niemand muss sich über Passant Nr. 4000 einig sein.
**Gameplay-relevante NPCs** (Gegner in Encounter-Zonen, Bosse, Händler)
werden synchronisiert, und zwar mit demselben Bauplan wie Remote-Spieler:
- **Ownership:** ein Client "besitzt" die NPC, simuliert ihre KI/Pfadfindung
  lokal und meldet Position/Zustand als Fakten — wie ein Spieler heute seine
  eigene Position meldet. Zuweisung proximity-basiert.
- **Darstellung:** alle anderen Clients sehen die NPC als Proxy-Follow-Puppet
  (bestehende Lokomotions-Architektur, unverändert wiederverwendet).
- **Handover:** Hysterese-Band wie alt:V (Stream-Distanz 400 / Migrations-
  Distanz 150), damit Ownership an der Grenze nicht flackert; explizites
  Disconnect-Cleanup (FiveMs eigene Docs nennen verwaiste Entities einen
  bekannten Footgun).
- **Kampf gegen NPCs:** gleiches Gate wie PvP (Phase 4) — Client meldet Hit,
  Server prüft Plausibilität und committet HP als Transaktion, damit alle
  Clients sich einig sind, ob die NPC lebt.

Voraussetzungen: Phase 1 (sonst reproduziert 100 NPCs × alle Spieler sofort
wieder das O(n²)-Problem) und Phase 4 (Hit-Gate). Die Rendering-/Physik-Last
ist voraussichtlich nicht der Engpass — Cyberpunk simuliert im Singleplayer
problemlos Hunderte Passanten; der Engpass ist die Netzwerk-/Ownership-
Logik. Das ~100-NPC-Ziel wird vor jeder Zusage mit dem Bot-Harness
lastgetestet (Bots als NPC-Owner-Simulatoren). *Shippable: erste
PvE-Encounter-Zone mit synchronisierten Gegnern.*

**Phase 6 — Session-/Instanz-Ebene.** In-Memory-Partitionierungsschlüssel
im Server.Managed-Entity-Modell (Bucket/Dimension-Äquivalent) + serverseitige
Trigger-Zonen für Instanz-Eintritt. Drop-in/Drop-out wird eine reine
State-Mutation, kein Prozess-Handling. *Shippable: erste instanzierte
Aktivität (Rennen/Deathmatch) neben Freeroam.*

**Phase 7 — Priority-Accumulator-Verfeinerung (später, nicht dringend).**
Erst relevant, wenn NPC-/Traffic-Sync dazukommt und Entity-Zahl 10–100×
Spielerzahl übersteigt.

Jede Phase ist unabhängig testbar mit dem bestehenden Bot-Harness und dem
`ingame-verify`-Skill.

---

## d) Trade-off-Protokolle (die größten Entscheidungen)

1. **Full-Broadcast beibehalten vs. Interessens-Management sofort einführen.**
   Gewählt: sofort (Phase 1). *Warum:* O(n²) ist der erste Faktor, der beim
   Skalieren bricht — jede spätere Phase baut auf einem begrenzten
   Broadcast-Modell auf. Kosten: zusätzlicher State (wer sieht wen) im
   Server.Managed, aber geringer Implementierungsaufwand gegenüber dem Nutzen.

2. **Client-forwarding-Bewegung (kein Server-Physik) vs. Versuch einer
   serverseitigen Bewegungsvalidierung mit echter Physik.** Gewählt:
   client-forwarding + billiger Plausibilitätsfilter. *Warum:* Serverseitige
   Physik ist bei Cyberpunk 2077 architektonisch unmöglich (keine Headless-
   Spielsimulation) — das ist keine Wahl, sondern eine harte Randbedingung.
   Der Plausibilitätsfilter ist der maximal erreichbare Kompromiss, den auch
   FiveM/alt:V fahren.

3. **Reported-hit-Kampf mit Server-Veto vs. gar keine Kampfvalidierung.**
   Gewählt: Server-Veto (Phase 4). *Warum:* Ohne jede Validierung ist
   Godmode/One-Shot-Injection trivial (Rockstars eigene P2P-Erfahrung als
   Negativbeispiel). Die Veto-Schicht ist billig (reine Arithmetik) und
   schließt die schlimmste Cheat-Klasse, ohne Simulation zu benötigen.
   Kosten: kann Aimbot/Wallhack nicht erkennen — das wird offen kommuniziert,
   nicht versprochen.

4. **Ein persistenter Serverprozess mit Partitionierungsschlüssel (Bucket/
   Dimension) vs. separate Prozesse pro Instanz.** Gewählt: ein Prozess +
   Partitionierung. *Warum:* FiveM und alt:V kamen unabhängig voneinander zum
   gleichen Schluss — Prozess-pro-Instanz bräuchte Connection-Migration/
   Reconnect-Logik, die mehr Komplexität kostet als sie an Isolation bringt.
   Bekannte Schwäche (von Cfx.re selbst dokumentiert): grobkörnige Buckets
   sind nicht ideal für kleinräumige Interieurs — als offene Baustelle
   akzeptiert, nicht verdrängt.

5. **Fork evolvieren vs. Neubau ("rebuild").** Gewählt: evolvieren (siehe e).
   *Warum:* Jeder öffentlich bekannte CP2077-Multiplayer-Versuch, der neu
   angefangen hat, ist entweder abgebrochen oder brauchte 4–5 Jahre bis
   Alpha/Beta — kein Beleg, dass ein Neustart schneller zu Feature-Parität
   mit dem heutigen, bereits funktionierenden Fork führt. Spolskys "Never
   rewrite"-Warnung (Netscape) und die Gegenposition (rewrite nur, wenn
   Änderungsbedarf ~25%+ des Codes betrifft) sprechen beide für Evolution,
   solange keine grundlegend falsche Technologiewahl vorliegt — und
   Transport (GameNetworkingSockets), Protokollansatz (zpp_bits) und
   Plugin-Server (Server.Managed) sind laut allen fünf Recherchen exakt die
   richtigen Bausteine für das Zielmodell.

---

## e) Risiken-Sektion — was bricht zuerst bei 16 / 32 / 64 Spielern

**Bei 16 Spielern:**
- Aktuelles Full-Broadcast-Modell (10 Hz, keine Culling) erzeugt bereits
  spürbaren Bandbreiten-Overhead (16² = 256 Update-Paare/Tick statt 8² = 64) —
  noch tragbar, aber die Kurve beginnt sich zu krümmen. **Fix: Phase 1 vor
  diesem Meilenstein.**
- Keine Entity-Ownership-Migration nötig, solange nur Spieler-Positionen
  (keine NPCs/Fahrzeuge) synchronisiert werden — Risiko hier gering.

**Bei 32 Spielern:**
- Ohne Phase 1 wird der Payload-Fanout ~16× gegenüber dem 8-Bot-Test (32²/8²) —
  das ist der Punkt, an dem "hat bei 8 funktioniert" nachweislich bricht.
  **Härtester Blocker, wenn Phase 1 nicht vorher umgesetzt ist.**
- Ohne Phase 3 (server-autoritative Wirtschaft) wird jeder Dupe-/Cheat-Exploit
  bei einer größeren, weniger vertrauten Testergruppe sichtbar und teuer —
  Community-Vertrauen ist bei dieser Spielerzahl erstmals wirklich im Spiel.
- Instanz-/Session-Ebene (Phase 6) wird nötig, sobald Freeroam + eine
  parallele Aktivität gleichzeitig laufen sollen — ohne sie konkurrieren
  alle Spieler zwangsläufig um dieselbe Weltinstanz.

**Bei 64 Spielern:**
- Reine Positions-Sync-Last verlangt zwingend Frequenz-Falloff + Delta-
  Encoding (Phase 2) — sonst ist die Bandbreite pro Client selbst mit
  Interessens-Management noch zu hoch bei dichter Ansammlung (z. B. alle in
  einem Nachtclub).
- Sobald gameplay-relevante NPCs/Fahrzeuge mitsynchronisiert werden (Phase 5,
  Ziel ~100 kuratierte NPCs), wird Entity-Ownership-Migration ohne
  Hysterese-Band zum sichtbaren Problem: Teleport-on-Handover und
  Boundary-Thrashing sind in FiveM/alt:V/RAGE:MP-Foren gut dokumentierte,
  wiederkehrende Bugs genau bei dieser Größenordnung.
- Anti-Cheat-Erwartung muss spätestens hier explizit kommuniziert werden:
  kein Server in diesem Genre verhindert Aimbot/Wallhack architektonisch —
  bei 64 öffentlichen Spielern wird das erstmals ein Community-Management-
  Thema, nicht nur ein Code-Thema.

**Übergreifendes Risiko bei allen drei Stufen:** Legal/IP — sowohl alt:V als
auch RAGE:MP wurden 2026 nach Jahren erfolgreichen Betriebs von Take-Two per
Cease-and-Desist abgeschaltet. Das hat keine direkte Entsprechung zu CDPR,
aber es unterstreicht: Plattform-Überleben hängt von mehr als technischer
Qualität ab — ein Faktor, der außerhalb dieses technischen Berichts, aber
nicht außerhalb der Projektplanung liegen sollte.
