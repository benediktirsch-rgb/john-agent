# john-agent

Johns Architektur — die Teile, die dafür sorgen, dass John **läuft**, statt zu schlafen: die Rezeption im
WWW, der Worker auf dem Gerät, die Lobby im Compass. Angelegt am 10.09.2026 auf Benes Auftrag hin.

Hier arbeiten **Claude** (Bau, Betrieb, Code) und **Madeleine** (GPT über die Codex CLI; Gegenprüfung,
Kosten, Organisation) zusammen. Was wir entscheiden, steht in `docs/adr/`; was wir besprechen, in
`beratung/protokoll.md`; was wir gelernt haben, in `wissen/`.

## Lies zuerst

| Frage | Datei |
|---|---|
| Wie ist das gebaut und warum? | [`ARCHITEKTUR.md`](ARCHITEKTUR.md) |
| Wie reden die Teile miteinander? | [`docs/protokoll.md`](docs/protokoll.md) |
| Was läuft schon, was fehlt? | [`docs/stand.md`](docs/stand.md) |
| Wie starte, prüfe, repariere ich? | [`docs/betrieb.md`](docs/betrieb.md) |
| Was muss Bene im KAS von Hand tun? | [`docs/kas-schritte.md`](docs/kas-schritte.md) |
| Wozu ist John überhaupt da? | [`wissen/zweck.md`](wissen/zweck.md) |
| Warum so und nicht anders? | [`docs/adr/`](docs/adr/) |

## Die drei Teile in einem Satz

- **Rezeption** (`hub/`) — PHP auf dem KAS unter `hotel-vaikuntha.de/john/`. Johns Zimmer: hält seinen
  Stapel, seine Aufträge, sein Logbuch. Wach rund um die Uhr, denkt nie.
- **Gerät** (`geraet/`) — `john-worker.ps1`, ein Prozess je Rechner. Johns Hände: Takt, Tür auf Port
  8788, Denken in abgekoppelten Kindprozessen.
- **Lobby** (`compass/`) — `compass-john-lobby.js`, hängt sich von außen an den Flow Compass. Erscheint,
  wenn John gerade nicht kann, zeigt seinen letzten Stand und startet ihn.

## Loslegen

```powershell
# Gerät anmelden und Aufgaben einrichten (einmal je Rechner)
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\john-agent\geraet\john-aufgaben.ps1 -Register

# Läuft alles?
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\john-agent\geraet\john-aufgaben.ps1 -Status

# Rezeption hochladen (braucht VA_FTP_HOST/USER/PASS als User-Umgebungsvariablen)
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\john-agent\hub\hub-deploy.ps1
```

## Grenzen

Nichts Persönliches in dieses Repo: keine Kontostände, keine Namen aus dem CRM, keine Betreffzeilen,
keine Zugänge. Zugänge sind ausschließlich User-Umgebungsvariablen (`JOHN_HUB_URL`, `JOHN_HUB_TOKEN`,
`JOHN_GERAET`, `VA_FTP_*`). Johns Inhalte (Pipeline, Coaching, Profil) bleiben im Ordner `C:\dev\john`.
