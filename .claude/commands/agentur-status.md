---
description: Zeigt Projektstand, Gate-Status und den nächsten Schritt der Agentur
---

Erstelle einen Statusbericht zum laufenden App-Projekt.

Vorgehen:

1. Lies `agentur/PROJEKT.md`.
2. Prüfe den tatsächlichen Stand der Artefakte auf der Platte, nicht nur die Tabelle:
   - `agentur/01-requirements/` — PRD und Stories vollständig?
   - `agentur/02-design/DESIGN-FREIGABE.md` — Status?
   - `agentur/03-architecture/` — ADRs und API-Vertrag vorhanden?
   - `agentur/05-qa/bugs.md` — offene Blocker?
   - `agentur/06-security/befunde.md` — offene kritische Befunde?
3. Aktualisiere die Phasentabelle in `agentur/PROJEKT.md`, wenn sie vom Ist-Stand abweicht.
4. Berichte kompakt:

```
Phase:        <n> — <Name>
Erledigt:     <…>
Gate:         bestanden / offen (<Grund>)
Nächster:     <Agent> — <Aufgabe>
Blockiert:    <…>
Offene Fragen an mich: <…>
```
