# KI-Software-Agentur — Entwicklungsteam für iOS & Android

Zehn spezialisierte Subagenten, die einen professionellen Entwicklungsprozess simulieren:
von der Idee bis zum Store-Release. Gesteuert vom Prozess-Skill
[`software-agentur`](../skills/software-agentur/SKILL.md).

## Grundregel

> **Zuerst Design in Claude Design — dann Umsetzung in Claude Code.**

Phase 2 endet mit `agentur/02-design/DESIGN-FREIGABE.md`. Steht dort nicht
`Status: FREIGEGEBEN`, verweigert `frontend-dev` die Arbeit und meldet zurück.

## Team

| Agent | Rolle | Phase |
|-------|-------|-------|
| [`tech-lead`](tech-lead.md) | Agentur-Lead, Orchestrierung, Gates | alle |
| [`requirements-engineer`](requirements-engineer.md) | PRD, User Stories, MVP-Schnitt | 1 |
| [`ui-ux-designer`](ui-ux-designer.md) | Design-System, Claude-Design-Prompts, Freigabe | 2 |
| [`solution-architect`](solution-architect.md) | Stack, ADRs, Datenmodell, API-Vertrag | 3 |
| [`backend-dev`](backend-dev.md) | API, Datenbank, Auth, RLS | 4a |
| [`frontend-dev`](frontend-dev.md) | Screens, Navigation, State, Anbindung | 4b |
| [`qa-engineer`](qa-engineer.md) | Testplan, Tests, Bugs, Abnahme | 5 |
| [`security-reviewer`](security-reviewer.md) | Audit, DSGVO, Store-Compliance | 6 |
| [`devops`](devops.md) | CI/CD, Signing, Umgebungen, Monitoring | 7 |
| [`release-manager`](release-manager.md) | Store-Listings, Assets, Rollout | 8 |

## Ablauf

```
1 Anforderungen  →  2 Design (Claude Design)  →  GATE  →  3 Architektur
                                                              ↓
                                          4a Backend  ‖  4b Mobile App
                                                              ↓
        5 QA  →  GATE  →  6 Security  →  GATE  →  7 CI/CD  →  8 Release
```

## Schnellstart

```
/agentur-start <App-Idee>    Projekt anlegen, Anforderungen erheben
/agentur-design              Design-System + Prompt-Pack für Claude Design
                             → Prompts in Claude Design ausführen, Screens freigeben
/agentur-build               Architektur + Implementierung
/agentur-review              QA und Security-Review
/agentur-release             CI/CD und Store-Veröffentlichung
/agentur-status              Stand, Gate-Status, nächster Schritt
```

Ohne Slash-Command genügt: „Starte ein neues App-Projekt: <Idee>" — der `tech-lead`
übernimmt die Steuerung.

## Einzelne Agenten direkt ansprechen

```
Nutze den Agent ui-ux-designer für die Design-Phase des Onboardings.
Lass den security-reviewer die Auth-Implementierung prüfen.
```

## Projektstruktur

Alle Ergebnisse landen im Ordner `agentur/` des jeweiligen Projekts —
Struktur und Vorlagen siehe [SKILL.md](../skills/software-agentur/SKILL.md).

## Standard-Stack

React Native + Expo (TypeScript) · Expo Router · TanStack Query + Zustand ·
Supabase (Postgres, Auth, Storage, RLS) · Sentry · EAS Build & Submit.
Abweichungen werden vom `solution-architect` als ADR begründet.
