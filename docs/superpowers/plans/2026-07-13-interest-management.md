# Interest Management (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distance-based interest management (spatial grid + hysteresis) in Server.Managed so position/spawn/action packets only reach players within range.

**Architecture:** New `SpatialGrid` (2D cells, ring-generic query) pre-filters candidates; rewritten `EntityTracker` applies enter/exit hysteresis (425/470), keeps a reverse index (entity → tracking players) for despawn correctness and action routing. Config from `config.json`. No protocol/client changes.

**Tech Stack:** C# / .NET 9 (Server.Managed), xUnit (new test project), C++ (bot-harness pattern extension).

**Spec:** `docs/superpowers/specs/2026-07-13-interest-management-design.md` (choomlink repo). Code repo: `C:\Users\G4M3R\Programming\choomlink-core`.

## Global Constraints

- Defaults exactly: enterRadius 425.0, exitRadius 470.0, cellSize 470.0. Validation: `exitRadius > enterRadius > 0`, `cellSize > 0`; invalid → log warn + all-defaults, server always starts.
- No protocol changes — the 6-place packet checklist must NOT be touched.
- Grid is candidate pre-filter only; exact 3D `DistanceSquared` decides.
- Exit checks run over the reverse index, never over grid candidates (despawn correctness).
- Public tracker API keeps existing names: `UpdateTrackingOf(Entity)`, `StopTrackingOf(Entity)`, `InitialSpawnForPlayer(Player)`, `SetEntityVisibilityFilter`.
- All `dotnet` commands need env `DOTNET_ROLL_FORWARD=LatestMajor` (only runtimes 8/10 installed).
- Commit messages in choomlink-core follow existing style (`feat:`/`test:` prefixes fine), each task commits separately.

---

### Task 1: Test project + ServerConfig

**Files:**
- Create: `server/Managed.Tests/Cyberverse.Server.Tests.csproj`
- Create: `server/Managed.Tests/ServerConfigTests.cs`
- Create: `server/Managed/ServerConfig.cs`

**Interfaces:**
- Produces: `ServerConfig.Load(string path) -> ServerConfig` (static), `ServerConfig.Interest` of type `InterestConfig { float EnterRadius; float ExitRadius; float CellSize; }` — Task 3 consumes `InterestConfig`, Task 4 consumes `Load`.

- [ ] **Step 1: Create the test project**

`server/Managed.Tests/Cyberverse.Server.Tests.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
    <RootNamespace>Cyberverse.Server.Tests</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.11.1" />
    <PackageReference Include="xunit" Version="2.9.2" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\Managed\Cyberverse.Server.csproj" />
  </ItemGroup>

</Project>
```

Note: referencing the server project pulls in the P/Invoke layer as code, but tests never call `Native.*`, so no native DLL is needed at test time.

- [ ] **Step 2: Write the failing tests**

`server/Managed.Tests/ServerConfigTests.cs`:

```csharp
using Cyberverse.Server;
using Xunit;

namespace Cyberverse.Server.Tests;

public class ServerConfigTests
{
    [Fact]
    public void Load_MissingFile_ReturnsDefaults()
    {
        var config = ServerConfig.Load(Path.Combine(Path.GetTempPath(), $"does-not-exist-{Guid.NewGuid()}.json"));
        Assert.Equal(425.0f, config.Interest.EnterRadius);
        Assert.Equal(470.0f, config.Interest.ExitRadius);
        Assert.Equal(470.0f, config.Interest.CellSize);
    }

    [Fact]
    public void Load_ValidFile_ReadsValues()
    {
        var path = WriteTemp("""{ "interest": { "enterRadius": 200.0, "exitRadius": 240.0, "cellSize": 240.0 } }""");
        var config = ServerConfig.Load(path);
        Assert.Equal(200.0f, config.Interest.EnterRadius);
        Assert.Equal(240.0f, config.Interest.ExitRadius);
    }

    [Fact]
    public void Load_ExitNotGreaterThanEnter_FallsBackToDefaults()
    {
        var path = WriteTemp("""{ "interest": { "enterRadius": 400.0, "exitRadius": 400.0, "cellSize": 470.0 } }""");
        var config = ServerConfig.Load(path);
        Assert.Equal(425.0f, config.Interest.EnterRadius);
        Assert.Equal(470.0f, config.Interest.ExitRadius);
    }

    [Fact]
    public void Load_MalformedJson_FallsBackToDefaults()
    {
        var path = WriteTemp("{ not json ");
        var config = ServerConfig.Load(path);
        Assert.Equal(425.0f, config.Interest.EnterRadius);
    }

    private static string WriteTemp(string content)
    {
        var path = Path.Combine(Path.GetTempPath(), $"choomlink-test-{Guid.NewGuid()}.json");
        File.WriteAllText(path, content);
        return path;
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run (from `choomlink-core`): `DOTNET_ROLL_FORWARD=LatestMajor dotnet test server/Managed.Tests`
Expected: build FAILURE — `ServerConfig` does not exist.

- [ ] **Step 4: Implement ServerConfig**

`server/Managed/ServerConfig.cs`:

```csharp
using System.Text.Json;
using NLog;

namespace Cyberverse.Server;

public class InterestConfig
{
    public float EnterRadius { get; set; } = 425.0f;
    public float ExitRadius { get; set; } = 470.0f;
    public float CellSize { get; set; } = 470.0f;
}

public class ServerConfig
{
    private static readonly Logger Logger = LogManager.GetCurrentClassLogger();

    public InterestConfig Interest { get; set; } = new();

    public static ServerConfig Load(string path)
    {
        ServerConfig? config = null;
        try
        {
            if (File.Exists(path))
            {
                config = JsonSerializer.Deserialize<ServerConfig>(File.ReadAllText(path),
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            }
            else
            {
                Logger.Info("No config.json found at {0}, using defaults", path);
            }
        }
        catch (Exception e)
        {
            Logger.Warn(e, "config.json could not be read, using defaults");
        }

        return Validate(config ?? new ServerConfig());
    }

    private static ServerConfig Validate(ServerConfig config)
    {
        var i = config.Interest;
        if (i.EnterRadius <= 0 || i.ExitRadius <= i.EnterRadius || i.CellSize <= 0)
        {
            Logger.Warn("Invalid interest config (need exitRadius > enterRadius > 0, cellSize > 0) — using defaults");
            config.Interest = new InterestConfig();
        }
        return config;
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `DOTNET_ROLL_FORWARD=LatestMajor dotnet test server/Managed.Tests`
Expected: 4 passed.

- [ ] **Step 6: Commit**

```bash
git add server/Managed.Tests server/Managed/ServerConfig.cs
git commit -m "feat(server): config file with interest-management settings + first test project"
```

---

### Task 2: SpatialGrid

**Files:**
- Create: `server/Managed/Services/SpatialGrid.cs`
- Create: `server/Managed.Tests/SpatialGridTests.cs`

**Interfaces:**
- Consumes: `Entity` (`Types/Entity.cs`: `ulong NetworkedEntityId`, `Vector3 WorldTransform`), `Vector3` (`NativeLayer/Protocol/Common`).
- Produces: `SpatialGrid(float cellSize)`, `void Move(Entity)` (upsert — first call inserts), `void Remove(Entity)`, `IEnumerable<Entity> QueryCandidates(Vector3 position, float radius)`. Task 3 consumes all four.

- [ ] **Step 1: Write the failing tests**

`server/Managed.Tests/SpatialGridTests.cs`:

```csharp
using Cyberverse.Server.NativeLayer.Protocol.Common;
using Cyberverse.Server.Services;
using Cyberverse.Server.Types;
using Xunit;

namespace Cyberverse.Server.Tests;

public class SpatialGridTests
{
    private static Entity MakeEntity(ulong id, float x, float y, float z = 0f)
    {
        return new Entity(id, recordId: 1) { WorldTransform = new Vector3 { x = x, y = y, z = z } };
    }

    [Fact]
    public void Query_FindsEntityInSameCell()
    {
        var grid = new SpatialGrid(470f);
        var e = MakeEntity(1, 10f, 10f);
        grid.Move(e);
        Assert.Contains(e, grid.QueryCandidates(new Vector3 { x = 50f, y = 50f }, 470f));
    }

    [Fact]
    public void Query_FindsEntityInNeighborCell()
    {
        var grid = new SpatialGrid(470f);
        var e = MakeEntity(1, 460f, 0f);          // cell (0,0)
        grid.Move(e);
        var candidates = grid.QueryCandidates(new Vector3 { x = 480f, y = 0f }, 470f); // query from cell (1,0)
        Assert.Contains(e, candidates);
    }

    [Fact]
    public void Query_RadiusLargerThanCell_SearchesEnoughRings()
    {
        var grid = new SpatialGrid(100f);          // small cells, radius 470 -> 5 rings
        var e = MakeEntity(1, 450f, 0f);           // cell (4,0), 450m away
        grid.Move(e);
        Assert.Contains(e, grid.QueryCandidates(new Vector3 { x = 0f, y = 0f }, 470f));
    }

    [Fact]
    public void Query_CompletenessProperty_AllEntitiesWithinRadiusAreCandidates()
    {
        var grid = new SpatialGrid(470f);
        var rng = new Random(1337);
        var entities = new List<Entity>();
        for (ulong i = 0; i < 200; i++)
        {
            var e = MakeEntity(i, (float)(rng.NextDouble() * 4000 - 2000), (float)(rng.NextDouble() * 4000 - 2000));
            entities.Add(e);
            grid.Move(e);
        }

        var origin = new Vector3 { x = 123f, y = -456f };
        const float radius = 470f;
        var candidates = grid.QueryCandidates(origin, radius).ToHashSet();
        foreach (var e in entities.Where(e => e.WorldTransform.DistanceSquared(origin) <= radius * radius))
        {
            Assert.Contains(e, candidates);
        }
    }

    [Fact]
    public void Move_AcrossCellBoundary_LeavesOldCell()
    {
        var grid = new SpatialGrid(470f);
        var e = MakeEntity(1, 10f, 10f);
        grid.Move(e);
        e.WorldTransform = new Vector3 { x = 2000f, y = 2000f };
        grid.Move(e);
        Assert.DoesNotContain(e, grid.QueryCandidates(new Vector3 { x = 10f, y = 10f }, 470f));
        Assert.Contains(e, grid.QueryCandidates(new Vector3 { x = 2000f, y = 2000f }, 470f));
    }

    [Fact]
    public void Move_EntityExactlyOnCellEdge_IsDeterministicAndFound()
    {
        var grid = new SpatialGrid(470f);
        var e = MakeEntity(1, 470f, 0f);           // exactly on the boundary
        grid.Move(e);
        Assert.Contains(e, grid.QueryCandidates(new Vector3 { x = 470f, y = 0f }, 470f));
    }

    [Fact]
    public void Remove_EntityIsGone()
    {
        var grid = new SpatialGrid(470f);
        var e = MakeEntity(1, 10f, 10f);
        grid.Move(e);
        grid.Remove(e);
        Assert.DoesNotContain(e, grid.QueryCandidates(new Vector3 { x = 10f, y = 10f }, 470f));
    }

    [Fact]
    public void Remove_UnknownEntity_DoesNotThrow()
    {
        var grid = new SpatialGrid(470f);
        grid.Remove(MakeEntity(99, 0f, 0f));
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DOTNET_ROLL_FORWARD=LatestMajor dotnet test server/Managed.Tests`
Expected: build FAILURE — `SpatialGrid` does not exist.

- [ ] **Step 3: Implement SpatialGrid**

`server/Managed/Services/SpatialGrid.cs`:

```csharp
using Cyberverse.Server.NativeLayer.Protocol.Common;
using Cyberverse.Server.Types;

namespace Cyberverse.Server.Services;

/// <summary>
/// 2D cell grid over the world (x/y; height stays out of the cell structure — Night City is
/// horizontally huge but only ~200m tall). Pure candidate pre-filter: correctness always
/// comes from the exact 3D distance check done by the caller, never from cell geometry.
/// Ring-generic query so cellSize is a free tuning parameter (see spec).
/// </summary>
public class SpatialGrid
{
    private readonly float _cellSize;
    private readonly Dictionary<(int x, int y), HashSet<Entity>> _cells = new();
    private readonly Dictionary<ulong, (int x, int y)> _entityCells = new();

    public SpatialGrid(float cellSize)
    {
        _cellSize = cellSize;
    }

    private (int x, int y) CellOf(Vector3 position)
    {
        return ((int)MathF.Floor(position.x / _cellSize), (int)MathF.Floor(position.y / _cellSize));
    }

    /// Upsert: first call inserts, later calls migrate on cell change (cheap no-op otherwise).
    public void Move(Entity entity)
    {
        var cell = CellOf(entity.WorldTransform);
        if (_entityCells.TryGetValue(entity.NetworkedEntityId, out var oldCell))
        {
            if (oldCell == cell)
            {
                return;
            }

            RemoveFromCell(entity, oldCell);
        }

        if (!_cells.TryGetValue(cell, out var set))
        {
            set = new HashSet<Entity>();
            _cells.Add(cell, set);
        }

        set.Add(entity);
        _entityCells[entity.NetworkedEntityId] = cell;
    }

    public void Remove(Entity entity)
    {
        if (_entityCells.Remove(entity.NetworkedEntityId, out var cell))
        {
            RemoveFromCell(entity, cell);
        }
    }

    private void RemoveFromCell(Entity entity, (int x, int y) cell)
    {
        if (_cells.TryGetValue(cell, out var set))
        {
            set.Remove(entity);
            if (set.Count == 0)
            {
                _cells.Remove(cell);
            }
        }
    }

    public IEnumerable<Entity> QueryCandidates(Vector3 position, float radius)
    {
        var center = CellOf(position);
        var rings = (int)MathF.Ceiling(radius / _cellSize);
        for (var dx = -rings; dx <= rings; dx++)
        {
            for (var dy = -rings; dy <= rings; dy++)
            {
                if (!_cells.TryGetValue((center.x + dx, center.y + dy), out var set))
                {
                    continue;
                }

                foreach (var entity in set)
                {
                    yield return entity;
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `DOTNET_ROLL_FORWARD=LatestMajor dotnet test server/Managed.Tests`
Expected: all pass (Task 1's 4 + these 8).

- [ ] **Step 5: Commit**

```bash
git add server/Managed/Services/SpatialGrid.cs server/Managed.Tests/SpatialGridTests.cs
git commit -m "feat(server): spatial grid with ring-generic candidate query"
```

---

### Task 3: EntityTracker rewrite (hysteresis + reverse index)

**Files:**
- Create: `server/Managed/IPacketSink.cs`
- Modify: `server/Managed/Types/Player.cs` (add puppet reference)
- Modify: `server/Managed/Services/EntityTracker.cs` (rewrite)
- Create: `server/Managed.Tests/EntityTrackerTests.cs`

**Interfaces:**
- Consumes: `SpatialGrid` (Task 2), `InterestConfig` (Task 1), `PlayerService` (existing: `Dictionary<uint, Player> ConnectedPlayers`).
- Produces (Task 4 consumes):
  - `interface IPacketSink { void EnqueueMessage<T>(EMessageTypeClientbound messageType, uint connectionId, byte channelId, T content) where T : struct; }` — `GameServer` already has exactly this method signature and just declares the interface.
  - `EntityTracker(IPacketSink sink, PlayerService players, SpatialGrid grid, InterestConfig config)`
  - Kept API: `UpdateTrackingOf(Entity)`, `StopTrackingOf(Entity)`, `InitialSpawnForPlayer(Player)`, `SetEntityVisibilityFilter(EntityVisibilityFilter?)`
  - New: `IReadOnlyCollection<uint> GetPlayersTracking(ulong entityId)`, `void OnPlayerDisconnected(uint connectionId)`
  - `Player.PuppetEntity` (`Entity?`) — set by `HandleJoinWorld` in Task 4; the tracker uses it as the viewer position (replaces the per-player LINQ scan).

- [ ] **Step 1: Add IPacketSink**

`server/Managed/IPacketSink.cs`:

```csharp
using Cyberverse.Server.NativeLayer.Protocol.Clientbound;

namespace Cyberverse.Server;

/// <summary>
/// The one seam between game logic and the native transport. GameServer implements it with
/// its existing EnqueueMessage; tests implement it with a recording fake.
/// </summary>
public interface IPacketSink
{
    void EnqueueMessage<T>(EMessageTypeClientbound messageType, uint connectionId, byte channelId, T content)
        where T : struct;
}
```

- [ ] **Step 2: Add Player.PuppetEntity**

In `server/Managed/Types/Player.cs`, add to the class body:

```csharp
    /// <summary>
    /// The player's own puppet entity (set on JoinWorld). Used as the viewer position for
    /// interest management. Null until the player has joined the world.
    /// </summary>
    public Entity? PuppetEntity;
```

(Requires `using Cyberverse.Server.Types;` — same namespace, no using needed.)

- [ ] **Step 3: Write the failing tests**

`server/Managed.Tests/EntityTrackerTests.cs`:

```csharp
using Cyberverse.Server;
using Cyberverse.Server.NativeLayer.Protocol.Clientbound;
using Cyberverse.Server.NativeLayer.Protocol.Common;
using Cyberverse.Server.Services;
using Cyberverse.Server.Types;
using Xunit;

namespace Cyberverse.Server.Tests;

file sealed class RecordingSink : IPacketSink
{
    public readonly List<(EMessageTypeClientbound type, uint connectionId, object content)> Sent = new();

    public void EnqueueMessage<T>(EMessageTypeClientbound messageType, uint connectionId, byte channelId, T content)
        where T : struct
    {
        Sent.Add((messageType, connectionId, content));
    }

    public int CountFor(uint connectionId, EMessageTypeClientbound type)
        => Sent.Count(s => s.connectionId == connectionId && s.type == type);

    public void Clear() => Sent.Clear();
}

public class EntityTrackerTests
{
    private readonly RecordingSink _sink = new();
    private readonly PlayerService _players = new();
    private readonly SpatialGrid _grid = new(470f);
    private readonly EntityTracker _tracker;

    public EntityTrackerTests()
    {
        _tracker = new EntityTracker(_sink, _players, _grid,
            new InterestConfig { EnterRadius = 425f, ExitRadius = 470f, CellSize = 470f });
    }

    private (Player player, Entity puppet) AddPlayer(uint connectionId, float x, float y)
    {
        var puppet = new Entity(connectionId * 1000, recordId: 1)
        {
            NetworkIdOwner = connectionId,
            WorldTransform = new Vector3 { x = x, y = y }
        };
        var player = new Player { ConnectionId = connectionId, Name = $"p{connectionId}", PuppetEntity = puppet };
        _players.ConnectedPlayers.Add(connectionId, player);
        _grid.Move(puppet);
        return (player, puppet);
    }

    [Fact]
    public void EnterRadius_SpawnsExactlyOnce()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 400f, 0f); // within 425
        _tracker.UpdateTrackingOf(mover);
        Assert.Equal(1, _sink.CountFor(2, EMessageTypeClientbound.SpawnEntity));
        _tracker.UpdateTrackingOf(mover); // same position again
        Assert.Equal(1, _sink.CountFor(2, EMessageTypeClientbound.SpawnEntity));
    }

    [Fact]
    public void OutsideEnterRadius_NoSpawn_NoTeleport()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 450f, 0f); // between enter and exit, never tracked before
        _tracker.UpdateTrackingOf(mover);
        Assert.Equal(0, _sink.CountFor(2, EMessageTypeClientbound.SpawnEntity));
        Assert.Equal(0, _sink.CountFor(2, EMessageTypeClientbound.TeleportEntity));
    }

    [Fact]
    public void Hysteresis_OscillatingInsideBand_NoRepeatedSpawnDespawn()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 400f, 0f);
        _tracker.UpdateTrackingOf(mover); // tracked now (400 <= 425)
        _sink.Clear();

        foreach (var x in new[] { 440f, 465f, 430f, 468f, 426f })
        {
            mover.WorldTransform = new Vector3 { x = x, y = 0f };
            _tracker.UpdateTrackingOf(mover);
        }

        Assert.Equal(0, _sink.CountFor(2, EMessageTypeClientbound.SpawnEntity));
        Assert.Equal(0, _sink.CountFor(2, EMessageTypeClientbound.DestroyEntity));
        Assert.True(_sink.CountFor(2, EMessageTypeClientbound.TeleportEntity) >= 5); // still synced
    }

    [Fact]
    public void BeyondExitRadius_DespawnsExactlyOnce()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 400f, 0f);
        _tracker.UpdateTrackingOf(mover);
        _sink.Clear();

        mover.WorldTransform = new Vector3 { x = 480f, y = 0f }; // > 470 from p2? p2 is at 400 -> dist 80. Use far jump:
        mover.WorldTransform = new Vector3 { x = 5000f, y = 0f };
        _tracker.UpdateTrackingOf(mover);
        Assert.Equal(1, _sink.CountFor(2, EMessageTypeClientbound.DestroyEntity));
        _tracker.UpdateTrackingOf(mover);
        Assert.Equal(1, _sink.CountFor(2, EMessageTypeClientbound.DestroyEntity));
    }

    [Fact]
    public void FarJumpBeyondQueryRadius_TrackersStillGetDespawn_ReverseIndexConsistent()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 100f, 0f);
        _tracker.UpdateTrackingOf(mover);
        Assert.Contains(2u, _tracker.GetPlayersTracking(mover.NetworkedEntityId));
        _sink.Clear();

        mover.WorldTransform = new Vector3 { x = 100000f, y = 100000f }; // many cells away
        _tracker.UpdateTrackingOf(mover);

        Assert.Equal(1, _sink.CountFor(2, EMessageTypeClientbound.DestroyEntity));
        Assert.Empty(_tracker.GetPlayersTracking(mover.NetworkedEntityId));
    }

    [Fact]
    public void MoverApproachesRestingEntity_MoverStartsTrackingIt()
    {
        // Weakness 6 from the spec: viewer moves, target rests.
        var (_, mover) = AddPlayer(1, 5000f, 0f);
        var (_, resting) = AddPlayer(2, 0f, 0f);
        _tracker.UpdateTrackingOf(mover);
        Assert.Equal(0, _sink.CountFor(1, EMessageTypeClientbound.SpawnEntity));

        mover.WorldTransform = new Vector3 { x = 100f, y = 0f };
        _tracker.UpdateTrackingOf(mover); // ONLY the mover updates — resting entity never does
        Assert.Equal(1, _sink.CountFor(1, EMessageTypeClientbound.SpawnEntity)); // mover now sees resting puppet
    }

    [Fact]
    public void ActionRouting_GetPlayersTracking_OnlyNearbyPlayers()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 100f, 0f);
        AddPlayer(3, 10000f, 0f);
        _tracker.UpdateTrackingOf(mover);

        var trackers = _tracker.GetPlayersTracking(mover.NetworkedEntityId);
        Assert.Contains(2u, trackers);
        Assert.DoesNotContain(3u, trackers);
    }

    [Fact]
    public void Disconnect_CleansBothIndexDirections()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        var (p2, puppet2) = AddPlayer(2, 100f, 0f);
        _tracker.UpdateTrackingOf(mover);
        _tracker.UpdateTrackingOf(puppet2);

        _tracker.OnPlayerDisconnected(2);
        _tracker.StopTrackingOf(puppet2);
        _players.ConnectedPlayers.Remove(2);

        Assert.DoesNotContain(2u, _tracker.GetPlayersTracking(mover.NetworkedEntityId));
        Assert.Empty(_tracker.GetPlayersTracking(puppet2.NetworkedEntityId));
    }

    [Fact]
    public void StopTrackingOf_SendsDespawnToAllTrackersAndRemovesFromGrid()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 100f, 0f);
        _tracker.UpdateTrackingOf(mover);
        _sink.Clear();

        _tracker.StopTrackingOf(mover);
        Assert.Equal(1, _sink.CountFor(2, EMessageTypeClientbound.DestroyEntity));
        Assert.DoesNotContain(mover, _grid.QueryCandidates(new Vector3 { x = 0f, y = 0f }, 470f));
    }

    [Fact]
    public void VisibilityFilter_StillRespected()
    {
        var (_, mover) = AddPlayer(1, 0f, 0f);
        AddPlayer(2, 100f, 0f);
        _tracker.SetEntityVisibilityFilter((_, _) => false);
        _tracker.UpdateTrackingOf(mover);
        Assert.Equal(0, _sink.CountFor(2, EMessageTypeClientbound.SpawnEntity));
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `DOTNET_ROLL_FORWARD=LatestMajor dotnet test server/Managed.Tests`
Expected: build FAILURE — `EntityTracker` has no such constructor / `GetPlayersTracking` missing.

- [ ] **Step 5: Rewrite EntityTracker**

Replace the entire content of `server/Managed/Services/EntityTracker.cs`:

```csharp
using Cyberverse.Server.NativeLayer.Protocol.Clientbound;
using Cyberverse.Server.Types;

namespace Cyberverse.Server.Services;

/// <summary>
/// Distance-based interest management with hysteresis (spec:
/// choomlink/docs/superpowers/specs/2026-07-13-interest-management-design.md).
/// Enter checks run over spatial-grid candidates; exit checks run over the reverse index,
/// because a player who left the query radius never shows up among the candidates again.
/// </summary>
public class EntityTracker
{
    public delegate bool EntityVisibilityFilter(Player player, Entity entity);

    private readonly IPacketSink _sink;
    private readonly PlayerService _players;
    private readonly SpatialGrid _grid;
    private readonly InterestConfig _config;

    // player -> entities they track, and entity -> players tracking it. Kept in sync exclusively
    // by OnStartTrackingEntity/OnStopTrackingEntity.
    private readonly Dictionary<uint, HashSet<ulong>> _trackedEntities = new();
    private readonly Dictionary<ulong, HashSet<uint>> _trackers = new();

    private EntityVisibilityFilter? _visibilityFilter;

    public EntityTracker(IPacketSink sink, PlayerService players, SpatialGrid grid, InterestConfig config)
    {
        _sink = sink;
        _players = players;
        _grid = grid;
        _config = config;
    }

    public void SetEntityVisibilityFilter(EntityVisibilityFilter? filter)
    {
        _visibilityFilter = filter;
    }

    public IReadOnlyCollection<uint> GetPlayersTracking(ulong entityId)
    {
        return _trackers.TryGetValue(entityId, out var set) ? set : [];
    }

    public void UpdateTrackingOf(Entity entity)
    {
        _grid.Move(entity);

        // Enter side: players whose puppet is a grid candidate around the moved entity.
        foreach (var candidate in _grid.QueryCandidates(entity.WorldTransform, _config.EnterRadius))
        {
            var viewer = ViewerOf(candidate);
            if (viewer == null || viewer.ConnectionId == entity.NetworkIdOwner)
            {
                continue;
            }

            ConsiderPair(viewer, entity);
        }

        // Exit side MUST use the reverse index (see class doc).
        if (_trackers.TryGetValue(entity.NetworkedEntityId, out var trackers))
        {
            foreach (var connectionId in trackers.ToArray())
            {
                if (!_players.ConnectedPlayers.TryGetValue(connectionId, out var player))
                {
                    continue; // disconnect cleanup happens via OnPlayerDisconnected
                }

                ConsiderPair(player, entity);
            }
        }

        // Position update to everyone still tracking.
        if (_trackers.TryGetValue(entity.NetworkedEntityId, out var remaining))
        {
            var teleport = new TeleportEntity
            {
                networkedEntityId = entity.NetworkedEntityId,
                targetPosition = entity.WorldTransform,
                yaw = entity.Yaw
            };
            foreach (var connectionId in remaining)
            {
                _sink.EnqueueMessage(EMessageTypeClientbound.TeleportEntity, connectionId, 1, teleport);
            }
        }

        // Mover's own view (spec weakness 6): when a player's puppet moves, re-evaluate what
        // that player sees — a resting entity never triggers its own UpdateTrackingOf.
        if (entity.NetworkIdOwner != 0 && !entity.IsVehicle
            && _players.ConnectedPlayers.TryGetValue((uint)entity.NetworkIdOwner, out var owner)
            && ReferenceEquals(owner.PuppetEntity, entity))
        {
            foreach (var other in _grid.QueryCandidates(entity.WorldTransform, _config.EnterRadius))
            {
                if (other.NetworkIdOwner == entity.NetworkIdOwner)
                {
                    continue;
                }

                ConsiderPair(owner, other);
            }
        }
    }

    /// Applies enter/exit hysteresis for one (player, entity) pair. Which radius applies is
    /// decided by the pair's current tracked state.
    private void ConsiderPair(Player player, Entity entity)
    {
        if (player.PuppetEntity == null)
        {
            return; // not in the world yet
        }

        if (_visibilityFilter != null && !_visibilityFilter.Invoke(player, entity))
        {
            OnStopTrackingEntity(player, entity);
            return;
        }

        var distSq = player.PuppetEntity.WorldTransform.DistanceSquared(entity.WorldTransform);
        var isTracked = _trackedEntities.TryGetValue(player.ConnectionId, out var set)
                        && set.Contains(entity.NetworkedEntityId);

        if (!isTracked && distSq <= _config.EnterRadius * _config.EnterRadius)
        {
            OnStartTrackingEntity(player, entity);
        }
        else if (isTracked && distSq > _config.ExitRadius * _config.ExitRadius)
        {
            OnStopTrackingEntity(player, entity);
        }
    }

    private Player? ViewerOf(Entity candidate)
    {
        if (candidate.NetworkIdOwner == 0 || candidate.IsVehicle)
        {
            return null;
        }

        _players.ConnectedPlayers.TryGetValue((uint)candidate.NetworkIdOwner, out var player);
        // Only the puppet represents the viewer's position — ignore other owned entities.
        return player != null && ReferenceEquals(player.PuppetEntity, candidate) ? player : null;
    }

    public void OnStartTrackingEntity(Player player, Entity entity)
    {
        if (!_trackedEntities.TryGetValue(player.ConnectionId, out var tracked))
        {
            tracked = new HashSet<ulong>();
            _trackedEntities.Add(player.ConnectionId, tracked);
        }

        if (!tracked.Add(entity.NetworkedEntityId))
        {
            return; // already tracked
        }

        if (!_trackers.TryGetValue(entity.NetworkedEntityId, out var trackers))
        {
            trackers = new HashSet<uint>();
            _trackers.Add(entity.NetworkedEntityId, trackers);
        }

        trackers.Add(player.ConnectionId);

        var spawnEntity = new SpawnEntity
        {
            networkedEntityId = entity.NetworkedEntityId,
            recordId = entity.RecordId,
            spawnPosition = entity.WorldTransform
        };
        _sink.EnqueueMessage(EMessageTypeClientbound.SpawnEntity, player.ConnectionId, 1, spawnEntity);
    }

    public void OnStopTrackingEntity(Player player, Entity entity)
    {
        if (!_trackedEntities.TryGetValue(player.ConnectionId, out var tracked)
            || !tracked.Remove(entity.NetworkedEntityId))
        {
            return; // wasn't tracked
        }

        if (_trackers.TryGetValue(entity.NetworkedEntityId, out var trackers))
        {
            trackers.Remove(player.ConnectionId);
            if (trackers.Count == 0)
            {
                _trackers.Remove(entity.NetworkedEntityId);
            }
        }

        var destroyEntity = new DestroyEntity { networkedEntityId = entity.NetworkedEntityId };
        _sink.EnqueueMessage(EMessageTypeClientbound.DestroyEntity, player.ConnectionId, 1, destroyEntity);
    }

    /// Full removal: despawn at every tracker, drop from grid. Callers already use this before
    /// EntityService.RemoveEntity (vehicles, items, disconnects).
    public void StopTrackingOf(Entity entity)
    {
        foreach (var connectionId in GetPlayersTracking(entity.NetworkedEntityId).ToArray())
        {
            if (_players.ConnectedPlayers.TryGetValue(connectionId, out var player))
            {
                OnStopTrackingEntity(player, entity);
            }
        }

        _trackers.Remove(entity.NetworkedEntityId);
        _grid.Remove(entity);
    }

    /// Cleans the disconnected player's own tracked set + reverse-index entries. The player's
    /// entities themselves are cleaned up by the caller via StopTrackingOf.
    public void OnPlayerDisconnected(uint connectionId)
    {
        if (!_trackedEntities.Remove(connectionId, out var tracked))
        {
            return;
        }

        foreach (var entityId in tracked)
        {
            if (_trackers.TryGetValue(entityId, out var trackers))
            {
                trackers.Remove(connectionId);
                if (trackers.Count == 0)
                {
                    _trackers.Remove(entityId);
                }
            }
        }
    }

    /// <summary>
    /// A joining player wouldn't see resting entities (tracking is move-driven), so evaluate
    /// everything near their spawn once. Uses the same grid+hysteresis path as movement.
    /// </summary>
    public void InitialSpawnForPlayer(Player player)
    {
        if (player.PuppetEntity == null)
        {
            return;
        }

        foreach (var entity in _grid.QueryCandidates(player.PuppetEntity.WorldTransform, _config.EnterRadius))
        {
            if (entity.NetworkIdOwner == player.ConnectionId)
            {
                continue;
            }

            ConsiderPair(player, entity);
        }
    }
}
```

Note for the implementer: `UpdateTrackingOf(Entity, Player)` (the old two-arg overload) is deleted — nothing outside the tracker calls it (verify with grep before committing).

- [ ] **Step 6: Run tests — expect compile errors in GameServer only**

Run: `DOTNET_ROLL_FORWARD=LatestMajor dotnet build server/Managed`
Expected: `GameServer.cs` fails (old `new EntityTracker(this)` ctor). That wiring is Task 4 — to keep Task 3 green in isolation, apply the minimal GameServer change now (it belongs to the tracker's new contract):

In `server/Managed/GameServer.cs`, change the class declaration and constructor:

```csharp
public class GameServer: NativeGameServer, IPacketSink
{
    // ... existing fields ...
    public readonly ServerConfig Config;

    public GameServer(ushort listeningPort, ServerConfig config) : base(listeningPort)
    {
        Config = config;
        EntityService = new EntityService();
        EntityTracker = new EntityTracker(this, PlayerService,
            new SpatialGrid(config.Interest.CellSize), config.Interest);
    }
```

Add `using Cyberverse.Server.Services;` if missing (already present). In `Program.cs`, change the construction line:

```csharp
        var config = ServerConfig.Load(Path.Combine(AppContext.BaseDirectory, "config.json"));
        var server = new GameServer(1337, config);
```

And in `GameServer.OnConnectionStateChange`, after the `foreach (var playerEntity in playerEntities)` loop (before `PlayerService.ConnectedPlayers.Remove(connectionId);`), add:

```csharp
            EntityTracker.OnPlayerDisconnected(connectionId);
```

- [ ] **Step 7: Run all tests to verify they pass**

Run: `DOTNET_ROLL_FORWARD=LatestMajor dotnet test server/Managed.Tests`
Expected: all pass (4 + 8 + 10).

- [ ] **Step 8: Commit**

```bash
git add server/Managed/IPacketSink.cs server/Managed/Types/Player.cs server/Managed/Services/EntityTracker.cs server/Managed/GameServer.cs server/Managed/Program.cs server/Managed.Tests/EntityTrackerTests.cs
git commit -m "feat(server): interest management with hysteresis + reverse index in EntityTracker"
```

---

### Task 4: Wire-up — PuppetEntity assignment + action routing

**Files:**
- Modify: `server/Managed/PacketHandling/PlayerPacketHandler.cs` (`HandleJoinWorld` ~line 47, `HandleActionTracked` ~line 213)

**Interfaces:**
- Consumes: `Player.PuppetEntity` (Task 3), `EntityTracker.GetPlayersTracking(ulong)` (Task 3).
- Produces: nothing new — behavior change only.

- [ ] **Step 1: Set PuppetEntity on world join**

In `HandleJoinWorld`, after `entity.NetworkIdOwner = player.ConnectionId;` add:

```csharp
            player.PuppetEntity = entity;
```

- [ ] **Step 2: Route actions through the tracker**

In `HandleActionTracked`, replace the final `foreach (var player in _players!.ConnectedPlayers.Values) { ... }` loop with:

```csharp
        foreach (var trackingConnectionId in _tracker!.GetPlayersTracking(senderEntity.NetworkedEntityId))
        {
            server.EnqueueMessage(EMessageTypeClientbound.EntityAction, trackingConnectionId, channelId, entityAction);
        }
```

(The `player.ConnectionId == connectionId` self-check is no longer needed — a player never tracks their own entity.)

- [ ] **Step 3: Build + full test run**

Run: `DOTNET_ROLL_FORWARD=LatestMajor dotnet build server/Managed && DOTNET_ROLL_FORWARD=LatestMajor dotnet test server/Managed.Tests`
Expected: build OK, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add server/Managed/PacketHandling/PlayerPacketHandler.cs
git commit -m "feat(server): route entity actions through interest tracking"
```

---

### Task 5: Bot-harness — boundary pattern + spawn/despawn counters

**Files:**
- Modify: `tools/bot-harness/src/Behavior.h` (new pattern)
- Modify: `tools/bot-harness/src/main.cpp` (CLI: `--pattern boundary`, `--distance`)
- Modify: `tools/bot-harness/src/BotClient.h` / `BotClient.cpp` (spawn/despawn counters)

**Interfaces:**
- Consumes: existing `Behavior::Pattern` enum, existing per-message cases `eSpawnEntity`/`eDestroyEntity` in `BotClient.cpp` (~lines 153/193), existing stats counters pattern (`m_teleportsReceived`, `ConsumeTeleports()` in `BotClient.h` ~lines 45-52).
- Produces: CLI `--pattern boundary --distance <m>` (bot oscillates radially around `<m>` ±22.5m from center at walk speed); stats line additionally prints `spawns` and `despawns` per interval.

- [ ] **Step 1: Add the Boundary pattern to Behavior.h**

Add `Boundary` to the enum:

```cpp
    enum class Pattern
    {
        Circle,
        Random,
        Boundary,
    };
```

Extend the constructor signature (new optional param, default keeps old call sites working):

```cpp
    Behavior(const Pattern pattern, const Vector3 center, const int botIndex, const float boundaryDistance = 440.0f)
        : m_pattern(pattern), m_center(center),
          m_radius(5.0f + static_cast<float>(botIndex)),
          m_angle(static_cast<float>(botIndex) * 0.7f),
          m_boundaryDistance(boundaryDistance),
          m_rng(1337 + botIndex)
```

Add to the `Tick` switch:

```cpp
        case Pattern::Boundary:
            return TickBoundary(dt);
```

Add the implementation (private section) and the member:

```cpp
    // Oscillates radially between boundaryDistance-22.5 and boundaryDistance+22.5 around the
    // center — with defaults 440 +/- 22.5 that is 417.5..462.5, i.e. crossing the enter radius
    // (425) but never the exit radius (470): the server must spawn us once and never despawn.
    Pose TickBoundary(const float dt)
    {
        m_boundaryPhase += (WALK_SPEED / 22.5f) * dt;
        const float dist = m_boundaryDistance + 22.5f * std::sin(m_boundaryPhase);
        m_position = { m_center.x + dist * std::cos(m_angle), m_center.y + dist * std::sin(m_angle), m_center.z };
        const float yaw = (m_angle + (std::cos(m_boundaryPhase) >= 0.0f ? 0.0f : 3.1415927f)) * 57.29578f;
        return { m_position, std::fmod(yaw, 360.0f) };
    }

    float m_boundaryDistance;
    float m_boundaryPhase = 0.0f;
```

- [ ] **Step 2: CLI parsing in main.cpp**

Where `--pattern` values are parsed (~line 77), add:

```cpp
                else if (value == "boundary")
                {
                    options.pattern = Behavior::Pattern::Boundary;
                }
```

Add an option + parser branch analogous to `--jump-every` (~line 105):

```cpp
        else if (arg == "--distance")
        {
            options.boundaryDistance = std::strtof(argv[++i], nullptr);
        }
```

with `float boundaryDistance = 440.0f;` in the options struct (~line 33), pass it through to the `Behavior` constructor call site, and extend the usage string (~line 115) with `[--pattern circle|random|boundary] [--distance <m>]`.

- [ ] **Step 3: Spawn/despawn counters in BotClient**

In `BotClient.h`, next to `m_teleportsReceived` (~line 95), add:

```cpp
    uint64_t m_spawnsReceived = 0;
    uint64_t m_despawnsReceived = 0;
```

and next to `ConsumeTeleports`/`ConsumeActions` (~lines 45-52), add the same consume-and-reset accessors:

```cpp
    uint64_t ConsumeSpawns() { const auto count = m_spawnsReceived; m_spawnsReceived = 0; return count; }
    uint64_t ConsumeDespawns() { const auto count = m_despawnsReceived; m_despawnsReceived = 0; return count; }
```

In `BotClient.cpp`, inside `case eSpawnEntity:` (~line 153) add `m_spawnsReceived++;` and inside `case eDestroyEntity:` (~line 193) add `m_despawnsReceived++;`. In the stats aggregation in `main.cpp`, print them alongside teleports/actions (same pattern as the existing stats line).

- [ ] **Step 4: Build**

Build inside vcvars64 (same recipe as documented in `docs/ENVIRONMENT.md`, choomlink repo):

```
cmake --build tools/bot-harness/build/ninja-vcpkg
```

Expected: clean build.

- [ ] **Step 5: Commit**

```bash
git add tools/bot-harness
git commit -m "feat(bot-harness): boundary pattern + spawn/despawn counters for interest-management verification"
```

---

### Task 6: Headless verification (bot-harness against live server)

**Files:** none (verification only; record results in the commit message / bean notes)

**Interfaces:**
- Consumes: server from Tasks 1–4 (`dotnet run` in `server/Managed`, `DOTNET_ROLL_FORWARD=LatestMajor`, native DLLs beside the exe — recipe in choomlink `docs/ENVIRONMENT.md`), bot-harness from Task 5.

- [ ] **Step 1: Far-bot isolation test**

Start the server. Run two bot groups: `--count 4 --pattern circle --center 0,0,0` and `--count 4 --pattern circle --center 1000,1000,0` (>530m apart, beyond exit radius).
Expected: each bot's stats show teleports/actions ONLY from its own group (3 peers × 10 Hz ≈ 30 teleports/s per bot, not 7 × 10 Hz = 70); `spawns` stays at 3 per bot; `despawns` 0.

- [ ] **Step 2: Boundary hysteresis test**

Run: 1 static bot at center (`--count 1 --pattern circle --center 0,0,0`) + 1 boundary bot (`--count 1 --pattern boundary --distance 440 --center 0,0,0`).
Expected: the static bot's stats show exactly 1 spawn for the boundary bot and 0 despawns over ≥2 minutes of oscillation (417.5–462.5m stays inside the 425/470 band after first entry). Then re-run with `--distance 500` (oscillates 477.5–522.5, fully outside): expected 0 spawns.

- [ ] **Step 3: 50-bot density test (headless part)**

Run: `--count 50 --pattern circle --center 0,0,0`.
Expected: all 50 connect and run; per-bot teleports ≈ 49 × 10 Hz = 490/s; server log free of errors/warnings; server process CPU noted (Task Manager / `Get-Process`) — record the number.

- [ ] **Step 4: Shut everything down** (standing rule: no idle server/bots), record results, commit any notes to the bean:

```bash
beans update choomlink-pzib --comment "Phase 1 headless verification: <results>"
```

(If `beans update --comment` is not supported, append to the bean body file instead.)

---

### Task 7: In-game verification + density measurement

Use the `ingame-verify` skill (choomlink repo, `.claude/skills/ingame-verify/SKILL.md`) — it owns deploy/launch/log-gating/capture/cleanup. Feature-specific success criteria on top of the skill's standard sequence:

- [ ] **Step 1: Visibility radius.** Bots at ~400m from the player's save-game position (`--center` chosen accordingly): visible in a capture burst. Bots at >500m: NOT visible, and the client receives no teleports for them (CET Game Log via FTLog if needed).
- [ ] **Step 2: No boundary flicker.** One boundary-pattern bot at `--distance 440` around the player's position: capture bursts over 2 minutes show the puppet continuously present (no popping).
- [ ] **Step 3: Far actions filtered.** A far bot with `--jump-every 5`: no remote-jump FTLog lines for it on the client.
- [ ] **Step 4: 50-bot density (the user's "50 players in one grid" question).** `--count 50` circling near the player: capture burst + note client FPS (Steam overlay or CET). Record the number in bean choomlink-pzib and in `docs/research/` notes — this is the empirical answer feeding Phase 5 density expectations.
- [ ] **Step 5: Cleanup per standing rule** (quit game, stop bots + server), report results to the user, commit.

---

## Self-Review (done at plan-writing time)

- **Spec coverage:** config (T1), grid + ring-generic query + edge cases (T2), hysteresis + reverse index + despawn correctness + weakness 6 + disconnect cleanup + visibility-filter hook (T3), action routing + PuppetEntity (T4), boundary pattern + counters (T5), far/boundary/50-bot verification (T6/T7). InitialSpawnForPlayer switched to grid path (T3 code). Non-goals respected (no protocol change — verified: no new message types anywhere).
- **Type consistency:** `IPacketSink.EnqueueMessage<T>` matches GameServer's existing method signature exactly (verified against GameServer.cs:71). `GetPlayersTracking(ulong)` used identically in T3 tests and T4. `InterestConfig` property names match T1 JSON via case-insensitive deserialization.
- **Known judgment call:** `HandlePositionUpdate`'s LINQ over SpawnedEntities stays (bounded: one scan per packet over total entities; the tracker's per-player LINQ — the actual hot path — is gone via PuppetEntity + grid). Noted for a later cleanup when EntityService gets an owner index.
