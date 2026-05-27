using System.Collections.ObjectModel;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using NeuraDeV.Engine;
using NeuraDeV.Engine.Templates;
using NeuraDeV.Models;

namespace NeuraDeV.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly INeuraEngine _engine;
    private readonly Dictionary<string, (string Content, string Language)> _fileBank;
    private ProjectContext _projectCtx;

    public ObservableCollection<NavItem> NavItems { get; }
    public ObservableCollection<ProjectNode> ProjectTree { get; }
    public ObservableCollection<ChatMessage> Messages { get; }
    public ObservableCollection<string> Logs { get; } = new();
    public ObservableCollection<Diagnostic> Errors { get; } = new();

    [ObservableProperty] private string activeFileName = "police_server.lua";
    [ObservableProperty] private string codeContent = string.Empty;
    [ObservableProperty] private string codeLanguage = "lua";
    [ObservableProperty] private string draftInput = string.Empty;
    [ObservableProperty] private string inputPlaceholder = "Nachricht an NeuraDeV...";
    [ObservableProperty] private string serverHost = "localhost";
    [ObservableProperty] private string serverPlayers = "0/32";
    [ObservableProperty] private bool serverOnline = true;
    [ObservableProperty] private string engineStatus = "Lokale KI: Templates aktiv (kein LLM geladen)";

    [ObservableProperty] private bool isTabCode = true;
    [ObservableProperty] private bool isTabLive;
    [ObservableProperty] private bool isTabLogs;
    [ObservableProperty] private bool isTabErrors;

    public MainViewModel() : this(new NeuraEngine()) { }

    public MainViewModel(INeuraEngine engine)
    {
        _engine = engine;
        _projectCtx = new ProjectContext(
            ProjectName: "my_fivem_project",
            RootPath: string.Empty,
            Framework: Framework.QbCore,
            OpenFiles: Array.Empty<string>());

        if (_engine.HasLlm)
            EngineStatus = "Lokale KI: LLM aktiv (offline)";

        NavItems = new ObservableCollection<NavItem>
        {
            new() { Title = "Dashboard",        Icon = "", Key = "dashboard" },
            new() { Title = "Chat",             Icon = "", Key = "chat", IsActive = true },
            new() { Title = "Projekt Explorer", Icon = "", Key = "explorer" },
            new() { Title = "Script Generator", Icon = "", Key = "scripts" },
            new() { Title = "Debug Assistant",  Icon = "", Key = "debug" },
            new() { Title = "Config Builder",   Icon = "", Key = "config" },
            new() { Title = "Test Generator",   Icon = "", Key = "tests" },
            new() { Title = "UI Generator",     Icon = "", Key = "ui" },
            new() { Title = "Datenbank",        Icon = "", Key = "db" },
            new() { Title = "Einstellungen",    Icon = "", Key = "settings" }
        };

        ProjectTree = new ObservableCollection<ProjectNode>
        {
            new()
            {
                Name = "my_fivem_project", IsFolder = true,
                Children =
                {
                    new() { Name = "server", IsFolder = true, Children =
                    {
                        new() { Name = "main.lua" },
                        new() { Name = "config.lua" },
                        new() { Name = "police_server.lua" }
                    }},
                    new() { Name = "client", IsFolder = true, Children =
                    {
                        new() { Name = "main.lua" },
                        new() { Name = "police_client.lua" }
                    }},
                    new() { Name = "ui", IsFolder = true, Children =
                    {
                        new() { Name = "index.html" },
                        new() { Name = "style.css" },
                        new() { Name = "script.js" }
                    }},
                    new() { Name = "config", IsFolder = true, Children =
                    {
                        new() { Name = "config.lua" }
                    }},
                    new() { Name = "sql", IsFolder = true, Children =
                    {
                        new() { Name = "police_system.sql" }
                    }},
                    new() { Name = "fxmanifest.lua" },
                    new() { Name = "README.md" }
                }
            }
        };

        Messages = new ObservableCollection<ChatMessage>();

        _fileBank = BuildFileBank();

        // Pre-load the police_server.lua so the Code Preview shows something.
        OpenFile("server/police_server.lua");

        Log("NeuraDeV gestartet.");
        Log("Lokale KI-Engine: Templates aktiv. Bereit für deine Anfrage.");
    }

    // ─────────────────────────────────────────────────────────────────────
    // Commands
    // ─────────────────────────────────────────────────────────────────────

    [RelayCommand]
    private void SelectNav(NavItem? item)
    {
        if (item is null) return;
        foreach (var n in NavItems) n.IsActive = false;
        item.IsActive = true;

        // Each nav slot primes the chat input for its purpose.
        (InputPlaceholder, DraftInput) = item.Key switch
        {
            "dashboard" => ("Frage zum Projektstatus...", string.Empty),
            "chat"      => ("Nachricht an NeuraDeV...", string.Empty),
            "explorer"  => ("Datei suchen oder beschreiben...", string.Empty),
            "scripts"   => ("Beschreibe das FiveM-Script: ", "Generiere ein FiveM Script: "),
            "debug"     => ("Beschreibe den Fehler...", "Debugge folgenden Code:\n\n"),
            "config"    => ("Beschreibe die Config-Datei...", "Erstelle eine Config (Lua/JSON/SQL): "),
            "tests"     => ("Welche Module sollen getestet werden?", "Schreibe Tests für: "),
            "ui"        => ("Beschreibe das UI...", "Generiere ein NUI-Menü: "),
            "db"        => ("Welche Tabellen / welcher Use-Case?", "Erstelle ein SQL Schema für: "),
            "settings"  => ("Einstellungen — wähle einen Bereich", string.Empty),
            _           => ("Nachricht an NeuraDeV...", string.Empty)
        };

        if (item.Key == "settings") ShowSettings();
        Log($"Nav: {item.Title}");
    }

    [RelayCommand]
    private void SelectTab(string? index)
    {
        if (!int.TryParse(index, out var i)) return;
        IsTabCode   = i == 0;
        IsTabLive   = i == 1;
        IsTabLogs   = i == 2;
        IsTabErrors = i == 3;
    }

    [RelayCommand]
    private void ApplyAction(string? action)
    {
        DraftInput = action switch
        {
            "generate" => "Generiere folgendes Modul: ",
            "fix"      => "Behebe folgenden Fehler:\n\n" + CodeContent,
            "explain"  => "Erkläre folgenden Code Schritt für Schritt:\n\n" + CodeContent,
            "improve"  => "Verbessere folgenden Code (Performance, Sicherheit, Stil):\n\n" + CodeContent,
            _ => DraftInput
        };
    }

    [RelayCommand]
    private async Task SendAsync()
    {
        var text = (DraftInput ?? string.Empty).Trim();
        if (text.Length == 0) return;

        Messages.Add(new ChatMessage
        {
            Role = ChatRole.User, Author = "User", Text = text, IsUser = true
        });
        DraftInput = string.Empty;

        Log($"Anfrage: {Trim(text, 60)}");
        AssistantReply reply;
        try
        {
            reply = await _engine.AskAsync(text, _projectCtx);
        }
        catch (Exception ex)
        {
            Log($"FEHLER: {ex.Message}");
            Messages.Add(new ChatMessage
            {
                Role = ChatRole.Assistant, Author = "NeuraDeV AI",
                Text = $"⚠️ Engine-Fehler: {ex.Message}", IsAssistant = true
            });
            return;
        }

        var msg = new ChatMessage
        {
            Role = ChatRole.Assistant,
            Author = "NeuraDeV AI",
            Text = reply.Text,
            StatusLine = reply.StatusLine,
            Progress = reply.Progress,
            IsAssistant = true
        };
        foreach (var p in reply.Plan)
            msg.Plan.Add(new PlanStep { Title = p.Title, IsDone = p.IsDone });
        Messages.Add(msg);

        // Update right panel with the first generated file.
        if (reply.Files.Count > 0)
        {
            var first = reply.Files[0];
            ActiveFileName = Path.GetFileName(first.Path);
            CodeContent = first.Content;
            CodeLanguage = first.Language;
            IsTabCode = true; IsTabLive = IsTabLogs = IsTabErrors = false;
            Log($"Generiert: {reply.Files.Count} Datei(en). Aktiv: {ActiveFileName}");
        }

        // Errors tab
        Errors.Clear();
        foreach (var d in reply.Diagnostics.Errors) Errors.Add(d);
        foreach (var d in reply.Diagnostics.Warnings) Errors.Add(d);
        if (reply.Diagnostics.Errors.Count > 0)
            Log($"⚠ {reply.Diagnostics.Errors.Count} Fehler erkannt.");
    }

    [RelayCommand]
    private void SaveCode()
    {
        if (string.IsNullOrEmpty(CodeContent))
        {
            MessageBox.Show("Kein Code zum Speichern.", "NeuraDeV", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        var dlg = new SaveFileDialog
        {
            FileName = ActiveFileName,
            Filter = CodeLanguage switch
            {
                "lua"      => "Lua (*.lua)|*.lua|Alle Dateien|*.*",
                "sql"      => "SQL (*.sql)|*.sql|Alle Dateien|*.*",
                "html"     => "HTML (*.html)|*.html|Alle Dateien|*.*",
                "css"      => "CSS (*.css)|*.css|Alle Dateien|*.*",
                "js"       => "JavaScript (*.js)|*.js|Alle Dateien|*.*",
                "markdown" => "Markdown (*.md)|*.md|Alle Dateien|*.*",
                _          => "Alle Dateien|*.*"
            }
        };
        if (dlg.ShowDialog() == true)
        {
            File.WriteAllText(dlg.FileName, CodeContent);
            Log($"Gespeichert: {dlg.FileName}");
        }
    }

    [RelayCommand]
    private void CopyCode()
    {
        if (string.IsNullOrEmpty(CodeContent)) return;
        Clipboard.SetText(CodeContent);
        Log("Code in Zwischenablage kopiert.");
    }

    [RelayCommand]
    private void NewFile()
    {
        ProjectTree[0].Children.Add(new ProjectNode { Name = $"untitled-{DateTime.Now:HHmmss}.lua" });
        Log("Neue Datei in Projekt aufgenommen.");
    }

    [RelayCommand]
    private void ClearChat()
    {
        Messages.Clear();
        Log("Chat geleert.");
    }

    [RelayCommand]
    private void ShowTeam() =>
        MessageBox.Show("Team-Mitglieder:\n\n• Developer (Admin) — du\n\nMehr-Benutzer-Setup ist auf der Roadmap.",
            "NeuraDeV — Team", MessageBoxButton.OK, MessageBoxImage.Information);

    [RelayCommand]
    private void ShowNotifications() =>
        MessageBox.Show("Aktuelle Benachrichtigungen:\n\n• Engine bereit\n• Lokale KI: Templates aktiv\n• 1 Update verfügbar (Roadmap)",
            "NeuraDeV — Benachrichtigungen", MessageBoxButton.OK, MessageBoxImage.Information);

    [RelayCommand]
    private void ShowSettings()
    {
        var llmHint = _engine.HasLlm
            ? "✓ Lokales LLM ist aktiv."
            : "✗ Kein LLM geladen. Optional: GGUF-Modell unter %LOCALAPPDATA%\\NeuraDeV\\models\\ ablegen.";
        MessageBox.Show(
            $"Engine: {EngineStatus}\n" +
            $"{llmHint}\n\n" +
            $"Projekt: {_projectCtx.ProjectName}\n" +
            $"Framework: {_projectCtx.Framework}\n" +
            $"Memory-Verzeichnis: %LOCALAPPDATA%\\NeuraDeV\\memory\\\n" +
            $"Log-Verzeichnis: %LOCALAPPDATA%\\NeuraDeV\\logs\\",
            "NeuraDeV — Einstellungen", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    // ─────────────────────────────────────────────────────────────────────
    // File operations (called from code-behind on TreeView selection)
    // ─────────────────────────────────────────────────────────────────────

    public void OpenFile(string path)
    {
        if (_fileBank.TryGetValue(path, out var entry))
        {
            CodeContent = entry.Content;
            CodeLanguage = entry.Language;
            ActiveFileName = Path.GetFileName(path);
            IsTabCode = true; IsTabLive = IsTabLogs = IsTabErrors = false;
            Log($"Geöffnet: {path}");
            return;
        }

        // Search by filename (tree nodes don't carry their parent path)
        var name = Path.GetFileName(path);
        var hit = _fileBank.FirstOrDefault(kv => kv.Key.EndsWith(name, StringComparison.OrdinalIgnoreCase));
        if (hit.Key != null)
        {
            CodeContent = hit.Value.Content;
            CodeLanguage = hit.Value.Language;
            ActiveFileName = name;
            IsTabCode = true; IsTabLive = IsTabLogs = IsTabErrors = false;
            Log($"Geöffnet: {hit.Key}");
        }
    }

    private Dictionary<string, (string Content, string Language)> BuildFileBank()
    {
        var bank = new Dictionary<string, (string, string)>(StringComparer.OrdinalIgnoreCase);
        var lib = new TemplateLibrary();
        foreach (var f in lib.QbCorePoliceJob(_projectCtx))
            bank[f.Path] = (f.Content, f.Language);

        bank["README.md"] = (
            "# my_fivem_project\n\nGeneriert mit NeuraDeV.\n\nKomplette QBCore Police-Job-Implementierung.\n",
            "markdown");

        return bank;
    }

    private void Log(string line) => Logs.Insert(0, $"[{DateTime.Now:HH:mm:ss}] {line}");

    private static string Trim(string s, int max) => s.Length <= max ? s : s[..(max - 3)] + "...";
}
