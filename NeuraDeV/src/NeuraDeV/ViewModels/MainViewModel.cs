using System.Collections.ObjectModel;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NeuraDeV.Models;
using NeuraDeV.Services;

namespace NeuraDeV.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly IAiService _ai;

    public ObservableCollection<NavItem> NavItems { get; }
    public ObservableCollection<ProjectNode> ProjectTree { get; }
    public ObservableCollection<ChatMessage> Messages { get; }
    public ObservableCollection<CodeToken> CodeTokens { get; }

    [ObservableProperty] private string activeFileName = "police_server.lua";
    [ObservableProperty] private string draftInput = string.Empty;
    [ObservableProperty] private string serverHost = "localhost";
    [ObservableProperty] private string serverPlayers = "0/32";
    [ObservableProperty] private bool serverOnline = true;

    public MainViewModel() : this(new MockAiService()) { }

    public MainViewModel(IAiService ai)
    {
        _ai = ai;

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

        // Pre-seed the assistant reply that matches the screenshot
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

        CodeTokens = BuildPoliceServerLua();
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

        var reply = await _ai.RespondAsync(text);
        Messages.Add(reply);
    }

    /// Hand-tokenised Lua snippet shown in the Code Preview panel.
    /// Matches the police_server.lua excerpt from the screenshot.
    private static ObservableCollection<CodeToken> BuildPoliceServerLua()
    {
        var t = new ObservableCollection<CodeToken>();
        void K(string s) => t.Add(new CodeToken(s, CodeTokenKind.Keyword));
        void Str(string s) => t.Add(new CodeToken(s, CodeTokenKind.String));
        void Num(string s) => t.Add(new CodeToken(s, CodeTokenKind.Number));
        void Cmt(string s) => t.Add(new CodeToken(s, CodeTokenKind.Comment));
        void Fn(string s) => t.Add(new CodeToken(s, CodeTokenKind.Function));
        void Id(string s) => t.Add(new CodeToken(s, CodeTokenKind.Identifier));
        void P(string s) => t.Add(new CodeToken(s, CodeTokenKind.Plain));

        K("local "); Id("QBCore"); P(" = "); Id("exports"); P("["); Str("'qb-core'"); P("]:"); Fn("GetCoreObject"); P("()\n\n");
        Cmt("-- Polizeijob definieren\n");
        Id("QBCore"); P("."); Id("Functions"); P("."); Fn("CreateJob"); P("("); Str("\"police\""); P(", {\n");
        P("    "); Id("label"); P(" = "); Str("'Polizei'"); P(",\n");
        P("    "); Id("defaultDuty"); P(" = "); K("true"); P(",\n");
        P("    "); Id("offDutyPay"); P(" = "); K("true"); P(",\n");
        P("    "); Id("grades"); P(" = {\n");
        P("        ["); Num("0"); P("] = { "); Id("name"); P(" = "); Str("'Rekrut'");    P(", "); Id("payment"); P(" = "); Num("50");  P(" },\n");
        P("        ["); Num("1"); P("] = { "); Id("name"); P(" = "); Str("'Offizier'");  P(", "); Id("payment"); P(" = "); Num("100"); P(" },\n");
        P("        ["); Num("2"); P("] = { "); Id("name"); P(" = "); Str("'Sergeant'");  P(", "); Id("payment"); P(" = "); Num("150"); P(" },\n");
        P("        ["); Num("3"); P("] = { "); Id("name"); P(" = "); Str("'Leutnant'");  P(", "); Id("payment"); P(" = "); Num("200"); P(" },\n");
        P("        ["); Num("4"); P("] = { "); Id("name"); P(" = "); Str("'Kommandant'");P(", "); Id("payment"); P(" = "); Num("250"); P(" },\n");
        P("    },\n");
        P("})");

        return t;
    }
}
