namespace NeuraDeV.Engine.Reasoning;

/// <summary>
/// Rule-based intent classifier. Fast, deterministic, transparent.
/// Acts as the first router stage before any LLM is consulted.
/// </summary>
public sealed class IntentClassifier
{
    public Intent Classify(string input)
    {
        var t = input.ToLowerInvariant();

        if (Contains(t, "police", "polizei") && Contains(t, "job", "system"))
            return Intent.QbCorePoliceJob;

        if (Contains(t, "fivem") && Contains(t, "resource", "skript", "script", "ressource"))
            return Intent.FiveMResourceScaffold;

        if (Contains(t, "nui", "menü", "menu", "ui") && Contains(t, "fivem", "polizei", "spieler"))
            return Intent.NuiMenu;

        if (Contains(t, "sql", "schema", "tabelle", "datenbank") && !Contains(t, "police"))
            return Intent.SqlSchema;

        if (Contains(t, "config", "konfiguration") && Contains(t, "lua", "json"))
            return Intent.ConfigFile;

        if (Contains(t, "fehler", "error", "bug", "fix") || Contains(t, "behebe", "repariere"))
            return Intent.Debug;

        if (Contains(t, "erklär", "erklaer", "was macht", "wie funktioniert"))
            return Intent.Explain;

        if (Contains(t, "test", "unit"))
            return Intent.TestGenerator;

        return Intent.Unknown;
    }

    private static bool Contains(string haystack, params string[] needles) =>
        needles.Any(n => haystack.Contains(n, StringComparison.OrdinalIgnoreCase));
}

public enum Intent
{
    Unknown,
    QbCorePoliceJob,
    FiveMResourceScaffold,
    NuiMenu,
    SqlSchema,
    ConfigFile,
    Debug,
    Explain,
    TestGenerator
}
