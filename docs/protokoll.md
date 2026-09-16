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
| **Browser** (`hash_browser`) | `JOHN_HUB_TOKEN_BROWSER` | eingesetzt im gebauten eigenen Compass | `stand`, `punkt`, `auftrag`, `stapelstand`, `stopp`, `rueckfragen`, `rueckfrage-antwort` |
| **Beraterin** (`berater[name]`, seit 16.09.2026) | `JOHN_HUB_TOKEN_BERATER_<NAME>` auf Benes Rechner, in der Umgebung der Beraterin als `JOHN_HUB_TOKEN` | je Beraterin einer (heute: `madelene`) | `stand` (verkürzt: `wach`, `takt`, Gerätenamen, nur **ihre** offenen Rückfragen — ohne Stapel, Compass-Spiegel, Räume, Logbuch; `sicht: "beraterin"`), `rueckfragen` (**nur ihre eigenen**), `rueckfrage`, `log` — nur unter ihrem Namen. Einzeln widerrufbar: `hub-deploy.ps1 -BeraterWiderrufen <name>` |

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
### Rückfragen an der Rezeption: `w=rueckfragen`, `w=rueckfrage`, `w=rueckfrage-antwort` (seit 16.09.2026)

Bene, 16.09.2026: „Ich will Madelene gleichberechtigten Zugriff auf meinen Compass geben und auch alle
Rückfragen von ihr dort sehen."

Bis hierher lebten Rückfragen an Bene nur in `rhythmus-data.js › rueckfragen` auf seinem Rechner. Schreiben
konnte sie nur, wer dort eine Datei anfasst — Claude. Madelene (Astra, Codex in ChatGPT Work) hat GitHub und
ihre eigene Linux-Umgebung, sonst nichts. Deshalb hält die Rezeption jetzt **Rückfragen**: wer fragt, legt sie
hier ab; der Compass zeigt sie im Banner „Fragen an dich" und im Ritual, auf jedem Gerät; die Antwort kommt
hierher zurück, und wer gefragt hat, liest sie hier ab. Die Rezeption bleibt dumm: sie hält Frage, Optionen und
Antwort — keine Zahlen, keine Personendaten (ADR 0002). Wer fragt, hält sich daran.

**Form** — dieselbe wie im Compass, plus Herkunft und Stand:

```json
{ "id": "madelene-compass-checkins-20260916", "von": "madelene", "projekt": "Madelene · flow-compass",
  "frage": "…?", "warum": "…", "optionen": ["…", "…", "…"], "wann": "2026-09-16", "link": null, "dringend": false,
  "erstellt": "2026-09-16T10:02:11+02:00", "geaendert": "2026-09-16T10:02:11+02:00",
  "status": "offen", "antwort": null }
```

- `id`: `[a-z0-9][a-z0-9-]{2,59}`; eine Beraterin beginnt sie mit ihrem Namen (`madelene-…`), sonst **400**.
- Grenzen: `frage` ≤ 500 Zeichen, `warum` ≤ 2000, `projekt` ≤ 120, bis zu 4 `optionen` à 160, `link` nur `http(s)`.
  `wann` (`JJJJ-MM-TT`) sagt, ab wann sie erscheint; leer = heute. `dringend` (bool) stellt sie im Compass nach vorn;
  eine Beraterin darf **höchstens eine** dringende offene Rückfrage haben (**409**).
- `status`: `offen` → `beantwortet` (Bene) oder `zurueckgezogen` (der Fragende). Beantwortetes und Zurückgezogenes
  bleibt 30 Tage lesbar, dann räumt die Rezeption es weg.
- Höchstens **5 offene je Beraterin** und 60 insgesamt — mehr wäre kein Fragen, sondern eine Halde (**409**).

**Endpunkte**

| Aufruf | wer | Antwort |
|---|---|---|
| `GET w=rueckfragen[&status=offen\|beantwortet\|zurueckgezogen\|alle][&von=<name>][&seit=<iso>]` | Gerät, Browser, Beraterin | `{ok, jetzt, rueckfragen:[…]}` — jüngste Änderung zuerst, höchstens 100. Standard `status=offen`; `seit` liefert nur, was danach geändert wurde. **Eine Beraterin sieht nur ihre eigenen** (`von` wird erzwungen, ein fremdes `von` → **403**) |
| `POST w=rueckfrage {id, projekt, frage, warum, optionen, wann?, link?, von?}` | Gerät, Beraterin | anlegen oder die eigene ändern: `{ok, id, status, offen}`. Beraterin: `von` ist ihr gebundener Name, `von` im Körper wird ignoriert. Gerät: `von` Standard `claude`. Gleiche `id` desselben `von` → aktualisiert; fremde `id` → **403**; schon beantwortet → **409** (neue id nehmen) |
| `POST w=rueckfrage {id, zurueckziehen: true}` | Gerät, Beraterin | nur die eigene: `status=zurueckgezogen`. Unbekannt **404**, beantwortet **409** |
| `POST w=rueckfrage-antwort {id, a, ts?, wer?}` | Gerät, Browser | `a` Pflicht (≤ 200), `ts` Datum (Standard heute, Berlin), `wer` `compass\|checkin\|claude\|geraet`. Setzt `status=beantwortet`, `antwort={a, ts, wer, zeit}`; eine spätere Antwort überschreibt (wie `Add-Antwort -direkt` im Compass-Server). Unbekannt **404**, zurückgezogen **409** |

`GET w=stand` liefert zusätzlich `rueckfragen: {offen, von: {<name>: <n>}}` (für eine Beraterin nur ihre eigene
Zahl). Ins Logbuch geht nur `id` und `von`, nie Frage oder Antwort.

**Wiederholen ist sicher (idempotent).** Die Kennung vergibt, wer fragt — die Rezeption erzeugt keine. Geht die
Antwort auf `w=rueckfrage` verloren, wird derselbe Körper mit derselben `id` noch einmal gesendet: gleiche Felder →
`{ok, unveraendert: true}` ohne Schreibung und ohne neues `geaendert`; geänderte Felder → Aktualisierung; inzwischen
beantwortet → **409** (für den Client: angekommen, nicht neu stellen). Beim Wiederholen nie eine neue `id` erzeugen.
Dasselbe gilt für `w=rueckfrage-antwort` (gleiche Antwort → `unveraendert`). Parallele Aufrufe mit derselben `id`
ergeben einen Eintrag, weil jede Schreibung unter derselben Sperre liest und prüft.

**Eine fremde Kennung** meldet einer Beraterin nur „id vergeben“ (**409**), ohne zu verraten, wem sie gehört.

**Wer liest was**

- **Compass** (Browser-Schlüssel, `compass-fragen-rezeption.js`): holt die offenen, hängt sie an `offeneFragen()`
  (Kennung bleibt die `id`; steht dieselbe `id` schon in `rhythmus-data.js`, gewinnt die Datei), schreibt jede
  Antwort zusätzlich per `w=rueckfrage-antwort` hierher. Ohne `JOHN_HUB`/`JOHN_HUB_TOKEN` (Demo, Kundeninstanz)
  tut die Datei nichts.
- **Claude** (Geräte-Schlüssel): liest hier, was Madelene gefragt und Bene geantwortet hat (Astra-Postfach).
  Claudes eigene Rückfragen bleiben vorerst in `rhythmus-data.js` und werden **nicht** hierher gespiegelt: ihre
  Begründungen tragen Namen und Beträge, und die Rezeption hält keine Inhalte (Regel 3). Ob und in welchem
  Umfang gespiegelt wird (nur Frage und Antwort, oder alles), ist Benes Rückfrage `madelene-sieht-claudes-fragen`.
  Die Schnittstelle trägt es schon: ein Gerät legt Fragen mit `von=claude` an.
- **Madelene** (Beraterinnen-Schlüssel): legt Rückfragen an, liest Antworten, zieht zurück. Sie ist kein Gerät:
  kein `puls`, kein `nimm`, kein `ergebnis`, kein `stapel`.

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

### Holodeck: Browserstimme und eingeladene Gastdarstellung (11.09.2026)

Die Tür-Schnittstelle bleibt unverändert. Der Browser wandelt Sprache optional in Text um und
sendet diesen ausschließlich an die lokale Tür. Browser-Spracherkennung kann Audio beim
Browseranbieter verarbeiten; Aktivierung verlangt bewusste Wahl dieses Dienstes oder lokale
Erkennung (falls Browser und Sprachpaket vorhanden). Kein Audio wird von uns aufgezeichnet,
gespeichert oder an die Rezeption geschickt. Bestehende Modellverarbeitung des Texts bleibt gleich.

Neue Antworten werden optional mit synthetischen Browserstimmen vorgelesen. Während Ausgabe
und Modelllauf pausiert das Mikrofon. Unterbrechen beendet Ausgabe und ruft POST /stopp auf.
Schließen, Hintergrund, Raumwechsel und Verbindungsverlust beenden den Sprachmodus.
Keine Hintergrundaufnahme, kein Wiederholen alter Antworten, kein automatischer Retry eines POST.

Gäste werden zunächst vorgeschlagen und nur per ausdrücklichem Klick eingeladen. John stellt
die KI-Gastrolle dar, Madeleine bleibt sie selbst. Kein dritter Modellprozess, keine behauptete
Originalstimme. Ein vor dem Senden angezeigter Rollenauftrag wird im lokalen Nachrichten-Text
mitgeschickt; der Verlauf dokumentiert ihn. Die Auswahl gilt pro Raum und Browser-Sitzung.
Vorbereitet: Nietzsche, Merz, Trump, Picard sowie fiktive Fachgäste für weitere Expertise.

## Holodeck: Wolken-Coach und Avatar-Ausgabe (15.09.2026)

### Erste Clip-Ausgabe (15.09., Folgeauftrag Bewegtbild)

Die Regie liest zusätzlich `holodeck-assets/motion-manifest.json`:
`{version:1, reception:{video,poster}, john:{video,poster}}`. Pfade unterliegen
derselben sicheren Asset-Auflösung wie das vorhandene Manifest. Fehlende Datei
lässt den bisherigen Raum unverändert. Diese erste Implementierung spielt kurze,
stumme, vorproduzierte Clips, keinen Visem-Renderer. Keine zweite KI-Persona.
Empfang läuft einmal nach dem Eintritt, mit Überspringen und maximal 6 Sekunden
Wartezeit. Johns Nahaufnahme läuft einmal beim Öffnen und beim Beginn des Zuhörens;
sie ist als vorbereitete Mimik gekennzeichnet, keine inhaltliche/emotionale Bewertung.
Sprechausgabe pausiert den Clip: keine unpassende Mundbewegung als Lippensync ausgeben.
Clipende hält das letzte Bild, kein abrupter Endlosschleifen-Sprung. Unterbrechen,
Platzwechsel, Tab-Verbergen und Schließen stoppen die Bewegung. Reduzierte Bewegung
zeigt nur das Poster. Fehler/Autoplay-Sperre führen zum Poster, ohne Ton/Mikrofon zu ändern.
Die Nahaufnahme zeigt die vorhandene Kamin-Aufnahme auch im Enterprise-Raum und wird
als solche benannt; keine falsche Behauptung einer neu gerenderten Enterprise-Aufnahme.

Dieser Abschnitt ergänzt die Rezeption, ersetzt deren Geräte-/Hub-Vertrag aber nicht.
**Ist:** `compass/holodeck-engine/coach-door.js` adaptiert die bestehende Wolken-API
`GET /status` und `POST /api/john` auf die lokalen Raumoperationen im Browser.
Nur John antwortet. Räume existieren im Arbeitsspeicher der Browser-Sitzung.
Unterbrechen beendet Audio und Empfang; es bestätigt keinen Modellstopp auf dem Server.
Die Anmeldung funktioniert laut Betriebsübergabe vom 15.09.2026, 11:10 wieder.
Server, Zugänge und Instanzen werden ausschließlich auf der Infrastruktur-Wikiseite
2771189762 dokumentiert; keine Zugangsadresse oder Schlüssel in diesem Vertrag.

### Avatar-Vertrag v1 — Vorschlag, noch kein aktiver Renderer

Die Regie steuert Zustände, ein Renderer nur Bild und Bewegung. Er bekommt weder
Coaching-Kontext noch Mikrofon-Rohdaten und ruft kein Sprachmodell auf. John bleibt
die einzige KI-Persona. Ein Renderer implementiert:

```ts
type AvatarState = 'idle' | 'listening' | 'thinking' | 'speaking';
type Cue = {atMs: number; durationMs: number; viseme: string; weight: number};
interface AvatarRenderer {
  capabilities: {states: AvatarState[]; visemes: boolean};
  prepare(input: {manifestVersion: 1; assets: Record<string, string>},
          signal: AbortSignal): Promise<void>;
  setState(input: {sessionId: string; turnId: string; state: AvatarState}): void;
  presentSpeech(input: {
    sessionId: string; turnId: string; cues: Cue[];
    // Wiedergabezeit der tatsächlich hörbaren Audiospur, nicht Antwortankunft.
    playbackTimeMs: () => number;
  }): void;
  stop(input: {sessionId: string; turnId: string}): void;
  dispose(): void;
}
```

Audio gehört dem Sprachplayer; stumme Clips dürfen keine zweite Stimme abspielen.
Der Player ist die Zeitquelle: Start erst bei tatsächlicher Wiedergabe, Pause friert
Bewegung ein, Ende führt zu idle. Cues müssen monoton, endlich und innerhalb der
Audiodauer liegen; Gewichte liegen zwischen 0 und 1. Unbekannte Viseme werden neutral.
Ein Wechsel oder Abbruch entwertet die turnId vor dem Stoppen; verspätete Cues werden
verworfen. `stop` und `dispose` müssen wiederholbar sein und Ressourcen freigeben.
Renderer-Fehler dürfen Audio, Untertitel und Unterbrechen nicht blockieren.

Browser-Sprachausgabe bietet hier bislang keine verlässliche Visem-Zeitspur.
Ohne gemessene Zeitspur und geeigneten Renderer wird **keine Lippensynchronität**
behauptet. Zuhören/Denken dürfen vorbereitete echte Bewegungsschleifen verwenden;
ein Reaktionsclip wird nur durch explizite Regie ausgelöst, nicht aus einer vermuteten
Emotion des Nutzers abgeleitet. Antworttext allein ist kein verlässlicher Mimik-Takt.

Medien werden nur über die bestehende geprüfte Asset-URL-Auflösung geladen. Das
bisherige Manifest `{assets: {id: {poster, video}}}` bleibt kompatibel. Eine künftige
versionierte Erweiterung `avatar: {version: 1, john: {idle, listening, thinking}}`
verweist auf Asset-IDs. Sie wird erst mit echten Medien und einem getesteten Renderer
aktiviert. Fehlende Clips führen zum Poster mit ehrlicher Kennzeichnung. Bei
reduzierter Bewegung bleibt die Darstellung statisch; Stimme und Untertitel funktionieren.
Ein Raumloop ist Kulisse und ersetzt keine individuelle Gesichtsanimation.

### Server-Stopp v1 — zurückgestellt (Bene, 15.09.2026)

**Entscheidung:** nicht bauen, bis das Holodeck sich im Alltag bewährt hat. Stattdessen sagt die
Oberfläche, was sie wirklich tut: der Knopf heißt „Unterbrechen · Empfang aus“ und trägt als Titel
„Beendet Stimme und Antwortempfang. John kann auf dem Server weiterdenken; ein bestätigter
Modellstopp ist hier noch nicht eingebaut.“ Der UI-Test hält diese Zusage fest
(`tools/tests/test-experience.cjs`), damit sie beim nächsten Umbau nicht wieder zu
„stoppt Stimme und Modell“ wird — genau so war die falsche Zusage entstanden.

Grund für das Zurückstellen: die Umsetzung fässt den laufenden Dienst an, an dem auch die
Team-Instanzen hängen, und beendet Prozessbäume. Dafür gibt es bisher keine Last — im Holodeck
wurde noch kein echtes Gespräch geführt. Der Vertrag unten bleibt gültig und ist der Bauplan,
sobald die Entscheidung kippt. Bis dahin: `capabilities.holodeckJobs` aus, `/api/john` unverändert.

Der ursprüngliche Vorschlag (Astra, 15.09.2026):

Ziel: HTTP-Auslieferung und Modellarbeit trennen. Ein kurzer HTTP-Aufruf legt einen
Auftrag an; ein begrenzter Worker führt ihn aus. Status und Stopp bleiben währenddessen
erreichbar. Keine Modellaufrufe im ausliefernden Prozess. Der bisherige `/api/john`-Weg
bleibt kompatibel, bis eine explizite Capability die neue Umsetzung bestätigt.

| Operation | Vorgeschlagener Vertrag |
|---|---|
| `GET /status` | zusätzlich `capabilities.holodeckJobs=1` und `capabilities.cancelJob=true`; erst nach implementierter Abnahme melden |
| `POST /api/holodeck/jobs` | `{requestId, messages, context}` → HTTP 202 `{jobId, state:'queued'}`; John ist serverseitig festgelegt |
| `GET /api/holodeck/jobs/{jobId}` | `{jobId,state}` mit `queued/running/completed/cancel_requested/cancelled/failed`; bei completed zusätzlich `text` |
| `POST /api/holodeck/jobs/{jobId}/cancel` | wiederholbar; HTTP 202 `cancel_requested` oder HTTP 200 terminaler Zustand; kein Erfolg allein durch Socket-Abbruch |

Bestehende Authentisierung und Herkunftsprüfung gelten weiter. Jede jobId gehört
genau einer authentisierten Instanz; fremde und unbekannte IDs liefern gleichermaßen
404. UUIDs sind Identifikatoren, keine Zugangsberechtigung. requestId verhindert
doppeltes Starten derselben Anfrage; gleiche ID mit anderem Inhalt ergibt 409.
Für den Anfang maximal ein laufender Auftrag je Instanz, keine unbegrenzte Warteschlange;
Überlast wird als 429 mit Retry-After beantwortet, ohne automatisches erneutes Senden.
Text- und Kontextgrößen werden vor Annahme begrenzt.

`cancelled` darf der Server erst melden, wenn der Auftrag aus der Warteschlange entfernt
oder der zugehörige Worker samt Kindprozessen nachweislich beendet wurde. Eine inzwischen
fertige Antwort bleibt `completed`; Abbruch darf sie nicht nachträglich als gestoppt
deklarieren. Wiederholte Cancel-Aufrufe verändern terminale Zustände nicht.
Nach Empfangsabbruch zeigt der Browser auch ein spätes completed-Ergebnis nicht ungefragt.
Bei Timeout lautet der Zustand „Stopp nicht bestätigt“; keine automatische Wiederholung
des Gesprächs. Bei fehlender Capability bleibt „Unterbrechen = Empfang aus“ bestehen.

Vorschlag zur Aufbewahrung: terminale Ergebnisse höchstens 15 Minuten im Arbeitsspeicher,
keine Gesprächsinhalte im Betriebslog. Nach Neustart liefern verlorene Jobs 404;
die Oberfläche benennt den Verlust und sendet keinen Auftrag erneut. Laufende Jobs
haben eine feste maximale Laufzeit; deren Beendigung nutzt denselben Worker-Abbruchpfad.
Erst nach Last-, Authentisierungs-, Neustart- und Prozessabbruchtests wird die Capability
aktiviert. Der Browseradapter wechselt niemals aufgrund eines einzelnen 404 heimlich
zwischen altem und neuem Versandweg.
