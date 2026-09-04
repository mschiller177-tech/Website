# Best Practices — Sicherheit

Verbindlich für alle Agenten der Agentur. Orientiert an OWASP MASVS und OWASP Mobile Top 10.

## Grundsätze

1. **Dem Client nie vertrauen.** Alles, was auf dem Gerät läuft, ist einsehbar und
   manipulierbar. Jede Regel, die zählt, wird auf dem Server durchgesetzt.
2. **Least Privilege.** Jeder Nutzer, Dienst und Schlüssel bekommt genau die Rechte,
   die er braucht — nicht mehr, und befristet.
3. **Secure by Default.** Der sichere Zustand ist der Standardzustand. Öffnen ist eine
   bewusste, dokumentierte Entscheidung.
4. **Defense in Depth.** Keine einzelne Maßnahme trägt allein.
5. **Fail closed.** Fällt eine Prüfung aus, wird der Zugriff verweigert, nicht gewährt.

## 1. Secrets und Konfiguration

- Keine Secrets im Repository, im App-Bundle, in `app.json`, in Screenshots oder in Logs.
- Nur öffentliche Schlüssel (z. B. Supabase Anon Key) dürfen in die App — und nur, wenn
  der Zugriffsschutz serverseitig über Policies erzwungen wird.
- Service-Role-Keys, Admin-Tokens und Drittanbieter-Secrets ausschließlich serverseitig.
- Secrets über Umgebungsvariablen bzw. GitHub/EAS Secrets, rotierbar und mit Ablaufdatum.
- Vor jedem Release prüfen:
  ```bash
  grep -rEn "(api[_-]?key|secret|password|token|bearer|private[_-]?key)\s*[:=]" \
    --include="*.ts" --include="*.tsx" --include="*.json" --include="*.env*" . \
    | grep -v node_modules
  ```
- Versehentlich committete Secrets gelten als kompromittiert: **rotieren**, nicht nur löschen.

## 2. Authentifizierung und Sitzung

- Access-Token kurzlebig (15–60 min), Refresh-Token rotierend und serverseitig widerrufbar.
- Logout invalidiert die Sitzung **auf dem Server**, nicht nur lokal.
- Passwörter: Mindestlänge statt Zeichenklassen-Zwang, Abgleich gegen bekannte Leaks,
  serverseitiges Hashing mit Argon2id oder bcrypt.
- Ratenbegrenzung und Sperrlogik bei Login, Registrierung, Passwort-Reset und OTP.
- Fehlermeldungen verraten nicht, ob eine Kennung existiert.
- Biometrie ist Komfort, kein Ersatz für serverseitige Autorisierung.
- MFA anbieten, sobald sensible Daten verarbeitet werden.

## 3. Autorisierung

- **Pro Ressource prüfen**, nicht nur „ist eingeloggt": Gehört dieser Datensatz dem Aufrufer?
  Fehlt diese Prüfung, entsteht IDOR — die häufigste schwere Lücke in Mobile-Backends.
- Bei Supabase: RLS auf **jeder** Tabelle aktiv, Policies je Operation
  (select/insert/update/delete). Eine Tabelle ohne Policy ist eine offene Tabelle.
- Rollen und Rechte serverseitig ableiten, nie aus einem Client-Feld übernehmen.
- Autorisierung mit zwei Testnutzern verifizieren: Sieht A die Daten von B? Antwort: nein.

## 4. Datenhaltung auf dem Gerät

- Tokens und Zugangsdaten in **Keychain (iOS) / Keystore (Android)** — nicht in
  AsyncStorage, UserDefaults, SharedPreferences oder SQLite im Klartext.
- Personenbezogene Daten lokal verschlüsseln; Cache beim Logout löschen.
- Keine sensiblen Daten in Logs, Crash-Reports, Analytics-Events oder Backups.
- Bei sensiblen Screens: Screenshot-Schutz und Inhalt im App-Switcher verdecken.
- Zwischenablage nach sensiblem Kopiervorgang zeitlich begrenzen.

## 5. Transport

- Ausschließlich TLS 1.2+. Keine Ausnahmen in `NSAppTransportSecurity` oder
  `network_security_config.xml`, auch nicht „nur für Entwicklung".
- Zertifikatsprüfung niemals deaktivieren. Certificate Pinning bei hohem Schutzbedarf,
  mit Rotationsplan.
- Sensible Daten nie in URL-Parametern (landen in Logs und Verläufen).

## 6. Eingaben und Backend

- Jede Eingabe serverseitig validieren (Schema-Validierung, Allowlist statt Blocklist),
  auch wenn die App bereits prüft.
- Parametrisierte Queries, niemals String-Konkatenation in SQL.
- Datei-Uploads: Typ, Größe und Inhalt prüfen, außerhalb des Web-Roots speichern,
  Dateinamen neu vergeben.
- Ausgehende Requests mit Nutzereingaben (SSRF-Gefahr): Ziel-Allowlist.
- Fehlerantworten ohne Stacktraces, SQL-Fragmente oder interne Pfade.
- Idempotenzschlüssel bei Schreiboperationen, damit Wiederholungen nicht doppelt buchen.

## 7. Plattform-Härtung

- Deep Links und Custom Schemes validieren — sie sind eine Angriffsfläche von außen.
- WebViews: JavaScript-Bridges minimieren, nur vertrauenswürdige Ziele laden,
  `allowFileAccess` aus.
- Exportierte Android-Komponenten (Activities, Receiver, Provider) auf das Nötige begrenzen.
- Debug-Funktionen, Testkonten und Entwicklermenüs sind in Release-Builds nicht enthalten.
- Code-Obfuskation und Root-/Jailbreak-Erkennung sind Zusatzhürden, keine Sicherheitsgrenze.

## 8. Abhängigkeiten

- `npm audit --production` in der CI; kritische Funde blockieren den Release.
- Versionen gepinnt, Lockfile eingecheckt, Updates regelmäßig und bewusst.
- Neue Abhängigkeit nur mit Begründung: Wartungsstand, Verbreitung, Berechtigungen.

## 9. Datenschutz (DSGVO)

- Datenminimierung: nur erheben, was eine Anforderung belegt.
- Rechtsgrundlage und Zweck je Datenkategorie dokumentiert.
- Betroffenenrechte umgesetzt: Auskunft, Berichtigung, **Löschung in der App**.
- Auftragsverarbeiter gelistet, Drittlandtransfers geprüft.
- Tracking erst nach Einwilligung (ATT auf iOS, Consent im EWR).
- Apple Privacy Manifest und Play Data Safety müssen dem tatsächlichen Verhalten entsprechen —
  Abweichungen führen zur Ablehnung im Review.

## Kurz-Checkliste vor jedem Release

- [ ] Keine Secrets im Bundle oder Repository
- [ ] Tokens im Keychain/Keystore, Logout serverseitig wirksam
- [ ] Autorisierung pro Ressource mit zwei Nutzern getestet
- [ ] RLS/Policies auf allen Tabellen
- [ ] Nur TLS, keine Ausnahmen im Netzwerk-Config
- [ ] Serverseitige Validierung aller Eingaben
- [ ] Ratenbegrenzung auf Auth-Endpunkten
- [ ] `npm audit` ohne kritische Funde
- [ ] Keine personenbezogenen Daten in Logs und Crash-Reports
- [ ] Account-Löschung in der App vorhanden
- [ ] Datenschutzangaben stimmen mit dem Code überein
