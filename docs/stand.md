# Stand — was läuft, was fehlt

Diese Datei wird bei **jeder** Änderung nachgezogen. Sie ist die einzige Stelle, an der die
nächste Session sieht, wo sie steht.

## Läuft (Stand 11.09.2026, 00:30)

| Teil | Zustand | geprüft womit |
|---|---|---|
| **Lobby** im Compass | in `dashboard.html`, in der eigenen Instanz gebaut | Browser: fünf Lagen richtig benannt, Fenster öffnet nach 2 Fehlschlägen (~6 s) |
| **Worker** auf `vishnu-master` | Aufgabe „John Worker", Tür auf 8788 | `GET /stand` antwortet in ms, `POST /wecken` erkennt einen gesunden Server |
| **Rezeption** im WWW | `https://naturnah-lernen.de/john/` und `http://hotel-vaikuntha.de/john/` | alle neun Endpunkte durchgespielt; ohne Token 403, `stand.json` und `token.php` 403 |
| **Puls** Gerät → Rezeption | jede Minute | Rezeption meldet `wach: true`, Gerät `vishnu-master` |
| **Wiederanlauf** | Aufgabe „John Server" jetzt **jede Minute** (vorher 5) | `-Status` zeigt `PT1M` |
| **Hub im Compass-Build** | `build-compass.ps1` setzt Adresse + Token in die eigene Instanz | im gebauten `index.html` nachgelesen |
| **Zwei Schlüssel** (Gerät / Browser) + CORS-Allowlist | Madeleines Einwand, sofort umgesetzt | live: Browser-Schlüssel auf `stapel`/`auftraege`/`log` → 403, fremder Ursprung ohne Allow-Origin |
| **Takt-Wächter** `takt.letzter` / `stille_tage` | in `w=stand`, in der Lobby sichtbar | Feld live abgefragt (noch `null`: erster Takt am Morgen) |
| **Projekt John** auf vishnuartists.com | `f/projekt-john.php`, im Menü „Intern" jeder eingeloggten Seite | Prüfstand 25/25; Deploy über GitHub |
| **Bene digital** (Buchung → Entwurf → Freigabe) | Briefkasten `daten/eingang.jsonl`, Auftrag `coach`, öffentliche Persona | echter Durchlauf 11.09. 00:42: Worker holte den Auftrag selbst, Claude 12 s, Entwurf in der Rezeption |
| **Demo bleibt sauber** | Produkt-Build nimmt Lobby und Rezeption heraus | Wortprüfung bestanden, `compass-john-lobby.js` nicht im Demo-Ordner |

## Fehlt noch

1. **Compass-Karte aus der Rezeption speisen.** Johns Kachel liest ihren Stapel weiter vom
   Cockpit-Server. Solange das so ist, gibt es zwei Stände (ADR 0004). Nächster Schritt:
   `johnKachel()` liest zuerst die Rezeption und schreibt jedes OK dorthin (`w=punkt`) — dann
   stimmt „einmal abgeräumt, überall weg" wirklich.
2. **hotel-vaikuntha.de mit eigenem Verzeichnis und Zertifikat** (`docs/kas-schritte.md`, Bene).
3. **Zweites Gerät.** Das Protokoll trägt es; gebraucht wird nur `john-aufgaben.ps1 -Register` mit
   gesetztem `JOHN_HUB_TOKEN` und `JOHN_GERAET`. Handy: liest über die Rezeption mit, denkt nicht.
4. **Bene digital: Freigabe im Compass.** Heute gibt Bene Entwürfe auf `projekt-john.php` frei. Besser wäre
   eine Rückfrage im Compass („Antwort an Sarah freigeben?"), dort entscheidet er ohnehin. Dazu: der erste
   echte Login-Durchlauf der Seite (angemeldete Wege sind nur im Prüfstand gelaufen, nicht live).
5. **`john-ki.ps1` herausziehen** (ADR 0003) — solange steht der Claude-Aufruf zweimal da.
6. **Erster echter Takt steht noch aus.** Angelegt in der Nacht zum 11.09.; das Zeitfenster
   (Mo–Fr 6:30–21:30) öffnet erst am Morgen. Der erste Lauf gehört gelesen: `john\coaching\takt.md`
   und `geraet\john-auftrag.log`.

## Kleine Wahrheiten, die man sonst zweimal lernt

- Der Cockpit-Server meldet bei http.sys nur `http://localhost:8787/` an. Über `127.0.0.1` kommt
  ein **400** zurück — eine Antwort, aber keine brauchbare. Der Worker fragt deshalb `localhost`
  und unterscheidet „dreht sich die Schleife" von „taugt die Antwort".
- Deutsche Anführungszeichen in doppelt gequoteten PowerShell-Strings beenden den String, wenn das
  schließende Zeichen ein gerades `"` ist. Zwei Läufe sind daran gescheitert, der Parser meldet es
  nur manchmal — im Zweifel Anführungszeichen aus Code-Strings heraushalten.
- `jh_leer()` gab `geraete` einmal als `stdClass` zurück; der erste Puls auf einer frischen
  Rezeption starb daran. Gefunden nur, weil die Endpunkte wirklich gelaufen sind — `php -l` war grün.

- Das Logbuch der Rezeption hat anfangs Fragetexte mitgeschrieben (`auftrag: <text>`, `fertig: <text>`).
  Seit 11.09. 00:50 nur noch Art und Länge — bei `coach` stünde dort sonst die Frage eines Mitglieds.
  Die zwei alten Zeilen im Live-Log stammen aus meinem eigenen Prüfauftrag und rollen mit der Zeit heraus.
