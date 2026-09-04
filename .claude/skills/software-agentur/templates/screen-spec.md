# Screen: <Name>

- **Story-IDs:** US-00x, US-00y
- **Einstiegspunkte:** <von welchen Screens / Deep Link / Push>
- **Zweck:** <ein Satz>

## Layout (von oben nach unten)

1. <Element> — Token: <…>
2. <Element>
3. <Element>

## Verwendete Komponenten

| Komponente | Variante | Anmerkung |
|------------|----------|-----------|

## Zustände

| Zustand | Auslöser | Darstellung |
|---------|----------|-------------|
| Standard | Daten vorhanden | <…> |
| Laden | Erstabruf | Skeleton, kein Spinner-Vollbild |
| Leer | Keine Daten | Text + primäre Aktion |
| Fehler | Request fehlgeschlagen | Meldung + „Erneut versuchen" |
| Offline | Kein Netz | Hinweisleiste, gecachte Daten |
| Keine Berechtigung | Zugriff verweigert | Erklärung + Weg zu den Einstellungen |

## Interaktionen

| Auslöser | Aktion | Ziel / Ergebnis |
|----------|--------|-----------------|

## Texte (Wortlaut)

| Element | Text |
|---------|------|
| Titel | |
| Primäre Aktion | |
| Leerzustand | |
| Fehlermeldung | |

## Validierung

| Feld | Regel | Fehlermeldung |
|------|-------|---------------|

## Plattformunterschiede

- iOS: <…>
- Android: <…>

## Barrierefreiheit

- Screenreader-Labels: <…>
- Fokusreihenfolge: <…>
- Mindestkontrast geprüft: ja/nein
