namespace NeuraDeV.Engine.Inference;

/// <summary>Catalogue + on-disk lookup of GGUF models for LlamaCppRuntime.</summary>
public sealed class ModelManager
{
    private static readonly string DefaultDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NeuraDeV", "models");

    public string ModelDirectory { get; }

    public ModelManager(string? directory = null)
    {
        ModelDirectory = directory ?? DefaultDir;
        Directory.CreateDirectory(ModelDirectory);
    }

    public IReadOnlyList<ModelDescriptor> Catalog { get; } = new[]
    {
        new ModelDescriptor(
            "deepseek-coder-1.3b",
            "DeepSeek Coder 1.3B",
            "Schnell, klein, gut für Code-Vervollständigung.",
            FileName: "deepseek-coder-1.3b-instruct.Q4_K_M.gguf",
            SizeMb: 800),
        new ModelDescriptor(
            "qwen2.5-coder-1.5b",
            "Qwen2.5 Coder 1.5B",
            "Neuer, sehr stark bei Multi-Sprache (Lua, C#, JS).",
            FileName: "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf",
            SizeMb: 1100),
        new ModelDescriptor(
            "phi-3.5-mini",
            "Phi-3.5 Mini 3.8B",
            "Großer Kontext, gute Reasoning-Fähigkeit, ~2 GB RAM.",
            FileName: "Phi-3.5-mini-instruct-Q4_K_M.gguf",
            SizeMb: 2200)
    };

    public ModelDescriptor? Find(string id) => Catalog.FirstOrDefault(m => m.Id == id);

    public IEnumerable<ModelDescriptor> Installed() =>
        Catalog.Where(m => File.Exists(PathFor(m)));

    public string PathFor(ModelDescriptor m) => Path.Combine(ModelDirectory, m.FileName);
}

public sealed record ModelDescriptor(
    string Id,
    string DisplayName,
    string Description,
    string FileName,
    int SizeMb);
