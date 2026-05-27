using System.Text;

namespace NeuraDeV.Engine.Reasoning;

/// <summary>
/// Builds prompts for the LLM runtime. Injects project context, code style,
/// framework conventions and few-shot examples so the model produces
/// production-quality output even without fine-tuning.
/// </summary>
public sealed class PromptBuilder
{
    public string System(ProjectContext ctx) =>
        $$"""
        Du bist NeuraDeV, ein lokaler KI-Software-Engineer.
        Du arbeitest am Projekt "{{ctx.ProjectName}}" (Framework: {{ctx.Framework}}).
        Regeln:
          - Schreibe nur vollständige, produktionsreife Module.
          - Keine halben Snippets, keine TODO-Kommentare.
          - Modulare Architektur (server/client/ui/config/sql).
          - Für FiveM: Sicherheit beachten (server-seitige Validierung, keine client-trust).
          - Antwort-Format: Plain code in fenced blocks, jeweils mit Dateipfad-Header.
        """;

    public string ForIntent(Intent intent, string userInput, ProjectContext ctx)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"Intent: {intent}");
        sb.AppendLine($"Projekt: {ctx.ProjectName}  Framework: {ctx.Framework}");
        if (ctx.OpenFiles.Count > 0)
        {
            sb.AppendLine("Geöffnete Dateien:");
            foreach (var f in ctx.OpenFiles) sb.AppendLine($"  - {f}");
        }
        sb.AppendLine().AppendLine("User-Anfrage:");
        sb.AppendLine(userInput);
        return sb.ToString();
    }
}
