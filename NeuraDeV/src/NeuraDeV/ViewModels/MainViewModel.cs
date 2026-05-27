using System.Collections.ObjectModel;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NeuraDeV.Engine;
using NeuraDeV.Models;

namespace NeuraDeV.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly INeuraEngine _engine;
    private ProjectContext _projectCtx;

    public ObservableCollection<NavItem> NavItems { get; }
    public ObservableCollection<ProjectNode> ProjectTree { get; }
    public ObservableCollection<ChatMessage> Messages { get; }

    [ObservableProperty] private string activeFileName = "police_server.lua";
    [ObservableProperty] private string draftInput = string.Empty;
    [ObservableProperty] private string serverHost = "localhost";
    [ObservableProperty] private string serverPlayers = "0/32";
    [ObservableProperty] private bool serverOnline = true;
    [ObservableProperty] private string engineStatus = "Lokale KI: Templates aktiv (kein LLM geladen)";

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
            new() { Title = "Dashboard",        Icon = "", Key = "dashboard" },
            new() { Title = "Chat",             Icon = "", Key = "chat", IsActive = true },
            new() { Title = "Projekt Explorer", Icon = "", Key = "explorer" },
            new() { Title = "Script Generator", Icon = "", Key = "scripts" },
            new() { Title = "Debug Assistant",  Icon = "", Key = "debug" },
            new() { Title = "Config Builder",   Icon = "", Key = "config" },
            new() { Title = "Test Generator",   Icon = "", Key = "tests" },
            new() { Title = "UI Generator",     Icon = "", Key = "ui" },
            new() { Title = "Datenbank",        Icon = "", Key = "db" },
            new() { Title = "Einstellungen",    Icon = "", Key = "settings" }
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

        Messages = new ObservableCollection<ChatMessage>
        {
            new()
            {
                Role = ChatRole.User,
                Author = "User",
                Text = "Mach mir ein Police Job System für FiveM",
                IsUser = true
            }
        };

        var seed = new ChatMessage
        {
            Role = ChatRole.Assistant,
            Author = "NeuraDeV AI",
            Text = "Verstanden! Ich werde ein komplettes Police Job System für FiveM erstellen. Hier ist der Plan:",
            StatusLine = "Schritt 1/5: Datenbank erstellen",
            Progress = 0.22,
            IsAssistant = true
        };
        seed.Plan.Add(new PlanStep { Title = "1. Datenbank erstellen", IsDone = true });
        seed.Plan.Add(new PlanStep { Title = "2. Server-Script entwickeln", IsDone = true });
        seed.Plan.Add(new PlanStep { Title = "3. Client-Script entwickeln", IsDone = true });
        seed.Plan.Add(new PlanStep { Title = "4. UI für Polizei Menü erstellen", IsDone = true });
        seed.Plan.Add(new PlanStep { Title = "5. Konfiguration hinzufügen", IsDone = true });
        Messages.Add(seed);
    }

    [RelayCommand]
    private void SelectNav(NavItem? item)
    {
        if (item is null) return;
        foreach (var n in NavItems) n.IsActive = false;
        item.IsActive = true;
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

        var reply = await _engine.AskAsync(text, _projectCtx);

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
    }
}
