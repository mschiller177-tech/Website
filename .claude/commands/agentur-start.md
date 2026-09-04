---
description: Startet ein neues App-Projekt mit dem KI-Agentur-Team (Phase 1 Anforderungen)
argument-hint: "<App-Idee>"
---

Starte ein neues Mobile-App-Projekt mit der Software-Agentur.

**App-Idee:** $ARGUMENTS

Vorgehen:

1. Lies `.claude/skills/software-agentur/SKILL.md` (Prozess, Phasen, Gates).
2. Beauftrage den Agent `tech-lead` über `Task` mit dem Projektstart:
   - Idee aufnehmen, maximal 3–5 gezielte Rückfragen an mich stellen
   - Workspace `agentur/` gemäß Skill anlegen, `agentur/PROJEKT.md` aus der Vorlage
     `.claude/skills/software-agentur/templates/projekt.md` erzeugen
   - Phase 1 an `requirements-engineer` delegieren
3. Nach Phase 1 das Gate prüfen und mir berichten:
   erledigt · Gate-Status · nächster Schritt · offene Fragen.

Wichtig: Phase 2 ist die Design-Phase in **Claude Design**. Es wird kein UI-Code
geschrieben, bevor `agentur/02-design/DESIGN-FREIGABE.md` auf `FREIGEGEBEN` steht.
