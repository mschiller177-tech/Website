# Kommunikationsprotokoll der Agentur

Die Agenten arbeiten nacheinander und teilweise parallel — sie sehen den Verlauf der
anderen nicht. Deshalb kommunizieren sie **über Dateien**. Was nicht geschrieben wurde,
ist nicht gesagt worden.

Verbindlich für alle Agenten.

## Die drei Pflichtschritte jedes Agenten

Jeder Agent hält sich an denselben Ablauf — ohne Ausnahme:

### 1. Posteingang lesen (vor der Arbeit)

```
agentur/kommunikation/board.md          → Was ist mir zugewiesen? Wartet jemand auf mich?
agentur/kommunikation/uebergaben/       → Die Übergabe an mich, falls vorhanden
agentur/kommunikation/rueckfragen.md    → Offene Fragen an mich
agentur/kommunikation/entscheidungen.md → Was wurde seit meinem letzten Einsatz entschieden?
```

Erst lesen, dann arbeiten. Wer ohne Posteingang startet, wiederholt Entscheidungen,
die längst gefallen sind.

### 2. Arbeiten und dokumentieren

Ergebnisse in den eigenen Phasenordner unter `agentur/`. Jede getroffene Annahme wird
festgehalten, nicht stillschweigend gemacht.

### 3. Postausgang schreiben (nach der Arbeit)

- **Übergabe** an den nächsten Agenten: `agentur/kommunikation/uebergaben/<phase>-<von>-an-<zu>.md`
- **Board aktualisieren:** eigene Zeile auf `fertig`, nächste Zeile auf `bereit`
- **Rückfragen eintragen**, die andere beantworten müssen
- **Entscheidungen eintragen**, die andere betreffen

Ein Agent gilt erst als fertig, wenn Schritt 3 erledigt ist.

## Nachrichtenformat

Jede Nachricht zwischen Agenten hat diesen Kopf — kurz, immer gleich, sofort lesbar:

```markdown
### MSG-00x · <Betreff>
- **Von:** <agent>  **An:** <agent oder Mensch>
- **Typ:** Übergabe | Rückfrage | Befund | Entscheidung | Blocker
- **Dringlichkeit:** Blocker | Hoch | Normal
- **Bezug:** US-00x / ADR-00x / BUG-00x / Screen
- **Status:** offen | beantwortet | erledigt

**Inhalt:** <Sachverhalt in 1–5 Sätzen>
**Erwartet:** <was der Empfänger konkret tun oder entscheiden soll>
**Frist:** <bis wann, oder „blockiert Phase n">
```

## Übergabedokument (Pflicht bei jedem Phasenwechsel)

```markdown
# Übergabe: <von-agent> → <an-agent> (Phase <n> → <n+1>)

## Was fertig ist
- <Ergebnis> → <Datei>

## Was der Empfänger als Erstes lesen soll
1. <Datei> — <warum>

## Entscheidungen, die den Empfänger binden
| Entscheidung | Begründung | Verweis |

## Annahmen, die ich getroffen habe
| Annahme | Auswirkung, falls falsch |

## Was bewusst offen bleibt
- <Punkt> — <wer entscheidet>

## Bekannte Risiken für die nächste Phase
- <Risiko> → <Empfehlung>

## Definition of Done meiner Phase
- [x] … / - [ ] … (offene Punkte begründet)
```

Eine Übergabe ohne Abschnitt „Annahmen" und „Was offen bleibt" ist unvollständig.

## Kommunikationswege

**Grundsatz: Der `tech-lead` ist die Vermittlungsstelle.** Alles, was Scope, Termine,
Architektur oder Kosten berührt, läuft über ihn.

Direkte Wege ohne Umweg — weil täglich gebraucht:

| Von | An | Inhalt |
|-----|----|--------|
| Tester | `qa-engineer` | Prüfberichte und Befunde |
| `qa-engineer` | `frontend-dev`, `backend-dev` | Bugs zur Behebung |
| `security-reviewer`, `security-tester` | `frontend-dev`, `backend-dev` | Sicherheitsbefunde |
| `frontend-dev` | `backend-dev` | Fragen zum API-Vertrag (Kopie an `solution-architect`) |
| `ui-ux-designer` | `frontend-dev` | Design-Rückfragen zur Umsetzung |
| `devops` | `test-automation-engineer` | CI-Anbindung der Testsuite |

Über den Lead läuft: Scope-Änderungen · Stack-Entscheidungen · Terminverschiebungen ·
Konflikte zwischen Agenten · alles, was den Menschen betrifft.

## Rückfragen

- Rückfrage in `rueckfragen.md` eintragen, Empfänger benennen, **weiterarbeiten** an dem,
  was nicht davon abhängt.
- Blockiert die Frage alles, `Dringlichkeit: Blocker` setzen und den Lead informieren.
- Nach **zwei** Runden ohne Klärung entscheidet der Lead und hält die Entscheidung fest.
  Endlose Rückfragen zwischen zwei Agenten sind unzulässig.
- Fragen an den Menschen werden gebündelt, nicht einzeln gestellt.

## Konflikte zwischen Agenten

Beispiel: `solution-architect` verlangt Cursor-Paginierung, `ui-ux-designer` hat eine
Seitenzahl-Navigation entworfen.

1. Wer den Konflikt bemerkt, trägt ihn im Board als `Konflikt` ein — mit beiden Positionen.
2. Der `tech-lead` entscheidet innerhalb einer Runde.
3. Die Entscheidung wird in `entscheidungen.md` und, wenn architektonisch, als ADR festgehalten.
4. Beide Agenten passen ihre Artefakte an. Stillschweigendes Ignorieren ist ein Verstoß.

## Eskalation an den Menschen

Nur der `tech-lead` spricht den Menschen an — gebündelt, und nur bei:

- fachlicher Unklarheit, die keine Annahme auflösen kann
- Scope-Erweiterung
- Design-Freigabe (Phase 2)
- Blocker-Befund kurz vor dem Release
- Kosten- oder Terminfolgen

Format: maximal 10 Zeilen, mit Empfehlung und Auswirkung je Option.

## Statusrunde nach jeder Phase

Der `tech-lead` schreibt eine Kurznotiz in `agentur/kommunikation/standup.md`:

```markdown
## Runde <n> — <Datum>
| Agent | Erledigt | Als Nächstes | Blockiert durch |
Entscheidungen dieser Runde: <…>
Offene Fragen an den Menschen: <…>
```

## Schreibrechte (verhindert Überschreiben bei paralleler Arbeit)

Jede Datei hat **einen** Eigentümer. Andere lesen und schreiben Anmerkungen ins Board —
sie ändern fremde Dateien nicht.

| Ordner | Eigentümer |
|--------|------------|
| `01-requirements/` | `requirements-engineer` |
| `02-design/` | `ui-ux-designer` |
| `03-architecture/` | `solution-architect` |
| `04-implementation/` | `frontend-dev`, `backend-dev` (je eigene Notizdatei) |
| `05-qa/` | `qa-engineer` (Tester schreiben nur in `05-qa/berichte/<eigener-name>.md`) |
| `06-security/` | `security-reviewer` |
| `07-devops/` | `devops` |
| `08-release/` | `release-manager` |
| `PROJEKT.md`, `kommunikation/board.md`, `standup.md`, `entscheidungen.md` | `tech-lead` |
| `kommunikation/rueckfragen.md`, `uebergaben/` | alle (nur eigene Einträge anfügen) |

## Sprachregeln

- Sachlich, kurz, ohne Füllwörter. Ein Absatz je Gedanke.
- Behauptungen mit Beleg: Datei, Zeile, Messwert oder Story-ID.
- „Erledigt" nur, wenn geprüft — nicht, wenn geschrieben.
- Probleme werden benannt, nicht abgeschwächt. Ein verschwiegenes Risiko kostet später
  ein Vielfaches.
- Auf Deutsch, Fachbegriffe bleiben englisch.
