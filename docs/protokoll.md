# Protokoll der Rezeption — die eine verbindliche Schnittstelle

Alles, was mit John redet (Compass, Worker, Handy, Vishnu-Backend, später fremde Geräte), redet über
dieses Protokoll. Wer es ändert, ändert es **hier zuerst** und dann im Code — sonst laufen zwei
Wahrheiten nebeneinander.

## Adresse

```
https://hotel-vaikuntha.de/john/api.php?w=<was>
```

Seit 11.09.2026 mit Zertifikat; die Wurzel-.htaccess schickt jede andere Adresse dieser Domain nach `/john/`. Früher: Übergangsadresse, solange hotel-vaikuntha.de im KAS kein eigenes Dokumentenverzeichnis und kein
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
| **Gerät, gebunden** (`geraete[name]`) | `JOHN_HUB_TOKEN_<NAME>` auf dem Rechner, als `JOHN_HUB_TOKEN` in der Umgebung des Geräts | je Gerät eines | alles, aber nur unter seinem Namen |
| **Browser** (`hash_browser`) | `JOHN_HUB_TOKEN_BROWSER` | eingesetzt im gebauten eigenen Compass | `stand`, `punkt`, `auftrag`, `stapelstand` |

Warum zwei (Madeleines Einwand, `beratung/protokoll.md`): ein Schlüssel im Browser ist ein Schlüssel,
der verloren gehen kann. Mit dem Browser-Schlüssel lässt sich Johns Stapel weder überschreiben noch
ein Auftrag beanspruchen oder ein Ergebnis fälschen, und er lässt sich einzeln neu würfeln, ohne dass
ein Gerät stehenbleibt. Ohne Kopf oder mit falschem Schlüssel: **403**, nichts geschrieben. Ein
Endpunkt außerhalb der Reichweite: **403** „dieser Schlüssel darf kein …".

**Ein Schlüssel je Gerät (seit 12.09.2026, ADR 0007).** `token.php` trägt neben `hash_browser` eine
Liste `geraete` (`name => SHA-256`). Ein Schlüssel aus dieser Liste ist an seinen Namen **gebunden**: die
Rezeption nimmt `geraet` (bei `puls`, `nimm`, `log`), `quelle` (bei `stapel`, `spiegel`) nur an, wenn es
leer ist (dann setzt sie den gebundenen Namen ein) oder genau dem Namen gehört. Ein anderer Name → **403**
„dieser Schlüssel gehört zu <name>“. Damit kann ein geleakter Wolken-Schlüssel nicht als vishnu-master
auftreten, und jeder Schlüssel lässt sich einzeln neu würfeln (`hub-deploy.ps1 -GeraetErzeugen <name>`),
ohne dass ein anderes Gerät stehenbleibt. Der alte ungebundene Geräte-Schlüssel (`hash`) bleibt als
Übergang gültig, bis jedes Gerät seinen eigenen hat; `hub-deploy.ps1 -NurGeraete` lässt ihn weg.

**CORS:** kein `*`. Die Rezeption antwortet mit `Access-Control-Allow-Origin` nur den Ursprüngen,
auf denen Johns Klienten laufen (`bene.vishnuartists.com`, `bene.vaikuntha.eu`, `vishnuartists.com`, `vishnu-artists.de`,
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

`{"art":"stapel|board|chat|frage|takt|coach|raum","text":"…","wer":"…","dringend":false}` (bei `raum` kein `text`, siehe Gesprächsraum)
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

### Gesprächsraum: Art `raum`, Status `gestoppt`, `POST w=stopp` (seit 11.09.2026 — Vertrag für Astras Oberfläche)

Ein gemeinsamer Raum, in dem Bene, John und Madeleine sprechen. **Der Text liegt auf dem Gerät**
(`C:\dev\john\coaching\raum\<raum>.jsonl`), die Rezeption trägt nur das Signal: wer gerade denkt, in welchem
Raum, welcher Zug, welcher Status. Integrationsvorlage: `madelene-agent/docs/integration-gespraechsraum.md`.

**Auftrag der Art `raum`** (`POST w=auftrag`, nur Gerät legt ihn an):
`{"art":"raum","raum":"<id>","zug":<n>,"an":"john|madeleine","thema":"<≤80 Zeichen>","wer":"<geraet>"}`
- `raum`: `[a-z0-9-]{1,40}`. `an`: wer diesen Zug denkt. `thema`: Überschrift des Raums, das Thema, nicht der Inhalt.
- **`text` muss leer sein** — sonst **400** „raum trägt keinen Text". Ebenso bei `w=ergebnis`: nur `ok`, `notiz`
  (≤300, z. B. „Zug 4 liegt am Gerät (812 Zeichen)").
- Eine eigene Art `madeleine` gibt es **nicht**: eine einzelne Frage an Madeleine ist ein Raum mit einem Zug. Ein
  Weg, nicht zwei.

**Status** (für alle Arten):

```
 offen ──nimm──► laeuft ──ergebnis──► fertig
   │               │
   └──── stopp ────┴──────────────► gestoppt        (verfällt wie fertig nach 7 Tagen)
   └── 24 h ──► verfallen
```

- `POST w=stopp {"id":"<auftrag>","wer":"compass|handy|geraet"}` (Gerät und Browser): `offen`/`laeuft` →
  `gestoppt`. Auf `fertig`/`verfallen`/`gestoppt` → **409**.
- `nimm` und `ergebnis` auf einen gestoppten Auftrag → **409**.
- `POST w=puls` antwortet zusätzlich `stopp: [<ids>]` — gestoppte Aufträge, die **dieses** Gerät beansprucht hatte
  (letzte Stunde). Das Gerät beendet den zugehörigen Kindprozess; so wirkt ein Stopp vom Handy.
- `GET w=stand` liefert `raeume: [{id, raum, thema, zug, an, status, erstellt, fertig}]` — die letzten 20
  Raum-Aufträge, **ohne Text**. Damit zeigt das Handy den Stand eines Raums.
- Offene Raum-Aufträge zählen **nicht** in `puls.auftraege`: sie nimmt der Kindprozess, der sie angelegt hat,
  sofort selbst. Sonst startete das Gerät für jeden Zug einen leeren Hub-Lauf.

**Tür des Workers (nur lokal, `http://127.0.0.1:8788`, ab Worker 1.2.0)** — hier liegt der Text:

| Aufruf | Antwort |
|---|---|
| `GET /raeume` | `{ok, raeume:[{id, thema, zuege, zuletzt, laeuft:<bool>, wartet:[an…]}]}` — die 50 jüngsten Räume |
| `GET /raum?id=<raum>&seit=<zug>` | `{ok, id, thema, zuege:[{zug, wer, zeit, text, weitergeben}], laeuft:{an, seit}\|null, wartet:[an…]}` — `seit` liefert nur neuere Züge (Live: alle 2 s fragen, die Tür antwortet in ms). **404**, wenn es den Raum nicht gibt |
| `POST /raum {id?, thema?, text, an:"john"\|"madeleine"\|"beide"}` | `{ok, id, zug, wartet}` — ohne `id` entsteht ein neuer Raum (Kennung aus dem Thema + Datum, ohne `thema` die erste Zeile des Texts); Benes Zug wird angehängt, die Antwort eingereiht (`wartet: true`, wenn John gerade anderes denkt oder ein anderer Raum vorn steht). `text` ≤ 8000 Zeichen (**413**), `an` Pflicht (**400**), unbekannte `id` **404**. Schreibt Bene zweimal, bevor jemand antwortet, entsteht kein zweiter Lauf — der wartende wird erweitert (john + madeleine = beide) |
| `POST /raum/weitergeben {id, zug, weitergeben:false\|true}` | `{ok, id, zug, weitergeben}` — dieser Zug geht in keinen weiteren Zug ein (bzw. wieder ein). Unbekannter Zug **404** |
| `POST /stopp {id:<raum>}` | `{ok, gestoppt:<bool>}` — beendet den laufenden Zug **samt Modellprozess** (`taskkill /T`), leert die Warteschlange des Raums, schreibt eine `system`-Zeile, meldet `w=stopp`. `gestoppt:false` = es lief nichts und wartete nichts |

- **Reihenfolge:** Ein wartender Raum-Zug geht vor Takt und Hub-Aufträgen — dort wartet ein Mensch. Denkt John
  gerade (Takt, Frage), wartet der Raum, bis der Kopf frei ist; ein Denkvorgang wird nie abgebrochen, um
  einen anderen zu starten.
- **Stopp vom Handy:** Browser → `w=stopp` an der Rezeption → nächster Puls des Geräts (alle **10 s**, solange
  im Raum gesprochen wird, sonst 60 s) → Gerät beendet den Lauf, `system`-Zeile „Gestoppt von einem anderen Gerät".
- **Hänger:** Ein Raum-Lauf wird nach 16 Min beendet („beide" sind zwei Modellaufrufe à bis 7 Min), andere nach 12.
- **Zugnummern:** Tür und Kindprozess schreiben dieselbe Datei; beide nehmen den Mutex `Local\john-raum-<id>`.

**Wer die Tür benutzen darf.** Die Tür beantwortet Privates. Deshalb:
- Kommt eine Anfrage mit `Origin`, muss es eine eigene Seite sein: `https://bene.vishnuartists.com`,
  `http(s)://localhost:<port>`, `http(s)://127.0.0.1:<port>` und was in der User-Variable `JOHN_TUER_ORIGINS`
  steht (Komma-getrennt). Sonst **403** — auch für `GET` und `OPTIONS`. `Access-Control-Allow-Origin` nennt genau
  diese Herkunft, nie `*`.
- Anfragen **ohne** `Origin` (PowerShell, curl, geplante Aufgaben) sind erlaubt: sie kommen nicht aus einer
  fremden Webseite.
- **Handlungen nur per `POST`:** `/wecken`, `/takt`, `/raum` (schreibend), `/raum/weitergeben`, `/stopp`, `/__stop`.
  `GET` darauf → **405**. Grund: ein `<img src="http://127.0.0.1:8788/wecken">` auf einer fremden Seite schickt
  keinen `Origin` und darf nichts auslösen.
- DNS-Rebinding greift nicht: http.sys nimmt nur die Hosts `127.0.0.1` und `localhost` an.

`wer` eines Zugs: `bene` · `john` · `madeleine` · `system` (Stopp, Fehler — „leer heißt nie nichts").

**Was in einen Zug eingeht:** Persona und Wissen **des Sprechenden** (John: seine Lage; Madeleine: ihr Wissen,
privater Stand, Live-Zahlen aus dem Finanzlauf) plus die Züge dieses Raums mit `weitergeben ≠ false`. Nie die
Wissensdateien des anderen.
### Johns Kachel überall: `compass` in `w=stand`, `POST w=spiegel`, `POST w=stapelstand` (seit 11.09.2026)

Johns Kachel im Compass bekommt ihren Stapel vom Cockpit-Server (`/api/john/stapel`). Am Handy und auf
jedem anderen Gerät ist dieser Server nicht erreichbar — die Kachel war dort leer. Deshalb spiegelt
das Gerät den Stapel in die Rezeption, und jedes Gerät liest ihn dort, wenn es den Server nicht erreicht.

- `w=stand` liefert zusätzlich `compass: { punkte, stand, stand_um, quelle }`. `punkte` sind Johns
  Stapelpunkte in der Form des Compass (`key`, `titel`, `satz`, `aktion`), `stand` ist der Stand je
  Punkt (`{key: {status: ok|wieder|offen, ts, bis, aktion, titel}}`).
- `POST w=spiegel` (**nur Gerät**): `{punkte, stand, stand_um, quelle}`. Die Punkte werden ersetzt,
  der Stand wird **gemischt: der jüngere `ts` gewinnt** (so kann ein Gerät kein OK vom Handy
  überschreiben, das es noch nicht kennt). Antwort: der gemischte `stand`, damit das Gerät weiß,
  was es an den Cockpit-Server nachreichen muss.
- `POST w=stapelstand` (**Gerät und Browser**): `{key, status, ts, bis, aktion, titel}` — ein OK,
  eine Wiedervorlage oder ein Zurück, egal von welchem Gerät. Wieder gilt: jüngerer `ts` gewinnt.
- `POST w=puls` antwortet zusätzlich mit `compassTs` (jüngster `ts` im gespiegelten Stand). Liegt er
  nach dem letzten Abgleich des Geräts, reicht es die neuen Einträge über den Endpunkt des
  Cockpit-Servers (`POST /api/john/stapel/stand`) nach — nie über die Datei (ADR 0004).

**Was nicht in die Rezeption gespiegelt wird:** der Mail-Entwurf einer Aktion (`an`, `betreff`,
`text`) und jeder Claude-Auftrag. Solche Aktionen tragen im Spiegel `nurAmRechner: true`; die
Kachel sagt am Handy „am Rechner", statt einen leeren Entwurf zu öffnen. Titel und Satz eines
Punkts gehen mit (Satz auf 500 Zeichen gekürzt) — das ist die Grenze aus ADR 0002: das Thema ja,
der Inhalt nein.
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
