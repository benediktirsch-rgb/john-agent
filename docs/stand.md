# Stand — was läuft, was fehlt

Diese Datei wird bei **jeder** Änderung nachgezogen. Sie ist die einzige Stelle, an der die
nächste Session sieht, wo sie steht.

## Neu am 16.09.2026 abends: eine Madelene

Bene: „Nur pro Frage, mit Vorschau und 30 Tagen“ und „Madelene ist eine Person“.

- **Rezeption (live, f6ffce0):**
  - `w=freigabe` / `w=freigaben`: Musterprüfung, höchstens 30 Tage, Widerruf löscht.
  - `w=gedaechtnis`: Astra und Beratungs-Laufzeit schreiben und lesen.
  - `w=persona`: nur ein Gerät lädt hoch, die Persona liegt in `daten/`, das per `.htaccess` gesperrt ist.
  - `bezug` an Rückfragen.
  - Prüfstand 92/92 lokal. Live lesend geprüft: Browser, Astra, Gerät je 200; Persona für den Browser 403, Persona-Datei direkt 403.
- **Persona:** `hub-deploy.ps1` lädt `C:\dev\madeleine\persona-gemeinsam.md` hoch (nach Sperrliste und Muster; 3168 Zeichen live).
- **Compass (flow-compass 38e8850):**
  - Knopf „🔓 Für Madelene …“ in `compass-fragen-rezeption.js`.
  - Im Browser gegen eine Test-Rezeption geprüft: Warnung bei Betrag, Senden mit 14 Tagen, Madelene sieht genau den Vorschau-Text, Widerruf löscht.
  - Staging ist live, Prod folgt beim nächsten Publish nach dem Commit der Wolke-Session.
- **Beratungs-Laufzeit:**
  - `flow-compass/produkt/server/madelene-gemeinsam.ps1` in `john-madeleine.ps1` eingebunden, john-server neu gestartet. Status nennt `persona-gemeinsam.md` und die drei Rezeptionsquellen.
  - `madeleine.ps1` (wolke) bindet das Modul in der Session „Briefkasten/Madeleine auf wolke“ ein.
- **Offen:**
  - Astra liest `docs/madelene-compass.md` Abschnitt 9 (Hinweis ins Issue #1 über die Astra-Postfach-Routine).
  - Themen-Vorauswahl (Weg B) ist bewusst nicht gebaut.

## Läuft (Stand 11.09.2026, 14:45)

| Teil | Zustand | geprüft womit |
|---|---|---|
| **Lobby** im Compass | in `dashboard.html`, in der eigenen Instanz gebaut | Browser: fünf Lagen richtig benannt, Fenster öffnet nach 2 Fehlschlägen (~6 s) |
| **Worker** auf `vishnu-master` | Aufgabe „John Worker", Tür auf 8788 | `GET /stand` antwortet in ms, `POST /wecken` erkennt einen gesunden Server |
| **Rezeption** im WWW | **`https://hotel-vaikuntha.de/john/`** (Zertifikat seit 11.09.; Domain-Wurzel leitet nach /john/), zweite Adresse `naturnah-lernen.de/john/` | alle neun Endpunkte durchgespielt; ohne Token 403, `stand.json` und `token.php` 403 |
| **Puls** Gerät → Rezeption | jede Minute | Rezeption meldet `wach: true`, Gerät `vishnu-master` |
| **Wiederanlauf** | Aufgabe „John Server" jetzt **jede Minute** (vorher 5) | `-Status` zeigt `PT1M` |
| **Hub im Compass-Build** | `build-compass.ps1` setzt Adresse + Token in die eigene Instanz | im gebauten `index.html` nachgelesen |
| **Zwei Schlüssel** (Gerät / Browser) + CORS-Allowlist | Madeleines Einwand, sofort umgesetzt | live: Browser-Schlüssel auf `stapel`/`auftraege`/`log` → 403, fremder Ursprung ohne Allow-Origin |
| **Takt-Wächter** `takt.letzter` / `stille_tage` | in `w=stand`, in der Lobby sichtbar | Feld live abgefragt (noch `null`: erster Takt am Morgen) |
| **Projekt John** auf vishnuartists.com | `f/projekt-john.php`, im Menü „Intern" jeder eingeloggten Seite | Prüfstand 25/25; Deploy über GitHub |
| **Bene digital** (Buchung → Entwurf → Freigabe) | Briefkasten `daten/eingang.jsonl`, Auftrag `coach`, öffentliche Persona | echter Durchlauf 11.09. 00:42: Worker holte den Auftrag selbst, Claude 12 s, Entwurf in der Rezeption |
| **Kachel auf allen Geräten** | Worker spiegelt den Compass-Stapel (`w=spiegel`), Kachel liest ihn aus dem Zimmer, wenn der Server fehlt; OK/⏰ gehen ins Zimmer (`w=stapelstand`) und zurück an den Server | Browser: Kachel aus dem Zimmer mit Hinweis; OK per Browser-Schlüssel kam beim Server an, zweiter Lauf reicht nichts doppelt nach |
| **Takt auf der Kachel** | „🔔 Von selbst gesehen · Johns Takt HH:MM" mit „In den Stapel sortieren" / „Gesehen" | Browser, drei Funde des 09:30-Takts sichtbar |
| **Erster Takttag** 11.09. | 06:30 und 09:30 mit Funden, dazwischen „nichts Neues" | Hash-Bremse war wirkungslos (Uhrzeit im Hash) — seit 10:15 behoben |
| **Demo bleibt sauber** | Produkt-Build nimmt Lobby und Rezeption heraus | Wortprüfung bestanden, `compass-john-lobby.js` nicht im Demo-Ordner |
| **Gesprächsraum — Backend** (Worker 1.2.0) | Tür: `/raeume`, `/raum`, `/raum/weitergeben`, `/stopp`; Warteschlange vor dem Takt; Rezeption: Art `raum` ohne Text, Status `gestoppt`, `w=stopp`, `puls.stopp`; Madeleine denkt im Worker über `john-ki.ps1` (Codex) | Rezeption-Prüfstand 21/21 lokal, live deployt; Tür-Prüfstand 29/29 am laufenden Worker: echte Antworten von John, Stopp mitten in „beide" (auch mit lebendem `codex.exe` — nichts überlebt), Stopp vom Handy über die Rezeption binnen 10 s; Rezeption kennt Status, keinen Satz Inhalt |
| **Tür nur für eigene Seiten** | `Allow-Origin: *` ist weg: fremde Herkunft 403, Handlungen nur per POST (405) | im Tür-Prüfstand (Abschnitt A) |
| **Tür-Attrappe** für die Oberfläche | `tools/tuer-attrappe.php` — derselbe Vertrag mit gespielten Antworten | 10 Prüfungen gegen `php -S` |
| **Gesprächsraum — Oberfläche** (von Astra, eingebaut 11.09. 14:40) | `compass/compass-gespraechsraum.js` → per `john-aufgaben.ps1 -Sync` nach flow-compass kopiert, `<script>` in `dashboard.html` nach der Lobby, Demo nimmt es heraus; Knopf „Gespräch mit John & Madeleine“ in Johns Karte | am **echten** Worker aus `localhost:8787`: Tür erreichbar, neuer Raum „Einbauprobe (Claude)“, John antwortet nach ~5 s, Status zurück auf „Bereit.“, Stopp gesperrt; Demo-Build: Wortprüfung bestanden, 0 Treffer |

| **Gerät „wolke“** (ADR 0006, 12.09.) | im Repo: `geraet-wolke/rezeption.sh` (Protokoll-Client in bash), `TAKT.md` (Ablauf der Routine), `umgebung.md` (was Bene einrichtet); Routine „John · wolke“ stündlich Mo–Fr | `bash -n`; Skript gegen die Live-Rezeption: ohne Token Exit 3 mit Grund, mit falschem Token 403 → **Umgebung noch ohne Token, erster Takt steht aus** |
| **Rezeption gehärtet** (12.09.) | Bremse gegen Token-Raten (`daten/bremse.json`, 20 Fehlversuche je Herkunft in 10 min → 429, 0,3 s je Fehlversuch), Körper ≤ 256 KB (413), `nosniff`/`no-referrer`, HSTS nur auf hotel-vaikuntha.de; `.htaccess` sperrt auch `.jsonl/.txt/.ps1` | `php -l`; live nach `hub-deploy.ps1`: 21× falsches Token → 429 mit `Retry-After` |
| **Ein Schlüssel je Gerät** (ADR 0007, 12.09.) | `token.php` mit Liste `geraete`, Schlüssel an den Namen gebunden (`puls`, `nimm`, `log`, `stapel`, `spiegel`); `hub-deploy.ps1 -GeraetErzeugen <name>`, `-NurGeraete`; alter Schlüssel als Übergang | lokal mit `php -S`: Wolken-Schlüssel als vishnu-master → 403, leeres `geraet` → gebundener Name, alter Schlüssel ungebunden; `hub-deploy.ps1` **ohne PowerShell geschrieben, Parser-Prüfung steht aus** |
| **memanto für John** (12.09.) | `docs/memanto.md`: Agent `john`, was hinein darf und was nie; Takt der Wolke liest und schreibt es | Einrichtung auf dem Rechner offen (`memanto agent create john`, `connect claude-code`) |
| **Rückfragen an der Rezeption + Beraterin Madelene** (16.09.) | `w=rueckfragen`, `w=rueckfrage`, `w=rueckfrage-antwort`; Schlüsselklasse `berater` (`token.php › berater`, `hub-deploy.ps1 -BeraterErzeugen/-BeraterKopieren`), verkürzter `stand`; Compass-Modul `compass/compass-fragen-rezeption.js` (per `-Sync`, Produkt-Build nimmt es heraus) | `tools/pruefstand-rueckfragen.py` 32/32 gegen `php -S`; Compass-Vorschau: Frage von Madelene erscheint an 4. Stelle, Antwort per Klick liegt an der Rezeption; live nur lesend geprüft (verkürzter Stand, 403 für Antworten/Puls, 400 für ungültige id) |
| **Madelenes Zugang gehärtet** (16.09., Benes Vorgaben) | Beraterin liest nur eigene Rückfragen (`von` erzwungen) und nur ihre eigene Zahl im `stand`; fremde id → 409 ohne Eigentümer; Wiederholung mit gleicher id → `unveraendert`; `dringend` (max. 1 je Beraterin); `hub-deploy.ps1 -BeraterWiderrufen`, Zwischenablage ohne Verlauf/Cloud, `-OhneWarten`; Compass: gleiche Ordnung für alle (dringend vorn, älteste ab 3 Tagen auf Platz 3), Hinweis bei Störung, lokaler Compass über gitignorierte `rezeption-lokal.js` (`-Sync`). Freigabe-Modell nur als Vorschlag (`docs/madelene-freigaben-vorschlag.md`) | Prüfstand 59/59; live: Widerruf → alter Schlüssel 403, Gerät/Browser 200; Ersatz → neu 200, alt 403; fremde Fragen 403; dreifache Sendung = ein Eintrag; Schlüsselsuche in Repos, Git-Historie, Logs, Sitzungsprotokollen, PowerShell-Verlauf ohne Fund; Vorschau: lokal findet die Rezeption, Sortierung, Störungshinweis |

## Fehlt noch

0. **Wolke läuft seit 14.09.2026 22:41** (Umgebung „John“ `env_01Mo9sPNZwqrAUWqteRuwye5`, Netzwerk „Unbegrenzt“,
   Variablen + Setup-Skript von Bene eingetragen; erster Takt: Puls angekommen, Logbuch „Neues Gerät: wolke“,
   0 Aufträge). Offen: privates Repo `john` (Play-Knopf-Skript unten), Gmail/Kalender an der Routine, `-NurGeraete`.
   Vorgeschichte — Rechnerseite (Claude): `hub-deploy.ps1` parst fehlerfrei,
   `JOHN_HUB_GERAETE=vishnu-master,wolke`, beide Geräteschlüssel erzeugt (`JOHN_HUB_TOKEN_VISHNU_MASTER` =
   `JOHN_HUB_TOKEN`, `JOHN_HUB_TOKEN_WOLKE`), `token.php` liegt in der Rezeption, Worker neu gestartet (Tür
   antwortet, Puls mit neuem Schlüssel angekommen). Routine „John · wolke“ (trig_01H2Kf7L7eU2ADjZmifGY4zt,
   stündlich `0 4-18 * * 1-5`) hat jetzt `john-agent` als **Quelle** — bis dahin klonte sie selbst, und der
   Klassifizierer der Cloud verweigerte `rezeption.sh` als „Code from External“ (Lauf 14.09. 18:02 UTC).
   **Offen, nur Bene:** in claude.ai/code → Environments → Default die Variablen `JOHN_HUB_TOKEN`
   (= `[Environment]::GetEnvironmentVariable('JOHN_HUB_TOKEN_WOLKE','User')`), `JOHN_GERAET=wolke`, optional
   `MOORCHEH_API_KEY` und das Setup-Skript aus `geraet-wolke/umgebung.md` eintragen; privates Repo `john`
   per `C:\dev\_tools\john-repo-anlegen.ps1` anlegen (Play-Knopf; der Klassifizierer blockt das für Claude)
   und als zweite Quelle anhängen; der Routine Gmail/Kalender geben. Wenn beide Geräte laufen:
   `hub-deploy.ps1 -NurGeraete`.
1. **Takt-Funde in den Stapel statt daneben.** Heute stehen sie als eigener Block auf der Kachel; ein Klick
   sortiert neu (ein Claude-Aufruf im Server, bis 90 s). Eleganter: der Server nimmt `letzter-takt.json` als
   Kandidatenquelle und der Compass-Hash berücksichtigt den Takt — dann sortiert John von selbst ein. Braucht
   einen Eingriff in `john-server.ps1` (Get-StapelKandidatenServer) an einem ruhigen Tag.
2. ~~Raumschiff-Subdomain~~ erledigt 11.09.: `raumschiff.vishnuartists.com` leitet aufs Raumschiff. Repo auf GitHub angelegt (öffentlich); Push macht Bene.
3. **Bene digital: Freigabe im Compass** statt auf der Seite, und der erste echte Login-Durchlauf.
4. **Zweites Gerät** — `john-aufgaben.ps1 -Register` mit `JOHN_HUB_TOKEN` und `JOHN_GERAET`.
5. **`john-ki.ps1`** (ADR 0003): für den Worker gibt es sie seit 11.09. (Claude + Codex + Madeleines Kopf); der
   Cockpit-Server lädt weiterhin seinen eigenen Stand (`john-madeleine.ps1`). Zusammenführen an einem ruhigen Tag.
6. **Takt-Quote messen** bis 18.09.: wie viele Takte gedacht, wie viele gehandelt. Unter einem Drittel → 60 min.
7. **Zeitvergleich im Compass selbst:** `stapelStandMischen` in dashboard.html vergleicht Zeitstempel als
   Text („…+02:00" gegen „…Z") — dabei gewinnt manchmal der ältere. Die Lobby umgeht es mit echtem
   Zeitvergleich; im Compass selbst ist es eine Zeile für eine Session, die dashboard.html gerade hält.
8. **Gesprächsraum — was nach dem Einbau offen ist** (Oberfläche siehe „Läuft“; Astras Prüfliste gegen die
   Attrappe steht im Commit f59dbff). Beim Einbau geändert: die Instanz gilt schon als konfiguriert, wenn es
   `JOHN_API` gibt — lokal ist es `''` (same-origin), und der Knopf wäre am Rechner nie erschienen.
   - **`https://bene.vaikuntha.eu`** ist von Bene ausdrücklich als weiterer Einbauort beauftragt.
     Rezeption-Allowlist und Anmeldung (`vishnuartists-website-redesign/f/weiter.php`) bekommen
     genau diese Adresse; keine pauschale Freigabe für andere Vaikuntha-Subdomains.
     HTTPS-Prüfung am 11.09.: DNS erreichbar, Zertifikat passt noch nicht zum Hostnamen
     (`RemoteCertificateNameMismatch`). KAS-Zertifikat und Zuordnung zum geschützten persönlichen
     Portal stehen aus. Danach `JOHN_TUER_ORIGINS` um genau `https://bene.vaikuntha.eu` ergänzen,
     Worker kontrolliert neu laden und Anmeldung sowie Raum auf der Zieladresse prüfen.
   - Am Handy und auf `bene.vishnuartists.com` noch nicht selbst gesehen (die Anmeldung ist Benes).
   - Namensschild auf 140 px verbreitert, damit „Du · Platzhalter“ bei 14 px in die Pille passt.
9. **Offene Entscheidung für Bene:** darf er am Handy in den Raum **schreiben**? Dann läge sein Satz einmal in der
   Rezeption. Bis dahin: am Handy Stand und Stopp.

## Kleine Wahrheiten, die man sonst zweimal lernt

- Der Cockpit-Server meldet bei http.sys nur `http://localhost:8787/` an. Über `127.0.0.1` kommt
  ein **400** zurück — eine Antwort, aber keine brauchbare. Der Worker fragt deshalb `localhost`
  und unterscheidet „dreht sich die Schleife" von „taugt die Antwort".
- Deutsche Anführungszeichen in doppelt gequoteten PowerShell-Strings beenden den String, wenn das
  schließende Zeichen ein gerades `"` ist. Zwei Läufe sind daran gescheitert, der Parser meldet es
  nur manchmal — im Zweifel Anführungszeichen aus Code-Strings heraushalten.
- Ein Kindprozess mit `$p.Kill()` zu beenden, lässt `claude.exe`/`codex.exe` darunter weiterlaufen — der Zug
  hätte nach dem Stopp noch in den Raum geschrieben. Deshalb `taskkill /PID <id> /T /F` über `cmd /c` (ein `2>&1`
  in PowerShell 5.1 wirft bei `ErrorActionPreference Stop` schon an der ersten stderr-Zeile).
- `jh_leer()` gab `geraete` einmal als `stdClass` zurück; der erste Puls auf einer frischen
  Rezeption starb daran. Gefunden nur, weil die Endpunkte wirklich gelaufen sind — `php -l` war grün.

- Das Logbuch der Rezeption hat anfangs Fragetexte mitgeschrieben (`auftrag: <text>`, `fertig: <text>`).
  Seit 11.09. 00:50 nur noch Art und Länge — bei `coach` stünde dort sonst die Frage eines Mitglieds.
  Die zwei alten Zeilen im Live-Log stammen aus meinem eigenen Prüfauftrag und rollen mit der Zeit heraus.


## Hotel-Lobby — direkte Einstiege (11.09.2026)

`#hotel-lobby` öffnet den Gesprächsraum direkt. Der Knopf „Hotel-Lobby öffnen“ sitzt in Johns Karte und in der ansichtsübergreifenden Rhythmusleiste. Vereins-Compass, Benes persönliches Portal und Hotel-Seite verlinken die Lobby. Keine neue Backend-Schnittstelle, keine öffentliche Gesprächsausgabe.

## Holodeck und Aufzug · 11.09.2026

Oberfläche: #holodeck und alter #hotel-lobby öffnen denselben Raum. Fünf fotografische Welten, Tür-/Rasterübergang, große Raumansicht, manuelle und tägliche Garderobe (Europe/Berlin). Private Bilddateien in compass/holodeck-assets sind gitignored und nur hinter den vorhandenen Gates auszuliefern. Keine Änderung der Raumschnittstelle oder Freigabe für mobiles Schreiben. Persönlichkeitswünsche separat an Claude übergeben.

## Holodeck-Stimme und Gäste · 11.09.2026

Browser-Sprachmodus mit ausdrücklicher Aktivierung, optional lokaler Erkennung, automatischem
Senden nach Sprechpause, synthetischen Stimmen pro Teilnehmer und Unterbrechen über /stopp.
Gastvorschläge werden erst nach Klick eingeladen. John stellt die Gastrolle anhand des sichtbaren
Auftrags dar; ein eigenständiger Gast-Worker ist noch nicht angebunden. Keine Originalstimmen.
Browser-Funktionstest mit simuliertem Mikrofon, TTS und Tür prüft Einladung, Einzelsendung,
Reihenfolge, Echo-Vermeidung, keine Wiederholung alter Antworten, Stoppen, Schließen und Ausfall.
Eine echte Unterhaltung mit Benes Mikrofon und Lautsprechern muss Bene noch gegenhören.

## Holodeck: 30 Filmszenen und freigegebene Charaktere · 11.09.2026

Fotografische Filmstills ersetzen die einfachen 3D-Figuren. 30 auswählbare Szenen in fünf Orten,
eigene Dialogauftakte, Kameraregie, Musik- und Castingvorgaben. Freigegebene John-Vorlage und
dunkelhaarige Mona als Madeleine; schlanke sportliche Statur für den eigenen Avatar. Drei neue
Garderobentafeln und Vishnu-/Brahma-/Shiva-Momente. Bilder bleiben privat und gitignoriert.
Kein fertiges Video, keine tatsächliche Figurenbewegung, keine produzierte Musik oder Premiumstimme.

Browserdialog in DE/EN/HI/IT/FR, nur verfügbare Stimmen. Castingwunsch: Madeleine mit französischem
Akzent, John mit deutscher Travolta-Synchronwirkung. Das ist Regie, keine verfügbare Originalstimme.
Der schnelle Schließen/Öffnen-Wechsel beendet den alten Sprachlauf; ein verspätetes close-Ereignis
kann die neue Verbindungsprüfung nicht mehr abschalten. Mikrofon wartet auch auf Picards Begrüßung.

Chrome-Prüfung: alle 30 Bilder geladen, reine Szenenwechsel senden nichts, Orte stimmen, einmalige
Eröffnung, Introabbruch beim Schließen, göttliche Rolle, mobile Breite. Kontrollierter Sprachtest:
englische Erkennung/Sprachauftrag/passende TTS-Auswahl, Gast nur auf Einladung, Ausgabe nacheinander,
kein Echo oder erneutes Vorlesen alter Antworten, Stoppen, schnelles Wiederöffnen und Offline-Stopp.
Echte Mikrofon-Hardware und professionelle Sprecherqualität sind noch nicht abgenommen.
Details: docs/holodeck-film.md. Tür-API unverändert.

## Erlebnisraum, Enterprise-Lounge und Wolken-Coach · 15.09.2026

Astras Commits `9ee1c60` (Eintritt und Gesprächsfluss als Erlebnis) und `988cee1` (Enterprise-Einstellung
und ausdrücklicher Wolken-Coach-Adapter). Neu unter `compass/holodeck-engine/`: `experience.js` löst
`cinema.js` als Raum-Modul ab (Eintritt, Platzwahl, Untertitel, Nebenansichten), `experience.css`,
`coach-door.js`. Der Adapter spricht den vorhandenen `/api/john`-Anschluss des Wolkenservers: HTTPS
erzwungen, `credentials:'omit'`, Basis ausschließlich aus `JOHN_API` — keine neue Herkunft, kein
zweiter Schlüssel, kein Eingriff an der Tür. Sitzungen liegen nur im Speicher; der Stopp beendet den
Empfang, nicht den serverseitigen Lauf, und sagt das über `serverStopUnavailable` auch so. `NO_LOGIN`
kommt im Klartext an die Oberfläche.

Eingebaut in flow-compass als `840b25d` (Quelle `john-agent/compass` per `john-aufgaben.ps1 -Sync`);
`build-compass.ps1` listet die drei neuen Module, Assets (Lounge-Bild, Manifest) bleiben unversioniert.
Veröffentlicht 15.09. 10:01 in die eigene Instanz, 9 Dateien, 0 Fehler. Geprüft: `node --check` über
`experience.js`, `coach-door.js`, `studio-audio.js` und `compass-gespraechsraum.js`. Rückmeldung an
Astra im Postfach als `claude-holodeck-erlebnisraum-20260915-01`.

Noch nicht abgenommen: ein echtes Gespräch über den Wolken-Coach mit Benes Anmeldung — der erste Zug
gehört ihm. Tür-API unverändert.

## Übergabe weitergeführt · 15.09.2026

Portable Prüfungen liegen unter `tools/tests/` mit npm-Lockdatei und eigener Anleitung.
Adapter- und Browserprüfung bestehen lokal; UI-Fixtures benötigen keine privaten Medien.
`docs/protokoll.md` beschreibt Avatar-Zeitspur und asynchrone Jobs mit bestätigtem Cancel
als Vorschlag. Noch kein Renderer und keine neuen Server-Endpunkte implementiert.
Laut Betriebsübergabe um 11:10 antwortet John seit 10:55 wieder; ein neues persönliches
Coaching-Gespräch wurde durch diese Tests nicht ausgelöst. Echte Bewegungsclips fehlen.

## Echte Clip-Wiedergabe · 15.09.2026

Vorhandene lokale LTX-Videos vom 12.09. außerhalb des Asset-Ordners wiedergefunden.
Empfangssequenz nach Eintritt und Johns vorbereitete Kamin-Nahaufnahme mit Gesichts-,
Kopf- und Handbewegung integriert. Stumme Einmal-Clips; Pause bei TTS/Unterbrechen,
Poster bei Fehlern oder reduzierter Bewegung. Kein nahtloser Loop, keine Lippensynchronität.
Medien separat in outputs/holodeck-motion geliefert, bleiben unversioniert. Keine neue
Video-Erzeugung oder Cloud-Anfrage. Branch astra/holodeck-bewegungsclips zur Prüfung
durch Claude; nicht durch Astra deployt. Browserprüfung mit echten MP4s bestanden.

## Unterbrechen sagt die Wahrheit · 15.09.2026

Bene hat entschieden: **kein Server-Stopp jetzt**, stattdessen ehrliche Beschriftung. Umgesetzt in
`compass/holodeck-engine/experience.js` (Knopf „Unterbrechen · Empfang aus“ mit erklärendem Titel) und
`compass/compass-gespraechsraum.js` (zwei Texte, die zu viel behaupteten — vor allem „stoppt Stimme und
Modell“ im Sprach-Panel, jetzt „beendet Stimme und Antwortempfang — John kann auf dem Server
weiterdenken“). Die Fehlermeldungen in `coach-door.js` waren schon ehrlich und blieben unverändert.

Neu abgesichert: `tools/tests/test-experience.cjs` prüft Beschriftung und Titel des Knopfes. Ohne diese
Prüfung war die falsche Zusage überhaupt erst entstanden. `tools/tests/test-motion.cjs` suchte den Knopf
mit `exact:true` und wäre an der Umbenennung gescheitert — nachgezogen. Er lief nicht rot auf, weil
`npm test` ihn nicht startet (er braucht `HOLODECK_MEDIA_DIR`); vor dem Commit einzeln gefahren.

Geprüft am 15.09.2026: `npm test` grün (Adapter + UI) und `node test-motion.cjs` grün mit den echten
Clips aus dem gelieferten Medienpaket — Wiedergabe, Pause bei Unterbrechen, Poster-Rückfall, Entsorgung.
Gegenprobe: mit der alten Beschriftung fällt der neue UI-Test durch, wie er soll.

## Drei Enterprise-Sets live · 16.09.2026

Astras Standbilder `enterprise-bruecke`, `enterprise-aussicht` und `enterprise-maschinenraum` (je 1672×941,
Lieferung in `C:/dev/übergaben/2026-09-16-holodeck-sets/` samt BILDNACHWEISE.json) sind mit
`persoenliches-dashboard/tools/holodeck-clip-einbauen.ps1` in beide Asset-Ordner eingebaut; das Manifest trägt
sie unter `plaetze` (`bruecke`, `aussicht`, `maschinenraum`, je mit gleichnamiger Klangpalette). Assets und
Manifest bleiben unversioniert; am Code hat sich nichts geändert.

Veröffentlicht am 16.09. um 21:15 auf bene. (7 Dateien, 0 Fehler). Angemeldet im Browser geprüft: Die Platzwahl zeigt
sieben Plätze, jeder neue Platz lädt sein Bild, Johns Kamin-Clip läuft weiter, der Raumklang lässt sich einschalten.
Eine Hörprobe steht noch aus. Offen für Bene: Das Empfangsbild `cinema-welcome` zeigt eine Schauspieler-Ähnlichkeit in
Sternenflotten-Uniform und widerspricht damit der Set-Regel aus `holodeck-calliope.md` §8.
