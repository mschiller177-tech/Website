# PRD — <App-Name>

- **Version:** 1.0 · **Datum:** YYYY-MM-DD · **Autor:** requirements-engineer
- **Plattformen:** iOS <min-version> · Android <min-api>
- **Status:** Entwurf | In Prüfung | Freigegeben

## 1. Zielbild

**Problem:** <Welches Problem hat wer, wie oft, wie schmerzhaft?>
**Lösung:** <Ein Satz.>
**Nutzenversprechen:** <Warum diese App und nicht die Alternative?>

## 2. Erfolgskriterien

| Kennzahl | Zielwert | Messung |
|----------|----------|---------|
| | | |

## 3. Personas

### Persona 1 — <Name, Rolle>
- Kontext: <Situation, Gerät, Umgebung>
- Ziel: <Was will sie erreichen?>
- Frustration heute: <Was nervt an der aktuellen Lösung?>

## 4. Nutzerreisen

### Reise 1 — <Name>
1. <Schritt>
2. <Schritt>
- Fehlerfall: <Was passiert, wenn es schiefgeht?>

## 5. Funktionale Anforderungen

### US-001 — <Titel>
**Priorität:** Must | Should | Could | Won't
Als <Rolle> möchte ich <Ziel>, damit <Nutzen>.

```gherkin
Szenario: <Name>
  Angenommen <Ausgangszustand>
  Wenn <Aktion>
  Dann <erwartetes Ergebnis>
```

## 6. Nichtfunktionale Anforderungen

| Bereich | Anforderung |
|---------|-------------|
| Performance | Kaltstart < 2 s, Listen-Scroll 60 fps |
| Offline | <Welche Funktionen ohne Netz?> |
| Barrierefreiheit | WCAG 2.2 AA, Dynamic Type bis 200 %, VoiceOver/TalkBack |
| Datenschutz | DSGVO, Löschkonzept, Datenminimierung |
| Sprachen | <de, en, …> |
| Geräte | <kleinste/größte unterstützte Displays, Tablet ja/nein> |

## 7. Plattform-Spezifika

| Thema | iOS | Android |
|-------|-----|---------|
| Navigation | | |
| Push | | |
| Berechtigungen | | |
| Bezahlung | | |

## 8. Store-Anforderungen

- Benötigte Berechtigungen mit Begründung: <…>
- Account-Löschung in der App: erforderlich ja/nein
- Datenschutzerklärung: <URL>
- Altersfreigabe: <…>

## 9. MVP-Schnitt

| Story | Priorität | Im MVP |
|-------|-----------|--------|

## 10. Nicht im Scope

- <Was ausdrücklich nicht gebaut wird und warum>

## 11. Annahmen

- <Annahme + Auswirkung, falls sie falsch ist>

## 12. Offene Fragen

- [ ] <Frage> — blockiert: <Phase>
