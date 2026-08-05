# FiveM Dev Assistant — MCP Server

MCP-Server für die FiveM/CFX-Entwicklung. Läuft lokal über **stdio** und stellt einem
KI-Assistenten Werkzeuge für Natives, NUI, Resource-Gerüste, Framework-Snippets und
Doku-Suche bereit.

Phase 1 des Projekts **FiveM Dev Assistant**. Alle Daten liegen als lokales JSON im
Paket — der Server geht zur Laufzeit **nie** ins Netz.

---

## Status

| Werkzeug | Zweck | Status |
|---|---|---|
| `fivem_natives_lookup` | Natives per Name, Hash oder Freitext im Offline-Cache suchen | **implementiert** |
| `fivem_nui_generate` | NUI aus HTML/CSS/JS erzeugen | Schema steht, Implementierung offen |
| `fivem_resource_scaffold` | Resource-Gerüst je Framework erzeugen | Schema steht, Implementierung offen |
| `fivem_framework_snippet` | Idiomatische Snippets für ESX/QBCore/Qbox/Standalone | Schema steht, Implementierung offen |
| `fivem_docs_search` | Zwischengespeicherte CFX-/Framework-Doku durchsuchen | Schema steht, Implementierung offen |

Die vier offenen Werkzeuge sind bereits mit ihren **endgültigen Eingabe-Schemata**
registriert. Ein Aufruf liefert eine klare Fehlermeldung mit dem geplanten Verhalten —
kein stiller Fehlschlag und keine erfundene Ausgabe.

---

## Installation

```bash
cd fivem-dev-assistant/mcp-server
npm install
npm run build
```

Voraussetzung: Node.js ≥ 18.

### Natives-Cache aktualisieren

Mitgeliefert ist ein **von Hand gepflegter Seed-Satz mit 31 Natives**, damit der Server
sofort ohne Netz funktioniert. Den vollständigen Satz aus der offiziellen
CFX-Dokumentation holst du explizit:

```bash
npm run natives:update
```

Das Skript lädt `natives.json` und `natives_cfx.json` von `runtime.fivem.net`,
normalisiert beide und schreibt `data/natives.json` neu. Solange der Seed aktiv ist,
weist **jede** Antwort des Lookup-Werkzeugs darauf hin.

---

## Einbinden

### Claude Code

```bash
claude mcp add fivem-dev-assistant -- node /absoluter/pfad/zu/mcp-server/dist/index.js
```

### Andere MCP-Clients (`mcp.json` o. ä.)

```json
{
  "mcpServers": {
    "fivem-dev-assistant": {
      "command": "node",
      "args": ["/absoluter/pfad/zu/mcp-server/dist/index.js"]
    }
  }
}
```

### Prüfen

```bash
node dist/index.js --help     # Übersicht, ohne den Server zu starten
npm run inspect               # MCP Inspector gegen den gebauten Server
```

---

## Konfiguration

| Variable | Bedeutung | Default |
|---|---|---|
| `FIVEM_MCP_DATA_DIR` | Verzeichnis mit `natives.json` | `<paket>/data` |

Keine Keys, keine Tokens, keine hartkodierten Pfade. Der Server schreibt ausschließlich
nach `stderr` — `stdout` gehört dem MCP-Protokoll.

---

## `fivem_natives_lookup`

```
query            Name, Hash oder Freitext: "GetEntityCoords", "0x3FEF770D40960D5A", "vehicle engine"
apiset           optional "client" | "server" — Shared-Natives sind immer enthalten
namespace        optional "ENTITY", "VEHICLE", "CFX", ...
limit            1–50 (Default 10)
offset           Paging (Default 0)
response_format  "markdown" (Default) | "json"
```

Die Suche kombiniert exakte Treffer auf Name/Hash mit einem IDF-gewichteten
Token-Index. Generische Wortteile wie `get` reichen allein nicht für einen Treffer,
sonst würde jede Anfrage die halbe Datenbank zurückgeben.

Greift ein Filter zu hart, sagt die Fehlermeldung, wo das Native tatsächlich liegt:

```
Error: No natives matched 'SetNuiFocus' with apiset='server'.
Hint: 'SetNuiFocus' exists but is in namespace CFX with apiset 'client'. Drop or change the filter to see it.
```

---

## Projektstruktur

```
mcp-server/
├── data/natives.json          # Offline-Cache (Seed, per natives:update ersetzt)
├── scripts/fetch-natives.ts   # Cache-Update, expliziter Schritt
└── src/
    ├── index.ts               # Einstiegspunkt, stdio-Transport
    ├── constants.ts           # Pfade, Limits, Upstream-URLs
    ├── types.ts               # Gemeinsame Typen
    ├── services/
    │   ├── natives.ts         # Laden, Index, Suche
    │   └── result.ts          # Einheitliche Tool-Ergebnisse und Fehler
    └── tools/
        ├── natives-lookup.ts  # implementiert
        └── planned.ts         # die vier offenen Werkzeuge
```

---

## Entwicklung

```bash
npm run dev      # tsx watch
npm run build    # tsc -> dist/
npm start        # gebauten Server starten
```

Ein neues Werkzeug wird implementiert, indem sein Eintrag aus `src/tools/planned.ts`
entfernt und eine eigene `register*`-Datei nach dem Muster von `natives-lookup.ts`
ergänzt wird. Das Eingabe-Schema wandert dabei unverändert mit.
