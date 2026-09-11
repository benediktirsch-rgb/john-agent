# Stand — was läuft, was fehlt

Diese Datei wird bei **jeder** Änderung nachgezogen. Sie ist die einzige Stelle, an der die
nächste Session sieht, wo sie steht.

## Läuft (Stand 11.09.2026, 10:20)

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

## Fehlt noch

1. **Takt-Funde in den Stapel statt daneben.** Heute stehen sie als eigener Block auf der Kachel; ein Klick
   sortiert neu (ein Claude-Aufruf im Server, bis 90 s). Eleganter: der Server nimmt `letzter-takt.json` als
   Kandidatenquelle und der Compass-Hash berücksichtigt den Takt — dann sortiert John von selbst ein. Braucht
   einen Eingriff in `john-server.ps1` (Get-StapelKandidatenServer) an einem ruhigen Tag.
2. ~~Raumschiff-Subdomain~~ erledigt 11.09.: `raumschiff.vishnuartists.com` leitet aufs Raumschiff. Repo auf GitHub angelegt (öffentlich); Push macht Bene.
3. **Bene digital: Freigabe im Compass** statt auf der Seite, und der erste echte Login-Durchlauf.
4. **Zweites Gerät** — `john-aufgaben.ps1 -Register` mit `JOHN_HUB_TOKEN` und `JOHN_GERAET`.
5. **`john-ki.ps1` herausziehen** (ADR 0003).
6. **Takt-Quote messen** bis 18.09.: wie viele Takte gedacht, wie viele gehandelt. Unter einem Drittel → 60 min.
7. **Zeitvergleich im Compass selbst:** `stapelStandMischen` in dashboard.html vergleicht Zeitstempel als
   Text („…+02:00" gegen „…Z") — dabei gewinnt manchmal der ältere. Die Lobby umgeht es mit echtem
   Zeitvergleich; im Compass selbst ist es eine Zeile für eine Session, die dashboard.html gerade hält.
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
