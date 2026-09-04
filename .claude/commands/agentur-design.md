---
description: Führt die verpflichtende Design-Phase durch (Design-System + Prompt-Pack für Claude Design)
argument-hint: "[screen oder fokus]"
---

Führe Phase 2 der Software-Agentur durch: **Design vor Code**.

Fokus (optional): $ARGUMENTS

Vorgehen:

1. Beauftrage den Agent `ui-ux-designer` über `Task`.
2. Input: `agentur/01-requirements/prd.md` und `user-stories.md`.
   Fehlen sie, zuerst `/agentur-start` ausführen.
3. Erwartete Ergebnisse in `agentur/02-design/`:
   - `design-brief.md` — Designrichtung mit Begründung
   - `design-system.md` — Tokens für Hell und Dunkel, Kontraste geprüft
   - `claude-design-prompts.md` — ein fertiger Prompt je Screen für **Claude Design**
   - `screens/<screen>.md` — Spezifikation mit allen Zuständen
   - `komponenten.md` — Komponenteninventar
   - `DESIGN-FREIGABE.md` — Freigabedokument, Status `OFFEN`
4. Die Design-Datenbank des Repos nutzen:
   `python3 src/ui-ux-pro-max/scripts/search.py "<query>" --domain style|color|typography|ux`
5. Lege mir am Ende die Prompts aus `claude-design-prompts.md` vor. Ich führe sie in
   **Claude Design** aus und gebe die Screens frei.

Erst wenn `DESIGN-FREIGABE.md` auf `FREIGEGEBEN` steht, darf `/agentur-build` starten.
