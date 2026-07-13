# ChoomLink — project rules

Project home/planning repo. Code lives in `..\choomlink-core` (fork of TDUniverse/Cyberverse, MIT). Environment record: `docs/ENVIRONMENT.md`. Issue tracking: beans (`beans list`).

## Game process discipline

- **Quit Cyberpunk 2077 as soon as it is no longer needed for the current test** (`Stop-Process -Name Cyberpunk2077`). Same for the Cyberverse server and bot harness when no further test is planned. The game is extremely resource-hungry; leaving it running slows everything else. Exception: the user is actively playing or the next step needs it.
- Launch the game directly (never via Steam UI): `<game>\bin\x64\Cyberpunk2077.exe --cyberverse-server-address=127.0.0.1 --cyberverse-server-port=1337`. Connected clients auto-load the last save.

## Working style

- **No shortcuts — sustainable solutions.** When something misbehaves, don't tune magic constants or fake the effect; find the engine-native mechanism (user rule, applies to everything: "wenn wir eine gute PvP-Erfahrung wollen, können wir uns keine Shortcuts leisten").
- **Willing to throw away already-built work for performance.** If a proven-better architecture requires discarding something already implemented and working (a packet format, a sync model, even a whole subsystem), that's an acceptable cost — a competitive PvP community server prioritizes performance/correctness over sunk cost. Don't let "we already built this" block replacing it with something that scales or performs better.
- **Actively look for better architecture options, and take them when found — evaluated, not reflexive.** When research or hands-on work surfaces a genuinely better approach (proven pattern from a comparable system, evidence from our own tests, a documented engine-native mechanism we missed), adopt it, even if it means reworking or replacing something that already works. This is not a license for wholesale rewrites on a hunch: weigh a change against concrete evidence (benchmarks, cited precedent, a real bottleneck we've actually hit) before switching, the same way the fork-vs-rebuild call was made by evidence, not by "starting over feels cleaner." Prefer the smallest change that captures the improvement over throwing out a working foundation. When a rebuild-the-whole-thing impulse comes up, first ask whether the pain is caused by our own code (fixable by replacing that piece) or by an underlying engine/game constraint (unaffected by a rebuild, since it would resurface regardless of foundation).

- Do verification yourself where possible (see the `ingame-verify` skill): logs, packet counters, screenshot bursts you evaluate visually. Only hand the user what genuinely needs a human (animation feel, gameplay judgment) — and when their impression matters, report what you saw first, then ask what they saw.
- **Pinned game version.** ChoomLink targets CP2077 v2.31 (the build we started on) and is not obligated to chase new game patches — FiveM's fixed-build strategy. A version bump is a deliberate project, never an implicit requirement. Server should reject clients on a different game version.
- Never read tiltedphoques/CyberpunkMP core source (license forbids studying it). **The game's own code is fair game**: CP2077's redscript sources (`<game>\r6\scripts\`, the public decompiled dump), RTTI/NativeDB reflection data, and TweakDB records may be read and studied freely — standard modding practice, and often the fastest way to find the engine-native mechanism.
- New protocol packet = 6 places: shared header + enum, server/Native switch, server/Managed enum/struct/handler, client/red4ext switch, client .reds native declarations, bot harness. Missing the .reds declaration kills the game at startup (UNRESOLVED_METHOD).
