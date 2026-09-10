# ADR 0001 — Drei Schichten statt eines Prozesses

**Datum:** 10.09.2026 · **Status:** angenommen, umgesetzt

## Lage

John war derselbe Prozess wie der Cockpit-Server: eine serielle `HttpListener`-Schleife, die den
Compass ausliefert und für John denkt. Ein Denkvorgang dauert 60–90 s und blockiert alles andere.
Gemessen am 10.09.2026, 23:18: Server lief, Port antwortete, und der Compass zeigte an vier Karten
„John-Server nicht erreichbar". Dazu: Johns Stand lag auf einem Rechner, also gab es am Handy
keinen John, und die geplanten Aufgaben liefen nur bei angemeldetem Benutzer.

## Entscheidung

Drei Schichten mit klarer Zuständigkeit:

1. **Rezeption** im WWW (PHP auf dem KAS) — hält Johns Stand, wach rund um die Uhr, denkt nie.
2. **Gerät** (`john-worker.ps1`) — denkt, hat einen eigenen Takt, und hat eine Tür, die in
   Millisekunden antwortet, weil sie neben dem großen Server lebt und nicht in ihm.
3. **Klienten** fragen in dieser Reihenfolge: Gerät → Cockpit-Server → Rezeption.

## Begründung

Das eigentliche Problem war nicht Verfügbarkeit, sondern **Auskunftsfähigkeit**: niemand konnte
sagen, ob John denkt, hängt oder aus ist. Ein weiterer Watchdog hätte daran nichts geändert — er
hätte nur schneller etwas beendet, das vielleicht gerade arbeitete. Eine zweite, absichtlich dumme
Stelle daneben kann die Frage beantworten, ohne selbst blockierbar zu sein.

## Folgen

- Ein Prozess mehr je Gerät, eine PHP-Datei mehr im Netz.
- Der Cockpit-Server bleibt, wie er ist — **kein Umbau an 331 kB Code**, der von vier Sessions
  gleichzeitig bearbeitet wird. Er ist nur nicht mehr „John".
- Der Claude-Aufruf steht jetzt an zwei Stellen (siehe ADR 0003).
- Neue langsame Arbeit gehört ab sofort in einen Auftrag, nie in eine bedienende Schleife.

## Verworfene Möglichkeiten

- **Nur den Watchdog schärfen.** Löst „hängt", nicht „belegt", und gar nichts für andere Geräte.
- **Den Cockpit-Server mehrläufig machen** (Runspaces je Anfrage). Richtiger Weg auf lange Sicht,
  aber ein Eingriff mitten in den Prozess, an dem gerade alles hängt — und PowerShell-Runspaces
  teilen keinen Zustand, halber Umbau wäre schlimmer als keiner.
- **Johns Denken ganz in die Cloud.** Scheitert am Zweck: John braucht Benes Mails, Jira, Kalender
  und Dateien. Die liegen auf dem Gerät, und dort sollen sie bleiben.
