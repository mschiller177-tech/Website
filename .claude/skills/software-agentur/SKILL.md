---
name: software-agentur
description: "Simuliert eine komplette Software-Agentur aus spezialisierten KI-Agenten für professionelle iOS- und Android-Apps. Verbindlicher Prozess mit Quality Gates: Anforderungen → Design (Claude Design) → Architektur → Implementierung → QA → Security → CI/CD → Release. Use for: App entwickeln, App bauen, Mobile App, iOS, Android, Entwicklungsprozess, Agentur, Team simulieren, Projekt starten, Sprint, Softwareprojekt, build an app, development team, mobile development workflow."
argument-hint: "[app-idee]"
license: MIT
metadata:
  version: "1.0.0"
---

# Software-Agentur — KI-Entwicklungsteam für iOS & Android

Ein vollständiges Entwicklungsteam aus spezialisierten Agenten, das eine App-Idee in
definierten Phasen zu einer veröffentlichungsfähigen App führt.

## Grundregel

> **Zuerst Design in Claude Design. Danach Umsetzung in Claude Code.**

Kein UI-Code entsteht, bevor das Design steht und freigegeben ist. Diese Regel ist als
Gate in Phase 2 verankert und wird von `tech-lead` und `frontend-dev` geprüft.

## Das Team

| Agent | Rolle | Verantwortung |
|-------|-------|---------------|
| `tech-lead` | Agentur-Lead | Orchestrierung, Delegation, Gates, Projektstand |
| `requirements-engineer` | Product Owner | PRD, User Stories, Akzeptanzkriterien, MVP |
| `ui-ux-designer` | UI/UX Design | Design-Brief, Claude-Design-Prompts, Design-System, Freigabe |
| `solution-architect` | Architektur | Tech-Stack, ADRs, Datenmodell, API-Vertrag |
| `frontend-dev` | Mobile Entwicklung | Screens, Navigation, State, API-Anbindung |
| `backend-dev` | Backend | API, Datenbank, Auth, RLS, Migrationen |
| `qa-engineer` | Qualitätssicherung | Testplan, automatisierte Tests, Bugs, Abnahme |
| `security-reviewer` | Security & Compliance | Audit, DSGVO, Store-Datenschutzangaben |
| `devops` | DevOps | CI/CD, Signing, Umgebungen, Monitoring |
| `release-manager` | Release | Store-Listings, Assets, Rollout |

Die Agenten liegen in `.claude/agents/` und werden vom Lead per `Task` beauftragt.

## Prozess in acht Phasen

```mermaid
flowchart TD
    A[1 Anforderungen] --> B[2 Design — Claude Design]
    B -->|GATE: Design freigegeben| C[3 Architektur]
    C --> D1[4a Backend]
    C --> D2[4b Mobile App]
    D1 --> E[5 QA]
    D2 --> E
    E -->|GATE: keine Blocker| F[6 Security & Compliance]
    F -->|GATE: freigegeben| G[7 CI/CD]
    G --> H[8 Release]
```

### Phase 1 — Anforderungen · `requirements-engineer`
Idee → PRD, User Stories mit Akzeptanzkriterien, MVP-Schnitt, Scope-Abgrenzung.
**Gate:** Jede MVP-Story hat testbare Akzeptanzkriterien.

### Phase 2 — Design · `ui-ux-designer` **(Claude Design)**
Design-Brief, Design-System (Tokens), ein fertiger Prompt je Screen für **Claude Design**,
Screen-Spezifikationen mit allen Zuständen, Plattformunterschiede iOS/Android.
Der Mensch führt die Prompts in Claude Design aus und gibt die Ergebnisse frei.
**Gate:** `agentur/02-design/DESIGN-FREIGABE.md` steht auf `FREIGEGEBEN`.

### Phase 3 — Architektur · `solution-architect`
Tech-Stack (Standard: React Native + Expo + Supabase), ADRs, Datenmodell mit
Zugriffsregeln, API-Vertrag, Offline-Strategie, Projektstruktur.
**Gate:** API-Vertrag deckt alle MVP-Stories ab.

### Phase 4 — Implementierung · `backend-dev` + `frontend-dev`
Beide arbeiten parallel gegen den API-Vertrag.
**Gate:** Typecheck, Lint und Tests grün; alle MVP-Screens mit allen Zuständen.

### Phase 5 — Qualitätssicherung · `qa-engineer`
Testplan, automatisierte Tests, E2E der kritischen Flows, explorative Tests, Bugliste.
**Gate:** keine offenen Blocker- oder Hoch-Bugs.

### Phase 6 — Security & Compliance · `security-reviewer`
Secrets, Auth, Datenhaltung, Netzwerk, Abhängigkeiten, DSGVO, Store-Datenschutzangaben.
**Gate:** keine kritischen Befunde offen.

### Phase 7 — CI/CD · `devops`
Pipelines, Signing, Umgebungen, OTA-Updates, Crash-Reporting, Runbook.
**Gate:** reproduzierbare Builds für iOS und Android.

### Phase 8 — Release · `release-manager`
Store-Listings, Assets, Prüfung der Ablehnungsgründe, gestaffelter Rollout.
**Gate:** Release-Checkliste vollständig abgehakt.

## Projekt-Workspace

Jedes Projekt bekommt diese Struktur:

```
agentur/
├── PROJEKT.md                  Steckbrief, Phasenstatus, Entscheidungen, Risiken
├── 01-requirements/            prd.md, user-stories.md, backlog.md, nicht-im-scope.md
├── 02-design/                  design-brief.md, claude-design-prompts.md,
│                               design-system.md, komponenten.md, screens/,
│                               DESIGN-FREIGABE.md
├── 03-architecture/            architektur.md, datenmodell.md, api-vertrag.md,
│                               projektstruktur.md, adr/
├── 04-implementation/          backend-notizen.md, frontend-notizen.md
├── 05-qa/                      testplan.md, testfaelle.md, bugs.md, abnahme.md
├── 06-security/                befunde.md, datenschutz.md
├── 07-devops/                  umgebungen.md, runbook.md
└── 08-release/                 store-listing-ios.md, store-listing-android.md,
                                assets.md, release-checkliste.md, changelog.md
```

Vorlagen liegen in `.claude/skills/software-agentur/templates/`.

## Start

```
/agentur-start <App-Idee>       Projekt anlegen und Phase 1 starten
/agentur-design                 Design-Phase (Claude Design) durchführen
/agentur-build                  Implementierung starten (nur nach Design-Freigabe)
/agentur-status                 Projektstand und nächster Schritt
/agentur-release                Release vorbereiten
```

Alternativ direkt: „Starte ein neues App-Projekt: <Idee>" — der `tech-lead` übernimmt.

## Arbeitsregeln der Agentur

1. **Kein Sprung über eine Phase.** Wer Ergebnisse einer Vorphase braucht, wartet oder
   fordert sie an.
2. **Kein Gate ohne Prüfung.** Der Lead prüft jedes Gate selbst; nicht bestanden heißt
   zurück an den Agent mit konkreter Mängelliste.
3. **Artefakte sind die Wahrheit.** Was nicht in `agentur/` steht, gilt als nicht entschieden.
4. **Annahmen werden dokumentiert**, nicht stillschweigend getroffen.
5. **Widersprüche löst der Lead auf** und hält die Entscheidung als ADR fest.
6. **Scope-Erweiterungen** landen im Backlog, nicht im laufenden Sprint.
7. **Jede Entscheidung wird begründet** — vor allem Stack- und Designentscheidungen.

## Design-Datenbank nutzen

Vor jeder Designentscheidung die Datenbank des Repos befragen:

```bash
python3 src/ui-ux-pro-max/scripts/search.py "<query>" --domain product|style|color|typography|ux
python3 src/ui-ux-pro-max/scripts/search.py "<query>" --stack react-native
```

Ergänzende Skills: `ui-ux-pro-max`, `design`, `design-system`, `ui-styling`.

## Standard-Stack

Ohne gegenteilige Anforderung: **React Native + Expo (TypeScript)**, Expo Router,
TanStack Query + Zustand, **Supabase** (Postgres, Auth, Storage, RLS), Sentry,
EAS Build & Submit. Abweichungen brauchen ein ADR.
