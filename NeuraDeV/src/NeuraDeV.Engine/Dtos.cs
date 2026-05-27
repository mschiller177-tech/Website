namespace NeuraDeV.Engine;

/// <summary>Top-level reply produced by the engine for a single user turn.</summary>
public sealed record AssistantReply(
    string Text,
    IReadOnlyList<PlanItem> Plan,
    IReadOnlyList<GeneratedFile> Files,
    string StatusLine,
    double Progress,
    DiagnosticsReport Diagnostics);

public sealed record PlanItem(string Title, bool IsDone);

/// <summary>A single source file emitted by the engine, ready to write to disk.</summary>
public sealed record GeneratedFile(string Path, string Content, string Language);

/// <summary>Per-project context passed into every engine turn.</summary>
public sealed record ProjectContext(
    string ProjectName,
    string RootPath,
    Framework Framework,
    IReadOnlyList<string> OpenFiles)
{
    public static ProjectContext Empty(string name) =>
        new(name, string.Empty, Framework.Standalone, Array.Empty<string>());
}

public enum Framework { Standalone, QbCore, Esx, Csharp, Web }

public sealed record DiagnosticsReport(
    IReadOnlyList<Diagnostic> Errors,
    IReadOnlyList<Diagnostic> Warnings)
{
    public bool IsClean => Errors.Count == 0 && Warnings.Count == 0;
    public static DiagnosticsReport Empty { get; } = new(Array.Empty<Diagnostic>(), Array.Empty<Diagnostic>());
}

public sealed record Diagnostic(string File, int Line, string Message, string? Suggestion);
