# NeuraDeV

> KI-Entwicklerplattform für FiveM, C#/.NET und Script-Generierung
> als native **Windows Desktop App** (WPF, .NET 8).

Modernes Developer-UI im Stil von Cursor / Linear / Claude:
Dark Mode, Neon Blau/Violett, Glassmorphismus, Vektor-Logo (Brain + Code-Circuits).

```
┌─ Titlebar ──────────────────────────────────────────────────────────────┐
│ [Logo] NeuraDeV                  [team][⚙][🔔₃]  [Developer/Admin] _ □ × │
├──────────┬─────────────┬───────────────────────────┬───────────────────┤
│ Dashboard│ Project     │ NeuraDeV AI Assistant     │ Code Preview      │
│ Chat ●   │ Explorer    │                           │  Live Vorschau    │
│ ...      │ my_fivem... │  User: Mach mir ein ...   │  Logs / Errors    │
│          │ ├ server    │                           │                   │
│          │ ├ client    │  NeuraDeV AI:             │  police_server.lua│
│          │ ├ ui        │   ✓ 1. Datenbank          │  (Lua highlighted)│
│          │ ├ config    │   ✓ 2. Server-Script ...  │                   │
│          │ └ sql       │   ▮▮▮▮▮▯▯▯▯▯ 22%          │  [Save] [Copy]    │
│          │             │  [Code] [Fix] [Erkl.]     ├───────────────────┤
│ ●Online  │             │                           │ Live Vorschau     │
│ localhost│             │  [Nachricht...     ➤]    │ POLIZEI MENÜ      │
│ 0/32     │             │                           │ □ □ □ □           │
└──────────┴─────────────┴───────────────────────────┴───────────────────┘
```

## Build & Start

Voraussetzungen: **.NET 8 SDK** (Windows).

```pwsh
cd NeuraDeV
dotnet restore
dotnet run --project src/NeuraDeV
```

Release-Build (Single-File Executable):

```pwsh
dotnet publish src/NeuraDeV -c Release -r win-x64 --self-contained false `
  -p:PublishSingleFile=true
```

Ausgabe unter `src/NeuraDeV/bin/Release/net8.0-windows/win-x64/publish/NeuraDeV.exe`.

## Architektur

```
NeuraDeV.sln
└── src/NeuraDeV/
    ├── App.xaml(.cs)                  Resource-Dictionary Loader
    ├── MainWindow.xaml(.cs)           Komplette UI (Header + 4 Panels)
    │
    ├── Themes/
    │   ├── Colors.xaml                Farbpalette + Neon-Gradients
    │   └── Styles.xaml                Buttons, Tabs, TreeView, ScrollBars
    │
    ├── Controls/
    │   └── NeuraLogo.xaml(.cs)        Vektor-Logo (Brain + Code-Brackets)
    │
    ├── ViewModels/
    │   └── MainViewModel.cs           MVVM Root (CommunityToolkit.Mvvm)
    │
    ├── Models/
    │   ├── NavItem.cs                 Sidebar-Eintrag
    │   ├── ProjectNode.cs             File-Tree-Knoten
    │   ├── ChatMessage.cs             User/Assistant-Nachricht
    │   ├── PlanStep.cs                Plan-Schritt mit Checkmark
    │   └── CodeToken.cs               Token für Syntax-Highlight
    │
    └── Services/
        ├── IAiService.cs              Contract für KI-Backend
        └── MockAiService.cs           Demo-Implementierung (Police-Flow)
```

## KI-Backend anbinden

`MockAiService` durch eine echte Implementierung ersetzen:

```csharp
public sealed class ClaudeAiService : IAiService
{
    private readonly Anthropic.Client _client;

    public ClaudeAiService(string apiKey)
        => _client = new Anthropic.Client(apiKey);

    public async Task<ChatMessage> RespondAsync(string userInput)
    {
        var response = await _client.Messages.CreateAsync(new()
        {
            Model = "claude-opus-4-7",
            MaxTokens = 4096,
            Messages = [ new() { Role = "user", Content = userInput } ]
        });

        return new ChatMessage
        {
            Role = ChatRole.Assistant,
            Author = "NeuraDeV AI",
            Text = response.Content[0].Text,
            IsAssistant = true
        };
    }
}
```

Im `MainViewModel` injecten — DI-Container (Microsoft.Extensions.DependencyInjection)
hinzufügen, falls die App wächst.

## Roadmap

- [x] Layout 1:1 zum Mockup (Header, Sidebar, Explorer, Chat, Code, Preview)
- [x] Vektor-Logo (Brain + Code-Circuits) als reusable UserControl
- [x] MVVM mit CommunityToolkit.Mvvm Source-Generators
- [x] Custom Window-Chrome (eigene Min/Max/Close)
- [x] Sidebar-Navigation mit Active-State + Glow
- [x] TreeView mit Lua/SQL/HTML/CSS-Icon-Farben
- [x] Lua-Syntax-Highlight (statisch) im Code Preview
- [x] Police-Job-Demo-Flow (Plan + Progress + Live Vorschau)
- [ ] Echte Anthropic API Integration
- [ ] Persistent Memory (LiteDB/SQLite)
- [ ] AvalonEdit für volle Code-Editor-Funktionalität
- [ ] FiveM Server Status (TCP-Ping localhost:30120)
- [ ] Project Save/Load (JSON/SQLite)
- [ ] Multi-Project Tabs
