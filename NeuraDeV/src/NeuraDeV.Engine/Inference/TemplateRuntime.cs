namespace NeuraDeV.Engine.Inference;

/// <summary>
/// Deterministic, zero-dependency "runtime". Doesn't generate creative text —
/// returns canned answers that the Planner can stitch with template output.
/// This is what powers NeuraDeV out of the box when no GGUF model is loaded.
/// </summary>
public sealed class TemplateRuntime : ILlmRuntime
{
    public bool IsLlmBacked => false;

    public Task<string> CompleteAsync(LlmRequest req, CancellationToken ct = default)
    {
        // The Planner only calls this when no rule covers an intent. Provide
        // a safe, structured fallback that admits limits rather than hallucinating.
        var msg =
            "Für diesen Spezialfall ist kein Template hinterlegt. " +
            "Lade ein lokales LLM (Einstellungen → KI-Modell → GGUF laden), " +
            "oder formuliere die Anfrage als bekannte Vorlage " +
            "(z. B. \"Police Job\", \"FiveM Resource\", \"NUI Menü\", \"SQL Schema\").";
        return Task.FromResult(msg);
    }
}
