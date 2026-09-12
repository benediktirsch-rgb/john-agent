# John — Architektur (Stand 10.09.2026)

> Benes Auftrag, wörtlich: „sobald John weg ist, geb mir ein Layover-Fenster, das ihn direkt startet,
> und lass ihn auf dem Server leben — er soll ein echter Agent sein und nicht ständig schlafen.
> Stell das bitte sicher, egal was es kostet. John lebt später auf allen Geräten."

## 1. Warum John verschwindet — gemessen, nicht vermutet

Am 10.09.2026 um 23:18 lief der Server (PID 36464, Port 8787 antwortet), während Benes Compass vier
Karten mit „John-Server nicht erreichbar" zeigte. Das ist der Kern des Problems: **John war nicht tot,
er war belegt.** Vier Ursachen, in der Reihenfolge ihrer Häufigkeit:

1. **Ein Prozess für alles.** `john-server.ps1` (331 KB) liefert den Compass aus *und* denkt für John,
   in **einer** seriellen `GetContext()`-Schleife. Ein Stapel-Aufruf an Claude dauert 60–90 s; solange
   beantwortet der Server **keine** einzige andere Anfrage. Der Browser bricht mit „Failed to fetch" ab
   und schreibt an 18 Stellen in `dashboard.html` denselben Satz — derselbe Satz für „belegt", „hängt"
   und „tot". Bene kann drei völlig verschiedene Lagen nicht unterscheiden.
2. **Wiederanlauf dauert Minuten.** Die Aufgabe „John Server" versuchte es alle **5 min**; die „John
   Server Wacht" braucht Fehlschläge à 2 min, bevor sie einen Hänger abschießt, danach wieder bis zu
   5 min. Schlechtester Fall: **rund 11 Minuten Stille** — und niemand sagt Bene, dass gewartet wird.
3. **Nur solange Bene angemeldet ist.** Beide Aufgaben laufen `LogonType=Interactive` (aus gutem Grund:
   User-Umgebungsvariablen, Claude-Abo-Anmeldung, Drive-Spiegel). Schläft der Rechner oder ist Bene
   abgemeldet, ist John **vollständig** weg — es gibt keine zweite Stelle, die etwas von ihm weiß.
4. **Johns Gedächtnis liegt auf einem Rechner.** `john-stapel.json` liegt neben dem Server. Am Handy,
   im Zug, auf einem zweiten Gerät gibt es keinen John, sondern eine leere Karte.

Was daraus folgt: Ein *Watchdog mehr* löst nichts. Solange Denken und Ausliefern derselbe Prozess sind
und Johns Gedächtnis an diesem Prozess klebt, bleibt John so verfügbar wie ein Laptopdeckel.

## 2. Die drei Schichten

```
      +---------------------------- Klienten ----------------------------+
      |  Flow Compass (lokal · bene.vishnuartists.com · Handy)           |
      |  Vishnu-Backend „Projekt John" (alle eingeloggten Seiten)        |
      |  Lobby-Overlay: sichtbar genau dann, wenn John gerade nicht kann |
      +-----------+---------------------------------+--------------------+
                  | 1. erst das Gerät (schnell)     | 2. dann die Rezeption (immer da)
                  v                                 v
      +--------------------------+      +-------------------------------------+
      |  Gerät · „Johns Hände"   |<---->|  Rezeption · „Johns Zimmer"         |
      |  john-worker.ps1 :8788   | Puls |  hotel-vaikuntha.de/john/           |
      |  - Tür: antwortet in ms  | Auf- |  PHP auf dem KAS, wach rund um die  |
      |  - Takt: Johns Rhythmus  | trag |  Uhr, kennt kein Passwort und kein  |
      |  - Denken: Kindprozess   | Erg. |  Modell — nur Johns Stand           |
      |    (Claude-Abo, CLI)     |      |  - Stapel, Aufträge, Log, Geräte    |
      +----------+---------------+      +-------------------------------------+
                 | startet / bewacht
                 v
      +--------------------------+
      | john-server.ps1 :8787    |  bleibt, was er ist: Cockpit-Server und
      | (Compass + Quellen)      |  Quellenbündel. Er ist nicht mehr John.
      +--------------------------+
```

### Schicht 1 — Rezeption (`hub/`, im WWW)

Johns **feste Adresse**: `https://hotel-vaikuntha.de/john/` (Übergang: `https://naturnah-lernen.de/john/`,
dieselben Dateien, siehe `docs/kas-schritte.md`). Reines PHP + JSON-Dateien auf dem KAS-Webspace.

Was sie kann: Johns Stapel halten, Aufträge annehmen und ausgeben, Ergebnisse einsammeln, den Puls der
Geräte notieren, ein Logbuch führen. Was sie **nicht** kann und nie können wird: denken, Modelle rufen,
Schlüssel halten, Mails lesen. Genau daran hängt ihre Verlässlichkeit — es gibt nichts, was langsam
werden könnte. Sie ist Johns Zimmer, nicht sein Kopf.

Damit gilt: **John ist nie „weg".** Ist kein Gerät wach, sagt die Rezeption „Johns Hände schlafen,
sein Stand ist von 22:41" — statt einer leeren Karte, die aussieht wie „nichts zu tun".

### Schicht 2 — Gerät (`geraet/`, je Rechner einer)

`john-worker.ps1` ist der einzige Prozess, der für John *denkt*. Drei Dinge in einer Schleife, die
**nie länger als Millisekunden** blockiert:

- **Tür** (HTTP auf `127.0.0.1:8788`): `/stand` beantwortet sofort, wie es John geht — auch dann, wenn
  der große Server auf 8787 gerade 90 s in einem Claude-Aufruf steht. Das ist die Stelle, die der Lobby
  die Wahrheit sagt. `/wecken` startet den Cockpit-Server nach — deshalb kann der Knopf im Browser
  wirklich starten und braucht keinen Protokoll-Handler in der Registry.
- **Takt**: Johns eigener Rhythmus (Standard 15 min). Er schaut auf seine Welt und *handelt*, ohne
  gefragt zu werden. Das ist der Unterschied zwischen einem Endpunkt und einem Agenten.
- **Hände**: jede langsame Arbeit (Claude-Aufruf, Board, Stapel) läuft als **abgekoppelter
  Kindprozess** (`john-auftrag.ps1`). Der Worker wartet nicht, er schaut nach. Ein Auftrag, der hängt,
  kostet einen Auftrag — nicht John.

### Schicht 2b — die Wolke (`geraet-wolke/`, seit 12.09.2026)

Ein Gerät ohne Rechner: eine Routine in Claude Code (Web) startet stündlich eine Session, die als John
denkt und dasselbe Protokoll spricht. Sie hat keine Tür und keine Räume, nimmt aber Aufträge und setzt den
Stapel, wenn der Rechner schläft. Damit hängt John nicht mehr an vishnu-master (Ursache 3 oben). Warum das
ADR 0001 nicht widerspricht: die Cloud hat inzwischen Mail, Kalender und Jira als Konnektoren —
`docs/adr/0006-geraet-wolke.md`.

### Schicht 3 — Klienten

Der Compass fragt in dieser Reihenfolge: **Gerät (8788) → Cockpit-Server (8787) → Rezeption (WWW)**.
Die erste Antwort gewinnt, und die Karte sagt immer, woher sie kommt. Die **Lobby**
(`compass/compass-john-lobby.js`) erscheint nur, wenn keine der drei Stellen liefert, und tut dann drei
Dinge: Johns letzten Stand aus der Rezeption zeigen, ihn mit einem Knopf starten, und selbst wieder
verschwinden, sobald er antwortet.

## 3. Die Regeln, an denen nicht gedreht wird

1. **Kein Denken im ausliefernden Prozess.** Wer HTTP beantwortet, ruft kein Modell. Neue langsame
   Arbeit wird ein Auftrag, kein Zweig in der Schleife.
2. **Leer heißt nie „nichts".** Jede Karte, jedes Feld nennt den Grund: belegt, schläft, nicht
   angebunden, wirklich nichts zu tun. Vier verschiedene Sätze, nie einer für alles.
3. **Die Rezeption ist dumm.** Kein Modell, kein Schlüssel, kein Zugriff auf Mail/Jira/Konto. Wer der
   Rezeption etwas anvertraut, muss damit leben, dass es auf einem Webspace liegt: Stapelzeilen ja,
   Kontostände nein.
4. **Ein Gerät ist ein Gerät.** Jedes meldet sich mit eigenem Namen und eigenem Puls an. Zwei wache
   Geräte streiten nicht: einen Auftrag bekommt genau eines (Sperre über `nimmt` + Ablaufzeit).
5. **Johns Gedächtnis ist die Rezeption, nicht der Rechner.** Was Bene irgendwo mit „OK" abräumt, ist
   überall weg. Lokale Dateien sind Puffer, nie Wahrheit.
6. **Nichts Persönliches ins Repo** (Regel aus `flow-compass`, gilt hier genauso). Zugänge nur als
   User-Umgebungsvariablen: `JOHN_HUB_URL`, `JOHN_HUB_TOKEN`, `JOHN_GERAET`.

## 4. Was wo liegt

| Teil | Datei | Repo |
|---|---|---|
| Rezeption (WWW) | `hub/api.php`, `hub/index.php`, `hub/.htaccess` | **john-agent** |
| Rezeption hochladen | `hub/hub-deploy.ps1` | **john-agent** |
| Gerät: Worker + Tür + Takt | `geraet/john-worker.ps1` | **john-agent** |
| Gerät: ein einzelner Auftrag | `geraet/john-auftrag.ps1` | **john-agent** |
| Gerät: Aufgaben einrichten | `geraet/john-aufgaben.ps1` | **john-agent** |
| Lobby im Compass | `compass/compass-john-lobby.js` → kopiert nach `flow-compass/` | **john-agent** (Quelle) |
| Gerät „wolke“: Rezeptions-Client, Takt, Umgebung | `geraet-wolke/rezeption.sh`, `geraet-wolke/TAKT.md`, `geraet-wolke/umgebung.md` | **john-agent** (ADR 0006) |
| Cockpit-Server, Quellen, Boards | `john-server.ps1`, `john-board.ps1` | flow-compass |
| Johns Persona, Pipeline, Coaching | `CLAUDE.md`, `bewerbungen/`, `coaching/` | john |
| Madeleines Persona und Wissen | `CLAUDE.md`, `wissen/` | madeleine (Ordner) |
| Vishnu-Seite „Projekt John" | `f/projekt-john.php` | vishnuartists-website-redesign |

## 5. Reihenfolge des Ausbaus

1. **Lobby** — Bene sieht sofort, was ist, und kann starten.
2. **Wiederanlauf verkürzen** — Aufgabe minütlich, Wacht mit ehrlicher Schwelle.
3. **Worker mit Tür und Takt** — John handelt von selbst und ist auskunftsfähig, auch wenn 8787 belegt ist.
4. **Rezeption im WWW** — Johns Stand überlebt den Laptopdeckel; Handy und zweites Gerät bekommen John.
5. **Vishnu-Backend „Projekt John"** — Vorstellung des Projekts und buchbarer virtueller Coach.

Stand der Umsetzung: `docs/stand.md`.
