namespace NeuraDeV.Engine.Inference;

/// <summary>
/// Skeleton for local LLM inference via LLamaSharp (llama.cpp bindings).
///
/// To activate:
///   1. Add NuGet packages to NeuraDeV.Engine.csproj:
///        &lt;PackageReference Include="LLamaSharp" Version="0.19.0" /&gt;
///        &lt;PackageReference Include="LLamaSharp.Backend.Cpu" Version="0.19.0" /&gt;
///        (use LLamaSharp.Backend.Cuda12 for NVIDIA GPU acceleration)
///   2. Uncomment the body below and replace TODO sections.
///   3. Download a GGUF model. Recommended for code tasks:
///        - DeepSeek-Coder-1.3B-Instruct-Q4_K_M.gguf (~800 MB)
///        - Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf (~1.1 GB)
///        - Phi-3.5-mini-instruct-Q4_K_M.gguf (~2.2 GB)
///      Place under: %LOCALAPPDATA%\NeuraDeV\models\
///
/// Once enabled, NeuraEngine.HasLlm flips to true and the Planner uses the
/// LLM to fill creative gaps that the deterministic templates can't cover.
/// </summary>
public sealed class LlamaCppRuntime : ILlmRuntime, IDisposable
{
    private readonly string _modelPath;
    // private readonly LLama.LLamaWeights _weights;
    // private readonly LLama.LLamaContext _ctx;

    public LlamaCppRuntime(string modelPath)
    {
        _modelPath = modelPath;
        if (!File.Exists(modelPath))
            throw new FileNotFoundException("GGUF model not found", modelPath);

        // var parameters = new LLama.Common.ModelParams(modelPath)
        // {
        //     ContextSize = 8192,
        //     GpuLayerCount = 0,   // CPU-only by default
        // };
        // _weights = LLama.LLamaWeights.LoadFromFile(parameters);
        // _ctx = _weights.CreateContext(parameters);
    }

    public bool IsLlmBacked => true;

    public Task<string> CompleteAsync(LlmRequest req, CancellationToken ct = default)
    {
        // var executor = new LLama.InstructExecutor(_ctx);
        // var inferenceParams = new LLama.Common.InferenceParams
        // {
        //     MaxTokens = req.MaxTokens,
        //     Temperature = (float)req.Temperature,
        //     AntiPrompts = req.Stop?.ToList() ?? new()
        // };
        // var prompt = $"{req.SystemPrompt}\n\n### Instruction:\n{req.UserPrompt}\n\n### Response:\n";
        // var output = new System.Text.StringBuilder();
        // await foreach (var token in executor.InferAsync(prompt, inferenceParams, ct))
        //     output.Append(token);
        // return output.ToString().Trim();

        throw new NotImplementedException(
            "LlamaCppRuntime is a skeleton. Add LLamaSharp NuGet + uncomment the body.");
    }

    public void Dispose()
    {
        // _ctx?.Dispose();
        // _weights?.Dispose();
    }
}
