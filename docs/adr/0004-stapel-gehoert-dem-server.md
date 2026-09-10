# ADR 0004 — `john-stapel.json` gehört dem Cockpit-Server allein

**Datum:** 10.09.2026 · **Status:** angenommen

## Der Fund

`john-server.ps1` liest den Stapel **einmal** und hält ihn danach in `$script:Stapel`
(`Read-Stapel`: „ist er schon geladen, gib ihn zurück"). `Save-Stapel` schreibt die Datei
**vollständig neu** aus diesem Speicher. Wer die Datei von außen ändert, während der Server läuft,
verliert seine Änderung beim nächsten Speichern — ohne Fehler, ohne Meldung.

Das ist beim Bauen des Workers aufgefallen, bevor etwas kaputtging.

## Entscheidung

Kein Prozess außer dem Cockpit-Server schreibt `john-stapel.json`. Lesen ist erlaubt (der Worker
nimmt den Stand als Kontext mit). Johns Erkenntnisse aus dem Takt gehen zwei andere Wege:

1. **Rezeption** (`w=stapel`) — gilt geräteübergreifend, das ist der eigentliche Weg.
2. **`john\coaching\takt.md`**, append-only — John liest seine Notizen beim nächsten Denken selbst
   mit, so kommt die Erkenntnis auch ohne Rezeption an.

## Folgen

- Solange Compass-Karte und Rezeption zwei getrennte Stapel führen, kann es zwei Stände geben.
  Zusammengeführt wird das, wenn die Karte im Compass ihren Stand aus der Rezeption zieht statt aus
  dem Server — das ist der nächste Schritt nach dieser Nacht (siehe `docs/stand.md`).
- Wer je „nur schnell" in die Datei schreiben will: nicht tun. Der Server-Endpunkt
  `POST /api/john/stapel/stand` ist der richtige Weg von außen.
