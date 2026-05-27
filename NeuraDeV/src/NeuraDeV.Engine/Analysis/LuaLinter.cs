using System.Text.RegularExpressions;

namespace NeuraDeV.Engine.Analysis;

/// <summary>
/// Lightweight Lua linter. Catches the most common FiveM mistakes without
/// pulling in a full Lua parser. Designed to run on every generated file
/// before it reaches the user.
/// </summary>
public sealed class LuaLinter
{
    private static readonly Regex BadTriggerClient = new(
        @"TriggerServerEvent\s*\(\s*['""][^'""]*['""]\s*\)",
        RegexOptions.Compiled);

    private static readonly Regex UnsafeExecutionString = new(
        @"loadstring\s*\(",
        RegexOptions.Compiled);

    private static readonly Regex MissingEndOfBlock = new(
        @"\bfunction\b(?![^()]*\bend\b)",
        RegexOptions.Compiled | RegexOptions.Singleline);

    public (List<Diagnostic> Errors, List<Diagnostic> Warnings) Lint(GeneratedFile file)
    {
        var errors = new List<Diagnostic>();
        var warnings = new List<Diagnostic>();

        var lines = file.Content.Split('\n');
        var brackets = 0;
        for (var i = 0; i < lines.Length; i++)
        {
            var line = lines[i];
            brackets += line.Count(c => c == '{') - line.Count(c => c == '}');

            if (UnsafeExecutionString.IsMatch(line))
                errors.Add(new Diagnostic(file.Path, i + 1,
                    "Verwendung von loadstring() ist unsicher (Code-Injection).",
                    "Entferne dynamische String-Ausführung oder validiere strikt."));

            if (line.Contains("TriggerServerEvent") && !line.Contains(','))
                warnings.Add(new Diagnostic(file.Path, i + 1,
                    "Server-Event ohne Argumente — vermutlich unbeabsichtigt.",
                    "Argumente serverseitig validieren (nie client-trust)."));

            if (line.TrimStart().StartsWith("local QBCore") &&
                !line.Contains("GetCoreObject"))
                warnings.Add(new Diagnostic(file.Path, i + 1,
                    "QBCore-Import sieht unvollständig aus.",
                    "Verwende: local QBCore = exports['qb-core']:GetCoreObject()"));
        }

        if (brackets != 0)
            errors.Add(new Diagnostic(file.Path, lines.Length,
                $"Klammer-Bilanz nicht ausgeglichen ({brackets:+#;-#;0}).",
                "Suche nach fehlenden { oder }."));

        return (errors, warnings);
    }
}
