namespace NeuraDeV.Engine.Inference;

/// <summary>
/// Abstraction over the underlying text-generation engine. Swap implementations
/// without touching the Planner / Engine. Two implementations ship in this repo:
/// <list type="bullet">
///   <item><see cref="TemplateRuntime"/>: deterministic, no model required.</item>
///   <item><see cref="LlamaCppRuntime"/>: GGUF model via llama.cpp (offline).</item>
/// </list>
/// </summary>
public interface ILlmRuntime
{
    /// <summary>True when this runtime is backed by an actual neural network.</summary>
    bool IsLlmBacked { get; }

    /// <summary>
    /// Generate a completion for the given prompt. The runtime may stream
    /// internally but returns the full text once complete.
    /// </summary>
    Task<string> CompleteAsync(LlmRequest request, CancellationToken ct = default);
}

public sealed record LlmRequest(
    string SystemPrompt,
    string UserPrompt,
    int MaxTokens = 1024,
    double Temperature = 0.2,
    IReadOnlyList<string>? Stop = null);
