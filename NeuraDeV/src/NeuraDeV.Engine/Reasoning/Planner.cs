using NeuraDeV.Engine.Inference;
using NeuraDeV.Engine.Templates;

namespace NeuraDeV.Engine.Reasoning;

/// <summary>
/// Strategic core of the engine. Turns a user request into:
///   1. A multi-step plan (visible to the user as checkmarks).
///   2. A set of generated files (executed step by step).
///
/// Rule-based first: known intents skip the LLM entirely and produce
/// deterministic, high-quality output. Unknown intents fall back to the
/// LLM runtime (TemplateRuntime if no model is loaded).
/// </summary>
public sealed class Planner
{
    private readonly IntentClassifier _classifier;
    private readonly PromptBuilder _prompts;
    private readonly TemplateLibrary _templates;
    private readonly ILlmRuntime _llm;

    public Planner(ILlmRuntime llm)
    {
        _llm = llm;
        _classifier = new IntentClassifier();
        _prompts = new PromptBuilder();
        _templates = new TemplateLibrary();
    }

    public Task<Plan> PlanAsync(string userInput, ProjectContext ctx, CancellationToken ct)
    {
        var intent = _classifier.Classify(userInput);
        Plan plan = intent switch
        {
            Intent.QbCorePoliceJob => Plan.For(
                summary: "Verstanden! Ich werde ein komplettes Police Job System für FiveM erstellen. Hier ist der Plan:",
                statusLine: "Schritt 1/5: Datenbank erstellen",
                progress: 0.22,
                steps: new[]
                {
                    new PlanStep("1. Datenbank erstellen", true),
                    new PlanStep("2. Server-Script entwickeln", true),
                    new PlanStep("3. Client-Script entwickeln", true),
                    new PlanStep("4. UI für Polizei Menü erstellen", true),
                    new PlanStep("5. Konfiguration hinzufügen", true),
                },
                intent: intent),

            Intent.FiveMResourceScaffold => Plan.For(
                summary: "Ich gerüste eine vollständige FiveM Resource mit Server/Client/UI/Config.",
                statusLine: "Schritt 1/4: Manifest schreiben",
                progress: 0.25,
                steps: new[]
                {
                    new PlanStep("1. fxmanifest.lua erzeugen", true),
                    new PlanStep("2. Server-Skelett", true),
                    new PlanStep("3. Client-Skelett", true),
                    new PlanStep("4. Config-Datei", true),
                },
                intent: intent),

            Intent.NuiMenu => Plan.For(
                summary: "Ich baue ein NUI-Menü (HTML/CSS/JS) mit FiveM Bridge.",
                statusLine: "Schritt 1/3: HTML Struktur",
                progress: 0.33,
                steps: new[]
                {
                    new PlanStep("1. HTML/CSS Layout", true),
                    new PlanStep("2. JS NUI Bridge", true),
                    new PlanStep("3. Client-Lua Trigger", true),
                },
                intent: intent),

            Intent.SqlSchema => Plan.For(
                summary: "Ich entwerfe ein normalisiertes SQL-Schema mit Indizes.",
                statusLine: "Schritt 1/2: Tabellen entwerfen",
                progress: 0.5,
                steps: new[]
                {
                    new PlanStep("1. Tabellen + Spalten", true),
                    new PlanStep("2. Indizes + Foreign Keys", true),
                },
                intent: intent),

            _ => Plan.For(
                summary: "Ich analysiere die Anfrage. Bitte konkretisiere (Framework, Zielmodul).",
                statusLine: string.Empty,
                progress: 0,
                steps: Array.Empty<PlanStep>(),
                intent: intent),
        };

        return Task.FromResult(plan);
    }

    public async Task<IReadOnlyList<GeneratedFile>> ExecuteAsync(
        Plan plan,
        ProjectContext ctx,
        CancellationToken ct)
    {
        return plan.Intent switch
        {
            Intent.QbCorePoliceJob       => _templates.QbCorePoliceJob(ctx),
            Intent.FiveMResourceScaffold => _templates.FiveMResource(ctx),
            Intent.NuiMenu               => _templates.NuiMenu(ctx),
            Intent.SqlSchema             => _templates.SqlSchema(ctx),
            Intent.ConfigFile            => _templates.ConfigFile(ctx),
            Intent.Unknown               => await LlmFallbackAsync(plan, ctx, ct),
            _ => Array.Empty<GeneratedFile>()
        };
    }

    private async Task<IReadOnlyList<GeneratedFile>> LlmFallbackAsync(
        Plan plan, ProjectContext ctx, CancellationToken ct)
    {
        var system = _prompts.System(ctx);
        var user = _prompts.ForIntent(plan.Intent, plan.Summary, ctx);
        var raw = await _llm.CompleteAsync(new LlmRequest(system, user), ct);

        // For now, surface the LLM text without parsing into files. A real
        // implementation would extract fenced code blocks ```lang:path  ... ```.
        return new[]
        {
            new GeneratedFile("response.md", raw, "markdown")
        };
    }
}

public sealed record Plan(
    string Summary,
    string StatusLine,
    double Progress,
    IReadOnlyList<PlanStep> Steps,
    Intent Intent)
{
    public static Plan For(string summary, string statusLine, double progress,
        IReadOnlyList<PlanStep> steps, Intent intent) =>
        new(summary, statusLine, progress, steps, intent);
}

public sealed record PlanStep(string Title, bool IsDone);
