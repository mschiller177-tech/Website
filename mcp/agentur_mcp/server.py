#!/usr/bin/env python3
"""MCP-Server der KI-Software-Agentur.

Stellt das komplette Agentur-Team, seine Wissensbasis, den Projekt-Workspace und
das Kommunikationsprotokoll als MCP-Tools bereit — nutzbar in Claude Desktop,
Claude Code und jedem anderen MCP-Client.

Transport: stdio (JSON-RPC 2.0, zeilenweise).
Abhängigkeiten: keine — nur die Python-Standardbibliothek.

Konfiguration über Umgebungsvariablen:
  AGENTUR_HOME     Wurzel des Agentur-Repos (Standard: zwei Ebenen über dieser Datei)
  AGENTUR_PROJEKT  Standard-Projektverzeichnis (Standard: aktuelles Arbeitsverzeichnis)
"""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any, Callable

SERVER_NAME = "agentur-mcp"
SERVER_VERSION = "1.0.0"
SUPPORTED_PROTOCOLS = ["2025-06-18", "2025-03-26", "2024-11-05"]
DEFAULT_PROTOCOL = "2025-06-18"

HOME = Path(os.environ.get("AGENTUR_HOME") or Path(__file__).resolve().parents[2])
AGENTS_DIR = HOME / ".claude" / "agents"
SKILL_DIR = HOME / ".claude" / "skills" / "software-agentur"
REF_DIR = SKILL_DIR / "references"
TPL_DIR = SKILL_DIR / "templates"

REFERENCES = {
    "kommunikation": "kommunikation.md",
    "app-grundgeruest": "app-grundgeruest.md",
    "interaktions-checkliste": "interaktions-checkliste.md",
    "security": "security.md",
    "performance": "performance.md",
    "skalierbarkeit": "skalierbarkeit.md",
}

TEMPLATES = {
    "prd": "prd.md",
    "adr": "adr.md",
    "design-brief": "design-brief.md",
    "screen-spec": "screen-spec.md",
    "design-freigabe": "design-freigabe.md",
    "release-checkliste": "release-checkliste.md",
    "projekt": "projekt.md",
    "board": "board.md",
    "uebergabe": "uebergabe.md",
    "rueckfragen": "rueckfragen.md",
}

PHASES = {
    "1": ("Anforderungen", "requirements-engineer", "01-requirements"),
    "2": ("Design (Claude Design)", "ui-ux-designer", "02-design"),
    "3": ("Architektur", "solution-architect", "03-architecture"),
    "4": ("Implementierung", "frontend-dev, backend-dev", "04-implementation"),
    "5": ("Qualitätssicherung", "qa-engineer", "05-qa"),
    "6": ("Security & Compliance", "security-reviewer", "06-security"),
    "7": ("CI/CD", "devops", "07-devops"),
    "8": ("Release", "release-manager", "08-release"),
}

PHASE_OF_AGENT = {
    "tech-lead": "alle", "requirements-engineer": "1", "ui-ux-designer": "2",
    "solution-architect": "3", "backend-dev": "4", "frontend-dev": "4",
    "qa-engineer": "5", "functional-tester": "5", "api-tester": "5",
    "performance-tester": "5", "security-tester": "5", "accessibility-tester": "5",
    "compatibility-tester": "5", "test-automation-engineer": "5",
    "security-reviewer": "6", "devops": "7", "release-manager": "8",
}

WORKSPACE_DIRS = [
    "kommunikation", "kommunikation/uebergaben", "01-requirements", "02-design",
    "02-design/screens", "03-architecture", "03-architecture/adr",
    "04-implementation", "05-qa", "05-qa/berichte", "06-security",
    "07-devops", "08-release",
]


# ---------------------------------------------------------------- Hilfsfunktionen

class ToolError(Exception):
    """Fehler mit einer für das Modell verwertbaren Handlungsanweisung."""


def read_text(path: Path) -> str:
    if not path.is_file():
        raise ToolError(f"Datei nicht gefunden: {path}")
    return path.read_text(encoding="utf-8")


def parse_frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---\n", 3)
    if end == -1:
        return {}
    data: dict[str, str] = {}
    for line in text[4:end].split("\n"):
        m = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if m:
            data[m.group(1)] = m.group(2).strip()
    return data


def extract_section(text: str, needle: str) -> str | None:
    """Gibt den Abschnitt zurück, dessen Überschrift `needle` enthält."""
    lines = text.split("\n")
    start = level = None
    for i, line in enumerate(lines):
        m = re.match(r"^(#{2,4})\s+(.*)$", line)
        if not m:
            continue
        if start is None and needle.lower() in m.group(2).lower():
            start, level = i, len(m.group(1))
        elif start is not None and len(m.group(1)) <= level:
            return "\n".join(lines[start:i]).strip()
    return "\n".join(lines[start:]).strip() if start is not None else None


def checkbox_items(text: str) -> list[str]:
    return [m.group(1).strip() for m in re.finditer(r"^\s*-\s\[[ xX]\]\s+(.*)$", text, re.M)]


def agent_names() -> list[str]:
    if not AGENTS_DIR.is_dir():
        return []
    return sorted(p.stem for p in AGENTS_DIR.glob("*.md") if p.stem != "README")


def agent_path(agent: str) -> Path:
    if agent not in agent_names():
        raise ToolError(
            f"Unbekannter Agent '{agent}'. Verfügbar: {', '.join(agent_names())}. "
            "Mit agentur_list_team gibt es die Übersicht mit Rollen."
        )
    return AGENTS_DIR / f"{agent}.md"


def project_root(arg: str | None) -> Path:
    raw = arg or os.environ.get("AGENTUR_PROJEKT") or os.getcwd()
    path = Path(raw).expanduser().resolve()
    if not path.is_dir():
        raise ToolError(
            f"Projektverzeichnis '{path}' existiert nicht. Lege es an oder gib mit "
            "'projekt_pfad' ein vorhandenes Verzeichnis an."
        )
    return path


def workspace(arg: str | None, *, muss_existieren: bool = True) -> Path:
    root = project_root(arg)
    ws = root / "agentur" if root.name != "agentur" else root
    if muss_existieren and not ws.is_dir():
        raise ToolError(
            f"Kein Agentur-Workspace unter '{ws}'. Lege ihn mit agentur_init_project an."
        )
    return ws


def append_block(path: Path, block: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text(encoding="utf-8") if path.is_file() else ""
    path.write_text(existing.rstrip() + "\n\n" + block.strip() + "\n", encoding="utf-8")


def next_message_id(text: str) -> str:
    ids = [int(n) for n in re.findall(r"MSG-(\d{3})", text)]
    return f"MSG-{max(ids) + 1:03d}" if ids else "MSG-001"


def board_cells(line: str) -> list[str]:
    """Zerlegt eine Board-Tabellenzeile; leere Liste, wenn es keine Datenzeile ist."""
    if not line.startswith("|") or re.match(r"^\|[\s\-|:]+\|$", line.strip()):
        return []
    return [c.strip() for c in line.strip().strip("|").split("|")]


def is_board_row(line: str, agent: str) -> bool:
    """Wahr nur, wenn der Agent in der Agenten-Spalte steht — nicht irgendwo in der Zeile."""
    cells = board_cells(line)
    return len(cells) >= 2 and cells[1] == agent


def as_table(rows: list[list[str]], header: list[str]) -> str:
    out = ["| " + " | ".join(header) + " |", "|" + "|".join(["---"] * len(header)) + "|"]
    out += ["| " + " | ".join(r) + " |" for r in rows]
    return "\n".join(out)


def render(payload: Any, markdown: str, fmt: str) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2) if fmt == "json" else markdown


# ------------------------------------------------------------------------- Tools

TOOLS: list[dict[str, Any]] = []


def tool(name: str, description: str, schema: dict[str, Any], **hints: bool):
    def deco(fn: Callable[[dict], str]):
        TOOLS.append({
            "name": name,
            "description": description,
            "inputSchema": {"type": "object", "properties": schema.get("properties", {}),
                            "required": schema.get("required", [])},
            "annotations": {
                "readOnlyHint": hints.get("read_only", True),
                "destructiveHint": hints.get("destructive", False),
                "idempotentHint": hints.get("idempotent", True),
                "openWorldHint": False,
            },
            "handler": fn,
        })
        return fn
    return deco


FORMAT_PROP = {
    "format": {"type": "string", "enum": ["markdown", "json"], "default": "markdown",
               "description": "Ausgabeformat. 'markdown' zum Lesen, 'json' zur Weiterverarbeitung."}
}
PROJEKT_PROP = {
    "projekt_pfad": {"type": "string",
                     "description": "Absoluter Pfad zum Projektverzeichnis. Ohne Angabe wird "
                                    "AGENTUR_PROJEKT bzw. das Arbeitsverzeichnis verwendet."}
}


@tool("agentur_list_team",
      "Listet das Agentur-Team: alle 17 spezialisierten Agenten mit Rolle, Phase, Modell und "
      "Kommunikationswegen (Posteingang/Postausgang). Startpunkt, um den passenden Agenten für "
      "eine Aufgabe zu finden.",
      {"properties": {**FORMAT_PROP,
                      "phase": {"type": "string",
                                "description": "Optional auf eine Phase filtern: 1-8."}}})
def _list_team(args: dict) -> str:
    phase = args.get("phase")
    items = []
    for name in agent_names():
        text = read_text(AGENTS_DIR / f"{name}.md")
        fm = parse_frontmatter(text)
        p = PHASE_OF_AGENT.get(name, "?")
        if phase and p not in (phase, "alle"):
            continue
        inbox = re.search(r"\*\*Posteingang von:\*\*\s*(.+)", text)
        outbox = re.search(r"\*\*Postausgang an:\*\*\s*(.+)", text)
        items.append({
            "agent": name,
            "phase": p,
            "modell": fm.get("model", "-"),
            "rolle": fm.get("description", "").split(".")[0],
            "posteingang_von": inbox.group(1).strip() if inbox else "-",
            "postausgang_an": outbox.group(1).strip() if outbox else "-",
        })
    if not items:
        raise ToolError(f"Keine Agenten für Phase '{phase}'. Gültig sind 1-8.")
    md = ("# Agentur-Team\n\n" + as_table(
        [[i["agent"], i["phase"], i["modell"], i["rolle"]] for i in items],
        ["Agent", "Phase", "Modell", "Rolle"])
        + "\n\nBriefing eines Agenten: agentur_get_agent_briefing.")
    return render({"anzahl": len(items), "agenten": items}, md, args.get("format", "markdown"))


@tool("agentur_get_agent_briefing",
      "Liefert die vollständige Arbeitsanweisung eines Agenten (Auftrag, Vorgehen, Regeln, "
      "Definition of Done, Kommunikationspflichten). Damit übernimmt das Modell die Rolle "
      "dieses Agenten und arbeitet nach dessen Standard.",
      {"properties": {
          "agent": {"type": "string", "description": "Name des Agenten, z. B. 'ui-ux-designer'."},
          "abschnitt": {"type": "string",
                        "description": "Optional nur einen Abschnitt zurückgeben, z. B. "
                                       "'Definition of Done' oder 'Kommunikation'."}},
       "required": ["agent"]})
def _briefing(args: dict) -> str:
    text = read_text(agent_path(args["agent"]))
    body = text.split("\n---\n", 1)[1].strip() if text.startswith("---\n") else text
    section = args.get("abschnitt")
    if section:
        found = extract_section(body, section)
        if not found:
            heads = re.findall(r"^##\s+(.*)$", body, re.M)
            raise ToolError(f"Abschnitt '{section}' nicht gefunden. Vorhanden: {', '.join(heads)}")
        return found
    return body


@tool("agentur_get_process",
      "Erklärt den verbindlichen Entwicklungsprozess der Agentur: acht Phasen, Quality Gates, "
      "Workspace-Struktur und die Regel 'zuerst Design in Claude Design, dann Umsetzung'.",
      {"properties": {"phase": {"type": "string",
                                "description": "Optional nur eine Phase (1-8) beschreiben."}}})
def _process(args: dict) -> str:
    text = read_text(SKILL_DIR / "SKILL.md")
    body = text.split("\n---\n", 1)[1].strip() if text.startswith("---\n") else text
    phase = args.get("phase")
    if not phase:
        return body
    if phase not in PHASES:
        raise ToolError(f"Unbekannte Phase '{phase}'. Gültig: {', '.join(PHASES)}")
    found = extract_section(body, f"Phase {phase} ")
    return found or body


@tool("agentur_get_reference",
      "Liefert ein Referenzdokument der verbindlichen Wissensbasis: kommunikation (Protokoll "
      "der Zusammenarbeit), app-grundgeruest (was jede App braucht), interaktions-checkliste "
      "(jeder Button/Feld/Nachricht funktioniert), security, performance, skalierbarkeit.",
      {"properties": {
          "dokument": {"type": "string", "enum": sorted(REFERENCES),
                       "description": "Welches Referenzdokument."},
          "abschnitt": {"type": "string",
                        "description": "Optional nur einen Abschnitt, z. B. 'Fehlerbehandlung'."}},
       "required": ["dokument"]})
def _reference(args: dict) -> str:
    key = args["dokument"]
    if key not in REFERENCES:
        raise ToolError(f"Unbekanntes Dokument '{key}'. Gültig: {', '.join(sorted(REFERENCES))}")
    text = read_text(REF_DIR / REFERENCES[key])
    section = args.get("abschnitt")
    if section:
        found = extract_section(text, section)
        if not found:
            heads = re.findall(r"^##\s+(.*)$", text, re.M)
            raise ToolError(f"Abschnitt '{section}' nicht gefunden. Vorhanden: {', '.join(heads)}")
        return found
    return text


@tool("agentur_get_template",
      "Liefert eine Arbeitsvorlage der Agentur (PRD, ADR, Design-Brief, Screen-Spezifikation, "
      "Design-Freigabe, Übergabe, Board, Rückfragen, Release-Checkliste, Projektsteckbrief) "
      "zum Ausfüllen.",
      {"properties": {"vorlage": {"type": "string", "enum": sorted(TEMPLATES),
                                  "description": "Welche Vorlage."}},
       "required": ["vorlage"]})
def _template(args: dict) -> str:
    key = args["vorlage"]
    if key not in TEMPLATES:
        raise ToolError(f"Unbekannte Vorlage '{key}'. Gültig: {', '.join(sorted(TEMPLATES))}")
    return read_text(TPL_DIR / TEMPLATES[key])


@tool("agentur_get_checklist",
      "Gibt eine Prüfliste als einzelne Punkte zurück — zum Abarbeiten statt zum Lesen. "
      "Verfügbar: grundgeruest (was jede App braucht), interaktion (Button, Feld, Formular, "
      "Nachricht, Liste), klick-test (Prüfung vor der QA-Übergabe), security, performance, "
      "skalierbarkeit, release.",
      {"properties": {
          "checkliste": {"type": "string",
                         "enum": ["grundgeruest", "interaktion", "klick-test", "security",
                                  "performance", "skalierbarkeit", "release"],
                         "description": "Welche Prüfliste."},
          **FORMAT_PROP},
       "required": ["checkliste"]})
def _checklist(args: dict) -> str:
    key = args["checkliste"]
    sources = {
        "grundgeruest": (REF_DIR / REFERENCES["app-grundgeruest"], None),
        "interaktion": (REF_DIR / REFERENCES["interaktions-checkliste"], None),
        "klick-test": (REF_DIR / REFERENCES["interaktions-checkliste"], "Klick-Test"),
        "security": (REF_DIR / REFERENCES["security"], "Kurz-Checkliste"),
        "performance": (REF_DIR / REFERENCES["performance"], "Kurz-Checkliste"),
        "skalierbarkeit": (REF_DIR / REFERENCES["skalierbarkeit"], "Kurz-Checkliste"),
        "release": (TPL_DIR / TEMPLATES["release-checkliste"], None),
    }
    if key not in sources:
        raise ToolError(f"Unbekannte Checkliste '{key}'. Gültig: {', '.join(sorted(sources))}")
    path, section = sources[key]
    text = read_text(path)
    if section:
        text = extract_section(text, section) or text
    items = checkbox_items(text)
    if key == "klick-test":
        items = [m.group(1).strip() for m in re.finditer(r"^\d+\.\s+(.*)$", text, re.M)] or items
    if not items:
        raise ToolError(f"Keine Prüfpunkte in '{key}' gefunden.")
    md = f"# Prüfliste: {key} ({len(items)} Punkte)\n\n" + "\n".join(f"- [ ] {i}" for i in items)
    return render({"checkliste": key, "anzahl": len(items), "punkte": items},
                  md, args.get("format", "markdown"))


@tool("agentur_init_project",
      "Legt den Agentur-Workspace für ein neues App-Projekt an: Ordnerstruktur für alle acht "
      "Phasen, Kommunikationsordner mit Board und Rückfragen, Projektsteckbrief. Überschreibt "
      "keine vorhandenen Dateien.",
      {"properties": {
          "app_name": {"type": "string", "description": "Name der App."},
          "plattformen": {"type": "string", "default": "iOS und Android",
                          "description": "Zielplattformen."},
          "idee": {"type": "string", "description": "Die App-Idee in einem Satz."},
          **PROJEKT_PROP},
       "required": ["app_name"]},
      read_only=False, destructive=False, idempotent=True)
def _init(args: dict) -> str:
    ws = workspace(args.get("projekt_pfad"), muss_existieren=False)
    created, skipped = [], []
    for d in WORKSPACE_DIRS:
        (ws / d).mkdir(parents=True, exist_ok=True)

    def place(rel: str, content: str) -> None:
        target = ws / rel
        if target.exists():
            skipped.append(rel)
            return
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        created.append(rel)

    name, idee = args["app_name"], args.get("idee", "<in Phase 1 zu klären>")
    plattformen = args.get("plattformen", "iOS und Android")
    projekt = (read_text(TPL_DIR / TEMPLATES["projekt"])
               .replace("<App-Name>", name)
               .replace("- **Idee:** <ein Satz>", f"- **Idee:** {idee}")
               .replace("- **Plattformen:** iOS <min> · Android <min>",
                        f"- **Plattformen:** {plattformen}")
               .replace("- **Start:** YYYY-MM-DD", f"- **Start:** {date.today().isoformat()}"))
    place("PROJEKT.md", projekt)
    place("kommunikation/board.md",
          read_text(TPL_DIR / TEMPLATES["board"]).replace("<App-Name>", name))
    # Vorlage ohne den Beispieleintrag übernehmen — sonst kollidiert er mit echten IDs.
    rueckfragen = read_text(TPL_DIR / TEMPLATES["rueckfragen"]).split("\n---\n")[0].rstrip() + "\n"
    place("kommunikation/rueckfragen.md", rueckfragen)
    place("kommunikation/entscheidungen.md",
          "# Entscheidungen\n\n| # | Datum | Entscheidung | Von | Begründung | Verweis |\n"
          "|---|-------|--------------|-----|------------|---------|\n")
    place("kommunikation/standup.md", "# Statusrunden\n")
    place("02-design/DESIGN-FREIGABE.md",
          read_text(TPL_DIR / TEMPLATES["design-freigabe"]).replace("<App-Name>", name))

    md = (f"# Workspace angelegt: {name}\n\n"
          f"Ort: `{ws}`\n\nNeu erstellt ({len(created)}):\n"
          + "\n".join(f"- {c}" for c in created))
    if skipped:
        md += f"\n\nÜbersprungen, weil vorhanden ({len(skipped)}): " + ", ".join(skipped)
    md += ("\n\n**Nächster Schritt:** Phase 1 mit dem Agenten `requirements-engineer` "
           "(agentur_get_agent_briefing) — PRD und User Stories.\n"
           "Danach Phase 2: Design in Claude Design. Vor der Freigabe wird kein UI-Code gebaut.")
    return md


@tool("agentur_get_project_status",
      "Zeigt den Projektstand: welche Phase läuft, welche Artefakte vorliegen, ob die "
      "Design-Freigabe erteilt ist, offene Rückfragen und Blocker. Erster Aufruf in jeder "
      "neuen Sitzung an einem laufenden Projekt.",
      {"properties": {**PROJEKT_PROP, **FORMAT_PROP}})
def _status(args: dict) -> str:
    ws = workspace(args.get("projekt_pfad"))
    phasen = []
    for num, (title, agent, folder) in PHASES.items():
        d = ws / folder
        files = sorted(p.name for p in d.glob("*.md")) if d.is_dir() else []
        phasen.append({"phase": num, "titel": title, "agent": agent,
                       "artefakte": files, "status": "begonnen" if files else "offen"})

    freigabe = "kein Dokument"
    fpath = ws / "02-design" / "DESIGN-FREIGABE.md"
    if fpath.is_file():
        t = fpath.read_text(encoding="utf-8")
        freigabe = "FREIGEGEBEN" if re.search(r"Status:\s*FREIGEGEBEN|\[x\]\s*\*\*FREIGEGEBEN",
                                              t, re.I) else "OFFEN"
    klick = (ws / "04-implementation" / "klick-test.md").is_file()

    offene = []
    rpath = ws / "kommunikation" / "rueckfragen.md"
    if rpath.is_file():
        for block in re.split(r"\n---\n", rpath.read_text(encoding="utf-8")):
            mid = re.search(r"(MSG-\d{3})", block)
            if mid and re.search(r"\*\*Status:\*\*\s*offen", block, re.I):
                betreff = re.search(r"MSG-\d{3}\s*·\s*(.*)", block)
                an = re.search(r"\*\*An:\*\*\s*([^\n*]+)", block)
                offene.append({"id": mid.group(1),
                               "betreff": (betreff.group(1).strip() if betreff else "-"),
                               "an": (an.group(1).strip() if an else "-")})

    blocker = []
    bpath = ws / "kommunikation" / "board.md"
    if bpath.is_file():
        sec = extract_section(bpath.read_text(encoding="utf-8"), "Blocker") or ""
        blocker = [l.strip() for l in sec.split("\n")
                   if l.startswith("|") and not re.match(r"^\|[\s\-|]+\|$", l)][2:]

    payload = {"workspace": str(ws), "phasen": phasen, "design_freigabe": freigabe,
               "klick_test": klick, "offene_rueckfragen": offene, "blocker": blocker}
    md = ["# Projektstand", f"\nWorkspace: `{ws}`\n",
          as_table([[p["phase"], p["titel"], p["status"],
                     ", ".join(p["artefakte"]) or "—"] for p in phasen],
                   ["#", "Phase", "Status", "Artefakte"]),
          f"\n**Design-Freigabe (Gate vor Phase 4b):** {freigabe}",
          f"**Klick-Test vor QA-Übergabe:** {'vorhanden' if klick else 'fehlt'}"]
    if offene:
        md.append("\n## Offene Rückfragen\n" + "\n".join(
            f"- {o['id']} an {o['an']}: {o['betreff']}" for o in offene))
    if blocker:
        md.append("\n## Blocker\n" + "\n".join(blocker))
    md.append("\nGate einer Phase prüfen: agentur_check_gate.")
    return render(payload, "\n".join(md), args.get("format", "markdown"))


@tool("agentur_check_gate",
      "Prüft das Quality Gate einer Phase gegen die tatsächlich vorhandenen Artefakte und "
      "meldet bestanden oder nicht bestanden mit konkreter Mängelliste. Phase 2 ist das harte "
      "Gate: ohne erteilte Design-Freigabe darf keine UI gebaut werden.",
      {"properties": {
          "phase": {"type": "string", "enum": sorted(PHASES),
                    "description": "Phase 1-8."},
          **PROJEKT_PROP, **FORMAT_PROP},
       "required": ["phase"]})
def _gate(args: dict) -> str:
    phase = args["phase"]
    if phase not in PHASES:
        raise ToolError(f"Unbekannte Phase '{phase}'. Gültig: {', '.join(sorted(PHASES))}")
    ws = workspace(args.get("projekt_pfad"))

    def has(rel: str) -> bool:
        return (ws / rel).is_file()

    def content(rel: str) -> str:
        p = ws / rel
        return p.read_text(encoding="utf-8") if p.is_file() else ""

    checks: list[tuple[str, bool, str]] = []
    if phase == "1":
        checks = [
            ("PRD vorhanden", has("01-requirements/prd.md"),
             "requirements-engineer beauftragen, Vorlage 'prd'"),
            ("User Stories vorhanden", has("01-requirements/user-stories.md"), "Stories schreiben"),
            ("Akzeptanzkriterien in Gherkin", "Szenario:" in content("01-requirements/user-stories.md"),
             "Je Story mindestens ein 'Szenario:'-Block"),
            ("Scope-Abgrenzung", has("01-requirements/nicht-im-scope.md"),
             "Explizit festhalten, was nicht gebaut wird"),
        ]
    elif phase == "2":
        f = content("02-design/DESIGN-FREIGABE.md")
        screens = list((ws / "02-design" / "screens").glob("*.md")) if (ws / "02-design" / "screens").is_dir() else []
        checks = [
            ("Design-System mit Tokens", has("02-design/design-system.md"), "ui-ux-designer beauftragen"),
            ("Prompt-Pack für Claude Design", has("02-design/claude-design-prompts.md"),
             "Je Screen einen Prompt erzeugen"),
            ("Screen-Spezifikationen", bool(screens), "Vorlage 'screen-spec' je Screen ausfüllen"),
            ("Freigabedokument vorhanden", bool(f), "Vorlage 'design-freigabe' anlegen"),
            ("Freigabe erteilt", bool(re.search(r"Status:\s*FREIGEGEBEN|\[x\]\s*\*\*FREIGEGEBEN", f, re.I)),
             "Screens in Claude Design erstellen, vom Menschen freigeben lassen, dann "
             "agentur_set_design_approval aufrufen"),
        ]
    elif phase == "3":
        adr = list((ws / "03-architecture" / "adr").glob("*.md")) if (ws / "03-architecture" / "adr").is_dir() else []
        checks = [
            ("Architekturdokument", has("03-architecture/architektur.md"), "solution-architect beauftragen"),
            ("Mindestens ein ADR", bool(adr), "ADR-001 zum Tech-Stack schreiben"),
            ("Datenmodell mit Zugriffsregeln", has("03-architecture/datenmodell.md"), "RLS je Tabelle festlegen"),
            ("API-Vertrag", has("03-architecture/api-vertrag.md"),
             "Ohne Vertrag können frontend-dev und backend-dev nicht parallel arbeiten"),
            ("10x-Test im ADR beantwortet",
             any("10×" in p.read_text(encoding="utf-8") or "10x" in p.read_text(encoding="utf-8") for p in adr),
             "Skalierungsfragen aus references/skalierbarkeit.md im ADR beantworten"),
        ]
    elif phase == "4":
        checks = [
            ("Design-Freigabe lag vor",
             bool(re.search(r"Status:\s*FREIGEGEBEN|\[x\]\s*\*\*FREIGEGEBEN",
                            content("02-design/DESIGN-FREIGABE.md"), re.I)),
             "Ohne Freigabe verweigert frontend-dev die Arbeit — zuerst Phase 2 abschließen"),
            ("Klick-Test dokumentiert", has("04-implementation/klick-test.md"),
             "agentur_get_checklist mit 'klick-test' abarbeiten und Ergebnis ablegen"),
        ]
    elif phase == "5":
        befunde = content("05-qa/befunde.md")
        berichte = list((ws / "05-qa" / "berichte").glob("*.md")) if (ws / "05-qa" / "berichte").is_dir() else []
        checks = [
            ("Teststrategie", has("05-qa/teststrategie.md"), "qa-engineer beauftragen"),
            ("Berichte des Testteams", len(berichte) >= 3,
             f"Bisher {len(berichte)} Berichte — die sieben Tester beauftragen"),
            ("Konsolidierte Befunde", has("05-qa/befunde.md"), "Befunde zusammenführen"),
            ("Keine offenen Blocker/Hoch",
             not re.search(r"Schweregrad:\s*(Blocker|Hoch)", befunde),
             "Offene Blocker- und Hoch-Befunde an frontend-dev/backend-dev geben"),
            ("Abnahmeempfehlung", has("05-qa/abnahme.md"), "Freigabeempfehlung schreiben"),
        ]
    elif phase == "6":
        f = content("06-security/befunde.md")
        checks = [
            ("Security-Befunde dokumentiert", has("06-security/befunde.md"), "security-reviewer beauftragen"),
            ("Datenschutzprüfung", has("06-security/datenschutz.md"),
             "DSGVO, Privacy Manifest und Data Safety abgleichen"),
            ("Keine offenen kritischen Befunde", not re.search(r"Schweregrad:\s*Kritisch", f),
             "Kritische Befunde beheben lassen — sie blockieren den Release"),
        ]
    elif phase == "7":
        checks = [
            ("Umgebungen dokumentiert", has("07-devops/umgebungen.md"), "devops beauftragen"),
            ("Runbook für Release und Rollback", has("07-devops/runbook.md"),
             "Ohne getesteten Rollback-Weg ist der Release nicht auslieferbar"),
        ]
    else:
        c = content("08-release/release-checkliste.md")
        offen = [i for i in re.findall(r"^\s*-\s\[ \]\s+(.*)$", c, re.M)]
        checks = [
            ("Store-Listing iOS", has("08-release/store-listing-ios.md"), "release-manager beauftragen"),
            ("Store-Listing Android", has("08-release/store-listing-android.md"), "release-manager beauftragen"),
            ("Release-Checkliste vollständig", bool(c) and not offen,
             f"{len(offen)} Punkte offen: " + "; ".join(offen[:5]) if offen else "Checkliste anlegen"),
        ]

    passed = all(ok for _, ok, _ in checks)
    title, agent, _ = PHASES[phase]
    md = [f"# Gate Phase {phase} — {title}",
          f"\n**Ergebnis: {'BESTANDEN' if passed else 'NICHT BESTANDEN'}**  (zuständig: {agent})\n",
          as_table([["✓" if ok else "✗", name, "—" if ok else fix] for name, ok, fix in checks],
                   ["", "Prüfpunkt", "Wenn offen"])]
    if not passed:
        md.append("\nNicht weiterreichen. Zurück an den zuständigen Agenten mit dieser Mängelliste.")
    return render({"phase": phase, "bestanden": passed,
                   "pruefpunkte": [{"punkt": n, "erfuellt": ok, "massnahme": fix}
                                   for n, ok, fix in checks]},
                  "\n".join(md), args.get("format", "markdown"))


@tool("agentur_set_design_approval",
      "Setzt das Design-Gate: erteilt oder verweigert die Freigabe der in Claude Design "
      "erstellten Screens. Erst nach 'FREIGEGEBEN' darf UI-Code entstehen. Nur nach "
      "ausdrücklicher Entscheidung des Menschen aufrufen.",
      {"properties": {
          "status": {"type": "string", "enum": ["FREIGEGEBEN", "ÄNDERUNGEN NÖTIG", "OFFEN"],
                     "description": "Ergebnis der Design-Abnahme."},
          "freigegeben_von": {"type": "string", "description": "Wer die Entscheidung getroffen hat."},
          "anmerkung": {"type": "string", "description": "Offene Punkte oder Auflagen."},
          **PROJEKT_PROP},
       "required": ["status", "freigegeben_von"]},
      read_only=False, destructive=False, idempotent=True)
def _approve(args: dict) -> str:
    ws = workspace(args.get("projekt_pfad"))
    path = ws / "02-design" / "DESIGN-FREIGABE.md"
    if not path.is_file():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(read_text(TPL_DIR / TEMPLATES["design-freigabe"]), encoding="utf-8")
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"^- \*\*Status:\*\*.*$", f"- **Status:** {args['status']}", text, count=1, flags=re.M)
    if "- **Status:**" not in text:
        text = f"- **Status:** {args['status']}\n" + text
    text = re.sub(r"^- \*\*Freigegeben von:\*\*.*$",
                  f"- **Freigegeben von:** {args['freigegeben_von']} · **Datum:** {date.today().isoformat()}",
                  text, count=1, flags=re.M)
    block = (f"\n## Entscheidung vom {date.today().isoformat()}\n\n"
             f"- Status: **{args['status']}**\n- Entschieden von: {args['freigegeben_von']}\n")
    if args.get("anmerkung"):
        block += f"- Anmerkung: {args['anmerkung']}\n"
    path.write_text(text.rstrip() + "\n" + block, encoding="utf-8")

    if args["status"] == "FREIGEGEBEN":
        weiter = ("Gate offen — `frontend-dev` darf jetzt starten. Nächster Schritt: "
                  "Phase 3 abschließen (API-Vertrag), dann Implementierung.")
    else:
        weiter = ("Gate bleibt geschlossen. `frontend-dev` arbeitet nicht an UI. "
                  "Offene Punkte an `ui-ux-designer` zurückgeben.")
    return f"Design-Freigabe auf **{args['status']}** gesetzt (`{path}`).\n\n{weiter}"


@tool("agentur_update_board",
      "Aktualisiert die Statuszeile eines Agenten auf dem Agentur-Board — der zentralen "
      "Übersicht, wer woran arbeitet und wer auf wen wartet. Jeder Agent meldet damit "
      "Beginn und Abschluss seiner Arbeit.",
      {"properties": {
          "agent": {"type": "string", "description": "Name des Agenten."},
          "status": {"type": "string",
                     "enum": ["wartet", "bereit", "läuft", "in Prüfung", "fertig", "blockiert", "Konflikt"],
                     "description": "Neuer Status."},
          "notiz": {"type": "string", "description": "Kurze Ergänzung, z. B. worauf gewartet wird."},
          **PROJEKT_PROP},
       "required": ["agent", "status"]},
      read_only=False, destructive=False, idempotent=False)
def _board(args: dict) -> str:
    agent = args["agent"]
    if agent not in agent_names():
        raise ToolError(f"Unbekannter Agent '{agent}'. Verfügbar: {', '.join(agent_names())}")
    ws = workspace(args.get("projekt_pfad"))
    path = ws / "kommunikation" / "board.md"
    if not path.is_file():
        raise ToolError(f"Kein Board unter '{path}'. Mit agentur_init_project anlegen.")
    lines = path.read_text(encoding="utf-8").split("\n")
    stamp = date.today().isoformat()
    hit = False
    for i, line in enumerate(lines):
        if is_board_row(line, agent):
            cells = board_cells(line)
            if len(cells) >= 4:
                cells[3] = args["status"]
                if args.get("notiz"):
                    cells[4 if len(cells) > 4 else -1] = args["notiz"]
                lines[i] = "| " + " | ".join(cells) + " |"
                hit = True
                break
    if not hit:
        for i, line in enumerate(lines):
            if line.startswith("## Blocker"):
                lines.insert(i, f"| – | {agent} | {args.get('notiz', '')} | {args['status']} | | |")
                hit = True
                break
    path.write_text("\n".join(lines), encoding="utf-8")
    return (f"Board aktualisiert: `{agent}` → **{args['status']}** ({stamp}).\n"
            f"Datei: `{path}`\n\nBei Status 'fertig' gehört zusätzlich eine Übergabe dazu: "
            "agentur_write_handover.")


@tool("agentur_post_message",
      "Schreibt eine Nachricht an einen anderen Agenten oder an den Menschen: Rückfrage, "
      "Befund, Entscheidung oder Blocker. So kommunizieren die Agenten miteinander, ohne den "
      "Verlauf der anderen zu sehen. Die Nachricht landet in der Rückfragen-Datei des Projekts.",
      {"properties": {
          "von": {"type": "string", "description": "Absender-Agent."},
          "an": {"type": "string", "description": "Empfänger-Agent oder 'Mensch'."},
          "typ": {"type": "string", "enum": ["Rückfrage", "Befund", "Entscheidung", "Blocker", "Übergabe"],
                  "description": "Art der Nachricht."},
          "betreff": {"type": "string", "description": "Kurzer Betreff."},
          "inhalt": {"type": "string", "description": "Sachverhalt in ein bis fünf Sätzen."},
          "erwartet": {"type": "string", "description": "Was der Empfänger tun oder entscheiden soll."},
          "dringlichkeit": {"type": "string", "enum": ["Blocker", "Hoch", "Normal"], "default": "Normal"},
          "bezug": {"type": "string", "description": "Bezug wie US-001, ADR-002, BUG-003 oder Screen."},
          "annahme": {"type": "string",
                      "description": "Womit der Absender weiterarbeitet, falls keine Antwort kommt."},
          **PROJEKT_PROP},
       "required": ["von", "an", "typ", "betreff", "inhalt", "erwartet"]},
      read_only=False, destructive=False, idempotent=False)
def _message(args: dict) -> str:
    ws = workspace(args.get("projekt_pfad"))
    path = ws / "kommunikation" / "rueckfragen.md"
    existing = path.read_text(encoding="utf-8") if path.is_file() else "# Rückfragen\n"
    mid = next_message_id(existing)
    block = (f"---\n\n### {mid} · {args['betreff']}\n\n"
             f"- **Von:** {args['von']}  **An:** {args['an']}\n"
             f"- **Typ:** {args['typ']}\n"
             f"- **Dringlichkeit:** {args.get('dringlichkeit', 'Normal')}\n"
             f"- **Bezug:** {args.get('bezug', '—')}\n"
             f"- **Status:** offen\n"
             f"- **Datum:** {date.today().isoformat()}\n\n"
             f"**Inhalt:** {args['inhalt']}\n\n"
             f"**Erwartet:** {args['erwartet']}\n\n"
             f"**Annahme ohne Antwort:** {args.get('annahme', '—')}\n\n"
             f"**Antwort:** _(offen)_\n")
    append_block(path, block)
    hinweis = ("\n\nDringlichkeit 'Blocker': zusätzlich den tech-lead informieren und den "
               "Board-Status auf 'blockiert' setzen." if args.get("dringlichkeit") == "Blocker"
               else "\n\nNicht auf die Antwort warten — an dem weiterarbeiten, was nicht davon abhängt.")
    return f"{mid} an **{args['an']}** eingetragen (`{path}`).{hinweis}"


@tool("agentur_answer_message",
      "Beantwortet eine offene Nachricht und setzt sie auf 'beantwortet'. Der Empfänger einer "
      "Rückfrage schließt sie damit ab, statt sie unbeantwortet stehen zu lassen.",
      {"properties": {
          "nachricht_id": {"type": "string", "description": "ID wie 'MSG-001'."},
          "von": {"type": "string", "description": "Wer antwortet."},
          "antwort": {"type": "string", "description": "Die Entscheidung oder Antwort."},
          **PROJEKT_PROP},
       "required": ["nachricht_id", "von", "antwort"]},
      read_only=False, destructive=False, idempotent=False)
def _answer(args: dict) -> str:
    ws = workspace(args.get("projekt_pfad"))
    path = ws / "kommunikation" / "rueckfragen.md"
    text = read_text(path)
    mid = args["nachricht_id"].upper()
    if mid not in text:
        offen = re.findall(r"(MSG-\d{3})", text)
        raise ToolError(f"'{mid}' nicht gefunden. Vorhanden: {', '.join(sorted(set(offen))) or 'keine'}")
    blocks = text.split("\n---\n")
    for i, b in enumerate(blocks):
        if mid in b:
            b = re.sub(r"\*\*Status:\*\*\s*offen", "**Status:** beantwortet", b, flags=re.I)
            b = re.sub(r"\*\*Antwort:\*\*.*",
                       f"**Antwort:** {args['antwort']} — {args['von']}, {date.today().isoformat()}",
                       b, count=1)
            blocks[i] = b
            break
    path.write_text("\n---\n".join(blocks), encoding="utf-8")
    return (f"{mid} beantwortet und geschlossen.\n\nWenn die Antwort andere Agenten bindet, "
            "gehört sie zusätzlich in `kommunikation/entscheidungen.md`.")


@tool("agentur_get_inbox",
      "Liefert den Posteingang eines Agenten: seine Board-Zeile, die an ihn gerichtete "
      "Übergabe und alle offenen Nachrichten an ihn. Pflichtaufruf, bevor ein Agent mit "
      "der Arbeit beginnt.",
      {"properties": {
          "agent": {"type": "string", "description": "Name des Agenten."},
          **PROJEKT_PROP, **FORMAT_PROP},
       "required": ["agent"]})
def _inbox(args: dict) -> str:
    agent = args["agent"]
    if agent not in agent_names():
        raise ToolError(f"Unbekannter Agent '{agent}'. Verfügbar: {', '.join(agent_names())}")
    ws = workspace(args.get("projekt_pfad"))
    komm = ws / "kommunikation"

    board_rows = []
    if (komm / "board.md").is_file():
        board_rows = [l.strip() for l in (komm / "board.md").read_text(encoding="utf-8").split("\n")
                      if is_board_row(l, agent)]

    uebergaben = []
    if (komm / "uebergaben").is_dir():
        uebergaben = [p.name for p in sorted((komm / "uebergaben").glob(f"*-an-{agent}.md"))]

    nachrichten = []
    if (komm / "rueckfragen.md").is_file():
        for block in (komm / "rueckfragen.md").read_text(encoding="utf-8").split("\n---\n"):
            if re.search(rf"\*\*An:\*\*\s*{re.escape(agent)}\b", block) and \
               re.search(r"\*\*Status:\*\*\s*offen", block, re.I):
                nachrichten.append(block.strip())

    entscheidungen = ""
    if (komm / "entscheidungen.md").is_file():
        entscheidungen = (komm / "entscheidungen.md").read_text(encoding="utf-8").strip()

    md = [f"# Posteingang: {agent}", "\n## Board",
          "\n".join(board_rows) or "Keine Zeile auf dem Board — Status mit agentur_update_board setzen.",
          "\n## Übergaben an dich",
          "\n".join(f"- `kommunikation/uebergaben/{u}`" for u in uebergaben) or "Keine.",
          "\n## Offene Nachrichten an dich",
          "\n\n".join(nachrichten) or "Keine.",
          "\n## Entscheidungslog", entscheidungen or "Noch leer.",
          "\n---\nNach der Arbeit: Übergabe schreiben (agentur_write_handover) und Board "
          "auf 'fertig' setzen. Vorher giltst du nicht als fertig."]
    return render({"agent": agent, "board": board_rows, "uebergaben": uebergaben,
                   "offene_nachrichten": len(nachrichten)},
                  "\n".join(md), args.get("format", "markdown"))


@tool("agentur_write_handover",
      "Schreibt das Übergabedokument beim Phasenwechsel: was fertig ist, was der Empfänger "
      "zuerst lesen soll, welche Entscheidungen ihn binden, welche Annahmen getroffen wurden "
      "und was offen bleibt. Ohne Übergabe gilt ein Agent nicht als fertig.",
      {"properties": {
          "von": {"type": "string", "description": "Abgebender Agent."},
          "an": {"type": "string", "description": "Empfangender Agent."},
          "phase": {"type": "string", "description": "Abgeschlossene Phase, z. B. '2'."},
          "fertig": {"type": "string", "description": "Was fertig ist, je Zeile ein Ergebnis mit Datei."},
          "zuerst_lesen": {"type": "string", "description": "Welche Dateien zuerst und warum."},
          "entscheidungen": {"type": "string", "description": "Entscheidungen, die den Empfänger binden."},
          "annahmen": {"type": "string", "description": "Getroffene Annahmen und ihre Folgen, falls falsch."},
          "offen": {"type": "string", "description": "Was bewusst offen bleibt und wer entscheidet."},
          "risiken": {"type": "string", "description": "Risiken für die nächste Phase mit Empfehlung."},
          **PROJEKT_PROP},
       "required": ["von", "an", "phase", "fertig"]},
      read_only=False, destructive=False, idempotent=False)
def _handover(args: dict) -> str:
    for role in ("von", "an"):
        if args[role] not in agent_names():
            raise ToolError(f"Unbekannter Agent '{args[role]}'. Verfügbar: {', '.join(agent_names())}")
    ws = workspace(args.get("projekt_pfad"))
    path = ws / "kommunikation" / "uebergaben" / f"{args['phase']}-{args['von']}-an-{args['an']}.md"
    fehlend = [k for k in ("annahmen", "offen") if not args.get(k)]
    doc = (f"# Übergabe: {args['von']} → {args['an']}\n\n"
           f"- **Phase:** {args['phase']}\n- **Datum:** {date.today().isoformat()}\n\n"
           f"## Was fertig ist\n\n{args['fertig']}\n\n"
           f"## Zuerst lesen\n\n{args.get('zuerst_lesen', '—')}\n\n"
           f"## Entscheidungen, die dich binden\n\n{args.get('entscheidungen', '—')}\n\n"
           f"## Annahmen, die ich getroffen habe\n\n{args.get('annahmen', '—')}\n\n"
           f"## Was bewusst offen bleibt\n\n{args.get('offen', '—')}\n\n"
           f"## Risiken für deine Phase\n\n{args.get('risiken', '—')}\n")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(doc, encoding="utf-8")
    hinweis = ""
    if fehlend:
        hinweis = ("\n\n**Unvollständig:** Die Abschnitte " + " und ".join(fehlend) +
                   " sind leer. Eine Übergabe ohne Annahmen und offene Punkte ist laut Protokoll "
                   "unvollständig — bitte ergänzen.")
    return (f"Übergabe geschrieben: `{path}`\n\nNächster Schritt: Board-Zeile von "
            f"`{args['von']}` auf 'fertig' und `{args['an']}` auf 'bereit' setzen "
            f"(agentur_update_board).{hinweis}")


# --------------------------------------------------------------------- Prompts

PROMPTS = [
    ("agentur_start", "Neues App-Projekt mit dem Agentur-Team starten",
     [("app_idee", "Die App-Idee in ein bis zwei Sätzen", True)],
     "Starte ein neues Mobile-App-Projekt mit der Software-Agentur.\n\n"
     "App-Idee: {app_idee}\n\n"
     "1. Rufe agentur_get_process auf und halte dich an den Prozess.\n"
     "2. Lege den Workspace mit agentur_init_project an.\n"
     "3. Übernimm die Rolle des tech-lead (agentur_get_agent_briefing) und stelle mir "
     "maximal fünf gezielte Rückfragen.\n"
     "4. Starte Phase 1 mit dem requirements-engineer: PRD, User Stories, MVP-Schnitt. "
     "Arbeite dabei die Liste aus agentur_get_checklist('grundgeruest') ab.\n"
     "5. Prüfe das Gate mit agentur_check_gate('1') und berichte in maximal zehn Zeilen.\n\n"
     "Wichtig: Phase 2 ist die Design-Phase in Claude Design. Vor der Freigabe entsteht kein UI-Code."),

    ("agentur_design", "Design-Phase durchführen und Prompts für Claude Design erzeugen",
     [("fokus", "Optionaler Schwerpunkt, z. B. ein einzelner Screen", False)],
     "Führe Phase 2 der Software-Agentur durch: Design vor Code. Fokus: {fokus}\n\n"
     "1. Übernimm die Rolle ui-ux-designer (agentur_get_agent_briefing).\n"
     "2. Lies den Posteingang (agentur_get_inbox) und das PRD.\n"
     "3. Erstelle Design-Brief, Design-System mit Tokens für Hell und Dunkel inklusive "
     "geprüfter Kontraste, Screen-Spezifikationen mit allen Zuständen und ein Prompt-Pack "
     "für Claude Design — je Screen ein vollständiger Prompt.\n"
     "4. Lege die Screens vor und bitte mich ausdrücklich um Freigabe. Erst wenn ich sie "
     "erteile, rufe agentur_set_design_approval auf.\n"
     "5. Schreibe die Übergabe an frontend-dev (agentur_write_handover)."),

    ("agentur_build", "Architektur und Implementierung starten",
     [("fokus", "Optionaler Schwerpunkt, z. B. eine Story-ID", False)],
     "Starte die Umsetzungsphasen der Agentur. Fokus: {fokus}\n\n"
     "1. Prüfe zuerst agentur_check_gate('2'). Ist die Design-Freigabe nicht erteilt, brich ab "
     "und sage mir warum.\n"
     "2. Fehlt die Architektur, übernimm solution-architect: ADR zum Stack mit beantwortetem "
     "10x-Test, Datenmodell mit Zugriffsregeln, API-Vertrag.\n"
     "3. Danach backend-dev und frontend-dev gegen den API-Vertrag. Halte dich an die "
     "Best Practices aus agentur_get_reference für security, performance und skalierbarkeit.\n"
     "4. Führe vor der Übergabe den Klick-Test aus agentur_get_checklist('klick-test') durch."),

    ("agentur_check", "Grundgerüst und Klick-Test — funktioniert wirklich alles?",
     [("bereich", "Optionaler Screen oder Bereich", False)],
     "Prüfe die App gegen Grundgerüst und Interaktions-Checkliste. Bereich: {bereich}\n\n"
     "1. agentur_get_checklist('grundgeruest') — Punkt für Punkt: umgesetzt, fehlt oder "
     "bewusst nicht nötig mit Begründung.\n"
     "2. agentur_get_checklist('interaktion') und ('klick-test') abarbeiten: jeder Button, "
     "jedes Eingabefeld, jedes Formular, jede Nachricht, jede Liste.\n"
     "3. Suche im Code gezielt nach Schaltflächen ohne Handler, fehlender Sperre während des "
     "Ladens, Netzaufrufen ohne Fehlerpfad, Listen ohne Leerzustand und Nachrichten ohne "
     "Sendestatus.\n"
     "4. Schreibe das Ergebnis nach agentur/04-implementation/klick-test.md."),

    ("agentur_review", "Qualitätssicherung mit dem gesamten Testteam",
     [("bereich", "Optionaler Prüfschwerpunkt", False)],
     "Führe die Prüfphasen der Agentur durch. Bereich: {bereich}\n\n"
     "1. Übernimm die Rolle qa-engineer (agentur_get_agent_briefing) und schreibe die "
     "Teststrategie.\n"
     "2. Arbeite die sieben Testrollen nacheinander ab — functional-tester, api-tester, "
     "performance-tester, security-tester, accessibility-tester, compatibility-tester, "
     "test-automation-engineer. Hole je Rolle das Briefing und lege den Bericht in "
     "agentur/05-qa/berichte/ ab.\n"
     "3. Konsolidiere die Befunde, entdopple sie und priorisiere nach Schweregrad.\n"
     "4. Lass den security-reviewer Code und Compliance prüfen.\n"
     "5. Prüfe agentur_check_gate('5') und ('6') und gib die Abnahmeempfehlung."),

    ("agentur_release", "Release für App Store und Google Play vorbereiten",
     [("version", "Versionsnummer, z. B. 1.0.0", False)],
     "Bereite den Release vor. Version: {version}\n\n"
     "1. Prüfe agentur_check_gate('5') und ('6') — ohne Abnahme und Security-Freigabe kein Release.\n"
     "2. Übernimm devops: CI/CD, Signing, Umgebungen, Runbook mit getestetem Rollback.\n"
     "3. Übernimm release-manager: Store-Listings, Assets, die zehn häufigsten "
     "Ablehnungsgründe prüfen, gestaffelter Rollout.\n"
     "4. Arbeite agentur_get_checklist('release') vollständig ab und nenne offene Punkte "
     "namentlich — nichts stillschweigend abhaken."),

    ("agentur_status", "Projektstand, Board, Blocker und nächster Schritt", [],
     "Zeige den Stand des Agentur-Projekts.\n\n"
     "1. agentur_get_project_status aufrufen.\n"
     "2. Die Gates der begonnenen Phasen mit agentur_check_gate prüfen.\n"
     "3. Berichte kompakt: aktuelle Phase, Erledigtes, Gate-Status, nächster Agent mit "
     "Aufgabe, Blocker und offene Fragen an mich."),
]


# ------------------------------------------------------------------- Ressourcen

def resource_list() -> list[dict[str, str]]:
    items = [{"uri": "agentur://prozess", "name": "Prozess und Quality Gates",
              "description": "Acht Phasen, Gates, Workspace-Struktur", "mimeType": "text/markdown"}]
    items += [{"uri": f"agentur://referenz/{k}", "name": f"Referenz: {k}",
               "description": f"Verbindliche Wissensbasis ({v})", "mimeType": "text/markdown"}
              for k, v in sorted(REFERENCES.items())]
    items += [{"uri": f"agentur://agent/{a}", "name": f"Agent: {a}",
               "description": f"Arbeitsanweisung des Agenten {a}", "mimeType": "text/markdown"}
              for a in agent_names()]
    return items


def resource_read(uri: str) -> str:
    if uri == "agentur://prozess":
        return read_text(SKILL_DIR / "SKILL.md")
    m = re.fullmatch(r"agentur://referenz/([a-z\-]+)", uri)
    if m and m.group(1) in REFERENCES:
        return read_text(REF_DIR / REFERENCES[m.group(1)])
    m = re.fullmatch(r"agentur://agent/([a-z\-]+)", uri)
    if m:
        return read_text(agent_path(m.group(1)))
    raise ToolError(f"Unbekannte Ressource '{uri}'. Verfügbare siehe resources/list.")


# ---------------------------------------------------------------------- Server

def handle(method: str, params: dict) -> Any:
    if method == "initialize":
        client = params.get("protocolVersion")
        return {
            "protocolVersion": client if client in SUPPORTED_PROTOCOLS else DEFAULT_PROTOCOL,
            "capabilities": {"tools": {}, "prompts": {}, "resources": {}},
            "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
            "instructions": (
                "KI-Software-Agentur: 17 spezialisierte Agenten für professionelle iOS- und "
                "Android-Apps mit verbindlichem Prozess. Reihenfolge: agentur_get_process, "
                "dann agentur_init_project, dann phasenweise arbeiten. Harte Regel: Das Design "
                "entsteht zuerst in Claude Design; ohne erteilte Freigabe "
                "(agentur_set_design_approval) wird kein UI-Code geschrieben. Agenten "
                "kommunizieren über agentur_get_inbox, agentur_post_message und "
                "agentur_write_handover."),
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": [{k: v for k, v in t.items() if k != "handler"} for t in TOOLS]}
    if method == "tools/call":
        name = params.get("name")
        entry = next((t for t in TOOLS if t["name"] == name), None)
        if entry is None:
            return {"isError": True, "content": [{"type": "text", "text":
                    f"Unbekanntes Tool '{name}'. Verfügbar: {', '.join(t['name'] for t in TOOLS)}"}]}
        try:
            text = entry["handler"](params.get("arguments") or {})
            return {"content": [{"type": "text", "text": text}]}
        except ToolError as exc:
            return {"isError": True, "content": [{"type": "text", "text": f"Fehler: {exc}"}]}
        except Exception as exc:  # noqa: BLE001
            print(f"[{SERVER_NAME}] {name}: {exc!r}", file=sys.stderr)
            return {"isError": True, "content": [{"type": "text", "text":
                    f"Fehler beim Ausführen von '{name}': {exc}"}]}
    if method == "prompts/list":
        return {"prompts": [{"name": n, "description": d,
                             "arguments": [{"name": a, "description": ad, "required": req}
                                           for a, ad, req in args]}
                            for n, d, args, _ in PROMPTS]}
    if method == "prompts/get":
        name = params.get("name")
        entry = next((p for p in PROMPTS if p[0] == name), None)
        if entry is None:
            raise ValueError(f"Unbekannter Prompt '{name}'")
        given = params.get("arguments") or {}
        text = entry[3]
        for arg, _, _ in entry[2]:
            text = text.replace("{" + arg + "}", given.get(arg) or "—")
        return {"description": entry[1],
                "messages": [{"role": "user", "content": {"type": "text", "text": text}}]}
    if method == "resources/list":
        return {"resources": resource_list()}
    if method == "resources/read":
        uri = params.get("uri", "")
        return {"contents": [{"uri": uri, "mimeType": "text/markdown", "text": resource_read(uri)}]}
    raise LookupError(method)


def force_utf8() -> None:
    """MCP schreibt UTF-8. Windows-Konsolen laufen sonst auf cp1252 und brechen
    beim ersten Sonderzeichen mit UnicodeEncodeError ab."""
    for stream, extra in ((sys.stdin, {}), (sys.stdout, {"newline": "\n"}), (sys.stderr, {})):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace", **extra)
        except (AttributeError, ValueError):  # pragma: no cover
            pass


def selftest() -> int:
    """Diagnose für die Einrichtung: python server.py --selftest"""
    ok = True
    print(f"{SERVER_NAME} {SERVER_VERSION}")
    print(f"Python:          {sys.version.split()[0]} ({sys.executable})")
    print(f"Ausgabe-Kodierung: {sys.stdout.encoding}")
    print(f"AGENTUR_HOME:    {HOME}")
    for label, path in (("Agenten", AGENTS_DIR), ("Referenzen", REF_DIR), ("Vorlagen", TPL_DIR)):
        exists = path.is_dir()
        ok &= exists
        count = len(list(path.glob("*.md"))) if exists else 0
        print(f"{label + ':':16} {'gefunden' if exists else 'FEHLT'} — {path} ({count} Dateien)")
    agents = agent_names()
    print(f"Agenten geladen: {len(agents)}")
    print(f"Tools:           {len(TOOLS)}   Prompts: {len(PROMPTS)}")
    projekt = os.environ.get("AGENTUR_PROJEKT")
    if projekt:
        exists = Path(projekt).is_dir()
        print(f"AGENTUR_PROJEKT: {'gefunden' if exists else 'FEHLT (wird beim Anlegen gebraucht)'} — {projekt}")
    try:
        sys.stdout.write("Sonderzeichen:   → ✓ ✗ Ü ä\n")
        sys.stdout.flush()
    except UnicodeEncodeError:
        ok = False
        print("FEHLER: Die Konsole kann keine UTF-8-Zeichen ausgeben.")
    if not ok:
        print("\nNicht bereit. Prüfe den Pfad zur Datei server.py und ob das Repo vollständig "
              "geklont wurde (Ordner .claude/agents muss existieren).")
        return 1
    print("\nBereit. Der Server kann in Claude Desktop eingetragen werden.")
    return 0


def main() -> None:
    force_utf8()
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    if not AGENTS_DIR.is_dir():
        print(f"[{SERVER_NAME}] Agentur nicht gefunden unter {HOME}. "
              "AGENTUR_HOME auf das Repo-Verzeichnis setzen. "
              "Diagnose: python server.py --selftest", file=sys.stderr)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        mid, method, params = msg.get("id"), msg.get("method", ""), msg.get("params") or {}
        if mid is None:  # Benachrichtigung — keine Antwort
            continue
        try:
            result = handle(method, params)
            response = {"jsonrpc": "2.0", "id": mid, "result": result}
        except LookupError:
            response = {"jsonrpc": "2.0", "id": mid,
                        "error": {"code": -32601, "message": f"Method not found: {method}"}}
        except Exception as exc:  # noqa: BLE001
            print(f"[{SERVER_NAME}] {method}: {exc!r}", file=sys.stderr)
            response = {"jsonrpc": "2.0", "id": mid,
                        "error": {"code": -32603, "message": str(exc)}}
        try:
            sys.stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
            sys.stdout.flush()
        except UnicodeEncodeError:
            # Letzte Rückfallebene, falls die Kodierung sich nicht umstellen ließ.
            sys.stdout.write(json.dumps(response, ensure_ascii=True) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except Exception as exc:  # noqa: BLE001
        print(f"[{SERVER_NAME}] Abbruch: {exc!r}\n"
              f"Diagnose mit: python \"{Path(__file__).resolve()}\" --selftest", file=sys.stderr)
        sys.exit(1)
