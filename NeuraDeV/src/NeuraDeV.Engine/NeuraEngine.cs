using NeuraDeV.Engine.Analysis;
using NeuraDeV.Engine.Inference;
using NeuraDeV.Engine.Memory;
using NeuraDeV.Engine.Reasoning;
using NeuraDeV.Engine.Security;

namespace NeuraDeV.Engine;

public sealed class NeuraEngine : INeuraEngine
{
    private readonly Planner _planner;
    private readonly ILlmRuntime _llm;
    private readonly LuaLinter _luaLinter;
    private readonly ProjectMemory _memory;
    private readonly InputValidator _validator;
    private readonly EngineLogger _log;

    public NeuraEngine(
        ILlmRuntime? llm = null,
        ProjectMemory? memory = null,
        EngineLogger? logger = null)
    {
        _log = logger ?? new EngineLogger();
        _llm = llm ?? new TemplateRuntime();
        _planner = new Planner(_llm);
        _luaLinter = new LuaLinter();
        _memory = memory ?? new ProjectMemory();
        _validator = new InputValidator();
    }

    public bool HasLlm => _llm.IsLlmBacked;

    public async Task<AssistantReply> AskAsync(
        string userInput,
        ProjectContext context,
        CancellationToken ct = default)
    {
        _log.Info($"AskAsync project={context.ProjectName} input={Trim(userInput)}");

        if (!_validator.TryValidate(userInput, out var reason))
        {
            return new AssistantReply(
                Text: $"⚠️ Eingabe abgelehnt: {reason}",
                Plan: Array.Empty<PlanItem>(),
                Files: Array.Empty<GeneratedFile>(),
                StatusLine: string.Empty,
                Progress: 0,
                Diagnostics: DiagnosticsReport.Empty);
        }

        // 1. Plan (rule-based first, LLM fallback)
        var plan = await _planner.PlanAsync(userInput, context, ct);

        // 2. Execute plan → emit files
        var generated = await _planner.ExecuteAsync(plan, context, ct);

        // 3. Static analysis + auto-fix pass
        var diag = await AnalyzeAsync(generated, ct);

        // 4. Persist to project memory
        await _memory.RecordTurnAsync(context.ProjectName, userInput, plan, generated, ct);

        return new AssistantReply(
            Text: plan.Summary,
            Plan: plan.Steps.Select(s => new PlanItem(s.Title, s.IsDone)).ToList(),
            Files: generated,
            StatusLine: plan.StatusLine,
            Progress: plan.Progress,
            Diagnostics: diag);
    }

    public Task<DiagnosticsReport> AnalyzeAsync(
        IReadOnlyList<GeneratedFile> files,
        CancellationToken ct = default)
    {
        var errors = new List<Diagnostic>();
        var warnings = new List<Diagnostic>();

        foreach (var f in files)
        {
            if (string.Equals(f.Language, "lua", StringComparison.OrdinalIgnoreCase))
            {
                var (e, w) = _luaLinter.Lint(f);
                errors.AddRange(e);
                warnings.AddRange(w);
            }
            // CSharp + SQL + HTML linters wire in here when implemented.
        }

        return Task.FromResult(new DiagnosticsReport(errors, warnings));
    }

    private static string Trim(string s) => s.Length <= 80 ? s : s[..77] + "...";
}
