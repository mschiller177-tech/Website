# Best Practices — Performance

Verbindlich für alle Agenten. Grundsatz: **Messen statt raten.** Eine Optimierung ohne
Messung vorher und nachher ist eine Vermutung.

## Performance-Budgets (Standard, sofern nichts anderes vereinbart)

| Kennzahl | Budget |
|----------|--------|
| Kaltstart bis interaktiv | < 2,0 s (Mittelklassegerät) |
| Warmstart | < 1,0 s |
| Bildschirmwechsel | < 300 ms |
| Scroll-Bildrate | 60 fps, keine Einbrüche unter 50 |
| Reaktion auf Tippen | sichtbares Feedback < 100 ms |
| API-Antwortzeit p95 | < 300 ms |
| JS-Bundle (initial) | < 3 MB |
| App-Download-Größe | < 60 MB |
| Speicherverbrauch im Leerlauf | < 200 MB |

Budgets gehören ins PRD, werden in der CI geprüft und bei Überschreitung wie ein Bug behandelt.

## 1. App-Start

- Beim Start nur laden, was der erste Screen braucht. Alles andere verzögert nachladen.
- Screens und schwere Bibliotheken über Lazy Imports / `React.lazy` einbinden.
- Hermes-Engine aktiviert; Inline Requires eingeschaltet.
- Keine blockierenden Netzwerkaufrufe vor dem ersten Frame — zuerst Skeleton zeigen,
  dann Daten nachladen.
- Aufwändige Migrationen und Initialisierungen nach dem ersten Frame ausführen.

## 2. Rendering

- **Listen immer virtualisiert** (`FlatList`, `FlashList`) mit stabilen Keys,
  `getItemLayout` wo möglich, konstanter Item-Höhe wo sinnvoll. Nie `map()` über
  hunderte Einträge in einem ScrollView.
- Re-Renders begrenzen: State so tief wie möglich ansiedeln, `memo`, `useMemo`,
  `useCallback` gezielt einsetzen — nicht flächendeckend, das kostet selbst.
- Keine Objekt- oder Funktionsliterale in Props von Listenelementen.
- Animationen über Reanimated bzw. `useNativeDriver: true` — auf dem UI-Thread,
  nicht über die Bridge.
- Teure Berechnungen aus dem Renderpfad heraus; lange Aufgaben aufteilen,
  damit der Frame nicht blockiert.
- Bilder in Zielauflösung ausliefern, nicht per CSS skalieren; Caching aktiv
  (`expo-image`), Platzhalter und `contentFit` setzen.
- Schatten und Blur sind teuer, besonders auf Android — sparsam einsetzen.

## 3. Netzwerk

- Caching-Ebene über TanStack Query: `staleTime` bewusst wählen, damit nicht bei jedem
  Fokus neu geladen wird.
- Paginierung mit Cursor statt Offset; nie unbegrenzte Listen abrufen.
- Nur benötigte Felder anfordern; Antwortgröße im Blick behalten.
- Kompression (gzip/brotli) serverseitig aktiv.
- Parallelisieren, wo möglich; Wasserfälle aus abhängigen Requests auflösen.
- Wiederholungen mit exponentiellem Backoff und Obergrenze — nicht in Endlosschleife.
- Vorausschauendes Laden (Prefetch) für den wahrscheinlich nächsten Screen.
- Optimistische Updates bei schnellen Aktionen, mit sauberem Rollback im Fehlerfall.

## 4. Speicher und Akku

- Listener, Timer, Intervalle und Subscriptions in der Aufräumfunktion beenden —
  die häufigste Leckquelle.
- Große Objekte nicht dauerhaft im State halten; Bildcache begrenzen.
- Standortabfragen mit passender Genauigkeit und Intervall; Hintergrundarbeit bündeln.
- Polling vermeiden — Push oder Realtime bevorzugen. Polling entlädt Akkus.
- Bei App im Hintergrund: Timer und Datenabrufe pausieren.

## 5. Backend

- Indizes für jede Spalte in `WHERE`, `JOIN` und `ORDER BY`; Abfragepläne prüfen (`EXPLAIN ANALYZE`).
- N+1-Abfragen auflösen (Join oder Batch-Laden).
- `SELECT *` vermeiden.
- Verbindungs-Pooling nutzen; bei Serverless auf Pool-Grenzen achten.
- Antwort-Caching für gleichbleibende Daten; Cache-Invalidierung bewusst festlegen.
- Langlaufende Arbeit asynchron in eine Warteschlange, nicht in den Request-Pfad.

## 6. Messen

| Bereich | Werkzeug |
|---------|----------|
| Startzeit, Bildrate | React DevTools Profiler, Perf Monitor, Systrace |
| Reale Nutzung | Sentry Performance / Firebase Performance |
| Bundle-Größe | `npx expo-atlas`, Source-Map-Explorer |
| Backend-Last | k6 oder Artillery |
| Datenbank | `EXPLAIN ANALYZE`, `pg_stat_statements` |

Vorgehen: messen → Engpass benennen → **eine** Änderung → erneut messen → Ergebnis
dokumentieren. Auf einem Mittelklassegerät testen, nicht auf dem schnellsten Testgerät.

## Kurz-Checkliste

- [ ] Budgets im PRD definiert und geprüft
- [ ] Kaltstart auf Mittelklassegerät unter Budget
- [ ] Alle langen Listen virtualisiert
- [ ] Animationen auf dem nativen Thread
- [ ] Bilder in Zielauflösung mit Cache
- [ ] Kein Datenabruf im Wasserfall, Paginierung überall
- [ ] Keine Leaks: Timer und Listener werden aufgeräumt
- [ ] Datenbankabfragen indiziert, keine N+1
- [ ] Messwerte vorher/nachher dokumentiert
