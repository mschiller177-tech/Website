# Best Practices — Skalierbarkeit

Verbindlich für alle Agenten. Leitfrage bei jeder Entscheidung:
**„Was passiert bei 10× so vielen Nutzern, Daten und Anfragen?"**

## Grundsätze

1. **Zustandslose Dienste.** Kein Sitzungszustand im Prozessspeicher — sonst ist keine
   zweite Instanz möglich.
2. **Unbegrenztes wird begrenzt.** Jede Liste, jede Abfrage, jeder Upload und jede
   Warteschlange braucht eine Obergrenze.
3. **Asynchron, wo der Nutzer nicht wartet.** Alles über ~500 ms gehört in eine Warteschlange.
4. **Idempotenz.** Jede Operation muss eine Wiederholung ohne Schaden überstehen —
   mobile Netze brechen ab und Clients wiederholen.
5. **Wachstum kostet Geld.** Skalierung wird gegen Kosten geplant, nicht dagegen entdeckt.

## 1. Datenmodell und Datenbank

- Indizes gezielt auf Filter-, Join- und Sortierspalten; zusammengesetzte Indizes in der
  Reihenfolge der Selektivität. Jeder Index kostet bei Schreibvorgängen — nicht blind anlegen.
- **Cursor-Paginierung statt `OFFSET`.** `OFFSET 10000` wird linear langsamer.
- Zeitreihen- und Ereignistabellen partitionieren (z. B. monatlich) und Altdaten archivieren.
- Aufwändige Aggregate materialisieren statt bei jedem Aufruf zu berechnen.
- Migrationen ohne Ausfall planen: Spalte hinzufügen → doppelt schreiben → zurückfüllen →
  umschalten → alte Spalte entfernen. Nie eine belegte Spalte direkt löschen oder umbenennen.
- Wachstumsschätzung je Tabelle dokumentieren: Zeilen pro Nutzer und Monat.

## 2. Caching-Ebenen

| Ebene | Zweck | Gültigkeit |
|-------|-------|------------|
| Client (TanStack Query) | Wiederholte Ansichten | Sekunden bis Minuten |
| CDN / Edge | Statische und öffentliche Inhalte | Minuten bis Tage |
| Anwendung (Redis) | Teure Berechnungen, Sitzungsdaten | Minuten |
| Datenbank | Materialisierte Sichten | Nach Aktualisierung |

Für jeden Cache gilt: Wer invalidiert ihn, und was passiert bei einem Fehlgriff?
Ein Cache ohne Invalidierungsstrategie erzeugt Datenfehler statt Geschwindigkeit.

## 3. Lastspitzen abfangen

- **Ratenbegrenzung** je Nutzer und je IP auf allen öffentlichen Endpunkten.
- **Backpressure:** bei Überlast mit `429` und `Retry-After` antworten, statt zusammenzubrechen.
- **Circuit Breaker** vor Drittanbietern — ein hängender Fremddienst darf nicht den
  eigenen Dienst blockieren.
- **Timeouts überall.** Ein Aufruf ohne Timeout ist ein Aufruf mit unendlichem Timeout.
- Client-seitig: exponentieller Backoff **mit Jitter**, damit nicht alle Geräte
  gleichzeitig erneut anfragen (Thundering Herd nach einer Störung).

## 4. Asynchrone Verarbeitung

- Warteschlange für Push-Versand, E-Mails, Bildverarbeitung, Exporte, Webhooks.
- Jeder Job: idempotent, mit begrenzten Wiederholungen und Dead-Letter-Queue.
- Fortschritt für den Nutzer sichtbar machen, statt ihn warten zu lassen.
- Geplante Aufgaben gestaffelt starten, nicht alle zur vollen Stunde.

## 5. Dateien und Medien

- Uploads direkt zum Objektspeicher über kurzlebige signierte URLs — nicht durch den
  eigenen Server leiten.
- Bilder serverseitig in mehreren Größen ableiten, Auslieferung über CDN.
- Größenbegrenzung und Typprüfung erzwingen, Speicherkosten je Nutzer abschätzen.

## 6. Realtime und Push

- Fanout begrenzen: Wie viele Empfänger löst ein Ereignis aus? Bei großen Gruppen
  aggregieren statt einzeln zu senden.
- Realtime-Verbindungen sind teuer — nur dort einsetzen, wo Aktualität wirklich zählt,
  sonst Pull mit sinnvollem Intervall.
- Push-Versand über Batch-APIs, mit Fehlerbehandlung für ungültige Tokens.

## 7. Beobachtbarkeit

Ohne Messung keine Skalierung. Mindestens:

- **Metriken:** Anfragerate, Fehlerrate, Latenz p50/p95/p99, Sättigung (CPU, Verbindungen, Queue-Tiefe)
- **Tracing** über Dienstgrenzen hinweg, mit Korrelations-ID vom Client bis zur Datenbank
- **Strukturierte Logs** ohne personenbezogene Daten
- **SLOs** je Kernfunktion, mit Alarm bei Verletzung
- Alarme auf Symptome (Nutzer betroffen), nicht auf jede Kennzahlschwankung

## 8. Code- und Teamskalierbarkeit

- Klare Modulgrenzen nach Fachlichkeit, nicht nach Dateityp; Importregeln durchsetzen.
- Feature-Flags für Auslieferung ohne Big-Bang-Release.
- Verträge zwischen App und Backend versioniert; ältere App-Versionen bleiben lauffähig,
  denn Nutzer aktualisieren nicht sofort. Breaking Changes brauchen eine Übergangsphase.

## Der 10×-Test

Vor jeder Architekturentscheidung durchspielen und im ADR festhalten:

| Frage | Antwort |
|-------|---------|
| 10× Nutzer — was bricht zuerst? | |
| 10× Daten je Nutzer — welche Abfrage wird langsam? | |
| 10× Schreiblast — hält die Datenbank? | |
| Drittanbieter fällt aus — was passiert? | |
| Kosten bei 10× — tragbar? | |

## Kurz-Checkliste

- [ ] Keine unbegrenzten Abfragen, Cursor-Paginierung überall
- [ ] Indizes belegt durch Abfragepläne
- [ ] Ratenbegrenzung und Timeouts auf allen Endpunkten
- [ ] Schreiboperationen idempotent
- [ ] Lange Arbeit asynchron mit Wiederholung und DLQ
- [ ] Caching-Ebenen mit Invalidierungsstrategie
- [ ] Uploads direkt zum Objektspeicher, Auslieferung über CDN
- [ ] Metriken, Tracing und SLOs aktiv
- [ ] Migrationen ohne Ausfall geplant
- [ ] 10×-Test im ADR beantwortet
