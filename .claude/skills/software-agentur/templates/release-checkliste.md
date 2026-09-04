# Release-Checkliste — <App-Name> v<x.y.z>

## Code & Qualität

- [ ] Alle MVP-Stories umgesetzt und abgenommen
- [ ] Keine offenen Blocker- oder Hoch-Bugs
- [ ] Typecheck, Lint und Tests grün
- [ ] E2E der kritischen Flows auf iOS und Android grün
- [ ] Keine Debug-Menüs, Testdaten oder Platzhalter in der App
- [ ] Versionsnummer und Build-Nummer erhöht

## Sicherheit & Datenschutz

- [ ] Security-Review ohne offene kritische Befunde
- [ ] Keine Secrets im App-Bundle
- [ ] Datenschutzerklärung erreichbar und in der App verlinkt
- [ ] Account-Löschung in der App möglich (bei Login verpflichtend)
- [ ] Apple Privacy Manifest gepflegt
- [ ] Play Data Safety ausgefüllt und konsistent zum Code
- [ ] Jede Berechtigung wird genutzt und ist begründet

## Builds

- [ ] Release-Build iOS erstellt und signiert
- [ ] Release-Build Android (AAB) erstellt und signiert
- [ ] Auf physischen Geräten beider Plattformen installiert und getestet
- [ ] Kaltstart ohne Absturz auf dem kleinsten unterstützten Gerät
- [ ] Sourcemaps an Crash-Reporting übertragen

## Store-Einträge

- [ ] Titel, Untertitel, Beschreibung, Keywords gepflegt
- [ ] Screenshots in allen Pflichtformaten
- [ ] App-Icon in allen Größen, iOS ohne Alphakanal
- [ ] Feature-Graphic (Play) 1024×500
- [ ] „Was ist neu" konkret formuliert
- [ ] Altersfreigabe ausgefüllt
- [ ] Support- und Marketing-URL erreichbar
- [ ] Testzugangsdaten für den Review hinterlegt

## Rollout

- [ ] Interne Tests abgeschlossen
- [ ] Beta-Feedback ausgewertet
- [ ] Play: gestaffelter Rollout 10 % geplant
- [ ] iOS: Phased Release aktiviert
- [ ] Monitoring und Alarme aktiv
- [ ] Rollback-Weg dokumentiert und verstanden

## Nach dem Rollout (T+24 h)

- [ ] Crash-Rate im Rahmen
- [ ] Backend-Fehlerrate und Latenz im Rahmen
- [ ] Erste Bewertungen gesichtet
- [ ] Entscheidung: Rollout erhöhen / anhalten
