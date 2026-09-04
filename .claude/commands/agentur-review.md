---
description: Führt QA mit dem kompletten Testteam und den Security-Review vor dem Release durch
argument-hint: "[bereich]"
---

Führe die Prüfphasen 5 und 6 der Software-Agentur durch.

Bereich (optional): $ARGUMENTS

Vorgehen:

1. **Vorbedingung:** `agentur/04-implementation/klick-test.md` liegt vor.
   Fehlt sie, zuerst `/agentur-check` ausführen — ungeprüfte Bedienbarkeit wird nicht
   an das Testteam weitergereicht.
2. `qa-engineer` über `Task` beauftragen. Er schreibt die Teststrategie und beauftragt
   sein Testteam parallel:
   - `functional-tester` — Akzeptanzkriterien, Nutzerflows, Grenzfälle, Regression
   - `api-tester` — Vertragstreue, Fehlerpfade, IDOR-Test mit zwei Nutzern, Idempotenz
   - `performance-tester` — Budgets messen, Lasttest gegen die Kernendpunkte
   - `security-tester` — Sitzung, lokaler Speicher, Transport, Eingabemanipulation, Deep Links
   - `accessibility-tester` — VoiceOver/TalkBack, Schrift 200 %, Kontraste
   - `compatibility-tester` — Geräte-/OS-Matrix, Sprachen, Update von der Vorversion
   - `test-automation-engineer` — Suite automatisieren und in die CI hängen
   Berichte nach `agentur/05-qa/berichte/<tester>.md`, Konsolidierung in `befunde.md`.
3. `security-reviewer` über `Task` beauftragen: Code-Audit, DSGVO, Apple Privacy Manifest,
   Play Data Safety, Abhängigkeiten. Ergebnisse nach `agentur/06-security/`.
4. Befunde an `frontend-dev` bzw. `backend-dev` zur Behebung — die Prüfer reparieren nicht
   selbst. Nach jeder Behebung gezielt nachtesten.
5. **Gate:** keine offenen Blocker-/Hoch-Befunde, keine kritischen Security-Befunde,
   Performance-Budgets belegt, Grundgerüst geprüft.
6. `agentur/PROJEKT.md` und `agentur/kommunikation/board.md` aktualisieren, dann berichten.
