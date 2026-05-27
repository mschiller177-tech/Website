using System.Text.Json;
using NeuraDeV.Engine.Reasoning;

namespace NeuraDeV.Engine.Memory;

/// <summary>
/// Persistent per-project memory. Backed by JSON files under
/// %LOCALAPPDATA%\NeuraDeV\memory\&lt;project&gt;.json — swap for SQLite if
/// concurrent access becomes a concern.
///
/// The engine records every turn so it can:
///   - replay decisions when a project is re-opened
///   - learn user preferences (framework, code style, naming)
///   - diff generated outputs across versions
/// </summary>
public sealed class ProjectMemory
{
    private static readonly string DefaultDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NeuraDeV", "memory");

    private readonly string _dir;
    private readonly JsonSerializerOptions _json = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public ProjectMemory(string? directory = null)
    {
        _dir = directory ?? DefaultDir;
        Directory.CreateDirectory(_dir);
    }

    public async Task RecordTurnAsync(
        string projectName,
        string userInput,
        Plan plan,
        IReadOnlyList<GeneratedFile> files,
        CancellationToken ct = default)
    {
        var record = new MemoryRecord(
            DateTime.UtcNow,
            userInput,
            plan.Intent.ToString(),
            plan.Steps.Select(s => s.Title).ToArray(),
            files.Select(f => f.Path).ToArray());

        var path = PathFor(projectName);
        var history = await ReadAsync(projectName, ct);
        history.Turns.Add(record);
        await using var fs = File.Create(path);
        await JsonSerializer.SerializeAsync(fs, history, _json, ct);
    }

    public async Task<ProjectHistory> ReadAsync(string projectName, CancellationToken ct = default)
    {
        var path = PathFor(projectName);
        if (!File.Exists(path)) return new ProjectHistory(projectName, new List<MemoryRecord>());
        await using var fs = File.OpenRead(path);
        return await JsonSerializer.DeserializeAsync<ProjectHistory>(fs, _json, ct)
            ?? new ProjectHistory(projectName, new List<MemoryRecord>());
    }

    private string PathFor(string projectName)
    {
        var safe = string.Concat(projectName.Where(c =>
            char.IsLetterOrDigit(c) || c == '-' || c == '_'));
        return Path.Combine(_dir, $"{safe}.json");
    }
}

public sealed record MemoryRecord(
    DateTime At,
    string UserInput,
    string Intent,
    string[] PlanSteps,
    string[] Files);

public sealed record ProjectHistory(string Project, List<MemoryRecord> Turns);
