namespace NeuraDeV.Engine;

/// <summary>
/// Top-level facade for the NeuraDeV AI engine. Implementations orchestrate
/// intent classification, planning, template generation, LLM inference (if a
/// model is loaded), static analysis, memory and security guards.
/// </summary>
public interface INeuraEngine
{
    /// <summary>Run a single user turn against the current project context.</summary>
    Task<AssistantReply> AskAsync(
        string userInput,
        ProjectContext context,
        CancellationToken ct = default);

    /// <summary>Re-run analysis + auto-fix over already generated files.</summary>
    Task<DiagnosticsReport> AnalyzeAsync(
        IReadOnlyList<GeneratedFile> files,
        CancellationToken ct = default);

    /// <summary>True when a local LLM is loaded and ready to assist creative gaps.</summary>
    bool HasLlm { get; }
}
