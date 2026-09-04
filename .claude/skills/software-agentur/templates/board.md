# Agentur-Board — <App-Name>

Zentrale Statusübersicht. Eigentümer: `tech-lead`. Jeder Agent liest hier zuerst.

Status: `wartet` · `bereit` · `läuft` · `in Prüfung` · `fertig` · `blockiert` · `Konflikt`

## Aktuelle Runde

| # | Agent | Aufgabe | Status | Wartet auf | Übergabe an |
|---|-------|---------|--------|------------|-------------|
| 1 | requirements-engineer | PRD und Stories | bereit | — | ui-ux-designer |
| 2 | ui-ux-designer | Design-Phase (Claude Design) | wartet | 1 | frontend-dev |
| 3 | solution-architect | Architektur und API-Vertrag | wartet | 1, 2 | frontend-dev, backend-dev |
| 4a | backend-dev | API und Datenbank | wartet | 3 | qa-engineer |
| 4b | frontend-dev | Screens und Anbindung | wartet | 2 (Freigabe), 3 | qa-engineer |
| 5 | qa-engineer | Qualitätssicherung mit Testteam | wartet | 4a, 4b | tech-lead |
| 6 | security-reviewer | Audit und Compliance | wartet | 4a, 4b | tech-lead |
| 7 | devops | CI/CD und Umgebungen | wartet | 3 | release-manager |
| 8 | release-manager | Store und Rollout | wartet | 5, 6, 7 | tech-lead |

## Blocker

| # | Was blockiert | Wen | Seit | Verantwortlich | Nächster Schritt |
|---|---------------|-----|------|----------------|------------------|

## Konflikte

| # | Position A (Agent) | Position B (Agent) | Entscheidung des Leads | Verweis |
|---|--------------------|--------------------|------------------------|---------|

## Nachrichten

| MSG | Von | An | Typ | Betreff | Status |
|-----|-----|----|-----|---------|--------|
