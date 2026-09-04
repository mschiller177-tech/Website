# App-Grundgerüst — was jede App braucht

Diese Liste ist die Basis **jeder** App, unabhängig vom Feature-Umfang. Sie wird in Phase 1
in Stories überführt, in Phase 2 gestaltet, in Phase 4 gebaut und in Phase 5 geprüft.
Was hier fehlt, fällt später als Bug, Store-Ablehnung oder Support-Aufwand auf.

Kurzregel: **Kein Screen ohne Ladezustand, Leerzustand und Fehlerzustand.
Keine Aktion ohne sichtbare Rückmeldung. Kein Fehler ohne Ausweg.**

## 1. Technisches Fundament

- [ ] Navigation mit definiertem Zurück-Verhalten auf beiden Plattformen
- [ ] Zentrale Zustandsverwaltung (Server-Zustand getrennt vom UI-Zustand)
- [ ] **Globale Fehlerbehandlung** (Error Boundary): ein unerwarteter Fehler zeigt einen
      Auffang-Screen mit „Erneut versuchen", statt die App zu schließen
- [ ] Zentraler API-Client: Basis-URL, Auth-Header, Timeout, Wiederholung mit Backoff,
      einheitliche Fehlerübersetzung
- [ ] Konfiguration je Umgebung (dev/staging/prod) ohne Codeänderung
- [ ] Feature-Flags für riskante Funktionen
- [ ] Versions- und Build-Nummer in der App sichtbar (Support braucht sie)
- [ ] Crash-Reporting und strukturiertes Logging aktiv, ohne personenbezogene Daten

## 2. Erster Start und Onboarding

- [ ] Splash-Screen ohne Hänger, mit Zeitbegrenzung
- [ ] Onboarding erklärt den Nutzen, ist überspringbar und wiederholbar
- [ ] Berechtigungen werden **vorher erklärt**, dann erst angefragt
- [ ] Nutzung ohne Konto so weit wie möglich (Login-Wand nur, wo nötig)
- [ ] Erster Leerzustand führt zur ersten sinnvollen Aktion

## 3. Konto und Sitzung

- [ ] Registrierung, Login, Logout
- [ ] Passwort vergessen inkl. Rücksetzung
- [ ] E-Mail-Verifikation, falls fachlich nötig
- [ ] Social/Apple Login — **Apple Sign-In ist Pflicht**, wenn ein anderer Social-Login existiert
- [ ] Sitzungsablauf: automatische Erneuerung, sonst freundlicher Hinweis statt 401-Fehlerdialog
- [ ] Profil ansehen und bearbeiten
- [ ] **Account-Löschung in der App** (Store-Pflicht bei Login) mit Bestätigung und Hinweis auf Folgen
- [ ] Abmelden auf allen Geräten

## 4. Rückmeldung an den Nutzer

- [ ] Ladezustände: Skeleton für Inhalte, Spinner im Button für Aktionen
- [ ] Erfolgsmeldung nach jeder abgeschlossenen Aktion (Toast/Snackbar)
- [ ] Fehlermeldung in verständlicher Sprache, mit Handlungsoption
- [ ] Bestätigungsdialog vor unwiderruflichen Aktionen
- [ ] Rückgängig-Option, wo möglich (besser als ein weiterer Dialog)
- [ ] Fortschrittsanzeige bei allem, was länger als 2 Sekunden dauert
- [ ] Haptisches Feedback bei wichtigen Aktionen

## 5. Fehlerbehandlung (die häufigste Lücke)

Für jede dieser Situationen gibt es einen definierten, gestalteten Zustand:

| Situation | Verhalten |
|-----------|-----------|
| Kein Netz | Hinweisleiste, gecachte Daten anzeigen, „Erneut versuchen" |
| Zeitüberschreitung | Meldung + Wiederholen, kein endloser Spinner |
| Serverfehler (5xx) | „Da ist bei uns etwas schiefgelaufen" + Wiederholen |
| Nicht gefunden (404) | Erklärung + Weg zurück |
| Keine Berechtigung (403) | Erklärung, keine leere Seite |
| Sitzung abgelaufen (401) | Stille Erneuerung, sonst Login mit Rückkehr zum Ausgangspunkt |
| Ungültige Eingabe (400) | Fehler am betroffenen Feld, nicht als globaler Dialog |
| Ratenbegrenzung (429) | „Bitte kurz warten", mit Wartezeit |
| Unerwarteter Absturz | Error Boundary + Crash-Report |
| App-Version zu alt | Hinweis mit Link zum Store (Force-Update-Mechanismus) |

- [ ] Keine technischen Meldungen für Nutzer („NetworkError", Stacktrace, JSON)
- [ ] Jede Fehlermeldung sagt: was passiert ist **und** was der Nutzer tun kann
- [ ] Support-Kontakt aus dem Fehlerzustand erreichbar

## 6. Offline und Netz

- [ ] Netzstatus wird erkannt und angezeigt
- [ ] Zuletzt geladene Daten bleiben lesbar
- [ ] Schreibaktionen offline: entweder blockiert mit Hinweis oder in Warteschlange
      mit späterer Synchronisierung
- [ ] Automatische Wiederaufnahme, wenn das Netz zurückkehrt
- [ ] Keine doppelte Ausführung nach Wiederverbindung (Idempotenz)

## 7. Navigation und Deep Links

- [ ] Zurück-Geste (iOS) und Systemzurück (Android) funktionieren überall
- [ ] Deep Links auf Kern-Screens, auch aus Push-Nachrichten
- [ ] Deep Link im ausgeloggten Zustand: erst Login, dann Ziel-Screen
- [ ] Zustand bleibt beim Wechsel zwischen Tabs erhalten
- [ ] Nach App-Neustart landet der Nutzer an sinnvoller Stelle

## 8. Berechtigungen

- [ ] Jede Berechtigung wird vor der Anfrage im Kontext erklärt
- [ ] Verweigerte Berechtigung: Funktion bleibt erklärt, Weg in die Systemeinstellungen
- [ ] Dauerhaft verweigert („nicht mehr fragen") wird abgefangen
- [ ] Die App funktioniert ohne optionale Berechtigungen weiter

## 9. Benachrichtigungen

- [ ] Opt-in erst, wenn der Nutzen erkennbar ist
- [ ] Einstellungen je Benachrichtigungsart in der App
- [ ] Tippen auf eine Push-Nachricht führt zum passenden Screen
- [ ] Verhalten bei App im Vordergrund definiert
- [ ] Ungültige Push-Tokens werden serverseitig aufgeräumt

## 10. Einstellungen (Mindestumfang)

Konto · Benachrichtigungen · Sprache · Erscheinungsbild (Hell/Dunkel/System) ·
Datenschutz und Tracking-Einwilligung · Datenschutzerklärung · AGB · Impressum ·
Open-Source-Lizenzen · Support kontaktieren · App bewerten · Version und Build ·
Abmelden · **Konto löschen**

## 11. Inhalte und Texte

- [ ] Alle Texte zentral verwaltet (i18n-fähig), keine Zeichenketten im Code verstreut
- [ ] Deutsche Texte sind länger als englische — Layout muss das aushalten
- [ ] Datum, Zeit, Zahlen und Währung nach Systemregion formatiert
- [ ] Einheitliche Anrede und Tonalität
- [ ] Leerzustände mit Text **und** nächster Aktion, nicht nur „Keine Daten"

## 12. Listen- und Detail-Muster

- [ ] Erstladung als Skeleton
- [ ] Pull-to-Refresh
- [ ] Nachladen beim Scrollen (Paginierung), Ladeanzeige am Listenende
- [ ] „Ende der Liste" ist erkennbar
- [ ] Leer-, Fehler- und Offline-Zustand der Liste
- [ ] Tippen auf ein gelöschtes Element führt zu einer Meldung, nicht zum Absturz
- [ ] Suche mit Verzögerung (Debounce), Abbrechen und Zustand „keine Treffer"

## 13. Update und Wartung

- [ ] Force-Update-Mechanismus (Mindestversion vom Server)
- [ ] Wartungsmodus mit Hinweis-Screen
- [ ] OTA-Update-Kanal für JS-Änderungen
- [ ] Datenmigration bei App-Update wird getestet (alte Version → neue Version)
- [ ] Alte App-Versionen bleiben gegen das neue Backend lauffähig

## 14. Messung

- [ ] Kern-Events definiert (Installation, Registrierung, Aktivierung, Kernaktion, Fehler)
- [ ] Crash-freie Sitzungen als Kennzahl
- [ ] Performance-Messung realer Nutzung
- [ ] Alles erst nach Einwilligung, ohne personenbezogene Daten

## 15. Barrierefreiheit und Erscheinungsbild

- [ ] Hell- und Dunkelmodus vollständig
- [ ] Schriftskalierung bis 200 % ohne Layoutbruch
- [ ] Screenreader-Labels auf allen bedienbaren Elementen
- [ ] Kontraste eingehalten (Text ≥ 4.5:1)

## 16. Sicherheit im Grundgerüst

- [ ] Tokens im Keychain/Keystore
- [ ] Cache und lokale Daten beim Logout gelöscht
- [ ] Sitzungszeitüberschreitung bei sensiblen Apps
- [ ] Screenshot-Schutz und verdeckter App-Switcher bei sensiblen Inhalten
- [ ] Keine Debugmenüs im Release

## Mindest-Screens jeder App

Splash · Onboarding · Login · Registrierung · Passwort vergessen · Hauptbereich ·
Detailansicht · Erstellen/Bearbeiten · Profil · Einstellungen · Über/Rechtliches ·
Fehler-Auffangseite · Kein-Netz-Zustand · Wartung/Update erforderlich

## Gate

Der `requirements-engineer` führt diese Liste im PRD als „Grundgerüst" mit
Ja/Nein/Begründung. Der `functional-tester` prüft sie in Phase 5 Punkt für Punkt ab.
Ein „nicht nötig" ist erlaubt — aber nur mit Begründung, nie durch Vergessen.
