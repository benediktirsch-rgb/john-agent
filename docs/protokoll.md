# Protokoll der Rezeption — die eine verbindliche Schnittstelle

Alles, was mit John redet (Compass, Worker, Handy, Vishnu-Backend, später fremde Geräte), redet über
dieses Protokoll. Wer es ändert, ändert es **hier zuerst** und dann im Code — sonst laufen zwei
Wahrheiten nebeneinander.

## Adresse

```
https://hotel-vaikuntha.de/john/api.php?w=<was>
```

Übergangsadresse, solange hotel-vaikuntha.de im KAS kein eigenes Dokumentenverzeichnis und kein
Zertifikat hat (siehe `kas-schritte.md`): `https://naturnah-lernen.de/john/api.php?w=<was>` — **dieselben
Dateien, dasselbe Verzeichnis.** Der Worker nimmt `JOHN_HUB_URL`, fällt ohne Variable auf die
Übergangsadresse zurück und schreibt das in seinen Stand, damit niemand rätselt.

## Anmeldung — zwei Schlüssel (seit 11.09.2026)

Jede Anfrage trägt den Kopf `X-John-Token: <Geheimnis>`. Es gibt **zwei** Schlüssel mit
verschiedener Reichweite; die Rezeption speichert von beiden nur den SHA-256 (`token.php`,
gitignoriert, erzeugt von `hub-deploy.ps1`):

| Schlüssel | Variable | liegt wo | darf |
|---|---|---|---|
| **Gerät** (`hash`) | `JOHN_HUB_TOKEN` | Benutzerumgebung jedes Geräts | alles |
| **Browser** (`hash_browser`) | `JOHN_HUB_TOKEN_BROWSER` | eingesetzt im gebauten eigenen Compass | `stand`, `punkt`, `auftrag` |

Warum zwei (Madeleines Einwand, `beratung/protokoll.md`): ein Schlüssel im Browser ist ein Schlüssel,
der verloren gehen kann. Mit dem Browser-Schlüssel lässt sich Johns Stapel weder überschreiben noch
ein Auftrag beanspruchen oder ein Ergebnis fälschen, und er lässt sich einzeln neu würfeln, ohne dass
ein Gerät stehenbleibt. Ohne Kopf oder mit falschem Schlüssel: **403**, nichts geschrieben. Ein
Endpunkt außerhalb der Reichweite: **403** „dieser Schlüssel darf kein …".

**CORS:** kein `*`. Die Rezeption antwortet mit `Access-Control-Allow-Origin` nur den Ursprüngen,
auf denen Johns Klienten laufen (`bene.vishnuartists.com`, `vishnuartists.com`, `vishnu-artists.de`,
`naturnah-lernen.de`, `hotel-vaikuntha.de`, `localhost`/`127.0.0.1` mit beliebigem Port). Das hält
fremde Seiten im Browser draußen; gegen ein kopiertes Token hilft nur die Schlüsseltrennung oben.

Die **Demo und jede Kundeninstanz bekommen keinen der beiden Schlüssel** — der Produkt-Build nimmt
die Lobby ganz heraus.

## Antwortform

Immer JSON, immer mit `ok`. Fehler: `{"ok":false,"fehler":"<klartext>"}` plus HTTP-Code
(400 falsche Eingabe · 403 kein/falsches Token · 409 schon vergeben · 500 Rezeption defekt).
Zeiten immer ISO 8601 mit Zone (`2026-09-10T23:41:07+02:00`), **lokale** Zone Europe/Berlin —
`toISOString()` liefert nachts den Vortag, das ist im Compass schon einmal schiefgegangen.

## Die Endpunkte

### `GET w=stand` — wie geht es John?

Die einzige Frage, die jeder Klient stellt. Antwort:

```json
{ "ok": true,
  "jetzt": "2026-09-10T23:41:07+02:00",
  "wach": true,
  "takt": { "letzter": "2026-09-11T09:30:00+02:00", "geraet": "vishnu-master", "alter_s": 612, "stille_tage": 0 },
  "geraete": [ { "name": "bene-pc", "puls": "2026-09-10T23:40:12+02:00", "alter_s": 55,
                 "wach": true, "takt": "2026-09-10T23:30:00+02:00", "version": "1.0.0",
                 "kann": ["stapel","board","chat"], "notiz": "Cockpit-Server läuft" } ],
  "stapel": { "stand": "2026-09-10T22:41:00+02:00", "quelle": "bene-pc",
              "punkte": [ { "id": "…", "titel": "…", "warum": "…", "art": "rueckfrage", "aktion": "…" } ] },
  "auftraege": { "offen": 1, "laufend": 0, "fertig24": 4 },
  "log": [ { "zeit": "…", "art": "takt", "text": "…" } ] }
```

`takt.letzter` ist der jüngste eigene Takt irgendeines Geräts, `takt.stille_tage` die ganzen Tage seitdem — der Wächter gegen einen John, der seit Tagen nicht mehr denkt, ohne dass es jemand merkt. `null` heißt: noch nie gelaufen.

`wach` ist wahr, wenn **irgendein** Gerät in den letzten 180 s einen Puls geschickt hat. Genau daran
entscheidet die Lobby ihren Satz: `wach:false` heißt „Johns Hände schlafen", nicht „John ist weg".

### `POST w=puls` — ein Gerät meldet sich

```json
{ "geraet": "bene-pc", "version": "1.0.0", "kann": ["stapel","board","chat"],
  "notiz": "Cockpit-Server läuft", "takt": "2026-09-10T23:30:00+02:00" }
```

Antwort: `{"ok":true,"auftraege":<Zahl offener Aufträge>}` — der Worker weiß damit nach einem einzigen
Aufruf, ob er etwas zu tun hat, und braucht keinen zweiten.

### `POST w=stapel` — Johns Stapel setzen

Nur ein Gerät schreibt hier (das, das gerade gedacht hat). `{"stand": "<iso>", "quelle": "<geraet>",
"punkte": [ … ]}`. Die Rezeption nimmt den Stapel **nur an, wenn `stand` neuer ist** als der gespeicherte
— so kann ein spät zurückkehrendes Gerät keinen alten Stand über einen neuen legen.

### `POST w=punkt` — Bene hat etwas abgeräumt

`{"id":"<punkt-id>","tat":"ok|aktion|spaeter","wer":"compass|handy|backend","notiz":"…"}`
Die Rezeption entfernt den Punkt (`ok`) bzw. markiert ihn (`spaeter` mit Wiedervorlage in 24 h) und legt
eine Logzeile. **Das ist die Stelle, die „überall weg" möglich macht** — egal, an welchem Gerät Bene tippt.

### `POST w=auftrag` — jemand will etwas von John

`{"art":"stapel|board|chat|frage|takt|coach","text":"…","wer":"…","dringend":false}`
Antwort `{"ok":true,"id":"…"}`. Die Rezeption speichert nur; ausgeführt wird auf einem Gerät.
Ein Auftrag verfällt nach 24 h unbearbeitet (`verfallen`), damit die Liste nicht zur Halde wird.

### `GET w=auftraege` — was liegt an? (nur Worker)

`{"ok":true,"auftraege":[{"id":"…","art":"…","text":"…","wer":"…","erstellt":"…"}]}` — nur die offenen,
älteste zuerst, höchstens 20.

### `POST w=nimm` — Auftrag beanspruchen

`{"id":"…","geraet":"bene-pc"}` → `{"ok":true}` oder **409**, wenn ein anderes Gerät schneller war.
Die Beanspruchung verfällt nach 15 Minuten; danach darf ein anderes Gerät ran (ein abgestürztes Gerät
darf einen Auftrag nicht für immer festhalten).

### `POST w=ergebnis` — fertig

`{"id":"…","ok":true,"text":"…","notiz":"…"}`. Ergebnisse bleiben 7 Tage lesbar, dann räumt die
Rezeption sie weg.

### `POST w=log` — Logbuch

`{"art":"takt|start|fehler|hinweis","text":"…","geraet":"…"}`. Das Logbuch ist Johns Gedächtnis für
Betrieb, nicht für Inhalte: 200 Zeilen, dann rollt es.

### Briefkasten `daten/eingang.jsonl` — Buchungen von der Vishnu-Seite (seit 11.09.2026)

Die Seite „Projekt John" (`vishnuartists.com/projekt-john.php`) liegt **auf demselben Webspace** wie
die Rezeption. Sie braucht deshalb keinen Schlüssel und keinen HTTP-Aufruf: sie hängt eine Zeile an
`/john/daten/eingang.jsonl` (unter `LOCK_EX`, `FILE_APPEND`) — ein Briefkasten, in den sie nur
einwirft. Die Rezeption leert ihn bei **jeder** Schreibung unter ihrer eigenen Sperre und macht aus
jeder Zeile einen Auftrag der Art `coach`. So bleibt `stand.json` in genau einer Hand.

Zeile: `{"id":"b-<hex>","art":"coach","thema":"flow|karriere|ki|fuehrung","text":"…","wer":"vishnu:<person-id>","vorname":"…","form":"schriftlich|gespraech","wuensche":["2026-09-15 10:00"],"erstellt":"<iso>"}`

Aufträge der Art `coach` beantwortet ein Gerät **ausschließlich** mit der öffentlichen Persona
(`wissen/bene-digital.md`) — ohne Johns Lage, ohne Memory, ohne Dateien aus `C:\dev\john`. Das
Ergebnis ist ein **Entwurf**: die Person sieht ihn erst, wenn Bene ihn auf der Seite freigegeben hat.

Die Vishnu-Seite liest für ihre Anzeige `daten/stand.json` direkt (nur lesend, `LOCK_SH`) und zeigt
Mitgliedern ausschließlich: ob John wach ist, wann sein letzter Takt war, und den Stand **ihrer
eigenen** Buchungen. Johns Stapel sieht dort niemand.
## Sperren und Nebenläufigkeit

Der ganze Zustand liegt in **einer** Datei (`daten/stand.json`). Jede Schreibung liest, ändert und
schreibt die Datei unter **einer** exklusiven Sperre (`flock(LOCK_EX)`, dann `ftruncate` + neu schreiben);
Leser nehmen `LOCK_SH`. Kein Umbenennen einer Nachbardatei — das hätte die Sperre ausgehebelt, weil
sie an der alten Datei hängt. Grund für all das: zwei Geräte,
zwei Browser und der Vishnu-Backend rufen gleichzeitig; ein halb geschriebenes JSON würde John den Kopf
kosten. Nie zwei Zustandsdateien einführen, die zueinander passen müssen.

## Was die Rezeption niemals tut

- kein Modell rufen, keinen Schlüssel halten, keine Mail lesen, kein Jira anfassen;
- keinen Klartext aus Mails, Konten oder CRM speichern — ein Stapelpunkt nennt das Thema, nicht den Inhalt;
- nichts an Bene senden (kein Mailversand, kein Push von dort aus);
- nichts löschen, was ein Gerät gerade beansprucht hat.
