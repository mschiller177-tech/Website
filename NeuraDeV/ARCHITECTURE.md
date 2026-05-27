# NeuraDeV — Architektur

## Designprinzipien

1. **Offline-first.** Kein externer KI-Dienst nötig. Wer ein lokales Modell
   lädt, bekommt zusätzliche Kreativität — wer keines lädt, bekommt
   deterministische Template-Generatoren, die für FiveM-Standardarbeit
   reichen.
2. **Hybrid-Reasoning.** Regelbasierter Planner zuerst, LLM-Fallback nur
   für unbekannte Intents. Dadurch bleibt der Output vorhersagbar und
   schnell, mit echter KI als Notnagel.
3. **Saubere Trennung.** Engine (`NeuraDeV.Engine`) hängt nicht von WPF ab
   und kann genauso aus einer CLI, einem Visual-Studio-Plugin oder einem
   Test-Harness genutzt werden.
4. **Production-ready Output.** Templates erzeugen vollständige Module
   inkl. SQL, server/client, NUI, Config, Manifest — nie halbe Snippets.

---

## Schichtenmodell

```
┌─────────────────────────────────────────────────────────────────┐
│  NeuraDeV (WPF, .NET 8)                                         │
│  ────────────────────────────────────────────────────────────   │
│  Views      MainWindow.xaml + Controls/NeuraLogo                │
│  ViewModels MainViewModel (MVVM via CommunityToolkit.Mvvm)      │
│  Models     ChatMessage, PlanStep, ProjectNode, NavItem         │
└────────────────────────────┬────────────────────────────────────┘
                             │  INeuraEngine.AskAsync(input, ctx)
┌────────────────────────────┴────────────────────────────────────┐
│  NeuraDeV.Engine (netstandard-kompatibles .NET 8)               │
│  ────────────────────────────────────────────────────────────   │
│                                                                 │
│   1. Security        InputValidator → PermissionGuard           │
│        ↓                                                        │
│   2. Reasoning       IntentClassifier → Planner                 │
│        ↓                                                        │
│   3. Execution       TemplateLibrary  (deterministisch)         │
│        OR                                                       │
│        ILlmRuntime → LlamaCppRuntime  (lokales LLM, optional)   │
│        ↓                                                        │
│   4. Analysis        LuaLinter (+ CSharpAnalyzer/SqlChecker)    │
│        ↓                                                        │
│   5. Memory          ProjectMemory (JSON, später SQLite)        │
│        ↓                                                        │
│   ──→ AssistantReply (Text, Plan, Files, Diagnostics)           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Ein Turn — von Eingabe bis Code

```
User tippt:  "Mach mir ein Police Job System für FiveM"
                          │
                          ▼
┌──────────────────────────────────────────┐
│ InputValidator                           │   blockt:
│   length > 8 000? Shell-Befehle?         │   - leere Eingabe
│   Secrets-Pattern?                       │   - "rm -rf", "format c:"
└──────────────────────────────────────────┘   - sk-/ghp_-Tokens
                          │
                          ▼
┌──────────────────────────────────────────┐
│ IntentClassifier                         │   liefert
│   regex/keyword-Matching                 │   Intent.QbCorePoliceJob
└──────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────┐
│ Planner                                  │   Plan {
│   bekannte Intents → fester Plan         │     Steps: [DB, Server, Client,
│   Unknown        → LLM Fallback          │             UI, Config],
└──────────────────────────────────────────┘     Progress: 0.22 }
                          │
                          ▼
┌──────────────────────────────────────────┐
│ TemplateLibrary                          │   8 Dateien:
│   QbCorePoliceJob()                      │   sql/police_system.sql
│                                          │   server/police_server.lua
│                                          │   client/police_client.lua
│                                          │   ui/{index.html,style.css,script.js}
│                                          │   config/config.lua
│                                          │   fxmanifest.lua
└──────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────┐
│ LuaLinter                                │   Diagnostics:
│   Klammer-Bilanz, loadstring,            │   keine Fehler,
│   client-trust events,                   │   0–2 Warnungen
│   QBCore-Import                          │
└──────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────┐
│ ProjectMemory                            │   schreibt:
│   recordTurn(project, input, plan, files)│   %LOCALAPPDATA%\NeuraDeV\
└──────────────────────────────────────────┘   memory\my_fivem_project.json
                          │
                          ▼
                   AssistantReply
                          │
                          ▼
                   MainViewModel
                          │
                          ▼
                  Chat-UI Update
                  (Plan + Progress + Files)
```

---

## Komponenten im Detail

### `INeuraEngine`
Top-Level-Fassade. Eine einzige Methode: `AskAsync(input, context) → AssistantReply`.
Drop-in austauschbar — Tests, CLI-Adapter oder VS-Plugin nutzen die gleiche API.

### `IntentClassifier`
Schneller Regex-/Keyword-Klassifizierer. Transparent (kein "Black Box"),
deterministisch, in <1 ms. Erkennt aktuell: QbCorePoliceJob,
FiveMResourceScaffold, NuiMenu, SqlSchema, ConfigFile, Debug, Explain,
TestGenerator.

Erweiterung: neuen Enum-Wert + Regel hinzufügen.

### `Planner`
Wandelt Intent → Plan + Dateien. Bekannte Intents werden komplett
deterministisch erfüllt (über die `TemplateLibrary`). Bei `Intent.Unknown`
springt der LLM-Fallback (`ILlmRuntime.CompleteAsync`) ein.

### `TemplateLibrary`
Versammelt sämtliche eingebauten Generatoren. Aktuell:

| Intent                  | Erzeugte Dateien                                           |
| ----------------------- | ---------------------------------------------------------- |
| QbCorePoliceJob         | SQL, Server/Client Lua, NUI (HTML/CSS/JS), Config, FxManif |
| FiveMResourceScaffold   | fxmanifest, server/main, client/main, config               |
| NuiMenu                 | HTML, CSS, JS, Client-Lua                                  |
| SqlSchema               | generisches normalisiertes Schema                          |
| ConfigFile              | Lua-Config-Stub                                            |

Neue Templates: Const-String + Methode + Mapping im Planner.

### `ILlmRuntime` & Implementierungen
- **`TemplateRuntime`** (default) — gibt strukturierte Hinweise zurück
  statt zu halluzinieren. Keine NuGet-Abhängigkeiten.
- **`LlamaCppRuntime`** (optional) — Skelett für LLamaSharp/llama.cpp.
  Aktivieren in zwei Schritten:
  1. NuGet-Pakete in `NeuraDeV.Engine.csproj` einkommentieren.
  2. GGUF-Modell in `%LOCALAPPDATA%\NeuraDeV\models\` legen
     (siehe `ModelManager.Catalog` für Empfehlungen).

### `LuaLinter`
Regex-Heuristik für die häufigsten FiveM-Fallen: `loadstring`-Injection,
Client-getriggerte Server-Events ohne Args, unausgeglichene Klammern,
unvollständiger `QBCore`-Import. Diagnostics gehen direkt ins
`AssistantReply.Diagnostics`-Feld und können in der UI als Errors-Tab
angezeigt werden.

### `ProjectMemory`
JSON-Datei pro Projekt unter `%LOCALAPPDATA%\NeuraDeV\memory\`. Jeder
Turn wird mit Zeitstempel, Intent, Plan-Schritten und erzeugten
Dateipfaden archiviert. Upgrade-Pfad: gleiche Schnittstelle, SQLite-Body.

### `InputValidator` / `PermissionGuard` / `CrashGuard`
- **InputValidator:** schneidet zu lange Inputs, blockt destruktive
  Shell-Befehle und durchgesickerte API-Tokens **vor** der Verarbeitung.
- **PermissionGuard:** drei Rollen (User/Developer/Admin). Privilegierte
  Operationen rufen `Require(Role.Admin)`.
- **CrashGuard:** AppDomain.UnhandledException + UnobservedTaskException
  werden eingefangen, in eine Rolling-Log-Datei geschrieben, optional
  per Callback an die UI gemeldet. Der Prozess stirbt nicht.

---

## Erweiterung: eigene Intents

```csharp
// 1) Intent.cs
public enum Intent { ..., Garage }

// 2) IntentClassifier.cs
if (Contains(t, "garage", "vehicle storage")) return Intent.Garage;

// 3) TemplateLibrary.cs
public IReadOnlyList<GeneratedFile> Garage(ProjectContext ctx) => new[] { /* ... */ };

// 4) Planner.cs (PlanAsync switch)
Intent.Garage => Plan.For(summary: "...", steps: [...], intent: Intent.Garage),

// 5) Planner.cs (ExecuteAsync switch)
Intent.Garage => _templates.Garage(ctx),
```

Vier kleine Ergänzungen — keine UI-Anpassung nötig.

---

## Was bewusst nicht Teil dieser Engine ist

- **Eigenes vortrainiertes LLM.** Realistisch nicht ohne GPU-Cluster und
  TB-Daten. Wir benutzen stattdessen kuratierte Open-Weights-Modelle
  (Qwen2.5-Coder, DeepSeek-Coder), die lokal laufen. *Das ist
  „deine eigene KI im Sinne von: dein Modell auf deinem Rechner, kein
  Cloud-Call".*
- **Cloud-Sync.** Optionales Feature. Memory liegt erstmal lokal —
  fügen wir einen Cloud-Adapter hinzu, bleibt die Schnittstelle gleich.
- **Voice-Coding.** Stand auf der Roadmap, nicht im Kern.
