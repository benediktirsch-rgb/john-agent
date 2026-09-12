# Betrieb — starten, nachsehen, reparieren

## Die drei Stellen

| Was | Wo | Wie man sie fragt |
|---|---|---|
| Cockpit-Server (Compass + Quellen) | `john-server.ps1`, Port **8787** | `http://localhost:8787/api/john/status` |
| Gerät (Johns Hände) | `john-worker.ps1`, Port **8788** | `http://127.0.0.1:8788/stand` |
| Rezeption (Johns Zimmer) | `hotel-vaikuntha.de/john/` | `api.php?w=stand` mit Kopf `X-John-Token` |

Ein Satz, der alles zeigt:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\john-agent\geraet\john-aufgaben.ps1 -Status
```

## Geplante Aufgaben

| Aufgabe | Takt | tut |
|---|---|---|
| `John Server` | **jede Minute** | startet den Cockpit-Server, wenn er fehlt (IgnoreNew: läuft er, passiert nichts) |
| `John Server Wacht` | alle 2 Min | erkennt einen **blockierten** Server und beendet ihn; startet selbst nichts |
| `John Worker` | alle 2 Min | startet Johns Hände, wenn sie fehlen |

Alle drei laufen **interaktiv** (nur bei angemeldetem Benutzer) und **ohne Zeitlimit** — mit
Zeitlimit würde der Aufgabenplaner genau die Prozesse abschießen, die er am Leben halten soll.

## Wenn John nicht antwortet

Die Lobby im Compass sagt es inzwischen selbst; hier die Handarbeit dahinter.

1. **Wer lebt?** `john-aufgaben.ps1 -Status`. Interessant ist die Kombination:
   - Server läuft, Tür antwortet, Port 8787 keine Antwort → **Hänger**. `POST 127.0.0.1:8788/wecken`
     beendet ihn, die Aufgabe startet ihn binnen einer Minute neu.
   - Server läuft nicht → `Start-ScheduledTask -TaskName 'John Server'` oder einfach eine Minute warten.
   - Tür antwortet nicht → `Start-ScheduledTask -TaskName 'John Worker'`; Log: `geraet\john-worker.log`.
2. **Antwortet er dem Gerät, aber nicht dem Browser?** Dann ist die Adresse im Compass falsch:
   Browser-Speicher `compassJohnApi` (Standard `http://localhost:8787`). Genau das meldet die Lobby
   als „John läuft — diese Seite erreicht ihn nicht".
3. **Nach jeder Code-Änderung neu starten.** Beide Prozesse laden ihren Code nur beim Start.
   Worker: `http://127.0.0.1:8788/__stop`, dann `Start-ScheduledTask -TaskName 'John Worker'`.
   Server: `http://localhost:8787/__stop` — und danach **prüfen, ob der Prozess wirklich weg ist**;
   er bleibt manchmal stehen, spiegelt nach H: und blockiert die Aufgabe (IgnoreNew).

## Gerät „wolke“ (seit 12.09.2026, ADR 0006)

Läuft nicht auf einem Rechner: eine Routine in Claude Code (Web) startet stündlich Mo–Fr 06–20 Uhr eine
Session, die `geraet-wolke/TAKT.md` abarbeitet. Sie spricht die Rezeption über `geraet-wolke/rezeption.sh`
an, nimmt Aufträge, setzt den Stapel nur, wenn kein anderes Gerät in den letzten zwei Stunden getaktet hat.

| Frage | Antwort |
|---|---|
| Lebt sie? | `w=stand` → `geraete[]` enthält `wolke` mit `takt`; `wach` ist nur während der Session wahr |
| Stumm? | Routine in claude.ai/code → Routines ansehen: letzte Läufe, Fehler. Ohne `JOHN_HUB_TOKEN` endet jeder Lauf nach einer Zeile („nicht angebunden“) |
| Anhalten | Routine deaktivieren; John läuft dann nur noch auf dem Rechner |
| Neu starten | Routine „jetzt ausführen“ — ein Takt außer der Reihe |
| Zeitumstellung | Cron ist UTC: Sommer `0 4-18 * * 1-5`, Winter `0 5-19 * * 1-5` |

## Johns Takt

- Mo–Fr 6:30–21:30, standardmäßig alle 30 Minuten. Wochenende und Nacht sind bewusst frei.
- Ein Takt denkt **nur, wenn sich die Lage geändert hat** (SHA-256 über den Kontext,
  `geraet\takt-hash.txt`). Sonst kostet er nichts.
- Von Hand: `POST 127.0.0.1:8788/takt` oder `john-worker.ps1 -Einmal` (im Vordergrund, mit Ausgabe).
- Was dabei herauskommt, steht in `john\coaching\takt.md`, in `geraet\letzter-takt.json` und —
  wenn eine Rezeption eingerichtet ist — in Johns Stapel auf allen Geräten.
- Kontingent: ein Takt ist ein Claude-Aufruf auf **Benes Abo**. Zu viele Takte gehen ihm tagsüber
  selbst ab. Wer den Abstand verkleinern will, rechnet vorher: 30 min → ~26 Aufrufe/Woche.

## Was Johns Stapel darf und was nicht

`persoenliches-dashboard\john-stapel.json` gehört **dem Cockpit-Server allein**. Er hält die Datei
im Speicher und überschreibt sie vollständig; jede Schreibung von außen ist beim nächsten Speichern
lautlos weg. Wer Johns Stapel von außen ändern will, geht über die Rezeption (`w=stapel`) oder über
den Server-Endpunkt — nie über die Datei.

## Logbücher

| Datei | was drin steht |
|---|---|
| `geraet\john-worker.log` | Start, Wecken, Aufträge, Takt |
| `geraet\john-auftrag.log` | jeder Denkvorgang mit Dauer und Ergebnis |
| `_tools\john-wacht.log` | wann die Wacht einen Hänger beendet hat |
| Rezeption `w=stand` → `log` | die letzten 20 Ereignisse geräteübergreifend |

## Zugänge

Alles User-Umgebungsvariablen, nie Dateien:
`JOHN_HUB_URL`, `JOHN_HUB_TOKEN`, `JOHN_GERAET` (Standard: Rechnername), `JOHN_BACKEND`
(`cli` = Claude-Abo, Standard), `VA_FTP_HOST/USER/PASS` (nur zum Hochladen der Rezeption).
Änderungen wirken erst im **neu gestarteten** Prozess.
