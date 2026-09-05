#!/usr/bin/env python3
"""Richtet den Agentur-MCP-Server in Claude Desktop ein.

Trägt den Server mit dem Python-Interpreter ein, der dieses Skript ausführt —
damit entfällt jedes Rätselraten über 'python', 'python3' oder 'py'.

Aufruf:
    python setup.py                            # einrichten
    python setup.py --projekt "C:\\Pfad\\App"   # mit Projektverzeichnis
    python setup.py --pruefen                  # nur prüfen, nichts ändern
    python setup.py --entfernen                # Eintrag wieder löschen
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

SERVER = Path(__file__).resolve().parent / "server.py"
REPO = Path(__file__).resolve().parents[2]
ENTRY = "agentur"


def config_path() -> Path:
    """Ort der Claude-Desktop-Konfiguration je Betriebssystem."""
    if sys.platform == "win32":
        base = os.environ.get("APPDATA") or (Path.home() / "AppData" / "Roaming")
        return Path(base) / "Claude" / "claude_desktop_config.json"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Claude" / "claude_desktop_config.json"
    return Path.home() / ".config" / "Claude" / "claude_desktop_config.json"


def pruefen() -> list[str]:
    """Gibt die Liste der Probleme zurück — leer heißt: alles in Ordnung."""
    probleme = []
    if sys.version_info < (3, 8):
        probleme.append(f"Python {sys.version.split()[0]} ist zu alt — mindestens 3.8 nötig.")
    if not SERVER.is_file():
        probleme.append(f"server.py nicht gefunden unter {SERVER}")
    for label, rel in (("Agenten", ".claude/agents"),
                       ("Wissensbasis", ".claude/skills/software-agentur/references"),
                       ("Vorlagen", ".claude/skills/software-agentur/templates")):
        if not (REPO / rel).is_dir():
            probleme.append(f"{label} fehlen: {REPO / rel} — Repository unvollständig geklont?")
    return probleme


def lade_config(path: Path) -> dict:
    if not path.is_file():
        return {}
    roh = path.read_text(encoding="utf-8-sig").strip()
    if not roh:
        return {}
    try:
        daten = json.loads(roh)
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"\nFEHLER: '{path}' enthält kein gültiges JSON ({exc}).\n"
            "Häufigste Ursache: ein Komma zu viel hinter dem letzten Eintrag.\n"
            "Datei reparieren oder vorübergehend umbenennen, dann dieses Skript erneut ausführen."
        )
    if not isinstance(daten, dict):
        raise SystemExit(f"\nFEHLER: '{path}' hat ein unerwartetes Format.")
    return daten


def main() -> int:
    p = argparse.ArgumentParser(description="Agentur-MCP-Server in Claude Desktop einrichten.")
    p.add_argument("--projekt", help="Verzeichnis deines App-Projekts (wird als AGENTUR_PROJEKT gesetzt).")
    p.add_argument("--pruefen", action="store_true", help="Nur prüfen, nichts verändern.")
    p.add_argument("--entfernen", action="store_true", help="Den Eintrag aus der Konfiguration löschen.")
    args = p.parse_args()

    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

    print("Agentur-MCP — Einrichtung fuer Claude Desktop\n" + "=" * 46)
    print(f"Python:      {sys.version.split()[0]}")
    print(f"Interpreter: {sys.executable}")
    print(f"Repository:  {REPO}")
    print(f"Server:      {SERVER}")

    probleme = pruefen()
    if probleme:
        print("\nNicht bereit:")
        for pr in probleme:
            print(f"  - {pr}")
        print("\nDas Repository muss vollstaendig vorliegen. Falls noch nicht geschehen:")
        print("  git clone -b claude/software-agentur-ki-agenten-6d7uzi "
              "https://github.com/mschiller177-tech/Website.git")
        return 1

    # Selbsttest des Servers mit genau diesem Interpreter
    res = subprocess.run([sys.executable, str(SERVER), "--selftest"],
                         capture_output=True, text=True, timeout=60)
    if res.returncode != 0:
        print("\nSelbsttest des Servers fehlgeschlagen:")
        print((res.stdout or "") + (res.stderr or ""))
        return 1
    for zeile in res.stdout.splitlines():
        if zeile.startswith(("Agenten geladen", "Tools:")):
            print(f"{zeile}")
    print("Selbsttest:  bestanden")

    cfg = config_path()
    print(f"Konfiguration: {cfg}")

    if args.pruefen:
        daten = lade_config(cfg)
        vorhanden = ENTRY in daten.get("mcpServers", {})
        print(f"\nEintrag '{ENTRY}' vorhanden: {'ja' if vorhanden else 'nein'}")
        print("Alles bereit. Zum Eintragen dieses Skript ohne --pruefen ausfuehren.")
        return 0

    daten = lade_config(cfg)
    server_liste = daten.setdefault("mcpServers", {})

    if args.entfernen:
        if server_liste.pop(ENTRY, None) is None:
            print(f"\nKein Eintrag '{ENTRY}' vorhanden — nichts zu tun.")
            return 0
    else:
        eintrag: dict = {"command": sys.executable, "args": [str(SERVER)]}
        projekt = args.projekt or os.environ.get("AGENTUR_PROJEKT")
        if projekt:
            pfad = Path(projekt).expanduser()
            pfad.mkdir(parents=True, exist_ok=True)
            eintrag["env"] = {"AGENTUR_PROJEKT": str(pfad.resolve())}
            print(f"Projektordner: {pfad.resolve()}")
        server_liste[ENTRY] = eintrag

    if cfg.is_file():
        stempel = datetime.now().strftime("%Y%m%d-%H%M%S")
        sicherung = cfg.with_suffix(f".backup-{stempel}.json")
        shutil.copy2(cfg, sicherung)
        print(f"Sicherung:   {sicherung.name}")
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text(json.dumps(daten, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    andere = [n for n in server_liste if n != ENTRY]
    print(f"\nFertig. Eingetragene MCP-Server: {', '.join(server_liste) or 'keine'}")
    if andere:
        print(f"Unveraendert uebernommen: {', '.join(andere)}")
    if not args.entfernen:
        print("\nNaechste Schritte:")
        print("  1. Claude Desktop vollstaendig beenden — auch das Symbol unten rechts "
              "in der Taskleiste (Rechtsklick, Beenden).")
        print("  2. Claude Desktop neu starten.")
        print("  3. Der Server 'agentur' erscheint unter Einstellungen -> Entwickler.")
        print("  4. Die sieben Agentur-Ablaeufe findest du im Chat unter '+'.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
