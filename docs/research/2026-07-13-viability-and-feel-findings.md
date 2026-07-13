# Viability & Game-Feel — Deep-Research-Ergebnisse (2026-07-13)

> Ergebnis des `/deep-research`-Workflow-Laufs (5 Suchwinkel, 21 Quellen
> gefetcht, 66 Behauptungen extrahiert, 25 adversarial verifiziert: 20
> bestätigt / 5 verworfen). Quelle: `wf_5f7cc6a3-1fb`.

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

## Offene Fragen (vom Workflow selbst benannt)

- Hat CD Projekt Red je eine erkennbare Haltung zu inoffiziellen CP2077-
  Multiplayer-Mods geäußert (analog zu Take-Twos GTA-V-Durchsetzungsmuster)?
  **Nicht gefunden — echte Lücke, gezielte Nachrecherche empfohlen.**
- Primärquelle (GDC-Talk-Ebene) für Command-Frame-Netcode jenseits des
  einzelnen Blogposts?
- Aktiv gepflegte Open-Source-Referenzimplementierungen für Prediction/
  Reconciliation, die eine Verifikation überstehen?
- Wie bildet sich RED4exts mehrmonatige Patch-Lag konkret auf Cyberverses
  eigenen Wartungsaufwand ab?

## Empfehlung

Dieser Lauf liefert solide, aber lückenhafte Grundlage — stark bei
Onboarding/Distribution und beim rechtlichen Warnsignal, schwach bei
konkreten Feel-Parametern und CDPR-spezifischem Recht. Empfehle eine gezielte
Nachrecherche (2–3 fokussierte Agenten statt eines breiten Fans) speziell zu:
(a) CDPRs dokumentierter Haltung zu Cyberpunk-Mods/REDmod/Multiplayer-Fan-
Content, (b) konkreten, primärquellen-belegten Interpolations-/Prediction-
Parametern aus Shooter-Netcode-Literatur (Gaffer On Games, Valve-Wiki direkt
statt über Sekundärquellen), (c) Solo-Dev-Scope- und Funding-Postmortems
jenseits des Skyrim-Together-Falls.
