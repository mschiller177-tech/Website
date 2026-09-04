---
description: Bereitet CI/CD und die Veröffentlichung in App Store und Google Play vor
argument-hint: "[version]"
---

Führe die Phasen 7 und 8 der Software-Agentur durch.

Version (optional): $ARGUMENTS

Vorgehen:

1. **Vorbedingung prüfen:** QA-Abnahme (`agentur/05-qa/abnahme.md`) und Security-Freigabe
   (`agentur/06-security/befunde.md`) liegen vor, keine offenen Blocker.
   Sonst abbrechen und `/agentur-review` vorschlagen.
2. `devops` über `Task` beauftragen:
   - CI (Lint, Typecheck, Tests) und Build-Workflows für iOS und Android
   - Signing, drei getrennte Umgebungen, Crash-Reporting mit Sourcemaps
   - `agentur/07-devops/runbook.md` mit Release- und Rollback-Ablauf
3. `release-manager` über `Task` beauftragen:
   - Store-Listings für beide Plattformen, Screenshot-Plan aus dem freigegebenen Design
   - Prüfung der zehn häufigsten Ablehnungsgründe
   - `agentur/08-release/release-checkliste.md` aus der Vorlage abarbeiten
   - Gestaffelter Rollout (Play 10 % → 50 % → 100 %, iOS Phased Release)
4. Offene Punkte der Checkliste namentlich melden — nichts stillschweigend abhaken.
