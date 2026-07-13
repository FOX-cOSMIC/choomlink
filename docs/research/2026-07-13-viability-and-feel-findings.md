# Viability & Game-Feel — Deep-Research-Ergebnisse (2026-07-13)

> Ergebnis des `/deep-research`-Workflow-Laufs (5 Suchwinkel, 21 Quellen
> gefetcht, 66 Behauptungen extrahiert, 25 adversarial verifiziert: 20
> bestätigt / 5 verworfen). Quelle: `wf_5f7cc6a3-1fb`.

## Quellenlage-Einordnung

Wie beim Architektur-Bericht: nicht alle Befunde stehen auf gleich solidem
Boden. Zusammengefasst über den Erst-Workflow UND die drei Nachrecherchen:

- **Hohe Konfidenz (direkt gefetchte Primärquellen/offizielle Dokumente):**
  RED4ext-Release-Historie (GitHub, primär), Wabbajack/r2modman-Doku,
  Skyrim-Together-Mod-Paritäts-Mechanismus, Nexus Mods' Spenden-Richtlinie
  (Plattform-eigene Regel), CDPRs Fan-Content-Guidelines und EULA-Text
  (beide direkt abgerufen und zitiert), der Luke-Ross-VR-Mod-Fall und
  Take-Two/RAGE:MP/alt:V-Shutdown-Fakten (5+ unabhängige Pressequellen),
  Gambettas Artikelserie und Unitys Netcode-Doku (beide vollständig
  gefetcht, keine Sekundärzusammenfassung), das ACM-CHI-PLAY-Paper
  (Peer-Review, DOI vorhanden).
- **Mittlere Konfidenz (Sekundärquellen oder firmenübergreifende Synthese):**
  Riots "Peeker's Advantage"-Zahlen (nur über Such-Snippet erreicht, nicht
  direkt gefetcht), Overwatchs Command-Frame-Modell (nur ein Blogpost, der
  den GDC-Talk zusammenfasst — Primärquelle nicht erreichbar), **der
  CDPR-vs-Take-Two-Vergleich** ("CDPR ist mod-freundlicher") — das ist eine
  Synthese über zwei verschiedene Firmen-Historien, keine direkte
  Gegenüberstellung aus einer Quelle, die einzelnen Solo-Dev-Postmortem-
  Fälle (Thorium/Fabric/ENB/DerangedTeddy — jeweils Einzelbeispiele, nicht
  branchenweiter Konsens).
- **Niedrig/echte Lücke, explizit offen gelassen:** Overwatch-GDC-Talk-
  Originalinhalt (Video hinter Login, nicht extrahierbar), Valve-
  Entwicklerwiki-Werte (`cl_interp` — HTTP 403, automatisierte Abrufe
  komplett blockiert), das "Patch-Chasing-Burnout"-Narrativ (verbreitete
  Folklore, kaum in Ich-Form belegt), **wie CDPRs private-Server-EULA-
  Klausel tatsächlich ausgelegt würde** (nie getestet, nie kommentiert —
  siehe CDPR-Abschnitt unten).

Für die Projektentscheidungen, die bereits getroffen wurden (Versionspinning
auf v2.31, serverseitige Mod-Paritätsprüfung), ändert das nichts — die
tragenden Fakten stehen auf der hohen Quellenklasse. Die mittel/niedrig
eingestuften Punkte sind dort markiert, wo sie im Bericht auftauchen.

## Ehrliche Einordnung der Abdeckung

Der Workflow hat den Auftrag aus `2026-07-13-viability-and-feel-research-prompt.md`
(6 Fragenblöcke, 7 Deliverables) **nicht vollständig** in der Tiefe abgedeckt,
die die manuelle 5-Agenten-Recherche zur Architektur letzte Woche erreicht
hat — er hat automatisch nur 5 Suchwinkel gebildet und ist bei 7 final
verifizierten Kernbefunden gelandet. Stark abgedeckt: Patch-Resilienz,
Onboarding-Reibung, rechtliches Präzedenzrisiko (GTA-Seite), Community-
Reputationsrisiko. **Dünn/unzureichend abgedeckt:** konkrete Netcode-Feel-
Parameter (die Source-Engine-100ms-Interp-Quelle fiel bei der Verifikation
durch — als "unreliable" markiert, 0 Behauptungen überlebten), CDPR-
spezifische rechtliche Haltung (nur GTA/Take-Two-Präzedenzfälle gefunden,
nichts direkt zu Cyberpunk 2077), Solo-Dev-Scope-Disziplin/Funding-Modelle
über den Skyrim-Together-Fall hinaus, und die geforderte "Warum-Projekte-
sterben"-Liste blieb unvollständig. Ich markiere unten explizit, was
belastbar ist und wo eine gezielte Nachrecherche sich lohnt.

---

## Bestätigte Kernbefunde (hohe/mittlere Konfidenz, Quellen verifiziert)

1. **Patch-Kompatibilität ist strukturell reaktiv und unregelmäßig getaktet.**
   RED4ext v1.29.0 (Sept. 2025) kam gezielt für CP2077-Patch 2.31+; zwischen
   manchen Kompatibilitäts-Releases lagen ~6 Monate (v1.27.0→v1.28.0: 175
   Tage; v1.29.1→v1.30.0: ~5,9 Monate), neben auch schnellen Same-Day-Fixes.
   **Projektentscheidung (2026-07-13, Auftraggeber):** ChoomLink pinnt sich
   auf v2.31 (der heutige Start-Build) und ist NICHT verpflichtet, neuen
   CP2077-Patches hinterherzuziehen — dieselbe Strategie, die FiveM mit
   festen GTA-Builds fährt. Damit wird die Patch-Lag von einem wiederkehrenden
   Überlebensrisiko zu einer bewussten, einmaligen Wahl. Verbleibende
   Konsequenzen: (a) Tester müssen Auto-Updates verhindern bzw. den
   gepinnten Build behalten können (GOG macht Rollback leicht, Steam braucht
   Depot-Tricks — gehört ins Onboarding), (b) der Server sollte die
   Client-Spielversion beim Join prüfen (gleiche Kick-bei-Mismatch-Logik wie
   Befund 4), (c) ein späterer Versionssprung ist ein geplantes Projekt, kein
   Zwang. *(Quelle: github.com/WopsS/RED4ext/releases — primär, hohe Konfidenz)*

2. **Steam Workshops "Enable Game Branch Versions"** ist ein offizieller,
   aber für Cyberpunk 2077 nicht direkt nutzbarer Mechanismus, um Mod-
   Versionen an Spiel-Versionen zu binden — als Muster relevant: Mod-Version
   ↔ Spiel-Patch explizit koppeln und kommunizieren, auch ohne Workshop.
   *(pcguide.com + partner.steamgames.com — hohe Konfidenz)*

3. **Selbst die beste Distributions-Tooling-Klasse (Wabbajack, r2modman)
   löst Onboarding-Reibung nicht vollständig.** Wabbajack braucht offiziell
   dokumentiert 7–10 Schritte und "Minuten bis Stunden" für die Erstinstallation,
   trotz Manifest-System und One-Click-Ambition. r2modman/Thunderstore ist
   im Vergleich deutlich leichter (One-Click Install/Enable/Disable, Profil-
   Export). **Lektion:** ein ChoomLink-Installer sollte sich eher am
   r2modman/Thunderstore-Modell orientieren (leichtgewichtiger Modmanager +
   Profile) als am Wabbajack-Modell (schweres Gesamtpaket) — Ersteres passt
   besser zu "einfach überschaubar", was du für die Architektur-Seite auch
   priorisiert hast.
   *(wabbajack.org, wiki.wabbajack.org, github.com/ebkr/r2modmanPlus — hohe
   Konfidenz)*

4. **Mod-Listen-Parität wird serverseitig per Kick-bei-Mismatch durchgesetzt**
   — der bewährte Mechanismus bei Skyrim Together Reborn (nur 3 offiziell
   kompatible Mods: SKSE, Address Library, SkyUI; alles andere auf eigenes
   Risiko, gameplay-verändernde Mods nicht unterstützt). Server validiert
   Load-Order/Modliste und kickt bei Abweichung.
   **Direkt übertragbar:** ChoomLink sollte früh eine serverseitige Mod-
   Whitelist/Hash-Prüfung einplanen, nicht Client-Selbstauskunft vertrauen —
   deckt sich mit dem "nie dem Client vertrauen"-Prinzip aus der Architektur-
   Recherche.
   *(gamerevolution.com — hohe Konfidenz)*

5. **Das größte externe Risiko ist rechtliche Durchsetzung durch den
   Publisher, nicht technisches Versagen.** Take-Two hat 2026 sowohl alt:V
   (Cease-and-Desist März 2026, wirksam 6. Juli 2026) als auch RAGE:MP (288
   Server, Shutdown bis 31. August 2026) abgeschaltet und GTA-V-Multiplayer-
   Modding auf das eigene FiveM konsolidiert (Platform Licensing Agreement).
   **Wichtige Einschränkung:** das betrifft GTA V/Take-Two, nicht CDPR/
   Cyberpunk 2077 direkt — als Präzedenzfall-Warnung zu lesen, nicht als
   Beweis für CDPRs Haltung. *(5+ unabhängige Quellen: gtaboom.com,
   notebookcheck.net, PC Gamer, Dexerto, Kotaku — hohe Konfidenz für die
   GTA-Fakten; offene Frage für CP2077-Übertragbarkeit, siehe unten)*

6. **Community-/Reputationsfehler haben Multiplayer-Mod-Projekte historisch
   genauso beschädigt wie technische Probleme.** Skyrim Together geriet in
   die Kritik, weil das Team öffentlich sagte, es schulde der Community
   trotz Patreon-Finanzierung nichts — und weil Loader-Code direkt aus SKSE
   übernommen war (später öffentlich entschuldigt und neu geschrieben).
   **Direkte Lehre für ChoomLinks Kommunikationsstil:** Erwartungsmanagement
   und Transparenz zu Alpha-Status sind kein Nice-to-have, sondern historisch
   ein Bruchpunkt für genau diese Projektklasse.
   *(altchar.com, gamedeveloper.com — hohe Konfidenz)*

7. **Overwatchs Command-Frame-Modell** (Client läuft ~halbe Round-Trip-Time
   voraus, Input wird lokal zeitgestempelt) ist die meistzitierte Referenz
   für PvP-Netcode-Feel. **Konfidenz nur mittel** — die einzige überlebende
   Quelle ist ein Blogpost (daposto.medium.com), der Tim Fords GDC-Talk 2017
   zusammenfasst; die Primärquelle (GDC-Talk/Slides) wurde nicht gefunden.
   Zwei verwandte Behauptungen zu einem Open-Source-Referenz-Repo
   (`minism/fps-netcode`) zur Client-Prediction/Reconciliation-Implementierung
   wurden bei der Verifikation **verworfen** (1-2 Stimmen) — die Feel-Technik-
   Ebene bleibt damit die am wenigsten abgesicherte Aussage aus diesem Lauf.

## Verworfene Behauptungen (zur Transparenz)

- Wabbajack als reibungsloses One-Click-Erlebnis (1-2 verworfen — die
  Schrittzahl widerspricht dem)
- Skyrim Together kompatibel mit "allen Creation-Kit-Mods" inkl. SkyUI (0-3
  verworfen — widerspricht Befund 4 oben)
- Bestimmte Engine-Fix-Mods explizit inkompatibel mit Skyrim Together (1-2,
  nicht ausreichend belegt)
- `fps-netcode`-Repo implementiert Client-Prediction (1-2 verworfen)
- `fps-netcode`-Repo implementiert Backwards-Reconciliation/Replay (1-2 verworfen)

## Offene Fragen — Stand nach Nachrecherche

- ~~Hat CD Projekt Red je eine erkennbare Haltung zu inoffiziellen CP2077-
  Multiplayer-Mods geäußert?~~ **Geklärt (negativ): CDPR hat sich nie
  geäußert — siehe Nachrecherche-Abschnitt unten. Track Record ist trotzdem
  aussagekräftig.**
- **Weiterhin offen, braucht einen Menschen:** Primärquelle (Video/Slides)
  für Tim Fords Overwatch-GDC-Talk 2017 — hinter GDC-Vault-Login, von
  automatisierten Tools nicht extrahierbar.
- **Weiterhin offen, braucht einen Menschen:** Valve-Entwicklerwiki
  (`cl_interp`, Lag Compensation) blockiert automatisierte Abrufe komplett
  (HTTP 403) — falls die genauen Source-Engine-Defaultwerte je
  entscheidungsrelevant werden, direkt im Browser nachsehen.
- Wie bildet sich RED4exts mehrmonatige Patch-Lag konkret auf Cyberverses
  eigenen Wartungsaufwand ab? **Entschärft durch die Versionspinning-
  Entscheidung (v2.31) — nicht mehr akut relevant.**

## Nachrecherche (2026-07-13, 3 fokussierte Agenten) — die drei Lücken geschlossen

### CDPRs rechtliche Haltung zu Mods/Multiplayer

**Kein CDPR-Statement zu CyberpunkMP oder Fan-Multiplayer existiert** —
weder positiv noch negativ, trotz dessen mehrjähriger öffentlicher Existenz
(2020 Start, 2024 Alpha, 2025 Beta). Das ist eine echte, bestätigte Lücke,
kein Rechercheversagen — CDPR hat sich dazu schlicht nie geäußert. Alles
andere ist Ableitung aus dem, was CDPR tatsächlich getan hat:

- **Offizielle Fan-Content-Guidelines** (cdprojektred.com/en/fan-content,
  von der EULA referenziert): kein kommerzieller Gebrauch, keine Paywalls,
  optionale Spenden okay, kein CDPR-Branding im Mod-/Projektnamen, Pflicht-
  Disclaimer "unofficial fan work". Nichts davon erwähnt Multiplayer/Server
  spezifisch.
- **REDmod vs. RED4ext/redscript:** CDPRs offizielle Modding-Support-Seite
  dokumentiert nur REDmod — RED4ext/redscript werden nirgends erwähnt, weder
  gutgeheißen noch verboten. Da sie seit Jahren offen existieren, ohne dass
  CDPR je dagegen vorgegangen ist, ist "faktische Duldung durch Nicht-
  Handeln" die einzig belastbare Aussage — keine ausdrückliche Erlaubnis.
- **Track Record im Vergleich zu Take-Two:** CDPRs einzige je dokumentierte
  Mod-Abmahnung (Luke Ross' Cyberpunk-VR-Mod, Januar 2026) war **ausschließlich
  monetarisierungsgetrieben** — Patreon-Paywall — mit explizitem Rückkehr-Weg
  ("mach's kostenlos, dann ist es okay", CDPR-VP Jan Rosner). Für The Witcher 3
  hat CDPR sogar offiziell REDkit nachgeliefert, um Modding zu fördern; keine
  einzige dokumentierte Klage gegen einen Witcher-3-Mod, multiplayer oder
  sonst. Das steht in scharfem Kontrast zu Take-Twos 2026er Kahlschlag gegen
  alt:V/RAGE:MP — dort ging es nicht um Monetarisierung, sondern um die bloße
  Existenz unabhängiger Multiplayer-Plattformen neben dem selbst aufgekauften
  FiveM. **CDPR ist nach den tatsächlichen Vorfällen (nicht nach Ruf)
  nachweislich mod-freundlicher als Take-Two.**
- **Der eine echte Risiko-Punkt:** Die aktuelle EULA (Punkt 24, Steam-EULA
  direkt geprüft) verbietet wörtlich "creation or use of private servers"
  unter der Überschrift Netzwerk-/IT-Interferenz — neben Tunneling und Code-
  Injection. Das ist breit genug formuliert, um wörtlich jeden Fan-Server zu
  treffen, aber der Kontext (zusammen mit Anti-Tamper-Klauseln) deutet eher
  auf Schutz von CDPRs eigener Backend-/Anti-Cheat-Infrastruktur hin — ein
  Standard-Boilerplate-Muster bei Singleplayer-Spielen mit Online-Anteil.
  **CDPR hat diese Klausel nie gegen einen Mod ausgelegt oder durchgesetzt —
  weder bestätigt noch dementiert, dass sie auf Fan-Multiplayer zielt.**

**Verdikt für ChoomLink:** kein Grund zur Panik, aber auch keine Entwarnung.
CDPRs generelle Haltung (nicht-kommerziell, kein Branding-Missbrauch, keine
Paywalls) begünstigt ein Projekt wie ChoomLink stark — solange es genau
diese drei Linien einhält. Die private-Server-Klausel bleibt echtes,
ungetestetes rechtliches Risiko, das durch gutes Verhalten nicht restlos
neutralisiert wird, aber realistisch sehr niedrige Priorität hat, solange
das Projekt klein, kostenlos und branding-sauber bleibt.
*(Konfidenz: hoch für die Fakten selbst — EULA-Text, REDkit-Release, Luke-
Ross-Fall, Take-Two-Kontrast; mittel für die vergleichende Einschätzung, da
sie eine Synthese über zwei verschiedene Firmen ist.)*

### Netcode-Feel-Parameter aus Primärquellen

Diesmal wurden echte Primärquellen direkt abgerufen (nicht nur Blog-
Zusammenfassungen): Gabriel Gambettas Artikelserie (gabrielgambetta.com,
vollständig gefetcht) und Unitys Netcode-for-GameObjects-Doku (vollständig
gefetcht) lieferten belastbare, implementierbare Details. **Die Valve-
Entwicklerwiki-Seiten (`cl_interp`, Lag Compensation) blockierten
automatisierte Abrufe komplett (HTTP 403, zweimal bestätigt)** — jede Zahl
von dort bleibt unverifizierte Sekundärangabe, nicht Fakt. Der Overwatch-
GDC-Talk (Tim Ford, 2017) wurde lokalisiert, aber Inhalt/Zahlen waren mit
verfügbaren Werkzeugen nicht extrahierbar (Video hinter Login) — dieser
Punkt bleibt offen für einen Menschen, der sich das Video selbst ansieht.

**Was verifiziert und direkt übertragbar ist:**
- **Entity-Interpolation für Remote-Entities** (Gambetta, primär, hohe
  Konfidenz): Client puffert mindestens zwei Server-Snapshots und rendert
  Remote-Entities ca. **eine Tick-Periode (~100 ms bei üblichen Setups) in
  der Vergangenheit**, linear zwischen den letzten zwei bekannten Snapshots
  interpoliert. Als "generally imperceptible" für Bewegungsglättung
  dokumentiert. Unitys NGO-Doku bestätigt dasselbe Prinzip wörtlich:
  Clients laufen absichtlich leicht hinter dem Server, damit beim Rendern
  von Zustand n bereits Zustand n+1 vorliegt — Interpolationsverzögerung
  sollte kürzer als das Server-Sendeintervall bleiben, sonst Ruckeln.
- **Client-Side Prediction + Reconciliation** (Gambetta, primär, hohe
  Konfidenz, aber **nicht relevant für Remote-Puppets** — nur falls
  ChoomLink je die Eingaben des lokalen Spielers selbst vorhersagt, bevor
  der Server bestätigt): Sequenznummern pro Input, sofortige lokale
  Anwendung, Server bestätigt letzte verarbeitete Sequenznummer, Client
  verwirft bestätigte Inputs und spielt nur die noch unbestätigten erneut
  ab dem korrigierten Serverzustand ab.
- **Wahrnehmungsschwellen** (ACM-CHI-PLAY-Paper, echte Peer-Review-Quelle,
  DOI vorhanden): erfahrene FPS-Spieler nehmen Latenz ab **~15 ms** wahr,
  Esports-taugliche Systeme zielen auf **unter ~50 ms** Gesamtlatenz. Diese
  Schwellen betreffen aber **Input-zu-Aktion für den eigenen Charakter**,
  nicht wie "laggy" ein Remote-Puppet aussieht — nicht direkt auf euren
  Broadcast-Tuning übertragbar.
- **Riots "Peeker's Advantage"** (Sekundärquelle, mittlere Konfidenz):
  10 ms Unterschied kann bei hohem Skill-Level ein 90/10-Win-Rate-Matchup
  kippen — relevant für spätere Kampf-/Hit-Registration, nicht für
  Lokomotion.

**Konkrete Anwendung auf eure Proxy-Follow-Architektur** (explizit als
Empfehlung, nicht als zitierte Zahl markiert, wo es eine Extrapolation ist):
1. **[belegt]** Puffert/glättet die **Zielposition des Proxys**, nicht nur
   das Puppet — eine Verzögerung von ca. einem Broadcast-Intervall (~100 ms
   bei 10 Hz), bevor der Proxy zur neuen Position teleportiert wird, statt
   sofortigem Snap. Das ist der direkt verteidigbare Transfer aus Gambetta/
   Unity, unabhängig davon, dass `AIFollowTargetCommand` nachgeschaltet ist.
2. **[Extrapolation]** Paket-Verlust-Toleranz: ~2–3 Pakete Puffertiefe als
   Startwert, dann empirisch mit echtem ChoomLink-Traffic nachjustieren —
   die Source-spezifische `cl_interp_ratio`-Zahl (3–4×) konnte diesmal nicht
   verifiziert werden, nicht blind übernehmen.
3. **[Extrapolation]** Distanzbasierte Broadcast-Rate (10 Hz nah, 2–5 Hz
   fern) passt zur ohnehin geplanten Interessens-Management-Phase — keine
   Quelle in diesem Lauf nennt eine distanzgestaffelte Rate konkret, das ist
   Ableitung aus allgemeiner Interest-Management-Praxis.
4. **[Extrapolation, muss im Spiel getestet werden]** Der "harte Snap"-
   Schwellenwert (ab wann der Proxy zum Puppet teleportiert statt sanft
   nachzuziehen) muss empirisch mit dem `ingame-verify`-Skill ermittelt
   werden — keine externe Quelle behandelt `AIFollowTargetCommand`-
   spezifisches Gait-Flapping, das ist eine CP2077-spezifische Eigenheit,
   die niemand sonst dokumentiert.
5. Kampf-/Hit-Registration-Tuning (Riot/Overwatch-Zahlen) explizit **getrennt
   von Lokomotions-Tuning** behandeln — unterschiedliche Subsysteme.

### Solo-Dev-Postmortems jenseits Skyrim Together

Fünf zusätzliche, unabhängige Fälle gefunden (Thorium Mod/Terraria, Fabric/
Minecraft, Nexus Mods, ReShade, ENB, ProjectZomboid, DerangedTeddy/Cities
Skylines II, Calamity Mod) — deutlich breitere Beleglage als der einzelne
Skyrim-Together-Fall zuvor.

**Robust (mehrere unabhängige Quellen stimmen überein):**
- **Dünn schippen, nicht Feature-Vollständigkeit jagen.** Mehrere Indie-
  Multiplayer-Entwickler (Game-Developer-Rundschau 2014) konvergieren:
  Multiplayer nur hinzufügen, wenn essenziell (verdoppelt grob die
  Entwicklungszeit); im Zweifel weglassen; "gut genug" Sync anstreben, nicht
  perfekte — Spieler *glauben*, sie teilen sich eine Welt, kleine
  Abweichungen werden toleriert. Branchenweite Basisrate: 71 % von 24
  untersuchten Postmortems berichten Scope-Probleme.
- **Finanzierung: Tip-Jar ja, Zahl-für-Zugang riskant.** Nexus Mods' eigene
  Richtlinie zieht die klarste dokumentierte Linie: Spenden okay, aber
  Spenden "im Austausch für Dateien/Updates/Hilfe" einfordern oder Early-
  Access gegen Bezahlung anbieten ist ausdrücklich verboten. ReShade und
  tModLoader fahren beide reines "Danke, hier ein kosmetisches Discord-
  Abzeichen"-Modell ohne Gating. ENB Series ist das eine Gegenbeispiel
  (Patreon-gated Early Builds) — genau das, was Nexus' Richtlinie verbietet,
  kein bestätigt sicherer Präzedenzfall.
- **Erste Mitstreiter kommen aus informeller Vorleistung, nicht aus
  offener Rekrutierung.** Thorium Mod (Terraria) und Fabric (Minecraft)
  zeigen dasselbe Muster: Leute, die sich schon unaufgefordert beteiligt
  hatten (Fanart, Wiki-Edits, spontane Beiträge), wurden erst danach formell
  eingeladen — teils über ein Jahr später.
- **Kommunikations-Konsistenz schlägt Frequenz.** Project Zomboids
  Entwickler gingen bewusst von wöchentlich auf zweiwöchentlich zurück, um
  ungestörte Tiefenarbeit zu bekommen. Unregelmäßige Schübe gefolgt von
  Stille lesen sich als Projekt-Aufgabe — ein langsamerer, aber verlässlicher
  Takt schlägt einen schnellen, unregelmäßigen. Nie Termine veröffentlichen,
  die nicht kurzfristig gehalten werden (Star Citizen als warnendes,
  fachfremdes, aber gut belegtes Beispiel).
- **Strukturelle Lösungen schlagen Willenskraft bei Burnout.** Nexus-Mods-
  Gründer Robin Scott gab nach 24 Jahren die Projektleitung komplett ab
  (nicht nur eine Pause) und nannte Burnout explizit als Grund. Cities-
  Skylines-II-Modder DerangedTeddy zog zwei populäre Mods zurück wegen
  community-toxizität, die eigentlich Base-Game-Beschwerden galt — mit
  explizitem öffentlichem Ultimatum als Grenzsetzung. Beides funktionierte;
  informelles Selbstmanagement wird in den Quellen nirgends als Lösung
  genannt.

**Dünn/mit Vorsicht behandeln (Einzelfall oder umstritten):**
- Das "Patch-Chasing-Burnout"-Narrativ (Mod bricht bei jedem Game-Update) —
  weit verbreitete Community-Folklore, aber kaum in Ich-Form dokumentiert.
- Project Zomboids eigene Scope-Geschichte ist in den Quellen selbst
  umstritten — eine Destructoid-Retrospektive argumentiert, der unfokussierte
  Ansatz habe dem Spiel langfristig sogar genützt. Nicht als eindeutigen
  Beleg für "immer Scope kürzen" zitieren.
- Calamity Mods Massenabgang (22+ von 30 Freiwilligen) ist ein dramatischer
  Einzelfall zu Governance-Risiko bei großen Freiwilligen-Teams, kein Muster.
- Early-Access-für-Patreon-Unterstützer (ENB) — ein reales Beispiel existiert,
  läuft aber der einzigen klar dokumentierten Richtlinie (Nexus) zuwider und
  sollte nicht als validierte Praxis gelten.

## Gesamteinordnung

Mit dieser Nachrecherche sind alle drei ursprünglichen Lücken geschlossen —
mit ehrlicher Kennzeichnung, wo die Beleglage stark (CDPR-Kontrast, Nexus-
Finanzierungsrichtlinie, Gambetta/Unity-Interpolation) und wo sie dünn bleibt
(Overwatch-Zahlen unerreichbar, Valve-Wiki blockiert automatisierte Abrufe,
Patch-Chasing-Burnout nur Folklore). Für die zwei verbliebenen echten Lücken
(Overwatch-GDC-Talk-Inhalt, Valve-`cl_interp`-Originalwerte) reicht
automatisierte Recherche nicht — das bräuchte einen Menschen, der sich das
GDC-Video ansieht bzw. developer.valvesoftware.com direkt im Browser öffnet.
