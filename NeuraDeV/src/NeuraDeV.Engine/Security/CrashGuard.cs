namespace NeuraDeV.Engine.Security;

/// <summary>
/// Process-wide last-resort exception handler. Persists the crash to a
/// rolling log file so the engine survives misbehaving plugins/templates
/// without taking down the host UI.
/// </summary>
public static class CrashGuard
{
    private static readonly string LogPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NeuraDeV", "logs", "crash.log");

    public static void Install(Action<Exception>? onCrash = null)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(LogPath)!);

        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            Handle(e.ExceptionObject as Exception ?? new Exception("Unknown"), onCrash);

        TaskScheduler.UnobservedTaskException += (_, e) =>
        {
            Handle(e.Exception, onCrash);
            e.SetObserved();
        };
    }

    private static void Handle(Exception ex, Action<Exception>? onCrash)
    {
        try
        {
            var line = $"[{DateTime.UtcNow:O}] {ex.GetType().FullName}: {ex.Message}\n{ex.StackTrace}\n";
            File.AppendAllText(LogPath, line);
        }
        catch { /* never throw from the crash handler */ }

        onCrash?.Invoke(ex);
    }
}
