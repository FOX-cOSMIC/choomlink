# Frequency Falloff (Phase 2a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distance-tiered update rates — far observers receive position updates at 2 Hz instead of 10 Hz, configurable, server-only.

**Architecture:** `EntityTracker` keeps one update counter per entity; the already-computed observer distance picks a tier divisor; a teleport is sent only when `counter % divisor == 0`. No protocol change.

**Tech Stack:** C# / .NET 9, xUnit (existing test project `server/Managed.Tests`).

**Spec:** `docs/superpowers/specs/2026-07-13-frequency-falloff-design.md`. Code repo: `C:\Users\G4M3R\Programming\choomlink-core`.

## Global Constraints

- Default tiers exactly: (maxDistance 100, divisor 1), (250, 3), (1e9, 5). Validation: non-empty, ascending maxDistance, all divisors >= 1; invalid → warn + default tiers.
- No protocol changes; actions are NOT falloff-filtered; spawn/despawn/hysteresis logic untouched.
- `dotnet` commands need `DOTNET_ROLL_FORWARD=LatestMajor`.

---

### Task 1: FalloffTier config

**Files:**
- Modify: `server/Managed/ServerConfig.cs`
- Modify: `server/Managed.Tests/ServerConfigTests.cs` (add tests)

**Interfaces:**
- Produces: `class FalloffTier { float MaxDistance; int Divisor; }`, `InterestConfig.Falloff` (`List<FalloffTier>`, defaulted). Task 2 consumes.

- [ ] **Step 1: Add failing tests** to `ServerConfigTests.cs`:

```csharp
    [Fact]
    public void Load_MissingFalloff_UsesDefaultTiers()
    {
        var path = WriteTemp("""{ "interest": { "enterRadius": 425.0, "exitRadius": 470.0, "cellSize": 470.0 } }""");
        var config = ServerConfig.Load(path);
        Assert.Equal(3, config.Interest.Falloff.Count);
        Assert.Equal(1, config.Interest.Falloff[0].Divisor);
        Assert.Equal(100.0f, config.Interest.Falloff[0].MaxDistance);
        Assert.Equal(5, config.Interest.Falloff[2].Divisor);
    }

    [Fact]
    public void Load_CustomFalloff_IsRead()
    {
        var path = WriteTemp("""{ "interest": { "falloff": [ { "maxDistance": 50.0, "divisor": 1 }, { "maxDistance": 1e9, "divisor": 10 } ] } }""");
        var config = ServerConfig.Load(path);
        Assert.Equal(2, config.Interest.Falloff.Count);
        Assert.Equal(10, config.Interest.Falloff[1].Divisor);
    }

    [Fact]
    public void Load_UnsortedFalloff_FallsBackToDefaultTiers()
    {
        var path = WriteTemp("""{ "interest": { "falloff": [ { "maxDistance": 250.0, "divisor": 3 }, { "maxDistance": 100.0, "divisor": 1 } ] } }""");
        var config = ServerConfig.Load(path);
        Assert.Equal(3, config.Interest.Falloff.Count); // defaults
    }

    [Fact]
    public void Load_ZeroDivisor_FallsBackToDefaultTiers()
    {
        var path = WriteTemp("""{ "interest": { "falloff": [ { "maxDistance": 1e9, "divisor": 0 } ] } }""");
        var config = ServerConfig.Load(path);
        Assert.Equal(3, config.Interest.Falloff.Count);
        Assert.Equal(1, config.Interest.Falloff[0].Divisor);
    }
```

- [ ] **Step 2: Run** `DOTNET_ROLL_FORWARD=LatestMajor dotnet test server/Managed.Tests` — expect build FAILURE (`Falloff` missing).

- [ ] **Step 3: Implement** in `ServerConfig.cs` — add class and property:

```csharp
public class FalloffTier
{
    public float MaxDistance { get; set; }
    public int Divisor { get; set; }
}
```

In `InterestConfig` add:

```csharp
    public List<FalloffTier> Falloff { get; set; } = DefaultFalloff();

    public static List<FalloffTier> DefaultFalloff() =>
    [
        new FalloffTier { MaxDistance = 100.0f, Divisor = 1 },
        new FalloffTier { MaxDistance = 250.0f, Divisor = 3 },
        new FalloffTier { MaxDistance = 1e9f, Divisor = 5 }
    ];
```

In `ServerConfig.Validate`, after the existing radius check add:

```csharp
        var falloff = config.Interest.Falloff;
        var sorted = falloff.Count > 0;
        for (var t = 0; t < falloff.Count && sorted; t++)
        {
            if (falloff[t].Divisor < 1 || (t > 0 && falloff[t].MaxDistance <= falloff[t - 1].MaxDistance))
            {
                sorted = false;
            }
        }
        if (!sorted)
        {
            Logger.Warn("Invalid falloff tiers (need ascending maxDistance, divisor >= 1) — using defaults");
            config.Interest.Falloff = InterestConfig.DefaultFalloff();
        }
```

- [ ] **Step 4: Run tests** — all pass (24 + 4 new).
- [ ] **Step 5: Commit** `feat(server): configurable falloff tiers`.

---

### Task 2: Tracker falloff logic

**Files:**
- Modify: `server/Managed/Services/EntityTracker.cs`
- Modify: `server/Managed.Tests/EntityTrackerTests.cs` (add tests)

**Interfaces:**
- Consumes: `InterestConfig.Falloff` (Task 1). No new public API.

- [ ] **Step 1: Add failing tests** to `EntityTrackerTests.cs`:

```csharp
    private void Drive(Entity mover, int updates, float step = 0.5f)
    {
        for (var i = 0; i < updates; i++)
        {
            mover.WorldTransform = new Vector3 { x = mover.WorldTransform.x + step, y = mover.WorldTransform.y };
            _tracker.UpdateTrackingOf(mover);
        }
    }

    [Fact]
    public void Falloff_NearObserver_GetsEveryUpdate()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 50f, 0f);
        _tracker.UpdateTrackingOf(mover);
        _sink.Clear();
        Drive(mover, 10);
        Assert.Equal(10, _sink.CountFor(2, EMessageTypeClientbound.TeleportEntity));
    }

    [Fact]
    public void Falloff_MidObserver_GetsRoughlyEveryThird()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 150f, 0f);
        _tracker.UpdateTrackingOf(mover);
        _sink.Clear();
        Drive(mover, 12);
        Assert.Equal(4, _sink.CountFor(2, EMessageTypeClientbound.TeleportEntity));
    }

    [Fact]
    public void Falloff_FarObserver_GetsEveryFifth()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 300f, 0f);
        _tracker.UpdateTrackingOf(mover);
        _sink.Clear();
        Drive(mover, 10);
        Assert.Equal(2, _sink.CountFor(2, EMessageTypeClientbound.TeleportEntity));
    }

    [Fact]
    public void Falloff_MixedObservers_SameStreamDifferentRates()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 50f, 0f);
        AddPlayer(3, 300f, 0f);
        _tracker.UpdateTrackingOf(mover);
        _sink.Clear();
        Drive(mover, 10);
        Assert.Equal(10, _sink.CountFor(2, EMessageTypeClientbound.TeleportEntity));
        Assert.Equal(2, _sink.CountFor(3, EMessageTypeClientbound.TeleportEntity));
    }
```

Note the existing hysteresis test asserts `>= 5` teleports while oscillating at 426-468m — that is far tier (divisor 5) after this change, so it would receive only ~1 of 5. **Update that assertion** to `>= 1` with a comment referencing falloff.

- [ ] **Step 2: Run tests** — new ones FAIL (all observers currently get every update).

- [ ] **Step 3: Implement** in `EntityTracker.cs`:

Add fields:

```csharp
    private readonly Dictionary<ulong, ulong> _updateCounters = new();
    private readonly float[] _falloffMaxDistSq;
    private readonly int[] _falloffDivisors;
```

In the constructor:

```csharp
        _falloffMaxDistSq = config.Falloff.Select(t => t.MaxDistance * t.MaxDistance).ToArray();
        _falloffDivisors = config.Falloff.Select(t => t.Divisor).ToArray();
```

Add helper:

```csharp
    private int DivisorFor(float distSq)
    {
        for (var i = 0; i < _falloffMaxDistSq.Length; i++)
        {
            if (distSq <= _falloffMaxDistSq[i])
            {
                return _falloffDivisors[i];
            }
        }
        return _falloffDivisors[^1];
    }
```

In `UpdateTrackingOf`, increment the counter right after `_grid.Move(entity);`:

```csharp
        var counter = _updateCounters.TryGetValue(entity.NetworkedEntityId, out var c) ? c + 1 : 1;
        _updateCounters[entity.NetworkedEntityId] = counter;
```

Replace the teleport send block ("Position update to everyone still tracking") with:

```csharp
        if (_trackers.TryGetValue(entity.NetworkedEntityId, out var remaining) && remaining.Count > 0)
        {
            var teleport = new TeleportEntity
            {
                networkedEntityId = entity.NetworkedEntityId,
                targetPosition = entity.WorldTransform,
                yaw = entity.Yaw
            };
            foreach (var connectionId in remaining)
            {
                // Frequency falloff: far observers get every Nth update (spec Phase 2a).
                if (_players.ConnectedPlayers.TryGetValue(connectionId, out var observer)
                    && observer.PuppetEntity != null)
                {
                    var distSq = observer.PuppetEntity.WorldTransform.DistanceSquared(entity.WorldTransform);
                    if (counter % (ulong)DivisorFor(distSq) != 0)
                    {
                        continue;
                    }
                }

                _sink.EnqueueMessage(EMessageTypeClientbound.TeleportEntity, connectionId, 1, teleport);
            }
        }
```

In `StopTrackingOf`, add cleanup after `_grid.Remove(entity);`:

```csharp
        _updateCounters.Remove(entity.NetworkedEntityId);
```

- [ ] **Step 4: Run all tests** — expect 32 pass (28 + 4, one adjusted).
- [ ] **Step 5: Commit** `feat(server): distance-tiered update frequency falloff`.

---

### Task 3: Headless verification

- [ ] **Step 1:** Start server (`dotnet run`, `DOTNET_ROLL_FORWARD=LatestMajor`). Observer bot: `--count 1 --pattern circle --center -2102,446,36`. Far bot: `--count 1 --pattern boundary --distance 300 --center -2102,446,36`.
  Expected: observer stats show ~2 teleports/s (was 10 before falloff). Far bot sees observer at ~300m → also ~2/s.
- [ ] **Step 2:** Near regression: `--count 4 --pattern circle` (all within 100m ring? bots circle at radius 5-8m → near tier): each bot ~30 teleports/s (3 peers × 10 Hz), unchanged.
- [ ] **Step 3:** Stop everything (standing rule), record numbers.

### Task 4: In-game regression (ingame-verify skill)

- [ ] Near bots visibly smooth (burst); one bot at ~300m still moves believably for the distance (burst; feel verdict stays with the user). Clean up per standing rule. Record results in the spec, commit, push both repos.

## Self-Review

- Spec coverage: tiers+config (T1), counter+divisor send path (T2), cleanup (T2 step 3), bot measurement + in-game (T3/T4). Actions untouched ✓ (send path for EntityAction is in PlayerPacketHandler, not modified). Hysteresis test adjustment called out explicitly.
- Type consistency: `Falloff`/`FalloffTier`/`DefaultFalloff` names match between T1 and T2; `DivisorFor(float distSq)` compares squared distances against precomputed squared bounds.
- Known judgment call: counter is per entity (all observers share phase) — an observer entering mid-cycle may wait up to `divisor` ticks for its first teleport after spawn; spawn packet carries position, accepted in spec.
