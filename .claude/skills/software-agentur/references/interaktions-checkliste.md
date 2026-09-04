# Interaktions-Checkliste — jedes Element muss funktionieren

Diese Liste verhindert die Fehlerklasse, die Nutzer am schnellsten bemerken:
**Ein Button, der nichts tut. Ein Feld, das den Text frisst. Eine Nachricht, die
zweimal ankommt.**

Verbindlich für `frontend-dev` (beim Bauen) und `functional-tester` (beim Prüfen).
Jedes bedienbare Element wird gegen den passenden Abschnitt geprüft, bevor es als
fertig gilt.

## Grundregel

> Jede Berührung erzeugt binnen 100 ms eine sichtbare Reaktion.
> Jede Aktion endet sichtbar — mit Erfolg oder mit einem Fehler samt Ausweg.
> Keine Aktion lässt sich versehentlich doppelt auslösen.

## 1. Button / Schaltfläche

- [ ] Sichtbares Feedback beim Drücken (Farbe, Skalierung, Haptik)
- [ ] **Zustände umgesetzt:** Standard · Gedrückt · Deaktiviert · Ladend · Erfolg
- [ ] Während der Ausführung: deaktiviert **und** mit Ladeanzeige — sonst entstehen
      Doppelbuchungen
- [ ] Doppeltipp-Schutz (zweiter Tipp innerhalb der Ausführung wird verworfen)
- [ ] Deaktivierter Button erklärt, warum er deaktiviert ist (Hinweistext in der Nähe)
- [ ] Trefferfläche ≥ 44×44 pt / 48×48 dp, auch bei kleinem Symbol
- [ ] Beschriftung sagt, was passiert („Speichern", nicht „OK")
- [ ] Screenreader-Label und Rolle gesetzt
- [ ] Zerstörerische Aktion optisch abgesetzt und mit Bestätigung
- [ ] **Kein Button ohne Wirkung** — jede Schaltfläche ist verdrahtet oder nicht vorhanden

## 2. Eingabefeld

- [ ] Sichtbares Label über dem Feld (Platzhalter ist **kein** Label)
- [ ] Passender Tastaturtyp (E-Mail, Zahl, Telefon, Passwort)
- [ ] Autokorrektur und Autokapitalisierung aus bei Codes, Benutzernamen, E-Mail
- [ ] Autofill-Hinweise gesetzt (E-Mail, Passwort, Einmalcode)
- [ ] Passwortfeld mit Umschalter „anzeigen/verbergen"
- [ ] Zeichenlimit sichtbar, Eingabe wird begrenzt statt abgeschnitten
- [ ] Leerzeichen am Anfang und Ende werden entfernt
- [ ] Eingefügter Text (Copy-Paste) wird korrekt verarbeitet, auch mit Formatierung
- [ ] Sehr lange Eingaben brechen das Layout nicht
- [ ] Emoji, Umlaute und Sonderzeichen funktionieren
- [ ] Tastatur verdeckt weder das Feld noch die primäre Schaltfläche
- [ ] „Weiter"-Taste springt zum nächsten Feld, „Fertig" schließt die Tastatur
- [ ] Tippen außerhalb schließt die Tastatur
- [ ] Feldinhalt überlebt Drehen des Geräts und kurzes Wechseln in den Hintergrund
- [ ] Löschen-Symbol bei gefülltem Feld

## 3. Validierung

- [ ] Validierung beim Verlassen des Feldes, nicht bei jedem Tastendruck
- [ ] Fehlertext direkt am Feld, in verständlicher Sprache
- [ ] Fehler verschwindet, sobald korrigiert wurde
- [ ] Serverseitige Fehler landen am richtigen Feld, nicht in einem globalen Dialog
- [ ] Beim Absenden mit Fehlern: zum ersten fehlerhaften Feld scrollen und fokussieren
- [ ] Erfolgreiche Eingabe optional bestätigen (Häkchen)
- [ ] Fehler wird angesagt (Screenreader), nicht nur farblich markiert

## 4. Formular

- [ ] Absenden ist genau einmal möglich (Sperre während der Ausführung)
- [ ] Pflichtfelder sind erkennbar
- [ ] Fortschritt bleibt erhalten, wenn die App kurz in den Hintergrund geht
- [ ] Verlassen mit ungespeicherten Änderungen fragt nach
- [ ] Nach Erfolg: klare Rückmeldung und definierter nächster Screen
- [ ] Nach Fehler: Eingaben bleiben erhalten — **niemals** das Formular leeren
- [ ] Abbrechen führt zurück, ohne etwas zu speichern

## 5. Nachricht senden (Chat, Kommentar, Beitrag)

Der Klassiker unter den Fehlerquellen — jeder Punkt einzeln prüfen:

- [ ] Leere Nachricht lässt sich nicht senden (Senden-Schaltfläche deaktiviert)
- [ ] Nur-Leerzeichen zählt als leer
- [ ] Nachricht erscheint sofort optimistisch in der Liste
- [ ] Sichtbarer Status je Nachricht: **wird gesendet · gesendet · fehlgeschlagen**
- [ ] Fehlgeschlagene Nachricht bleibt sichtbar und ist mit einem Tipp erneut sendbar
- [ ] Eingabefeld wird erst nach erfolgreicher Übergabe geleert
- [ ] Doppeltes Senden erzeugt **eine** Nachricht (Idempotenzschlüssel)
- [ ] Reihenfolge bleibt korrekt, auch wenn eine Nachricht langsamer ankommt
- [ ] Liste scrollt beim Senden und beim Empfang zur neuesten Nachricht
- [ ] Sehr lange Nachrichten und Zeilenumbrüche werden korrekt dargestellt
- [ ] Links, Emoji und Sonderzeichen funktionieren
- [ ] Offline: Nachricht wird in die Warteschlange gelegt und später gesendet
- [ ] App im Hintergrund während des Sendens: Nachricht geht nicht verloren
- [ ] Anhänge mit Fortschritt, Abbrechen und Fehlerbehandlung

## 6. Liste

- [ ] Erstladung als Skeleton, nicht als leerer Bildschirm
- [ ] Leerzustand mit Text und nächster Aktion
- [ ] Fehlerzustand mit „Erneut versuchen"
- [ ] Pull-to-Refresh funktioniert und zeigt Rückmeldung
- [ ] Nachladen beim Scrollen mit Ladeanzeige am Ende
- [ ] Ende der Liste erkennbar, kein endloses Nachladen
- [ ] Schnelles Scrollen bleibt flüssig (virtualisierte Liste)
- [ ] Tippen auf ein inzwischen gelöschtes Element: Meldung statt Absturz
- [ ] Löschen mit Rückgängig-Möglichkeit
- [ ] Position bleibt beim Zurückkehren erhalten

## 7. Navigation

- [ ] Jeder Screen hat einen Weg zurück
- [ ] Schnelles doppeltes Antippen öffnet den Zielscreen nur einmal
- [ ] Systemzurück (Android) und Wischgeste (iOS) verhalten sich wie erwartet
- [ ] Zurück aus einem Formular fragt bei ungespeicherten Änderungen nach
- [ ] Tab-Wechsel behält den Zustand je Tab

## 8. Dialoge, Sheets, Auswahl

- [ ] Schließen per Schaltfläche, per Wischen und per Systemzurück
- [ ] Tippen außerhalb schließt (außer bei Bestätigungen)
- [ ] Nur ein Dialog gleichzeitig
- [ ] Fokus springt hinein und beim Schließen zurück
- [ ] Auswahl zeigt den aktuellen Wert vorausgewählt

## 9. Bilder und Uploads

- [ ] Platzhalter während des Ladens, Fehlerbild bei Fehlschlag
- [ ] Upload mit Fortschritt und Abbrechen
- [ ] Größen- und Typprüfung mit verständlicher Meldung
- [ ] Upload überlebt kurzen Wechsel in den Hintergrund oder wird sauber abgebrochen

## 10. Suche

- [ ] Eingabeverzögerung (Debounce) statt Request je Tastendruck
- [ ] Ladeanzeige während der Suche
- [ ] Zustand „keine Treffer" mit Vorschlag
- [ ] Löschen-Symbol setzt die Suche zurück
- [ ] Alte Antwort überschreibt keine neuere (Race Condition)

## Der Klick-Test vor jeder Übergabe

Pflicht für `frontend-dev` vor der Übergabe an QA — auf **beiden** Plattformen:

1. **Jedes** bedienbare Element auf jedem Screen einmal antippen. Passiert nichts → Befund.
2. Jede primäre Schaltfläche zweimal schnell hintereinander antippen → nur eine Wirkung.
3. Jedes Formular leer absenden → verständliche Fehler, kein Absturz.
4. Jedes Formular mit Maximalwerten absenden → kein Layoutbruch.
5. Jeden Screen im Flugmodus öffnen → Fehlerzustand mit Ausweg, kein endloser Spinner.
6. Während einer laufenden Aktion in den Hintergrund und zurück → Zustand konsistent.
7. Jeden Screen mit Systemschrift 200 % öffnen → alles lesbar und erreichbar.
8. Jeden Screen im Dunkelmodus öffnen → nichts unsichtbar.

Ergebnis als kurze Notiz in `agentur/04-implementation/klick-test.md` festhalten.
Ohne diese Notiz nimmt der `qa-engineer` die Übergabe nicht an.
