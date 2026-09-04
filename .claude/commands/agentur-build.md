---
description: Startet Architektur und Implementierung (nur nach Design-Freigabe)
argument-hint: "[feature oder story-id]"
---

Starte die Umsetzungsphasen der Software-Agentur.

Fokus (optional): $ARGUMENTS

Vorgehen:

1. **Gate prüfen:** Lies `agentur/02-design/DESIGN-FREIGABE.md`.
   Steht dort nicht `Status: FREIGEGEBEN`, brich ab, sage mir warum und schlage
   `/agentur-design` vor. Kein UI-Code ohne Freigabe.
2. Ist `agentur/03-architecture/` noch leer, zuerst `solution-architect` beauftragen:
   Tech-Stack (ADR), Datenmodell mit Zugriffsregeln, API-Vertrag, Projektstruktur.
3. Danach parallel über `Task` beauftragen:
   - `backend-dev` — Schema, Migrationen, RLS, Auth, Endpunkte nach `api-vertrag.md`
   - `frontend-dev` — Tokens als Code, Basiskomponenten, Navigation, Screens mit allen
     Zuständen, Anbindung nach `api-vertrag.md`
4. Nach der Umsetzung prüfen: `npx tsc --noEmit`, `npm run lint`, `npm test`.
5. `agentur/PROJEKT.md` aktualisieren und mir in maximal 10 Zeilen berichten.

Bei Abweichungen vom API-Vertrag: nicht raten, sondern an `solution-architect` zurückgeben.
