---
description: Prüft das App-Grundgerüst und führt den Klick-Test — funktioniert wirklich jeder Button, jedes Feld, jede Nachricht?
argument-hint: "[screen oder bereich]"
---

Prüfe die App gegen das Grundgerüst und die Interaktions-Checkliste.

Bereich (optional): $ARGUMENTS

Vorgehen:

1. Lies `.claude/skills/software-agentur/references/app-grundgeruest.md` und
   `.claude/skills/software-agentur/references/interaktions-checkliste.md`.
2. **Grundgerüst-Abgleich:** Gehe die 16 Abschnitte durch und stelle für diese App fest:
   umgesetzt · fehlt · bewusst nicht nötig (mit Begründung).
   Schwerpunkt auf den Punkten, die am häufigsten fehlen:
   - globale Fehlerbehandlung (Error Boundary) und die Fehlertabelle aus Abschnitt 5
   - Lade-, Leer-, Fehler- und Offline-Zustand auf **jedem** Screen
   - Account-Löschung, Sitzungsablauf, Passwort vergessen
   - Force-Update, Wartungsmodus, Deep Links, Berechtigungs-Verweigerungsfall
   - Einstellungen, Rechtliches, Support-Kontakt
3. **Klick-Test** (aus der Interaktions-Checkliste), auf beiden Plattformen:
   jedes Element antippen · Doppeltipp · leeres Formular absenden · Maximalwerte ·
   jeden Screen im Flugmodus · Hintergrund und zurück während einer Aktion ·
   Systemschrift 200 % · Dunkelmodus.
4. Prüfe im Code gezielt die typischen Fehlerquellen:
   Schaltflächen ohne `onPress`, fehlende `disabled`-Sperre während des Ladens,
   Formulare ohne Absende-Sperre, Netzaufrufe ohne Fehlerpfad, Listen ohne Leerzustand,
   Nachrichten ohne Sendestatus und ohne Idempotenzschlüssel.
5. Ergebnis nach `agentur/04-implementation/klick-test.md` schreiben:
   geprüft · Befunde mit Screen und Element · was blockiert die Übergabe an QA.
6. Befunde als Aufgaben an `frontend-dev` bzw. `backend-dev` übergeben und im
   Board unter `agentur/kommunikation/board.md` eintragen.

Ohne diese Notiz nimmt der `qa-engineer` die Übergabe nicht an.
