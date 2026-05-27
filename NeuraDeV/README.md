# NeuraDeV

> **Eigenständige, offline-fähige KI-Entwicklerplattform** für FiveM, C#/.NET und
> Script-Generierung. Native Windows-Desktop-App (WPF, .NET 8) mit eingebauter,
> lokaler KI-Engine. Kein externer Dienst nötig.

```
NeuraDeV/
├── NeuraDeV.sln                 ← in Visual Studio öffnen
├── ARCHITECTURE.md              ← komplettes Architekturbild
├── src/
│   ├── NeuraDeV/                ← WPF-Frontend (UI + ViewModels)
│   │   ├── App.xaml(.cs)
│   │   ├── MainWindow.xaml(.cs)
│   │   ├── Themes/              ← Colors + Styles (Dark/Neon/Glass)
│   │   ├── Controls/NeuraLogo   ← Vektor-Logo
│   │   ├── ViewModels/
│   │   └── Models/
│   │
│   └── NeuraDeV.Engine/         ← lokale KI-Engine
│       ├── INeuraEngine.cs      ← Top-Level-Fassade
│       ├── NeuraEngine.cs       ← orchestriert alles
│       ├── Dtos.cs              ← AssistantReply, PlanItem, GeneratedFile, …
│       ├── Inference/           ← ILlmRuntime + TemplateRuntime + LlamaCpp
│       ├── Reasoning/           ← IntentClassifier + Planner + PromptBuilder
│       ├── Templates/           ← QBCore Police Job, FiveM Resource, NUI, SQL
│       ├── Analysis/            ← LuaLinter
│       ├── Memory/              ← ProjectMemory (JSON, später SQLite)
│       └── Security/            ← Input/Permission/Crash Guard + Logger
```

## Start

```pwsh
dotnet restore
dotnet run --project src/NeuraDeV
```

Voraussetzung: **.NET 8 SDK** ([Download](https://dotnet.microsoft.com/download/dotnet/8.0)).

Release-Build:

```pwsh
dotnet publish src/NeuraDeV -c Release -r win-x64 --self-contained false `
  -p:PublishSingleFile=true
```

Die fertige `NeuraDeV.exe` liegt in
`src/NeuraDeV/bin/Release/net8.0-windows/win-x64/publish/`.

## Wie die KI funktioniert

NeuraDeV macht **keine Cloud-Calls**. Stattdessen drei Schichten:

1. **Deterministischer Planner + Template-Engine** — erledigt 80 % typischer
   FiveM-Arbeit regelbasiert (komplette Police-Jobs, NUI-Menüs, SQL-Schemata,
   Resource-Scaffolding). Schnell, vorhersagbar, fehlerarm.
2. **Lokales LLM** (optional, via [LLamaSharp](https://github.com/SciSharp/LLamaSharp)) —
   für kreative Anfragen, die nicht in eine Vorlage passen. Empfohlen:
   Qwen2.5-Coder-1.5B oder DeepSeek-Coder-1.3B als GGUF-Datei. Läuft auf CPU
   oder GPU, völlig offline.
3. **Statische Analyse** (LuaLinter + Klammer-/Sicherheits-Heuristik) —
   prüft jeden generierten File-Block bevor er zum User geht.

Siehe [`ARCHITECTURE.md`](./ARCHITECTURE.md) für das ganze Bild.

## Lokales LLM aktivieren (optional)

```xml
<!-- src/NeuraDeV.Engine/NeuraDeV.Engine.csproj -->
<PackageReference Include="LLamaSharp" Version="0.19.0" />
<PackageReference Include="LLamaSharp.Backend.Cpu" Version="0.19.0" />
```

Body von `Inference/LlamaCppRuntime.cs` einkommentieren, GGUF-Modell ablegen
unter `%LOCALAPPDATA%\NeuraDeV\models\`, dann in `App.xaml.cs`:

```csharp
var llm  = new LlamaCppRuntime(modelManager.PathFor(model));
var eng  = new NeuraEngine(llm);
var main = new MainWindow { DataContext = new MainViewModel(eng) };
```

## Was die Engine kann (out of the box, ohne LLM)

| Anfrage                          | Erzeugte Dateien                                           |
| -------------------------------- | ---------------------------------------------------------- |
| "Police Job System für FiveM"    | SQL, Server/Client Lua, NUI (HTML/CSS/JS), Config, fxmanif |
| "FiveM Resource Skelett"         | fxmanifest, server/client/main, config                     |
| "NUI Menü"                       | HTML, CSS, JS + Client-Lua-Bridge                          |
| "SQL Schema für …"               | normalisierte Tabellen mit Indizes                         |
| "Konfigurationsdatei"            | Lua-Config-Stub                                            |

Alle Outputs sind vollständige Module — keine halben Snippets.

## Sicherheit

- `InputValidator` blockt zu lange Eingaben, destruktive Shell-Befehle
  (`rm -rf`, `format c:`) und durchgesickerte API-Tokens (`sk-…`, `ghp_…`).
- `PermissionGuard` mit drei Rollen (User / Developer / Admin) — privilegierte
  Operationen (Modell-Download, FS-Writes außerhalb Projekt) sind gated.
- `CrashGuard` fängt `UnhandledException` + `UnobservedTaskException`,
  schreibt ins Crash-Log (`%LOCALAPPDATA%\NeuraDeV\logs\crash.log`) und
  zeigt dem User eine MessageBox — der Prozess stirbt nicht.

## Roadmap

- [x] WPF-UI 1:1 zum Mockup
- [x] Vektor-Logo als reusable Control
- [x] `NeuraDeV.Engine` (Planner + Templates + Linter + Memory + Security)
- [x] QBCore Police Job als kompletter Generator
- [x] Lokale Persistenz (JSON-Memory)
- [ ] `LlamaCppRuntime` produktiv (LLamaSharp aktivieren)
- [ ] SQLite-Memory + Embeddings für semantische Suche
- [ ] AvalonEdit als Code-Viewer mit Live-Diff
- [ ] Roslyn-Analyzer für C#-Output
- [ ] FiveM Server Live Status (TCP-Ping localhost:30120)
- [ ] Plugin-System für eigene Templates / Tools
