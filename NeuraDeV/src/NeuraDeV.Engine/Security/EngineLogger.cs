namespace NeuraDeV.Engine.Security;

/// <summary>
/// Minimal structured logger for the engine. Writes timestamped lines to a
/// rolling file under %LOCALAPPDATA%\NeuraDeV\logs\engine.log. Swap with
/// Serilog/Microsoft.Extensions.Logging if the host app wires a richer logger.
/// </summary>
public sealed class EngineLogger
{
    private static readonly string LogDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NeuraDeV", "logs");

    private readonly object _lock = new();
    private readonly string _path;

    public EngineLogger(string? path = null)
    {
        Directory.CreateDirectory(LogDir);
        _path = path ?? Path.Combine(LogDir, "engine.log");
    }

    public void Info(string message)  => Write("INFO ", message);
    public void Warn(string message)  => Write("WARN ", message);
    public void Error(string message) => Write("ERROR", message);

    private void Write(string level, string message)
    {
        var line = $"[{DateTime.UtcNow:O}] {level} {message}\n";
        lock (_lock)
        {
            try { File.AppendAllText(_path, line); }
            catch { /* never throw from the logger */ }
        }
    }
}
