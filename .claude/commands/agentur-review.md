---
description: Führt QA und Security-Review vor dem Release durch
argument-hint: "[bereich]"
---

Führe die Prüfphasen 5 und 6 der Software-Agentur durch.

Bereich (optional): $ARGUMENTS

Vorgehen:

1. `qa-engineer` über `Task` beauftragen:
   - Testplan aus dem PRD ableiten, Testfälle je Akzeptanzkriterium
   - Unit-, Komponenten- und Integrationstests; E2E für die kritischen Flows
   - Mobile-Schwerpunkte: kein Netz, Hintergrund/Kaltstart, verweigerte Berechtigungen,
     Schrift auf 200 %, kleinstes und größtes Display, abgelaufene Sitzung
   - Ergebnisse nach `agentur/05-qa/`, Bugs priorisiert
2. `security-reviewer` über `Task` beauftragen:
   - Secrets, Auth, Datenhaltung, Netzwerk, Backend-Policies, Abhängigkeiten
   - DSGVO, Apple Privacy Manifest, Play Data Safety, Berechtigungsbegründungen
   - Ergebnisse nach `agentur/06-security/`
3. Befunde an `frontend-dev` bzw. `backend-dev` zur Behebung geben — die Prüfer
   reparieren nicht selbst.
4. Gate: keine offenen Blocker-/Hoch-Bugs und keine offenen kritischen Security-Befunde.
   Ergebnis in `agentur/PROJEKT.md` festhalten und mir berichten.
