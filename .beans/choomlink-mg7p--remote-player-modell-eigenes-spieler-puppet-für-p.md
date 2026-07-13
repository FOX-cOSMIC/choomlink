---
# choomlink-mg7p
title: 'Remote-Player-Modell: eigenes Spieler-Puppet für PvP-Darstellung (Research + Entwicklung)'
status: todo
type: epic
priority: high
created_at: 2026-07-13T15:42:24Z
updated_at: 2026-07-13T15:42:24Z
---

Erkenntnis aus der Netcode-Diskussion 2026-07-13: AIFollowTargetCommand-Locomotion (Proxy-Follow) trägt Boden-Fortbewegung, aber KEINE PvP-taugliche Darstellung — kein Strafing, keine Zielhaltung, keine Waffe in der Hand. Rust/GTA-Plattformen treiben das Animations-System des Remote-Spielers direkt aus Netzwerkdaten; Cyberpunk hat dafür keine fertige API (Singleplayer-Engine, NPC-Animationsgraphen).

Entscheidung des Auftraggebers: wir bauen ein eigenes Spieler-Modell/Puppet ('fast ein eigener Mod'), weil es für gute PvP-Erfahrung nötig ist. Zweistufig:

1. DEEP-RESEARCH-SPIKE (eigene Session, Brief noch zu schreiben):
   - AnimFeatures/AnimationControllerComponent: Können Puppet-Animationsgraphen direkt mit Bewegungs-/Zustandsparametern gefüttert werden (der Weg der Posing-Mods)?
   - Eigenes .ent/Rig: Was braucht ein Custom-Player-Entity mit spielerähnlichem Animationsgraph (WolvenKit, Archive-Distribution)?
   - Waffe in der Hand: TransactionSystem/Equipment auf Puppets (Gangs machen es nativ vor) — Anknüpfung an Bean choomlink-y9rd (Weapons Sync)
   - Zielhaltung: AI-Aim-/Attack-Kommandos auf Puppets (Upstream experimentierte mit AIMeleeAttackCommand)
   - Strafing/Stances: was geht über AnimFeatures, was braucht echtes Custom-Rig
2. ENTWICKLUNG nach Spike-Befund, phasenweise (Waffe sichtbar -> Zielhaltung -> Bewegungs-Fidelity).

Einordnung: Proxy-Follow bleibt für Phase 1 (Boden-Locomotion) und später für NPCs; für SPIELER-Puppets darf es durch das neue Modell ersetzt werden — explizit okay per CLAUDE.md-Regel 'willing to throw away built work for performance/quality'.
