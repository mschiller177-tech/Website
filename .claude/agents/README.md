# KI-Software-Agentur — Entwicklungsteam für iOS & Android

17 spezialisierte Subagenten, die einen professionellen Entwicklungsprozess simulieren:
von der Idee bis zum Store-Release. Gesteuert vom Prozess-Skill
[`software-agentur`](../skills/software-agentur/SKILL.md).

## Drei Grundregeln

1. **Zuerst Design in Claude Design — dann Umsetzung in Claude Code.**
   Phase 2 endet mit `agentur/02-design/DESIGN-FREIGABE.md`. Steht dort nicht
   `Status: FREIGEGEBEN`, verweigert `frontend-dev` die Arbeit.
2. **Die Agenten kommunizieren über Dateien.** Posteingang lesen → arbeiten →
   Übergabe schreiben. Protokoll: [`kommunikation.md`](../skills/software-agentur/references/kommunikation.md).
3. **Nichts gilt als fertig, was nicht bedienbar ist.** Klick-Test vor jeder Übergabe an QA.

## Kernteam

| Agent | Rolle | Phase |
|-------|-------|-------|
| [`tech-lead`](tech-lead.md) | Agentur-Lead, Orchestrierung, Gates, Vermittlung | alle |
| [`requirements-engineer`](requirements-engineer.md) | PRD, User Stories, MVP-Schnitt | 1 |
| [`ui-ux-designer`](ui-ux-designer.md) | Design-System, Claude-Design-Prompts, Freigabe | 2 |
| [`solution-architect`](solution-architect.md) | Stack, ADRs, Datenmodell, API-Vertrag | 3 |
| [`backend-dev`](backend-dev.md) | API, Datenbank, Auth, RLS | 4a |
| [`frontend-dev`](frontend-dev.md) | Screens, Navigation, State, Anbindung | 4b |
| [`security-reviewer`](security-reviewer.md) | Code-Audit, DSGVO, Store-Compliance | 6 |
| [`devops`](devops.md) | CI/CD, Signing, Umgebungen, Monitoring | 7 |
| [`release-manager`](release-manager.md) | Store-Listings, Assets, Rollout | 8 |

## Testteam (Phase 5, geleitet vom QA Lead)

| Agent | Prüft |
|-------|-------|
| [`qa-engineer`](qa-engineer.md) | **QA Lead** — Teststrategie, Beauftragung, Konsolidierung, Abnahme |
| [`functional-tester`](functional-tester.md) | Akzeptanzkriterien, Flows, Grenzfälle, Regression |
| [`api-tester`](api-tester.md) | Vertragstreue, Fehlerpfade, IDOR, Idempotenz |
| [`performance-tester`](performance-tester.md) | Startzeit, Bildrate, Speicher, Lasttest (k6) |
| [`security-tester`](security-tester.md) | Laufzeitangriffe: Sitzung, Speicher, Transport, Eingaben |
| [`accessibility-tester`](accessibility-tester.md) | WCAG 2.2 AA, VoiceOver/TalkBack, Schrift 200 % |
| [`compatibility-tester`](compatibility-tester.md) | Geräte-/OS-Matrix, Sprachen, Update-Test |
| [`test-automation-engineer`](test-automation-engineer.md) | Jest, RNTL, Maestro/Detox, CI |

## Ablauf

```
1 Anforderungen  →  2 Design (Claude Design)  →  GATE  →  3 Architektur
                                                              ↓
                                          4a Backend  ‖  4b Mobile App
                                                              ↓
                                                      Klick-Test (Gate)
                                                              ↓
                                 5 QA mit Testteam (7 Tester, parallel)
                                                              ↓
        GATE  →  6 Security  →  GATE  →  7 CI/CD  →  8 Release
```

## Verbindliche Wissensbasis

Jeder Agent liest vor Arbeitsbeginn die für seine Rolle benannten Referenzen in
[`../skills/software-agentur/references/`](../skills/software-agentur/references/):

| Datei | Inhalt |
|-------|--------|
| `kommunikation.md` | Wie die Agenten zusammenarbeiten: Board, Übergaben, Rückfragen, Konflikte |
| `app-grundgeruest.md` | Was jede App braucht — 16 Bereiche, Mindest-Screens, Fehlertabelle |
| `interaktions-checkliste.md` | Button, Eingabefeld, Formular, Nachricht, Liste, Navigation + Klick-Test |
| `security.md` | OWASP MASVS, DSGVO, Store-Compliance |
| `performance.md` | Budgets und Messverfahren |
| `skalierbarkeit.md` | 10×-Test, Caching, Lastspitzen, Beobachtbarkeit |

## Schnellstart

```
/agentur-start <App-Idee>    Projekt anlegen, Anforderungen erheben
/agentur-design              Design-System + Prompt-Pack für Claude Design
                             → Prompts in Claude Design ausführen, Screens freigeben
/agentur-build               Architektur + Implementierung
/agentur-check               Grundgerüst + Klick-Test: funktioniert wirklich alles?
/agentur-review              QA mit Testteam und Security-Review
/agentur-release             CI/CD und Store-Veröffentlichung
/agentur-status              Stand, Board, Blocker, nächster Schritt
```

Ohne Slash-Command genügt: „Starte ein neues App-Projekt: <Idee>" — der `tech-lead`
übernimmt die Steuerung.

## Einzelne Agenten direkt ansprechen

```
Nutze den Agent ui-ux-designer für die Design-Phase des Onboardings.
Lass den security-tester die Sitzungsverwaltung angreifen.
Lass den qa-engineer sein Testteam auf den Checkout ansetzen.
```

## In anderen Claude-Oberflächen: MCP-Server

Für Claude Desktop und andere MCP-Clients gibt es die Agentur als MCP-Server:
15 Tools, 7 Prompts, alle Referenzen als Ressourcen — ohne Installation von
Abhängigkeiten. Siehe [`mcp/agentur_mcp/README.md`](../../mcp/agentur_mcp/README.md).

```
agentur_list_team · agentur_get_agent_briefing · agentur_get_process
agentur_get_reference · agentur_get_template · agentur_get_checklist
agentur_init_project · agentur_get_project_status · agentur_check_gate
agentur_set_design_approval · agentur_get_inbox · agentur_post_message
agentur_answer_message · agentur_write_handover · agentur_update_board
```

## Projektstruktur

Alle Ergebnisse landen im Ordner `agentur/` des jeweiligen Projekts, inklusive
`agentur/kommunikation/` für Board, Übergaben und Rückfragen —
Struktur und Vorlagen siehe [SKILL.md](../skills/software-agentur/SKILL.md).

## Standard-Stack

React Native + Expo (TypeScript) · Expo Router · TanStack Query + Zustand ·
Supabase (Postgres, Auth, Storage, RLS) · Sentry · EAS Build & Submit.
Abweichungen werden vom `solution-architect` als ADR begründet.
