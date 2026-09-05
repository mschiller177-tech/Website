# Agentur-MCP-Server

Verbindet die KI-Software-Agentur mit Claude — nicht nur in Claude Code, sondern in
jedem MCP-Client: Claude Desktop, Claude Code, claude.ai (über Connectors) und andere.

Das Team, seine Wissensbasis, der Projekt-Workspace und das Kommunikationsprotokoll
werden als Tools, Prompts und Ressourcen bereitgestellt.

- **Transport:** stdio
- **Abhängigkeiten:** keine — nur Python 3.9+ Standardbibliothek
- **Server-Datei:** `mcp/agentur_mcp/server.py`

## Einrichtung

### Claude Code (Projekt-Scope, empfohlen)

Im Repository liegt bereits `.mcp.json`. Beim nächsten Start fragt Claude Code einmalig
nach der Freigabe des Servers. Prüfen mit:

```bash
claude mcp list
```

Manuell hinzufügen (z. B. für ein anderes Projektverzeichnis):

```bash
claude mcp add agentur --scope user \
  --env AGENTUR_HOME=/pfad/zum/Website \
  -- python3 /pfad/zum/Website/mcp/agentur_mcp/server.py
```

### Claude Desktop

`claude_desktop_config.json` öffnen (Einstellungen → Entwickler → Konfiguration bearbeiten)
und ergänzen — **absolute Pfade** verwenden:

```json
{
  "mcpServers": {
    "agentur": {
      "command": "python3",
      "args": ["/pfad/zum/Website/mcp/agentur_mcp/server.py"],
      "env": {
        "AGENTUR_HOME": "/pfad/zum/Website",
        "AGENTUR_PROJEKT": "/pfad/zu/deinem/App-Projekt"
      }
    }
  }
}
```

Danach Claude Desktop neu starten. Die sieben Agentur-Prompts erscheinen im
Anhang-Menü (`+` → Aus MCP hinzufügen).

### Windows

- Als `command` **`python`** eintragen, nicht `python3` — letzteres öffnet den Microsoft
  Store. Führt `python --version` zu keiner Ausgabe, den vollen Pfad zu `python.exe`
  verwenden.
- Pfade mit doppelten Backslashes: `C:\\Users\\name\\Website\\mcp\\agentur_mcp\\server.py`
- Der Server stellt seine Ein- und Ausgabe selbst auf UTF-8 um. Ohne das bricht jede
  Antwort mit Sonderzeichen ab (`→`, `✓`, Umlaute) und Claude Desktop meldet
  „Server disconnected".

### Fehlersuche bei „Server disconnected"

| Prüfung | Befehl |
|---------|--------|
| Läuft Python? | `python --version` |
| Ist der Pfad richtig? | `dir "C:\...\mcp\agentur_mcp\server.py"` |
| Ist alles vollständig? | `python "C:\...\server.py" --selftest` |

Der Selbsttest nennt die Ursache im Klartext. Läuft er durch, liegt der Fehler in der
Konfigurationsdatei — meist ein Komma zu viel oder ein einfacher statt doppelter Backslash.

### Umgebungsvariablen

| Variable | Bedeutung | Standard |
|----------|-----------|----------|
| `AGENTUR_HOME` | Wurzel des Agentur-Repos (enthält `.claude/agents` und `.claude/skills`) | zwei Ebenen über `server.py` |
| `AGENTUR_PROJEKT` | Standard-Projektverzeichnis für Workspace-Tools | aktuelles Arbeitsverzeichnis |

`AGENTUR_PROJEKT` lässt sich pro Aufruf mit dem Parameter `projekt_pfad` übersteuern —
so lassen sich mehrere App-Projekte aus derselben Installation bedienen.

## Tools (15)

### Wissen und Team — nur lesend

| Tool | Zweck |
|------|-------|
| `agentur_list_team` | Alle 17 Agenten mit Rolle, Phase, Modell, Kommunikationswegen |
| `agentur_get_agent_briefing` | Vollständige Arbeitsanweisung eines Agenten — das Modell übernimmt die Rolle |
| `agentur_get_process` | Prozess, acht Phasen, Quality Gates |
| `agentur_get_reference` | Wissensbasis: kommunikation, app-grundgeruest, interaktions-checkliste, security, performance, skalierbarkeit |
| `agentur_get_template` | Vorlagen: PRD, ADR, Design-Brief, Screen-Spec, Übergabe, Board, Release-Checkliste … |
| `agentur_get_checklist` | Prüfliste als abarbeitbare Punkte statt Fließtext |

### Projekt und Gates

| Tool | Zweck |
|------|-------|
| `agentur_init_project` | Workspace anlegen: alle Phasenordner, Board, Rückfragen, Projektsteckbrief |
| `agentur_get_project_status` | Phasen, Artefakte, Design-Freigabe, offene Rückfragen, Blocker |
| `agentur_check_gate` | Quality Gate einer Phase prüfen — bestanden oder Mängelliste |
| `agentur_set_design_approval` | Das harte Design-Gate setzen (nur nach Entscheidung des Menschen) |

### Kommunikation zwischen den Agenten

| Tool | Zweck |
|------|-------|
| `agentur_get_inbox` | Posteingang eines Agenten: Board-Zeile, Übergaben, offene Nachrichten |
| `agentur_post_message` | Rückfrage, Befund, Entscheidung oder Blocker an einen anderen Agenten |
| `agentur_answer_message` | Offene Nachricht beantworten und schließen |
| `agentur_write_handover` | Übergabedokument beim Phasenwechsel |
| `agentur_update_board` | Statuszeile auf dem Agentur-Board aktualisieren |

## Prompts (7)

`agentur_start` · `agentur_design` · `agentur_build` · `agentur_check` ·
`agentur_review` · `agentur_release` · `agentur_status`

Sie entsprechen den Slash-Commands aus Claude Code und führen durch dieselben Phasen.

## Ressourcen

`agentur://prozess` · `agentur://referenz/<name>` · `agentur://agent/<name>`

## Beispiele

**1. Neues Projekt starten**

> Starte ein Projekt für eine Lauf-App mit Trainingsplänen.

Claude ruft `agentur_get_process`, dann `agentur_init_project` und arbeitet Phase 1 ab.

**2. Einen Agenten arbeiten lassen**

> Übernimm die Rolle des ui-ux-designer und mach die Design-Phase für das Onboarding.

Claude holt sich das Briefing über `agentur_get_agent_briefing`, den Posteingang über
`agentur_get_inbox` und liefert am Ende das Prompt-Pack für Claude Design.

**3. Prüfen, ob wirklich alles funktioniert**

> Prüf die App gegen Grundgerüst und Klick-Test.

Claude arbeitet `agentur_get_checklist('grundgeruest')` und `('klick-test')` ab.

**4. Gate prüfen, bevor gebaut wird**

> Darf frontend-dev schon anfangen?

`agentur_check_gate('2')` antwortet mit bestanden oder einer konkreten Mängelliste.

## Test

### Selbsttest — zuerst ausführen

```bash
python3 mcp/agentur_mcp/server.py --selftest    # Windows: python statt python3
```

Zeigt Python-Version, Ausgabekodierung, gefundene Agenten, Referenzen und Vorlagen.
Endet mit „Bereit" oder benennt, was fehlt. **Dieser Aufruf beantwortet fast jedes
Einrichtungsproblem** — insbesondere „Server disconnected" in Claude Desktop.

### Weitere Prüfungen

```bash
python3 -m py_compile mcp/agentur_mcp/server.py

printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | python3 mcp/agentur_mcp/server.py
```

Interaktiv mit dem offiziellen Inspector:

```bash
npx @modelcontextprotocol/inspector python3 mcp/agentur_mcp/server.py
```

## Sicherheitshinweise

- Der Server hat **keinen Netzwerkzugriff** und ruft keine externen Dienste auf
  (`openWorldHint: false`).
- Schreibende Tools arbeiten ausschließlich im angegebenen Projektverzeichnis unterhalb
  von `agentur/`. Vorhandene Dateien werden von `agentur_init_project` nicht überschrieben.
- Agenten- und Dokumentnamen werden gegen feste Listen geprüft — keine Pfadangaben aus
  Modelleingaben.
- Es werden keine Zugangsdaten gelesen, gespeichert oder übertragen.
