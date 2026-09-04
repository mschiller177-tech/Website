# Design-Brief — <App-Name>

## 1. Ausgangslage

- Produkttyp: <…>
- Zielgruppe: <…>
- Wettbewerb / Referenz-Apps: <…>
- Markenpersönlichkeit (3–5 Adjektive): <…>

## 2. Designrichtung

- Stilrichtung: <z. B. Minimalismus mit Bento-Grid> — **Begründung:** <…>
- Recherchequelle: `search.py "<query>" --domain style`
- Bildsprache: <Fotografie / Illustration / Icons>
- Hell- und Dunkelmodus: beide von Anfang an

## 3. Design-System (Kurzfassung)

### Farben
| Token | Hell | Dunkel | Verwendung | Kontrast |
|-------|------|--------|------------|----------|
| `color.bg` | #… | #… | Hintergrund | — |
| `color.surface` | #… | #… | Karten, Sheets | — |
| `color.text` | #… | #… | Fließtext | x.x:1 |
| `color.text.muted` | #… | #… | Sekundärtext | x.x:1 |
| `color.primary` | #… | #… | Hauptaktion | x.x:1 |
| `color.danger` | #… | #… | Fehler | x.x:1 |

### Typografie
| Token | Größe/Zeilenhöhe | Gewicht | Verwendung |
|-------|------------------|---------|------------|
| `text.display` | 32/40 | 700 | Screen-Titel |
| `text.title` | 22/28 | 600 | Abschnitte |
| `text.body` | 16/24 | 400 | Fließtext |
| `text.caption` | 13/18 | 400 | Hilfstext |

### Spacing, Radius, Motion
- Raster: 4 pt — Skala 4 / 8 / 12 / 16 / 24 / 32 / 48
- Radius: `sm` 8 · `md` 12 · `lg` 20 · `full` 999
- Motion: Standard 200 ms `ease-out`; Sheets 300 ms; Reduce-Motion respektieren

## 4. Mobile-Grundregeln

- Touch-Targets ≥ 44 pt (iOS) / 48 dp (Android)
- Safe Areas auf jedem Screen
- Schriftskalierung bis 200 % ohne Layoutbruch
- Kontrast: Text ≥ 4.5:1, UI-Elemente ≥ 3:1

## 5. Screens

| Screen | Story-ID | Zweck |
|--------|----------|-------|

## 6. Plattformunterschiede

| Element | iOS | Android |
|---------|-----|---------|
| Navigation | | |
| Modal / Sheet | | |
| Datumsauswahl | | |
| Haptik | | |
